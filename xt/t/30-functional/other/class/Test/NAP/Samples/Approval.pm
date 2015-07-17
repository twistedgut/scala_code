package Test::NAP::Samples::Approval;

=head1 NAME

Test::NAP::Samples::Approval - Test Samples approval

=head1 DESCRIPTION

Test Samples approval.

Is this enough coverage?

#TAGS inventory sample prl poorcoverage

=head1 METHODS

=cut

use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';

use Test::XTracker::RunCondition export => [qw( $prl_rollout_phase )];

use Test::More::Prefix 'test_prefix';
use Test::XT::Flow;
use Test::XTracker::Data;

use XTracker::Constants::FromDB qw( :authorisation_level );

sub startup : Test(startup => 1) {
    my ( $self ) = @_;

    test_prefix 'Startup';

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [qw(
            Test::XT::Flow::Samples
        )],
    );

    $self->{framework}->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Inventory',
                'Stock Control/Sample',
            ],
        },
        dept => 'Stock Control',
    });

    $self->{framework}->mech->force_datalite(1);
}

=head2 test_insufficient_stock_for_samples

Get a product variant.

Reset its stock level so only 2 units are available.

Create three sample requests for that variant.

Approve first one - should succeed, leaving 1 unit available.

Try to approve the other two requests - should fail as only one can be fulfilled.

=cut

sub test_insufficient_stock_for_samples : Tests {
    my ( $self ) = @_;

    test_prefix 'Insufficient Stock for Samples';

    my $framework = $self->{framework};

    # Get a product variant
    my ( $channel, $pids ) = Test::XTracker::Data->grab_products({ force_create => 1 });
    my $variant = $pids->[0]->{variant};
    my $sku = $variant->sku;

    # Reset its stock level so only 2 units are available
    $variant->quantities->update({ quantity => 2 });

    # Create three sample requests for that variant
    my @sample_shipments = map {
        $framework->db__samples__create_stock_transfer(
            $channel->id,
            $variant->id,
            {},
        );
    } 1..3;

    # Approve first one - should succeed, leaving 1 unit available
    $framework
        ->flow_mech__samples__stock_control_sample
        ->flow_mech__samples__stock_control_approve_transfer(
            $sample_shipments[0]->id);

    if ($prl_rollout_phase) {
        is(
            $sample_shipments[0]->shipments->first->allocations->count,
            1,
            "The first Shipment has an Allocation
             (just a sanity check to see that they're written to the db at all)",
        );
    }


    # Try to approve the other two requests - should fail as only one can be fulfilled
    $framework
        ->flow_mech__samples__stock_control_sample
        ->catch_error(
            qr/Not enough stock available to approve the sample requests for SKU $sku: Stock available = 1, stock requested = 2\./,
            'Error should explain not enough stock to fulfil sample requests',
            flow_mech__samples__stock_control_approve_transfer => (
                map { $_->id } @sample_shipments[1..2],
            ),
        );
}

1;
