#!/usr/bin/env perl
use NAP::policy "tt", 'test', 'class';
use Test::XTracker::Data::Product;
use Test::XT::DC::JQ;
use Test::XTracker::Data;

BEGIN {
    extends 'NAP::Test::Class';

    has 'product_test_data_helper' => (
        is => 'ro',
        lazy => 1,
        default => sub {
            return Test::XTracker::Data::Product->new();
        },
        handles => [ 'create_product' ],
    );

    use_ok("XT::JQ::DC::Receive::Product::Update");
};

sub test__product_update :Tests { SKIP:{
    my ($self) = @_;

    my $jqt = Test::XT::DC::JQ->new;

    eval { $jqt->schema->storage->dbh; };
    skip "Need a job_queue database for DCs for this test to work: $@", 3 if $@;

    my $product = $self->create_product();
    my $channel = $product->get_channel();

    # Grab a real ship_restriction
    my $real_ship_restriction = $self->schema->resultset('Public::ShipRestriction')->search({},{
        rows => 1,
    })->first();

    my $payload = [{
        product_id => $product->id(),
        operator_id => Test::XTracker::Data->get_application_operator_id(),
        restriction_code => { add => [$real_ship_restriction->code()] },
        channel => [ {
            channel_id => $channel->id,
            editors_comments => "",
            keywords => "",
            long_description => "Neque porro quisquam est qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit...",
            size_fit => "",
        }],
    }];

    $jqt->clear_ok;

    my $job = XT::JQ::DC->new( { funcname => 'Receive::Product::Update' });
    $job->set_payload( $payload );
        $job->send_job;
    $jqt->is_last_job(
        { funcname => 'XT::JQ::DC::Receive::Product::Update',
        payload => $payload, },
    );
    $jqt->queue->work_until_done;

    $product->discard_changes();

    my %set_codes = map { $_->code() => 1 } $product->ship_restrictions();
    is_deeply(\%set_codes, { $real_ship_restriction->code() => 1 },
        'Correct shipping restrictions have been set');

    # ---------------------------------------------------------------
    # test sending payload to enable pre order for product
    # --------------------------------------------------------------

    # Reversing the flag so we can send it through a new payload
    # As the database is not re-populated on each run of the test, we need to find
    # the current pre_order status and switch it to the opposite to send to the
    # payload for testing purposes

    my $reverse_pre_order_flag = $product->attribute->pre_order ? 0 : 1;

    # Creating the payload with the new flag value in place
    $payload = [{
        product_id => $product->id,
        channel => [ {
            channel_id => $channel->id,
            pre_order => $reverse_pre_order_flag,
        }],
    }];

    $jqt->clear_ok;

    # Sending the job via JQ
    $job = XT::JQ::DC->new( { funcname => 'Receive::Product::Update' });
    $job->set_payload( $payload );
        $job->send_job;
    $jqt->is_last_job(
        { funcname => 'XT::JQ::DC::Receive::Product::Update',
        payload => $payload, },
    );
    $jqt->queue->work_until_done;

    $product->discard_changes();
    is($product->attribute->pre_order, $reverse_pre_order_flag , "pre order flag changed as expected");

    # ---------------------------------------------------------------

    $payload = [
      { canonical_product_id => 29149, product_id => $product->id() },
    ];

    $job->set_payload( $payload );
        $job->send_job;
    $jqt->is_last_job(
        { funcname => 'XT::JQ::DC::Receive::Product::Update',
        payload => $payload, },
    );
    $jqt->queue->work_until_done;

    is( $jqt->get_last_failed_job, undef, 'no failed jobs!' );
};}

Test::Class->runtests;
