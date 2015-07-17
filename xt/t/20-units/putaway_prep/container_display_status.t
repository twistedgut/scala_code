#!/usr/bin/env perl

# TODO: This should probably be a .pm, no real reason for it being in a .t
#   other than I couldn't think of a good place to put the .pm
#   see http://reviewboard.jaffar.dave.net-a-porter.com/r/413/#comment2729

use NAP::policy "tt", 'test', 'class';
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends 'NAP::Test::Class';
    with 'NAP::Test::Class::Template';
};

use Test::XTracker::RunCondition prl_phase => 'prl';



use NAP::policy "tt";
use Test::XT::Data::PutawayPrep;
use XTracker::Constants::FromDB qw(
    :putaway_prep_container_status
);

sub startup :Test(startup => 5) {
    my ($test) = @_;

    $test->{setup} = Test::XT::Data::PutawayPrep->new;

    # We're creating containers that will be shared between all tests here. That's
    # fine for the simple testing needed for display_status, but if you're adding
    # other tests later which might care about container history, you might want
    # to set up new containers for them.
    foreach my $config (
        {
            test_type => 'stock process',
            recode => 0,
            group_id_field_name => 'pgid',
        },
        {
            test_type => 'stock recode',
            recode => 1,
            group_id_field_name => 'recode_id',
        },
    ) {
        note("set up ".$config->{test_type});
        # setup
        my ($stock_process, $product_data)
            = $test->{setup}->create_product_and_stock_process( 1, {
                group_type => ($config->{recode}
                    ? XTracker::Database::PutawayPrep::RecodeBased->name
                    : XTracker::Database::PutawayPrep->name
                ),
            });
        my $group_id = $product_data->{ $config->{group_id_field_name} };
        my $sku = $product_data->{sku};
        my $pp_group = $test->{setup}->create_pp_group({
            group_id => $group_id,
            group_type => ($config->{recode}
                ? XTracker::Database::PutawayPrep::RecodeBased->name
                : XTracker::Database::PutawayPrep->name
            ),
        });
        my $pp_container = $test->{setup}->create_pp_container;

        $test->{pp_container}->{$config->{test_type}} = $pp_container;
    }
}

# TESTS

sub display_status__no_advice_yet : Tests {
    my ($test) = @_;

    note "Container still in progress";

    foreach my $test_type ('stock process', 'stock recode') {
        my $pp_container = $test->{pp_container}->{$test_type};
        $pp_container->update({
            putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS,
        });

        is ($test->display_status($pp_container), '(blank)',
            $test_type.": Display status for container in progress is empty");
    }
}

sub display_status__advice_sent : Tests {
    my ($test) = @_;

    note "Advice has been sent, no response received";

    foreach my $test_type ('stock process', 'stock recode') {
        my $pp_container = $test->{pp_container}->{$test_type};
        $pp_container->update({
            putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT,
        });

        is ($test->display_status($pp_container), 'Sent',
            $test_type.": Display status when advice sent is 'Sent'");
    }
}

sub display_status__failed_container : Tests {
    my ($test) = @_;

    my $failure_reason = "Test failure reason: $$";
    note "Fail the container: reason: '$failure_reason'";

    foreach my $test_type ('stock process', 'stock recode') {
        my $pp_container = $test->{pp_container}->{$test_type};
        $pp_container->update({
            putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__FAILURE,
            failure_reason => $failure_reason,
        });

        is ($test->display_status($pp_container), $failure_reason,
            $test_type.": Display status for failed container shows reason");
    }
}

sub display_status__success : Tests {
    my ($test) = @_;

    note "Successful container";

    foreach my $test_type ('stock process', 'stock recode') {
        my $pp_container = $test->{pp_container}->{$test_type};
        $pp_container->update({
            putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
        });

        is ($test->display_status($pp_container), 'Putaway',
            $test_type.": Display status for successful container is 'Putaway'");
    }
}


=head2 display_status

Utility function to process the template and extract the status

First calls a wrapper template, which then includes the template we're testing.

=cut

sub display_status {
    my ($test, $pp_container) = @_;

    my $template_vars = {
        status_id => $pp_container->status_id,
        failure_reason => $pp_container->failure_reason || undef,
        container_display_status => 'Unset',
    };

    my $output = $test->process('putaway/container_status.tt', $template_vars);

    my ($status) = $output =~ m/container_display_status is "(.+)"/;
    if ($status eq '<!-- nothing displayed -->') { $status = '(blank)'; }

    return $status;
}

Test::Class->runtests;
