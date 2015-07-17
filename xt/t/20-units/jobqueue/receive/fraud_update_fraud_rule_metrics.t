#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';

=head1 NAME

fraud_update_fraud_rule_metrics.t

=head1 DESCRIPTION

Test the 'Receive::Fraud::UpdateFraudRuleMetrics' worker

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::FraudRule;

use Test::MockObject;


sub startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->{channel}     = Test::XTracker::Data->channel_for_nap;
    $self->{jobq_worker} = 'Receive::Fraud::UpdateFraudRuleMetrics';

    Test::XTracker::Data::FraudRule->split_live_and_archived_id_sequences();

    use_ok( 'XT::JQ::DC::' . $self->{jobq_worker} );
}

sub setup: Test( setup => no_plan ) {
    my $self = shift;
    $self->schema->txn_begin;
}

sub teardown : Tests( teardown => no_plan ) {
    my $self = shift;
    $self->schema->txn_rollback();
}

=head1 TESTS

=head2 test_job_updates_metrics_when_live_rules_exist

Test that the Job Updates the Metrics for the correct Rules
when Live Rules matching the Archived Rule Ids still exist
in the table.

=cut

sub test_job_updates_metrics_when_live_rules_exist : Tests {
    my $self = shift;

    Test::XTracker::Data::FraudRule->delete_fraud_rules();
    my @rules = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', {
        how_many => 5,
    } );

    # split the Rules into those that expected
    # to get updated and those that don't
    my @rules_to_update     = @rules[ 0, 2, 4 ];
    my @rules_to_not_update = @rules[ 1, 3 ];

    # set all Archived Rule & Live Rule Metrics to ZERO
    $self->_zero_metrics();

    my @archived_rule_ids = map {
        $_->archived_rule_id
    } @rules_to_update;

    my $payload = {
        job_tag => 'TEST',
        decisioning_archived_rule_id => $rules_to_update[-1]->archived_rule_id,
        archived_rule_ids_used       => \@archived_rule_ids,
    };


    note "Test with a Deciding Archived Rule Id";
    lives_ok( sub {
        $self->_send_job( $payload, $self->{jobq_worker} );
    }, "Send Update Metrics Job" );

    $self->_check_metrics( \@rules_to_update, {
        used_count       => 1,
        decided_count    => 1,
        deciding_rule_id => $rules_to_update[-1]->id,
    }, "Metrics for Records that were Updated are as Expected" );

    $self->_check_metrics( \@rules_to_not_update, {
        used_count    => 0,
        decided_count => 0,
    }, "Metrics for Records NOT Updated are as Expected" );


    note "Test without a Deciding Archived Rule Id";
    $payload->{decisioning_archived_rule_id} = undef;
    lives_ok( sub {
        $self->_send_job( $payload, $self->{jobq_worker} );
    }, "Send Update Metrics Job" );

    $self->_check_metrics( \@rules_to_update, {
        used_count       => 2,
        decided_count    => 1,  # this will still be 1
        deciding_rule_id => $rules_to_update[-1]->id,
    }, "Metrics for Records that were Updated are as Expected" );

    $self->_check_metrics( \@rules_to_not_update, {
        used_count    => 0,
        decided_count => 0,
    }, "Metrics for Records NOT Updated are as Expected" );
}

=head2 test_job_updates_metrics_for_archived_rules

Test that the Job Updates the Metrics for the Archived Rules
when the Live Rules matching the Archived Rule Ids don't
exist in the table.

When new Rules are Published the existing Live Rules are
removed and new ones with new Archived Ids will be created
hence the test for when this happens that the metrics on
the Archived Rules for the old Live Rules are updated.

=cut

sub test_job_updates_metrics_for_archived_rules : Tests {
    my $self = shift;

    Test::XTracker::Data::FraudRule->delete_fraud_rules();
    my @rules = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', {
        how_many => 5,
    } );
    my @archived_rules = map { $_->archived_rule } @rules;

    # split the Rules into those that expected
    # to get updated and those that don't
    my @rules_to_update     = @archived_rules[ 0, 2, 4 ];
    my @rules_to_not_update = @archived_rules[ 1, 3 ];

    # remove the Staging & Live Rules just created
    Test::XTracker::Data::FraudRule->delete_fraud_rules();

    # create a new set of Live Rules
    my @new_live_rules = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', {
        how_many => 7,
    } );

    # set all Archived Rule & Live Rule Metrics to ZERO
    $self->_zero_metrics();

    my @archived_rule_ids = map {
        $_->id
    } @rules_to_update;

    my $payload = {
        job_tag => 'TEST',
        decisioning_archived_rule_id => $rules_to_update[-1]->id,
        archived_rule_ids_used       => \@archived_rule_ids,
    };


    note "Test with a Deciding Archived Rule Id";
    lives_ok( sub {
        $self->_send_job( $payload, $self->{jobq_worker} );
    }, "Send Update Metrics Job" );

    $self->_check_metrics( \@rules_to_update, {
        used_count       => 1,
        decided_count    => 1,
        deciding_rule_id => $rules_to_update[-1]->id,,
    }, "Metrics for Records that were Updated are as Expected" );

    $self->_check_metrics( \@rules_to_not_update, {
        used_count    => 0,
        decided_count => 0,
    }, "Metrics for Records NOT Updated are as Expected" );


    note "Test without a Deciding Archived Rule Id";
    $payload->{decisioning_archived_rule_id} = undef;
    lives_ok( sub {
        $self->_send_job( $payload, $self->{jobq_worker} );
    }, "Send Update Metrics Job" );

    $self->_check_metrics( \@rules_to_update, {
        used_count       => 2,
        decided_count    => 1,  # this will still be 1
        deciding_rule_id => $rules_to_update[-1]->id,
    }, "Metrics for Records that were Updated are as Expected" );

    $self->_check_metrics( \@rules_to_not_update, {
        used_count    => 0,
        decided_count => 0,
    }, "Metrics for Records NOT Updated are as Expected" );


    # now make sure the new Live Rule Metrics still remain at ZERO
    $self->_check_metrics( \@new_live_rules, {
        used_count    => 0,
        decided_count => 0,
    }, "New Live Rules all have their Metric Counters still at ZERO" );
}

#--------------------------------------------------------------

sub _check_metrics {
    my ( $self, $records, $args, $msg ) = @_;

    my $expect_used_count    = $args->{used_count};
    my $expect_decided_count = $args->{decided_count};
    my $deciding_rule_id     = $args->{deciding_rule_id} // 0;

    $msg ||= "Metric Counts are as Expected";

    my %got = map {
        $_->discard_changes->id => {
            metric_used    => $_->metric_used,
            metric_decided => $_->metric_decided,
        }
    } @{ $records };

    my %expected = map {
        $_ => {
            metric_used    => $expect_used_count,
            metric_decided => (
                $deciding_rule_id == $_
                ? $expect_decided_count
                : 0
            )
        }
    } keys %got;

    cmp_deeply( \%got, \%expected, $msg );

    return;
}

sub _zero_metrics {
    my $self = shift;

    $self->rs('Fraud::LiveRule')->update( {
        metric_used    => 0,
        metric_decided => 0,
    } );

    $self->rs('Fraud::ArchivedRule')->update( {
        metric_used    => 0,
        metric_decided => 0,
    } );

    return;
}

# Creates and executes a job
sub _send_job {
    my $self = shift;
    my $payload = shift;
    my $worker  = shift;

    note "Job Payload: " . p( $payload );

    my $fake_job    = _setup_fake_job();
    my $funcname    = 'XT::JQ::DC::' . $worker;
    my $job         = new_ok( $funcname => [
        payload => $payload,
        schema  => $self->{schema},
        dbh     => $self->{schema}->storage->dbh,
    ] );
    my $errstr      = $job->check_job_payload($fake_job);
    die $errstr     if ( $errstr );
    $job->do_the_task( $fake_job );

    return $job;
}


# setup a fake TheShwartz::Job
sub _setup_fake_job {
    my $fake = Test::MockObject->new();
    $fake->set_isa('TheSchwartz::Job');
    $fake->set_always( completed => 1 );
    return $fake;
}

Test::Class->runtests;
