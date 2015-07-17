#!/usr/bin/env perl

=head1 NAME

cancel_item_and_change_size_between_packing.t - Cancel item and change size between packing

=head1 DESCRIPTION

Create 5 products and assign them to a shipment with a status of I<Selected>,
then pick them and advance to the pack QC page.

Log in as a user in I<Distribution Management>.

Cancel the first item in another tab, return to the other tab and try and QC
the item - look for a shipment has changed error.

Go back to the pack items screen and get to the packing QC page.

Open another tab and change the size of an item to the first available
alternative. Check the email that is created and check we logged to the
shipment_item_email_log.

Return to the previous tab, submit the QC page and expect to see another
shipment has changed error.

Try and pack again and expect an error message saying there's still items to
pick before we can pack this shipment.

#TAGS cancelitem changeitemsize fulfilment packing orderview setuppicking iws prl checkruncondition duplication whm

=cut

# Push an order through to packing

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level :correspondence_templates );
use XTracker::Database qw(:common);
use XTracker::Config::Local qw( config_var customercare_email );
use Test::XTracker::LocationMigration;
use Test::XTracker::Data;
use Test::XT::Data::Container;
use Test::Differences;

use Test::XTracker::RunCondition
    export => [qw(
        $iws_rollout_phase
        $prl_rollout_phase
        $distribution_centre
)];

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection'
    ]}
});
my $schema = Test::XTracker::Data->get_schema;
my $channel = Test::XTracker::Data->get_local_channel;

# Create the order with five products
my $product_count = 5;

my (undef,$pids) =
    Test::XTracker::Data->grab_products({
        ensure_stock_all_variants => 1,
        how_many => $product_count,
        channel => $channel,
    });

my $product_data =
    $framework->flow_db__fulfilment__create_order_selected(
        channel  => $channel,
        products => $pids,
    );

my $shipment_id = $product_data->{'shipment_id'};
my ($tote_id)   = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );
my $order_id    = $product_data->{order_object}->id;

# Pick the shipment
$framework->task__picking($product_data->{shipment_object});
$framework->flow_msg__prl__induct_shipment(
    shipment_row => $product_data->{shipment_object},
);

# Ensure we've already selected a packing station if required
$framework->mech__fulfilment__set_packing_station( $channel->id );

# Go into QC_OK page
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $shipment_id );

# Cancel an item in another Mech object...
{
    my $framework_cancel_item = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
    );

    $framework_cancel_item->login_with_permissions({
        dept => 'Distribution Management',
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection',
        'Customer Care/Order Search',
        'Customer Care/Customer Search',
    ]}
    });

    $framework_cancel_item->flow_mech__customercare__orderview( $order_id )
    ->flow_mech__customercare__cancel_shipment_item;

    my $pre_change_form=$framework_cancel_item->mech->as_data;

    # just cancel the first item
    my $first_item=$pre_change_form->{cancel_item_form}->{select_items}->[0];

    my $pid=$first_item->{PID};
    note "PID of cancelled item is $pid";

    $framework_cancel_item
        ->flow_mech__customercare__cancel_item_submit( $pid )
        ->flow_mech__customercare__cancel_item_email_submit();
}

# QC_OK the items
$framework->errors_are_fatal(0);
$framework->flow_mech__fulfilment__packing_checkshipment_submit();
$framework->errors_are_fatal(1);


$framework->mech->has_feedback_error_ok(qr/This shipment has changed/,"Scan the tote again message.");


# Back to Packing items page and marking as QC OK.
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $shipment_id );


# Amend order by changing item size
{
    my $framework_change_item_size = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
    );


    $framework_change_item_size->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection',
        'Customer Care/Customer Search'
    ]}
    });

    note "Now changing the size of the first item";

    $framework_change_item_size->flow_mech__customercare__orderview( $order_id )
    ->flow_mech__customercare__size_change;

    my $pre_change_form=$framework_change_item_size->mech->as_data;

    my ($changing_item_index,$changing_item)=(undef,undef);

    # hunt for the first item that has actual alternatives...
  ITEM:
    foreach my $item (0..scalar(@{$pre_change_form->{size_change_form}->{select_items}})) {
    if ( exists $pre_change_form->{size_change_form}->{select_items}->[$item]->{change_to}
     && $pre_change_form->{size_change_form}->{select_items}->[$item]->{change_to} ne ''
     &&  exists  $pre_change_form->{size_change_form}->{select_items}->[$item]->{change_to}->{values}
     && scalar(@{$pre_change_form->{size_change_form}->{select_items}->[$item]->{change_to}->{values}})>1) {
        note "Size change list: ".scalar(@{$pre_change_form->{size_change_form}->{select_items}->[$item]->{change_to}->{values}});
        $changing_item_index=$item;
        $changing_item=$pre_change_form->{size_change_form}->{select_items}->[$item];
        last ITEM;
    }
    }

    ok(defined($changing_item),"Will be changing item $changing_item_index");

    # just change the first item to have the first alternative size
    # (which will change the SKU for the affected line item)

    my $old_sku=$changing_item->{SKU};
    my ($new_sku,$new_sku_index)=(undef,undef);

  SKU:
    foreach my $sku (0..scalar(@{$changing_item->{change_to}->{values}})) {
    my $candidate_sku=$changing_item->{change_to}->{values}->[$sku]->{value};
    # actually, only part of that needs to be compared...
    $candidate_sku=~s/.*_(\d+-\d{3,4})$/$1/;

    if ($old_sku ne $candidate_sku) {
        $new_sku_index=$sku;
        $new_sku=$changing_item->{change_to}->{values}->[$sku]->{value};
        last SKU;
    }
    }

    ok(defined($new_sku),"Different SKU in position $new_sku_index");

    # Actual SKU will be last component of that value:
    $new_sku=~s/.*_(\d+-\d{3,4})$/$1/;

    isnt( $old_sku, $new_sku, "Old SKU and new SKU are different (self-check)" );
    note "Will be changing SKU [$old_sku] to [$new_sku]";

    my $size_page = $framework_change_item_size
        ->flow_mech__customercare__size_change_submit([$old_sku => $new_sku]);

    # Check Email
    note "Check that content of the email before sending";
    my $shipment_obj = $schema->resultset("Public::Shipment")->find($shipment_id);

    my $expected_to_address   = $shipment_obj->email;
    my $expected_from_address = customercare_email( $channel->business->config_section, {
        schema => $schema,
        locale => $product_data->{order_object}->customer->locale
    } );

    my $spdata = $size_page->mech->as_data()->{email_form};

    cmp_ok(length($spdata->{"Email Text"}{value}), '>', 2, "Email text has content");
    cmp_ok(length($spdata->{"Subject"}{input_value}), '>', 2, "Email subject has content");
    isnt($spdata->{"Email Text"}{input_value}, undef, "Email type has content");
    is($spdata->{"To"}{input_value}, $expected_to_address, "To address is correct");
    is($spdata->{"From"}{input_value}, $expected_from_address, "From address is correct");
    is($spdata->{"Reply-To"}{input_value}, $expected_from_address, "Reply-To Address is correct");


    $shipment_obj->shipment_email_logs->delete_all;

    $size_page->flow_mech__customercare__size_change_email_submit();
    $shipment_obj->discard_changes;
    cmp_ok($shipment_obj->shipment_email_logs->count, '==', 1, "Shipment now has 1 email log record" );
    cmp_ok($shipment_obj->shipment_email_logs->first->correspondence_template->id, '==', $CORRESPONDENCE_TEMPLATES__CHANGE_SIZE_OF_PRODUCT, "Email template is correct" );

    note "Check that the size change stuck";

    $framework_change_item_size->flow_mech__customercare__orderview( $product_data->{order_object}->id )
    ->flow_mech__customercare__size_change;
}

# Back to Packing items page and marking as QC OK.
$framework->errors_are_fatal(0);
$framework->flow_mech__fulfilment__packing_checkshipment_submit();

$framework->mech->has_feedback_error_ok(qr/This shipment has changed/,"Scan the tote again message.");

$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $shipment_id );

# For now we're ok to just check that it get's stuck here because of
# item still being in selected status.

my $expected = $prl_rollout_phase
    ? {
        next_uri_qr      => qr{/Fulfilment/Packing$},
        info_message_qr  => qr{Pack lane \d+: Allocation \d+ .+?$tote_id \Q(en route)\E},
        error_message_qr => qr{The shipment \d+ is not ready to be packed; it is awaiting further picks\b},
    }
    : {
        next_uri_qr      => qr{\Q/Fulfilment/Packing/PlaceInPEtote?shipment_id=\E},
        info_message_qr  => undef,
        error_message_qr => qr{The shipment \d+ is not ready to be packed\b},
    };


if (my $info_message_qr = $expected->{info_message_qr}) {
    like (
        $framework->mech->app_info_message,
        $info_message_qr,
        "Packing summary ok",
    );
}

like (
    $framework->mech->app_error_message,
    $expected->{error_message_qr},
    "Item still needs to be picked.",
);

like( $framework->mech->uri, $expected->{next_uri_qr}, "Next URI ok" );


done_testing;
