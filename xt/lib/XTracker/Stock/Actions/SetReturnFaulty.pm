package XTracker::Stock::Actions::SetReturnFaulty;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database;
use XTracker::Database::Return qw( release_return_invoice auto_refund_to_customer );
use XTracker::Database::Invoice qw( adjust_existing_renum_tenders );
use XTracker::Error;
use Try::Tiny;

use feature ':5.14';

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $uri_path = $handler->{r}->parsed_uri->path;

    my $operator_id = $handler->operator_id;

    my $redirect_uri = URI->new('/GoodsIn/ReturnsFaulty');

    # No PGID - return to overview page
    my $pgid = $handler->{param_of}{process_group_id};
    return $handler->redirect_to( $redirect_uri ) unless $pgid;

    # Nothing to do - redirect to pgid view page
    my $decision = $handler->{param_of}{decision};
    unless ( $decision ) {
        $redirect_uri->query_form({process_group_id => $pgid});
        return $handler->redirect_to( $redirect_uri );
    }

    my $schema = $handler->schema;

    # In practice all returns have a 1-1 relationship between pgids and stock
    # process ids
    my @stock_processes = $schema->resultset('Public::StockProcess')->search({
        group_id => $pgid
    })->all;
    # ... but let's double-check
    if ( !@stock_processes ) {
        xt_warn( "Could not find pgid $pgid" );
        return $handler->redirect_to( $redirect_uri );
    }
    if ( @stock_processes > 1 ) {
        xt_warn( "Found more than one item in pgid $pgid" );
        return $handler->redirect_to( $redirect_uri );
    }

    my $msg_factory = $handler->msg_factory;
    my ($return, $stock_manager);
    eval{
        # In this transaction we lock the return_item row ASAP to prevent
        # concurrent updates
        my $guard = $schema->txn_scope_guard;

        my $stock_process = $stock_processes[0];
        my $return_item = $schema->resultset('Public::ReturnItem')->find(
            $stock_process->return_item->id,
            { for => 'update' }
        );
        $return = $return_item->return;

        my ( $fault_type_id, $fault_description )
            = @{$handler->{param_of}}{qw/ddl_item_fault_type fault_description/};

        $stock_manager = $return_item->variant->current_channel->stock_manager;
        my ( $renums_to_adjust, $feedback );
        SMARTMATCH: {
            use experimental 'smartmatch';
            given ( $decision ) {
                when ( 'accept' ) {
                    $return_item->accept_failed_qc( $operator_id );
                    $feedback = "PGID $pgid accepted";
                }
                when ( 'reject' ) {
                    $renums_to_adjust = $return_item->reject_failed_qc( $stock_manager, $operator_id );
                    $feedback = "PGID $pgid rejected";
                }
                when ( 'rtv_repair' ) {
                    $return_item->send_to_rtv_customer_repair({
                        fault_description => $fault_description,
                        fault_type_id => $fault_type_id,
                        uri_path => $uri_path,
                        amq => $msg_factory,
                        operator_id => $operator_id,
                    });
                    $feedback = "PGID $pgid sent to RTV repair";
                }
                when ( 'rts' ) {
                    $return_item->set_failed_qc_fixed($operator_id);
                    $stock_process->send_to_main( 'returns', $msg_factory );
                    $feedback = "PGID $pgid sent to main stock";
                }
                when ( 'rtv' ) {
                    $return_item->set_failed_qc_rtv($operator_id);
                    $stock_process->send_to_rtv({
                        fault_description => $fault_description,
                        fault_type_id => $fault_type_id,
                        uri_path => $uri_path,
                        amq => $msg_factory,
                        origin => 'returns',
                    });
                    $feedback = "PGID $pgid sent to RTV";
                }
                when ( 'rtc' ) {
                    $return_item->return_to_customer( $operator_id );
                    $feedback = "PGID $pgid returned to customer";
                }
                when ( 'dead' ) {
                    $return_item->set_failed_qc_deadstock($operator_id);
                    $stock_process->send_to_dead( 'returns', $msg_factory );
                    $feedback = "PGID $pgid sent to dead";
                }
                default {
                    die "Unknown action '$_'\n";
                }
            }
        }

        # We do some adjustments in here, and remove them from
        # $renums_to_adjust so we don't do them twice
        _release_pending_invoices( $return, $renums_to_adjust, $msg_factory, $operator_id )
            if $decision ne "rtv_repair";

        # sla is applied to exchange when return is accepted
        $return->exchange_shipment->apply_SLAs
            if $return->exchange_shipment && $decision eq "accept";

        # THIS has been moved here because otherwise it interferes with
        # 'release_return_invoice' and ends up hanging because it locks the
        # 'renumeration' table. (CANDO-478)
        _update_renum_tenders( $schema, $renums_to_adjust );
        $stock_manager->commit;
        $guard->commit;
        xt_success( $feedback );
    };

    if( my $error = $@ ){
        $stock_manager->rollback;
        xt_warn($error);
        $redirect_uri->query_form({process_group_id => $pgid});
        return $handler->redirect_to( $redirect_uri );

    }
    eval {
        # can't throw an error if this doesn't work as it doesn't really have
        # anything to do with processing Faulty returns but rather the
        # Auto-Refunding of Customer's, so not a complete disaster if this
        # message fails
        if ( $return->shipment && $return->shipment->order ) {
            my $order = $return->shipment->order;
            $msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::Orders::Update',
                { order_id => $order->id, }
            );
        }
    };

    # redirect back
    SMARTMATCH: {
        use experimental 'smartmatch';
        if ($decision ~~ [qw/accept reject/]) {
            $redirect_uri->query_form({process_group_id => $pgid})
        }
    }

    return $handler->redirect_to( $redirect_uri );
}

sub _release_pending_invoices {
    my ( $return, $renums_to_adjust, $msg_factory, $operator_id ) = @_;

    ### check if return now fully complete
    my ($is_complete, $exchange_complete)
        = @{$return->check_complete}{qw/is_complete exchange_complete/};

    ### update return status
    $return->set_complete( $operator_id ) if $is_complete;

    ### release any pending invoices
    my $schema = $return->result_source->schema;
    my @invoice_ids = release_return_invoice( $schema, $return->id );
    if ( @invoice_ids ) {
        my $separate_dbh = XTracker::Database::xtracker_schema_no_singleton->storage->dbh;

        foreach my $invoice_id ( @invoice_ids ) {
            my $renumeration    = $schema->resultset('Public::Renumeration')->find( $invoice_id );

            # update the 'sent_to_psp' flag to prevent processing
            # things twice without manual intervention, hence it
            # uses it's own Database Conenction outside of the rest
            # of the Transaction.
            $renumeration->_isolated_update_sent_to_psp( 1, $separate_dbh );

            # clean up any renumeration tenders that need adjusting for the invoice one at a time
            if ( exists( $renums_to_adjust->{ $invoice_id } ) ) {
                _update_renum_tenders( $schema, { $invoice_id => delete( $renums_to_adjust->{ $invoice_id } ) } );
            }

            # refund the Customer
            auto_refund_to_customer( $schema, $msg_factory, $renumeration->discard_changes, $operator_id, { no_reset_psp_update => 1 } );
        }

        $separate_dbh->disconnect();
    }

    return unless ( $return->exchange_shipment_id && $exchange_complete );
    ### got an exchange and its ready for release
    $_->is_on_return_hold && $_->set_status_processing( $operator_id )
        for $return->exchange_shipment;
}

# _update_renum_tenders
# this function will update any renumeration tenders
# that need to be adjusted after 'renumeration_item'
# records being deleted.
sub _update_renum_tenders {
    my ( $schema, $renums_to_adjust )  = @_;

    # adjust any Renumeration Tender Values
    # as a result of 'Rejects'
    while ( my ( $id, $new_value ) = each %{ $renums_to_adjust } ) {
        my $renum       = $schema->resultset('Public::Renumeration')->find( $id );
        adjust_existing_renum_tenders( $renum, ($new_value < 0) ? 0 : $new_value );
    }

    return;
}

1;
