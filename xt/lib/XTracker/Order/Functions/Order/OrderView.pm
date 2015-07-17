package XTracker::Order::Functions::Order::OrderView;

# Holding off on NAP::policy for the moment due to the potentially problematic
# intersection of fatal warnings and this handler's large, twisty and
# generally ill-understood nature
use strict;
use warnings;
use Try::Tiny;

use Plack::App::FakeApache1::Constants qw(:common);

use Readonly;
use XTracker::Handler;
use XT::Domain::Payment;
use XTracker::Config::Local qw( config_var isa_finance_manager_user has_delivery_signature_optout can_opt_out_of_requiring_a_delivery_signature );
use XTracker::Constants::FromDB qw(
    :department
    :flag
    :order_status
    :renumeration_type
    :shipment_class
    :shipment_item_status
    :shipment_status
    :shipment_type
);
use XTracker::Database;
use XTracker::Database::Address;
use XTracker::Database::Currency;
use XTracker::Database::Customer;
use XTracker::Database::Finance;
use XTracker::Database::Invoice;
use XTracker::Database::OrderPayment qw(
    get_order_payment
    get_order_status
    toggle_payment_fulfilled_flag_and_log
);
use XTracker::Database::Order qw( :DEFAULT log_order_access get_order_id get_order_total_charge );
use XTracker::Database::Return;
use XTracker::Database::Shipment qw(
:DEFAULT check_tax_included  get_shipment_routing_option
get_shipment_item_voucher_usage
);
use XTracker::Error;
use XTracker::Image;
use XTracker::PrintFunctions;
use XTracker::PrinterMatrix;
use XTracker::Order::Printing::AddressCard;
use XTracker::Order::Printing::GiftMessage;
use XTracker::Utilities qw( parse_url number_in_list unpack_csm_changes_params );

use XTracker::Navigation        qw( build_orderview_sidenav );

use XTracker::Logfile qw(xt_logger);
use XT::Net::Seaview::Client;

Readonly my $PATH_PRINT_DOCS => config_var('SystemPaths','document_dir');

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    my $schema = $handler->schema;

    # Seaview client for central address management
    $handler->{seaview} = XT::Net::Seaview::Client->new({schema => $schema});

    if ( exists $handler->{param_of}{viewdoc} ) {
        my $uri = _view_document(
            $handler->{param_of}{order_id},
            $handler->{param_of}{viewdoc},
            $schema,
        );
        return $handler->redirect_to( "/print_docs/$uri" );
    }

    for my $p ( keys %{ $handler->{param_of} } ) {
        # Display gift or voucher message to user

        if ( $p =~ m{^gift_message_text_(\d+)$} ) {

            my $shipment = $schema->resultset('Public::Shipment')->find($1);
            my $gms = $shipment->get_gift_messages();

            $shipment->update({ gift_message => $handler->{param_of}{$p} });

            foreach my $gm (@$gms) {
                if (!defined($gm->shipment_item)) {
                    # this is the top level gift message that we can change.
                    $gm->replace_existing_image();
                    last;
                }
            }

            xt_info( 'Gift message updated' );
            return $handler->redirect_to(
                $handler->path . '?order_id=' . $shipment->order->id
            );
        }
        # Do a gift voucher message update
        elsif ( $p =~ m{^voucher_message_text_(\d+)$} ) {
            my $shipment_item = $schema->resultset('Public::ShipmentItem')->find($1);
            my $shipment = $shipment_item->shipment;

            $shipment_item->update({
                gift_message => $handler->{param_of}{$p},
                gift_from    => $handler->{param_of}{gift_from},
                gift_to      => $handler->{param_of}{gift_to},
            });

            my $gms = $shipment->get_gift_messages();
            foreach my $gm (@$gms) {
                if (defined($gm->shipment_item) && $gm->shipment_item->id == $shipment_item->id) {
                    # this is the top level gift message that we can change.
                    $gm->replace_existing_image();
                    last;
                }
            }

            xt_info( 'Gift Voucher message updated' );
            return $handler->redirect_to(
                $handler->path . '?order_id=' . $shipment_item->shipment->order->id
            );
        }
        # Do recipient email update for virtual voucher
        elsif ( $p =~ m{^recipient_email_(\d+)$} ) { #CANDO-74
            my $ship_id = $1;
            my $email = $handler->{param_of}{$p};
            #if( Email::Valid->address($email)) {
            if( $email && $email =~ /^.*@.*$/) {
                    my $shipment_item
                        = $schema->resultset('Public::ShipmentItem')->find($ship_id);
                    $shipment_item->update({
                        gift_recipient_email => $email
                    });
                    xt_info( 'Recipient Email updated' );
                    return $handler->redirect_to(
                        $handler->path . '?order_id=' . $shipment_item->shipment->order->id
                    );
            } else {
                 xt_warn("Invalid Email - $email \n");
            }
        }
    }

    $handler->{data}{can_preview_shipment_messages} = 1
        if ( $handler->department_id == $DEPARTMENT__CUSTOMER_CARE
          || $handler->department_id == $DEPARTMENT__CUSTOMER_CARE_MANAGER
          || $handler->department_id == $DEPARTMENT__DISTRIBUTION
          || $handler->department_id == $DEPARTMENT__DISTRIBUTION_MANAGEMENT
          || $handler->department_id == $DEPARTMENT__FINANCE );

    $handler->{data}{can_preview_voucher_messages} = 1
        if ( $handler->department_id == $DEPARTMENT__DISTRIBUTION_MANAGEMENT
          || $handler->department_id == $DEPARTMENT__DISTRIBUTION );

    $handler->{data}{can_print_messages} = 1
        if ( $handler->department_id == $DEPARTMENT__DISTRIBUTION_MANAGEMENT );

    $handler->{data}{can_edit_messages} = 1
        if $handler->department_id == $DEPARTMENT__DISTRIBUTION_MANAGEMENT;

    $handler->{data}{can_view_payment_details} = 1
        if $handler->department_id == $DEPARTMENT__FINANCE;

    #CANDO_74
    $handler->{data}{can_edit_recipient_email} = 1
        if ( $handler->department_id == $DEPARTMENT__CUSTOMER_CARE
          || $handler->department_id == $DEPARTMENT__CUSTOMER_CARE_MANAGER );

    $handler->{data}{prl_rollout_phase} = config_var('PRL', 'rollout_phase');

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    # order id and notice id (capturing responses from updates)
    $handler->{data}{orders_id} = $handler->{param_of}{order_id};
    $handler->{data}{notice_id} = $handler->{param_of}{notice_id};

    # check for an order number passed on url and get order if from it
    if ( $handler->{param_of}{order_nr} ) {
        $handler->{data}{orders_id} = get_order_id( $handler->{dbh}, $handler->{param_of}{order_nr} );
    }

    if ($handler->{data}{orders_id} !~ /^\d+$/ || $handler->{data}{orders_id} > 2147483647) {
        # An order ID can only be an integer value
        xt_logger->warn(__PACKAGE__.' called with non integer or too large order id');
        return $handler->redirect_to('/Home');
    }

    my $order = $schema->resultset('Public::Orders')->find($handler->{data}{orders_id});

    unless ( $order && $order->isa('XTracker::Schema::Result::Public::Orders') ) {
        xt_logger->warn(__PACKAGE__.' called without valid order_id');
        return $handler->redirect_to('/Home');
    }

    $handler->{data}{order} = $order;

    # check to see if operator has a packing printer assigned and set param if so FELIX
    my $operator_prefs = $handler->{schema}->resultset('Public::OperatorPreference')->find({
        operator_id                => $handler->operator_id,
    });
    if ($operator_prefs) {
        my $packing_printer = $operator_prefs->packing_printer();
        if (defined $packing_printer) {
            $packing_printer=~s/\s//g;
            $handler->{data}{packing_printer} = $packing_printer;
        }
    }

    # get list of all mrp printers in config to populate dropdown (even if one set)
    my $printer_matrix = XTracker::PrinterMatrix->new({schema => $schema});
    $handler->{data}{mrp_sticker_printers} = $printer_matrix->get_packing_printers;

    my $display_sticker = $schema->resultset('SystemConfig::ConfigGroupSetting')
        ->config_var( "personalized_stickers", "display_sticker_in_xtracker", $order->channel_id );

    $handler->{data}{display_sticker} = $display_sticker;

    $handler->{data}{vouchers} = [ $handler->{data}{order}
        ->search_related('tenders',
            { type_id => $RENUMERATION_TYPE__VOUCHER_CREDIT})
        ->all ];

    if ($handler->{data}{notice_id}) {
        $handler->{data}{notice_message} = _get_notice_message($handler->{data}{notice_id});
    }

    $handler->{data}{SHIPMENT_ITEM_STATUS__CANCEL_PENDING} = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
    $handler->{data}{SHIPMENT_ITEM_STATUS__CANCELLED} = $SHIPMENT_ITEM_STATUS__CANCELLED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__LOST} = $SHIPMENT_ITEM_STATUS__LOST;
    $handler->{data}{SHIPMENT_ITEM_STATUS__UNDELIVERED} = $SHIPMENT_ITEM_STATUS__UNDELIVERED;

    $handler->{data}{section}               = $section;
    $handler->{data}{subsection}            = $subsection;
    $handler->{data}{subsubsection}         = 'Order View';
    $handler->{data}{content}               = 'ordertracker/shared/orderview.tt';
    $handler->{data}{css}                   = [
        '/css/shipping_restrictions.css',
        '/css/finance/geolocation.css',
        '/css/order_view.css',
        '/css/shared/refund_history.css',
    ];
    $handler->{data}{js}                    = [
        '/javascript/xui.js',
        '/javascript/popup/xt_popup_args.js',
        '/javascript/api/payment.js',
        '/javascript/popup/refund_history_order_page.js',
    ];
    $handler->{data}{short_url}             = $short_url;
    $handler->{data}{url}                   = $short_url.'/OrderView?order_id='.$handler->{data}{orders_id};
    $handler->{data}{master_shipment_id}    = 0;
    $handler->{data}{num_shipments}         = 0;
    $handler->{data}{canc_shipments}        = 0;
    $handler->{data}{dc_country}            = config_var('DistributionCentre', 'country');
    $handler->{data}{weight_unit}           = config_var('Units', 'weight');
    $handler->{data}{has_delivery_signature_optout} = has_delivery_signature_optout();
    $handler->{data}{can_opt_out_of_requiring_a_delivery_signature} = can_opt_out_of_requiring_a_delivery_signature();
    $handler->{data}{total_order_charge}
        = XTracker::Database::Order::get_order_total_charge( $handler->{dbh}, $handler->{data}{orders_id} );

    # process any post vars from form submit
    if ( $handler->{param_of} ) {
        my $return_val = _process_post( $handler );
        return $handler->redirect_to( $return_val )     if $return_val;
    }

    # gather all the order data we need for the page - there's a lot of it!
    _gather_order_data( $handler );

    # get list of available printers for re-printing
    $handler->{data}{printers} = [XTracker::PrinterMatrix->new->printer_names];

    # build left hand navigation - access varies depending on department setting
    $handler->{data}{sidenav} = _build_left_navigation($handler);

    $handler->process_template( undef );
    return OK;
}

sub _view_document {
    my ( $order_id, $spl_id, $schema ) = @_;

    my $spl = $schema->resultset('Public::ShipmentPrintLog')
    ->find( $spl_id );

    # If doc types generated with different extensions map them here e.g. lbl
    my %ext_map = (
        'Shipping Label' => q{}, # No extension required, document field
        # contains filename and extensions
        'Outward Shipping Label' => q{},
        'Return Shipping Label' => q{},
    );
    my %dir_map = (
        'Shipping Label' => q{label/}, # These live in a subdir to print docs
        'Outward Shipping Label' => q{label/}, # These live in a subdir to print docs
        'Return Shipping Label' => q{label/}, # These live in a subdir to print docs
    );

    # determine document type (optional), id and extension (optional) from file
    # column in shipment print log
    my $document_details = XTracker::PrintFunctions::document_details_from_name( $spl->file );
    my ($document_type, $document_id, $extension) = ( $spl->file =~ /^([^-]+(?=-))?-?(.*?)\.?((?<=\.)\w+)?$/ );

    my $uri = XTracker::PrintFunctions::path_for_print_document( $document_details );
    my $print_filename = XTracker::PrintFunctions::path_for_print_document({ %$document_details, relative => 1 });

    my $shipment = $schema->resultset('Public::Shipment')
                          ->find($spl->shipment_id);
    # Regenerate the document
    if ( $spl->document eq 'Invoice' ) {
        $shipment->get_sales_invoice->generate_invoice;
    }
    elsif ( $spl->document eq 'Return Proforma' ) {
        $shipment->generate_return_proforma;
    }
    # HACK HACK BODGE HACK [REL-859]
    elsif ( $spl->document eq 'Outward Proforma' ) {
        require XTracker::Order::Printing::OutwardProforma;
        # print zero copies on the Finance printer
        # this might regenerate the source HTML file
        XTracker::Order::Printing::OutwardProforma::generate_outward_proforma($schema->storage->dbh, $spl->shipment_id, 'Finance', 0, $schema);
    }
    return $print_filename;
}

sub _gather_order_data {
    my $handler = shift;

    my $data = $handler->{data};
    my $dbh = $handler->{dbh};

    my $schema = $handler->{schema};

    $data->{master_shipment_id}    = 0;
    $data->{num_shipments}         = 0;
    $data->{canc_shipments}        = 0;
    $data->{active_shipments}      = 0;
    $data->{dispatched_shipments}  = 0;

    # log user in order access log
    log_order_access( $dbh, $data->{orders_id}, $data->{operator_id} );

    ## get order data
    $data->{orders}             = get_order_info( $dbh, $data->{orders_id} );
    _get_order_flags( $handler );                                                                # get any order flags and populate data set
    $data->{sales_channel}      = $data->{orders}{sales_channel};                                # set channel for order to display at top of page
    $data->{promotions}         = get_order_promotions( $dbh, $data->{orders_id} );              # order promotion data - free shipping, money off etc.


    # Grab customer information from XT db
    $data->{customer} = get_customer_info( $dbh, $data->{orders}{customer_id} );

    # Seaview: Overlay seaview information if present
    try{
        if(my $acc_urn = $handler->{seaview}
                                 ->registered_account($data->{orders}{customer_id})){

            my $seaview_account = $handler->{seaview}->account($acc_urn);

            if ( defined $seaview_account ) {
                my $sv_customer_info = $seaview_account->as_dbi_like_hash;
                # Overlay seaview information
                @{ $data->{customer} }{ keys %$sv_customer_info }
                  = values %$sv_customer_info;
            }
        }
    }
    catch {
        # We tried to load some Seaview data but failed - log and carry on
        xt_logger->warn($_);
    };

    $data->{customer}{notes}    = get_customer_notes( $dbh, $data->{orders}{customer_id} );      # customer notes
    $data->{orders}{watchFlags} = watch_flags( $dbh, $data->{orders}{customer_id} );             # customer watch flags
    $data->{inv_address}        = get_address_info( $schema, $data->{orders}{invoice_address_id} ); # billing address for order
    $data->{emails}             = get_order_emails( $dbh, $data->{orders_id} );                  # order email log
    $data->{order_payment}      = get_order_payment( $dbh, $data->{orders_id} );                 # get order payment details
    $data->{contact_subjects}   = $data->{order}->get_csm_available_to_change();                 # get Correspondence Subjects to Show Opt-Out Options for
    $data->{marketing_promotions} = $data->{order}->get_all_marketing_promotions;

    #get PreOrder data
    $data->{pre_order}         = $data->{order}->get_preorder;
    if ( $data->{pre_order} ) {
        $data->{pre_order_notes}    = [ $data->{pre_order}->pre_order_notes->order_by_date_desc->all ];
    }

    # query PSP for payment details
    if ( $data->{order_payment} ) {

        my $payment_ws          = XT::Domain::Payment->new( { acl => $schema->acl });
        my $payment_info        = $payment_ws->protected_getinfo_payment({ reference => $data->{order_payment}{preauth_ref} });
        $data->{payment_info}   = $payment_info;
        $data->{payment_info}   =  undef unless ($payment_ws->pmc_protected_getinfo_payment_call_was_allowed );

        $data->{show_payfulfill_btn}    = 0;
        if ( isa_finance_manager_user( $schema, $handler->{data}{username} ) ) {
            $data->{show_payfulfill_btn}= 1;
        }
        # get any fulfill log entries for the payment
        my @fulfill_log
            = $schema->resultset('Orders::LogPaymentFulfilledChange')
                        ->get_all_payment_fulfilled_change_logs_for_order_id( $data->{orders_id} )
                            ->order_by_date_changed_desc
                                ->all;
        if ( @fulfill_log ) {
            # only populate this field if there are any logs to show
            $data->{payfulfill_log} = \@fulfill_log;
        }

        # get card history
        foreach my $order ( @{ $data->{payment_info}->{paymentHistory} } ) {
            my $order_nr = $order->{orderNumber};

            $data->{card_history}{$order_nr} = $order;

            # get extra info on order from db
            my $extra_data = get_order_status($dbh, $order_nr);
            $data->{card_history}{$order_nr}{orders_id}   = $extra_data->{orders_id};
            $data->{card_history}{$order_nr}{total_value} = $extra_data->{total_value};
            $data->{card_history}{$order_nr}{status}      = $extra_data->{status};
            $data->{card_history}{$order_nr}{date}        = $extra_data->{date};
            $data->{card_history}{$order_nr}{fulfilled}   = $extra_data->{fulfilled};
        }
    }

    # get order notes
    my $notes = get_order_notes( $dbh, $data->{orders_id} );

    # pre-process order notes into common notes hash
    # using date_sort field as our key to display all notes in chronological order
    foreach my $note_id ( keys %{$notes} ) {
        my $note = $notes->{ $note_id };
        # set note class to 'Order' and note value as the order number
        $note->{'class'} = 'Order';
        $note->{'value'} = $data->{order}->order_nr;

        push @{ $data->{notes} }, $note;
    }

    # get the all shipments tied to this order
    my $shipments = get_order_shipment_info( $dbh, $data->{orders_id} );
    my $return_rs = $schema->resultset('Public::Return');

    # loop through each shipment and get the info required
    for my $ship_id ( keys %{ $shipments } ) {

        # This allows us to use shipment objects when we loop through the
        # shipments hash in the template. Yes it's not pretty. -DJ
        my $shipment_object
            = $shipments->{$ship_id}{object}
            = $schema->resultset('Public::Shipment')->find($ship_id);

        # is it an "active" shipment - not dispatched, cancelled or lost
        if (   $shipments->{$ship_id}{shipment_status_id} != $SHIPMENT_STATUS__DISPATCHED
            && $shipments->{$ship_id}{shipment_status_id} != $SHIPMENT_STATUS__CANCELLED
            && $shipments->{$ship_id}{shipment_status_id} != $SHIPMENT_STATUS__LOST )
        {
            $data->{active_shipments} = 1;
        }

        # has it been dispatched
        if ( $shipments->{$ship_id}{shipment_status_id} == $SHIPMENT_STATUS__DISPATCHED ) {
            $data->{dispatched_shipments} = 1;
        }

        # is it a re-shipment
        if ( $shipments->{$ship_id}{shipment_class_id} == $SHIPMENT_CLASS__RE_DASH_SHIPMENT ) {
            $data->{re_shipments} = 1;
        }

        # assign this shipment to the master shipment variable - indicates the main shipment in an order
        if ($shipments->{$ship_id}{shipment_class_id} == $SHIPMENT_CLASS__STANDARD && $data->{master_shipment_id} == 0){
            $data->{master_shipment_id} = $ship_id;
        }

        # Description of the Shipping option
        if ( my $shipping_charge_object = $shipment_object->shipping_charge_table() ) {
            $shipments->{$ship_id}{shipping_option_description} = $shipping_charge_object->description();
        }

        # tidy up the shipment charges for display on screen
        $shipments->{$ship_id}{shipping_charge} = _d2( $shipments->{$ship_id}{shipping_charge} );
        $shipments->{$ship_id}{store_credit} = _d2( $shipments->{$ship_id}{store_credit} );
        $shipments->{$ship_id}{gift_credit} = _d2( $shipments->{$ship_id}{gift_credit} );

        # start building up the shipment total value
        if ($shipments->{$ship_id}{shipment_status_id} != $SHIPMENT_STATUS__CANCELLED ){
            $shipments->{$ship_id}{shipment_total} = $shipments->{$ship_id}{shipping_charge};
        }

        my $ymd_template = "%d-%m-%Y";
        if(my $nominated_delivery_date = $shipment_object->nominated_delivery_date) {
            $shipments->{$ship_id}{nominated_delivery_date_str}
                = $nominated_delivery_date->strftime($ymd_template);
        }
        if(my $sla_cutoff = $shipment_object->sla_cutoff()) {
            $shipments->{$ship_id}{sla_cutoff_str}
                = $sla_cutoff->strftime("$ymd_template %H:%M");
        }

        $shipments->{$ship_id}{ship_address}   = get_address_info( $schema, $shipments->{$ship_id}{shipment_address_id} ); # Shipping address for shipment
        $shipments->{$ship_id}{boxes}          = get_shipment_boxes( $dbh, $ship_id);           # shipment boxes
        $shipments->{$ship_id}{emails}         = get_shipment_emails( $dbh, $ship_id );         # get shipment emails
        $shipments->{$ship_id}{return_emails}  = $shipment_object                               # get shipment's return emails
                                                        ->get_return_correspondence_logs
                                                            ->formatted_for_page;
        $shipments->{$ship_id}{refunds}        = get_shipment_invoices( $dbh, $ship_id );       # get shipment payments
        $shipments->{$ship_id}{paperwork}      = get_shipment_documents( $dbh, $ship_id );      # get shipment documents
        $shipments->{$ship_id}{pick_paperwork} = $shipment_object->picking_print_docs_info();   # get shipment extra_items
        $shipments->{$ship_id}{promotions}     = get_shipment_promotions( $dbh, $ship_id );     # get promotions applied to shipment
        $shipments->{$ship_id}{markdowns}      = get_shipment_markdowns( $dbh, $ship_id );      # get markdowns applied to shipment
        $shipments->{$ship_id}{routing_schedules}   = $shipment_object->routing_schedules->list_schedules;

        $shipments->{$ship_id}{short_gift_msg}
            = $shipment_object->summarise_gift_message;
        $shipments->{$ship_id}{has_vouchers}
            = $shipment_object->has_vouchers;

        # get routing option for premier deliveries
        if ( $shipments->{$ship_id}{shipment_type_id} == $SHIPMENT_TYPE__PREMIER ) {
            $shipments->{$ship_id}{premier_routing} = get_shipment_routing_option( $dbh, $ship_id );
        }

        # get shipments notes
        $notes = get_shipment_notes( $dbh, $ship_id );

        # loop through and pre-process into common notes hash
        foreach my $note_id ( keys %{$notes} ) {
            my $note = $notes->{ $note_id };
            # set note class to 'Shipment' and note value as the shipment id
            $note->{'class'} = 'Shipment';
            $note->{'value'} = $ship_id;

            push @{ $data->{notes} }, $note;
        }

        # get all the items in the shipment
        $shipments->{$ship_id}{ship_items} =
        get_shipment_item_info( $dbh, $ship_id );

        # loop through shipment items
        for my $ship_item_id (keys %{ $shipments->{$ship_id}{ship_items} } ){
            # get customs value of item - unit price and maybe tax (NO duty) converted into local currency
            my $conv_rate = get_local_conversion_rate($dbh, $data->{orders}{currency_id});

            #CANDO-74 Adding Recipient email
            if($shipments->{$ship_id}{ship_items}{$ship_item_id}{voucher}){
                    $shipments->{$ship_id}{recipient_email} = $shipments->{$ship_id}{ship_items}{$ship_item_id}{gift_recipient_email};
            } else {
                    $shipments->{$ship_id}{recipient_email} = undef;
            }

            if ( check_tax_included( $dbh, $shipments->{$ship_id}{ship_address}{country} ) ) {
                $shipments->{$ship_id}{ship_items}{$ship_item_id}{customs_value} = _d2($conv_rate * ($shipments->{$ship_id}{ship_items}{$ship_item_id}{unit_price} + $shipments->{$ship_id}{ship_items}{$ship_item_id}{tax}) );
            }
            else {
                $shipments->{$ship_id}{ship_items}{$ship_item_id}{customs_value} = _d2($conv_rate * $shipments->{$ship_id}{ship_items}{$ship_item_id}{unit_price});
            }

            # all items must have a value for customs - if unit price is 0 set it to 1 - only affects promo items
            if ($shipments->{$ship_id}{ship_items}{$ship_item_id}{customs_value} == 0) {
                $shipments->{$ship_id}{ship_items}{$ship_item_id}{customs_value} = 1;
            }

            # tidy up pricing for display purposes
            $shipments->{$ship_id}{ship_items}{$ship_item_id}{unit_price} = _d2( $shipments->{$ship_id}{ship_items}{$ship_item_id}{unit_price} );
            $shipments->{$ship_id}{ship_items}{$ship_item_id}{tax}        = _d2( $shipments->{$ship_id}{ship_items}{$ship_item_id}{tax} );
            $shipments->{$ship_id}{ship_items}{$ship_item_id}{duty}       = _d2( $shipments->{$ship_id}{ship_items}{$ship_item_id}{duty} );

            # calculate the items sub total
            $shipments->{$ship_id}{ship_items}{$ship_item_id}{sub_total} = _d2($shipments->{$ship_id}{ship_items}{$ship_item_id}{unit_price} + $shipments->{$ship_id}{ship_items}{$ship_item_id}{tax} + $shipments->{$ship_id}{ship_items}{$ship_item_id}{duty} );

            # if the item is not cancelled - add its value to the total value variable
            if ( $shipments->{$ship_id}{ship_items}{$ship_item_id}{shipment_item_status_id} != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING && $shipments->{$ship_id}{ship_items}{$ship_item_id}{shipment_item_status_id} != $SHIPMENT_ITEM_STATUS__CANCELLED ){
                $shipments->{$ship_id}{shipment_total} += $shipments->{$ship_id}{ship_items}{$ship_item_id}{sub_total};
            }

            # if the shipment item has a promotion attached to it
            foreach my $promotion_name ( %{ $shipments->{$ship_id}{promotions} } ) {
                if ( exists $shipments->{$ship_id}{promotions}{$promotion_name}
                        and exists $shipments->{$ship_id}{promotions}{$promotion_name}{items}{$ship_item_id} ) {
                    my $discount = $shipments->{$ship_id}{promotions}{$promotion_name}{items}{$ship_item_id}{unit_price};
                    my $paid     = $shipments->{$ship_id}{ship_items}{$ship_item_id}{unit_price};
                    $shipments->{$ship_id}{ship_items}{$ship_item_id}{promotion_percentage}
                    = 100 * ( _d2( # Round to two decimal places and multiply by 100
                            $discount / ( $discount + $paid ) # Work out discount proportion
                        )
                    );
                }
            }

            # get shipping restrictions only for a product
            if ($shipments->{$ship_id}{ship_items}{$ship_item_id}{product_id}) {
                try {
                my $product = $schema->resultset('Public::Product')
                    ->find($shipments->{$ship_id}{ship_items}{$ship_item_id}{product_id});

                my $ship_restrictions = $product->get_shipping_restrictions_status;
                $shipments->{$ship_id}{ship_items}{$ship_item_id}{is_hazmat}
                    = $ship_restrictions->{is_hazmat};
                $shipments->{$ship_id}{ship_items}{$ship_item_id}{is_aerosol}
                    = $ship_restrictions->{is_aerosol};
                $shipments->{$ship_id}{ship_items}{$ship_item_id}{is_hazmat_lq}
                    = $ship_restrictions->{is_hazmat_lq};
                };
            }

            # get the image for the product
            $shipments->{$ship_id}{ship_items}{$ship_item_id}{image} = get_images({
                product_id => $shipments->{$ship_id}{ship_items}{$ship_item_id}{product_id},
                live => 1,
                size => 'l',
                schema => $schema,
            });

            if ($shipments->{$ship_id}{ship_items}{$ship_item_id}{voucher}){
                if ( $shipments->{$ship_id}{ship_items}{$ship_item_id}{voucher_code_id} ) {
                    my $shipment_item = $schema->resultset('Public::ShipmentItem')->find($ship_item_id);
                    $shipments->{$ship_id}{ship_items}{$ship_item_id}{code}
                        = $shipment_item->voucher_code->code;
                    $shipments->{$ship_id}{ship_items}{$ship_item_id}{gift_from}
                        = $shipment_item->gift_from;
                    $shipments->{$ship_id}{ship_items}{$ship_item_id}{gift_to}
                        = $shipment_item->gift_to;
                    $shipments->{$ship_id}{ship_items}{$ship_item_id}{gift_message}
                        = $shipment_item->gift_message;

                    $shipments->{$ship_id}{ship_items}{$ship_item_id}{voucher_usage}
                    = [get_shipment_item_voucher_usage($schema, $ship_item_id)];
                }
            }
        }

        $shipments->{$ship_id}{shipment_total} = _d2( $shipments->{$ship_id}{shipment_total} ); # tidy up the shipment total

        # get shipment returns
        $shipments->{$ship_id}{returns} = get_shipment_returns( $dbh, $ship_id );

        # get returns arrivals
        $shipments->{$ship_id}{return_arrivals} = get_return_arrivals( $dbh, $shipments->{$ship_id}{return_airway_bill} );

        # loop through the returns
        for my $return_id ( keys %{ $shipments->{$ship_id}{returns} } ){
            $shipments->{$ship_id}{returns}{$return_id}{return_items} = get_return_item_info( $dbh, $return_id ); # get the items in the return

            # get the return notes
            $notes = get_return_notes( $dbh, $return_id );

            # loop through and pre-process into common notes hash
            foreach my $note_id ( keys %{$notes} ) {
                my $note = $notes->{ $note_id };
                # set note class to 'Return' and note value as the RMA number
                $note->{class}     = 'Return';
                $note->{value}     = $shipments->{$ship_id}{returns}{$return_id}{rma_number};
                $note->{return_id} = $return_id;

                push @{ $data->{notes} }, $note;
            }

            # get the DBIC version so it can be used in the TT
            my $return_obj  = $return_rs->find( $return_id );
            $shipments->{$ship_id}{returns}{$return_id}{object} = $return_obj;
            $shipments->{$ship_id}{returns}{$return_id}{routing_schedules} = $return_obj->routing_schedules->list_schedules;
        }

        # get "hold" data if shipment is on hold
        if ( $shipments->{$ship_id}{shipment_status_id} == $SHIPMENT_STATUS__HOLD ) {
            $shipments->{$ship_id}{hold} = _get_hold_info( $dbh, $ship_id);
        }

        # increment the number of shipments variable
        $data->{num_shipments}++;

        # increment the cancelled shipments variable
        if ( $shipments->{$ship_id}{shipment_status_id} == $SHIPMENT_STATUS__CANCELLED ) {
            $data->{canc_shipments}++;
        }

        $shipments->{$ship_id}{carrier_tracking_uri} =~ s/<TOKEN>//
            if $shipments->{$ship_id}{carrier_tracking_uri};
    }
    $data->{shipments} = $shipments;

    # check if master shipment is packed
    $data->{packed} = check_shipment_packed($dbh, $data->{master_shipment_id});
    return;
}

sub _build_left_navigation {
    my $handler = shift;
    my $data = $handler->{data};

    # set up base for links (section/sub section)
    my $link_base = $data->{short_url};

    # hash to allow us to sort the side nav subsections
    my %link_sort = (
        "None"          => 0,
        "Order"         => 1,
        "Customer"      => 2,
        "Shipment"      => 3,
        "Shipment Item" => 4,
        "Fraud Rules"   => 5,
    );

    # get a hash of all the available left nav links
    my $links = build_orderview_sidenav( $data );

    #
    # now remove links that aren't relevant based on order/shipment status
    #

    # can't cancel an order if its already been cancelled
    if ( $data->{orders}{order_status_id} == $ORDER_STATUS__CANCELLED ) {
        delete $links->{"Order"}{"Cancel Order"};
    }

    # order not on credit check - no need for Accept Order link
    if ( $data->{orders}{order_status_id} > $ORDER_STATUS__CREDIT_CHECK ) {
        delete $links->{"Order"}{"Accept Order"};
    }
    # don't need Credit Check link if order not on Credit Hold
    if ( $data->{orders}{order_status_id} != $ORDER_STATUS__CREDIT_HOLD ) {
        delete $links->{"Order"}{"Credit Check"};
    }
    # can only put order on Credit Hold if its status id "Accepted"
    if ( $data->{orders}{order_status_id} != $ORDER_STATUS__ACCEPTED ) {
        delete $links->{"Order"}{"Credit Hold"};
    }

    # can't get pre-auth if payment already fulfilled
    if ( not defined $data->{order_payment}{fulfilled}
          or $data->{order_payment}{fulfilled} != 0
    ) { delete $links->{"Order"}{"Pre-Authorise Order"}; }

    # no need for Remove Watch if customer not on watch
    if ( !$data->{orders}{watchFlags}{'FinanceWatch'} ) { delete $links->{"Order"}{"Remove Watch"}; }

    # no need for Add Watch if customer is already on watch
    if ( $data->{orders}{watchFlags}{'FinanceWatch'} ) { delete $links->{"Order"}{"Add Watch"}; }

    # delete add Customer watch if already on watch
    if ($data->{orders}{watchFlags}{'CustomerWatch'}){
        delete $links->{"Customer"}{"Add Watch"};
    }
    # delete remove Customer watch if not on watch
    else {
        delete $links->{"Customer"}{"Remove Watch"};
    }

    # can't change shipment items if shipment is dispatched, cancelled or lost
    if ( $data->{shipments}{$data->{master_shipment_id}}{shipment_status_id} == $SHIPMENT_STATUS__DISPATCHED
      || $data->{shipments}{$data->{master_shipment_id}}{shipment_status_id} == $SHIPMENT_STATUS__CANCELLED
      || $data->{shipments}{$data->{master_shipment_id}}{shipment_status_id} == $SHIPMENT_STATUS__LOST ) {
        delete $links->{"Shipment Item"}{"Cancel Shipment Item"};
    }

    # only do returns if shipment has been dispatched
    if ( $data->{dispatched_shipments} == 0 ) {
        delete $links->{"Shipment Item"}{"Returns"};
        delete $links->{"Shipment"}{"Lost Shipment"};
    }

    # can't amend or check pricing if payment already taken
    if ($data->{order_payment}{fulfilled}){
        delete $links->{"Shipment"}{"Amend Pricing"};
        # unfortunately 'Check Pricing' is always available to the Finance Department
        delete $links->{"Shipment"}{"Check Pricing"}    unless ( $data->{department_id} == $DEPARTMENT__FINANCE );
    }

    # can't do a dispatch and return unles shipment is packed and active
    if ($data->{packed} != 1 || $data->{active_shipments} == 0){ delete $links->{"Shipment"}{"Dispatch/Return"}; }

    # can't create a new shipment unless shipment has been dispatched
    if ( $data->{dispatched_shipments} == 0 ) { delete $links->{"Shipment"}{"Create Shipment"}; }

    # remove option to cancel re-shipment if no re-shipment exists
    unless ( $data->{re_shipments} ) {
        delete $links->{"Shipment"}{"Cancel Re-Shipment"};
    }

    # unfortunately some options are still special for the
    # Finance Department, this restriction should go when
    # the XT Access Controls project progresses.
    if ( $data->{department_id} != $DEPARTMENT__FINANCE ) {
        # can't cancel an order if its already cancelled or one of shipments is already dispatched
        if ( $data->{orders}{order_status_id} != $ORDER_STATUS__CANCELLED
          && $data->{dispatched_shipments} == 1 ) {
            delete $links->{"Order"}{"Cancel Order"};
        }

        # only create debits and credits on dispatch shipments
        if ( $data->{dispatched_shipments} == 0 ) { delete $links->{"Shipment"}{"Create Credit/Debit"}; }

        # can't hold a shipment if not active - already cancelled or dispatched
        if ( $data->{active_shipments} == 0){ delete $links->{"Shipment"}{"Hold Shipment"}; }
    }

    # we've finished removing links - put whats left into the sidenav hash
    my $sidenav;
    foreach my $link_section ( keys %{ $links } ) {
        foreach my $link ( sort {$links->{$link_section}{$a}[0] <=> $links->{$link_section}{$b}[0]} keys %{$links->{$link_section}}){
            my $url = (
                $links->{ $link_section }{ $link }[1] =~ m{^(/|http)}
                ? $links->{ $link_section }{ $link }[1]
                : $link_base ."/". $links->{ $link_section }{ $link }[1]
            );
            $url = ( $url eq "/StockControl/Inventory/" ? "/StockControl/Inventory?rmbrlctn=1" : $url );

            push @{ $sidenav->[ $link_sort{ $link_section } ]{ $link_section } },
                    { title => $link, url => $url, popup => $links->{ $link_section }{ $link }[2] // '' };
        }
    }
    return $sidenav;
}

sub _get_order_flags {
    my ( $handler ) = @_;

    my $flags = all_flags( $handler->{dbh}, $handler->{data}{orders_id} );

    my @warnings;
    my @categories;
    my @cchecks;
    my $cv2_avs;

    # hash of possible cv2/avs responses
    my %cv2_avs_lookup = ( 'ALL MATCH' => 1, 'SECURITY CODE MATCH' => 1, 'NO DATA MATCHES' => 1, 'DATA NOT CHECKED' => 1 );

    foreach my $flag ( @{$flags} ) {
        ## category flags
        if ( $flag->[0] == 1 ) {
            push( @categories, $flag->[1] );
        }
        ## warning flags
        elsif ( $flag->[0] == 2 || $flag->[0] == 5 ) {
            # CV2/AVS responses
            if ( $cv2_avs_lookup{ $flag->[1] } ) {
                $cv2_avs =  $flag->[1];
            }
            else {
                my $warningImg = $flag->[1];
                $warningImg =~ s/\s/_/g;

                if ( -e config_var('SystemPaths','xtdc_base_dir')."/root/static/images/finance_icons/$warningImg.png" ) {
                    push( @warnings,
                        '<img src="/images/finance_icons/'
                        . $warningImg
                        . '.png" align="left" hspace="4" alt="'
                        . $flag->[1]
                        . '">'
                    );
                }
                else {
                    push( @warnings, $flag->[1] . '&nbsp;&nbsp;&nbsp;' );
                }
            }
        }
        ## credit check flags
        elsif ( $flag->[0] == 3 ) {
            push( @cchecks, $flag->[1] );
        }
    }

    $handler->{data}{orders}{nameok}        = "";
    $handler->{data}{orders}{namewrong}     = "";
    $handler->{data}{orders}{addrok}        = "";
    $handler->{data}{orders}{addrwrong}     = "";
    $handler->{data}{orders}{possiblefraud} = "";

    if ( @cchecks > 0 ) {
        foreach my $ccheck (@cchecks) {
            if ( $ccheck eq "Address OK" ) {
                $handler->{data}{orders}{addrok} = "checked";
            }
            elsif ( $ccheck eq "Address Wrong" ) {
                $handler->{data}{orders}{addrwrong} = "checked";
            }
            elsif ( $ccheck eq "Name OK" ) {
                $handler->{data}{orders}{nameok} = "checked";
            }
            elsif ( $ccheck eq "Name Wrong" ) {
                $handler->{data}{orders}{namewrong} = "checked";
            }
            elsif ( $ccheck eq "Possible Fraud" ) {
                $handler->{data}{orders}{possiblefraud} = "checked";
            }
        }
    }

    $handler->{data}{orders}{cv2_avs}       = $cv2_avs;
    $handler->{data}{orders}{warningFlags}  = \@warnings;
    $handler->{data}{orders}{categoryFlags} = \@categories;
    return;
}

sub _process_post {
    my ( $handler ) = @_;

    my $redirect_url;

    # credit check flags
    if ( $handler->{param_of}{ccheck_flags} ) {
        _update_credit_check_flags( $handler);
    }

    # reprint docs
    if ( $handler->{param_of}{reprint} ) {
        _reprint_document( $handler );
    }

    # print pick docs
    if ( $handler->{param_of}{pick_print} ) {
        _print_pick_document( $handler );
    }

    # premier customer notes
    if ( $handler->{param_of}{premier_notes} ) {
        _set_premier_notes( $handler );
    }

    # validating a pre-auth
    if ( $handler->{param_of}{validate_preauth} ) {

        #Update 'valid' flag to TRUE in orders.payment table
        my $order = $handler->{data}{order};
        $order->discard_changes()->payments->validate;

        xt_success( "Order: " . $handler->{data}{order}->order_nr . " was successfully removed from the Invalid Payment queue" );
        if ( $handler->{data}{short_url} =~ m{Finance/InvalidPayments} ) {
            # came from the Finance->Invalid Payments list so
            # want to go back there to get the next one to do
            # and also take the user to the same Sales Channel
            $redirect_url   = $handler->{data}{short_url} . '?show_channel=' . $handler->{data}{order}->channel_id;
        }
    }

    # toggling the Payment Fulfilled Flag
    if ( $handler->{param_of}{fulfill_payment} ) {
        my $payment_id  = $handler->{param_of}{payment_id};
        toggle_payment_fulfilled_flag_and_log( $handler->{schema}, $payment_id, $handler->{data}{operator_id}, 'Manual Toggle via Order View Page' );
    }

    # Request Virtual Voucher Codes
    if ( $handler->{param_of}{request_virtual_codes} ) {
        my $schema  = $handler->{schema};
        my $shipment= $schema->resultset('Public::Shipment')->find( $handler->{param_of}{request_shipment_id} );
        $handler->msg_factory->transform_and_send( 'XT::DC::Messaging::Producer::Order::VirtualVoucherCode', $shipment );
        xt_success( "Virtual Voucher Codes have been Requested. Please wait a few minutes for them to be assigned." );
    }

    # Edit Delivery Signature Flag
    if ( ( my $shipment_id = $handler->{param_of}{edit_delivery_signature_flag_shipment_id} )
        && $handler->{data}{has_delivery_signature_optout} ) {
        my $schema  = $handler->schema;
        eval {
            $schema->txn_do( sub {
                my $order       = $handler->{data}{order};
                my $shipment    = $order->shipments->find( $shipment_id );

                # check the Delivery Flag on the Shipment can still be edited
                if ( $shipment->can_edit_signature_flag ) {

                    if ( $shipment->update_signature_required( $handler->{param_of}{signature_flag}, $handler->operator_id ) ) {

                        # check if 'no' option is passed, when not allowed
                        if( ! $handler->{data}{can_opt_out_of_requiring_a_delivery_signature} && $handler->{param_of}{signature_flag} == 0 ) {
                              xt_warn("Couldn't update 'Signature upon Delivery' flag because the 'NO' option is not allowed");
                         }  else {
                            # only get here if the new value was different to the old
                            $order->put_on_credit_hold_for_signature_optout( $shipment, $handler->operator_id );
                            xt_success( "Shipment: $shipment_id, 'Signature upon Delivery' flag has been Updated to: "
                                        . ( $handler->{param_of}{signature_flag} ? 'Yes' : 'No' ) );
                        }
                    }
                }
                else {
                    xt_warn( "Couldn't update 'Signature upon Delivery' flag because the flag can't be updated any more" );
                }
            } );
        };
        if ( my $err = $@ ) {
            xt_warn( "Shipment: $shipment_id, problem trying to update 'Signature upon Delivery' flag, No Changes made.<br/>$err" );
        }
    }

    # Update Order Contact Options
    if ( exists( $handler->{param_of}{update_order_contact_options} ) ) {
        my $schema      = $handler->schema;
        my $csm_changes = unpack_csm_changes_params( $handler->{param_of} );
        eval {
            my $order   = $handler->{data}{order}->discard_changes;
            $schema->txn_do( sub {
                my $any_changes = 0;
                foreach my $subject_id ( keys %{ $csm_changes } ) {
                    $any_changes    += $order->ui_change_csm_available_by_subject( $subject_id, $csm_changes->{ $subject_id } );
                }
                if ( $any_changes ) {
                    xt_success( "Order Contact Options Updated" );
                    # make sure the area on the page that was edited is not hidden
                    $handler->{data}{auto_show}{'OrderContactOptionsDiv'}   = 1;
                }
            } );
        };
        if ( my $err = $@ ) {
            xt_warn( "Couldn't Update Order Contact Options.<br/>$err" );
        }
    }

    if ( exists( $handler->{param_of}{send_order_status_message} ) ) {
        my $order = $handler->{data}{order};
        eval {
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::Orders::Update',
                { order => $order },
            );
            xt_success( "Order Status Message Sent" );
        };
        if ( my $err = $@ ) {
            xt_warn( "Couldn't Send Order Status Message" );
            xt_warn( $err );
        }
    }

    return $redirect_url;
}

sub _update_credit_check_flags {
    my ( $handler ) = @_;

    my $checkname = $handler->{param_of}{checkname};
    my $checkaddr = $handler->{param_of}{checkaddr};
    my $possfraud = $handler->{param_of}{possible_fraud};

    _get_order_flags( $handler );

    my $dbh = $handler->{dbh};
    my $data = $handler->{data};

    # updating possible fraud flag
    if ( defined $possfraud && $possfraud eq "yes" ) {
        if ( $data->{orders}{possiblefraud} ne "checked" ) {
            set_order_flag( $dbh, $data->{orders_id}, $FLAG__POSSIBLE_FRAUD );
        }
    }
    else {
        if ( $data->{orders}{possiblefraud} eq "checked" ) {
            delete_order_flag( $dbh, $data->{orders_id}, $FLAG__POSSIBLE_FRAUD );
        }
    }

    ## UPDATING NAME INFO
    if ( defined $checkname && $checkname eq "yes" ) {
        if ( $data->{orders}{nameok} ne "checked" ) {
            set_order_flag( $dbh, $data->{orders_id}, $FLAG__NAME_OK );
        }
        if ( $data->{orders}{namewrong} eq "checked" ) {
            delete_order_flag( $dbh, $data->{orders_id}, $FLAG__NAME_WRONG );
        }
    }
    elsif ( defined $checkname && $checkname eq "no" ) {
        if ( $data->{orders}{namewrong} ne "checked" ) {
            set_order_flag( $dbh, $data->{orders_id}, $FLAG__NAME_WRONG );
        }
        if ( $data->{orders}{nameok} eq "checked" ) {
            delete_order_flag( $dbh, $data->{orders_id}, $FLAG__NAME_OK );
        }
    }

    ## UPDATING ADDRESS INFO
    if ( defined $checkaddr && $checkaddr eq "yes" ) {
        if ( $data->{orders}{addrok} ne "checked" ) {
            set_order_flag( $dbh, $data->{orders_id}, $FLAG__ADDRESS_OK );
        }
        if ( $data->{orders}{addrwrong} eq "checked" ) {
            delete_order_flag( $dbh, $data->{orders_id}, $FLAG__ADDRESS_WRONG );
        }
    }
    elsif ( defined $checkaddr && $checkaddr eq "no" ) {
        if ( $data->{orders}{addrwrong} ne "checked" ) {
            set_order_flag( $dbh, $data->{orders_id}, $FLAG__ADDRESS_WRONG );
        }
        if ( $data->{orders}{addrok} eq "checked" ) {
            delete_order_flag( $dbh, $data->{orders_id}, $FLAG__ADDRESS_OK );
        }
    }
    return;
}

sub _get_hold_info {
    my ($dbh, $shipment_id) = @_;

    my $qry = "SELECT sh.shipment_hold_reason_id, sh.comment, to_char(sh.hold_date, 'DD-MM-YYYY HH24:MI') as hold_date, to_char(sh.release_date, 'DD-MM-YYYY HH24:MI') as release_date, to_char(sh.release_date, 'DD') as release_day, to_char(sh.release_date, 'MM') as release_month, to_char(sh.release_date, 'YYYY') as release_year, shr.reason, o.name  FROM shipment_hold sh, shipment_hold_reason shr, operator o
    WHERE sh.shipment_id = ?
    AND sh.shipment_hold_reason_id = shr.id
    AND sh.operator_id = o.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $data = $sth->fetchrow_hashref();
    return $data;
}

sub _get_notice_message {
    my ( $notice_id ) = @_;

    my %messages = (
        1 =>
        "There was a problem trying to change the status of the shipment, please check that the current status of the shipment allows you to make the change you require.",
        2 => "Error message 2",
        3 => "Error message 3",
        4 => "Error message 4",
        5 =>
        "There was a problem trying to change the status of the items selected, please check that the current status of those items allows you to make the change you require.",
        6 =>
        "There was a problem trying to change the status of the items selected, some information was missing.",
    );
    return $messages{ $notice_id };
}

sub _reprint_document {
    my ( $handler ) = @_;

    my $result;

    if ($handler->{param_of}{reprint} =~ /giftmessage/) {

        try {
            $result = print_document(
                $handler->{param_of}{reprint},
                $handler->{param_of}{printer},
                1, # copies
                undef, # header
                undef, # footer
                1, # really print file
                0, # delete file afterwards
                'A6', # page_size
                'Landscape', # paper orientation
            );
        } catch {
            xt_logger->warn("Unable to reprint gift message from order view page: $_");
            xt_warn("Unable to reprint gift message from order view page: $_");
            $result = 0;
        };
    } else {
        $result = print_document(
            $handler->{param_of}{reprint},
            $handler->{param_of}{printer},
            1 # copies
        );
    }

    if ( not defined $result or $result != 1 ) {
        $handler->{data}{notice_message} = 'There was a problem trying to re-print the document selected, please try again.';
    }
    return;
}

sub _print_pick_document {
    my ( $handler ) = @_;

    if ($handler->{param_of}{pick_print} eq 'AddressCard') {
        generate_address_card(
            $handler->schema->storage->dbh,
            $handler->{param_of}{shipment_id},
            $handler->{param_of}{printer},
            1
        );
    } elsif ($handler->{param_of}{pick_print} eq 'GiftMessage') {
        my $shipment_id = $handler->{param_of}{shipment_id};
        my $shipment = $handler->schema->resultset('Public::Shipment')->find($shipment_id);
        try {
            $shipment->print_gift_messages($handler->{param_of}{printer});
        } catch {
            xt_logger->warn("Unable to generate gift messages pick document $_");
            xt_warn("Unable to print gift messages");
        };
    } else {
        die "I don't know how to print a " . $handler->{param_of}{pick_print};
    }
}

sub _set_premier_notes {
    my ($handler) = @_;

    my $qry = "update customer set legacy_comment = ? where id = (select customer_id from orders where id = ?)";
    my $sth = $handler->{dbh}->prepare($qry);
    $sth->execute($handler->{param_of}{premier_notes}, $handler->{param_of}{order_id});
    return;
}

sub _d2 {
    # clear up some warnings in the log
    my $value   = shift;
    $value      = 0     if ( !defined $value );
    return sprintf( "%.2f", $value );
}

1;
