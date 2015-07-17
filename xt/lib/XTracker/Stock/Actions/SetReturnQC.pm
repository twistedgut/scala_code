package XTracker::Stock::Actions::SetReturnQC;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::EmailFunctions;


use XTracker::Document::ReturnsLabel;
use XTracker::Database::Shipment qw(get_shipment_item_info);
use XTracker::Database::Return qw( release_return_invoice_to_customer auto_refund_to_customer );

use XTracker::Constants::FromDB qw(
    :delivery_status
    :return_item_status
    :return_status
    :shipment_item_status
    :shipment_status
    :stock_process_status
    :stock_process_type
);
use XTracker::Error;
use Data::Dump qw(pp);

use XT::LP;
use XTracker::PrinterMatrix;

use vars qw($operator_id);

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema   = $handler->schema;
    my $operator = $handler->operator;
    $operator_id = $operator->id;
    my $op_pref  = $operator->operator_preference;
    my $redirect = '/GoodsIn/ReturnsQC';

    return $handler->redirect_to($redirect)
        unless $handler->{param_of}{decision};

    my $order;
    my @invoices_to_refund;
    # qc items
    eval{
        my $guard = $schema->txn_scope_guard;

        # Acquire an exclusive row-level lock on the return to prevent a race
        # condition where on submitting the same page on two tabs, the first
        # submission updates the return's stock processes *after* the status
        # checks against them have been made, causing a stock duplication bug
        my $return = $schema->resultset('Public::Return')->find(
            { id => $handler->{param_of}{return_id} },
            { for => 'update' }
        );

        _qc_return($handler, $return, $op_pref );
        _split_and_complete($handler, $return);
        @invoices_to_refund = release_return_invoice_to_customer(
            $schema,
            $handler->msg_factory,
            $handler->{param_of}{return_id},
            $operator->id, { no_auto_refund => 1 }
        );

        # FIXME: It's a little hairy here - If the below conditional statement
        # fails and we roll back, we'll have refunded the customer (in a
        # separate dbh you'll see if you follow through the methods), but XT's
        # data will have rolled back. Frankly this is a mess and needs cleaning
        # up, but not doing this as part of the ticket I'm working on right
        # now.

        # Some returns (RTV, sample) won't have orders to go with them
        if ($return->shipment && $return->shipment->order) {
            $order = $return->shipment->order;
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::Orders::Update',
                { order_id => $order->id, }
            );
        }
        $guard->commit;
        xt_success("Quality control check completed successfully");
    };

    if ( my $err = $@ ) {
        xt_warn("The quality control check could not be completed: ${err}");
    }
    else {
        eval {
            # don't care if this works or not as if it fails
            # the Renumeration's will be cleaned up manually
            # in the Active Invoices page

            foreach my $invoice_id ( @invoices_to_refund ) {

                auto_refund_to_customer(
                    $schema,
                    $handler->msg_factory,
                    $schema->resultset('Public::Renumeration')->find( $invoice_id ),
                    $operator->id
                );
            }

            # if the refunds then got Auto-Refunded, send
            # a message to the web-site again telling it so
            $handler->msg_factory->transform_and_send(
                'XT::DC::Messaging::Producer::Orders::Update',
                { order_id => $order->id, }
            );
        };
    }

    # redirect to qc
    return $handler->redirect_to($redirect);
}

sub _qc_return {
    my ( $handler, $return, $op_pref ) = @_;

    my $postref     = $handler->{param_of};

    my $schema              = $handler->{schema};
    my $stock_process_rs    = $schema->resultset('Public::StockProcess');

    ### loop through booked in items
    foreach my $item ( keys %{$postref} ) {
        next unless $item =~ m{qc_(\d+)};
        my $sp_id = $1;

        my $stock_process = $stock_process_rs->find($sp_id);

        # This logic is taken from the template, which only displays the
        # pass/fail radio buttons if the stock process is of type 'Main' and
        # has a status of 'New' or 'Appproved' - hence the slightly complex use
        # of 'unless'.
        die sprintf(
            "SKU '%s' has already been processed\n",
            $stock_process->variant->sku
        ) unless( $stock_process->is_main
            && ($stock_process->is_new || $stock_process->is_approved)
        );

        my $delivery_item = $stock_process->delivery_item;
        my $return_item   = $delivery_item->get_return_item;

        if ( $postref->{$item} eq "pass" ) {
            _qc_passed( $handler, $return_item, $stock_process, $op_pref );
        }
        elsif ( $postref->{$item} eq "fail" ) {
            _qc_failed( $handler, $return_item, $stock_process, $op_pref );
        }

        $stock_process->update(
            { status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED },
        );

        $delivery_item->update_status(
            $sp_id,
            'stock_process_id',
            $DELIVERY_STATUS__PROCESSING
        );

        # Stock process is empty
        if ( not $stock_process->quantity ) {
            $stock_process->complete(1);
        }
        else {
            # this branch will only be taken if the return was
            # marked "passed",
            #
            # reason:
            #
            # - if you mark it "faulty", the _qc_failed sub will
            #   split 1 item off the stock_process
            #
            # - return SPs only have quantity 1 (they are linked
            #   to return_item and to shipment_item, which always
            #   represent a single item)
            #
            # - so after the split, *this* stock_process will have
            #   quantity == 0, and will be caught by the first
            #   branch of this 'if'
            $handler->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::PreAdvice',{
                sp => $stock_process
            });
        }

        # Print out stock labels
        if ( $handler->operator->operator_preference ) {
            my $printer_station_name = $handler->operator->operator_preference->printer_station_name;
            _print_stock_labels( $handler, $return_item, $sp_id, $printer_station_name );
        } else {
            die (sprintf('No preferences set for operator: %s', $handler->operator->username));
        }
    }
    return;
}

sub _qc_passed {
    my ( $handler, $return_item, $stock_process, $op_pref ) = @_;

    # Update return item status
    $return_item->update_status( $RETURN_ITEM_STATUS__PASSED_QC, $operator_id, );

    # Update shipment item status
    $return_item->shipment_item->update_status(
        $SHIPMENT_ITEM_STATUS__RETURNED,
        $operator_id,
    );

    # print off sub group returns labels
    if ( $handler->operator->operator_preference ) {
        my $location = $handler->operator->operator_preference->printer_station_name;
        _print_return_label($location, $stock_process->id);
    } else {
        die (sprintf('No preferences set for operator: %s', $handler->operator->username));
    }

    return;
}

sub _qc_failed {
    my ( $handler, $return_item, $stock_process, $op_pref ) = @_;

    # Update return item status
    $return_item->update_status(
        $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
        $operator_id
    );

    ##TODO: these should now go straight to 'RTV Workstation' location rather than...
    ###  split delivery
    my $faulty_group = 0;
    my $quantity     = 1;

    my $new_sp = $stock_process->split_stock_process(
        $STOCK_PROCESS_TYPE__FAULTY,
        $quantity,
        $faulty_group,
    );

    $stock_process->complete_stock_process();

    # print off sub group returns labels
    if ( $handler->operator->operator_preference ) {
        my $location = $handler->operator->operator_preference->printer_station_name;
        _print_return_label($location, $new_sp->id);
    } else {
        die (sprintf('No preferences set for operator: %s', $handler->operator->username));
    }

    return;
}

sub _split_and_complete {
    my ($handler, $return) = @_;

    # Split return to return a partial refund to the customer
    $return->split_if_needed;
    _complete_return( $handler->schema, $return );
    return;
}

sub _complete_return {
    my ( $schema, $return ) = @_;

    ### check if return now fully QC
    my $return_data = $return->check_complete;

    # Update return status
    if ( $return_data->{is_complete} ) {
        $return->update_status( $RETURN_STATUS__COMPLETE, $operator_id, );
    }

    my $exchange_shipment_id = $return->exchange_shipment_id;

    ### got an exchange and its ready for release
    if ( $exchange_shipment_id && $return_data->{exchange_complete} ) {
        my $shipment = $schema->resultset('Public::Shipment')->find(
            $exchange_shipment_id
        );

        ### shipment on hold - release it
        if ( $shipment->shipment_status_id == $SHIPMENT_STATUS__RETURN_HOLD ) {
            $shipment->update_status( $SHIPMENT_STATUS__PROCESSING, $operator_id );
        }
    }

    return;
}

sub _print_stock_labels {
    my ( $handler, $return_item, $sp_id, $location ) = @_;

    # Get the variant
    my $variant = $return_item->variant;

    # Print large labels if required
    if ( my $copies = $handler->{param_of}{"large-".$sp_id} ) {
        # This is a really ugly hack, but until the standardisation
        # on all DCs kicks in we will keep it this way
        my $date = $handler->{schema}->db_now;

        $variant->large_label($date)->print_at_location($location, $copies);
    }

    # Print small labels if required
    if ( my $copies = $handler->{param_of}{"small-".$sp_id} ) {
        $variant->small_label->print_at_location($location, $copies);
    }

    return;
}

sub _print_return_label {
    my ( $location, $stock_process_id ) = @_;

    XTracker::Document::ReturnsLabel
        ->new(stock_process_id => $stock_process_id)
        ->print_at_location($location);
}

1;
