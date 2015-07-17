################################################################
#                                               ________
# DANGER, WILL ROBINSON!                       / *  + % \
#                                              |  + = + |
# THIS IS THE OLD ORDER IMPORTER!        V     \________/
#                                        0   ______||______
# DOCTOR SMITH HAS PROGRAMMED ME TO      0  |              |
# TELL YOU THAT THE NEW ONE IS AT        0000000 :::::: 0000000
#                                           |              |  0
#    XT::Data::Order                        \______________/  0|<
#                                              =========
# HE IS PROBABLY TELLING THE TRUTH!            ==== ====
#                                              ==== ====
# PROCEED AT YOUR OWN RISK!                    ==== ====
#                                            """""""""""""
# ALSO, AVOID ANY HUGE CARROTS!              |||||||||||||
#                                            """""""""""""
################################################################

package XT::OrderImporter;

use strict;
use warnings;
use XTracker::Config::Local             qw( config_var is_staff_order_premier_channel sys_config_var config_section_slurp );
use XTracker::Database                  qw( get_schema_using_dbh );
use XTracker::Database::Address;
use XTracker::Database::Customer        qw( :DEFAULT match_customer );
use XTracker::Database::Finance         qw( :DEFAULT get_credit_hold_thresholds );
use XTracker::Database::Invoice;
use XTracker::Database::Order;
use XTracker::Database::OrderPayment    qw( create_order_payment );
use XTracker::Database::Product         qw( :DEFAULT check_product_preorder_status) ;
use XTracker::Database::Reservation;
use XTracker::Database::Shipment        qw( get_shipment_shipping_account check_shipment_restrictions :DEFAULT );
use XTracker::DHL::RoutingRequest       qw( get_dhl_destination_code set_dhl_destination_code );
use XTracker::Promotion::Pack;
use XTracker::Database::Currency        qw( get_local_conversion_rate );

use XTracker::Role::WithAMQMessageFactory;

use XTracker::Logfile qw(xt_logger);
my $logger = xt_logger(__PACKAGE__);

use NAP::Carrier;

use Data::Dump qw(pp);

use XT::Domain::Payment;
use XT::Order::ImportUtils;
use XT::Business;

use DateTime;
use DateTime::Format::Strptime;
use Mail::Sendmail;
use Encode qw/encode decode/;

use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
    :carrier
    :customer_category
    :flag
    :order_status
    :pws_action
    :shipment_class
    :shipment_item_returnable_state
    :shipment_item_status
    :shipment_status
    :shipment_type
);


use File::Copy;
{
    my $payment_ws;

    sub extract_telephone {
        my($order,$node) = @_;
        my $numbers = { };

        foreach my $telephone ($order->findnodes("$node/TELEPHONE")) {
            if ($telephone->findvalue('@TYPE') eq "HOME") {
                $numbers->{home_telephone} = $telephone->hasChildNodes
                    ? $telephone->getFirstChild->getData : "";
            }
            elsif ($telephone->findvalue('@TYPE') eq "OFFICE") {
                $numbers->{work_telephone} = $telephone->hasChildNodes
                    ? $telephone->getFirstChild->getData : "";
            }
            elsif ($telephone->findvalue('@TYPE') eq "MOBILE") {
                $numbers->{mobile_telephone} = $telephone->hasChildNodes
                    ? $telephone->getFirstChild->getData : "";
            }
        }

        # if we don't have any numbers ...
        if (not keys %{$numbers}) {
            $logger->info("NO TELEPHONE NUMBERS FOUND");
            return;
        }

        $numbers->{telephone} = ($numbers->{home_telephone} eq "")
            ? $numbers->{work_telephone}
            : $numbers->{home_telephone};

        return $numbers;
    }

    sub call_psp {
        my($order_data,$tender,$tender_data) = @_;

        # get preauth ref from file
        $order_data->{preauth_ref}
            = $tender->findvalue('PAYMENT_DETAILS/PRE_AUTH_CODE');

        # query PSP for payment info
        $payment_ws ||= XT::Domain::Payment->new();

        $order_data->{payment_info} = $payment_ws->getinfo_payment({
            reference => $order_data->{preauth_ref},
        });

        if (!$order_data->{payment_info}{providerReference}) {
            die "Could not get payment info from PSP: reference: "
                ."$order_data->{preauth_ref}";
        }

        # pass payment value for checking later
        $order_data->{transaction_value}
            = $order_data->{payment_info}{coinAmount} / 100;

        # sort out card number to match old formats when checking
        if ( uc($order_data->{payment_info}{cardType}) eq 'AMEX' ) {
            $order_data->{payment_info}{card_number}
                = $order_data->{payment_info}{cardNumberFirstDigit}
                . 'xxxxxxxxxx'
                . $order_data->{payment_info}{cardNumberLastFourDigits};
        }
        else {
            $order_data->{payment_info}{card_number}
                = $order_data->{payment_info}{cardNumberFirstDigit}
                . 'xxxxxxxxxxx'
                . $order_data->{payment_info}{cardNumberLastFourDigits};
        }

        # debugging
        $logger->info("\n-------------\nGET PAYMENT DETAILS:\n-------------");
        foreach my $key ( keys %{$order_data->{payment_info}} ) {
                $logger->info("$key - $order_data->{payment_info}{$key}")
        }
        $logger->info("\n------------\nEND PAYMENT DETAILS:\n-------------");

        # in renumeration type table 'Card' is actuall 'Card Debit'
        $tender_data->{type}    = 'Card Debit';
    }
}

sub process_order_xml {
    ## no critic(ProhibitDeepNests)
    my (%args) = @_;

    my ($path, $DC, $dbh, $dbh_web, $parser, $channels, $skip_commit)
        = @args{qw(path DC dbh dbh_web parser channels skip_commit)};

    if (not ref($dbh_web)) {
        die "\$dbh_web needs to be a hash_ref containing web db details";
    }

    warn '######### SKIPPING COMMIT OF ORDER DETAILS'
        if $skip_commit;

    # get a schema connection for NAP::Carrier
    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    # business logic encapsulated using module pluggable
    my $business_logic = XT::Business->new({ });


    ### flag to catch any import errors
    my $import_error = 0;

    open my $xml, "<", $path || die "can't open file: $!";
    my $tree = $parser->parse_fh( $xml );
    close($xml);

    my $root = $tree->getDocumentElement;
    my @orders = $root->getElementsByTagName('ORDER');

    # set-up AMQ
    my $amq = XTracker::Role::WithAMQMessageFactory->build_msg_factory;
    $amq->transformer_args->{schema}=$schema;

    my $order_id;
    my $order_email_data;
    my $orders_id;

    foreach my $order ($root->findnodes('ORDER')) {
        my $plugin = undef;
        eval {

            my $utils = XT::Order::ImportUtils->new();
            $order_id = $order->findvalue('@O_ID');

            my $order_data = $utils->order_data($order);

            my $customer_data       = ();
#            my $customer_data       = $utils->customer_data(
#                $order, $order_data->{channel_id});
            my $tender_data         = ();
            my $promotion_data      = ();
            my $freeshipping_data   = ();
            my $freeshipping_all    = 0;
            my $bill_address        = ();
#            my $bill_address        = $utils->bill_address($order);
            my $fraud_data          = ();

            my $tax_check           = 0;
            my $duty_check          = 0;
            my $ship_check          = 0;

            my $freeship            = 0;
            my $percentage_discount = 0;
            my $ftbc_order          = 0;
            my $premier_order       = 0;

            # start collecting order data from input file
            my $channel_row = $schema->resultset('Public::Channel')->find(
                $order_data->{channel_id}
            );

            # Cannot tell what channel it is - this IS fatal
            if (!$channel_row) {
               die __PACKAGE__ .": Cannot find channel id - "
                    .$order_data->{channel_id};
            }

            $plugin = $business_logic->find_plugin(
                $channel_row,'OrderImporter');

            if (!defined $plugin) {
                $logger->info( __PACKAGE__ .": No plugin found for channel_id "
                    .$order_data->{channel_id} ." - this isn't fatal as it "
                    ."may not have its business logic seperated");
            }



            $logger->info("Processing Order: ".$order_data->{order_nr});


            $logger->info("HOME TEL: ".$order_data->{home_telephone});
            $logger->info("WORK TEL: ".$order_data->{work_telephone});
            $logger->info("MOBILE TEL: ".$order_data->{mobile_telephone});

            # SECTION: FRAUD DATA
            # push email and telephone into the fraud check hash
            $fraud_data->{"Customer"}{"Email"}     = $order_data->{email};
            $fraud_data->{"Customer"}{"Telephone"} = $order_data->{telephone};

            # billing address
            $bill_address->{first_name}     = $order->findvalue('BILLING_DETAILS/NAME/FIRST_NAME');
            $bill_address->{last_name}      = $order->findvalue('BILLING_DETAILS/NAME/LAST_NAME');
            $bill_address->{address_line_1} = $order->findvalue('BILLING_DETAILS/ADDRESS/ADDRESS_LINE_1');
            $bill_address->{address_line_2} = $order->findvalue('BILLING_DETAILS/ADDRESS/ADDRESS_LINE_2');
            $bill_address->{address_line_3} = "";
            $bill_address->{towncity}       = $order->findvalue('BILLING_DETAILS/ADDRESS/TOWNCITY');
            $bill_address->{postcode}       = $order->findvalue('BILLING_DETAILS/ADDRESS/POSTCODE');
            $bill_address->{country}        = _get_country_by_code($dbh, $order->findvalue('BILLING_DETAILS/ADDRESS/COUNTRY'));

            # DC specific fields
            if ( $DC eq 'DC2' ) {
                $bill_address->{county}
                    = $order->findvalue('BILLING_DETAILS/ADDRESS/STATE');
            }
            else { # Default to DC1 behaviour
                $bill_address->{county}
                    = $order->findvalue('BILLING_DETAILS/ADDRESS/COUNTY');
            }

            # push billing address into the fraud check hash
            $fraud_data->{"Address"}{"Name"} = $bill_address->{first_name} ." ".$bill_address->{last_name};
            $fraud_data->{"Address"}{"Street Address"} = $bill_address->{address_line_1};
            $fraud_data->{"Address"}{"Street Address"} .= ' '.$bill_address->{address_line_2};
            $fraud_data->{"Address"}{"Town/City"} = $bill_address->{towncity};
            $fraud_data->{"Address"}{"County/State"} = $bill_address->{county};
            $fraud_data->{"Address"}{"Postcode/Zipcode"} = $bill_address->{postcode};
            $fraud_data->{"Address"}{"Country"} = $bill_address->{country};


# FIXME preprocess_tender DONE
            # SECTION: TENDER LINE
            # payment info - credit card and store credits
            foreach my $tender ($order->findnodes('TENDER_LINE')) {
                my $tender_data;
                # get tender type (card or credit)
                $tender_data->{type}    = $tender->findvalue('@TYPE');
                $tender_data->{rank}    = $tender->findvalue('@RANK');


                # has to have a type!
                if (!$tender_data->{type}) {
                    die "No Tender Line type present";
                }

                # get tender value
                $tender_data->{value}   = $tender->findvalue('VALUE');

                # credit card
                if ($tender_data->{type} eq "Card") {
                    call_psp($order_data,$tender,$tender_data);
                }
                # store credit
                elsif ($tender_data->{type} eq "Store Credit") {
                    $order_data->{store_credit} = $tender_data->{value} * -1;
                }
                # gift credit
                elsif ($tender_data->{type} eq "Gift Credit") {
                    $order_data->{gift_credit}  = $tender_data->{value} * -1;
                }
                elsif ($tender_data->{type} eq "Gift Voucher") {
                    $tender_data->{type}    = "Voucher Credit";
                    $order_data->{voucher_credit}  = $tender_data->{value} * -1;
                    $tender_data->{voucher_code} = $tender->findvalue('@VOUCHER_CODE');
                    die "Voucher code missing"
                        unless defined $tender_data->{voucher_code}
                            and length $tender_data->{voucher_code};
                }

                push @{$order_data->{tenders}}, $tender_data;
            }

# XXX preprocess_tender


            die "There are no tenders associated with this order!!"
                unless scalar @{$order_data->{tenders}};

            # push card number into fraud check hash
            $fraud_data->{"Payment"}{"Card Number"}
                = $order_data->{payment_info}{card_number};


            # SECTION: PROMOTIONS
            # expected promotion types - must match one of these
            # FIXME parsing? _preprocess_cost_reduction - this mapping is done on parsing
            my %promo_type = (
                'free_shipping'         => 'Free Shipping',
                'percentage_discount'   => 'Percentage Off',
                'FS_GOING_GOING_GONE'   => 'Reverse Auction',
                'FS_PUBLIC_SALE'        => 'Public Sale',
                    # this was Percentage Off but it was impacting
                    # NAP evenmotions
            );

# FIXME __preprocess_free_shipping
            # SECTION: PROMOTION BASKET -
            # FIXME only loop for parsing -at most 1 free_shipping to take account of
            foreach my $promotion ($order->findnodes('PROMOTION_BASKET')) {
                my $promo_id = $promotion->findvalue('@PB_ID');
                my $promo_rec = {
                    type => $promotion->findvalue('@TYPE') || undef,
                    description => _get_promo_name_from_web( # FIXME: DELEGATED TO WEBAPP
                        $dbh_web->{ $order_data->{channel_id} },
                        $promotion->findvalue('@DESCRIPTION')
                    ),
                    shipping => 0,
                    promotion_discount => 0,
                };

                die "PROMO: Unknown promotion type: $promo_rec->{type}\n"
                    if (!$promo_rec->{type});
                $promo_rec->{class} = $promo_type{ $promo_rec->{type} },

                my $value = $promotion->findvalue('VALUE') || 0;
                $logger->info("WARNING: Unexpected promotion value: $value")
                    if ( !$value || $value <= 0 );

                # FIXME Assume this is done in the parsing.
                # free shipping
                if ( $promo_rec->{class} eq 'Free Shipping' ) {
                    $promo_rec->{shipping} = $value; # AS: This is the essence of what we were doing!
                }

                $logger->info("BASKET PROMO: $promo_rec->{description} ($promo_id)");
                $logger->info("TYPE: $promo_rec->{type}");
                $logger->info("VALUE: $value");
                $logger->info("SHIPPING: $promo_rec->{shipping}");
                $logger->info("FIXED DISCOUNT: $promo_rec->{promotion_discount}");
                $logger->info("\n----END PROMO----\n");

                $promotion_data->{$promo_id} = $promo_rec;
            }


# FIXME _preprocess_cost_reduction
            # SECTION: PROMOTION LINE
            foreach my $promotion ($order->findnodes('PROMOTION_LINE')) {

                # FIXME parsing to YYY
                # collect promo data and validate
                my $promotion_detail_id = $promotion->findvalue('@PL_ID');
                my $type                = $promotion->findvalue('@TYPE');
                my $description         = _get_promo_name_from_web( $dbh_web->{ $order_data->{channel_id} },
                                                , $promotion->findvalue('@DESCRIPTION') );
                my $value               = $promotion->findvalue('VALUE') || 0;

                # validate promo type
                if ( !$promo_type{ $type } ) {
                    die "PROMO: Unknown promotion type: $type";
                }

                # validate promo value
                if ( !$value || $value <= 0 ) {
                    $logger->info("WARNING: Unexpected promotion value: $value");
                }

                # get items discount applies to
                foreach my $orderline ($promotion->findnodes('ORDER_LINE_ID')) {
                    my $line_id = $orderline->hasChildNodes ? $orderline->getFirstChild->getData : "";
                    $promotion_data->{$promotion_detail_id}{items}{$line_id} = 1;
                }

                # start processing the promo data
                $promotion_data->{$promotion_detail_id}{type}           = $type;
                $promotion_data->{$promotion_detail_id}{class}          = $promo_type{ $type };
                $promotion_data->{$promotion_detail_id}{description}    = $description;
                # YYY

                # percentage discount
                # 'Reverse auction' and 'percentage discount' - value already off
                # unit price so only need to work out value off each component
                # of product cost (unit price, tax and duty)
                if ( $promo_type{ $type } =~ m{^(?:Reverse Auction|Percentage Off|Public Sale)$} ) {

                    # first loop over items to get their full price value
                    # FIXME all this is used for is calculating $percentage_removed WITH THIS PROMOTION!
                    my $item_total = 0;

                    ## FIXME It's not obvious whether this is parsing or processing, and if it's needed at all
                    foreach my $shipment ($order->findnodes('DELIVERY_DETAILS')) {
                        foreach my $item ($shipment->findnodes('ORDER_LINE')) {

                            # only include if item has promo applied
                            if ( $promotion_data->{$promotion_detail_id}{items}{$item->findvalue('@OL_ID')} ){
                                $item_total += ( $item->findvalue('UNIT_NET_PRICE/VALUE')
                                        + $item->findvalue('TAX/VALUE')
                                        + $item->findvalue('DUTIES/VALUE') )
                                    * $item->findvalue('@QUANTITY');

                            }
                        }
                    }
                    ## YYY

                    ##
                    # FIXME percentage_removed is the wrong name!!  suggests percentage of the original cost. It's actually
                    # just a ratio of discount:end_price which is used to calculate the discount amount for each item
                    ##
                    # now calculate the value of promotion as a percentage of item cost to work out split discount
                    $promotion_data->{$promotion_detail_id}{percentage_removed} = sprintf( "%.2f", ($value / $item_total) );

                    # FIXME This is for reporting
                    # second loop over order items to work out discount value per item
                    foreach my $shipment ($order->findnodes('DELIVERY_DETAILS')) {
                        foreach my $item ($shipment->findnodes('ORDER_LINE')) {

                            my $ol_id = $item->findvalue('@OL_ID');
                            # only include if item has promo applied
                            if ( $promotion_data->{$promotion_detail_id}{items}{$ol_id} ){

                                # Going going gone sale items on DC2 are not returnable
                                $promotion_data->{$promotion_detail_id}{returnable}{$ol_id} =
                                  ! (($promo_type{ $type } eq 'Reverse Auction'
                                        || $promo_type{ $type } eq 'Public Sale')
                                  && $DC eq 'DC2' );


                                if (! $promotion_data->{$promotion_detail_id}{returnable}{$ol_id}) {
                                  $promotion_data->{$promotion_detail_id}{returnable}{$ol_id} = $SHIPMENT_ITEM_RETURNABLE_STATE__NO;
                                  $logger->info("GGG/PUBLICSALE: Item $ol_id is not returnable");
                                }

                                $promotion_data->{$promotion_detail_id}{discounts}{$ol_id}{unit_price}
                                    = $item->findvalue('UNIT_NET_PRICE/VALUE') * $promotion_data->{$promotion_detail_id}{percentage_removed};
                                $promotion_data->{$promotion_detail_id}{discounts}{$ol_id}{tax}
                                    = $item->findvalue('TAX/VALUE') * $promotion_data->{$promotion_detail_id}{percentage_removed};
                                $promotion_data->{$promotion_detail_id}{discounts}{$ol_id}{duty}
                                    = $item->findvalue('DUTIES/VALUE') * $promotion_data->{$promotion_detail_id}{percentage_removed};
                            }
                        }
                    }
                }

                $logger->info("ITEM PROMO: $description ($promotion_detail_id)");
                $logger->info("TYPE: $type");
                $logger->info("VALUE: $value");
                if ( $promotion_data->{$promotion_detail_id}{percentage_discount} ) {
                    $logger->info("PERC DISCOUNT: $promotion_data->{$promotion_detail_id}{percentage_discount}");
                    $logger->info("ITEMS:");
                    foreach my $item_id ( keys %{$promotion_data->{$promotion_detail_id}{items}} ) {
                        $logger->info("$item_id - $promotion_data->{$promotion_detail_id}{items}{$item_id} subtracted");
                     }
                }
                $logger->info("\n----END PROMO----\n");
            }


            #die "END PROMOS";

# XXX _preprocess_cost_reduction

            $logger->info("ORDER TOTAL: ".$order_data->{gross_total});
            $logger->info("CREDIT CARD VALUE: ".$order_data->{transaction_value});
            $logger->info("STORE CREDIT: ".$order_data->{store_credit});
            $logger->info("GIFT CREDIT: ".$order_data->{gift_credit});


# FIXME _create_or_update_customer DONE
            # SECTION: CUSTOMER
            # get customer details from XML
            $customer_data->{is_customer_number} = $order_data->{customer_nr};
            $customer_data->{title}              = $order->findvalue('BILLING_DETAILS/NAME/TITLE');
            $customer_data->{first_name}         = $bill_address->{first_name};
            $customer_data->{last_name}          = $bill_address->{last_name};
            $customer_data->{category_id}        = $CUSTOMER_CATEGORY__NONE;
            $customer_data->{email}              = $order_data->{email};
            $customer_data->{telephone_1}        = $order_data->{home_telephone};
            $customer_data->{telephone_2}        = $order_data->{work_telephone};
            $customer_data->{telephone_3}        = $order_data->{mobile_telephone};
            $customer_data->{channel_id}         = $order_data->{channel_id};


            # create customer
            if ($order_data->{customer_id} == 0) {
                $order_data->{customer_id} = create_customer($dbh, $customer_data);
                $logger->info("Created customer $order_data->{customer_id}");
            }
            # update customer
            else {
                $customer_data->{customer_id}   = $order_data->{customer_id};
                update_customer($dbh, $customer_data);
                $logger->info("Updated customer - ".$order_data->{customer_id});
            }

            # check customer against default categories
            _check_customer_category($dbh, $order_data->{customer_id}, $order_data->{email});
            $logger->info("Finished customer stuff");

# XXX _create_or_update_customer

### FIXME _create_order

            # SECTION: CREATE ORDER
            $orders_id = create_order($dbh, $order_data, $bill_address);

            # SECTION: CREATE ORDER PAYMENT
            if ($order_data->{preauth_ref}) {
                create_order_payment(
                    $dbh,
                    $orders_id,
                    $order_data->{payment_info}{providerReference},
                    $order_data->{preauth_ref}
                );
            }

### XXX _create_order

            #
            # For gift vouchers now only going to create one shipment record which is always
            # what was happening anyway.
            #

# FIXME preprocess_shipment
            my $shipment_data       = {
                shipment_total   => 0,
                class_id         => $SHIPMENT_CLASS__STANDARD,
                status_id        => $SHIPMENT_STATUS__PROCESSING,
                comment          => "",
                date             => $order_data->{order_date},
                pack_instruction => "",
                gift_message     => "",
                gift             => "false",
                email            => $order_data->{email},
                telephone        => $order_data->{telephone},
                mobile_telephone => $order_data->{mobile_telephone},
                home_telephone   => "",
                work_telephone   => "",
                address          => undef,
                signature_required => $order_data->{signature_required},
            };
            my $shipment_address    = ();
            my $item_data           = ();

            # flag to set if no physical vouchers or
            # normal products in the 'DELIVERY_DETAILS' section
            my $virtual_voucher_only_order  = 1;
            # flag to indicate if there are any virtual vouchers
            my $any_virtual_vouchers        = 0;


            # process 'DELIVERY_DETAILS' first
            foreach my $shipment ($order->findnodes('DELIVERY_DETAILS')) {

                # un-set this flag as we have something
                $virtual_voucher_only_order = 0;

                $shipment_data->{gift_message}     = $shipment->findvalue('GIFT_MESSAGE');

                # Premier Routing is for both DC's now (CANDO-78)
                # Premier Routing changed in FLEX-250 to be deduced
                # from the Shipping Charge. Not fixed here since it's
                # the old Order Importer. This whole file should go.
                $shipment_data->{premier_routing_id}
                    = $order_data->{premier_routing_id};

                if ($shipment_data->{gift_message}) {
                    $shipment_data->{gift} = "true";
                }
                else {
                    $shipment_data->{gift} = "false";
                }


                # get telephone numbers from delivery address
                $shipment_data = Catalyst::Utils::merge_hashes(
                    $shipment_data,
                    extract_telephone($order,'DELIVERY_DETAILS/CONTACT_DETAILS')
                );


                # FIX IN CASE DELIVERY DOESN'T HAVE CONTACT DETAILS
                if ($shipment_data->{email} eq "") {
                    $shipment_data->{email} = $order_data->{email};
                }

                if (
                       defined $shipment_data->{telephone}
                    && $shipment_data->{telephone} eq ""
                ) {
                    $shipment_data->{telephone} = $order_data->{telephone};
                }
                # make sure we have a value for the telephone number, even if
                # it's an empty string
                if (not defined $shipment_data->{telephone}) {
                    $shipment_data->{telephone} = '';
                }

                if ($shipment_data->{mobile_telephone} eq "") {
                    $shipment_data->{mobile_telephone} = $order_data->{mobile_telephone};
                }

                # get shipping address
                $shipment_address->{first_name}     = $shipment->findvalue('NAME/FIRST_NAME');
                $shipment_address->{last_name}      = $shipment->findvalue('NAME/LAST_NAME');
                $shipment_address->{address_line_1} = $shipment->findvalue('ADDRESS/ADDRESS_LINE_1');
                $shipment_address->{address_line_2} = $shipment->findvalue('ADDRESS/ADDRESS_LINE_2');
                $shipment_address->{address_line_3} = "";
                $shipment_address->{towncity}       = $shipment->findvalue('ADDRESS/TOWNCITY');
                $shipment_address->{postcode}       = $shipment->findvalue('ADDRESS/POSTCODE');
                $shipment_address->{country}        = _get_country_by_code($dbh, $shipment->findvalue('ADDRESS/COUNTRY'));

                ## This is required later
                if (defined($shipment_address->{country}) && $shipment_address->{country} ne '') {
                    $order_data->{shipment_country} = $shipment_address->{country}
                }

                # DC specific fields
                # Don't worry - this is in the parser!
                if ( $DC eq 'DC2' ) {
                    $shipment_address->{county}
                        = $shipment->findvalue('ADDRESS/STATE');
                }
                else {
                    $shipment_address->{county}
                        = $shipment->findvalue('ADDRESS/COUNTY');
                }
                # push shipping address into fraud check hash
                $fraud_data->{"Address"}{"Name"}            .= ' '.$shipment_address->{first_name} ." ".$shipment_address->{last_name};
                $fraud_data->{"Address"}{"Street Address"}  .= ' '.$shipment_address->{address_line_1};
                $fraud_data->{"Address"}{"Street Address"}  .= ' '.$shipment_address->{address_line_2};
                $fraud_data->{"Address"}{"Town/City"}       .= ' '.$shipment_address->{towncity};
                $fraud_data->{"Address"}{"County/State"}    .= ' '.$shipment_address->{county};
                $fraud_data->{"Address"}{"Postcode/Zipcode"}.= ' '.$shipment_address->{postcode};
                $fraud_data->{"Address"}{"Country"}         .= ' '.$shipment_address->{country};

                $shipment_data->{address} = $shipment_address;

                # work out shipment type (Premier, Domestic, International etc..)
                $shipment_data->{type_id}   = get_country_shipment_type( $dbh, $shipment_address->{country}, $order_data->{channel_id} );

                # packaging skus to be ignored
                my %packing_options =  $schema->resultset('Public::PackagingType')->hash();

                # process each normal item in the shipment
                foreach my $item ($shipment->findnodes('ORDER_LINE')) {

                    # item id
                    my $id = $item->findvalue('@OL_ID');

                    # check if a shipping sku
                    my $shipping_charge_data = get_shipping_charge_data(
                        $dbh,
                        { "type" => "sku",
                          "value" => $item->findvalue('@SKU')
                        }
                    );

                    # matched shipping sku
                    if ( $shipping_charge_data ) {
                        # set shipping charge and charge_id
                        $shipment_data->{shipping_charge_id} = $shipping_charge_data->{id};
                        $shipment_data->{shipping_class}     = $shipping_charge_data->{class};
                        $shipment_data->{shipping_charge}    = $item->findvalue('UNIT_NET_PRICE/VALUE')
                                                             + $item->findvalue('TAX/VALUE')
                                                             + $item->findvalue('DUTIES/VALUE');

                        # add shipping to shipment total
                        $shipment_data->{shipment_total} += $shipment_data->{shipping_charge};

                        # check for premier shipping - update shipment type
                        if ( $shipping_charge_data->{class} eq "Same Day" ) {
                            $shipment_data->{type_id} = $SHIPMENT_TYPE__PREMIER;#2;  # Premier
                            $premier_order = 1;
                        }
                    }
                    # packing option skus
                    elsif ($packing_options{$item->findvalue('@SKU')}) {

                        # set packing instruction
                        $shipment_data->{pack_instruction} = $item->findvalue('@DESCRIPTION');

                    }
                    # remaining items are stock
                    else {

                        # gather item data
                        $item_data->{$id}{description} = $item->findvalue('@DESCRIPTION');
                        $item_data->{$id}{sku}         = $item->findvalue('@SKU');
                        $item_data->{$id}{quantity}    = $item->findvalue('@QUANTITY');

                        $item_data->{$id}{unit_price}  = $item->findvalue('UNIT_NET_PRICE/VALUE');
                        $item_data->{$id}{tax}         = $item->findvalue('TAX/VALUE');
                        $item_data->{$id}{duty}        = $item->findvalue('DUTIES/VALUE');

                        $item_data->{$id}{status_id}   = $SHIPMENT_ITEM_STATUS__NEW;#1; # default status to 'new'
                        foreach my $key (qw/value unit_price tax duty/) {
                            $item_data->{$id}->{promo}->{$key} = 0;
                        }

                        # By default all items are returnable (except Gift Vouchers). Some promos (GGG) might set this to false.
                        $item_data->{$id}{returnable_state_id}        = $SHIPMENT_ITEM_RETURNABLE_STATE__YES;

                        ($item_data->{$id}{product_id}, $item_data->{$id}{size_id}) = split(/-/, $item_data->{$id}{sku});

#FIXME preprocess_shipment -> _preprocess_cost_reduction
                        # check for promotion discounts on item

                        # loop through each promo
                        foreach my $promo_id ( keys %{$promotion_data} ) {

                            # If this promo controls returnable status, check it
                            # FIXME: This is preprocess because it influences the list_item ability to be returned!
                            my $returnable_hash = $promotion_data->{ $promo_id }{returnable} || {};
                            if (exists $returnable_hash->{$id} ) {
                              $item_data->{$id}{returnable_state_id} = $returnable_hash->{$id};
                              $logger->info("NOT RETURNABLE");
                            }

                            # check for a percentage discount set
                            # FIXME This was the old way of doing stuff! MAYBE JUST DELETE IT! from HERE YYY
                            if ( defined($promotion_data->{ $promo_id }{percentage_discount}) ) {

                                # loop through applicable items
                                my $items = $promotion_data->{ $promo_id }{items};
                                if (exists $items->{$id}) {
                                    my $promotion_discount = $promotion_data->{$promo_id}{percentage_discount};

                                    my $unit_discount = $item_data->{$id}{unit_price} * $percentage_discount;
                                    my $tax_discount  = $item_data->{$id}{tax} * $percentage_discount;
                                    my $duty_discount = $item_data->{$id}{duty} * $percentage_discount;

                                    $item_data->{$id}{unit_price}         = $item_data->{$id}{unit_price} - $unit_discount;
                                    $item_data->{$id}{tax}                = $item_data->{$id}{tax} - $tax_discount;
                                    $item_data->{$id}{duty}               = $item_data->{$id}{duty} - $duty_discount;

                                    $item_data->{$id}{promo}{applied}     = 1;
                                    $item_data->{$id}{promo}{id}          = $promo_id;
                                    $item_data->{$id}{promo}{description} = $promotion_data->{ $promo_id }{description};

#FIXME This needn't be a += because we get at most 1 discount for an item.
                                    $item_data->{$id}{promo}{value}       += ($unit_discount + $tax_discount + $duty_discount);
                                    $item_data->{$id}{promo}{unit_price}  += $unit_discount;
                                    $item_data->{$id}{promo}{tax}         += $tax_discount;
                                    $item_data->{$id}{promo}{duty}        += $duty_discount;

                                    $logger->info("ITEM DISCOUNT: " . $promotion_data->{ $promo_id }{percentage_discount} ." - "
                                        . " UNIT: $unit_discount"
                                        . " TAX: $tax_discount"
                                        . " DUTY: $duty_discount");
                                }
                            } # to here YYY
                            # check for a percentage removed set
                            elsif ( defined($promotion_data->{ $promo_id }{percentage_removed}) ) {

                                # match item
                                my $items = $promotion_data->{ $promo_id }{items};
                                if (exists $items->{$id}) {

                                    my $unit_discount = $promotion_data->{ $promo_id }{discounts}{ $id }{unit_price};
                                    my $tax_discount  = $promotion_data->{ $promo_id }{discounts}{ $id }{tax};
                                    my $duty_discount = $promotion_data->{ $promo_id }{discounts}{ $id }{duty};

                                    $item_data->{$id}{promo}{applied}       = 1;
                                    $item_data->{$id}{promo}{id}            = $promo_id;
                                    $item_data->{$id}{promo}{description}   = $promotion_data->{ $promo_id }{description};

#FIXME This needn't be a += because we get at most 1 discount for an item.
                                    $item_data->{$id}{promo}{value}         += ($unit_discount + $tax_discount + $duty_discount);
                                    $item_data->{$id}{promo}{unit_price}    += $unit_discount;
                                    $item_data->{$id}{promo}{tax}           += $tax_discount;
                                    $item_data->{$id}{promo}{duty}          += $duty_discount;

                                    $promotion_data->{ $promo_id
                                    }{percentage_discount} ||= 0;
                                    $logger->info("ITEM DISCOUNT: $promotion_data->{ $promo_id }{percentage_discount} - "
                                        . " UNIT: $unit_discount"
                                        . " TAX: $tax_discount"
                                        . " DUTY: $duty_discount");
                                }
                            }
                        }
#XXX preprocess_shipment -> _preprocess_cost_reduction

#FIXME preprocess_shipment

                        # add item totals to the shipment total
                        $shipment_data->{shipment_total}
                            += (
                                $item_data->{$id}{unit_price}
                              + $item_data->{$id}{tax}
                              + $item_data->{$id}{duty}
                            )
                            * $item_data->{$id}{quantity};

                        $logger->info("SKU: ".$item_data->{$id}{sku}."\n"
                            . "PRICE: ".$item_data->{$id}{unit_price}."\n"
                            . "TAX: ".$item_data->{$id}{tax}."\n"
                            . "DUTY: ".$item_data->{$id}{duty});


                        # get the variant id for the SKU
                        $item_data->{$id}{variant_id} = get_variant_by_sku($dbh, $item_data->{$id}{sku});

                        ### get variant id
                        if ((not defined $item_data->{$id}{variant_id}) or ($item_data->{$id}{variant_id} == 0)) {
                            my $tmpval = defined($item_data->{$id}{variant_id})
                                ? $item_data->{$id}{variant_id}
                                : '[undefined]'
                            ;
                            die "COULD NOT FIND VARIANT ID ($tmpval) for SKU $item_data->{$id}{sku}\n\n";
                        }
                        else {
                            $logger->info("GOT VARIANT ID: ".$item_data->{$id}{variant_id});
                        }

                        # check gift message against line item
                        $item_data->{$id}{gift_message} = $item->findvalue('GIFT_MESSAGE');

                        # FIXME preprocess! Andrew/Jason This is per-shipment
                        # set gift status and message on shipment
                        if ($item_data->{$id}{gift_message}) {
                            $shipment_data->{gift} = "true";
                            $shipment_data->{gift_message} = $item_data->{$id}{gift_message};
                        }
                    }
                }

                # process any Physical Voucher items
                foreach my $item ( $shipment->findnodes('ORDER_LINE_PHYSICAL_VOUCHER') ) {

                    # item id
                    my $id = $item->findvalue('@OL_ID');

                    # get the voucher info out of the line
                    my $item_info   = _extract_voucher_order_line( $schema, $item, \$shipment_data->{shipment_total} );
                    $item_data->{$id}       = $item_info;
                    # make physical voucher orders a Gift
                    $shipment_data->{gift}  = 'true';
                }

            } # process 'DELIVERY_DETAILS'

            # process 'VIRTUAL_DELIVERY_DETAILS' second
            foreach my $shipment ($order->findnodes('VIRTUAL_DELIVERY_DETAILS')) {

                # if there hasn't been any other products bought and there are currently
                # no shipment items (meaning we haven't added any V.Vouchers yet)
                # set-up a few defaults for when the shipment gets created
                if ( $virtual_voucher_only_order && !scalar( keys %{ $item_data } ) ) {
                    $shipment_address   = { %{ $bill_address } };   # use billing address as shipping address
                    delete $shipment_address->{hash};               # the 'hash' isn't there usually so get rid of it
                    $shipment_data->{address}   = $shipment_address;

                    # get the shipment type
                    $shipment_data->{type_id}   = get_country_shipment_type( $dbh, $shipment_address->{country}, $order_data->{channel_id} );

                    $shipment_data->{shipping_charge}   = 0;        # No Shipping Charge for Virtual Vouchers
                    $shipment_data->{shipment_charge_id}= 0;        # Specify 'Unknown' Shipment Charge Id

                    # get the Shipping Account Id which is for
                    # an Unknown Carrier for the Order's Channel
                    my $ship_acc    = $schema->resultset('Public::ShippingAccount')
                                                ->search( {
                                                            carrier_id => $CARRIER__UNKNOWN,
                                                            channel_id => $order_data->{channel_id},
                                                        } )->first;
                    $shipment_data->{shipping_account_id}   = $ship_acc->id;
                }

                # process Virtual Voucher items
                foreach my $item ( $shipment->findnodes('ORDER_LINE_VIRTUAL_VOUCHER') ) {

                    # item id
                    my $id = $item->findvalue('@OL_ID');

                    # get the voucher info out of the line
                    my $item_info   = _extract_voucher_order_line( $schema, $item, \$shipment_data->{shipment_total} );
                    $item_data->{$id}   = $item_info;
                    # make virtual voucher orders a Gift
                    $shipment_data->{gift}  = 'true';
                    # set flag to indicate we have some virtual vouchers
                    $any_virtual_vouchers   = 1;
                }

            } # process 'VIRTUAL_DELIVERY_DETAILS'


            # finally check for a free shipping promo and adjust shipping charge

            # loop through each promo
            foreach my $promo_id ( keys %{$promotion_data} ) {

                # check for a free shipping discount
                if ( $promotion_data->{ $promo_id }{shipping} ) {

                    $logger->info("SHIPPING DISCOUNT: ".$promotion_data->{ $promo_id }{shipping});

                    # quick sanity check
                    #if ( $promotion_data->{ $promo_id }{shipping} > $shipment_data->{shipping_charge} ) {
                    #    die "Free Shipping value ($promotion_data->{ $promo_id }{shipping}) greater than shipping charge ($shipment_data->{shipping_charge})\n";
                    #}

                    # shipping discount less than shipping charge - may be a mis-calculation - send warning email
                    if ( $promotion_data->{ $promo_id }{shipping} < $shipment_data->{shipping_charge} ) {
                        send_email(
                            "servicedesk\@net-a-porter.com",
                            "Shipping Discount Error",
                            "\nOrder ID: ".$order_id."\n"
                          . "Discount: ".$promotion_data->{ $promo_id }{shipping}."\n"
                          . "Shipping: ".$shipment_data->{shipping_charge}."\n\n"
                        );
                        $promotion_data->{ $promo_id }{shipping} = $shipment_data->{shipping_charge}
                    }

                    $shipment_data->{shipping_charge} -= $promotion_data->{ $promo_id }{shipping};
                    $shipment_data->{shipment_total}  -= $promotion_data->{ $promo_id }{shipping};
                }
            }

            # quick check for missing shipping SKU in import file
            if ( $shipment_data->{shipping_charge} eq "" ) {

                # send warning email
                send_email("servicedesk\@net-a-porter.com", "Missing Shipping SKU", "\nOrder ID: ".$order_id."\n\nHave a nice day,\nxTracker");

                # DC specific shipping charges
                if ( $DC eq 'DC2' ) {
                    ### set charge to 0 and work out shipment type
                    $shipment_data->{shipping_charge_id} = 0;
                    $shipment_data->{shipping_charge} = 0;

                    ### Premier
                    if ( $shipment_address->{county} eq "NY" ){
                        $shipment_data->{type_id} = $SHIPMENT_TYPE__PREMIER;#2;
                    }
                    ### US
                    elsif ( $shipment_address->{country} eq "United States" ){
                        $shipment_data->{type_id} = $SHIPMENT_TYPE__DOMESTIC;#3;
                    }
                    else {
                        $shipment_data->{type_id} = $SHIPMENT_TYPE__INTERNATIONAL;#4;
                    }
                }
                else { # Default to DC1 behaviour
                    # default charge to 0 and type to 2 (Premier)
                    $shipment_data->{shipping_charge} = 0;
                    $shipment_data->{type_id} = $SHIPMENT_TYPE__PREMIER;#2;
                }
            }

            # If the Customer is 'Staff' then change shipment type to being 'PREMIER'
            # if Order's Sales Channel Matches
            if ( _get_customer_category( $dbh, $order_data->{customer_id} ) eq 'Staff' ) {
                my $order_rec   = $schema->resultset('Public::Orders')->find( $orders_id );
                if ( is_staff_order_premier_channel( $order_rec->order_channel->business->config_section ) ) {
                    $shipment_data->{type_id}   = $SHIPMENT_TYPE__PREMIER;
                }
            }

            # debugging
            $logger->info("SHIPMENT COUNTRY: ".$shipment_address->{country});
            $logger->info("SHIPMENT TYPE: ".$shipment_data->{type_id});
            $logger->info("SHIPPING CHARGE: ".$shipment_data->{shipping_charge});
            $logger->info("SHIPMENT TOTAL: ".$shipment_data->{shipment_total});

            # work out store and gift credit value for shipment
            if ($order_data->{store_credit} < 0) {

                if ($shipment_data->{shipment_total} > ($order_data->{store_credit} * -1)) {
                    $shipment_data->{store_credit} = $order_data->{store_credit};
                }
                else {
                    $shipment_data->{store_credit} = $shipment_data->{shipment_total} * -1;
                }

                $order_data->{store_credit} -= $shipment_data->{store_credit};
                $shipment_data->{shipment_total} += $shipment_data->{store_credit};
            }
            else {
                $shipment_data->{store_credit} = 0;
            }

            if ($order_data->{gift_credit} < 0) {
                if ($shipment_data->{shipment_total} > ($order_data->{gift_credit} * -1)) {
                    $shipment_data->{gift_credit} = $order_data->{gift_credit};
                }
                else {
                    $shipment_data->{gift_credit} = $shipment_data->{shipment_total} * -1;
                }

                $order_data->{gift_credit} -= $shipment_data->{gift_credit};
                $shipment_data->{shipment_total} += $shipment_data->{gift_credit};
            }
            else {
                $shipment_data->{gift_credit} = 0;
            }

            if ( $order_data->{voucher_credit} < 0 ) {
                $shipment_data->{shipment_total} += $order_data->{voucher_credit};
            }

            $logger->info("GIFT CREDIT: ".$shipment_data->{gift_credit});
            $logger->info("STORE CREDIT: ".$shipment_data->{store_credit});
            $logger->info("FINAL SHIPMENT TOTAL: ".$shipment_data->{shipment_total});

            $order_data->{final_calculated_total} += $shipment_data->{shipment_total};

            # if the order is for more than just Virtual Vouchers then need
            # to get Shipping Account Id, else this has already been set above
            if ( !$virtual_voucher_only_order ) {
                # get shipping account id
                $shipment_data->{shipping_account_id}
                    = get_shipment_shipping_account(
                        $dbh,
                        { channel_id          => $order_data->{channel_id},
                          shipment_type_id    => $shipment_data->{type_id},
                          country             => $shipment_address->{country},
                          postcode            => $shipment_address->{postcode},
                          item_data           => $item_data,
                          shipping_class      => $shipment_data->{shipping_class},
                        }
                );
            }

            # TODO: This table is not in the Constants::FromDB - need to
            # investigate if this should be there and if so, add it and
            # use a named constant here
            if ($shipment_data->{shipping_account_id} == 3) {
                $ftbc_order = 1;
            }

            # SECTION: CREATE SHIPMENT
            my $shipment_id = create_shipment($dbh, $orders_id, "order", $shipment_data);
            $order_data->{shipments}{$shipment_id} = 1;
            my $shipment = $schema->resultset('Public::Shipment')->search({id=>$shipment_id})->single;

            # SECTION: SHIPMENT PROMOTION
            foreach my $promo_id ( keys %{$promotion_data} ) {

                # check for a free shipping discount
                if ( $promotion_data->{ $promo_id }{shipping} ) {
                    _link_shipment_promotion(
                        $dbh,
                        $shipment_id,
                        $promotion_data->{ $promo_id }{description},
                        $promotion_data->{ $promo_id }{shipping}
                    );
                }
            }

            # DDU Flags
            my $auto_ddu = $schema->resultset('Public::Country')->find( { country => $shipment_address->{country} } )->country_shipment_types()->find( { channel_id => $order_data->{channel_id} } )->auto_ddu() // 0;
            if( ( $shipment_data->{type_id} == $SHIPMENT_TYPE__INTERNATIONAL_DDU ) && ( $auto_ddu == 0 ) && ( get_customer_ddu_authorised( $dbh, $order_data->{customer_id} ) == 0 ) ) {
                update_shipment_status( $dbh, $shipment_id, $SHIPMENT_STATUS__DDU_HOLD, $APPLICATION_OPERATOR_ID );
                set_shipment_flag( $dbh, $shipment_id, $FLAG__DDU_PENDING );
            }

# MOVED: _apply_credit_rating
            # Credit Check flags - shipping address different to invoice adderss and not in database yet
            if (_check_shipping_address($dbh, $shipment_id) == 1) {
                set_order_flag($dbh, $orders_id, $FLAG__ADDRESS);# was 5);
                $order_data->{'credit_rating'}--;
                $order_data->{'address_match'} = 0;
            }
# END

            # flag to store pre-order status
            my $pre_order = 0;


            # SECTION: SHIPMENT ITEMS
            # loop through items
            foreach my $id (keys %{$item_data}) {

                for my $i (1 .. $item_data->{$id}{quantity}) {

                    # check for special order on SKU
                    $item_data->{$id}{reservation_id} = get_uploaded_reservation_by_sku($dbh, $order_data->{customer_id}, $item_data->{$id}{variant_id});

                    if ($item_data->{$id}{reservation_id} > 0) {

                        set_reservation_purchased($dbh, $item_data->{$id}{reservation_id}, $item_data->{$id}{variant_id});

                        $item_data->{$id}{special_order} = "true";

                        $logger->info("GOT RESERVATION!");
                    }
                    else {
                        $item_data->{$id}{special_order} = "false";
                    }

                    # create shipment item record - pass 'OL_ID' to store on 'shipment_item' row which was a change for Gift Vouchers
                    my $ship_item_id = create_shipment_item( $dbh, $shipment_id, { pws_ol_id => $id, %{ $item_data->{$id} } } );

                    my $var_id;
                    my $upd_pws_stock   = 1;

## FIXME This is the cost_reduction saving bit!!
                    # only need to do this if item is not a Gift Voucher
                    if ( !$item_data->{$id}{voucher_variant_id} ) {
                        $var_id = $item_data->{$id}{variant_id};
                        # create promotion links - if required
                        if (
                               defined $item_data->{$id}{promo}{applied}
                            && $item_data->{$id}{promo}{applied} == 1
                        ) {
                            _link_shipment_item_promotion(
                                $dbh,
                                $ship_item_id,
                                $item_data->{$id}{promo}{description},
                                $item_data->{$id}{promo}{unit_price},
                                $item_data->{$id}{promo}{tax},
                                $item_data->{$id}{promo}{duty}
                            );
                        }
                    }
                    else {
                        $var_id = $item_data->{$id}{voucher_variant_id};
                        # Virtual Vouchers don't have any stock to update
                        $upd_pws_stock  = $item_data->{$id}{is_physical};
                    }

                    if ( $upd_pws_stock ) {
                        # log a -1 in the pws log
                        $schema->resultset('Public::LogPwsStock')->log_stock_change(
                            variant_id      => $var_id,
                            channel_id      => $order_data->{channel_id},
                            pws_action_id   => $PWS_ACTION__ORDER,
                            quantity        => -1,
                            notes           => $shipment_id,
                        );
                    }
                }


                # check for pre-order products
                ##############################

                if ( check_product_preorder_status( $dbh, {'type' => 'variant', 'id' => $item_data->{$id}{variant_id}} ) ) {
                    $pre_order = 1;
                }

            }
            # Finished creating shipment items

# XXX preprocess_shipment

# FIXME assign_carrier
            # GV-395: Needed to move check after items have been created
            my $carrier = NAP::Carrier->new({schema => $schema, shipment_id => $shipment_id, operator_id => $APPLICATION_OPERATOR_ID});
            if (not defined $carrier->carrier) {
                # argh - we don't have a carrier for the shipment?!
                # $carrier->force_dhl_doodah_for_the_address;
                $carrier->set_address_validator('DHL');
            }
            $carrier->validate_address( { context_is => 'order_importer' } );

            # check for restricted items in order
            check_shipment_restrictions( $schema, { shipment_id => $shipment_id, send_email => 1 } );

# XXX assign_carrier

#FIXME preprocess_shipment
            # place shipment on pre-order hold and flag if required
            if ($pre_order == 1) {

                $logger->info("PRE-ORDER!!!!!!!!!");

                update_shipment_status($dbh, $shipment_id, $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD, $APPLICATION_OPERATOR_ID);

                set_shipment_flag($dbh, $shipment_id, $FLAG__PRE_DASH_ORDER);
                set_order_flag($dbh, $orders_id, $FLAG__PRE_DASH_ORDER);
            }

            # Implementation of SLAs at end of creation of order
            $shipment->apply_SLAs;

            # Update order to have sticker value
            $shipment->order->update({sticker=>$order_data->{sticker}});

            #
            # END SHIPMENT SECTION
            #
#XXX preprocess_shipment

# FIXME check_integrity
            # integrity check of calculated order total vs. card payment value
            if ($order_data->{transaction_value} > 0) {

                my $difference = $order_data->{final_calculated_total} - $order_data->{transaction_value};

                if ( $difference > 1 || $difference < -1 ) {
                    $logger->debug("PAYMENT vs. ORDER TOTAL MISMATCH!!!!!!!!");

                    send_email(
                        "xtrequests\@net-a-porter.com",
                        "Order Import Error",
                        "\nPayment mismatch for Order Nr:"
                      . $order_data->{order_nr}
                      . "\n\nPAYMENT VALUE: "
                      . $order_data->{transaction_value}
                      . "\nCALCULATED VALUE: "
                      . $order_data->{final_calculated_total}
                      . "\n\nHave a nice day,\nxTracker"
                    );
                }
            }
# XXX check_integrity

# MOVED: _apply_credit_rating
            # SECTION: CREDIT CHECKING
            _credit_check_order( $dbh, $orders_id, $order_data, $fraud_data, $schema );

            # check to see if Delivery Signature should put the Order on Hold (CANDO-216)
            if ( !$shipment->discard_changes->is_signature_required
                 && $shipment->order->should_put_onhold_for_signature_optout( $shipment ) ) {
                # now change 'credit_rating' to be less than zero
                # and add an appropriate flag to the Order
                $order_data->{'credit_rating'}  = -1;
                $shipment->order->add_flag_once( $FLAG__DELIVERY_SIGNATURE_OPT_OUT );
            }

            # customer failed credit checks - place order on hold
            if ($order_data->{'credit_rating'} < 1) {

                # PUT ORDER ON CREDIT HOLD
                update_order_status($dbh, $orders_id, $ORDER_STATUS__CREDIT_HOLD);
                log_order_status($dbh, $orders_id, $ORDER_STATUS__CREDIT_HOLD, $APPLICATION_OPERATOR_ID);

                # PUT SHIPMENTS ON FINANCE HOLD
                foreach my $ship_id ( keys %{$order_data->{shipments}} ) {
                    update_shipment_status($dbh, $ship_id, $SHIPMENT_STATUS__FINANCE_HOLD, $APPLICATION_OPERATOR_ID);
                }

# END
            }
            # customer passed credit checks - you're free to go
            else {
                ##### ORDER ACCEPTED
                log_order_status($dbh, $orders_id, $ORDER_STATUS__ACCEPTED, $APPLICATION_OPERATOR_ID);
            }

# FIXME do_channel_specific_modifications
            if (defined $plugin) {
                $plugin->call('shipment_modifier',$shipment);
            }
# XXX do_channel_specific_modifications


            # discard_changes: because we've been doing some dbh up til now,
            # update the DBIx::Class $shipment object
            # to whatever has been stored using the $dbh
            $shipment->discard_changes;
            if (!$shipment->is_on_hold) {
                local $@;
                eval {
                    $shipment->hold_if_invalid({
                        operator_id => $APPLICATION_OPERATOR_ID,
                    });
                };
                $logger->warn($@) if $@;
            }

            $dbh->commit() unless $skip_commit;

            # FIXME: an order comes in from a channel, only need to commit on
            # FIXME: the one webdb
            foreach my $channel_id ( keys %{$channels}) {
                if($dbh_web && !$skip_commit){
                    $dbh_web->{$channel_id}->commit();
                }
            }

#FIXME order_virtual_voucher_codes
#FIXME SCARY this is inside a transaction  - what happens if the AMQ response
#FIXME arrives before the end of the transaction? (Unlikely, I know, but...)
            # if there were any virtual vouchers for this order then we need
            # to ask Fulcrum for some Virtual Voucher Codes
            if ( $any_virtual_vouchers ) {
                $shipment->discard_changes;
                $amq->transform_and_send( 'XT::DC::Messaging::Producer::Order::VirtualVoucherCode', $shipment );
            }
#XXX order_virtual_voucher_codes

        }; # End of eval
        my $e = $@;

        ## if db update not successful output error message
        if($e){
            $dbh->rollback();

            foreach my $channel_id ( keys %{$channels}) {
                if($dbh_web){
                    $dbh_web->{$channel_id}->rollback();
                }
            }

            $logger->error("error - $e\n");

            send_email("xtrequests\@net-a-porter.com", "Order Import Error", "\nOrder ID: ".$order_id."\n\nError: ".$e."\n\nHave a nice day,\nxTracker");
            send_email("servicedesk\@net-a-porter.com", "Order Import Error", "\nOrder ID: ".$order_id."\n\nError: ".$e."\n\nHave a nice day,\nxTracker");

            $import_error = $e;
        }

        ## db update OK
        else {
             $logger->info("orders imported successfully");
        }

#FIXME add_promotion_packs
        eval {
            # Add a promotion pack if relevant
            # SECTION: PROMOTION PACK
            my $rs_order = $schema->resultset('Public::Orders')->find($orders_id);
            XTracker::Promotion::Pack->check_promotions(
                $schema, $rs_order, $plugin ) if defined($rs_order);

            $schema->storage->dbh->commit() unless $skip_commit;
        }; #eval
        $e = $@;
        if($e){
            $import_error=$e;
            $dbh->rollback();
            $logger->error("promotion pack error - $e");
            send_email("xtrequests\@net-a-porter.com", "Order Import Promotion Pack Error", "\nOrder ID: ".$order_id."\n\nError: ".$e."\n\nHave a nice day,\nxTracker");
            send_email("servicedesk\@net-a-porter.com", "Order Import Error", "\nOrder ID: ".$order_id."\n\nError: ".$e."\n\nHave a nice day,\nxTracker");
        }
    }
#XXX

    return $import_error;
}

sub archive {
    my ($file, $proc, $waiting) = @_;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);

    my $dir = ($year + 1900).($mon+1).$mday;

    unless( -d "$proc/$dir" ){
        mkdir("$proc/$dir");
    }

    my $from_file = "$waiting/$file";
    my $to_file = "$proc/$dir/$file";

    move($from_file, $to_file) || die "can't move $file: $! $to_file";
}

sub send_email {
    my ($to, $subject, $msg) = @_;

    # if the config doesn't say to send email ... don't
    my $send_email = config_var('Email', 'send_email');
    if (not defined $send_email) {
        $logger->warn("send_email is not defined in [Email] section of application configuration");
        return;
    }
    if ('yes' ne $send_email) {
        if ($ENV{VERBOSE}) {
            $logger->warn("email sending is disabled");
        }
        return;
    }

    my %mail = ( To      => $to,
                 From    => "order_import\@net-a-porter.com",
                 Subject => "$subject",
                 Message => "$msg",
    );

    unless( sendmail(%mail) ){ $logger->warn("no mail: $!"); }

}


sub _credit_check_order {

    my ($dbh, $orders_id, $order_data, $fraud_data, $schema) = @_;

    # build up an array of customer accounts to check against
    my @customer_accounts;

    # first push account used on this order into there
    push(@customer_accounts, $order_data->{customer_id});

    # now get any matched accounts
    my $matched_customers = match_customer($dbh, $order_data->{customer_id});

    foreach my $matched_customer_id ( @$matched_customers ) {
        push(@customer_accounts, $matched_customer_id);
    }


    # get threshold settings from db
    my $channel_thresholds  = get_credit_hold_thresholds($dbh);
    my $thresholds          = $channel_thresholds->{ $order_data->{channel_id} };


    ### EIP & STAFF CHECK
    $order_data->{'customer_category'} = _get_customer_category($dbh, $order_data->{customer_id});

    if ($order_data->{customer_category} =~ /^(EIP|EIP Centurion|Carmen)$/i) {
        $order_data->{'credit_rating'} += 200;
        $logger->debug("EIP order, +200 points");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});

    }


    ### allow orders through matching following criteria
    ## card number begins with a 3,4 or 6
    ## AND CV2 response is ALL MATCH
    ## AND billing and shipping address are the same

    if (
         defined $order_data->{payment_info}{card_number}
      && $order_data->{payment_info}{card_number} =~ m/\b[3,4,6].+/
      && $order_data->{payment_info}{cv2avsStatus} eq "ALL MATCH"
      && $order_data->{'address_match'} == 1
    ){
        $order_data->{'credit_rating'} = $order_data->{'credit_rating'} + 150;
        $logger->debug("CV2 ALL MATCH order, +150 points");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
    }

    ## EN-1162
    ## Allow orders through with:
    ## Card number begins with 3,4,5, or 6
    ## Matching billing and shipping address
    ## Order from 'low risk' country
    ## Order value <= country's low risk max order amount
    my $net_order_total = _total_order_value( $dbh, $order_data );
    if (
        defined $order_data->{payment_info}{card_number}
        && defined $order_data->{'shipment_country'}
        && $order_data->{payment_info}{card_number} =~ m/\b[3,4,5,6].+/
        && $order_data->{'address_match'} == 1
        && _shipping_country_risk( $schema, $order_data->{'shipment_country'} ) eq 'Low'
        && _low_risk_shipping_total(
            $schema,
            $order_data->{'shipment_country'},
            $net_order_total,
            $order_data->{'channel_id'}
        )
    ) {
        $logger->debug("Low risk order, +100 points");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
        $order_data->{'credit_rating'} = $order_data->{'credit_rating'} + 100;
    }
    #$logger->info(pp $order_data);

    ### Fraud Hotlist checks
    ###################################################

    # get hotlist
    my $hotlist = get_hotlist($dbh);

    # hotlist flag mapping
    my %hotlist_flag = (
        "Card Number"      => $FLAG__FRAUD_CREDIT_CARD,
        "Street Address"   => $FLAG__FRAUD_ADDRESS,
        "Town/City"        => $FLAG__FRAUD_ADDRESS,
        "County/State"     => $FLAG__FRAUD_ADDRESS,
        "Postcode/Zipcode" => $FLAG__FRAUD_POSTCODE,
        "Country"          => $FLAG__FRAUD_COUNTRY,
        "Email"            => $FLAG__FRAUD_EMAIL,
        "Telephone"        => $FLAG__FRAUD_TELEPHONE,
    );

    # loop through hotlist and check against order data
    foreach my $hotlist_id ( keys %{ $hotlist } ) {
        if (not exists $hotlist->{$hotlist_id}) {
            #print "NO HOTLIST VALUE FOR $hotlist_id\n";
            next;
        }
        # type, field and value of hotlist entry
        my $type  = $hotlist->{ $hotlist_id }{type};
        my $field = $hotlist->{ $hotlist_id }{field};
        my $value = $hotlist->{ $hotlist_id }{value};

        ### check against corresponding field from order
        if ($fraud_data->{ $type }{ $field } =~ m/\b\Q$value\E/i) {
            # set order flag
            set_order_flag( $dbh, $orders_id, $hotlist_flag{ $field } );

            # decrement fraud score
            $order_data->{'credit_rating'} = $order_data->{'credit_rating'} - 500;
            $logger->debug("Fraud hotlist! [$field: $value], -500 points");
            $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
        }
    }

    ## if on financial watch decrement credit score
    foreach my $customer_id ( @customer_accounts ) {
        my $c_flags = get_customer_flag($dbh, $customer_id);
        foreach my $flagid ( keys %{$c_flags} ) {
            if ( $c_flags->{$flagid}{flag_id} == 26 ) {
                $order_data->{'credit_rating'} = $order_data->{'credit_rating'} - 500;
                $logger->debug("Customer on financial watch list -50 points");
                $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
                set_order_flag($dbh, $orders_id, 26);
            }
        }
    }

    # get number of orders and total spend for customer
    # REL-909 - count for total order history, val for period
    my ($o_count_within_period, $customer_order_value) = _total_orders_within_period($dbh, \@customer_accounts);
    my ($o_count, $total_customer_order_value) = _total_orders($dbh, \@customer_accounts);

    # check if customer older than 6 months
    my $established_customer = _check_customer_age($dbh, \@customer_accounts);

    # check if customer has been credit checked
    my $checked = _get_customer_credit_check($dbh, \@customer_accounts);

    # flag all First orders

    my $first_order = 0;
    if ($o_count == 1) {
        set_order_flag($dbh, $orders_id, $FLAG__1ST);
        $order_data->{'credit_rating'} = $order_data->{'credit_rating'} - 110;
        $logger->debug("First order, -110 points");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
        $first_order = 1;

    }
    # 2nd order if not checked yet
    elsif ($o_count == 2 && !$checked) {
        set_order_flag($dbh, $orders_id, $FLAG__2ND);
        $order_data->{'credit_rating'} = $order_data->{'credit_rating'} - 120;
        $logger->debug("Second order, not checked -120 points");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
    }
    # 3rd order if not checked yet
    elsif ($o_count == 3 && !$checked) {
        set_order_flag($dbh, $orders_id, $FLAG__3RD);
        $order_data->{'credit_rating'} = $order_data->{'credit_rating'} - 130;
        $logger->debug("Third order, not checked -130 points");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
    }
    # customer not checked and shopping less than 6 months
    elsif (!$checked && !$established_customer) {
        set_order_flag($dbh, $orders_id, $FLAG__NO_CREDIT_CHECK);
        $order_data->{'credit_rating'} = $order_data->{'credit_rating'} - 3;
        $logger->debug("Customer not checked and less than 6 month histroy, -3 points");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});

    }

    # Check for existing CCheck orders
    if ( _ccheck_orders( $dbh, \@customer_accounts ) > 0 ) {
        set_order_flag($dbh, $orders_id, $FLAG__EXISTING_CCHECK);
        $order_data->{'credit_rating'} = $order_data->{'credit_rating'} - 500;
        $logger->debug("Customer has existing orders on credit check, -500 points");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
    }
    # Check for existing CHold orders
    if ( _chold_orders( $dbh, \@customer_accounts ) > 0 ) {
        set_order_flag($dbh, $orders_id, $FLAG__EXISTING_CHOLD);
        $order_data->{'credit_rating'} = $order_data->{'credit_rating'} - 500;
        $logger->debug("Customer has existing orders on credit hold, -500 points");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
    }
    # Commented out for EN-554/EN-562
    # Check for existing Cancelled orders
    # if ( _cancelled_orders( $dbh, \@customer_accounts ) > 0 ) {
    #     set_order_flag($dbh, $orders_id, $FLAG__HAS_CANCELLED_ORDERS);
    # }
    # Check total order value.
    my $order_value = _total_order_value($dbh, $order_data);

    if ($order_value > $thresholds->{'Single Order Value'} ) {
        set_order_flag($dbh, $orders_id, $FLAG__HIGH_VALUE);
        $order_data->{'credit_rating'} = $order_data->{'credit_rating'} - 75;
        $logger->debug("Total order value higher than threshold, -75 points");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});

    }
    # Check if customer has used this credit card before
    # DCS-1135 - Ignore FTBC transactions
    my $card_use_count = 0;
    for ( @{ $order_data->{payment_info}{cardHistory}{CardHistory} } ) {
        $card_use_count++ unless m{^ftbc-}xmsi;
    }

    # check if only store credit used = EN-282
    # somehow type gets changed to type_id - 1 is store credit but this should
    # be got more dynamically...
    my $non_store_credit = grep { !($_->{type_id} == 1) } @{$order_data->{tenders}};
    if ( ( $order_data->{payment_info}{cardHistory} && $card_use_count < 2) && $non_store_credit ) {
        set_order_flag($dbh, $orders_id, $FLAG__NEW_CARD);
        # EN-2051 - Don't take another -110 points off as we have already for being a new customer
        if (!$first_order) {
            $logger->debug("New payment card, -110 point");
            $logger->debug("credit_rating = $order_data->{credit_rating}");
            # REL-936
            $order_data->{'credit_rating'} -= 110;
        }
    }
    # Chold when customer has spent more than Total Order Value for the first time in 6 months
    if ( $customer_order_value >= $thresholds->{'Total Order Value'}
      && ($customer_order_value - $order_value) < $thresholds->{'Total Order Value'}
    ) {
        $logger->debug("- Total takes us over  " . $thresholds->{'Total Order Value'} . " for first time in last 6 months, -1 point");
        set_order_flag($dbh, $orders_id, $FLAG__TOTAL_ORDER_VALUE_LIMIT);
        --$order_data->{credit_rating};
        $logger->debug("credit_rating = $order_data->{credit_rating}");
    }

    # Check Weekly orders
    my ($w_count, $week_order_value) = _weekly_orders( $dbh, \@customer_accounts );
    if ($w_count) {
        # Customer has just spent more than Weekly Order Value in a week
        if ($week_order_value > $thresholds->{'Weekly Order Value'}) {
            $logger->debug("- Weekly total takes us over " . $thresholds->{'Weekly Order Value'}.", -1 point");
            set_order_flag($dbh, $orders_id, $FLAG__WEEKLY_ORDER_VALUE_LIMIT);
            --$order_data->{'credit_rating'};
            $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
        }
        # Customer has placed 5 or more orders in the week
        if ($w_count >= $thresholds->{'Weekly Order Count'}) {
            set_order_flag($dbh, $orders_id, $FLAG__WEEKLY_ORDER_COUNT_LIMIT);
            --$order_data->{'credit_rating'};
            $logger->debug("Customer placed more orders than the weekly order count thresold, -1 point");
            $logger->debug("credit_rating = " . $order_data->{'credit_rating'});

        }
    }

    # Check days orders
    my ($d_count, $day_order_value) = _daily_orders( $dbh, \@customer_accounts );
    # Customer has placed 3 or more orders today
    if ($d_count >= $thresholds->{'Daily Order Count'}) {
        set_order_flag($dbh, $orders_id, $FLAG__DAILY_ORDER_COUNT_LIMIT);
        --$order_data->{'credit_rating'};
        $logger->debug("Customer placed more orders than the daily order count thresold, -1 point");
        $logger->debug("credit_rating = " . $order_data->{'credit_rating'});
    }

    # CV2 Check Responses
    ## if {cv2avsStatus} isn't defined we don't need to do any of these checks
    if (defined $order_data->{payment_info}{cv2avsStatus}) {
        # Commented out for EN-554/EN-562
        #if ($order_data->{payment_info}{cv2avsStatus} eq "NO DATA MATCHES") {
        #    # Add CV2 - Failed flag
        #    set_order_flag($dbh, $orders_id, $FLAG__NO_DATA_MATCHES);
        #    --$order_data->{'credit_rating'};
        #}
        if ($order_data->{payment_info}{cv2avsStatus} eq "DATA NOT CHECKED") {
            set_order_flag($dbh, $orders_id, $FLAG__DATA_NOT_CHECKED);
        }
        if ($order_data->{payment_info}{cv2avsStatus} eq "SECURITY CODE MATCH ONLY") {
            # Add CV2 - Ok flag
            set_order_flag($dbh, $orders_id, $FLAG__SECURITY_CODE_MATCH);
        }
        if ($order_data->{payment_info}{cv2avsStatus} eq "ALL MATCH") {
            # Add ALL MATCH flag
            set_order_flag($dbh, $orders_id, $FLAG__ALL_MATCH);
        }
        if  ($order_data->{payment_info}{cv2avsStatus} eq "NONE") {
            set_order_flag($dbh, $orders_id, $FLAG__DATA_NOT_CHECKED);
        }
    }

    # customer has shopped across channels - info only flag
    if ( _check_multiple_channels( $dbh, \@customer_accounts ) > 1 ) {
        $logger->info("- Multi Channel Customer");
        set_order_flag($dbh, $orders_id, $FLAG__MULTI_CHANNEL_CUSTOMER);
    }
    return;
}

# BEGIN: migrated DBIx public.shipment
sub _check_shipping_address {
    my ($dbh, $shipment_id) = @_;

    # default flag to 0 - okay
    my $flag = 0;

    # compare billing and shipping address
    my $qry ="select o.invoice_address_id, s.shipment_address_id from orders o, link_orders__shipment los, shipment s where s.id = ? and s.id = los.shipment_id and los.orders_id = o.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        # billing and shipment address don't match - set flag to 1
        if ($row->[0] != $row->[1]){
            $flag = 1;
        }
    }

    # check if shipment address used for previous order
    $qry  = "SELECT count(*) FROM shipment WHERE shipment_address_id = (SELECT shipment_address_id FROM shipment WHERE id = ?) AND shipment_status_id != 5";
    $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        # shipment address used previously - unset flag
        if ($row->[0] > 1){
            $flag = 0;
        }
    }
    return $flag;
}
# END

sub _ccheck_orders {
    my ( $dbh, $customer_ref ) = @_;

    my $num_orders  = 0;
    my $customers   = join ',', @{$customer_ref};

    my $qry  = "SELECT count(*) FROM orders WHERE customer_id IN ($customers) AND order_status_id = 2";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $num_orders = $row->[0];
    }
    return $num_orders;
}

sub _chold_orders {
    my ( $dbh, $customer_ref ) = @_;

    my $num_orders  = 0;
    my $customers   = join ',', @{$customer_ref};

    my $qry  = "SELECT count(*) FROM orders WHERE customer_id IN ($customers) AND order_status_id = 1";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $num_orders = $row->[0];
    }
    return $num_orders;
}

sub _cancelled_orders {
    my ( $dbh, $customer_ref ) = @_;

    my $num_orders = 0;
    my $customers   = join ',', @{$customer_ref};

    my $qry  = "SELECT count(*) FROM orders WHERE customer_id IN ($customers) AND order_status_id = 4";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $num_orders = $row->[0];
    }
    return $num_orders;
}

sub _check_multiple_channels {
    my ( $dbh, $customer_ref ) = @_;

    my $num_channels    = 0;
    my $customers       = join ',', @{$customer_ref};

    my $qry  = "SELECT count(*) FROM channel WHERE id IN (SELECT channel_id FROM customer WHERE id IN ($customers))";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $num_channels = $row->[0];
    }
    return $num_channels;
}


sub _check_customer_age {
    my ( $dbh, $customer_ref ) = @_;

    my $customers   = join ',', @{$customer_ref};

    my $qry  = "SELECT CASE WHEN MIN(date) < current_timestamp - INTERVAL '6 months' THEN 1 ELSE 0 END AS old_customer FROM orders WHERE customer_id IN ($customers)";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $row = $sth->fetchrow_arrayref();
    return $row->[0];
}

sub _get_customer_credit_check {
    my ( $dbh, $customer_ref ) = @_;

    my $check;
    my $customers   = join ',', @{$customer_ref};

    my $qry = "SELECT credit_check FROM customer WHERE id IN ($customers)";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
        if ( defined $row->[0] && $row->[0] ne '' ) {
            $check = $row->[0];
        }
    }
    return $check;
}

sub _total_order_value {
    my ($dbh, $order_data) = @_;

    return $order_data->{gross_total} *
        get_local_conversion_rate($dbh, $order_data->{currency_id});

}

sub _total_orders {
    my ( $dbh, $customer_ref ) = @_;

    my $num_orders  = 0;
    my $val         = 0;
    my $customers   = join ',', @{$customer_ref};

    my $qry  = "SELECT total_value, currency_id FROM orders WHERE customer_id IN ($customers)";

    my $sth = $dbh->prepare($qry);
    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $num_orders++;
        $val       += ($row->[0] * get_local_conversion_rate($dbh, $row->[1]) );
    }
    return $num_orders, $val;
}

sub _total_orders_within_period {
    my ( $dbh, $customer_ref ) = @_;

    my $num_orders  = 0;
    my $val         = 0;
    my $customers   = join ',', @{$customer_ref};

    # EN554 changed age(date:date) which always == 0 to age(date) - not sure why this was... possibly main cause of bug?
    my $qry  = "SELECT total_value, currency_id FROM orders WHERE customer_id IN ($customers) AND age(date) < ?";
    #my $qry  = "SELECT total_value, currency_id FROM orders WHERE customer_id IN ($customers) AND age(date) < '6 months'";

    my $sth = $dbh->prepare($qry);
    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    $sth->execute(sys_config_var($schema, 'Order_Credit_Check', 'total_order_period'));
    # ^ RE EN-554 I am guessing A Solomon was trying to get the duration into sys config
    # however I am not quite sure of the signficance of the SystemConfig and is not
    # obvious how it works so reverting until he is here to discuss
    #$sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $num_orders++;
        $val       += ($row->[0] * get_local_conversion_rate($dbh, $row->[1]) );
    }
    return $num_orders, $val;
}


sub _weekly_orders {
    my ( $dbh, $customer_ref ) = @_;

    my $num_orders  = 0;
    my $val         = 0;
    my $customers   = join ',', @{$customer_ref};

    my $qry  = "SELECT total_value, currency_id  FROM orders WHERE customer_id IN ($customers) AND age(date) < '8 days'";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $num_orders++;
        $val += ($row->[0] * get_local_conversion_rate($dbh, $row->[1]));
    }
    return $num_orders, $val;
}

sub _daily_orders {
    my ( $dbh, $customer_ref ) = @_;

    my $num_orders  = 0;
    my $val         = 0;
    my $customers   = join ',', @{$customer_ref};

    my $qry  = "SELECT total_value, currency_id   FROM orders WHERE customer_id IN ($customers) AND age(date) < '1 day'";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $num_orders++;
        $val        += ($row->[0] * get_local_conversion_rate($dbh, $row->[1])) ;
    }
    return $num_orders, $val;
}

sub _get_customer_category {
    my ($dbh, $customer_id) = @_;

    my $cat = 0;

    my $qry  = "SELECT category FROM customer_category WHERE id = (SELECT category_id FROM customer WHERE id = ?)";

    my $sth = $dbh->prepare($qry);
    $sth->execute($customer_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $cat = $row->[0];
    }

    return $cat;
}

sub _get_country_by_code {
    my ($dbh, $country_code) = @_;

    my $country = "";

    my $qry  = "SELECT country FROM country WHERE code ilike ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($country_code);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $country = $row->[0];
    }
    return $country;
}

sub _get_country_of_origin {
    my ($dbh, $variant_id) = @_;

    my $country_code = "";

    my $qry  = "SELECT c.code FROM country c, shipping_attribute sa, variant v WHERE v.id = ? AND v.product_id = sa.product_id AND sa.country_id = c.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($variant_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $country_code = $row->[0];
    }
    return $country_code;
}

sub _check_cites_restriction {
    my ($dbh, $variant_id) = @_;

    my $restricted = 0;

    my $qry  = 'select cites_restricted from shipping_attribute where product_id = (select product_id from variant where id = ?)';
    my $sth = $dbh->prepare($qry);
    $sth->execute($variant_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $restricted = $row->[0];
    }
    return $restricted;
}

sub _get_conversion_rate {
    my ( $dbh, $from_currency_id, $to_currency_id ) = @_;

    my $qry = "
        select conversion_rate
        from sales_conversion_rate
        where current_timestamp > date_start
        and source_currency = ?
        and destination_currency = ?
        order by date_start desc limit 1
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($from_currency_id, $to_currency_id);

    my $rate = 1;

    while ( my $item = $sth->fetchrow_hashref() ) {
        $rate = $$item{conversion_rate};
    }
    return $rate;
}

sub _set_customer_credit {
    my ( $dbh, $customer_id, $value, $currency_id ) = @_;

    my $qry = "update customer_credit set credit = ?, currency_id = ? where customer_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($value, $currency_id, $customer_id);
}


sub d3 {
    my $val = shift;
    my $n = sprintf( "%.3f", $val );
    return $n;
}

sub get_shipping_charge_data {
    my ( $dbh, $args ) = @_;

    my $qry = "select sc.id, sc.sku, sc.description, sc.charge, sc.currency_id, cur.currency, sc.flat_rate, sc.class_id, scc.class
                    from shipping_charge sc, currency cur, shipping_charge_class scc
                    where sc.". $args->{type} ." = ?
                    and sc.currency_id = cur.id
                    and sc.class_id = scc.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($args->{value});

    my $row = $sth->fetchrow_hashref();

    return $row;
}

# FIXME calls here are always from free shipping and the value is always 0 as of  2010-08-27 05:49:00
sub _link_shipment_promotion {
    my ( $dbh, $shipment_id, $promo, $value ) = @_;

    my $qry = "insert into link_shipment__promotion (shipment_id, promotion, value) values (?, ?, ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id, $promo, $value);
}

## FIXME This is where cost_reduction is actually saved
sub _link_shipment_item_promotion {
    my ( $dbh, $shipment_item_id, $promo, $unit_price, $tax, $duty ) = @_;

    my $qry = "insert into link_shipment_item__promotion (shipment_item_id, promotion, unit_price, tax, duty) values (?, ?, ?, ?, ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_item_id, $promo, $unit_price, $tax, $duty);
}

sub _get_promo_name {
    my ($dbh, $promo_id) = @_;

    my $promo_name = 'Unknown';

    my $qry  = "select internal_title from event.detail where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($promo_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $promo_name = $row->[0];
    }

    return $promo_name;
}

# FIXME _preprocess_cost_reduction - The Webapp people are going to
# send us the correct string rather than us looking up their database.

sub _get_promo_name_from_web {
    my ($dbh, $promo_id) = @_;
    my $promo_name = 'Unknown_from_web';

    my $qry  = "select internal_title from event_detail where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($promo_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $promo_name = $row->[0];
    }

    return encode("utf-8", $promo_name);
}

sub _check_customer_category {
    my ($dbh, $customer_id, $email) = @_;

    my $category_id = 0;

    # get domain from email address
    my ($name, $domain) = split(/@/, $email);

    my $qry = "select category_id FROM customer_category_defaults WHERE email_domain = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($domain);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $category_id = $row->[0];
    }
    if ( $category_id ) {
        my $up_qry  = "update customer set category_id = ? where id = ? and category_id = 1";
        my $up_sth = $dbh->prepare($up_qry);
        $up_sth->execute( $category_id, $customer_id );

        $logger->info("Default category found - customer updated as id : $category_id");
    }
    else {
        $logger->info("No default category found");
    }
    return;
}

# gets the shipment type - DOMESTIC, INTERNATIONAL etc.
sub _get_shipment_type {
    my ( $dbh, $country )   = @_;

    my $type_id = $SHIPMENT_TYPE__INTERNATIONAL_DDU;   #5;  # default shipments to International DDU

    # check database for the country
    my $country_info = get_country_info($dbh, $country);

    # if record found use the shipment type set for the country
    if ( $country_info ) {
        $type_id = $$country_info{shipment_type_id};
    }

    return $type_id;
}

# extracts either a virtual or physical voucher from
# the relevant '_ORDER_LINE' section in the XML file
sub _extract_voucher_order_line {
    my ( $schema, $line, $total )   = @_;

    my %item_data = (
        # gather item data
        description => $line->findvalue('@DESCRIPTION'),
        sku         => $line->findvalue('@SKU'),
        quantity    => $line->findvalue('@QUANTITY'),

        unit_price  => $line->findvalue('UNIT_NET_PRICE/VALUE'),
        tax         => $line->findvalue('TAX/VALUE'),
        duty        => $line->findvalue('DUTIES/VALUE'),

        gift_to     => $line->findvalue('TO'),
        gift_from   => $line->findvalue('FROM'),
        gift_message=> $line->findvalue('GIFT_MESSAGE'),

        status_id   => $SHIPMENT_ITEM_STATUS__NEW,
        returnable_state_id  => $SHIPMENT_ITEM_RETURNABLE_STATE__NO, # Gift Vouchers aren't returnable

        # for consistency set-up promo stuff which won't get used
        promo => {
            value      => 0,
            unit_price => 0,
            tax        => 0,
            duty       => 0,
            applied    => 0,
        },
    );

    ($item_data{product_id}, $item_data{size_id}) = split(/-/, $item_data{sku});

    # add item totals to the shipment total
    $$total
        += (
            $item_data{unit_price}
          + $item_data{tax}
          + $item_data{duty}
        )
        * $item_data{quantity};

    $logger->info("SKU: $item_data{sku}\n"
                . "PRICE: $item_data{unit_price}\n"
                . "TAX: $item_data{tax}\n"
                . "DUTY: $item_data{duty}"
    );

    # get the voucher variant id for the SKU
    my $vouch_variant = $schema->resultset('Voucher::Variant')
                               ->search( { voucher_product_id => $item_data{product_id} } )
                               ->slice(0,0)
                               ->single;
    $item_data{voucher_variant_id} = $vouch_variant->id
        if $vouch_variant;

    ### get voucher variant id
    if ((not defined $item_data{voucher_variant_id}) or ($item_data{voucher_variant_id} == 0)) {
        my $tmpval = defined($item_data{voucher_variant_id})
                   ? $item_data{voucher_variant_id}
                   : '[undefined]'
        ;
        die "COULD NOT FIND VOUCHER VARIANT ID ($tmpval) for SKU $item_data{sku}\n\n";
    }
    else {
        $logger->info("GOT VOUCHER VARIANT ID: ".$item_data{voucher_variant_id});
    }

    $item_data{is_physical} = $vouch_variant->product->is_physical;

    return \%item_data;
}

=head2 _shipping_country_risk

Given a country, check its 'risk level', as definied in the sys_conf_var
database tables. Can return undef if a country hasn't had a risk level
defined, 'Low' if it has and possible 'High' in the future.

=cut
sub _shipping_country_risk {
    my ($schema, $country) = @_;

    $logger->debug("\$country = $country\n");

    my $origin_risk = sys_config_var($schema, 'OrderOriginRisk', $country);

    $origin_risk ? $logger->debug("\$origin_risk = $origin_risk\n")
                 : $logger->debug("No origin risk found");

    $origin_risk ||= '';

    return $origin_risk;
}

=head2 _low_risk_shipping_total

Returns the low risk shipping order threshold value,
for a given country, for a given channel. So if an order
is worth less than the threshold value it is 'low risk'.

=cut
sub _low_risk_shipping_total {
    my ($schema, $country, $total, $channel) = @_;

    my $country_code = _get_country_code( $schema, $country );

    my $conf_var = $country_code . 'OrderRiskAttributes';

    ## Dynamically generate a little lookup table from channel -> conf var
    ## e.g. 1 => NAP-INTL_Order_Threshold
    my $setting_channel_lookup = { };

    my @channels = $schema->resultset('Public::Channel')->all;

    foreach my $channel (@channels) {
        $setting_channel_lookup->{$channel->id} = $channel->web_name . '_Order_Threshold';
    }

    my $low_risk_total = sys_config_var($schema, $conf_var, $setting_channel_lookup->{$channel});

    $logger->debug("\$total = $total\n");
    $logger->debug("\$low_risk_total = $low_risk_total\n");

    if ( $total <= $low_risk_total ) {
        $logger->debug("$total <= $low_risk_total\n");
        return 1;
    }

    $logger->debug("$total > $low_risk_total\n");
    return 0;
}

=head2 _get_country_code

Given a country name, returns the country's short
code.

=cut
sub _get_country_code {
    my ($schema, $country) = @_;

    $logger->debug("\$country = $country\n");

    my $country_rs = $schema->resultset('Public::Country')
                ->search({ country => $country })
                ->single;

    if (!defined($country_rs)) {
        die "Couldn't find an entry in Public::Country for $country";
    }

    $logger->debug('$country_rs->code = ' . $country_rs->code ."\n");

    return $country_rs->code;
}

1;
