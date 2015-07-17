#!/usr/bin/env perl -I t/lib

use NAP::policy "tt",     'test';

=head1 Tests Status Updates Sent on AMQ for JSON Orders

This tests that Error and Success Messages are sent via AMQ for JSON Orders
that are Consumed on AMQ. This makes sure the Frontend is being informed
when there has been any errors and also when an Order has been successfuly
Imported.

Currently Tests for the following Sales Channels:
    * Jimmy Choo

Add more as more Channels use AMQ.

=cut

use Test::Data::JSON;

use Test::XTracker::Data;
use Test::XTracker::RunCondition
    dc       => [ qw( DC1 DC2 ) ];
use Test::XTracker::MessageQueue;
use Test::XTracker::Data::Order::Parser::IntegrationServiceJSON;

use XTracker::Config::Local         qw( config_var );
use XTracker::Utilities             qw( ff_deeply );
use JSON::XS ();

sub _json_payload {
    my ($files, $test_parse_data);
    # get our test data from some *known working* data,
    # then make specific parts broken
    $files = Test::Data::JSON->find_json_in_dir(
        "$ENV{XTDC_BASE_DIR}/t/data/order/third_party",
        'jchoo-' . lc( config_var('XTracker','instance') ) . '-001.json'
    );
    # if we didn't find any files to use as data, something is a little odd
    if (not @{$files}) {
        fail('no matching payload files found to use as input');
        exit -1;
    };
    $test_parse_data = Test::Data::JSON->slurp_json_file($files->[0]);
    $test_parse_data = Test::Data::JSON->make_order_test_safe($test_parse_data);

    return $test_parse_data;
}

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema', "Sanity Check" );

my ($amq,$app)     = Test::XTracker::MessageQueue->new_with_app();

# set-up stuff for each Sales Channel
# uses the Config Section as the key
my $instance    = config_var('XTracker', 'instance');
my $messaging_config = Test::XTracker::Config->messaging_config;
my %channel_args= (
        'JC'    => {
            receive_queue   => $messaging_config->{'Consumer::JimmyChooOrder'}{routes_map}{destination},
            send_queue      => '/queue/' . lc( $instance ) . '/jc/order-status',
        },
    );

# only process channels that are in the above %channel_args HASH
my @channels    = grep { exists( $channel_args{ $_->business->config_section } ) }
                        $schema->resultset('Public::Channel')->all;

my $order_parser    = Test::XTracker::Data::Order::Parser::IntegrationServiceJSON->new();

foreach my $channel ( @channels ) {
    my $conf_section= $channel->business->config_section;
    my $args        = $channel_args{ $conf_section };
    note "Sales Channel: " . $channel->name;

    my $customer    = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );
    my $order_args  = {
                channel     => $channel,
                customer    => {
                        id => $customer->id
                    },
                order       => {
                        channel_prefix => $conf_section,
                    },
            };

    my ( $pre_parsed_data )     = $order_parser->prepare_data_for_parser( $order_args );
    $pre_parsed_data->{'@type'} = 'order';      # the Consumer Method that will be used

    # now test that the correct Statues are sent on AMQ
    # based on whether the Order has been created or not

    note "Test Fail to Parse Properly";
    _clear_queues( $args );

    # fetch data based on real order data
    my $test_parse_data = _json_payload();

    note "Test Fail to Digest Properly";
    _clear_queues( $args );
    $test_parse_data    = ff_deeply( $pre_parsed_data );    # deep clone of the HASH
    $test_parse_data->{orders}[0]{delivery_detail}{order_line}[0]{sku}  = 'NON_EXISTING_SKU'.$$;    # ruin the SKU for an Order Line
    my $res    = $amq->request(
        $app,
        $args->{receive_queue},
        $test_parse_data,
        { type => 'order' },
    );
    ok( $res->is_success, "order consumed" );
    my $msg    = _test_for_msg( $amq, $args->{send_queue}, { successful => JSON::XS::false }, "Order Status: FAILED, Message Produced" );
    if ( ref( $msg ) ) {
        ok( exists( $msg->{error} ), "Found 'error' key in payload" );
        my $o_id = $msg->{o_id};
        my $channel_name = $channel->name;
        like( $msg->{error}{summary},
              qr{Create Failed: Error while processing order \Q$channel_name/$o_id\E: Can't call method "sku"}i,
              "Found expected Error Message" );
        is( $msg->{o_id}, $test_parse_data->{orders}[0]{o_id}, "Found proper Order Number in 'o_id'" );
    }

    note "Test Successful Order";
    _clear_queues( $args );
    $res    = $amq->request(
        $app,
        $args->{receive_queue},
        $pre_parsed_data,
        { type => 'order' },
    );
    ok( $res->is_success, "order consumed" );
    $msg    = _test_for_msg( $amq, $args->{send_queue}, { successful => JSON::XS::true , duplicate => JSON::XS::false}, "Order Status: SUCCESSFUL, Message Produced" );

    note "Test Successful Duplicate Order";
    _clear_queues( $args );
    $res    = $amq->request(
        $app,
        $args->{receive_queue},
        $pre_parsed_data,
        { type => 'order' },
    );
    ok( $res->is_success, "order consumed" );
    $msg    = _test_for_msg( $amq, $args->{send_queue}, { successful => JSON::XS::true, duplicate => JSON::XS::true }, "Order Status: SUCCESSFUL - Duplicate, Message Produced" );
}

done_testing;

#-------------------------------------------------------------------------

# test for an AMQ message and
# return it if matches ok
sub _test_for_msg {
    my ( $amq, $queue, $body, $test_msg )   = @_;
    $amq->assert_messages( {
        destination => $queue,
        assert_header => superhashof({
            type => 'OrderImportStatus',
        }),
        assert_body => superhashof($body),
    }, $test_msg );
    my ($msg) = $amq->messages($queue);
    return $amq->deserializer->($msg->body) if $msg;
    return;
}

# clear queues
sub _clear_queues {
    my $args    = shift;
    $amq->clear_destination( $args->{receive_queue} );
    $amq->clear_destination( $args->{send_queue} );
    return;
}
