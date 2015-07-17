package Test::NAP::Returns;

use NAP::policy qw/test class/;
use XTracker::Constants::FromDB ':authorisation_level';

use Test::XTracker::Data;
use Test::XTracker::PrintDocs;

BEGIN {
    extends 'NAP::Test::Class';
}

use Test::XT::Flow;

=head1 NAME

Test::NAP::Returns

=head1 METHODS

=head2 returns_qc_double_submit

Assert that opening two tabs at returns qc for the same return errors when the
operator attempts to process the same item on each tab. We do this for an item
with two returns to confirm that we don't break the multi-stage return
functionality.

=over

=item Dispatch an order with two items

=item Create a return for both items

=item At returns in, only process one item

=item Go to the returns qc page to begin processing that item

=item In another tab, go the same page

=item Process the item

=item Back in the first tab, process the item - expect an error

=item Back to returns in, process the other item that was part of the return

=item Go to the returns qc page and confirm the second item can be processed without any errors

=back

=cut

sub returns_qc_double_submit : Tests {
    my $self = shift;

    my $flow = Test::XT::Flow->new_with_traits(
        traits => [ qw/
            Test::XT::Data::Order
            Test::XT::Flow::CustomerCare
            Test::XT::Flow::GoodsIn
            Test::XT::Flow::PrintStation
        /]
    );

    my $shipment = $flow->dispatched_order(products => 2)->{shipment_object};
    my @variants = $shipment->shipment_items
        ->related_resultset('variant')
        ->all;

    my $perms = {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Customer Care/Customer Search',
            'Goods In/Returns In',
            'Goods In/Returns QC',
        ]
    };
    $flow->login_with_permissions({ perms => $perms, dept => 'Customer Care' });

    $flow->task_mech__customercare__create_return(
        $shipment->order->id, [map { +{ sku => $_->sku } } @variants]
    );

    # Book in just one of the returned items
    $flow->task__set_printer_station( 'GoodsIn', 'ReturnsIn' );
    $flow->task__goodsin__returns_in( $shipment->id, [$variants[0]->sku]);

    $flow->task__set_printer_station( 'GoodsIn', 'ReturnsQC' );

    my $return = $shipment->returns->not_cancelled->single;
    # Open a tab
    $flow->flow_mech__goodsin__returns_qc
        ->flow_mech__goodsin__returns_qc_submit( $return->rma_number );

    # Pass qc for the return in another tab
    {
    my $flow1 = Test::XT::Flow->new_with_traits(
        traits => [ qw/
            Test::XT::Flow::GoodsIn
            Test::XT::Flow::PrintStation
        /]
    );
    # TODO: We actually only require 'Goods In/Returns QC' here, but if we
    # don't specify them all we overwrite permissions for our other tab, where
    # the same user is logged in. It'd be nice to have something like perms =>
    # 'all' if you really don't care about granular access
    $flow1->login_with_permissions({ perms => $perms, dept => 'Customer Care' });

    $flow1->flow_mech__goodsin__returns_qc
        ->flow_mech__goodsin__returns_qc_submit( $return->rma_number )
        ->flow_mech__goodsin__returns_qc__process;
    }
    # Fail qc in the previously opened tab
    $flow->catch_error(
        qr{SKU '\d+-\d+' has already been processed},
        'should catch double submission error',
        flow_mech__goodsin__returns_qc__process => {decision => 'fail'}
    );

    # Book in the other returned item
    $flow->task__set_printer_station( 'GoodsIn', 'ReturnsIn' );
    $flow->task__goodsin__returns_in( $shipment->id, [$variants[1]->sku]);

    $flow->task__set_printer_station( 'GoodsIn', 'ReturnsQC' );
    $flow->flow_mech__goodsin__returns_qc
        ->flow_mech__goodsin__returns_qc_submit( $return->rma_number )
        ->flow_mech__goodsin__returns_qc__process;
}

=head2 test_returns_delivery

A couple of basic test for the returns delivery/arrival page.

=over

=item Create a return delivery on the I<'/GoodsIn/ReturnsDelivery'> page

=item Scan an AWB and submit its details, check that the AWB and total packages are correct

=item Scan the same AWB and submit its details, check package counts are unchanged

=item Scan the same AWB and submit its details, check package counts have increased

=item Scan a new AWB and submit its details, check package counts have been updated

=item Confirm the delivery, check a manifest was created and we have a manifest link when we view the delivery

=back

=cut

sub test_returns_delivery : Tests {
    my $self = shift;

    my $flow = Test::XT::Flow->new_with_traits(
        traits => [ 'Test::XT::Flow::GoodsIn' ]
    );

    $flow->login_with_permissions({ perms => {
        $AUTHORISATION_LEVEL__OPERATOR => [ 'Goods In/Returns Arrival' ],
    }});

    $flow->mech__goodsin__returns_delivery
        ->mech__goodsin__returns_delivery_create_delivery;

    # Generates two waybills - these aren't guaranteed to be unique, so this
    # could cause rare intermittent failures
    my @awbs = Test::XTracker::Data->generate_air_waybills;

    for (
        [ 'add arrival' => $awbs[0], 1, 1 ],
        [ 'cancel_arrival' => $awbs[0], 1, 1,
            sub {
                my ($self, $flow, $awb) = @_;
                $flow->mech__goodsin__returns_delivery_id_awb_submit($awb)
                    ->mech__goodsin__returns_arrival_cancel;
            },
        ],
        [ 'add arrival to existing awb' => $awbs[0], 2, 2 ],
        [ 'add arrival with new awb' => $awbs[1], 1, 3 ],
    ) {
        my (
            $test_name,
            $awb,
            $expected_awb_packages,
            $expected_total_packages,
            $override_sub
        ) = @$_;
        subtest $test_name => sub {
            my $sub = $override_sub // \&add_arrival;
            $sub->($self, $flow, $awb);
            $self->arrival_tests(
                $flow, $awb, $expected_awb_packages, $expected_total_packages
            );
        };
    }

    subtest 'confirm delivery' => sub {
        my $return_delivery_id = $flow->mech->as_data->{details}{ID};
        my $print_directory = Test::XTracker::PrintDocs->new;
        $flow->mech__goodsin__returns_delivery_id_confirm_submit;
        my ($manifest) = $print_directory->wait_for_new_files;
        ok( $manifest, 'created manifest file' );

        $flow->mech__goodsin__returns_delivery_id($return_delivery_id);
        ok( $flow->mech->find_xpath('id("print_manifest_link")')->pop,
            'has print manifest link');
    };
}

=head2 arrival_tests($flow, $awb, $expected_awb_packages, $expected_total_packages() :

Perform a few tests on the given awb - note that you have to be on the correct
return delivery page.

=cut

sub arrival_tests {
    my ( $self, $flow, $awb, $expected_awb_packages, $expected_total_packages ) = @_;

    my $data = $flow->mech->as_data;
    ok(
        my ($arrival) = (grep { $_->{'AWB #'} eq $awb } @{$data->{arrivals}//[]}),
        "found arrival $awb"
    ) or return;
    is( $arrival->{'# of Packages'}, $expected_awb_packages,
        'arrival package count ok' );
    is( $data->{total_packages}, $expected_total_packages,
        'total package count ok' );
}

=head2 add_arrival($flow, $awb) :

A shortcut to submit an awb and confirm its details.

=cut

sub add_arrival {
    my ( $self, $flow, $awb ) = @_;
    $flow->mech__goodsin__returns_delivery_id_awb_submit($awb)
        ->mech__goodsin__returns_arrival_submit_details;
}
