#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

nominated_day.t - Test Nominated Day functionality during selection

=head1 DESCRIPTION

There's one set of tests here that is mech - the rest should be unit tests.

In the mech test, we create a domestic nominated day order and verify that it
has the correct CSS classes applied to it on the selection page.

#TAGS fulfilment selection nominatedday iws email premier loops duplication movetounit whm

=cut

use Readonly;

use Data::Dump qw/pp/;
use IO::File;

use Test::XTracker::LoadTestConfig;

use Test::More::Prefix qw/ test_prefix /;
use Test::XT::Prove::Feature::NominatedDay;
use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Config::Local         qw( :DEFAULT );

use XTracker::Constants           qw( :application );
use XTracker::Constants::FromDB   qw(
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_type
                                        :authorisation_level
                                    );

use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Flow;
use Test::XT::Data::Container;
use XTracker::Script::Shipment::NominatedDayPossibleBreach;
use XTracker::EmailFunctions;

Readonly my $TEST_EMAIL_FILE => 't/tmp/test_email.txt';

{
    # FIXME: If we port this to Test::Class make sure we localise this!
    # monkey patch send_email to write to a file for the purpose of testing
    no strict 'refs'; ## no critic (ProhibitNoStrict)
    no warnings "redefine";
    *XTracker::EmailFunctions::send_email = sub {
        my($from,$replyto,$to,$subject,$msg,$type,$attachments) = @_;

        my $suffix = 1;
        while (-f "${TEST_EMAIL_FILE}.${suffix}") {
            $suffix++;
        }

        my $fh = IO::File->new("> ${TEST_EMAIL_FILE}.${suffix}");
        print $fh $msg;
        $fh->close;
    };
}


my $schema = Test::XTracker::Data->get_schema;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Feature::NominatedDay',
    ],
);
$framework->login_with_permissions({
    dept => 'Distribution Management',
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Selection',
    ]}
});


# Run tests for all enabled channels
my @channels = $schema->resultset('Public::Channel')->search({ is_enabled => 1 });
my %channel_opts = map { $_->id() => 1 } @channels;
my $pid_set = Test::XTracker::Data->get_pid_set(\%channel_opts);

# When auto-selection is turned on there are no checkboxes on the selection
# page, so this test fails.  This hack is necessary until we make a change to
# the blank db creation to set the flag to false by default
$schema->resultset('SystemConfig::Parameter')
       ->find({name => 'enable_auto_selection'})
       ->update({value => 0});

foreach my $bus (values %{$pid_set}) {
    my $channel = $bus->{channel};
    my $pids    = $bus->{pids};

    test_prefix("manual:" . $channel->name);
    test_manual_select(
        Test::XTracker::Data->create_domestic_order(
            channel => $channel,
            pids    => $pids,
            date    => DateTime->now(time_zone => $channel->timezone),
        )->shipments->first,
        $framework, $channel->timezone);

    test_prefix("breach:" . $channel->name);
    test_nominated_day_possible_and_actual_breach(
        Test::XTracker::Data->create_domestic_order(
            channel => $channel,
            pids    => $pids,
            date    => DateTime->now(time_zone => $channel->timezone),
        )->shipments->first,
        $channel->timezone);

}

sub test_manual_select {
    my($shipment, $flow, $timezone) = @_;

    my $nom_feature = Test::XT::Prove::Feature::NominatedDay->new();
    foreach my $case (@{$nom_feature->get_nominated_day_test_data}) {
        my $manual_select_test = $case->{test}->{manual_select} || {};

        $nom_feature->set_nominated_fields($shipment, $case, $timezone);
        $nom_feature->test_manual_select_get_selection_list(
            $case->{test},
            $shipment,
        );

        note "shipment_id ". $shipment->id;
        $flow->flow_mech__fulfilment__selection;

        # loop through the pages until it finds shipment or reaches the end
        # and causes an exception.
        eval {
            while (!$flow->flow_mech__fulfilment__selection_find_shipment(
                $shipment->id)) {

                $flow->flow_mech__fulfilment__selection_next;
            }
        };
        if (my $e = $@) {
            die "Cannot find shipment (" . $shipment->id . ") - " . $e;
        }

        $flow->test_mech__fulfilment__selection_nominatedday(
            $manual_select_test,
            $shipment,
        );
    }
}

sub test_nominated_day_possible_and_actual_breach {
    my($shipment, $timezone) = @_;

    my $nom_feature = Test::XT::Prove::Feature::NominatedDay->new();
    foreach my $case (@{$nom_feature->get_nominated_day_test_data}) {

        $nom_feature->set_nominated_fields($shipment, $case, $timezone);
        note "test name: ". $case->{_name};
        note "shipment_id ". $shipment->id;

        $nom_feature->test_possible_and_actual_breach(
            $case->{test},
            $shipment,
            $TEST_EMAIL_FILE,
        );

    }
}



done_testing;
