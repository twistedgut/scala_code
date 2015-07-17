package XTracker::Schema::ResultSet::Public::LogDelivery;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Carp;
use MooseX::Params::Validate 'pos_validated_list';

use XTracker::Constants::FromDB qw(:delivery_action
                                   :stock_process_type);

=head2 order_for_log

Returns the list of delivery logs in delivery_id,date order as needed by the Delivery Logs page on Stock Inventory Overview.

=cut

sub order_for_log {
    my $self    = shift;
    my $me      = $self->current_source_alias;
    return $self->search( {}, { order_by => [ "$me.delivery_id", "$me.date" ] } );
}


=head2 get_main_booked_in_date

Returns booked in date for MAIN process type

=cut

sub get_main_booked_in_date {
    my $self = shift;
    return $self->search( { type_id => $STOCK_PROCESS_TYPE__MAIN } );
}


=head2 get_surplus_booked_in_date

Returns booked in date for SURPLUS process type

=cut

sub get_surplus_booked_in_date {
    my $self = shift;
    return $self->search( { type_id => $STOCK_PROCESS_TYPE__SURPLUS } );
}

=head2 filter_between_dates($start_datetime, $end_datetime) : $rs|@arr

Return data that is between the given datetimes.

=cut

sub filter_between_dates {
    my $self = shift;
    my ( $start, $end ) = pos_validated_list(\@_, ({ isa => 'DateTime' }) x 2);
    my $me = $self->current_source_alias;
    return $self->search({
        "$me.date" => { -between => [
            map { $self->result_source->schema->format_datetime($_) } $start, $end
        ] }
    });
}

=head2 filter_by_channel($channel_id) : $resultset | @rows

Only include entries referencing inbound stock on the given channels.

=cut

sub filter_by_channel {
    my ( $self, $channel_id ) = @_;
    return $self->search(
        { 'purchase_order.channel_id' => $channel_id },
        { join => {
            delivery => {
                link_delivery__stock_order => {
                    stock_order => 'purchase_order'
                }
            }
        } }
    );
}

=head2 inbound_by_action(\%filter_args!, $order_by_key='date', $sort_desc=0) : $resultset|@rows

This is a pretty customised method call to return results for the inbound by
action page.  You have to pass 'C<$delivery_action_id>' to 'C<\%filter_args>'
and optionally 'C<$operator_id>' to filter results.

The second argument is a string that has to be one of the following:

=over

=item date - default

=item delivery_action_rank

=item delivery_id

=item operator_name

=item product_id

=item quantity

=back

The final argument is a boolean which when true sorts the results in descending
order.

=cut

sub inbound_by_action {
    my ( $self, $filter_args, $order_by_key, $sort_desc ) = @_;

    my ($delivery_action_id, $operator_id, $channel_id) = @{$filter_args}{qw/delivery_action_id operator_id channel_id/};

    croak "You must pass a value for 'delivery_action_id' in your first hashref"
        unless $delivery_action_id;

    my $base_rs = $self
        ->search(
            {
                delivery_action_id => $delivery_action_id,
                'link_delivery__stock_order.stock_order_id' => { q{!=} => undef },
                $operator_id ? (operator_id => $operator_id) : (),
            },
            {
                prefetch => [ qw/delivery_action operator/, {
                    delivery => { link_delivery__stock_order => 'stock_order' }
                } ]
            }
        );

    # If no Channel IDs have been passed, return at this point
    return $base_rs->_inbound_by_action_order_by($order_by_key, $sort_desc) if (!$channel_id);

    # Otherwise filter by channel ID and return
    return $base_rs
        ->filter_by_channel($channel_id)
        ->_inbound_by_action_order_by($order_by_key, $sort_desc);
}

sub _inbound_by_action_order_by {
    my ( $self, $order_by_key, $sort_desc ) = @_;

    my $me = $self->current_source_alias;
    my @default_order_by = ( "$me.date", "$me.id" );
    my %arg_map = (
        date                 => [ @default_order_by ],
        delivery_action_rank => [ "delivery_action.rank", @default_order_by ],
        delivery_id          => [ "$me.delivery_id", @default_order_by ],
        operator_name        => [ 'operator.name', @default_order_by ],
        product_id           => [
            \'COALESCE(stock_order.product_id, stock_order.voucher_product_id)',
            @default_order_by
        ],
        quantity             => [ "$me.quantity", @default_order_by ],
    );

    # Default to date, croak if we pass an invalid key
    my $order_by = $arg_map{$order_by_key//'date'}
        || croak "Invalid order by key '$order_by_key'";

    # Default to ascending
    my $asc_desc = $sort_desc ? '-desc' : '-asc';

    # The asc/desc parameter only applies to the first order by, the rest are
    # all hard-coded
    return $self->search({},
        { order_by => [ { $asc_desc => $order_by->[0] }, splice @$order_by, 1 ] }
    );
}

1;
