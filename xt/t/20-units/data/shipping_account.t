#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use Data::Dump qw( pp );
use Path::Class::File;

use Test::XTracker::Data;
use Test::XTracker::Utils;

my $path = 't/data/'. Test::XTracker::Data::whatami() .'/public_shippingaccount.json';


#TODO: {
#    local $TODO = 'Need to fix MRP skus first';


## get a schema to query
my $schema = Test::XTracker::Data->get_schema;
isa_ok($schema, 'XTracker::Schema' );
my $file = Path::Class::File->new( $path );
note $file;
isa_ok($file, 'Path::Class::File', 'created file');

my $data = Test::XTracker::Utils->slurp_json_file( $file );

isa_ok($data, 'HASH',
    'data file is hashref');
isa_ok($data->{public_shippingaccount}, 'ARRAY',
    'has shipping_account field with elements')
    || note ref($data);

test_shipping_account($data->{public_shippingaccount});

#}

done_testing();


sub test_shipping_account {
    my($data) = @_;

    my $acc_rs = $schema->resultset('Public::ShippingAccount');
    my $ch_rs = $schema->resultset('Public::Channel');
    my $ca_rs = $schema->resultset('Public::Carrier');


    foreach my $rec (@{$data}) {
        my $ch_name = delete $rec->{web_name};
        my $ca_name = delete $rec->{carrier_name};
        my $chan = $ch_rs->find_by_web_name($ch_name);
        my $carr = $ca_rs->find_by_name($ca_name);

        # we can find the channel name?
        isa_ok($chan,'XTracker::Schema::Result::Public::Channel',
            'its a channel rec');

        # check the fields with the record
        my $param = {
            name => $rec->{name} || undef,
            channel_id => $chan->id || undef,
            carrier_id => $carr->id || 0, # argh! should be undef
        };
        my $accs = $acc_rs->search($param);
        is($accs->count, 1, 'found one record') || note pp($param);

    }
}

