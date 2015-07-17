package XTracker::Schema::ResultSet::Public::RecommendedProduct;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Carp;
use Readonly;

Readonly my $FIRST_ORDER  => 1;
Readonly my $SECOND_ORDER => 2;
Readonly my $TEMP_ORDER   => 3;

use XTracker::Constants::FromDB qw( :recommended_product_type );
use base 'DBIx::Class::ResultSet';

sub get_recommendations {
    my ( $resultset ) = shift;
    my $me = $resultset->current_source_alias;

    return $resultset->search_rs(
        { type_id  => $RECOMMENDED_PRODUCT_TYPE__RECOMMENDATION },
        { order_by => { -asc => [ "$me.slot", "$me.sort_order" ] } },
    );
}

sub get_colour_variations {
    my ( $resultset ) = shift;

    return $resultset->search_rs(
        { type_id  => $RECOMMENDED_PRODUCT_TYPE__COLOUR_VARIATION },
        { order_by => [ qw(slot sort_order) ] },
    );
}

1;
