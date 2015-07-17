package XTracker::Schema::ResultSet::Public::VariantMeasurement;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub get_variant_measurement_value {

    my ( $resultset, $variant_id, $measurement_id ) = @_;

    my $value
        = $resultset->find($variant_id, $measurement_id)->value;

    return $value;

}

1;

