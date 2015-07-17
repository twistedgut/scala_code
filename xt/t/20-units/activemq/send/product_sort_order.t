#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::RunCondition  database => 'full';
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::Exception;
use XTracker::Config::Local qw/config_var/;
use XTracker::Constants '$APPLICATION_OPERATOR_ID';
use XTracker::Database::Product::SortOrder
    qw(update_pws_sort_data
       list_pws_sort_variables);
use Test::XT::BlankDB;

my $amq = Test::XTracker::MessageQueue->new();
my $schema  = Test::XTracker::Data->get_schema;

my $msg_type = 'XT::DC::Messaging::Producer::Product::SortOrder';
my $amq_destination = config_var('Producer::Product::SortOrder','destination');
my ($channel,$pids)=Test::XTracker::Data->grab_products({
    how_many => 5,
});

my $data = {
    channel_id => $channel->id,
    environment => 'staging',
    destination => 'main', # or 'preview'
    product_ids => [ map { $_->{pid} } @$pids ],
};

if (Test::XT::BlankDB::check_blank_db($schema)) {
    # this is not needed on the full db
    # FIXME This needs fixing, I don't understand it
    # It doesn't appear to do enough for this test to pass
    # using the blank db reliably
    Test::XTracker::Data->set_pws_sort_variable_weightings;

    # this is also not needed, and it takes ages to run, too
    update_pws_sort_data({
        destination => $data->{destination},
        channel_id => $data->{channel_id},
    });
}

$amq->clear_destination($amq_destination);

lives_ok {
    $amq->transform_and_send(
        $msg_type,
        $data,
    )
}
"Can send valid message";

$amq->assert_messages({
    destination => $amq_destination,
    assert_header => superhashof({
        type => 'product_sort_order',
    }),
    assert_body => superhashof({
        destination => $data->{destination},
        products => bag(
            map { +{
                product_id => $_->{pid},
                channel_id => $channel->id,
                sort_order => ignore(),
            } } @$pids
        ),
    }),
}, 'Message contains the correct products and is going in the correct destination' );

done_testing();
