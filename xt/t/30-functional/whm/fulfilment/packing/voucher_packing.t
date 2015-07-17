#!/usr/bin/env perl

=head1 NAME

voucher_packing.t - Pack a voucher

=head1 DESCRIPTION

Verify that a shipment with vouchers can be packed.

Check that when there are Cancelled Physical/Virtual Vouchers you go straight
to the Pre-Packing Page and not the PackQC page or get Rejected because of
Virtual Vouchers without codes.

Test error messages when packing an item.

Verify physical vouchers and normal products appear and virtual vouchers don't.

#TAGS fulfilment prl voucher packing loops checkruncondition http toobig xpath printer whm

=cut

use NAP::policy qw/test/;

use Test::XTracker::RunCondition
    export => [qw( $prl_rollout_phase )];


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::PrintDocs;
use XTracker::Config::Local         qw( :DEFAULT );

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :authorisation_level
                                        :shipment_item_status
                                        :shipment_item_returnable_state
                                        :shipment_status
                                        :shipment_type
                                        :stock_action
                                    );
use XTracker::DHL::RoutingRequest qw( set_dhl_destination_code );
use XTracker::PrintFunctions;

use XTracker::Database::Shipment qw(check_country_paperwork);

my ($channel,$pids,$tmp);

my $schema = Test::XTracker::Data->get_schema;

$channel        = Test::XTracker::Data->get_local_channel();
my $channel_id  = $channel->id;

my $mech = Test::XTracker::Mechanize->new;
Test::XTracker::Data->set_department('it.god', 'Shipping');
__PACKAGE__->setup_user_perms;
$mech->do_login;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Channel',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::Finance',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::PRL',
    ],
);
$framework->mech( $mech );

# Select Packing Station
$framework->mech__fulfilment__set_packing_station( $channel->id );

# extract session_id from cookie jar
my $session_store  = $mech->session;

my $customer        = Test::XTracker::Data->find_customer( { channel_id => $channel_id } );
my $shipping_account= Test::XTracker::Data->find_shipping_account( {
                                        carrier => config_var('DistributionCentre','default_carrier'),
                                        channel_id => $channel_id
                                    } );
my $address         = Test::XTracker::Data->create_order_address_in('current_dc_premier');

# go get some pids relevant to the db I'm using - channel is for test context
($channel,$pids) = Test::XTracker::Data->grab_products( {
            how_many => 1,
            phys_vouchers   => {
                how_many => 1,
                want_stock => 10,
                want_code => 10,
                value => '100.00',
            },
            virt_vouchers   => {
                how_many => 1,
                want_code => 1,
            },
    } );
# get a different type of voucher
($channel,$tmp) = Test::XTracker::Data->grab_products( {
            how_many => 1,
            phys_vouchers   => {
                how_many => 1,
                want_stock => 10,
                want_code => 10,
                value => '500.00',
            },
    } );
push @{ $pids }, $tmp->[1];

# for each pid make sure there's stock and set a packing note
foreach my $item ( @{ $pids } ) {
    if ( !$item->{voucher} ) {
        my $prod    = $item->{product};
        $prod->shipping_attribute->update( { packing_note => 'This is the packing note for '.$prod->id } );
        Test::XTracker::Data->ensure_variants_stock($item->{pid});
    }
}

my @tests = (
    {
        label           => 'Physical Voucher Only',
        pids            => [ $pids->[1] ],
        inv_code_for_qc => 1,
        nr_files        => 4,
        expected_files  => { },
        attrs           => [{price => 100.00 ,
                             gift_message => 'Testing vouchers gift message'}],
        gift_message_warning_nr   => 1,
    },
    {
        label               => 'Physical Voucher + Normal SKU + Virtual Voucher',
        pids                => [ $pids->[0], $pids->[1], $pids->[2] ],
        cant_pack_errs      => 1,
        chk_no_vv_codes     => 1,
        chk_vv_is_packed    => 1,
        chk_cancelled_vouch => 1,
        nr_files            => 5,
        attrs           => [{price => 100.00 ,
                             gift_message => 'Testing vouchers gift message'}],
        gift_message_warning_nr   => 1,
    },
    {
        label    => '2 Physical Vouchers the Same',
        pids     => [ $pids->[1], $pids->[1] ],
        nr_files => 3,
        gift_message_warning_nr => 0,
    },
    {
        label    => '2 Physical Vouchers Different',
        pids     => [ $pids->[1], $pids->[3] ],
        nr_files => 3,
        gift_message_warning_nr => 0,
    },
);
#~ if ( config_var('DHL', 'xmlpi_region_code') eq 'AM' )  {
    #~ my $dbh = $framework->schema->storage->dbh;
    #~ fail('Remove obsolete block of code that fixes previous test failure')
        #~ if ( $shipment->destination_code && $shipment->is_carrier_automated );
    #~ set_dhl_destination_code( $dbh, $shipment->id, 'LHR' );
    #~ $shipment->set_carrier_automated( 1 );
    #~ is( $shipment->is_carrier_automated, 1, "Shipment is now Automated" );
#~ }
# create a couple of orders
foreach my $test ( @tests ) {
    note "TEST CASE: $test->{label}";

    my ($order, $order_hash) = Test::XTracker::Data->create_db_order( {
            base => {
                customer_id => $customer->id,
                channel_id  => $channel_id,
                shipment_type => $SHIPMENT_TYPE__DOMESTIC,
                shipment_status => $SHIPMENT_STATUS__PROCESSING,
                shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
                shipping_account_id => $shipping_account->id,
                invoice_address_id => $address->id,
                gift_shipment => 1,
            },
            pids => $test->{pids},
            attrs => $test->{attrs} || [
                { price => 100.00 },
            ],
        } );

    my $order_nr = $order->order_nr;
    $mech->order_nr($order_nr);

    if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
        note sprintf "Shipping Acc.: %s", $shipping_account->name;
        note "Order Nr: $order_nr";
        note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;
    }

    my ($ship_nr, $status, $category)   = gather_order_info();
    note "Shipment Nr: $ship_nr";

    # The order status might be Credit Hold. Check and fix if needed
    if ( $status eq "Credit Hold" ) {
        note 'Credit Hold';
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $mech->reload;
        $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
        ($ship_nr, $status, $category) = gather_order_info();
    }
    is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

    # set shipment item logs
    $order->discard_changes;
    my @items   = $order->shipments->first->shipment_items->all;
    foreach my $item ( @items ) {
        $item->create_related( 'shipment_item_status_logs', {
                                        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                        operator_id             => $APPLICATION_OPERATOR_ID,
                                } );
    }

    # Get shipment to packing stage
    my $skus    = $mech->get_order_skus();
    my $vskus   = Test::XTracker::Data->stripout_vvoucher_from_skus( $skus );
    if ($prl_rollout_phase) {
        Test::XTracker::Data::Order->allocate_order($order);
        Test::XTracker::Data::Order->select_order($order);
        my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });
        $framework->flow_msg__prl__pick_shipment(
            shipment_id => $order->shipments->first->id,
            container => {
                $container_id => [keys %$skus],
            }
        );
        $framework->flow_msg__prl__induct_shipment(
            shipment_row => $order->shipments->first,
        );
    } else {
        my $print_directory = Test::XTracker::PrintDocs->new;
        $mech->test_direct_select_shipment( $ship_nr );
        $skus   = $mech->get_info_from_picklist($print_directory,$skus);
        $mech->test_pick_shipment( $ship_nr, $skus );
    }

    # make sure all items are set as picked
    $order->discard_changes;
    @items  = $order->shipments->first->shipment_items->all;
    foreach my $item ( @items ) {
        if ( $item->is_virtual_voucher ) {
            $item->create_related( 'shipment_item_status_logs', {
                                            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
                                            operator_id             => $APPLICATION_OPERATOR_ID,
                                    } );
        }
        if ( $item->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__PICKED ) {
            $item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
            $item->create_related( 'shipment_item_status_logs', {
                                            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                                            operator_id             => $APPLICATION_OPERATOR_ID,
                                    } );
        }
    }

    test_pack_qc( $mech, $session_store, $test, $ship_nr, $test->{pids}, $skus, $vskus, 1 );
    test_packing( $mech, $session_store, $test, $ship_nr, $test->{pids}, $skus, $vskus, 1 );
}

done_testing;

=head2 test_packing

 $mech  = test_packing($mech,$test,$shipment_id,$skus,$vskus)

Test to make sure a shipment with vouchers can be packed.

=cut

sub test_packing {
    my ($mech,$session_store,$test,$ship_nr,$pids,$skus,$vskus)    = @_;

    my $schema      = Test::XTracker::Data->get_schema;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    my $ship_items  = $shipment->shipment_items->search( undef, { order_by => 'me.id' } );
    my $users_name  = $mech->logged_in_as_logname;
    my $channel_id  = $shipment->order->channel_id;
    my $channel     = $shipment->order->channel->business->config_section;
    my $box_count;
    my $dc_name     = Test::XTracker::Data->whatami();
    my $tmp;

    if ( config_var('DHL', 'xmlpi_region_code') eq 'AM' )  {
        my $dbh = $schema->storage->dbh;
        fail('Remove obsolete block of code that fixes previous test failure')
            if ( $shipment->destination_code && $shipment->is_carrier_automated );
        set_dhl_destination_code( $dbh, $shipment->id, 'LHR' );
        $shipment->set_carrier_automated( 1 );
        is( $shipment->is_carrier_automated, 1, "Shipment is now Automated" );
    }

    # inner/outer boxes [0] - Inner, [1] - Outer
    my @boxes;
    if ( $channel eq "NAP" ) {
        @boxes  = ( 'NAP 3', "3" );
    }
    elsif ( $channel eq "OUTNET" ) {
        @boxes  = ( 'ON BAG L', "4" );
    }

    note "TESTING Pack Shipment";

    my %ship_qc_flds;

    # store renumeration id's for shipment
    # for later tests
    $tmp    = $shipment->renumerations->search( undef, { order_by => 'id DESC' } )->first;
    my $invoice_id  = ( defined $tmp ? $tmp->id : 0 );
    my @invitems_id;
    while ( my $item = $ship_items->next ) {
        $tmp    = $item->renumeration_items->search( undef, { order_by => 'id DESC' } )->first;
        push @invitems_id, ( defined $tmp ? $tmp->id : 0 );
        $ship_qc_flds{'shipment_item_qc_'.$item->id}    = 1 if ( !$item->is_virtual_voucher );
        $ship_qc_flds{'shipment_extra_item_qc_GiftMessage_' . $item->id} = 1
            if ($shipment->has_gift_messages() && $shipment->can_automate_gift_message()
            && (defined($item->gift_message) && $item->gift_message ne ''));
    }

    $ship_qc_flds{'shipment_extra_item_qc_GiftMessage'} = 1
        if ($shipment->has_gift_messages() && $shipment->can_automate_gift_message()
        && defined($shipment->gift_message) && $shipment->gift_message ne '');

    my $not_qced_code   = _mock_packqc_session( $session_store, $shipment, $pids );

    # just go straight to the Check Shipment page, missing the initial list and Pack QC pages
    $mech->get_ok('/Fulfilment/Packing/CheckShipment?shipment_id='.$shipment->id.'&from_pack_qc=1');
    like( $mech->uri, qr{Fulfilment/Packing/CheckShipment}, "Didn't get re-directed from Check Shipment page" );

    # Load session from storage
    my $session = $session_store->get_session;

    # check session stuff survived
    ok( scalar( keys %{ $session->{pack_qc}{qced_codes} } ), "qced_codes exists in session" );
    ok( scalar( keys %{ $session->{pack_qc}{qced_items} } ), "qced_items exists in session" );

    _correct_pids_onpage( $mech, $pids, "Check Shipment - " );

    $mech->submit_form_ok({
            form_name => 'pickShipment',
            with_fields => \%ship_qc_flds,
            #button => 'submit'
    },"Start Packing Shipment");
    $mech->no_feedback_error_ok;

    # check Invoice Items were created
    # for all ship items including Virtual
    note "Testing - Invoice Items Created";
    $shipment->discard_changes;
    $ship_items->reset;
    $tmp    = $shipment->renumerations->search( undef, { order_by => 'id DESC' } )->first->id;
    cmp_ok( $tmp, '>', $invoice_id, "New Invoice created for Shipment" );
    while ( my $item = $ship_items->next ) {
        $item->discard_changes;
        $tmp    = $item->renumeration_items->search( undef, { order_by => 'id DESC' } )->first;
        cmp_ok( $tmp->id, '>', shift @invitems_id, "New Invoice Item created for Shipment Item: ".$item->id );
        cmp_ok( $tmp->unit_price, '==', $item->unit_price, "New Invoice Item 'unit_price' matches Shipment Item 'unit_price'" );
    }
    # reset the cursor for future use
    $ship_items->reset;

    _correct_pids_onpage( $mech, $pids, "Pack Item - " );

    # check Virtual Vouchers can't be packed
    foreach my $vsku ( keys %{ $vskus } ) {
        $mech->submit_form_ok({
                with_fields => {
                    sku => $vsku,
                },
                button => 'submit'
        }, "Packing Virtual Voucher SKU: $vsku");
        $mech->has_feedback_error_ok( qr/The item entered is for a Virtual Voucher and can't be Packed/, "Can't Pack Virtual Voucher error found" );
    }

    # Pack all Items
    foreach ( 0..$#{ $pids } ) {
        my $pid = $pids->[ $_ ];
        my $vcode;

        # if virtual voucher, skip it
        next        if ( $pid->{voucher} && !$pid->{is_physical} );

        # get the stock log count to compare later and the shipment item that will be used
        my $log_stck_count = $schema->resultset('Public::LogStock')->count;
        my $log_vcred_count= $schema->resultset('Voucher::CreditLog')->count;
        my $vid_fld     = ( $pid->{voucher} ? 'voucher_variant_id' : 'variant_id' );
        $ship_items->reset();
        my $ship_item   = $ship_items->search(
                                            {
                                                $vid_fld                => $pid->{variant_id},
                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                                            },
                                            {
                                                order_by => 'me.id',
                                            }
                                        )->first;
        note "Shipment Item Id: ".$ship_item->id;

        # check some error messages appear only
        # need to do this once and for one test
        if ( $test->{cant_pack_errs} && $_ == 0 ) {
            _test_cant_pack_errors( $mech, $pid, $ship_items );
        }

        $mech->submit_form_ok({
                with_fields => {
                    sku => $pid->{sku},
                },
                button => 'submit'
        }, "Packing SKU: $pid->{sku}");
        $mech->no_feedback_error_ok;

        if ( $pid->{voucher} ) {
            $vcode  = shift @{ $pid->{voucher_codes} };
            ok (
                $mech->look_down (
                    _tag => 'td',
                    sub {$_[0]->as_trimmed_text =~ /Gift Card Code/}
                ),
                "Voucher Code Prompt Shown"
            );

            # check with invalid Voucher Code
            $mech->submit_form_ok({
                    with_fields => {
                        voucher_code => 'alskjdf',
                    },
                    button => 'submit'
            }, "Invalid Voucher Code" );
            $mech->has_feedback_error_ok( qr/alskjdf - This code is faulty/, "Invalid Voucher Code error" );

            # check with Voucher Code not in QC list
            $mech->submit_form_ok({
                    with_fields => {
                        voucher_code => $not_qced_code->code,
                    },
                    button => 'submit'
            }, "Voucher Code not in QC'd list: ".$not_qced_code->code );
            $tmp    = $not_qced_code->code;
            $mech->has_feedback_error_ok( qr/$tmp - Gift Card Code was not one of the ones that was QC'd/, "Voucher Code NOT in QC'd list error" );

            # check with good code
            $mech->submit_form_ok({
                    with_fields => {
                        voucher_code => $vcode->code,
                    },
                    button => 'submit'
            }, "Voucher Code Submit: ".$vcode->code );
            $mech->no_feedback_error_ok;
        }

        # if this is the last SKU then we should have
        # automatically moved on to the next page
        if ( $_ == $#{ $pids } ) {
            $mech->has_tag_like( 'h3', qr/Assign Box to Packed Items/, "Last SKU so on Add Box Page" );
        }
        else {
            $mech->content_like( qr/Packed Items.*$pid->{sku}/s, "SKU is now in 'Packed Items' table" );
        }

        # check Shipment Item Status etc. was updated and logged
        $ship_item->discard_changes;
        cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PACKED, "Shipment Item Status as expected" );
        if ( $pid->{voucher} ) {
            $vcode->discard_changes;
            cmp_ok( $ship_item->voucher_code_id, '==', $vcode->id, "Shipment Item Voucher Code Id as expected" );
            ok( defined $vcode->assigned, "Voucher now has an Assigned Date" );
            $tmp    = $schema->resultset('Voucher::CreditLog')->count;
            cmp_ok( $tmp, '>', $log_vcred_count, "Voucher Code Credit Log: Only one New Log created" );
            $tmp    = $vcode->credit_logs->search( undef, { order_by => 'me.id DESC' } )->first;
            cmp_ok( $tmp->delta, '==', $vcode->voucher_product->value, "Voucher Code Credit Log: Delta as expected" );
            ok( !defined $tmp->spent_on_shipment_id, "Voucher Code Credit Log: Shipment Id is undefined" );
        }
        $tmp    = $ship_item->shipment_item_status_logs->search( undef, { order_by => 'me.id DESC' } )->first;
        cmp_ok( $tmp->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PACKED, "Shipment Item Status Id in Log as expected" );
        $tmp    = $schema->resultset('Public::LogStock')->count;
        ok( ($tmp - $log_stck_count) == 1, "Variant Stock Log: Only one New Log created" );
        $tmp    = $schema->resultset('Public::LogStock')->search(
            { variant_id => $pid->{variant_id} },
            { order_by => 'me.id DESC', rows => 1 }
        )->first;
        cmp_ok( $tmp->stock_action_id, '==', $STOCK_ACTION__ORDER, "Variant Stock Log: Action Id as expected" );
        is( $tmp->notes, $ship_nr, "Variant Stock Log: Notes contain Shipment Id as expected" );
    };

    $mech->submit_form_ok({
            with_fields => {
                inner_box_id => $boxes[0],
                outer_box_id => $boxes[1],
                shipment_box_id => Test::XTracker::Data->get_next_shipment_box_id,
            },
            button => 'submit'
    }, "Added box");
    $mech->no_feedback_error_ok;
    $shipment->discard_changes;
    $ship_items->reset();
    my $box_id  = $shipment->shipment_boxes->first->id;
    while ( my $item = $ship_items->next ) {
        if ( $item->voucher_variant_id ) {
            if ( $item->voucher_variant->product->is_physical ) {
                is( $item->shipment_box_id, $box_id, "Physical Voucher Item has Shipment Box Id" );
            }
            else {
                ok( !defined $item->shipment_box_id, "Virtual Voucher Item DOESN'T have Shipment Box Id" );
            }
        }
        else {
            is( $item->shipment_box_id, $box_id, "Normal Product Item has Shipment Box Id" );
        }
    }

    if ( !$shipment->is_returnable ) {
        $mech->content_like( qr/Do not include a Return AWB with this shipment as all shipment items are non-returnable/,
                               "Message to omit return AWB correctly displayed" );
    }

    # Add return air waybills at packing
    if ( $shipment->is_returnable && config_var('DistributionCentre','expect_AWB') ) {
        my ( $ret_awb ) = Test::XTracker::Data->generate_air_waybills;
        $mech->submit_form_ok({
                with_fields => {
                        return_waybill => $ret_awb,
                },
                button => 'submit'
        }, "Added return airway bill");
        $mech->no_feedback_error_ok;
    }

    my $print_directory = Test::XTracker::PrintDocs->new;
    $mech->submit_form_ok({
            form_name => 'completePack',
            button => 'submit'
    }, "Completed Packing");
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/Shipment @{[$shipment->id]} has now been packed/ );
    if ( $shipment->display_no_returns_warning_after_packing ) {
        $mech->content_like( qr/Returns documentation will not be printed for this shipment as all shipment items are non-returnable/,
                               "Displayed message that no returns documentation will be printed" );
    }

    # We generate a shipping form for non-automated shipments and always an invoice
    my @expected_docs;
    push @expected_docs, 'shippingform' unless $shipment->is_carrier_automated;

    push @expected_docs, 'invoice';
    # you only get gift message warnings if gift message real printing is disabled
    if (!$shipment->can_automate_gift_message() && $test->{gift_message_warning_nr} > 0) {
        my $gift_messages = $shipment->get_gift_messages();
        foreach my $gift_message (@$gift_messages) {
            if (defined($gift_message->shipment_item)) {
                # filename = 'giftmessagewarning-<shipment-id>-<shipment_item_id>
                # but file_type test strips off only the last "-" part, leaving the comparison
                # as just "giftmessagewarning-<shipment-id>"
                push(@expected_docs, 'giftmessagewarning-'. $shipment->id);
            } else {
                push(@expected_docs, 'giftmessagewarning');
            }
        }
    }
    # We only expect a return proforma if we have a returnable
    # (non-voucher) item in our shipment
    push @expected_docs, 'retpro' if grep { !$_->{product}->is_voucher } @$pids;

    my ($expected_outpro) = check_country_paperwork( $schema->storage->dbh, $shipment->order->invoice_address->country );
    push @expected_docs, 'outpro' if $expected_outpro;

    my @print_files = $print_directory->wait_for_new_files( files => scalar @expected_docs );
    for my $expected_doc ( @expected_docs ) {
        ok( (grep { $_->file_type eq $expected_doc } @print_files), "found $expected_doc" );
    }

    if ( !$shipment->is_carrier_automated ) {
        my $barcode_directory = Test::XTracker::PrintDocs->new;
        $barcode_directory->non_empty_file_exists_ok( "pickorder$ship_nr.png", 'should find barcode file' );
        undef $barcode_directory;
    }

    if ( $test->{chk_vv_is_packed} ) {
        # check any virtual items have been 'Packed' also
        $shipment->discard_changes;
        $ship_items->reset;
        while ( my $item = $ship_items->next ) {
            if ( $item->is_virtual_voucher ) {
                cmp_ok( $item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__PACKED,
                                "Virtual Voucher Item is now 'Packed'" );
                cmp_ok( $item->shipment_item_status_logs->count( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } ), '==', 1,
                                    "Virtual Voucher Item has logged Packed status" );
            }
        }
    }
    return $mech;
}

=head2 test_pack_qc

 $mech  = test_pack_qc($mech,$session_store,$test,$shipment_id,$pids,$skus,$vskus)

=cut

sub test_pack_qc {
    my ($mech,$session_store,$test,$ship_nr,$pids,$skus,$vskus)    = @_;

    my $schema      = Test::XTracker::Data->get_schema;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    my $tmp;
    my @tmp;

    note "TESTING Packing QC";

    $mech->get_ok('/Fulfilment/Packing');
    ok (
        $mech->look_down (
            _tag => 'td',
            sub {$_[0]->as_trimmed_text =~ /$ship_nr/}
        ),
        "Found Shipment Id in List"
    ) or diag $mech->content;

    if ( $test->{chk_cancelled_vouch} ) {
        # Check that when there are Cancelled Physical/Virtual Vouchers you go
        # straight to the Pre-Packing Page and not the PackQC page or get Rejected
        # because of Virtual Vouchers without codes

        note "Check Shipments with Cancelled Vouchers go straight to Pre-Packing page";

        # cancel any Voucher item
        @tmp    = $shipment->shipment_items->all;
        foreach my $item ( @tmp ) {
            if ( $item->is_voucher ) {
                $item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED } );
            }
        }

        $mech->submit_form_ok({
                form_name => 'packShipment',
                with_fields => {
                    shipment_id => $ship_nr,
                },
                button => 'submit'
        }, "Pack shipment with cancelled vouchers");
        $mech->no_feedback_error_ok;
        like( $mech->uri, qr{Fulfilment/Packing/CheckShipment}, "On PrePackShipment page" );

        # TRY Cancel Pending
        $mech->get_ok('/Fulfilment/Packing');

        # cancel any Voucher item
        @tmp    = $shipment->shipment_items->all;
        foreach my $item ( @tmp ) {
            if ( $item->is_voucher ) {
                if ( $item->voucher_variant->product->is_physical ) {
                    $item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING } );
                }
            }
        }

        $mech->submit_form_ok({
                form_name => 'packShipment',
                with_fields => {
                    shipment_id => $ship_nr,
                },
                button => 'submit'
        }, "Pack shipment with cancelled pending vouchers");
        $mech->no_feedback_error_ok;
        like( $mech->uri, qr{Fulfilment/Packing/CheckShipment}, "On PrePackShipment page" );

        # Set any Voucher item back to Picked
        @tmp    = $shipment->shipment_items->all;
        foreach my $item ( @tmp ) {
            if ( $item->is_voucher ) {
                $item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
            }
        }

        # call the Packing page again
        $mech->get_ok('/Fulfilment/Packing');
    }

    $mech->submit_form_ok({
            form_name => 'packShipment',
            with_fields => {
                shipment_id => $ship_nr,
            },
            button => 'submit'
    }, "Pack shipment");

    if ( $test->{chk_no_vv_codes} ) {
        $mech->has_feedback_error_ok( qr/$ship_nr.*Contact Customer Care.*Request Virtual Voucher Codes/i,
                    "Error Message appears on page telling user to contact Customer Care" );
        @tmp    = $shipment->shipment_items->all;
        # assign a code to all virtual voucher items
        foreach my $item ( @tmp ) {
            if ( $item->is_virtual_voucher ) {
                my $code    = shift @{ $pids->[2]{voucher_codes} };
                $item->discard_changes;
                $item->update( { voucher_code_id => $code->id } );
            }
        }

        $mech->submit_form_ok({
                form_name => 'packShipment',
                with_fields => {
                    shipment_id => $ship_nr,
                },
                button => 'submit'
        }, "Pack shipment with V.Codes Set");
    }

    $mech->no_feedback_error_ok;

    like( $mech->uri, qr{Fulfilment/Packing/PackQC}, "Redirected to 'PackQC' page" );
    $mech->has_tag_like( 'span', qr/QC Voucher/, "Page has correct title" );

    # do the Physical Vouchers exist on the page & Normal PIDs don't
    foreach my $pid ( @{ $pids } ) {
        if ( $pid->{voucher} && $pid->{is_physical} ) {
            $mech->has_tag_like( 'td', qr/$pid->{sku}/, "Found Physical Voucher: $pid->{sku} on page" );
        }
        elsif ( !$pid->{voucher} ) {
            $mech->content_unlike( qr/$pid->{sku}/, "Can't find Normal SKU ($pid->{sku}) in Page" );
        }
    }
    # do the Virtual Vouchers not exist on the page
    foreach my $sku ( keys %{ $vskus } ) {
        $mech->content_unlike( qr/$sku/, "Can't find Virtual Voucher SKU ($sku) in Page" );
    }

    # test invalid code for first test only
    if ( $test->{inv_code_for_qc} ) {
        $mech->submit_form_ok({
            with_fields => {
                voucher_code    => 'lskajdfh',
            },
            button => 'submit',
        }, "Invalid Voucher Code Submit" );
        $mech->has_tag_like( 'span', qr/lskajdfh - This code is faulty/, "Faulty code message found" );
    }

    # store vcodes used so they can be put back again
    # for future tests
    my %store_vcodes;

    # QC all Phys Vouchers
    foreach my $pid ( @{ $pids } ) {
        # if normal SKU or virtual voucher we don't want it
        next        if ( !$pid->{is_physical} );

        my $vcode   = shift @{ $pid->{voucher_codes} };
        push @{ $store_vcodes{ $pid->{sku} } }, $vcode;

        $mech->submit_form_ok({
            with_fields => {
                voucher_code    => $vcode->code,
            },
            button  => 'submit',
        }, "QC Voucher: ".$pid->{sku}.", Code: ".$vcode->code );
        $mech->no_feedback_error_ok;
        $tmp    = $mech->find_xpath("//span[\@class='vcode_err']");
        cmp_ok( $tmp->size, '==', 0, 'No Voucher Code Error' );

        $mech->content_like( qr/QC'd Items.*$pid->{sku}/s, "SKU now in QC'd table" );
    }

    $mech->content_unlike( qr/Vouchers to QC/, "Voucher to QC table gone, all QC'd" );
    $mech->has_feedback_success_ok( qr/QC'ing Now Complete/ );
    $mech->submit_form_ok({
        form_name => 'QCPassed',
        button  => 'submit',
    }, "Goto Check Packing Page" );
    $mech->no_feedback_error_ok;
    like( $mech->uri, qr{Fulfilment/Packing/CheckShipment}, "Redirected to Check Shipment page" );

    my $session = $session_store->get_session;

    # check session contains QC'd data
    isa_ok( $session->{pack_qc}, 'HASH', "'pack_qc' appears in session" );
    if ( defined $session->{pack_qc} ) {
        # check voucher codes exist in session
        foreach my $sku ( keys %store_vcodes ) {
            map { ok( exists $session->{pack_qc}{qced_codes}{ $_->code }, "Found in Session Voucher Code: ".$_->code ) } @{ $store_vcodes{ $sku } };
        }
        # check shipment items exist in session
        my $ship_items  = $shipment->shipment_items->search(
                                                        {
                                                            is_physical => 1,
                                                            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                                                        },
                                                        {
                                                            join => [ { voucher_variant => 'product' } ],
                                                            order_by => 'me.id',
                                                        }
                                                    );
        while ( my $item = $ship_items->next ) {
            ok( exists $session->{pack_qc}{qced_items}{ $item->id }, "Found in Session Shipment Item: ".$item->id );
        }
    }

    # this should test that going to the CheckShipment page without comming
    # from the Pack QC page should clear out the 'pack_qc' session key
    $mech->get_ok('/Fulfilment/Packing/CheckShipment?shipment_id='.$shipment->id, "Goto Check Shipment which should clear the Session" );

    # Refresh the session from storage
    $session = $session_store->get_session;

    ok( !scalar( keys %{ $session->{pack_qc}{qced_codes} } ), "'pack_qc->qced_codes' has gone from session" );
    ok( !scalar( keys %{ $session->{pack_qc}{qced_items} } ), "'pack_qc->qced_items' has gone from session" );

    # put back the voucher codes
    # for future tests
    my %pids_done;
    foreach my $pid ( @{ $pids } ) {
        if ( $pid->{is_physical} && !exists $pids_done{ $pid->{pid} } ) {
            unshift @{ $pid->{voucher_codes} }, @{ $store_vcodes{ $pid->{sku} } };
            $pids_done{ $pid->{pid} }   = 1;
        }
    }

    $session_store->save_session;
    return $mech;
}

#------------------------------------------------------------------------------------------------

# this tests that various error messages are shown
# when a SKU is scanned in but not ready to be packed
sub _test_cant_pack_errors {
    my ( $mech, $pid, $ship_items ) = @_;

    my $vid_fld     = ( $pid->{voucher} ? 'voucher_variant_id' : 'variant_id' );
    my $ship_item   = $ship_items->search( { $vid_fld => $pid->{variant_id} } )->first;

    my $schema      = Test::XTracker::Data->get_schema;
    note "Testing Error Messages when Packing an Item";

    my %errors  = (
            $SHIPMENT_ITEM_STATUS__SELECTED => {
                label   => "Not Ready error found",
                err_msg => "The item entered is not ready to be packed",
            },
            $SHIPMENT_ITEM_STATUS__CANCEL_PENDING => {
                label   => "Cancelled Item message 1 error found",
                err_msg => "The item entered has been cancelled",
            },
            $SHIPMENT_ITEM_STATUS__CANCELLED => {
                label   => "Cancelled Item message 2 error found",
                err_msg => "The item entered has been cancelled",
            },
            $SHIPMENT_ITEM_STATUS__PACKED => {
                label   => "Item Already Packed error found",
                err_msg => "The item entered has already been packed",
            },
        );

    foreach my $status_id ( sort keys %errors ) {
        $ship_item->update( { shipment_item_status_id => $status_id } );
        $mech->submit_form_ok({
                with_fields => {
                    sku => $pid->{sku},
                },
                button => 'submit'
        }, "Error Check, Packing SKU: $pid->{sku}");
        $mech->has_feedback_error_ok( qr/$errors{$status_id}{err_msg}/, $errors{$status_id}{label} );
        # reset the status to what it should be
        $ship_item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
        $mech->back;
    }

    note "END OF - Testing Error Messages when Packing an Item";
    return $mech;
}

# decides if Physical Vouchers & Normal PIDs
# show up on the page and Virtual Vouchers don't
sub _correct_pids_onpage {
    my ( $mech, $pids, $prefix )    = @_;

    note "Testing - Correct PID's appear on the page";
    foreach my $pid ( @{ $pids } ) {
        CASE: {
            # Physical Voucher
            if ( $pid->{voucher} && $pid->{is_physical} ) {
                $mech->has_tag_like( 'td', qr/$pid->{sku}/, "${prefix}Found Physical Voucher: $pid->{sku} on page" );
                $mech->has_tag_like( 'li', qr/Check for gift message/, "${prefix}Found Physical Voucher: Shipping Note line 1" );
                $mech->has_tag_like( 'li', qr/Pack in Gift Voucher box/, "${prefix}Found Physical Voucher: Shipping Note line 2" );
                last CASE;
            }
            # Virtual Voucher
            if ( $pid->{voucher} && !$pid->{is_physical} ) {
                $mech->content_unlike( qr/$pid->{sku}/, "${prefix}Can't find Virtual Voucher: $pid->{sku} on Page" );
                last CASE;
            }
            # Normal PID
            ok (
                $mech->look_down (
                    _tag => 'td',
                    sub {$_[0]->as_trimmed_text =~ /$pid->{sku}/}
                ),
                "${prefix}Found Normal SKU: $pid->{sku} on page"
            );
            ok (
                $mech->look_down (
                    _tag => 'td',
                    sub {$_[0]->as_trimmed_text =~ /This is the packing note for $pid->{pid}/}
                ),
                "${prefix}Found Normal SKU: Shipping Note on page"
            );
        };
    }
    return $mech;
}

# mock a session as if it's come from the Pack QC page
# also returns a code that was not QC'd
sub _mock_packqc_session {
    my ( $session_store, $shipment, $pids )  = @_;

    my $session = $session_store->get_session;

    my @ship_items  = $shipment->shipment_items->search(
                                                    {
                                                        is_physical => 1,
                                                        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                                                    },
                                                    {
                                                        join    => [ { voucher_variant => 'product' } ],
                                                        order_by=> 'me.id',
                                                    } )->all;
    my $code_notqced;
    my %store_vcodes;
    my $pack_qc = {};
    my %items_used;
    foreach my $pid ( @{ $pids } ) {
        # if normal SKU or virtual voucher we don't want it
        next        if ( !$pid->{is_physical} );

        my $vcode   = shift @{ $pid->{voucher_codes} };
        push @{ $store_vcodes{ $pid->{sku} } }, $vcode;

        foreach my $item ( @ship_items ) {
            if ( $item->voucher_variant_id == $pid->{variant_id} && !exists $items_used{ $item->id } ) {
                $pack_qc->{qced_codes}{ $vcode->code }  = $item->id;
                $pack_qc->{qced_items}{ $item->id }     = $vcode->code;
                $items_used{ $item->id }    = 1;
                last;
            }
        }
    }
    $session->{pack_qc} = $pack_qc;

    # put back the voucher codes
    # for future tests
    foreach my $pid ( @{ $pids } ) {
        if ( $pid->{is_physical} ) {
            if ( !$code_notqced ) {
                # use a code that's not been QC'd
                $code_notqced   = $pid->{voucher_codes}[0];
                if ( !$code_notqced ) {
                    # if still not got a code, create one and add
                    # it to the list so that this doesn't happen again
                    $code_notqced   = $pid->{product}->create_related( 'codes', { code => 'NOTQC'.$pid->{pid} } );
                    push @{ $pid->{voucher_codes} }, $code_notqced;
                }
            }
            # re-populate the vouchers for testing but by 'shift'ing of the tmp store we don't
            # get duplication when an order has multiples of the same pid
            unshift @{ $pid->{voucher_codes} }, map { shift( @{ $store_vcodes{ $pid->{sku} } } ) } @{ $store_vcodes{ $pid->{sku} } };
        }
    }

    $session_store->save_session;
    return $code_notqced;
}

sub setup_user_perms {
    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR);
    # Perms needed for the order process
    for (qw/Airwaybill Dispatch Packing Picking Selection Labelling/ ) {
        Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, $AUTHORISATION_LEVEL__MANAGER);
    }
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
  my ($order_nr) = @_;

  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID
  note $mech->order_view_url;
  my $ship_nr = $mech->get_table_value('Shipment Number:');

  my $status = $mech->get_table_value('Order Status:');

  my $category = $mech->get_table_value('Customer Category:');
  return ($ship_nr, $status, $category);
}
