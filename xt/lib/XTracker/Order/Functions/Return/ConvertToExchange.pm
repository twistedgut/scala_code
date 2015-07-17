package XTracker::Order::Functions::Return::ConvertToExchange;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database qw( get_database_handle );
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Return;
use XTracker::Database::Invoice;
use XTracker::Database::Stock qw( :DEFAULT get_saleable_item_quantity );
use XTracker::Database::Product qw( :DEFAULT get_product_id );
use XTracker::EmailFunctions;
use XTracker::Error qw( xt_warn );
use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :shipment_status :correspondence_templates :pws_action :refund_charge_type );
use XTracker::Config::Local qw( returns_email localreturns_email );
use XTracker::Database::Channel qw(get_channel_details);
use DateTime;

sub handler {
    ## no critic(ProhibitDeepNests)

    my $r = shift;

    my $handler = XTracker::Handler->new($r);
    my $schema  = $handler->{schema};
    my $dbh     = $schema->storage->dbh;


    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}           = $section;
    $handler->{data}{subsection}        = $subsection;
    $handler->{data}{subsubsection}     = 'Convert Return Items To Exchange';
    $handler->{data}{content}           = 'ordertracker/returns/converttoexchange.tt';
    $handler->{data}{short_url}         = $short_url;

    # get order_id, shipment_id and return_id from URL
    $handler->{data}{order_id}      = $handler->{param_of}{order_id};
    $handler->{data}{shipment_id}   = $handler->{param_of}{shipment_id};
    $handler->{data}{return_id}     = $handler->{param_of}{return_id};


    if ( $handler->{data}{return_id} ) {

        push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back to Return', 'url' => "$short_url/Returns/View?order_id=$handler->{data}{order_id}&shipment_id=$handler->{data}{shipment_id}&return_id=$handler->{data}{return_id}" } );

        $handler->{data}{order_info}        = get_order_info( $dbh, $handler->{data}{order_id} );
        $handler->{data}{channel}           = get_channel_details( $dbh, $handler->{data}{order_info}{sales_channel} );
        $handler->{data}{sales_channel}     = $handler->{data}{order_info}{sales_channel};

        $handler->{data}{shipment_info}     = get_shipment_info( $dbh, $handler->{data}{shipment_id} );
        $handler->{data}{shipment_address}  = get_address_info( $dbh, $handler->{data}{shipment_info}{shipment_address_id} );
        $handler->{data}{shipment_items}    = get_shipment_item_info( $dbh, $handler->{data}{shipment_id} );

        $handler->{data}{num_return_items}  = 0;
        $handler->{data}{return}            = get_return_info( $dbh, $handler->{data}{return_id} );
        $handler->{data}{return_items}      = get_return_item_info( $dbh, $handler->{data}{return_id}, "no_canceled" );

        # work out potential Tax & Duty charges
        _get_tax_duty_charges( $handler );

        foreach my $id ( keys %{ $handler->{data}{return_items} } ) {
            $handler->{data}{return_items}{$id}{return_item_status_id} ||= "";
            if ( $handler->{data}{return_items}{$id}{return_item_status_id} && $handler->{data}{return_items}{$id}{return_item_status_id} < 9 ) {
                $handler->{data}{num_return_items}++;
                $handler->{data}{return_items}{ $id }{sizes} = get_exchange_variants( $dbh, $handler->{data}{return_items}{$id}{shipment_item_id} );

            }

        }

        if ( $handler->{param_of}{select_item} ) {

            ####################
            ### GATHER FORM DATA
            ####################

            $handler->{data}{num_remove_items} = 0;


            # loop over form post and get data
            # return items into a format we can use
            foreach my $form_key ( keys %{ $handler->{param_of} } ) {
                if ( $form_key =~ m/-/ ) {
                    my ($field_name, $return_item_id, $invoice_item_id) = split( /-/, $form_key );

                    if ( $field_name eq "item" ) {
                        if ( $handler->{param_of}{$form_key} == 1 ) {
                            $handler->{data}{return_items}{ $return_item_id }{remove} = 1;
                            $handler->{data}{num_remove_items}++;
                        }
                        else {
                            $handler->{data}{return_items}{ $return_item_id }{remove} = 0;
                        }
                    }

                    if ( $field_name eq "exch" ) {
                        ($handler->{data}{return_items}{ $return_item_id }{exch_variant},$handler->{data}{return_items}{ $return_item_id }{exch_size}) = split(/-/, $handler->{param_of}{ "exch-" . $return_item_id } );
                    }

                    if ( $field_name eq "amend_invoice" ) {
                        (   $handler->{data}{amend_invoice}{ $return_item_id }{refund_type_id}, $handler->{data}{amend_invoice}{ $return_item_id }{refund_type} ) = split( /-/, $handler->{param_of}{ "amend_refund_type-" . $return_item_id } );
                    }

                    if ( $field_name eq "amend_invoice_item" ) {
                        $handler->{data}{amend_invoice}{ $return_item_id }{items}{ $invoice_item_id }{convert} = 1;
                    }

                    if ( $field_name eq "amend_invoice_price" ) {
                        $handler->{data}{amend_invoice}{ $return_item_id }{items}{ $invoice_item_id }{unit_price} = $handler->{param_of}{$form_key};
                    }

                    if ( $field_name eq "amend_invoice_tax" ) {
                        $handler->{data}{amend_invoice}{ $return_item_id }{items}{ $invoice_item_id }{tax} = $handler->{param_of}{$form_key};
                    }

                    if ( $field_name eq "amend_invoice_duty" ) {
                        $handler->{data}{amend_invoice}{ $return_item_id }{items}{ $invoice_item_id }{duty} = $handler->{param_of}{$form_key};
                    }

                    if ( $field_name eq "create_invoice_item" ) {
                        $handler->{data}{create_invoice}{items}{ $return_item_id }{invoice_id} = $handler->{param_of}{$form_key};
                    }

                    if ( $field_name eq "create_invoice_price" ) {
                        $handler->{data}{create_invoice}{items}{ $return_item_id }{unit_price} = $handler->{param_of}{$form_key};
                    }

                    if ( $field_name eq "create_invoice_tax" ) {
                        $handler->{data}{create_invoice}{items}{ $return_item_id }{tax} = $handler->{param_of}{$form_key};
                    }

                    if ( $field_name eq "create_invoice_duty" ) {
                        $handler->{data}{create_invoice}{items}{ $return_item_id }{duty} = $handler->{param_of}{$form_key};
                    }
                }
            }


            $handler->{data}{pickup}    = $handler->{param_of}{pickup};
            $handler->{data}{notes}     = $handler->{param_of}{notes};
            ( $handler->{data}{create_invoice}{refund_type_id}, $handler->{data}{create_invoice}{refund_type} ) = split( /-/, $handler->{param_of}{create_invoice_refund_type}||"" );
            $handler->{data}{cur_invoice}   = $handler->{param_of}{cur_invoice};
            $handler->{data}{invoices}      = get_return_invoice( $dbh, $handler->{data}{return_id} );


            foreach my $inv_id ( keys %{ $handler->{data}{invoices} } ) {

                $handler->{data}{invoices}{$inv_id}{items} = get_invoice_item_info( $dbh, $inv_id );

                foreach my $inv_item_id ( keys %{ $handler->{data}{invoices}{$inv_id}{items} } ){

                    if ( $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{unit_price} != 0 ){
                        $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{unit_price} = $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{unit_price} * -1;
                    }

                    if ( $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{tax} != 0 ){
                        $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{tax} = $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{tax} * -1;
                    }

                    $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{tax} += $handler->{data}{shipment_items}{$handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{shipment_item_id}}{charge_tax};

                    if ($handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{duty} != 0 ){
                        $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{duty} = $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{duty} * -1;
                    }

                    $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{duty} += $handler->{data}{shipment_items}{$handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{shipment_item_id}}{charge_duty};

                    foreach my $ret_item_id ( keys %{ $handler->{data}{return_items} } ){
                        if ( $handler->{data}{return_items}{$ret_item_id}{remove}
                            && ($handler->{data}{return_items}{$ret_item_id}{remove} == 1) ){
                            if ( $handler->{data}{invoices}{$inv_id}{items}{$inv_item_id}{shipment_item_id} == $handler->{data}{return_items}{$ret_item_id}{shipment_item_id} ){

                                if ( $handler->{data}{invoices}{$inv_id}{renumeration_status_id} < 4 ){
                                    $handler->{data}{invoice_remove}{$inv_id}{$inv_item_id} = 1;
                                }
                                elsif ( $handler->{data}{invoices}{$inv_id}{renumeration_status_id} < 6 ){
                                    $handler->{data}{invoice_create}{$inv_item_id} = $inv_id;
                                }

                            }
                        }
                    }
                }
            }

            $handler->{data}{email_info} = $handler->domain('Returns')->render_email(
                {
                  return_id => $handler->{data}{return_id},
                  return_items => $handler->{data}{return_items},
                },
                $CORRESPONDENCE_TEMPLATES__CONVERT_TO_EXCHANGE
            );


            #####################
            ### UPDATE RETURN ###
            #####################
            if ( $handler->{param_of}{completed} ) {

                # Remember whether IWS knows about shipment now, before we start cancelling shipment items
                my $return = $schema->resultset('Public::Return')->find( $handler->{data}->{return_id} );
                my $exchange_shipment = $return && $return->exchange_shipment;
                my $iws_knows = $exchange_shipment && $exchange_shipment->does_iws_know_about_me();

                my $cancel_exchange;
                eval {
                    my $txn = $schema->txn_scope_guard;

                    my $data = $handler->{data};
                    my $ris = $data->{return_items};
                    for (keys %$ris) {
                        delete $ris->{$_}{sizes};
                        $ris->{$_}{reason_id} = delete $ris->{$_}{customer_issue_type_id};
                        $ris->{$_}{exchange_variant} = delete $ris->{$_}{exch_variant};

                        delete $ris->{$_} unless $ris->{$_}{remove};
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

                    $data->{email_template_id} = $CORRESPONDENCE_TEMPLATES__CONVERT_TO_EXCHANGE;

                    $cancel_exchange = $handler->domain('Returns')->convert_items({ %$data });

                    $txn->commit;
                };

                if ($@) {
                    $handler->{data}{error_msg} = 'An error occurred whilst trying to convert the return: ' . $@;
                }
                else {
                    # Send messages to IWS now that we have committed transaction
                    $handler->domain('Returns')->send_msgs_for_exchange_items( $exchange_shipment )
                        if $cancel_exchange && $iws_knows;

                    $handler->{data}{display_msg} = 'Return successfully converted.';
                }

            }

        }
        else {
            $handler->{data}{reasons} = $schema->resultset('Public::CustomerIssueType')->return_reasons_for_rma_pages;
        }

    }
    else {
        warn "hit evil dangling else case - should never get here?";

    }

    return $handler->process_template( undef );
}

# work out any potential Tax & Duty Charges for each Item
sub _get_tax_duty_charges {
    my $handler     = shift;

    my $ship_country= get_dbic_country( $handler->{schema}, $handler->{data}{shipment_address}{country} );

    foreach my $id ( keys %{ $handler->{data}{shipment_items} } ) {

        # don't charge extra tax and duty for countries who have tax refunded OR for faulty items
        # FIXME/XXX: replace these with constants from Constants::FromDB
        if ( $handler->{data}{return_items}{ $id }{reason}
            && ($handler->{data}{return_items}{ $id }{reason} eq "Incorrect item" || $handler->{data}{return_items}{ $id }{reason} eq "Defective/faulty") ) {
            $handler->{data}{shipment_items}{ $id }{charge_tax}     = "0.00";
            $handler->{data}{shipment_items}{ $id }{charge_duty}    = "0.00";
        }
        else {
            # assume we charge both Tax & Duties
            my $tax     = $handler->{data}{shipment_items}{ $id }{tax};
            my $duty    = $handler->{data}{shipment_items}{ $id }{duty};

            # check based on Shipping Country as to whether Tax &/or Duties should NOT be Charged
            if ( $ship_country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX ) ) {
                $tax    = '0.00';
            }
            if ( $ship_country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__DUTY ) ) {
                $duty   = '0.00';
            }

            $handler->{data}{shipment_items}{ $id }{charge_tax}     = -$tax;
            $handler->{data}{shipment_items}{ $id }{charge_duty}    = -$duty;
        }

    }

    return;
}

1;
