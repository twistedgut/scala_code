#!/usr/bin/env perl
use NAP::policy qw/test/;
use FindBin::libs;

use Test::XTracker::RunCondition export => [qw( $iws_rollout_phase $prl_rollout_phase )];


use Carp;
use HTML::Entities qw/ encode_entities /;

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Config::Local         qw( :DEFAULT :carrier_automation );
use XTracker::Database::Shipment    qw( get_address_shipping_charges
                                        :carrier_automation );

use XTracker::Constants::FromDB   qw(
    :shipment_item_status
    :shipment_status
    :shipment_type
    :shipping_charge_class
);
use Test::XTracker::PrintDocs;
use Data::Dump  qw( pp );

my $schema = Test::XTracker::Data->get_schema;
my $sh_rs = $schema->resultset('Public::Shipment');
my ($channel,$pids) = Test::XTracker::Data->grab_products;
my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

my $mech = Test::XTracker::Mechanize->new;
Test::XTracker::Data->set_department('it.god', 'Shipping');

my $dc_name = config_var(qw/DistributionCentre name/);
# Currently only DC2 uses UPS
my $carrier = $dc_name eq 'DC2' ? 'UPS' : 'DHL Express';

__PACKAGE__->setup_user_perms;

$mech->do_login;
make_shipments_valid($mech) if $carrier eq 'UPS';
my $shipping_account= Test::XTracker::Data->find_shipping_account({
    channel_id  => $channel->id,
    acc_name    => 'Domestic',
    carrier     => $carrier,
});

my $address = Test::XTracker::Data->create_order_address_in("current_dc_premier");

# for each pid make sure there's stock
foreach my $item (@{$pids}) {
    Test::XTracker::Data->ensure_variants_stock($item->{pid});
}
my $shipping_charge = $schema->resultset('Public::ShippingCharge')->find({
    description => Test::XTracker::Data->default_shipping_charge->{domestic}{$channel->web_name},
    channel_id  => $channel->id,
});

my ($order) = Test::XTracker::Data->create_db_order({
    base => {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $shipping_account->id,
        invoice_address_id => $address->id,
        shipping_charge_id => $shipping_charge->id,
    },
    pids => $pids,
    attrs => [
        { price => 100.00 },
    ],
});

# destination_code is for DHL shipments only
$order->get_standard_class_shipment->update({ destination_code => undef })
    if $carrier eq 'DHL Express';

my $order_nr = $order->order_nr;

note 'Shipping Acc.: ' . $shipping_account->id;
note "Order Nr: $order_nr";
note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;

$mech->order_nr($order_nr);

my ($ship_nr, $status, $category) = gather_order_info();
note "Shipment Nr: $ship_nr";

# The order status might be Credit Hold. Check and fix if needed
if ($status eq "Credit Hold") {
    Test::XTracker::Data->set_department('it.god', 'Finance');
    $mech->reload;
    $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
    ($ship_nr, $status, $category) = gather_order_info();
}
is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

if ( $carrier eq 'DHL Express' ) {
    subtest 'test invalid shipment page' => sub {
        test_invalid_shipment_page( $mech, $ship_nr, $carrier );
    };
    subtest 'test different dhl shipment stages' => sub {
        test_different_dhl_shipment_stages( $mech, $ship_nr );
    };
}
elsif ( $carrier eq 'UPS' ) {
    subtest 'test invalid shipment page with rtcb' => sub {
        test_invalid_shipment_page_with_rtcb($mech, $ship_nr, $carrier);
    };
    subtest 'test different departments' => sub {
        test_different_departments( $mech, $ship_nr );
    };
    subtest 'test different ups shipment stages' => sub {
        test_different_ups_shipment_stages( $mech, $ship_nr );
    };
}
else {
    croak "Unknown carrier '$carrier'";
}

done_testing;

=head2 test_invalid_shipment_page

 test_invalid_shipment_page($mech,$shipment_id)

Test the Invalid Shipments page.

=cut

sub test_invalid_shipment_page {
    my ($mech,$ship_nr,$carrier) = @_;

    my $shipment = $sh_rs->find( $ship_nr );

    # get shipping options available
    my $address = $shipment->shipment_address;
    my $dbh         = $schema->storage->dbh;
    my %shipping_charges = get_address_shipping_charges(
        $dbh,
        $shipment->get_channel->id,
        {
            country  => $address->country,
            postcode => $address->postcode,
            state    => $address->county,
        },
    );
    my $xml_error_fragment = "<res:RoutingErrorResponse";
    fake_dhl_routing_request_failure($shipment, $xml_error_fragment);

    # get premier and non-premier shipping charges
    my $premier_charge;
    my @non_prem_charge;
    foreach ( keys %shipping_charges ) {
        if ( $shipping_charges{$_}{class_id} == $SHIPPING_CHARGE_CLASS__SAME_DAY ) {
            $premier_charge = $_;
        }
        else {
            push @non_prem_charge,$_;
        }
    }

    note "TESTING Invalid Shipments page";


    # TEST you can see the page

    # this holds the message that should appear at the top of the page which can be checked for
    my $page_heading= "$carrier Shipments that have failed Address Validation";
    $mech->get_ok('/Fulfilment/InvalidShipments');
    $mech->has_tag_like('span',qr/$page_heading/,'Invalid Shipment Details Have Appeared');

    # this holds the number of columns (less ship id) to expect in the table
    my $tab_cols    = 7;
    # get the row in the table for the Shipment
    my @ship_row = _get_shipment_row( $mech, $ship_nr );
    ok(@ship_row,"Found Shipment Row in Table");
    cmp_ok(@ship_row,"==",$tab_cols,"Number of Columns Ok");
    is( $ship_row[3], "New", "Found Shipment Id set for Selection" );
    is( $ship_row[5], $shipment->date->dmy('/'), "Found Shipment Date" );

    # TEST you can follow all the links

    # Edit Address
    edit_address_no_address_change($mech, $xml_error_fragment);

    $mech->has_tag('h2', 'Invalid Shipments', 'Got Back to Invalid Shipments Page');

    # clear dest code
    $shipment->discard_changes;
    $shipment->update( { destination_code => '' } );

    # re-fresh page
    $mech->get_ok('/Fulfilment/InvalidShipments');

    # Edit Shipment
    $mech->follow_link_ok({ url_regex => qr/EditShipment.*shipment_id=$ship_nr/ }, "Edit Shipment Page");

    ok $mech->exists(qq{//span[text()="Shipment Details"]}),
        'Got There';
    $mech->submit_form_ok({
            form_name   => 'editShipment',
            button      => 'submit'
        },"Submit No Change on Edit Shipment");
    $mech->has_tag_like('span',qr/$page_heading/,'Got Back to Invalid Shipments Page');

    # View Order
    my $order_id = $shipment->order->id;
    $mech->follow_link_ok({ url_regex => qr/OrderView.*order_id=$order_id/ }, "Order View Page");

    ok $mech->exists(qq{//td//h3[text()="Order Details"]}),
        'Got There';
    $mech->follow_link_ok({ text_regex => qr/^Back/ }, "Back to Invalid Shipments Page");
    $mech->has_tag_like('span',qr/$page_heading/,'Got Back to Invalid Shipments Page');


    # TEST setting and clearing the DHL code field and that you can and can't see the shipment on the page

    # set the DHL code to be LHR
    $shipment->update( { destination_code => 'LHR' } );
    $mech->get_ok('/Fulfilment/InvalidShipments');
    # get the row in the table for the Shipment
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    cmp_ok(@ship_row,"==",0,"No Shipment Row Found when DLH code set");

    # remove destination code
    $shipment->update( { destination_code => '' } );
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    cmp_ok(@ship_row,"==",$tab_cols,"Shipment Row Found when DHL code empty");


    # TEST clearing the sla cutoff field to ensure it displays as 'Not set' on the page

    # remove sla_cutoff
    $shipment->update( { sla_cutoff => undef } );
    $mech->get_ok('/Fulfilment/InvalidShipments');
    # get the row in the table for the Shipment
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    like( $ship_row[1], qr/Not set/, "The SLA cutoff is displayed as 'Not set' if the sla_cutoff is null");

    # NOTE: We skip these tests if we don't have premier shipping charges
    # (currently this affects DC3). We can probably remove this block when DC3
    # has working premier shipments
    SKIP: {
        skip q{DC doesn't support premier shipments}, 21 unless $premier_charge;
        # TEST when shipment is type Premier

        # Go to Edit Shipment Page
        $mech->follow_link_ok({ url_regex => qr/EditShipment.*shipment_id=$ship_nr/ }, "Edit Shipment Page");
        ok $mech->exists(qq{//span[text()="Shipment Details"]}),
            'Got There';
        $mech->submit_form_ok({
                with_fields => {
                    shipping_charge_id  => $premier_charge
                },
                button      => 'submit'
            },"Change Shipment to be Premier $premier_charge");
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");
        like($mech->uri,qr{/Fulfilment/InvalidShipments(\?|$)},'Got Back to Invalid Shipments Page');

        @ship_row   = _get_shipment_row( $mech, $ship_nr );
        cmp_ok(@ship_row,"==",0,"No Shipment Row Found when Shipment is Premier");

        # put shipment type back to being Non-Premier
        $mech   = $mech->test_edit_shipment( $ship_nr );
        $mech->submit_form_ok({
                with_fields => {
                    shipping_charge_id  => $non_prem_charge[0]
                },
                button      => 'submit'
            },"Change Shipment to be Premier");
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");
        # set the rtcb field back to false
        set_carrier_automated( $dbh, $ship_nr, 0 );
        $mech->get_ok('/Fulfilment/InvalidShipments');
        $mech->has_tag_like('span',qr/$page_heading/,'Got Back to Invalid Shipments Page');
        @ship_row   = _get_shipment_row( $mech, $ship_nr );
        cmp_ok(@ship_row,"==",$tab_cols,"Shipment Row Found Again when Shipment is Non-Premier");
    };

    return $mech;
}

sub fake_dhl_routing_request_failure {
    my ($shipment, $xml_error_fragment) = @_;

    my $dbh = $shipment->result_source->storage->dbh;
    my $error = qq|XTracker::DHL::XMLDocument: did not parse any successful values from response - suspect not successful response - <?xml version="1.0" encoding="UTF-8"?>$xml_error_fragment xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-i|;
    $dbh->do(
        "insert into routing_request_log
         (date, shipment_id, error_code, error_message)
         values (current_timestamp, ?, ?, ?)",
        {},
        $shipment->id, "X", substr($error, 0, 255 ),
    );
}

=head2 test_invalid_shipment_page_with_rtcb

 test_invalid_shipment_page_with_rtcb($mech,$shipment_id,$oktodo)

Test the Invalid Shipments page with carrier automated shipments.

=cut

sub test_invalid_shipment_page_with_rtcb {
    my ($mech,$ship_nr,$carrier,$oktodo) = @_;

    my $dbh         = $schema->storage->dbh;

    my $shipment    = $sh_rs->find( $ship_nr );
    my $address     = $shipment->shipment_address;
    my $users_name  = $mech->logged_in_as_logname;
    my $channel_id  = $shipment->order->channel_id;
    my $qrt         = get_ups_qrt( $schema->resultset('Public::Channel')->find( $channel_id )->business->config_section );
    my $order_id    = $shipment->order->id;
    my @ship_row;
    my $tab_aqr;

    # position of various columns on the invalid shipments page
    my $status_col  = 3;
    my $aqr_col     = 5;
    my $address_col = 6;
    my $date_col    = 7;
    # this holds the number of columns (less ship id) to expect in the table
    my $tab_cols    = 9;
    # this holds the message that should appear at the top of the page which can be checked for
    my $page_heading= "$carrier Shipments that have failed Address Validation";

    # get shipping options available
    my %shipping_charges = get_address_shipping_charges(
        $dbh,
        $shipment->order->channel_id,
        {
            country  => $address->country,
            postcode => $address->postcode,
            state    => $address->county,
        },
    );

    # get premier and non-premier shipping charges
    my $premier_charge;
    my @non_prem_charge;
    foreach ( keys %shipping_charges ) {
        if ( $shipping_charges{$_}{class_id} == $SHIPPING_CHARGE_CLASS__SAME_DAY ) {
            $premier_charge = $_;
        }
        else {
            push @non_prem_charge,$_;
        }
    }

    note "TESTING Invalid Shipments page";


    # TEST you can see the page

    $mech->get_ok('/Fulfilment/InvalidShipments');
    $mech->has_tag('span',$page_heading,'Invalid Shipment Details Have Appeared');

    # get the row in the table for the Shipment
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    ok(@ship_row,"Found Shipment Row in Table");
    cmp_ok(@ship_row,"==",$tab_cols,"Number of Columns Ok");
    is( $ship_row[$status_col], "New", "Found Shipment Id set for Selection" );
    $tab_aqr = $ship_row[$aqr_col];
    $tab_aqr    =~ s/[^0-9]//g;
    is(
        $tab_aqr,
        ( $shipment->av_quality_rating || 0 ) * 100,
        "Quality Rating Matches",
    );
    is(
        $ship_row[$address_col],
        join(",",$address->towncity,$address->county,$address->postcode),
        "Address Part Matches"
    );
    is($ship_row[$date_col],$shipment->date->mdy('/'),"Date Part Matches");

    # TEST you can follow all the links

    # Edit Address
    $mech->follow_link_ok({ url_regex => qr/ChooseAddress.*shipment_id=$ship_nr/  }, "Edit Address Page");
    $mech->follow_link_ok({ text_regex => qr/^Back/ }, "Back to Invalid Shipments Page");
    like($mech->uri, qr{/Fulfilment/InvalidShipments\b}, 'Got Back to Invalid Shipments Page');

    # Edit Shipment
    $mech->follow_link_ok({ url_regex => qr/EditShipment.*shipment_id=$ship_nr/ }, "Edit Shipment Page");
    ok (
        $mech->look_down (
            _tag => 'span',
            sub {$_[0]->as_trimmed_text eq 'Shipment Details'}
        ),
        'Got to edit shipment page'
    );
    $mech->submit_form_ok({
            form_name   => 'editShipment',
            button      => 'submit'
        },"Submit No Change on Edit Shipment");
    like($mech->uri, qr{/Fulfilment/InvalidShipments\b}, 'Got Back to Invalid Shipments Page');

    # View Order
    $mech->follow_link_ok({ url_regex => qr/OrderView.*order_id=$order_id/ }, "Order View Page");
    ok (
        $mech->look_down (
            _tag => 'td',
            sub {$_[0]->as_trimmed_text eq 'Order Details'}
        ),
        'Got to order view page'
    );

    $mech->follow_link_ok({ text_regex => qr/^Back/ }, "Back to Invalid Shipments Page");

    like($mech->uri, qr{/Fulfilment/InvalidShipments\b}, 'Got Back to Invalid Shipments Page');

    # TEST different Shipment Quality Ratings & rtcb settings and that you can and can't see the shipment on the page

    # It seems RTCB (real time carrier booking) is a flag that when true trumps
    # the shipment's quality rating - i.e. it's a manual override
    for (
        [ 'quality rating under threshold'    => $qrt - 0.01, 0, 1 ],
        [ 'quality rating equal to threshold' => $qrt,        0, 0 ],
        [ 'quality rating above threshold'    => $qrt + 0.01, 0, 0 ],
        [ 'quality rating is empty string'    => q{},         0, 1 ],
        [ 'RTCB is true'                      => q{},         1, 0 ],
    ) {
        my ( $test_name, $quality_rating, $rtcb, $should_appear ) = @$_;
        subtest $test_name => sub {
            $shipment->update({
                av_quality_rating         => $quality_rating,
                real_time_carrier_booking => $rtcb,
            });
            $mech->get_ok('/Fulfilment/InvalidShipments');
            my $row_exists = !!_get_shipment_row( $mech, $ship_nr );
            if ( $should_appear ) {
                ok($row_exists, 'shipment appears on page');
            }
            else {
                ok(!$row_exists, "shipment doesn't appear on page");
            }
        };
    }

    # Make the shipment appear on the page again so we can test the sla_cutoff
    # and go to its edit shipment page
    $shipment->update({av_quality_rating => 0, real_time_carrier_booking => 0});

    # TEST clearing the sla cutoff field to ensure it displays as 'Not set' on the page
    # remove sla_cutoff
    $shipment->update( { sla_cutoff => undef } );
    $mech->get_ok('/Fulfilment/InvalidShipments');
    # get the row in the table for the Shipment
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    like( $ship_row[1], qr/Not set/, "The SLA cutoff is displayed as 'Not set' if the sla_cutoff is null");

    # TEST when shipment is type Premier
    $mech->follow_link_ok({ url_regex => qr/EditShipment.*shipment_id=$ship_nr/ }, "Edit Shipment Page");
    ok (
        $mech->look_down (
            _tag => 'span',
            sub {$_[0]->as_trimmed_text eq 'Shipment Details'}
        ),
        'Got to edit shipment page'
    );
    $mech->submit_form_ok({
            with_fields => {
                shipping_charge_id  => $premier_charge
            },
            button      => 'submit'
        },"Change Shipment to be Premier");
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");
    like($mech->uri, qr{/Fulfilment/InvalidShipments\b}, 'Got Back to Invalid Shipments Page');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    ok(!@ship_row,"No Shipment Row Found when Shipment is Premier");

    # put shipment type back to being Non-Premier
    $mech = $mech->test_edit_shipment( $ship_nr );
    $mech->submit_form_ok({
            with_fields => {
                shipping_charge_id  => $non_prem_charge[0]
            },
            button      => 'submit'
        },"Change Shipment to be Premier");
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");
    # set the rtcb field back to false
    set_carrier_automated( $dbh, $ship_nr, 0 );
    $mech->get_ok('/Fulfilment/InvalidShipments');
    $mech->has_tag('span',$page_heading,'Got Back to Invalid Shipments Page');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    ok(@ship_row,"Shipment Row Found Again when Shipment is Non-Premier");

    return $mech;
}

=head2 test_different_departments

 test_different_departments($mech,$shipment_id,$oktodo)

Test that the Edit Shipment page link can be seen when user is in various departments.

=cut

sub test_different_departments {
    my ($mech,$ship_nr,$oktodo) = @_;

    my $shipment    = $sh_rs->find( $ship_nr );
    my @depts       = ('Shipping','Shipping Manager','Customer Care','Customer Care Manager','Distribution Management','Stock Control');

    my $url = invalid_shipment_url();

    note "TESTING being in different departments";

    # Can see the link with various departments
    foreach ( @depts ) {
        Test::XTracker::Data->set_department('it.god', $_);
        $mech->get_ok($url);
        my $link_ref    = $mech->find_link( url_regex => qr/EditShipment.*shipment_id=$ship_nr/ );
        is(ref($link_ref),"WWW::Mechanize::Link","Found Edit Shipment Link for Department: $_");
    }

    # Can NOT see the link when not in one of the above departments
    Test::XTracker::Data->set_department('it.god', "Finance" );
    $mech->get_ok($url);
    my $link_ref    = $mech->find_link( url_regex => qr/EditShipment.*shipment_id=$ship_nr/ );
    isnt(ref($link_ref),"WWW::Mechanize::Link","Did not Find Edit Shipment Link for Department: Finance");

    # put department back to how it was
    Test::XTracker::Data->set_department('it.god', 'Shipping');

    return $mech;
}


=head2 test_different_dhl_shipment_stages($mech,$shipment_id)

Test that the status column in the invalid shipments page represents the
process in shipping stage for the dhl shipment at various points.

=cut

sub test_different_dhl_shipment_stages {
    my ($mech,$ship_nr,$oktodo) = @_;

    my $shipment    = $sh_rs->find( $ship_nr );
    my @ship_row;
    my $skus;

    note "TESTING the stages of shipping a Shipment";

    $skus    = $mech->get_order_skus();

    # New order should be New
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    is( $ship_row[3], "New", "Found Shipment set for New" );

    # Selected order should be at Picking
    {
        # Validate shipment so it'll pass through selection
        $shipment->update( { destination_code => 'LHR' } );
        my $print_directory = Test::XTracker::PrintDocs->new();
        $mech   = $mech->test_direct_select_shipment( $ship_nr );
        if ($iws_rollout_phase || $prl_rollout_phase) {
            $skus   = { map {; $_->get_true_variant->sku ,'' }
                            $shipment->shipment_items->all };
        } else {
            $skus   = $mech->get_info_from_picklist($print_directory, $skus);
        }
        # Invalidate it again
        $shipment->update( { destination_code => '' } );
    }
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    is( $ship_row[3], "Selected", "Found Shipment set for Selected" );

    # Picked order should be at Packing
    $mech   = $mech->test_pick_shipment( $ship_nr, $skus );
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    is( $ship_row[3], "Picked", "Found Shipment set for Picked" );

    # Packed order should be at Waiting Dispatch
    {
        # Validate shipment so it'll pass through packing
        $shipment->update( { destination_code => 'LHR' } );
        $mech->test_pack_shipment($ship_nr, $skus);
        # Invalidate it again
        $shipment->update( { destination_code => '' } );
    }
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    is( $ship_row[3], "Packed", "Found Shipment set for Packed" );

    # If we're in a DC with a seperate labelling section, we need to ensure that
    # you can't label & dispatch a DHL order without a valid DHL code.
    $mech->test_label_without_dhl_code($ship_nr );

    # give a proper DHL code
    $shipment->update( { destination_code => 'LHR' } );

    # Dispatch Order Shouldn't Show Up - ## not quite sure what this comment means
    $mech->test_labelling( $ship_nr );

    $mech->test_dispatch( $ship_nr );
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    cmp_ok(@ship_row,"==",0,"No Shipment Row Found when Dispatched");

    return $mech;
}

=head2 test_different_ups_shipment_stages ($mech,$shipment_id)

Test that the Status column in the Invalid Shipments page represents
the process in shipping stage for the Shipment at various points.

=cut

sub test_different_ups_shipment_stages {
    my ($mech,$ship_nr) = @_;

    my $shipment    = $sh_rs->find( $ship_nr );
    my @ship_row;
    my $skus;

    note "TESTING the stages of shipping a Shipment";

    $skus    = $mech->get_order_skus();

    # position of status column on the invalid shipments page
    my $status_col  = 3;

    # Shipment should be New
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    is( $ship_row[$status_col], "New", "Found Shipment set for New" );

    # Selected order should be at Picking
    my $print_directory = Test::XTracker::PrintDocs->new();
    my $old_quality = $shipment->av_quality_rating();
    $shipment->update({ av_quality_rating => 100 });
    if ($prl_rollout_phase) {
        Test::XTracker::Data::Order->allocate_order($order);
        Test::XTracker::Data::Order->select_order($order);
    } else {
        $mech   = $mech->test_direct_select_shipment( $ship_nr );
    }

    $shipment->update({ av_quality_rating => $old_quality });
    if ($iws_rollout_phase || $prl_rollout_phase) {
        $skus   = { map {; $_->get_true_variant->sku ,'' }
                        $shipment->shipment_items->all };
    } else {
        $skus   = $mech->get_info_from_picklist($print_directory, $skus);
    }
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    is( $ship_row[$status_col], "Selected", "Found Shipment set for Selected" );

    # Picked order should be at Packing
    $mech   = $mech->test_pick_shipment( $ship_nr, $skus );
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    is( $ship_row[$status_col], "Picked", "Found Shipment set for Packing" );

    # Packed order should be at Waiting Dispatch
    $shipment->update({ av_quality_rating => 100 });
    $mech->test_pack_shipment($ship_nr, $skus);
    $shipment->update({ av_quality_rating => $old_quality });
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    is( $ship_row[$status_col], "Packed", "Found Shipment set for Packed" );

    # Dispatch Order Shouldn't Show Up
    $mech->test_assign_airway_bill( $ship_nr )
            ->test_dispatch( $ship_nr );
    $mech->get_ok('/Fulfilment/InvalidShipments');
    @ship_row   = _get_shipment_row( $mech, $ship_nr );
    cmp_ok(@ship_row,"==",0,"No Shipment Row Found when Dispatched");

    # TODO We expect some files from the above tests: these tests should check them
    my @unexpected_files =
        grep { $_->file_type !~ /^(matchup_sheet|shippingform|invoice|retpro)$/ }
        $print_directory->new_files();

    ok(!@unexpected_files, 'should not have any unexpected print files');

    return $mech;
}

# this makes any pre-existing invalid shipments valid and ensures that shipments
# with Unknown carrier have a premier shipment type to prevent this test failing
sub make_shipments_valid {
    my ($mech) = @_;
    my $dbh = $schema->storage->dbh;
    my $shipment_rs = $sh_rs->invalid_shipments_rs();
    while ( my $s = $shipment_rs->next ) {
        if ( $s->carrier_is_dhl ) {
            $s->update( { destination_code => 'LHR' } );
        }
        elsif ( $s->carrier_is_ups ) {
            set_carrier_automated( $dbh, $s->id, 1 );
        }
        else {
            $s->update( { shipment_type_id => $SHIPMENT_TYPE__PREMIER } );
        }
    }
}

# _get_shipment_row
# this gets a row in the page which has the shipment id as it's first column
# then returns an array of the remaining columns.

sub _get_shipment_row {
    my ( $mech, $ship_nr )  = @_;

    my $ship_row = $mech->find_xpath(qq{
        //td[. =~ '$ship_nr']
        /following-sibling::td
    });

    if ( defined $ship_row ) {
        return $ship_row->string_values()
    }
    else {
        return;
    }
}

sub _get_all_shipids {
    my ($mech) = @_;

    my $ids = $mech->find_xpath(q{
      //table[@class='data']//a[@title="Edit Shipment Address"]
    });
    return $ids->string_values();
}

sub setup_user_perms {
    # Perms needed for the order process
    my @fulfilment_subsections = (
        qw/Airwaybill Dispatch Packing Picking Selection Labelling/
    );
    push @fulfilment_subsections, invalid_shipment_subsection();
    Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, 2)
        for @fulfilment_subsections;
    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
  my ($order_nr) = @_;

  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID

  my $ship_nr = $mech->get_table_value('Shipment Number:');

  my $status = $mech->get_table_value('Order Status:');

  my $category = $mech->get_table_value('Customer Category:');
  return ($ship_nr, $status, $category);
}

# Subs to return url/subsection-list-for-permissions where users can check for
# invalid shipments. There's probably a better way to work this out than DCs,
# but I'm not aware of it :/
sub invalid_shipment_url {
    # Using evil global for $carrier... sorry!
    return '/Fulfilment/', join q{}, split m{ }, invalid_shipment_page($carrier);
}
sub invalid_shipment_subsection {
    # Using evil global for $carrier... sorry!
    return join q{ }, split m{ }, invalid_shipment_page($carrier);
}

sub invalid_shipment_page {
    my $carrier = shift;
    return ( $carrier eq 'DHL Express' || $carrier eq 'UPS')
         ? 'Invalid Shipments'
         : croak "Unsupported carrier '$carrier'";
}

sub edit_address_no_address_change {
    my ($mech, $xml_error_fragment) = @_;

    $mech->follow_link_ok({ url_regex => qr/ChooseAddress.*shipment_id=$ship_nr/  }, "Edit Address Page");

    ok($mech->look_down(_tag => 'span',
                        sub { $_[0]->as_trimmed_text =~ /Change Address/ }),
       "got to Choose Address page");

    $mech->submit_form_ok({
        form_name   => 'base_address',
        button      => 'submit'
       },"Submit no change address" );

    $mech->submit_form_ok(
        { form_name => "use_address", button => "submit" },
        "Confirm no change address");

    $mech->submit_form_ok(
        { form_name   => 'editAddress', button => 'submit'},
        "Confirm Select Shipping Option, no address change");

    if(defined $xml_error_fragment){
        my $escaped_xml_error_fragment = encode_entities($xml_error_fragment);
        like(
            $mech->content,
            qr/\Q$escaped_xml_error_fragment/,
            "Escaped error fragment present in page",
           ) or diag($mech->content);
    }

    $mech->submit_form_ok({
        form_name   => 'editAddress',
        button      => 'submit'
       },"Finalise no change address");

    return 1;
}
