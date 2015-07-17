package XTracker::SchemaHelper;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Perl6::Export::Attrs;

sub data_as_hash :Export(:records) {
    my $result = shift;
    my %data;

    %data = $result->get_inflated_columns;

    # stringify anything that's a DateTime (to avoid the "...HHMMSS+01"
    # version that seems to confuse mysql)
    foreach my $key (sort keys %data) {
        if (ref($data{$key}) and 'DateTime' eq ref($data{$key})) {
            $data{$key} = $data{$key}->datetime;
        }
    }

    return \%data;
}

1;
