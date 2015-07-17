#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

payment_failure.t - Payment fails and is detected at packing

=head1 DESCRIPTION

Payment fails and is detected at packing.

Test with and without a cancelled item.

Verify message displayed to user "Pre-Authorisation no longer valid".

#TAGS fulfilment packing packingexception finance whm

=cut

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use XTracker::Config::Local qw( config_var );
use Test::XT::Data::Container;
#use Carp::Always;
use Data::Dump 'pp';

test_prefix("Setup: framework");
my $schema = Test::XTracker::Data->get_schema;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
);
$framework->clear_sticky_pages;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

sub test_it {
    my ($with_cancel)=@_;

    note 'testing DCEA-762 '.($with_cancel ? 'with' : 'without').' a canceled item';

    # create and pick the order
    test_prefix("Setup: order shipment");

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 3,
    });
    my $order_data = $framework->flow_db__fulfilment__create_order_picked(
        channel  => $channel,
        products => $pids,
    );
    my $shipment_id = $order_data->{shipment_id};
    note "shipment $shipment_id created";

    $framework->flow_msg__prl__induct_shipment( shipment_id => $shipment_id );


    # let's make it fail payment
    my $max_payment = $schema->resultset('Orders::Payment')->search({
            'length(preauth_ref)' => { '<' => 10 },
            preauth_ref => { '~' => '^[0-9]+$' },
            settle_ref => { '~' => '^[0-9]+$' },
        },{
        select => [
            { max => 'psp_ref' },
            { max => 'preauth_ref::integer' },
            { max => 'settle_ref::integer' },
        ],
        as => [qw(
                     psp_ref
                     preauth_ref
                     settle_ref
             )],
    })->single;
    Test::XTracker::Data->create_payment_for_order( $order_data->{order_object}, {
        psp_ref     => (($max_payment->psp_ref()||'') . 'X'),
        preauth_ref => (($max_payment->preauth_ref()||0) + 1),
        settle_ref  => (($max_payment->settle_ref()||0) + 1),
        fulfilled   => 0,
        valid       => 0,
    } );

    test_prefix("Setup: pack shipment");
    $framework->mech__fulfilment__set_packing_station( $channel->id );

    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $order_data->{tote_id} );

    my $canceled_item;
    if ($with_cancel) {
        test_prefix("Setup: cancel item");
        $canceled_item = splice @$pids,1,1;
        $framework
            ->open_tab("Customer Care")
            ->flow_mech__customercare__orderview( $order_data->{'order_object'}->id )
            ->flow_mech__customercare__cancel_shipment_item()
            ->flow_mech__customercare__cancel_item_submit(
                $canceled_item->{'sku'},
            )
            ->flow_mech__customercare__cancel_item_email_submit()
            ->close_tab();

        $framework->catch_error(
            qr{shipment has changed},
            'Check user is told shipment is changed',
            flow_mech__fulfilment__packing_checkshipment_submit => ()
        );
    }

    test_prefix("Payment");

    $framework->catch_error(
        qr{send to the packing exception desk},
        'payment failed',
        flow_mech__fulfilment__packing_checkshipment_submit => ()
    );

    test_prefix("PIPE");
    $framework->assert_location(qr!^/Fulfilment/Packing/PlaceInPEtote!);
    $framework
        ->test_mech__pipe_page__test_items(
            handled => [],
            pending => [
                map { +{
                    SKU => $_->{sku},
                    QC => 'Ok',
                    Container => $order_data->{tote_id},
                } } @$pids
            ]
        );

    my ($petote,$peotote) = Test::XT::Data::Container->get_unique_ids( { how_many => 2 } );

    for my $p (@$pids) {
        $framework
            ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $p->{sku} )
            ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $petote );
    }

    $framework->test_mech__pipe_page__test_items(
        pending => [],
        handled => [
            map { +{
                SKU => $_->{sku},
                QC => 'Ok',
                Container => $petote,
            } } @$pids
        ]
    )->flow_mech__fulfilment__packing_placeinpetote_mark_complete();

    test_prefix("PIPEO");

    $framework->assert_location(qr!^/Fulfilment/Packing/EmptyTote!);
    {
        my $et_data = $framework->mech->as_data();

        is_deeply([sort @{$et_data->{totes}}],[$order_data->{tote_id}],'only original tote shown');
    }

    if ($with_cancel) {
        $framework
            ->flow_mech__fulfilment__packing_emptytote_submit('no')
            ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($canceled_item->{sku})
            ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($peotote)
            ->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete
            ->flow_mech__fulfilment__packing_emptytote_submit('yes');
    }
    else {
        $framework
            ->flow_mech__fulfilment__packing_emptytote_submit('yes');
    }

    test_prefix("PE screen");


    if ($with_cancel) {
        $framework->without_datalite(
            flow_mech__fulfilment__packingexception => (),
        );
        my $pe_data = $framework->mech->as_data->{exceptions};

        my $peo_lines = $pe_data->{$channel->name}{'Containers with Unexpected or Cancelled Items'};
        my $found_peo_line;
        foreach my $peo_line (@$peo_lines) {
            if ($peo_line->{'Container ID'}->{value} eq $peotote) {
                $found_peo_line = $peo_line;
                last;
            }
        }
        isnt ($found_peo_line, undef, 'Exception tote appears on PE page');
        if ($found_peo_line) {
            is($found_peo_line->{'Cancelled Items'}, 1,
               'PE tote has 1 cancelled items');
            is($found_peo_line->{'Unexpected Items'}, 0,
               'PE tote has 0 orphaned items');
        }
    }
    else {
        $framework->flow_mech__fulfilment__packingexception;
    }

    $framework
        ->flow_mech__fulfilment__packingexception
        ->flow_mech__fulfilment__packingexception_submit( $shipment_id );
    {
        my $pes_data = $framework->mech->as_data();
        my $items=$pes_data->{shipment_items};
        is(scalar @{$items},3,
           'three items in PE screen');
        for my $i (@$items) {
            like($i->{QC},qr{^Ok\b},
               'item ok');
        }

        my $last_note=$pes_data->{shipment_summary}{Notes}[-1];
        is($last_note->{Operator},$framework->mech->app_operator_name(),
           'note with right operator');
        like($last_note->{Note},qr{Pre-Authorisation no longer valid},
             'correct payment-failed message');
    }
}

test_it(1);
test_it(0);

done_testing();
