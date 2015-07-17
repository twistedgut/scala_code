#!/usr/bin/env perl

=head1 NAME

customersegment.t - Testing Customer Segment creation functionality

=head1 DESCRIPTION

Testing Customer Segment creation functionality  for 'In the Box Marketing' Promotion

#TAGS shouldbecando iws checkruncondition

=head1 SEE ALSO

Jira issue: CANDO-1324

=cut

use NAP::policy "tt", 'test';

use FindBin::libs;

use Test::XT::Flow;
use Test::XTracker::Data;
use Test::XTracker::Data::MarketingCustomerSegment;
use DateTime;

use Test::XTracker::RunCondition dc => 'DC1', export => qw( $iws_rollout_phase );
use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :department
                                        );

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::NAPEvents::IntheBox',
    ],
);

$framework->login_with_permissions({
    dept => 'Marketing',
    perms => { $AUTHORISATION_LEVEL__OPERATOR => [
        'NAP Events/In The Box',
    ]},

});


my $schema = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );


#--------- Tests ----------------------------------------------
_test_customer_segment_functionality( $schema, 1 );
#--------------------------------------------------------------

done_testing;

sub _test_customer_segment_functionality {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_customer_segment_functionality", 1       if ( !$oktodo );

        note "TESTING Create/Edit/Disable/Enable Customer Segment -In the box marketing promotion";

        my $channel    = Test::XTracker::Data->channel_for_business(name=>'nap');
        my $now        = DateTime->now();
        my $past       = $now - DateTime::Duration->new( days => 2 );
        my $customers  = Test::XTracker::Data::MarketingCustomerSegment->grab_customers( { how_many => 3, channel_id => $channel->id } );

        # 1) Create Customer Segment
        my $title =  'Dummy customer segment'. $$;
        $framework->flow_mech__customer_segment__create_link
                  ->flow_mech__inthebox__create_customer_segment_submit({
                    segment_channel_id      => $channel->id,
                    customer_segment_name   => $title,
                });

        #check customer segment got created
        like( $framework->mech->app_status_message(), qr/Customer Segment was created succesfully/i, "Customer Segment creation Success message" );

        # Attach two customer to the segment
        my @customer_numbers;
        foreach my $cn ( @{$customers}) {
            push(@customer_numbers, $cn->{customer}->is_customer_number);
        }
        $framework->flow_mech__inthebox__create_customer_segment_submit({
                    add_customer_list => join(',', @customer_numbers ),
                });

        #check the customer list was sent to job queue
       like( $framework->mech->app_info_message(),
        qr/Successfully sent a job queue request to attach 3 Customer\(s\) to Customer Segment/i,
        "Customer List sent to jobqeue succesfully"
       );

        my $segment_row = $schema->resultset('Public::MarketingCustomerSegment')->search({},
                                { order_by   => 'me.id DESC'}
                            )->first;



        my $segment_id = $segment_row->id;

        #check disable functionality
        $framework->flow_mech__customer_segment_summary
              ->flow_mech__inthebox__enable_disable_segment_submit({
                segment_id    => $segment_id,});

        my $page_data = $framework->mech->as_data()->{data}->{$channel->business->name};

        my %result = map {  $_->{'Customer Segment Name'}->{'value'} => 1 }
                     grep { $_->{'Customer Segment Name'}->{value} eq  $title &&
                        $_->{'Customer Segment Name'}->{url}   =~ /segment_id=$segment_id\&/
                     }
                     @{ $page_data->{'Disabled Customer Segment List'} };


        is($result{$title}, 1, "Customer Segment is Listed in disable Segment list" );


        #check enabling functionality
        $framework->flow_mech__customer_segment_summary
              ->flow_mech__inthebox__enable_disable_segment_submit({
                segment_id    => $segment_id,});

        $page_data = $framework->mech->as_data()->{data}->{$channel->business->name};

        %result = map {  $_->{'Customer Segment Name'}->{'value'} => 1 }
                     grep { $_->{'Customer Segment Name'}->{value} eq  $title &&
                        $_->{'Customer Segment Name'}->{url}   =~ /segment_id=$segment_id\&/
                     }
                     @{ $page_data->{'Active Customer Segment List'} };


        is($result{$title}, 1, "Customer Segment is Listed in Active Segment list" );

        # Updated the flag to check override button
        $segment_row->update( {
            job_queue_flag => 1,
            date_of_last_jq => $past,
        });

        $framework->flow_mech__customer_segment_summary
               ->flow_mech__inthebox__edit_segment_link({
                    segment_id    => $segment_id,});

       #check the override button
       like( $framework->mech->app_info_message(),
        qr/The job has been running in the background since .* If you wish to override the job Click on Override button, else come back later/i,
        "Customer Segment Override Message"
       );




     };
}







