#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

stock_request.t - Basic test to request a sample

=head1 DESCRIPTION

Basic test to request a sample

Uses L<Test::XTracker::Mechanize>->test_create_sample_request

#TAGS sample fulfilment whm

=cut

use FindBin::libs;


use Test::XTracker::Data;

use XTracker::Constants::FromDB qw(:authorisation_level :delivery_status);
use Test::XT::Flow;

my $channel = Test::XTracker::Data->get_local_channel();

# Over-ride the default purchase order and create one with a delivery.
my $purchase_order = Test::XTracker::Data->create_from_hash({
    channel_id  => $channel->{id},
    placed_by   => 'Ian Dochertyy',
    stock_order => [{
        product => {
            product_type_id => 6,
            style_number    => 'ICD STYLE',
            variant         => [{
                size_id          => 1,
                stock_order_item => { quantity => 40, },
            }],
            product_channel   => [{ channel_id => $channel->{id}, }],
            product_attribute => { description => 'Test info attribute', },
            price_purchase    => {},
            delivery          => { status_id => $DELIVERY_STATUS__COUNTED, },
        },
    }],
});

my $pids = Test::XTracker::Data->find_products({
    channel_id => $channel->{id},
    how_many => 1,
});

my $framework = Test::XT::Flow->new;

$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Stock Control/Inventory',
        'Stock Control/Sample',
    ]},
    dept => 'Sample'
});

my $mech = $framework->mech;
$mech->test_create_sample_request( $pids, 'test test test' );
note "sample request created";

$mech->get_ok('/StockControl/Sample' );

$mech->content_contains('test test test');

done_testing();
