package XTracker::Schema::ResultSet::Shipping::DeliveryDateRestriction;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub restricted_shipping_charge_ids_grouped_by_type_date {
    my $self = shift;
    return $self->search(
        { is_restricted => 1 },
        {
            "select" => [
                "me.restriction_type_id",
                "me.date",
                \"array_to_string( array_agg( me.shipping_charge_id ORDER BY me.shipping_charge_id ), '-' )",
            ],
            "as" => [
                "restriction_type_id",
                "date",
                "shipping_charge_ids",
            ],
            group_by => [ "me.restriction_type_id", "me.date" ],
        }
    );
}

=head2 between_dates_per_channel_rs(:$channel, :$begin_date, :$end_date) : $rs

Return a resultset with rows for $channel, between $begin_date and
$end_date, with the restriction_type and shipping_charge prefetched.

=cut

sub between_dates_per_channel_rs {
    my ($self, $args) = @_;
    my $channel    = $args->{channel};
    my $begin_date = $args->{begin_date};
    my $end_date   = $args->{end_date};

    $self->search(
        {
            date => {
                -between => [ $begin_date, $end_date ], # BETWEEN is inclusive
            },
            "shipping_charge.channel_id" => $channel->id,
            is_restricted                => 1,
        },
        {
            join     => "shipping_charge",
            prefetch => "restriction_type",
        },
    );
}

1;
