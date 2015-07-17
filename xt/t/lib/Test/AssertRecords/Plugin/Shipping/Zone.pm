package Test::AssertRecords::Plugin::Shipping::Zone;
use Moose;
use Test::More 0.98;
use Data::Dump qw/pp/;
use Test::Differences;


with 'Test::AssertRecords::PluginBase';


sub make_record {
    my($self,$row) = @_;
    my $locs = $row->locations;
    my @all_locs;

    foreach my $loc ($locs->all) {
        push @all_locs, {
            country_code => $loc->country->code,
            postcode => $loc->postcode,
        };
    }

    return {
        'name' => $row->name,
        'locations' => \@all_locs,
    };
}

sub test_assert {
    my($self,$schema,$data) = @_;

    my $zone_rs = $schema->resultset('Shipping::Zone');

    foreach my $rec (@{$data}) {
        my $locations = delete $rec->{locations};
        my $zone = $zone_rs->find_name($rec->{name});

        isa_ok($zone,'XTracker::Schema::Result::Shipping::Zone',
            'its a zone rec - '.$rec->{name});

        is($zone->name,$rec->{name},"name matches");

        $self->_test_locations($locations, $zone->locations);
    }

}

sub _test_locations {
    my($self,$loc_t, $set) = @_;

    my @all_locs;
    foreach my $loc ($set->all) {
        push @all_locs, {
            country_code => $loc->country->code,
            postcode => $loc->postcode,
        };
    }
    eq_or_diff(\@all_locs,$loc_t,"list of locations matches");
}

1;
