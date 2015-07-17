package Test::AssertRecords::Plugin::Shipping::Option;
use Moose;
use Test::More 0.98;
use Data::Dump qw/pp/;
use Test::Differences;


with 'Test::AssertRecords::PluginBase';


sub make_record {
    my($self,$row) = @_;
    my $zone_set = $row->zones;

    my @zones;
    foreach my $zone ($zone_set->all) {
        push @zones, $zone->name;
    }

    return {
        'name'          => $row->name,
        'description'   => $row->description,
        'product_name'  => $row->product_name,
        'carrier'       => $row->carrier->name,
        'option_type'   => $row->option_type->name,
        'zones'         => \@zones,
    };
}

sub test_assert {
    my($self,$schema,$data) = @_;

    my $option_rs = $schema->resultset('Shipping::Option');

    foreach my $rec (@{$data}) {
        my $zones = delete $rec->{zones};

        my $option = $option_rs->find_name($rec->{name});

        isa_ok($option,'XTracker::Schema::Result::Shipping::Option',
            'its a option rec');

        is($option->name,$rec->{name},"name matches");
        is($option->description,$rec->{description},"description matches");
        is($option->carrier->name,$rec->{carrier},"carrier matches");
        is($option->option_type->name,$rec->{option_type},
            "option_type matches");

        $self->_test_zones($zones, $option->zones);
    }

}

sub _test_zones {
    my($self,$test, $set) = @_;

    my @all = $set->get_column('name')->all;
    eq_or_diff(\@all,$test,"list of zones matches");
}

1;
