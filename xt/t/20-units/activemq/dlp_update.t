#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local qw/config_var/;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw/$WEB_CONTENT_TYPE__DESIGNER_FOCUS
                                  $WEB_CONTENT_TEMPLATE__STANDARD_DESIGNER_LANDING_PAGE
                                  $WEB_CONTENT_INSTANCE_STATUS__DRAFT
                                  $WEB_CONTENT_FIELD__TITLE
                                  $DESIGNER_WEBSITE_STATE__INVISIBLE/;
use DateTime;
use Data::Dump qw/pp/;

my $amq = Test::XTracker::MessageQueue->new;

isa_ok( $amq, 'Test::XTracker::MessageQueue' );

my $schema = Test::XTracker::Data->get_schema;

isa_ok( $schema, 'XTracker::Schema' );

my $factory = $amq->producer;

isa_ok( $factory, 'Net::Stomp::Producer' );

#####################################################################

my $mesg_type = 'XT::DC::Messaging::Producer::DLP::Update';

note "testing amq message type: $mesg_type";



########################################################
##
## Decide on a designer - the first with a DLP (using sql)
## and store the Title of the page in $correct_dlp_title
##
########################################################

# my $designer_to_test_with = 'Prada';

my @stuff_to_delete=();

END {
    for my $o (@stuff_to_delete) {
        $o->delete;
    }
}

my $designer;

$schema->txn_do(sub {
my $max_designer_id = $schema->resultset('Public::Designer')->search({})->get_column('id')->max();
$designer = $schema->resultset('Public::Designer')->create({
    id => $max_designer_id+1,
    designer => 'test designer '.($max_designer_id+1),
    url_key => 'test',
});
my $channel = Test::XTracker::Data->channel_for_business(name => 'nap');
my $page = $schema->resultset('WebContent::Page')->create({
    name => 'Designer - '.$designer->designer(),
    type_id => $WEB_CONTENT_TYPE__DESIGNER_FOCUS,
    template_id => $WEB_CONTENT_TEMPLATE__STANDARD_DESIGNER_LANDING_PAGE,
    page_key => 'test_designer_page',
    channel_id => $channel->id,
});
my $instance = $page->create_related('instances',{
    label => 'foo',
    status_id => $WEB_CONTENT_INSTANCE_STATUS__DRAFT,
    created => DateTime->now(),
    created_by => $APPLICATION_OPERATOR_ID,
    last_updated => DateTime->now(),
    last_updated_by => $APPLICATION_OPERATOR_ID,
});
my $content = $instance->create_related('contents',{
    field_id => $WEB_CONTENT_FIELD__TITLE,
    content => 'some title',
});
my $designer_channel = $designer->create_related('designer_channel',{
    page_id => $page->id,
    website_state_id => $DESIGNER_WEBSITE_STATE__INVISIBLE,
    channel_id => $channel->id,
    description => 'foo',
    description_is_live => 0,
});
push @stuff_to_delete, $designer_channel,$content,$instance,$page,$designer;
});

my $channel_id = $designer->channels->search->first->id;
my $designer_id = $designer->id;
my $page = $schema->resultset('WebContent::Page')->search( { name => 'Designer - ' . $designer->designer, } )->first;
my $page_instance = $page->instances->search(undef, {order_by => { -desc=>'id'}} )->first;

# Get the page content
my $page_content = $schema->resultset('WebContent::Content')->search( { instance_id => $page_instance->id});

my $title_field_type = $schema->resultset('WebContent::Field')->search({ name=>'Title' })->first;


note 'Testing with designer: '.$designer->designer;
note 'Channel: '.$channel_id;
note 'Designer Id: '.$designer_id;
note 'Page Instance '.pp($page_instance->id);
note 'Title field id: '.pp($title_field_type->id);
my $correct_dlp_title =  $page_content->search({field_id => $title_field_type->id})->first->content;
note 'Current Value: '.$correct_dlp_title;


########################################################
##
## Send ourselves this DLP (with ActiveMQ)
##
########################################################

my $destination = config_var('Producer::DLP::Update', 'destination');
$amq->clear_destination($destination);

lives_ok {
    $factory->transform_and_send(
        $mesg_type,
        {
            schema   => $schema,
            designer => $designer_id,
            channel  => $channel_id,
        },
    );
}
"Can send valid message";


########################################################
##
## Make sure the ActiveMQ Title is the one we got with SQL
## NOTE:  We are looking on the broadcast channel
## (usually we'd look on the incoming channel)
##
########################################################
$amq->assert_messages({
    destination => $destination,
    filter_header => superhashof({
        type => 'dlp',
    }),
    filter_body => superhashof({
        id => $designer_id,
    }),
    assert_body => superhashof({
        Title => $correct_dlp_title,
    }),
}, 'Message contains correct designer name and is going to correct queue',
);


done_testing;
