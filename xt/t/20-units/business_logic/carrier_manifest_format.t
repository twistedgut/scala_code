#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;
use lib 't/lib';
use XT::Rules::Solve;


# TODO: Move this somewhere shared as it's been copy/pasted from somewhere
# else already...
my $lookup = sub {
    # Constant required
    my $constant = shift;
    $constant = "XTracker::Constants::FromDB::$constant";
    # Nasty soft-ref lookup
    my $value;
    { no strict 'refs'; $value = ${$constant}; } ## no critic(ProhibitNoStrict)
    # Get upset if we couldn't find it
    die "Can't find $constant" unless defined $value;
    # Give it back!
    return $value;
};

my %reference_data = (
    DC1 => {
        CARRIER__UNKNOWN => q{},
        CARRIER__DHL_EXPRESS => 'dhl',
        CARRIER__UPS => q{},
    },
    DC2 => {
        CARRIER__UNKNOWN => q{},
        CARRIER__DHL_EXPRESS => 'csv',
        CARRIER__UPS => 'csv',
    },
);

for my $dc_name ( sort keys %reference_data ) {
    for my $carrier_name ( sort keys %{$reference_data{$dc_name}} ) {
        my $expected = $reference_data{$dc_name}{$carrier_name};

        my $carrier_id = $lookup->($carrier_name);

        my $returned = XT::Rules::Solve->solve(
            'Carrier::manifest_format' => { carrier_id => $carrier_id },
            { 'Configuration::DC' => $dc_name, }
        );
        is( $returned, $expected,
            "Format for carrier $carrier_name ($carrier_id) on $dc_name is [$expected]");
    }
}

done_testing;
