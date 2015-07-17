package XTracker::Schema::ResultSet::Promotion::Detail;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw( :event_type );

sub promotion_list {
    my $resultset = shift;

    my $list = $resultset->search(
        {
        },
        {
            order_by => ['me.id DESC', 'start_date DESC', 'end_date DESC'],
            prefetch => [
                'coupon_generation',
                'coupon_restriction',
                'coupon_target',
                'status',
                'target_city',
                'detail_websites',
            ],
        },
    );

    return $list;
}

sub retrieve_promotion {
    my $resultset       = shift;
    my $promotion_id    = shift;

    my $promotion = $resultset->find(
        $promotion_id,
        {
            prefetch => [
                'coupon_generation',
                'coupon_restriction',
                'coupons',
                'coupon_target',
                'status',
                'target_city',
            ],
        },
    );

    return $promotion;
}

# get a new style event only (non classic promotions)
sub retrieve_event {
    my $resultset   = shift;
    my $event_id    = shift;

    my $event = $resultset->search(
        {
            'me.id'                 => $event_id,
            'me.is_classic'         => 0,
        },
        {
            prefetch => [
                'status',
                'target_city',
            ],
            join => [
                'detail_websites',
            ],
        },
    );

    return $event->first;
}

sub pws_get_export_promos {
    my $resultset       = shift;

    return $resultset->search(
        {
            # we only care about enabled promotions
            enabled     => 1,
            # anything that's open-ended OR ends in the future
            end_date    => [ undef, {'>=', 'NOW'} ],
        }
    );
}

sub have_been_exported {
    my $resultset = shift;

    return $resultset->search( { enabled => { q{!=}, undef } } );
}

1;
