#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

delivery_log.t - test the log_delivery table

=head1 DESCRIPTION

Create an order, check it's been created properly, then call C<log_delivery>
and C<get_delivery_log> from L<XTracker::Database::Logging> to ensure they
write to and read from the log_delivery table.

#TAGS shouldbeunit order delivery fulfilment

=cut

use FindBin::libs;



use Test::XTracker::Data;

use XTracker::Database::Logging  qw( log_delivery get_delivery_log );

use XTracker::Database::Utilities;
use XTracker::Database::Delivery;

my $channel = Test::XTracker::Data->get_local_channel();

my $schema      = Test::XTracker::Data->get_schema;

my $dbh = $schema->storage->dbh;

my $pids    = Test::XTracker::Data->find_or_create_products({
        channel_id => $channel->{id},
        how_many => 1,
        with_delivery => 1,
        });

my $pid = $pids->[0]->{pid};

my $stock_order = $schema->resultset('Public::StockOrder')->find({
                                                        product_id => $pid,
                                                            });

my $link_delivery__stock_order = $schema->resultset('Public::LinkDeliveryStockOrder')->find({
                                                        stock_order_id => $stock_order->id,
                                                            });

ok( defined($link_delivery__stock_order->delivery_id) , 'Got delivery_id from db' );
my $delivery_id = $link_delivery__stock_order->delivery_id;

my %args = (
    delivery_id => $delivery_id,
    quantity    => '11',
    operator    => '8572',
    type_id     => '0',
    action      => 4,
    notes       => 'Test approved items'
    );
log_delivery( $dbh, \%args );

my $data = get_delivery_log($dbh, $pid );


my $successfully_logged = 0;
foreach my $channel (values %{$data}){
    foreach my $raw (@{$channel}){
        if ($raw->{delivery_id} == $delivery_id && $raw->{notes} eq 'Test approved items'
                                                && $raw->{action} eq 'Approve'){
            $successfully_logged = 1;
        }
    }
}

is ($successfully_logged, 1, 'Approved stock successfully logged');

done_testing();
