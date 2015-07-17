#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Data::Dump qw(pp);

use Test::More::Prefix qw/test_prefix/;

use Test::XTracker::RunCondition
    iws_phase => 'iws', export => qw( $iws_rollout_phase );
use Test::XTracker::Data;
use XTracker::Config::Local;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::PrintDocs;
use Test::XTracker::LocationMigration;
use Test::XT::Flow;
use Test::XTracker::MessageQueue;

use XTracker::Constants::FromDB qw( :authorisation_level );

=head1 NAME

move-through-transit.t - Perform various tests on the transit location

=head1 DESCRIPTION

What we test:

=over 4

=item * Move an item out of IWS main stock into transit.
This involves sending a synthetic I<inventory_adjust> message
to XT with the magic reason B<stock out to xt>.

=item * Make sure that that item appears in transit

=item * Check that stock levels reflect its disappearance

=item * Move that item out of transit into Quarantine

=item * Check that it appears in Quarantine

=item * Check that it disappears from Transit

=back

We perform the above process twice, once treating the
item as I<faulty>, and once as I<non-faulty>.

The former just plops it into quarantine, while the latter also
initiates an RTV process for it too.

#TAGS iws transit quarantine inventory loops whm

=cut

test_prefix('Setup');

my $schema = Test::XTracker::Data->get_schema;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Flow::StockControl::Quarantine',
    ],
);


my $mech=$framework->mech;

$mech->force_datalite(1);

my $perms = {
    $AUTHORISATION_LEVEL__MANAGER => [
        'Stock Control/Inventory'
    ],
};

my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');

run_tests_in_phase($iws_rollout_phase);

done_testing;

sub run_tests_in_phase {
    my $phase = shift;

    note "Testing in phase $phase";

    test_prefix("Phase $phase");

    $framework->login_with_permissions( { perms => $perms, dept => 'Distribution Management' } );

    # synthesize a stock_adjustment for something that XT thinks is in main stock

    my (undef, $pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
        with_delivery => 1,
    });

    my ($status,$reason) = ('main','stock out to xt');

    my ($sku, $product, $variant_id, $variant ) = @{$pids->[0]}{qw( sku product variant_id variant )};

    # 'L' for faulty, since 'V' was already taken by 'non-faulty'. Obviously.

    my %resolutions = ( faulty       => { type => 'L', destination => 'Quarantine' },
                        'non-faulty' => { type => 'V', destination => 'RTV Transfer Pending' }
                      );

    my @quantity_changes = (1, 2, 5, 8, 13, 21);

    foreach my $resolution_name (keys %resolutions) {
        my $resolution = $resolutions{$resolution_name};

        foreach my $quantity_change (@quantity_changes) {

            my $payload = {
                sku => $sku,
                quantity_change => -$quantity_change,
                reason => $reason,
                stock_status => $status,
            };

            my $factory = Test::XTracker::MessageQueue->new();

            my $db_state = Test::XTracker::LocationMigration->new( variant_id => $variant_id );

            $db_state->snapshot('Before Inventory Adjust');

            $wms_to_xt->new_files;

            $factory->transform_and_send('XT::DC::Messaging::Producer::WMS::InventoryAdjust',$payload);

            $wms_to_xt->expect_messages( {
                            messages => [ {   type    => 'inventory_adjust',
                                              details => { reason => $reason,
                                                           sku => $sku,
                                                           quantity_change => -$quantity_change
                                                         }
                                        } ]
                             }
                         );

            # now see if that message has been acted upon, and the SKU we wanted
            # has turned up in 'Transit'

            $db_state->snapshot('After Inventory Adjust');

            $db_state->test_delta(
                from => 'Before Inventory Adjust',
                to   => 'After Inventory Adjust',
                stock_status => { 'Main Stock'          => -$quantity_change,
                                  'In transit from IWS' => +$quantity_change
                                }
            );

            note "Performing $resolution_name resolution";

            $framework->flow_mech__stockcontrol__inventory_stockquarantine( $product->id )
                      ->flow_mech__stockcontrol__inventory_stockquarantine_submit(
                            variant_id => $variant_id,
                            location => 'Transit',
                            quantity => $quantity_change,
                            type => $resolution->{type}
                        );

            $db_state->snapshot('After Quarantine Stock');

            $db_state->test_delta(
                from => 'After Inventory Adjust',
                to   => 'After Quarantine Stock',
                stock_status => { 'In transit from IWS'       => -$quantity_change,
                                   $resolution->{destination} => +$quantity_change
                                }
            );

            $db_state->test_delta(
                from => 'Before Inventory Adjust',
                to   => 'After Quarantine Stock',
                stock_status => { 'Main Stock'                => -$quantity_change,
                                  $resolution->{destination}  => +$quantity_change
                                }
            );
        }
    }
}

