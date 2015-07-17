#!/usr/bin/env perl
use NAP::policy "tt", 'test';


use Time::HiRes 'time';
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw/$WEB_CONTENT_TYPE__DESIGNER_FOCUS
                                  $WEB_CONTENT_TEMPLATE__STANDARD_DESIGNER_LANDING_PAGE
                                  $WEB_CONTENT_INSTANCE_STATUS__DRAFT
                                  $WEB_CONTENT_FIELD__TITLE
                                  $DESIGNER_WEBSITE_STATE__INVISIBLE
                                  :correspondence_templates/;
use XTracker::Config::Local;
use DateTime;

# FIXME: FUL-4553
my $incoming_queue = Test::XTracker::Config->messaging_config->{'Consumer::DLP'}{routes_map}{destination};

my $schema = Test::XTracker::Data->get_schema;
my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;

########################################################
##
## Decide on a designer to test - the first with a DLP
## and save the title of the DLP (SQL)
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
    id => ($max_designer_id + 1),
    designer => 'test designer '.($max_designer_id + 1),
    url_key => 'test_'.($max_designer_id + 1),
});
my $channel = Test::XTracker::Data->channel_for_business(name => 'nap');
my $page = $schema->resultset('WebContent::Page')->create({
    name => 'Designer - test designer '.($max_designer_id + 1),
    type_id => $WEB_CONTENT_TYPE__DESIGNER_FOCUS,
    template_id => $WEB_CONTENT_TEMPLATE__STANDARD_DESIGNER_LANDING_PAGE,
    page_key => 'test_designer_'.($max_designer_id + 1).'page',
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
note 'Page Instance '.p($page_instance->id);
note 'Title field id: '.p($title_field_type->id);
my $correct_dlp_title =  $page_content->search({field_id => $title_field_type->id})->first->content;
note 'Current Value: '.$correct_dlp_title;


########################################################
##
## Set a new title (containing the date) using Catalyst
## (we're jumping past ActiveMQ)
##
########################################################

my $new_title = 'DLP_test:'.join(':',localtime(),"__",time);

note $new_title;

my ($payload,$header) = test_payload($designer_id, $new_title);
note  'Sending: '.p($payload);
my $res = $amq->request($app, $incoming_queue, $payload, $header );
ok( $res->is_success, 'no ERROR in attempted DLP update' );

########################################################
##
## Check that the new title is what was expected (SQL)
##
########################################################

my $new_dlp_title =  $page_content->search({field_id => $title_field_type->id})->first->content;
ok($new_dlp_title eq $new_title, "correctly stored the new title $new_title in the database");


########################################################
##
## Give the title the old value using Catalyst
##
########################################################

($payload,$header) = test_payload($designer_id, $correct_dlp_title);
note  'Sending: '.p($payload);
$res = $amq->request($app, $incoming_queue, $payload, $header );
ok( $res->is_success, 'no ERROR in attempted DLP update' );


$new_dlp_title =  $page_content->search({field_id => $title_field_type->id})->first->content;
ok($new_dlp_title eq $correct_dlp_title, "correctly stored the new title $new_dlp_title in the database");

sub test_payload {
    my ($designer_id, $title) = @_;

    return {
        #'@type' => 'dlp',
        id => $designer_id,
        Title => $title,
    },{
        type => 'dlp',
    };
}

done_testing;
