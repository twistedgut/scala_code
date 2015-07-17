#!/usr/bin/env perl
use NAP::policy "tt", 'test';

=head2 Tests for Correspondence related Settings

This tests various things to do with the 'correspondence_*' tables, currently tests:

* That 'correspondence_method' is set-up correctly
* That 'correspondence_subject' is set-up correctly
* That 'csm_exclusion_calendar' is set-up correctly
* The ActiveMQ Correspondence Queues are configured correctly
* The CRM Email Addresses Used to Send Alerts to eGain with


Originally done for CANDO-431.

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ qw( $distribution_centre ) ];

use_ok( 'XTracker::Config::Local', qw(
                                        config_var
                                    ) );

use_ok( 'XTracker::Constants::FromDB', qw(
                                        :correspondence_method
                                    ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Schema sanity check' );

my @channels    = $schema->resultset('Public::Channel')->all;
my $corr_meth_rs= $schema->resultset('Public::CorrespondenceMethod');
my $corr_subj_rs= $schema->resultset('Public::CorrespondenceSubject');

my $messaging_config = Test::XTracker::Config->messaging_config();

note "Testing ActiveMQ Correspondence Queues are Configured";
is($messaging_config->{'Consumer::SMSCorrespondence'}{routes_map}{destination},
   '/queue/sms-response-' . lc( $distribution_centre ),
   'incoming SMS queue set OK');
is(config_var('Producer::Correspondence::SMS','destination'),
   '/queue/sms-incoming-message',
   'outgoing SMS queue set OK');

note "Testing ActiveMQ Correspondence Controller Retry Times are Configured";
my %retry_expect    = (
    sms_retry_count     => 5,
    sms_retry_secs      => 5,
);
my %retry_got;
foreach my $setting ( keys %retry_expect ) {
    $retry_got{ $setting }  = $messaging_config->{'Consumer::SMSCorrespondence'}{$setting};
}
is_deeply( \%retry_got, \%retry_expect, "AMQ Controller Retry Times Configured as Expected" );

# expected Methods and the state of their 'can_opt_out' flag
my %expected_methods    = (
        DC1 => {
            'SMS'       => { can_opt_out => 1, enabled => 1 },
            'Email'     => { can_opt_out => 1, enabled => 1 },
            'Phone'     => { can_opt_out => 1, enabled => 1 },
            'Document'  => { can_opt_out => 0, enabled => 1 },
            'Label'     => { can_opt_out => 0, enabled => 1 },
        },
        DC2 => {
            'SMS'       => { can_opt_out => 1, enabled => 0 },      # DC2 can't send SMS to begin with
            'Email'     => { can_opt_out => 1, enabled => 1 },
            'Phone'     => { can_opt_out => 1, enabled => 1 },
            'Document'  => { can_opt_out => 0, enabled => 1 },
            'Label'     => { can_opt_out => 0, enabled => 1 },
        },
        DC3 => {
            'SMS'       => { can_opt_out => 1, enabled => 0 },      # DC3 can't send SMS to begin with
            'Email'     => { can_opt_out => 1, enabled => 1 },
            'Phone'     => { can_opt_out => 1, enabled => 1 },
            'Document'  => { can_opt_out => 0, enabled => 1 },
            'Label'     => { can_opt_out => 0, enabled => 1 },
        },

    );

# expected Subject and the Method's assigned to it with their 'can_opt_out' & 'default_can_use' flags
my %expected_subjects   = (
            'Premier Delivery'  => {
                            'check_method'  => {
                                    'SMS'   => { can_opt_out => 1, default_can_use => 1, copy_to_crm => 0, send_from => undef },
                                    'Email' => { can_opt_out => 1, default_can_use => 1, copy_to_crm => 0, send_from => 'premier_email' },
                                    'Phone' => { can_opt_out => 1, default_can_use => 0, copy_to_crm => 0, send_from => undef },
                                },
                            'check_calendar'=> {    # 'csm_exclusion_calendar'
                                    'SMS'   => [
                                            { start_time => '21:00:00', end_time => '07:59:59' },
                                            { start_date => '25/12' },
                                        ],
                                },
                        },
        );

# expected Sales Channels with Subjects
my %expected_subject_by_channel = (
    NAP    => \%expected_subjects,
    MRP    => \%expected_subjects,
    OUTNET => \%expected_subjects,
    JC     => \%expected_subjects,
);

# expected CRM email addrsses per Sales Channel
my %expected_crm    = (
    DC1 => {
        # all though using test addresses, that a value has or hasn't
        # been set and that dev envs aren't pointing to live
        NAP => 'egaintest11.DAVE@net-a-porter.com',
        OUTNET => 'egaintest11.DAVE@net-a-porter.com',
        MRP => 'egaintest11.DAVE@net-a-porter.com',
        JC => undef,
    },
    DC2 => {
        # all though using test addresses, that a value has or hasn't
        # been set and that dev envs aren't pointing to live
        NAP => 'egaintest11.DAVE@net-a-porter.com',
        OUTNET => 'egaintest11.DAVE@net-a-porter.com',
        MRP => 'egaintest11.DAVE@net-a-porter.com',
        JC => undef,
    },
    DC3 => {
        # all though using test addresses, that a value has or hasn't
        # been set and that dev envs aren't pointing to live
        NAP => 'egaintest11.DAVE@net-a-porter.com',
        OUTNET => 'egaintest11.DAVE@net-a-porter.com',
        MRP => 'egaintest11.DAVE@net-a-porter.com',
        JC => undef,
    },
);

is( config_var( 'DistributionCentre', 'crm_sms_suffix' ), 'bulksms.co.uk', "CRM Suffix Found for DC" );

note "Testing 'correspondence_method' table";
my %got_methods = map { $_->method => { can_opt_out => $_->can_opt_out, enabled => $_->enabled } } $corr_meth_rs->all;
if ( exists( $expected_methods{ $distribution_centre } ) ) {
    my $dc_methods  = $expected_methods{ $distribution_centre };
    is_deeply( \%got_methods, $dc_methods, "Correspondence Methods and their 'can_opt_out' & 'enabled' Flags as Expected" );
}
else {
    fail( "No Expected Correspondence Methods for this DC: $distribution_centre" );
}

foreach my $channel ( @channels ) {

    note "Sales Channel: " . $channel->id . " - " . $channel->name;
    my $conf_section    = $channel->business->config_section;
    note "Config Section: $conf_section";

    note "Testing the CRM Email Addresses";
    is( config_var( "Email_${conf_section}", 'crm_email' ), $expected_crm{ $distribution_centre }{ $conf_section }, "CRM Email Address as Expected" );

    note "Testing 'correspondence_subject_method' table per Sales Channel";
    my $channel_subjects= $expected_subject_by_channel{ $conf_section };
    if ( $channel_subjects ) {
        foreach my $subject ( sort keys %{ $channel_subjects } ) {
            my $methods = $channel_subjects->{ $subject }{'check_method'};

            my $subject_rec = $corr_subj_rs->search( { subject => $subject, channel_id => $channel->id } )->first;
            isa_ok( $subject_rec, 'XTracker::Schema::Result::Public::CorrespondenceSubject', "Found Subject Record: $subject" );

            my @csm         = $subject_rec->correspondence_subject_methods->all;
            %got_methods    = map { $_->correspondence_method->method => {
                                            can_opt_out => $_->can_opt_out,
                                            default_can_use => $_->default_can_use,
                                            copy_to_crm => $_->copy_to_crm,
                                            send_from => $_->send_from,
                                        }
                                    } @csm;
            is_deeply( \%got_methods, $methods, "Methods and 'can_opt_out' & 'default_can_use' Flags as Expected for Subject" );

            # check Exclusion Calendar
            my $calendar= $channel_subjects->{ $subject }{'check_calendar'};
            my %got_calendar;
            foreach my $csm ( @csm ) {
                my @cal = $csm->csm_exclusion_calendars->search( {},
                                                            {
                                                                # get a predicatable order of records
                                                                order_by => 'start_time,end_time,start_date,end_date,day_of_week',
                                                            } )->all;
                foreach my $cal ( @cal ) {
                    # get all the 'defined' fields for this Calendar rec and push
                    # it onto an array for the Method in the %got_calendar hash
                    my %columns = $cal->get_columns;
                    delete $columns{id};        # don't want
                    delete $columns{csm_id};    # these fields
                    push @{ $got_calendar{ $csm->correspondence_method->method } }, {
                                                    map { $_ => $columns{ $_ } }
                                                        grep { defined $columns{ $_ } } keys %columns
                                                };
                }
            }
            eq_or_diff( \%got_calendar, $calendar, "Exclusion Calendar for Subject & Methods as Expected" );
        }
    }
    else {
        # No Subjects expected for Sales Channel so check there are none
        cmp_ok( $corr_subj_rs->search( { channel_id => $channel->id } )->count(), '==', 0, "No Subjects Found as Expected" );
    }
}

done_testing;
