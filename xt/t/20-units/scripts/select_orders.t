#!/usr/bin/env perl

use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
    with qw/Test::Role::WithSchema Test::Role::DBSamples/;
};

use XTracker::Constants::FromDB ':storage_type';
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Script::PRL::SelectOrders;

use Test::XTracker::RunCondition prl_phase => 'prl';

sub invoke :Tests() {
    my $self = shift;

    note 'Create two orders one with item from Full PRL and other - from Dematic';
    my ($order_full_prl, $order_dematic) =
        map { $self->test_data->new_order(products => [$_]) }
        map {
            Test::XTracker::Data->create_test_products({ storage_type_id => $_ })
        }
        $PRODUCT_STORAGE_TYPE__FLAT, $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT;


    note 'Start a message monitor to check the Pick messages are sent';
    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

    my $shipment_selector = XTracker::Script::PRL::SelectOrders->new({
        shipment_ids   => [ map { $_->{shipment_object}->id } $order_full_prl, $order_dematic ],
    });

    note 'Perform "invoke"';
    $shipment_selector->invoke;

    my $full_allocation = $order_full_prl->{shipment_object}->allocations->first;
    my $dcd_allocation = $order_dematic->{shipment_object}->allocations->first;

    # We should have messages for both allocations
    $xt_to_prl->expect_messages({
        messages => [
            {
                type    => 'pick',
                path    => $full_allocation->prl->amq_queue,
                details => {
                    allocation_id => $full_allocation->id,
                },
            },
            {
                type    => 'pick',
                path    => $dcd_allocation->prl->amq_queue,
                details => {
                    allocation_id => $dcd_allocation->id,
                },
            },
        ],
    });

}

Test::Class->runtests;
