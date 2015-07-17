package XT::Order::Parser::PublicWebsiteXML;
use NAP::policy "tt", 'class';
    with    'XT::Order::Role::Parser',
            'XT::Role::DC',
            'XT::Order::Role::Parser::Common::CustomerData',
            'XT::Order::Role::Parser::Common::Dates';

use Scalar::Util qw( blessed );
use Catalyst::Utils;
use DateTime::Format::Strptime;
use DateTime::Format::HTTP;
use URI;

use XT::Data::Order;
use XT::Data::Address;
use XT::Data::CustomerName;
use XT::Data::Money;
use XT::Data::Telephone;
use XT::Data::Order::Tender;
use XT::Data::Order::LineItem;
use XT::Data::Order::CostReduction;
use XT::Data::Order::GiftLineItem;
use XTracker::Config::Local qw/config_var get_tender_type_from_config/;

use XTracker::Logfile qw( xt_logger );
my $logger = xt_logger(__PACKAGE__);

use XTracker::Constants::FromDB qw(
    :order_status
    :shipment_status
);

sub is_parsable {
    my ( $class, $data ) = @_;

    return 1 if blessed( $data ) && ref( $data ) eq 'XML::LibXML::Document';
}

sub parse {
    my ( $self ) = @_;

    my $tree = $self->data;
    my $root = $tree->getDocumentElement;

    my @orders;
    foreach my $order ( $root->findnodes('ORDER') ) {

        # We have to accomodate virtual vouchers, which are basically
        # a big hack. Sorry...
        my $is_virtual_voucher_only = 1;
        my @nodes = $order->findnodes('DELIVERY_DETAILS');
        $is_virtual_voucher_only = 0 if scalar @nodes >= 1;

        # convert XML into native perl structures
        my $order_data          = $self->_get_order_data( $order );
        my $customer_data       = $self->_get_customer_data( $order );
        my $delivery_data       =
            $is_virtual_voucher_only ? undef : # We don't have this data in virtual voucher orders
            $self->_get_delivery_data( $order ) ;
        my $tender_data         = $self->_get_tender_data( $order );
        my $promotion_data      = $self->_get_promotion_data( $order );
        my $item_data           = $self->_get_item_data( $order );
        my $gift_message        = (
            $is_virtual_voucher_only
            ? undef
            : $self->_get_gift_message( $item_data, $delivery_data )
        ); # Virtual vouchers can only have a line item gift message (maybe?)

        # CANDO-326: get <GIFT_LINE> items
        my $gift_line_item_data = $self->_get_gift_line_item_data( $order );


        # convert perl structures into single objects
        my $billing_address     = $self->_get_billing_address( $customer_data );
        my $customer_name       = $self->_get_name( $customer_data );
        # virtual vouchers don't have delivery details so we reuse the
        # billing details
        my $delivery_address    = (
            $is_virtual_voucher_only
            ? $billing_address
            : $self->_get_delivery_address( $delivery_data )
        );
        my $delivery_name       = (
            $is_virtual_voucher_only
            ? $customer_name
            : $self->_get_name( $delivery_data->{'name'} )
        );
        my $nominated_day       = $delivery_data->{nominated_day} || {};

        my $gross_total         = $self->_get_gross_total( $order_data );
        my $gross_shipping      = $self->_get_gross_shipping( $order_data );

        my $currency            = $order_data->{'currency'};
        my $free_shipping       = $self->_get_free_shipping( $promotion_data );

        # convert perl structures into arrays of objects
        my @tenders             = $self->_get_tenders( $tender_data, $currency );
        my @line_items
            = $self->_get_line_items( $item_data, $order_data, $promotion_data );
        my @telephone_numbers
            = $self->_get_billing_telephone_numbers( $customer_data );
        my @gift_line_items     = $self->_get_gift_line_items( $gift_line_item_data, $order_data );

        my $is_gift = 0;
        if ( defined $gift_message || $is_virtual_voucher_only ) {
            $is_gift = 1;
        }

        # Add Shipping contact details
        my %shipping_data;
        if( ( exists $delivery_data->{home_telephone}  && $delivery_data->{home_telephone} ne '')  ||
            ( exists $delivery_data->{work_telephone} && $delivery_data->{work_telephone} ne '') ||
            ( exists $delivery_data->{mobile_telephone} && $delivery_data->{mobile_telephone} ne '' )
        ) {
            $shipping_data{delivery_telephone_numbers} = [ $self->_get_shipping_telephone_numbers( $delivery_data ) ];
        }

        if( exists $delivery_data->{email} && $delivery_data->{email} ne '' ) {
            $shipping_data{delivery_email} = $delivery_data->{email};
        }


        my $order = XT::Data::Order->new({
            schema                      => $self->schema,

            order_number                => $order_data->{'order_nr'},
            language_preference         => $order_data->{'language_preference'} || undef,
            preorder_number             => $order_data->{'preorder_number'} || undef,
            order_date                  => $order_data->{'order_date'},
            channel_name                => $order_data->{'channel'},
            customer_number             => $order_data->{'customer_nr'},
            customer_ip                 => $order_data->{'ip_address'},
            placed_by                   => $order_data->{'placed_by'},
            used_stored_credit_card     => ($order_data->{'used_stored_card'} eq 'T' ? 1 : 0),
            # Delivery Signature Opt Out, NULL or EMPTY implies TRUE
            signature_required          => (
                                            !$order_data->{signature_required}
                                                || $order_data->{signature_required} eq 'true'
                                            ? 1     # signature Required
                                            : 0     # signature NOT Required
                                           ),

            billing_name                => $customer_name,
            billing_address             => $billing_address,
            billing_email               => $customer_data->{'email'},
            customer_name               => $customer_name,
            delivery_name               => $delivery_name,
            delivery_address            => $delivery_address,
            %shipping_data,
            nominated_delivery_date     => $nominated_day->{nominated_delivery_date},
            nominated_dispatch_date     => $nominated_day->{nominated_dispatch_date},

            line_items                  => \@line_items,
            tenders                     => \@tenders,
            billing_telephone_numbers   => \@telephone_numbers,

            # CANDO-326:
            gift_line_items             => \@gift_line_items,

            is_free_shipping            => ( defined $free_shipping ? 1 : 0 ),
            free_shipping               => $free_shipping,

            gross_total                 => $gross_total,
            postage                     => $gross_shipping,

            gift_message                => $gift_message,
            is_gift_order               => $is_gift,
            sticker                     => $order_data->{sticker},
            source_app_name             => $order_data->{source_app_name},
            source_app_version          => $order_data->{source_app_version},
        });

        if ($order_data->{'premier_routing_id'}) {
            $order->order_premier_routing_id(
                $order_data->{'premier_routing_id'}
                );
        };

        if ($order_data->{'account_urn'}) {
            $order->account_urn($order_data->{'account_urn'});
        };

        push @orders, $order;
    }

    return wantarray ? @orders : \@orders;
}

sub _get_order_data {
    my ( $self, $node ) = @_;

    my $order_data = {};

    $order_data->{order_nr}               = $node->findvalue('@O_ID');
    $order_data->{preorder_number}        = $node->findvalue('@PREORDER_NUMBER');
    $order_data->{language_preference}    = $node->findvalue('@LANGUAGE');
    $order_data->{basket_id}              = $order_data->{order_nr};
    # FIXME who should be doing this? parser or pre-processor?
    $order_data->{customer_nr}            = $node->findvalue('@CUST_ID');
    $order_data->{channel}                = $node->findvalue('@CHANNEL');
    $order_data->{ip_address}             = ( split(/,/, $node->findvalue('@CUST_IP') // '' ) )[0] // ''; # Front end sends csv rubbish.
    $order_data->{placed_by}              = $node->findvalue('@LOGGED_IN_USERNAME');
    $order_data->{used_stored_card}       = $node->findvalue('@USED_STORED_CREDIT_CARD');
    $order_data->{signature_required}     = lc( $node->findvalue('@SIGNATURE_REQUIRED') );
    $order_data->{premier_routing_id}     = $node->findvalue('@PREMIER_ROUTING_ID');
    ### legacy card info
    $order_data->{sticker}
        = $node->findvalue('DELIVERY_DETAILS/STICKER');

    $order_data->{order_date} =
        $self->_get_timezoned_date(
            $node->findvalue('@ORDER_DATE'),
            config_var("DistributionCentre", "timezone"),
        );

    if(my $account_urn = $node->findvalue('@ACCOUNT_URN')){
        $order_data->{account_urn} = $account_urn;
    }

    # DC specific fields
    # FIXME how best to incorporate this?
    #       At a minimum, add tests and start using
    #       ->parse_dc_datetime_string
    if ( $self->dc() eq 'DC2' ) {
        $order_data->{use_external_tax_rate}
            = $node->findvalue('@USE_EXTERNAL_SALETAX_RATE') || 0;
    }

    xt_logger->info( "Processing Order: ".$order_data->{order_nr} );

    # order totals and currency
    $order_data->{gross_total}    = $node->findvalue('GROSS_TOTAL/VALUE');
    $order_data->{gross_shipping} = $node->findvalue('POSTAGE/VALUE');
    $order_data->{currency}       = $node->findvalue('GROSS_TOTAL/VALUE/@CURRENCY');

    # CANDO-2362 Capture source_app_name & source_app_version
    $order_data->{source_app_name}        = $node->findvalue('@SOURCE_APP_NAME');
    $order_data->{source_app_version}     = $node->findvalue('@SOURCE_APP_VERSION');

    return $order_data;
}

sub _get_customer_data {
    my ( $self, $node ) = @_;

    my $customer_data = {};

    $customer_data->{email}
        = $node->findvalue('BILLING_DETAILS/CONTACT_DETAILS/EMAIL');
    $customer_data->{home_telephone}         = "";
    $customer_data->{work_telephone}         = "";
    $customer_data->{mobile_telephone}       = "";

    # get telephone numbers from billing contact details
    $customer_data = Catalyst::Utils::merge_hashes(
        $customer_data,
        $self->_extract_telephone($node,'BILLING_DETAILS/CONTACT_DETAILS')
    );

    $customer_data = Catalyst::Utils::merge_hashes(
        $customer_data,
        $self->_extract_name($node,'BILLING_DETAILS/NAME')
    );

    $customer_data = Catalyst::Utils::merge_hashes(
        $customer_data,
        $self->_extract_address($node,'BILLING_DETAILS/ADDRESS')
    );

    return $customer_data;

}

sub _get_delivery_data {
    my ( $self, $node ) = @_;

    # FIXME is there a better way?
    my $delivery = $node->findnodes('DELIVERY_DETAILS')->[0];
    #warn "looking at delivery data";
    my $delivery_details = {
        name            => $self->_extract_name($delivery,'NAME'),
        address         => $self->_extract_address($delivery,'ADDRESS'),
        gift_message    => $delivery->findvalue('GIFT_MESSAGE'),
    };


    if( $delivery->exists('CONTACT_DETAILS')) {
        my $contact_details = $delivery->findnodes('CONTACT_DETAILS')->[0];

        $delivery_details->{email}             = $contact_details->findvalue('EMAIL') || '';
        $delivery_details->{home_telephone}    = "";
        $delivery_details->{work_telephone}    = "";
        $delivery_details->{mobile_telephone}  = "";

        $delivery_details = Catalyst::Utils::merge_hashes(
            $delivery_details,
            $self->_extract_telephone($node,'DELIVERY_DETAILS/CONTACT_DETAILS')
        );
    }

    if( my ($nominated_day_node) = $delivery->findnodes('NOMINATED_DAY')) {
        $delivery_details->{nominated_day} = {
            nominated_delivery_date
                => $nominated_day_node->findvalue('DELIVERY_DATE') || undef,
            nominated_dispatch_date
                => $nominated_day_node->findvalue('DISPATCH_DATE') || undef,
        };
    }

    return $delivery_details;
}

sub _get_tender_data {
    my ( $self, $node ) = @_;

    my @tenders;

    foreach my $tender ($node->findnodes('TENDER_LINE')) {
        my $tender_data = {};
        # get tender type (card or credit)
        $tender_data->{type}    = $tender->findvalue('@TYPE');
        $tender_data->{rank}    = $tender->findvalue('@RANK');


        # has to have a type!
        if (!$tender_data->{type}) {
            # FIXME exception
            die "No Tender Line type present";
        }

        #CANDO-8584- Get tender_type from config
        $tender_data->{type} = get_tender_type_from_config( $self->schema, $tender_data->{type} );

        # get tender value
        $tender_data->{value}   = $tender->findvalue('VALUE');

        if ($tender_data->{type} eq "Gift Voucher") {
            $tender_data->{type}    = "Voucher Credit";
            $tender_data->{voucher_code} = $tender->findvalue('@VOUCHER_CODE');
            # FIXME throw exception
            die "Voucher code missing"
                unless defined $tender_data->{voucher_code}
                    and length $tender_data->{voucher_code};
        }
        elsif ($tender_data->{type} eq "Card") {
            $tender_data->{type} = 'Card Debit';
            $tender_data->{payment_pre_auth_ref} =
                $tender->findvalue('PAYMENT_DETAILS/PRE_AUTH_CODE');
        }

        push @tenders, $tender_data;
    }
    return \@tenders;

}

sub _get_promotion_data {
    my ( $self, $node ) = @_;

    my $promotion_data = {};

    # SECTION: PROMOTIONS
    # expected promotion types - must match one of these
    my %promo_type = (
        'free_shipping'         => 'Free Shipping',
        'percentage_discount'   => 'Percentage Off',
        'FS_GOING_GOING_GONE'   => 'Reverse Auction',
        'FS_PUBLIC_SALE'        => 'Public Sale',
            # this was Percentage Off but it was impacting
            # NAP evenmotions
    );

    foreach my $promotion ($node->findnodes('PROMOTION_BASKET')) {
        my $promo_id = $promotion->findvalue('@PB_ID');
        my $promo_rec = {
            type => $promotion->findvalue('@TYPE') || undef,
            description => $promotion->findvalue('@DESCRIPTION'),
            shipping => 0,
            promotion_discount => 0,
        };

        # FIXME execption
        die "PROMO: Unknown promotion type: $promo_rec->{type}\n"
            if (!$promo_rec->{type});
        $promo_rec->{class} = $promo_type{ $promo_rec->{type} },

        my $value = $promotion->findvalue('VALUE') || 0;

        # free shipping
        if ( $promo_rec->{class} eq 'Free Shipping' ) {
            $promo_rec->{shipping} = $value;
        }

        $promotion_data->{'promotion_basket'}{$promo_id} = $promo_rec;
    }
    foreach my $promotion ($node->findnodes('PROMOTION_LINE')) {

        # collect promo data and validate
        my $promotion_detail_id = $promotion->findvalue('@PL_ID');
        my $type                = $promotion->findvalue('@TYPE');
        my $description         = $promotion->findvalue('@DESCRIPTION');
        my $value               = $promotion->findvalue('VALUE') || 0;

        # validate promo type
        if ( !$promo_type{ $type } ) {
            # FIXME exception
            die "PROMO: Unknown promotion type: $type";
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
        $promotion_data->{$promotion_detail_id}{value}          = $value;

        # percentage discount
        # Reverse auction and percentage discount - value already off
        # unit price so only need to work out value off each component
        # of product cost (unit price, tax and duty)
        #if ( $promo_type{ $type } =~ m{^(?:Reverse Auction|Percentage Off|Public Sale)$} ) {

            ## first loop over items to get their full price value
            #my $item_total = 0;

            #foreach my $shipment ($node->findnodes('DELIVERY_DETAILS')) {
                #foreach my $item ($shipment->findnodes('ORDER_LINE')) {

                    ## only include if item has promo applied
                    #if ( $promotion_data->{$promotion_detail_id}{items}{$item->findvalue('@OL_ID')} ){
                        #$item_total += ( $item->findvalue('UNIT_NET_PRICE/VALUE')
                                #+ $item->findvalue('TAX/VALUE')
                                #+ $item->findvalue('DUTIES/VALUE') )
                            #* $item->findvalue('@QUANTITY');

                    #}
                #}
            #}

            #now calculate the value of promotion as a percentage of item cost to work out split discount
            #$promotion_data->{$promotion_detail_id}{percentage_removed} = sprintf( "%.2f", ($value / $item_total) );

            #second loop over order items to work out discount value per item
            #foreach my $shipment ($order->findnodes('DELIVERY_DETAILS')) {
                #foreach my $item ($shipment->findnodes('ORDER_LINE')) {

                    #my $ol_id = $item->findvalue('@OL_ID');
                    #only include if item has promo applied
                    #if ( $promotion_data->{$promotion_detail_id}{items}{$ol_id} ){

                        #Going going gone sale items on DC2 are not returnable
                        #$promotion_data->{$promotion_detail_id}{returnable}{$ol_id} =
                          #! (($promo_type{ $type } eq 'Reverse Auction'
                                #|| $promo_type{ $type } eq 'Public Sale')
                          #&& $DC eq 'DC2' );


                        #if (! $promotion_data->{$promotion_detail_id}{returnable}{$ol_id}) {
                          #$logger->info("GGG/PUBLICSALE: Item $ol_id is not returnable");
                        #}

                        #$promotion_data->{$promotion_detail_id}{discounts}{$ol_id}{unit_price}
                            #= $item->findvalue('UNIT_NET_PRICE/VALUE') * $promotion_data->{$promotion_detail_id}{percentage_removed};
                        #$promotion_data->{$promotion_detail_id}{discounts}{$ol_id}{tax}
                            #= $item->findvalue('TAX/VALUE') * $promotion_data->{$promotion_detail_id}{percentage_removed};
                        #$promotion_data->{$promotion_detail_id}{discounts}{$ol_id}{duty}
                            #= $item->findvalue('DUTIES/VALUE') * $promotion_data->{$promotion_detail_id}{percentage_removed};
                    #}
                #}
            #}
        }

        #$logger->info("ITEM PROMO: $description ($promotion_detail_id)");
        #$logger->info("TYPE: $type");
        #$logger->info("VALUE: $value");
        #if ( $promotion_data->{$promotion_detail_id}{percentage_discount} ) {
            #$logger->info("PERC DISCOUNT: $promotion_data->{$promotion_detail_id}{percentage_discount}");
            #$logger->info("ITEMS:");
            #foreach my $item_id ( keys %{$promotion_data->{$promotion_detail_id}{items}} ) {
                #$logger->info("$item_id - $promotion_data->{$promotion_detail_id}{items}{$item_id} subtracted");
             #}
        #}
        #$logger->info("\n----END PROMO----\n");
    #}

    return $promotion_data;

}

# FIXME this definitely needs fixing FIXME #
sub _get_item_data {
    my ( $self, $node ) = @_;

    my $shipment_data = ();
    my $item_data = ();

    foreach my $shipment ($node->findnodes('DELIVERY_DETAILS')) {
        # process each normal item in the shipment
        foreach my $item ($shipment->findnodes('ORDER_LINE')) {
            # item id
            my $id = $item->findvalue('@OL_ID');

            $item_data->{ $id } = $self->_extract_common_item_data( $item );
        }

        # process each physical voucher in the shipment
        foreach my $item ( $shipment->findnodes('ORDER_LINE_PHYSICAL_VOUCHER') ) {
            # item id
            my $id = $item->findvalue('@OL_ID');

            $item_data->{ $id } = $self->_extract_common_item_data( $item );
            $item_data->{ $id }->{is_voucher} = 1;
            $item_data->{ $id }->{is_gift} = 1;
        }
    }

    foreach my $shipment ($node->findnodes('VIRTUAL_DELIVERY_DETAILS')) {

        #recipient email - CANDO-74
        my $email = $shipment->findvalue('EMAIL');

        # process each virtual voucher in the shipment
        foreach my $item ( $shipment->findnodes('ORDER_LINE_VIRTUAL_VOUCHER') ) {
            # item id
            my $id = $item->findvalue('@OL_ID');

            $item_data->{ $id } = $self->_extract_common_item_data( $item );
            $item_data->{ $id }->{is_voucher} = 1;
            $item_data->{ $id }->{is_gift} = 1;
            $item_data->{ $id }->{gift_recipient_email} = $email;
        }
    }

    return $item_data;
}

# CANDO-326: get all of the '<GIFT_LINE>' tags
sub _get_gift_line_item_data {
    my ( $self, $node )     = @_;

    my $gift_item_data  = ();
    my $seq = 1;

    foreach my $shipment ($node->findnodes('DELIVERY_DETAILS')) {
        foreach my $item ( $shipment->findnodes('GIFT_LINE') ) {
            my $sku         = $item->findvalue('@SKU');
            my $description = $item->findvalue('@DESCRIPTION') || '';
            my $opted_out   = $item->findvalue('@OPTED_OUT') || 'N';

            $gift_item_data->{ $seq }   = {
                                sku         => $sku,
                                description => $description,
                                opted_out   => $opted_out,
                            };
            $seq++;
        }
    }

    return $gift_item_data;
}

sub _extract_common_item_data {
    my $self = shift;
    my $item = shift;

    my %info = (
        sequence        => $item->findvalue('@OL_SEQ'),
        description     => $item->findvalue('@DESCRIPTION'),
        sku             => $item->findvalue('@SKU'),
        quantity        => $item->findvalue('@QUANTITY'),

        unit_price      => $item->findvalue('UNIT_NET_PRICE/VALUE'),
        tax             => $item->findvalue('TAX/VALUE'),
        duty            => $item->findvalue('DUTIES/VALUE'),

        gift_to         => $item->findvalue('TO'),
        gift_from       => $item->findvalue('FROM'),
        gift_message    => $item->findvalue('GIFT_MESSAGE'),

        returnable_state => $item->findvalue('RETURNABLE'),

        sale            => $item->findvalue('SALE'),
    );

    foreach (qw[gift_to gift_from]) {
        $info{$_} = undef if $info{$_} eq '';
    }

    ($info{product_id}, $info{size_id}) = split /-/, $info{sku};

    return wantarray ? %info : \%info;
}

sub _extract_telephone {
    my ( $self, $order, $node ) = @_;

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

    $numbers->{telephone} = (defined $numbers->{home_telephone} and $numbers->{home_telephone} eq "")
      ? $numbers->{work_telephone}
        : $numbers->{home_telephone};

    return $numbers;
}

sub _extract_name {
    my ( $self, $node, $nodename ) = @_;

    my $mapping = {
        title       => "$nodename/TITLE",
        first_name  => "$nodename/FIRST_NAME",
        last_name   => "$nodename/LAST_NAME",
    };
    return $self->_extract_fields($node,$mapping);
}

sub _extract_address {
    my( $self, $node, $nodename ) = @_;

    my $mapping = {
        address_line_1 => "$nodename/ADDRESS_LINE_1",
        address_line_2 => "$nodename/ADDRESS_LINE_2",
        towncity => "$nodename/TOWNCITY",
        county => "$nodename/COUNTY",
        state => "$nodename/STATE",
        postcode => "$nodename/POSTCODE",
        country => "$nodename/COUNTRY",
    };

    my $data = $self->_extract_fields($node,$mapping);
    #warn "_extract_address";
    # sort out the address do don't need to do this again and again
    if ($self->dc eq 'DC2') {
        $data->{county} = delete $data->{state};
    } else {
        # we shouldn't have state if it's not a Hong Kong Address
        $data->{county} ||= $data->{state};
        delete $data->{state};
    }

    # Seaview: Extract address attributes
    if(my $address_node = $node->findnodes($nodename)->get_node(1)){
        # Address URN
        if($address_node->hasAttribute('URN')){
            my $urn_str = $address_node->getAttribute('URN');
            eval{
                $data->{addr_urn} = $urn_str;
            };
            if($@){
                $logger->info('Ignoring URN: ' . $urn_str);
            }
        }
        # Address Last-Modifed date/time
        if($address_node->hasAttribute('LAST_MODIFIED')){
            my $date_str = $address_node->getAttribute('LAST_MODIFIED');
            eval{
                $data->{addr_last_modified}
                  = DateTime::Format::HTTP->parse_datetime($date_str);
            };
            if($@){
                $logger->info('Ignoring unparsable HTTP date: ' . $date_str);
            }
        }
    }

    return $data;
}

sub _extract_fields {
    my ( $self, $node, $mapping ) = @_;

    my $out = { };
    #warn "_extract_fields";
    foreach my $key (keys %{$mapping}) {
        my $field = $node->findvalue($mapping->{ $key });
        $out->{$key} = $field;
    }

    return $out;
}



__PACKAGE__->meta->make_immutable;

1;
