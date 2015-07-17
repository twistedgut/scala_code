package Test::XT::Data::Return;

use NAP::policy "tt",     qw( role test );

=head1 Test::XT::Data::Return

A Role to be loaded as a trait with either 'Test::XT::Data' or 'Test::XT::Flow' to create Customer Returns.

=head1 SYNOPSIS

    my $flow = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Data::Order',
            'Test::XT::Data::Return',
        ],
    );
    my $order_data = $flow->dispatched_order(products => $number_of_products);
    my $return = $flow->qc_passed_return(shipment_id => $order_data->{'shipment_id'});

    # If you want to find the return's pgid for use later:
    my $group_id = $return->return_items->first # assuming the simplest case
        ->uncancelled_delivery_item->stock_process->group_id;
    # Note: you'll get one process group per return item (that's the way
    # xtracker deals with returns). If you created a return for a shipment
    # with several items, just iterate over return_items instead.

=cut

use Test::XTracker::Data;

use XTracker::Constants         qw( :application );

use XTracker::Constants::FromDB qw(
    :customer_issue_type
    :delivery_item_status
    :delivery_type
    :putaway_type
    :renumeration_type
    :return_item_status
    :return_status
    :shipment_item_status
    :stock_process_status
    :stock_process_type
);
use XT::Domain::Returns;
use XTracker::Database::Delivery; # create_delivery
use XTracker::Database::StockProcess; # create_stock_process


=head1 METHODS

All of the following '*_return' methods will create a Customer Return and
return the DBIC Return object that has been created.

=head2 new_return

Creates a Return for the shipment provided, with all items from the shipment
included. If the shipment has an associated renumeration, a renumeration_item
is created for each shipment_item to be returned.

Required params:
- shipment_id

Optional params:
- refund_type_id
- operator_id

TODO: Allow only some items to be included in the return if params specify that.

TODO: Allow return type and reason to be specified in params too (possibly only in
combination with specified shipment items).

=cut

sub new_return {
    my ( $self, $args ) = @_;
    $args //= {};

    my $returns_domain = Test::XTracker::Data->returns_domain_using_dump_dir();
    $returns_domain->requested_from_arma($args->{'requested_from_arma'} // 1);

    my $shipment = $self->schema->resultset('Public::Shipment')->find($args->{'shipment_id'});
    die "no shipment found with id ".$args->{'shipment_id'} unless ($shipment);

    my $return_items;
    ITEM:
    foreach my $shipment_item ($shipment->shipment_items) {
        # if 'items' exists in $args then only Return
        # those Shipment Items else return all of the Items
        my $item_to_return = {};
        if ( exists $args->{items} ) {
            next ITEM       if ( !exists( $args->{items}{ $shipment_item->id } ) );
            $item_to_return = $args->{items}{ $shipment_item->id };
        }
        $return_items->{$shipment_item->id} = {
            type      => $item_to_return->{type}      || 'Return',
            reason_id => $item_to_return->{reason_id} || $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL, # random default
            (   # if the Item is to be Exchanged then specify the Exchange Item or use the same Variant
                ( $item_to_return->{type} // '' ) eq 'Exchange'
                ? ( exchange_variant => $item_to_return->{exchange_variant_id} || $shipment_item->variant_id )
                : ()
            ),
        };
    }
    my $extra = $args->{extra} // {};
    my %return_args = (
            operator_id => $args->{'operator_id'} // $APPLICATION_OPERATOR_ID,
            shipment_id => $args->{'shipment_id'},
            pickup => 0,
            refund_type_id => $args->{'refund_type_id'} // $RENUMERATION_TYPE__CARD_REFUND,
            return_items => $return_items,
            %$extra,
    );

    note "Create return";
    my $return  = $returns_domain->create( \%return_args );
    ok( $return, 'created return Id/RMA: '.$return->id.'/'.$return->rma_number );

    return $return;
}

=head2 booked_in_return

Creates a Return for the shipment provided, using new_return to create it and then
updating/creating the other data that changes when a Return is booked in.

Takes same params as new_return.

=cut

sub booked_in_return {
    my ( $self, $args ) = @_;

    my $shipment = $self->schema->resultset('Public::Shipment')->find($args->{'shipment_id'});
    die "no shipment found with id ".$args->{'shipment_id'} unless ($shipment);

    my $return = $self->new_return($args);
    die "failed to create new return" unless ($return);

    $return->update({
        return_status_id => $RETURN_STATUS__PROCESSING,
    });
    # TODO: insert row in return_status_log

    note "updated return status";

    my $di_ref = []; # holds delivery items to be linked
    foreach my $return_item ($return->return_items) {
        $return_item->update({
            return_item_status_id => $RETURN_ITEM_STATUS__BOOKED_IN,
        });
        # TODO: insert row in return_item_status_log
        $return_item->shipment_item->update({
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
        });
        # TODO: insert row in shipment_item_status_log
        push @{$di_ref}, {
            return_item_id => $return_item->id,
            packing_slip   => 1,
            type_id        => $DELIVERY_TYPE__CUSTOMER_RETURN,
        }
    }

    my $delivery_id = create_delivery($self->schema->storage->dbh, {
        delivery_type_id => $DELIVERY_TYPE__CUSTOMER_RETURN,
        delivery_items => $di_ref,
    });

    my $delivery = $self->schema->resultset('Public::Delivery')->find($delivery_id);
    isnt($delivery, undef, "Linked delivery created successfully: $delivery_id");

    foreach my $delivery_item ($delivery->delivery_items) {
        $delivery_item->update({
            quantity => 1,
            status_id => $DELIVERY_ITEM_STATUS__COUNTED,
        });
        my $sp = $self->schema->resultset('Public::StockProcess')->create({
            delivery_item_id => $delivery_item->id,
            quantity => 1,
            group_id => \"nextval('process_group_id_seq')",
            type_id => $STOCK_PROCESS_TYPE__MAIN,
            status_id => $STOCK_PROCESS_STATUS__NEW,
        });
        $sp->discard_changes;
        note "Stock process created: group_id ".$sp->group_id;
    }

    return $return;

}

=head2 qc_passed_return

Creates a Return for the shipment provided, using booked_in_return to get
a Return that's in the state it would be after booking in, and then
updating/creating the other data that changes when a Return goes through QC.

Takes same params as new_return.

=cut

sub qc_passed_return {
    my ( $self, $args ) = @_;

    my $shipment = $self->schema->resultset('Public::Shipment')->find($args->{'shipment_id'});
    die "no shipment found with id ".$args->{'shipment_id'} unless ($shipment);

    my $return = $self->booked_in_return($args);
    die "failed to create booked in return" unless ($return);

    note "updated return status";

    foreach my $return_item ($return->return_items) {
        $return_item->update({
            return_item_status_id => $RETURN_ITEM_STATUS__PASSED_QC,
        });
        # TODO: insert row in return_item_status_log
        $return_item->shipment_item->update({
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__RETURNED,
        });
        # TODO: insert row in shipment_item_status_log
        $return_item->uncancelled_delivery_item->update({
            status_id => $DELIVERY_ITEM_STATUS__PROCESSING,
        });
        $return_item->uncancelled_delivery_item->stock_process->update({
            status_id       => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            putaway_type_id => $PUTAWAY_TYPE__RETURNS,
        });
    }

    # TODO: renumeration updates

    $return->update({
        return_status_id => $RETURN_STATUS__COMPLETE,
    });
    # TODO: insert row in return_status_log

    return $return;
}

1;
