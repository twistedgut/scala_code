package Test::AssertRecords::Plugin::Public::ShippingAccount;
use Moose;
use Test::More 0.98;
use Data::Dump qw/pp/;


with 'Test::AssertRecords::PluginBase';


has '+map' => (
    default => sub {
        return {
            'name' => undef,
            'carrier_name' => [qw/carrier name/],
            'web_name' => [qw/channel web_name/],
            'return_cutoff_days' => undef,

        };
    },
);


sub find_base_record {
    my($self,$rs,$test_case) = @_;
    my $schema = $rs->result_source->schema;
    my $channel_rs = $schema->resultset('Public::Channel')->search({
        web_name => $test_case->{web_name},
    });
    my $carrier_rs = $schema->resultset('Public::Carrier')->search({
        name => $test_case->{carrier_name},
    });

    is($channel_rs->count,1,'matched only one channel');
    is($carrier_rs->count,1,'matched only one carrier');

    return $rs->search({
        name => $test_case->{name},
        carrier_id => $carrier_rs->first->id,
        channel_id => $channel_rs->first->id,
    });
}


1;
