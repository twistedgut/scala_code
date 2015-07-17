package XTracker::Schema::ResultSet::Public::ShipmentBoxLog;

# This class is copied from XTracker::Schema::ResultSet::Public::ShipmentItemStatusLog
# If something similar needs to be changed,
# then MIGHT have to consider changing in other class as well
use NAP::policy qw/tt class/;

use MooseX::NonMoose;
extends 'DBIx::Class::ResultSet';

use Carp;
use DateTime::Format::Pg;

use XTracker::Constants ':database';

__PACKAGE__->load_components(qw{Helper::ResultSet::SetOperations});

# This little bit of magic is helpfully suggested by the DBIC guys:
# https://metacpan.org/pod/DBIx::Class::ResultSet#CUSTOM-ResultSet-CLASSES-THAT-USE-Moose
sub BUILDARGS { $_[2] }

=head1 NAME

XTracker::Schema::ResultSet::Public::ShipmentBoxLog

=head1 METHOD

=head2 filter_between( $start, $end ) : $resultset | @rows

Pass two DateTime objects to filter log entries between them, inclusive.

=cut

sub filter_between_dates {
    my ( $self, $start, $end ) = @_;
    my $me = $self->current_source_alias;
    return $self->search({
        "${me}.timestamp" => { -between => [
            map { DateTime::Format::Pg->format_datetime($_) } $start, $end
        ] },
    });
}

=head2 filter_by_customer_shipments() : $resultset | @rows

Only include entries referencing customer shipments.

=cut

sub filter_by_customer_shipments {
    shift->search(
        { 'link_orders__shipment.shipment_id' => { q{!=} => undef } },
        { join => { shipment_box => { shipment => 'link_orders__shipment' } } }
    );
}

=head2 filter_by_sample_shipments() : $resultset | @rows

Only include entries referencing sample shipments.

=cut

sub filter_by_sample_shipments {
    shift->search(
        { 'link_stock_transfer__shipments.shipment_id' => { q{!=} => undef } },
        { join => { shipment_box => { shipment => 'link_stock_transfer__shipments' } } }
    );
}

=head2 filter_by_customer_channel($channel_id) : $resultset | @rows

Only include entries referencing shipments going to customers on the given
channel.

=cut

sub filter_by_customer_channel {
    my ( $self, $channel_id ) = @_;
    return $self->search(
        { 'orders.channel_id' => $channel_id },
        { join => {
            shipment_box => {
                shipment => { link_orders__shipment => 'orders' }
            }
        } }
    );
}

=head2 filter_by_sample_channel($channel_id) : $resultset | @rows

Only include entries referencing shipments going to samples on the given
channel.

=cut

sub filter_by_sample_channel {
    my ( $self, $channel_id ) = @_;
    return $self->search(
        { 'stock_transfer.channel_id' => $channel_id },
        { join => {
            shipment_box => {
                shipment => { link_stock_transfer__shipments => 'stock_transfer' }
            }
        } }
    );
}

# Define these two subs here as their values are used in more than one scope
sub _trunc_date_alias { 'start' };
sub _operator_alias { 'operator' };

sub _date_trunc_sql {
    my ( $self, $trunc_to, $as ) = @_;
    my $me = $self->current_source_alias;
    $as //= $self->_trunc_date_alias;

    return { date_trunc => "'$trunc_to',${me}.timestamp", -as => $as };
}

=head2 filter_for_report(\%args) : $rs | @rows

Produce a report on the labelling of shipment box

The parameters you can pass are:

=over

=item grouping - Str, required

=item start - DateTime, required

=item end - DateTime, required

=item by_operator - Bool, optional

=item channel_id = Int, optional

=item shipment_type - customer|sample, optional

=back

=cut

sub filter_for_report {
    my ( $self, $args ) = @_;

    my ($grouping) = (grep { $_ eq ($args->{grouping}//q{}) } @PG_TIME_UNITS)
        or croak "Invalid value '@{[$args->{grouping}//q{}]}' for parameter 'grouping'";
    my ( $start, $end ) = @{$args}{qw/start end/};

    my $by_operator = !!$args->{by_operator};
    my $channel_id = $args->{channel_id};
    my $shipment_type = $args->{shipment_type} || q{};
    croak "Invalid value '$shipment_type' for parameter 'shipment_type'"
        if $shipment_type && $shipment_type !~ m{^(?:customer|sample)$};

    my $total_labelled_boxes_alias = 'total_labelled_boxes';

    my $me = $self->current_source_alias;
    # We need the -as keys for the union selects to work for channelised
    # queries, and the $columns var's keys are necessary for HashRefInflator to
    # know what to call its keys
    my $columns = {
        start => $self->_date_trunc_sql($grouping),
        $total_labelled_boxes_alias => {
            count => "${me}.shipment_box_id",
            -as => $total_labelled_boxes_alias
        },
    };

    my $group_bys = [ $self->_trunc_date_alias ];
    my $joins = [];
    if ( $by_operator ) {
        $columns->{$self->_operator_alias}
            = \(join q{ AS }, 'operator.name', $self->_operator_alias);
        push @$group_bys, 'operator.name';
        push @$joins, 'operator';
    }

    # Create our base rs - our other resultsets are based on this
    my $base_rs = $self
        ->filter_between_dates($start, $end)
        ->search( undef, {
            columns => $columns,
            (@$joins ? (join => $joins) : ()),
            group_by => $group_bys,
        });

    # If we're not creating a customer/sample or channel-specific report, this
    # is all we need to do
    return $base_rs if (!$shipment_type && !$channel_id);

    my $customer_rs = $base_rs->filter_by_customer_shipments;
    my $sample_rs = $base_rs->filter_by_sample_shipments;

    # If we have got here and we don't have channelised results, we must have
    # filtered by shipment type, so we can return
    unless ( $channel_id ) {
        return $shipment_type eq 'customer' ? $customer_rs
             : $shipment_type eq 'sample'   ? $sample_rs
             : croak "Invalid value $shipment_type passed for 'shipment_type";
    }

    # If we have reached this point it means we must have channelised results -
    # we can return if we only want to report on customer or sample shipments
    my $channelised_customer_rs
        = $customer_rs->filter_by_customer_channel($channel_id);
    return $channelised_customer_rs if $shipment_type eq 'customer';

    my $channelised_sample_rs
        = $sample_rs->filter_by_sample_channel($channel_id);
    return $channelised_sample_rs if $shipment_type eq 'sample';

    # If we have got this far we have channelised results *and* we're filtering
    # by shipment type. Channelised results are annoying as the joins to
    # determine the channel a shipment belongs are different - so we need to do
    # a union.
    return $channelised_customer_rs->union_all($channelised_sample_rs)->search_rs;
}
# We need an around clause to apply ordering, and we can DRY by adding it here
# instead of once to each resultset returned.
around 'filter_for_report' => sub {
    my $orig = shift;
    my $self = shift;
    my ($args) = @_;

    my @order_bys = $self->_trunc_date_alias;
    # If we want to group by operator, we want that to be our primary order by
    unshift @order_bys, $self->_operator_alias if $args->{by_operator};
    return $self->$orig(@_)->search(undef, { order_by => \@order_bys });
};

__PACKAGE__->meta->make_immutable;
