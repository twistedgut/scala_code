package XTracker::Schema::ResultSet::Public::Reservation;

use strict;
use warnings;

use base 'XTracker::Schema::ResultSetBase';

use Carp;

use XTracker::Constants::FromDB qw( :reservation_status );
use XTracker::Constants         qw( :application );

=head1 NAME

XTracker::Schema::ResultSet::Public::Reservation - DBIC resultset

=head1 DESCRIPTION

DBIx::Class resultset for reservations

=head1 METHODS

=head2 by_variant_id ($variant_id)

Constrains resultset by variant_id

=cut

sub by_variant_id {
    my $self = shift;
    my $variant_id = shift;

    my $alias   = $self->current_source_alias;

    return $self->search({ "${alias}.variant_id" => $variant_id});
}

=head2 by_pid {

constrains resultset by variant->product_id

=cut

sub by_pid {
    my $self        = shift;
    my $product_id  = shift;

    return $self->search({
        'variant.product_id' => $product_id ,
    },{
        join => [ 'variant' ],
    });

}

=head2 uploaded

Constrains resultset by status -> uploaded

=cut

sub uploaded {
    my $self = shift;

    return $self->search({status_id => $RESERVATION_STATUS__UPLOADED});
}

=head2 pending

Constrains resultset by status -> pending

=cut

sub pending {
    my $self = shift;

    return $self->search({status_id => $RESERVATION_STATUS__PENDING});
}

=head2 pending_and_uploaded

Returns a ResultSet of all pending or uploaded reservations, i.e. ones that
have a status of either C<Pending> or C<Uploaded>.

=cut

sub pending_and_uploaded {
    my $self = shift;

    return $self->search({
        status_id => { '-in' => [
            $RESERVATION_STATUS__PENDING,
            $RESERVATION_STATUS__UPLOADED,
        ]},
    });
}

=head2 cancelled_or_purchased

Constrains resultset by status ->cancelled or purchased

=cut

sub cancelled_or_purchased {
    my $self = shift;

    return $self->search( { status_id => { -in => [ $RESERVATION_STATUS__CANCELLED, $RESERVATION_STATUS__PURCHASED ] } } );
}

=head2 not_for_pre_order

Excludes Reservations that are linked to a Pre-Order.

=cut

sub not_for_pre_order {
    my $self    = shift;

    return $self->search(
        {
            'pre_order_items.id' => undef,
        },
        {
            join => 'pre_order_items',
        }
    );
}

=head2 pending_in_priority_order

Returns a list of Pending Reservations in Priority Order - which uses the 'ordering_id' as the priority,
also takes into account Reservations for Pre-Orders and prioritises them first.

=cut

sub pending_in_priority_order {
    my $self    = shift;

    my $alias   = $self->current_source_alias;

    # CANDO-986: Rationale for Prioritising Pre-Orders:
    # Pre-Orders should come above Normal Reservations when deciding which one gets 'Uploaded',
    # so I've decided to use the Pre-Order Item Status Log Date for 'Complete' statuses as the
    # the ordering for the Pre-Orders and as there won't be a Log Date for Normal Reservations
    # that field will be NULL which will be coalesced into '2100-12-31' which is far in the future
    # which means they will appear last in the list. As all Normal Reservations will have the same
    # Log Date then they will be sorted by the second condition which is the Ordering Id and then
    # come out in the correct sequence too.

    return $self->pending->search( { },
                                {
                                    join        => { pre_order_items => 'unique_complete_pre_order_item_status_logs' },
                                    '+select'   => {
                                                        coalesce=> "unique_complete_pre_order_item_status_logs.date, '2100-12-31 23:59:59'",
                                                        -as     => 'unique_complete_pre_order_item_status_logs_date',
                                                   },
                                    '+as'       => 'unique_complete_pre_order_item_status_logs_date',
                                    order_by    => "unique_complete_pre_order_item_status_logs_date ASC, ${alias}.ordering_id ASC, ${alias}.id ASC",
                                } );
}

=head2 auto_upload_pending

    $stock_used = $resultset->auto_upload_pending( {
                                                    channel => $channel || channel_id => $channel_id,
                                                    variant_id => $variant_id,
                                                    operator_id => $operator_id,
                                                    stock_quantity => $stock_quantity,
                                                    stock_manager => XTracker::WebContent::StockManagement object,
                                                } );

This will go through all of the Pending Reservations in Priority Order for a Variant and Upload as many as it can based on the Amount of Stock that just got updated.

=cut

sub auto_upload_pending {
    my ( $self, $args ) = @_;

    my $variant_id      = $args->{variant_id};
    my $operator_id     = $args->{operator_id} || $APPLICATION_OPERATOR_ID;
    my $stock_qty       = $args->{stock_quantity};
    my $channel         = $args->{channel} || $args->{channel_id};
    my $stock_manager   = $args->{stock_manager};

    croak "'auto_upload_pending' not passed in a 'variant_id'"                  if ( !defined $variant_id );
    croak "'auto_upload_pending' not passed in an 'operator_id'"                if ( !$operator_id );
    croak "'auto_upload_pending' not passed in a 'stock_quantity'"              if ( !defined $stock_qty );
    croak "'auto_upload_pending' not passed in a 'channel' or 'channel_id'"     if ( !$channel );
    croak "'auto_upload_pending' not passed in a 'stock_manager'"               if ( !$stock_manager );

    # the amount of stock that will have been used
    # to upload all of the Pending Reservations
    my $stock_used  = 0;

    # if 'channel_id' passed in then get the 'Public::Channel' record
    if ( !ref( $channel ) ) {
        $channel    = $self->result_source->schema->resultset('Public::Channel')->find( $channel );
    }

    # check the Sales Channel supports Auto Uploading of Reservations
    if ( !$channel->can_auto_upload_reservations ) {
        return $stock_used;     # return no stock used
    }

    # get all of the Pending Reservations for the Sales Channel for the Variant Id
    my @reservations    = $channel->reservations
                                    ->pending_in_priority_order
                                        ->by_variant_id( $variant_id )
                                            ->search( {}, { rows => $stock_qty } )  # only get enough rows that I need
                                                ->all;

    foreach my $reservation ( @reservations ) {     # will process them in priority order
        if ( $reservation->upload_pending( $operator_id, $stock_manager ) ) {

            if ( my $email_params = $reservation->notify_of_auto_upload( $operator_id ) ) {
                # push email params onto Stock Managment Email Array
                $stock_manager->add_to_emails( {
                                            reservation => $reservation,
                                            email_params=> $email_params,
                                        } );
            }

            # each Reservation will only use 1 piece of Stock
            $stock_used++;
        }
    }

    return $stock_used;
}

=head2 commission_cut_off_date_from

    $reservations = $self->commission_cut_off_date_from( $date );

For the given date it returns all reservation whose commission_cut_off date has not yet
passed.

=cut

sub commission_cut_off_date_from {
    my $self = shift;
    my $date = shift;

    my $commission_cutoff_date = $self->result_source->schema->format_datetime( $date );

    return $self->search({
        '-and' => [
            commission_cut_off_date => {  '!=' => undef },
            commission_cut_off_date => {  '>=' => $commission_cutoff_date },
        ],
    });

}

=head2 created_before_or_on

    $reservations  = $self->created_before_or_on( $date );

For the given date it returns all reservations created before or on that date.

=cut

sub created_before_or_on {
    my $self = shift;
    my $date = shift;

    # Since reservation->date_created is without time_zone, adjust date
    my $date_without_timezone = $self->result_source->schema->format_datetime( $date->clone->set_time_zone('local') );

    return $self->search( {
        date_created => { '<=' => $date_without_timezone },
    });

}

=head1 SEE ALSO

L<XTracker::Schema>,
L<XTracker::Schema::Result::Public::ShipmentType>

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>

=cut

1;

