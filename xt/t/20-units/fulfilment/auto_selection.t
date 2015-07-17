#!/usr/bin/env perl

=head1 NAME

auto_selection.t - Test auto selection

=head1 DESCRIPTION

For each enabled channel, this test runs selection tests for nominated day (due
for selection, not due for selection, overdue selection), premier and domestic
shipments, both with and without vouchers.

It sets up the shipment, runs the auto_selection. It then then runs the code to
select the shipments, finally testing that the correct shipment_request
messages were sent and that the logs were correctly populated with 'Selected'
entries.

#TAGS checkruncondition nominatedday vouchers fulfilment selection shouldbeunit

=cut

use NAP::policy "tt", 'test', 'class';
use FindBin::libs;
use Test::XTracker::RunCondition dc => 'DC1', iws_phase => '2',
    export => ['$iws_rollout_phase'];

use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw( :shipment_type );

use Test::XTracker::Data::Order::Selection qw/
    setup_normal_shipment
    setup_voucher_shipment
    do_selection
    check_selection_messages
    check_logs_for_normal_selection
    check_logs_for_voucher_selection
/;
use Test::XT::Prove::Feature::NominatedDay;
my @cases = @{$Test::XT::Prove::Feature::NominatedDay::NOMINATEDDAY_TEST_DATA};

my $schema = Test::XTracker::Data->get_schema;
my @channels = $schema->resultset('Public::Channel')->search({'is_enabled'=>1},{ order_by => { -desc => 'id' } })->all;

my @shipment_types = (
    { name => 'premier', id => $SHIPMENT_TYPE__PREMIER },
    { name => 'premier', id => $SHIPMENT_TYPE__PREMIER, with_vouchers => 1 },
    { name => 'domestic', id => $SHIPMENT_TYPE__DOMESTIC },
    { name => 'domestic', id => $SHIPMENT_TYPE__DOMESTIC, with_vouchers => 1 },
);

foreach my $channel ( @channels ) {
    foreach my $case (@cases) {
        foreach my $shipment_type (@shipment_types) {

            display_marker(
                "CASE: ".$case->{_name},
                sprintf("Creating '%s' order %s"."for channel '%s' (%s)",
                    $shipment_type->{name},
                    ($shipment_type->{with_vouchers} ? 'with vouchers ' : ''),
                    $channel->name,
                    $channel->id
                ),
            );

            my $shipment = setup_normal_shipment({
                channel => $channel,
                shipment_type_id => $shipment_type->{id},
            });
            # It only has one item at the moment, so this is safe
            my $si_product = $shipment->shipment_items->first;

            # Run some preliminary tests
            my $nom_feature = Test::XT::Prove::Feature::NominatedDay->new();
            $nom_feature->set_nominated_fields(
                $shipment,
                $case,
                $channel->timezone,
            );
            $nom_feature->test_auto_select($case, $shipment);

            if ($shipment_type->{with_vouchers}) {
                if ($channel->business->config_section eq 'NAP') {
                    # with vouchers
                    note "\n" . ('#' x 80) . "\nTESTING Selection with Physical & Virtual Vouchers\n" . ('#' x 80) . "\n";

                    my ($si_physical_voucher, $si_virtual_voucher) = setup_voucher_shipment({
                        shipment => $shipment
                    });

                    my $message_logger = do_selection({ shipment => $shipment });

                    check_selection_messages({
                        channel => $channel,
                        shipment => $shipment,
                        message_logger => $message_logger,
                        vouchers_flag => $shipment_type->{with_vouchers},
                        iws_rollout_phase => $iws_rollout_phase,
                    });
                    check_logs_for_voucher_selection({
                        shipment => $shipment,
                        si_product => $si_product,
                        si_physical_voucher => $si_physical_voucher,
                        si_virtual_voucher => $si_virtual_voucher
                    });
                }

            } else {
                # without vouchers
                note "\n" . ('#' x 80) . "\nTESTING Selection - Regular\n" . ('#' x 80) . "\n\n";

                my $message_logger = do_selection({ shipment => $shipment });

                check_selection_messages({
                    channel => $channel,
                    shipment => $shipment,
                    message_logger => $message_logger,
                    vouchers_flag => $shipment_type->{with_vouchers},
                    iws_rollout_phase => $iws_rollout_phase,
                });

                check_logs_for_normal_selection({ shipment => $shipment });
            }

        } # shipment type
    } # cases
} # channels

done_testing;

sub display_marker {
    my (@lines) = @_;
    note "\n\n" . ('#' x 80);
    note $_ for @lines;
    note( ('#' x 80) . "\n");
}
