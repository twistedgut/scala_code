package XTracker::Order::Functions::Return::ConvertFromExchange;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database qw( get_database_handle );
use XTracker::Database::Order;
use XTracker::Database::Shipment qw( :DEFAULT );
use XTracker::Database::Address;
use XTracker::Database::Return qw( :DEFAULT release_return_invoice_to_customer auto_refund_to_customer );
use XTracker::Database::Invoice;
use XTracker::Database::Stock;
use XTracker::Database::Product;
use XTracker::EmailFunctions;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::Utilities     qw( parse_url number_in_list );
use XTracker::Config::Local qw( returns_email localreturns_email );
use XTracker::Constants::FromDB qw( :renumeration_class :renumeration_status :renumeration_type :shipment_status :shipment_item_status :correspondence_templates :pws_action :refund_charge_type );
use XTracker::Error;

sub handler {

    my $r = shift;

    my $handler = XTracker::Handler->new($r);
    # ensure we use the same dbh else we dont the changes in the transaction
    my $schema  = $handler->schema;
    my $dbh     = $schema->storage->dbh;


    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}           = $section;
    $handler->{data}{subsection}        = $subsection;
    $handler->{data}{subsubsection}     = 'Convert Exchange Items To Returns';
    $handler->{data}{content}           = 'ordertracker/returns/convertfromexchange.tt';
    $handler->{data}{short_url}         = $short_url;

    # get order_id, shipment_id and return_id from URL
    $handler->{data}{order_id}      = $handler->{param_of}{order_id};
    $handler->{data}{shipment_id}   = $handler->{param_of}{shipment_id};
    $handler->{data}{return_id}     = $handler->{param_of}{return_id};

    return $handler->process_template unless $handler->{data}{return_id};

    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back to Return', 'url' => "$short_url/Returns/View?order_id=$handler->{data}{order_id}&shipment_id=$handler->{data}{shipment_id}&return_id=$handler->{data}{return_id}" } );

    $handler->{data}{return}                    = get_return_info( $dbh, $handler->{data}{return_id} );
    $handler->{data}{return_items}              = get_return_item_info( $dbh, $handler->{data}{return_id}, "no_canceled" );
    $handler->{data}{exchange_shipment}         = get_shipment_info( $dbh, $handler->{data}{return}{exchange_shipment_id} );
    $handler->{data}{exchange_shipment_items}   = get_shipment_item_info( $dbh, $handler->{data}{return}{exchange_shipment_id} );

    $handler->{data}{exchange_shipment}{num_items} = 0;
    $handler->{data}{exchange_shipment}{packed_items} = 0;

    foreach my $id ( keys %{ $handler->{data}{exchange_shipment_items} } ) {
        $handler->{data}{exchange_shipment}{num_items}++;

        if (number_in_list($handler->{data}{exchange_shipment_items}{$id}{shipment_item_status_id},
                            $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                            $SHIPMENT_ITEM_STATUS__PACKED,
                            $SHIPMENT_ITEM_STATUS__DISPATCHED,
                            $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                            $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                            $SHIPMENT_ITEM_STATUS__RETURNED,
                        ) ) {
            $handler->{data}{exchange_shipment}{packed_items}++;
        }
    }


    $handler->{data}{order_info}        = get_order_info( $dbh, $handler->{data}{order_id} );
    $handler->{data}{channel}           = get_channel_details( $dbh, $handler->{data}{order_info}{sales_channel} );
    $handler->{data}{sales_channel}     = $handler->{data}{order_info}{sales_channel};

    $handler->{data}{shipment_info}     = get_shipment_info( $dbh, $handler->{data}{shipment_id} );
    $handler->{data}{shipment_address}  = get_address_info( $dbh, $handler->{data}{shipment_info}{shipment_address_id} );
    $handler->{data}{shipment_items}    = get_shipment_item_info( $dbh, $handler->{data}{shipment_id} );


    # get all existing invoices and take value off value to be refunded
    my $invoices = get_shipment_invoices( $dbh, $handler->{data}{shipment_id} );

    # loop through invoices
    foreach my $inv_id ( keys %{ $invoices } ) {

        # its a refund and its not cancelled - take it into account
        if ( ($invoices->{$inv_id}{renumeration_type_id} == $RENUMERATION_TYPE__STORE_CREDIT || $invoices->{$inv_id}{renumeration_type_id} == $RENUMERATION_TYPE__CARD_REFUND) && $invoices->{$inv_id}{renumeration_status_id} != $RENUMERATION_STATUS__CANCELLED){

            # get invoice items
            my $items = get_invoice_item_info( $dbh, $inv_id);

            foreach my $item_id ( keys %{ $items } ) {

                # take value of refund off shipment item value
                $handler->{data}{shipment_items}{ $items->{$item_id}{shipment_item_id} }{unit_price}    -= $items->{$item_id}{unit_price};
                $handler->{data}{shipment_items}{ $items->{$item_id}{shipment_item_id} }{tax}           -= $items->{$item_id}{tax};
                $handler->{data}{shipment_items}{ $items->{$item_id}{shipment_item_id} }{duty}          -= $items->{$item_id}{duty};
            }

        }
    }

    $handler->{data}{current_invoices} = get_return_invoice( $dbh, $handler->{data}{return_id} );

    foreach my $inv_id ( keys %{ $handler->{data}{current_invoices} } ) {
        if ($handler->{data}{current_invoices}{$inv_id}{renumeration_status_id} < $RENUMERATION_STATUS__PRINTED){

            $handler->{data}{current_invoice_items} = get_invoice_item_info( $dbh, $inv_id );

            foreach my $id ( keys %{ $handler->{data}{current_invoice_items} } ) {

                foreach my $retid ( keys %{ $handler->{data}{return_items} } ) {
                    if ( $handler->{data}{current_invoice_items}{$id}{shipment_item_id} == $handler->{data}{return_items}{$retid}{shipment_item_id} ){
                        $handler->{data}{return_items}{ $retid }{current_invoice_item} = $id;
                    }
                }
            }

            $handler->{data}{current_invoice}        = $handler->{data}{current_invoices}{$inv_id};
            $handler->{data}{current_invoice}{id}    = $inv_id;

        }
    }

    # get the possible unit, tax and duty refunds for each item
    _get_unit_tax_duty_refunds( $handler );

    unless ( $handler->{param_of}{select_item} ) {
        $handler->{data}{reasons} = $schema->resultset('Public::CustomerIssueType')->return_reasons_for_rma_pages;
        return $handler->process_template;
    }

    ########
    # GATHER FORM DATA
    ########

    $handler->{data}{num_changed_items} = 0;
    $handler->{data}{new_refund_total}  = 0;


    # loop over form post and get data
    # return items into a format we can use
    foreach my $form_key ( keys %{ $handler->{param_of} } ) {
        if ( $form_key =~ m/-/ ) {
            my ($field_name, $return_item_id) = split( /-/, $form_key );

            if ( $field_name eq 'item' ) {
                if ( $handler->{param_of}{$form_key} == 1 ) {
                    $handler->{data}{num_changed_items}++;

                    $handler->{data}{return_items}{ $return_item_id }{change}                = 1;

                    # EN-1529: Need to set these 2 arguments so that they can be copied over
                    #          to the new Return when it gets created to replace the Exchange.
                    #          The previously existing above key {change} will be used to tell
                    #          Domain::Returns to use these arguments when creating the Return Item
                    $handler->{data}{return_items}{ $return_item_id }{current_status_id}     = $handler->{data}{return_items}{ $return_item_id }{return_item_status_id};
                    $handler->{data}{return_items}{ $return_item_id }{current_return_awb}    = $handler->{data}{return_items}{ $return_item_id }{return_airway_bill};

                    my $r_item = $schema->resultset('Public::ReturnItem')->find($return_item_id);
                    $handler->{data}{return_items}{ $return_item_id }{current_exchange_item} = $r_item->get_uncancelled_exchange_shipment_item;
                    $handler->{data}{new_refund_total}                                       += $handler->{data}{return_items}{ $return_item_id }{refund_unit} + $handler->{data}{return_items}{ $return_item_id }{refund_tax} + $handler->{data}{return_items}{ $return_item_id }{refund_duty};
                }
                else {
                    $handler->{data}{return_items}{ $return_item_id }{change} = 0;
                }
            }
        }
    }

    $handler->{data}{change_refund_type} = 0;

    # check if renum type needs to change
    if (!$handler->{data}{current_invoice}{renumeration_type_id}){
        $handler->{data}{change_refund_type} = 1;
    }
    elsif ($handler->{data}{current_invoice}{renumeration_type_id} == $RENUMERATION_TYPE__CARD_DEBIT){
        if ( ($handler->{data}{current_invoice}{total} + $handler->{data}{new_refund_total}) > 0){
            $handler->{data}{change_refund_type} = 1;
        }
    }

    $handler->{data}{email_info} = $handler->domain('Returns')->render_email(
        {
            return_id => $handler->{data}{return_id},
            return_items => $handler->{data}{return_items},
        },
        $CORRESPONDENCE_TEMPLATES__CANCEL_EXCHANGE
    );

    return $handler->process_template unless $handler->{param_of}{completed};

    #######
    # UPDATE RETURN #
    #######

    my $data = $handler->{data};
    my $ris = $data->{return_items};

    for (keys %$ris) {
        delete $ris->{$_}{sizes};
        $ris->{$_}{reason_id} = delete $ris->{$_}{customer_issue_type_id};
        $ris->{$_}{exchange_variant} = delete $ris->{$_}{exch_variant};
        $ris->{$_}{remove} = 1;

        delete $ris->{$_} unless $ris->{$_}{change};
    }

    $data->{$_} = $handler->{param_of}{$_} for qw/
        email_body
        email_from
        email_to
        email_replyto
        email_subject
        email_content_type
    /;

    $data->{send_email} = ( $handler->{param_of}{send_email} // 'no' ) eq 'yes';

    $data->{email_template_id} = $CORRESPONDENCE_TEMPLATES__CANCEL_EXCHANGE;

    my $stock_manager = $schema->resultset('Public::Shipment')
                               ->find($handler->{data}{shipment_id})
                               ->get_channel
                               ->stock_manager;
    my @invoices_to_refund;

    # Remember whether IWS knows about shipment now, before we start cancelling shipment items
    my $return = $schema->resultset('Public::Return')->find( $handler->{data}->{return_id} );
    my $exchange_shipment = $return && $return->exchange_shipment;
    my $iws_knows = $exchange_shipment && $exchange_shipment->does_iws_know_about_me();

    my $cancel_exchange;
    eval {
        my $txn = $schema->txn_scope_guard;
        $cancel_exchange =
            $handler->domain('Returns')->convert_items({
                %$data, stock_manager => $stock_manager,
            });
        # any Invoices that have been created by 'convert_items' and can be
        # released will be set to 'Awaiting Authorisation' and a list of those
        # IDs will be returned so that they can be Auto Refunded further down
        @invoices_to_refund = release_return_invoice_to_customer(
            $schema,
            $handler->msg_factory,
            $handler->{data}{return_id},
            $handler->operator_id,
            # can't Auto-Refund yet as the Invoices
            # created won't have been 'commited' yet
            { no_auto_refund => 1 },
        );
        $stock_manager->commit;
        $txn->commit;
        $handler->{data}{display_msg} = 'Return successfully converted.';
    };
    if ($@) {
        $stock_manager->rollback;
        xt_warn( "An error occurred whilst trying to convert the return: $@" );
    }
    else {
        # Send messages to IWS now that we have committed transaction
        $handler->domain('Returns')->send_msgs_for_exchange_items( $exchange_shipment )
            if $cancel_exchange && $iws_knows;

        # don't care if this works or not as if it fails the Renumeration's
        # will be cleaned up manually in the Active Invoices page
        eval {
            foreach my $invoice_id ( @invoices_to_refund ) {
                auto_refund_to_customer(
                    $schema,
                    $handler->msg_factory,
                    $schema->resultset('Public::Renumeration')->find( $invoice_id ),
                    $handler->{data}{operator_id},
                );
            }

            # if the refunds then got Auto-Refunded, send a message to the
            # web-site again telling it so
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::Orders::Update',
                { order_id => $handler->{data}{order_id} }
            );
        };
    }

    return $handler->process_template;
}

# get the possible unit, tax and duty refunds for each item
sub _get_unit_tax_duty_refunds {
    my $handler     = shift;

    my $ship_country= get_dbic_country( $handler->{schema}, $handler->{data}{shipment_address}{country} );

    foreach my $id ( keys %{ $handler->{data}{return_items} } ) {

        # unit price
        $handler->{data}{return_items}{ $id }{refund_unit} = $handler->{data}{shipment_items}{ $handler->{data}{return_items}{ $id }{shipment_item_id} }{unit_price};

        # refund tax and duty for certain "reasons" for return
        if ( $handler->{data}{return_items}{ $id }{reason} eq "Incorrect item" || $handler->{data}{return_items}{ $id }{reason} eq "Defective/faulty" ) {
            $handler->{data}{return_items}{ $id }{refund_tax}   = $handler->{data}{shipment_items}{ $handler->{data}{return_items}{ $id }{shipment_item_id} }{tax};
            $handler->{data}{return_items}{ $id }{refund_duty}  = $handler->{data}{shipment_items}{ $handler->{data}{return_items}{ $id }{shipment_item_id} }{duty};
        }
        # refund tax if required for country
        else {
            # assume we don't reund Tax or Duty
            $handler->{data}{return_items}{ $id }{refund_tax}   = "0.00";
            $handler->{data}{return_items}{ $id }{refund_duty}  = "0.00";

            # based on the Shipping Country check to see if we can refund Tax &/or Duties

            if ( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX ) ) {
                $handler->{data}{return_items}{ $id }{refund_tax}   = $handler->{data}{shipment_items}{ $handler->{data}{return_items}{ $id }{shipment_item_id} }{tax};
            }
            if ( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__DUTY ) ) {
                $handler->{data}{return_items}{ $id }{refund_duty}  = $handler->{data}{shipment_items}{ $handler->{data}{return_items}{ $id }{shipment_item_id} }{duty};
            }
        }
    }

    return;
}

1;
