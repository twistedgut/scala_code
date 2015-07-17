#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XT::Data;

my $framework = Test::XT::Data->new_with_traits(
    traits => [ 'Test::XT::Data::Order' ],
);

# Stuff we need
my $lps_rs  = Test::XTracker::Data->get_schema->resultset('Public::LogPwsStock');
my @METHODS = qw/ log_order log_stock_change /;
my $data    = $framework->new_order;
my $shipment_item = Test::XTracker::Data->create_shipment_item({
    shipment_id => $data->{shipment_id},
    variant_id  => $data->{product_objects}->[0]->{product}->variants->first->id,
});
my $STOCK_CHANGE_ARGS = {
    variant_id    => $data->{product_objects}->[0]->{product}->variants->first->id,
    channel_id    => $data->{order_object}->channel_id,
    pws_action_id => 1,
    quantity      => 7,
    notes         => 'foo bar',
    operator_id   => 1,
};

# Instantiation etc
isa_ok( $lps_rs, 'XTracker::Schema::ResultSet::Public::LogPwsStock',
    'Instantiated resultset' );
can_ok( $lps_rs, @METHODS );

# Method argument validation
throws_ok { $lps_rs->log_order } qr/Shipment item row required/,
    'Missing arg caught okay';
lives_ok { $lps_rs->log_order( $shipment_item ) } 'Lives with correct arg';

dies_ok { $lps_rs->log_stock_change } 'Dies with no args';
my %args = %{$STOCK_CHANGE_ARGS};
delete $args{channel_id};
throws_ok{ $lps_rs->log_stock_change( \%args ) } qr/Mandatory parameter 'channel_id' missing/,
    'Missing arg caught ok';
lives_ok{ $lps_rs->log_stock_change( $STOCK_CHANGE_ARGS ) }
    'Lives with correct args';

# Functionality
my $log_row = $lps_rs->search({},{order_by => {-desc => 'id'}, rows => 1})->single;
is( $log_row->variant_id, $STOCK_CHANGE_ARGS->{variant_id}, 'Variant correct' );
is( $log_row->quantity, $STOCK_CHANGE_ARGS->{quantity}, 'Quantity correct' );

done_testing;
