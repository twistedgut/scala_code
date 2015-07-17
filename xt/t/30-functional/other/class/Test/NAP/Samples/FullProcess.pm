package Test::NAP::Samples::FullProcess;

=head1 NAME

full-process.t - Test the full Goods In process for samples

=head1 DESCRIPTION

=head2 What we want to test here

=over

=item a

fast track goods in, then putaway to normal stock

Messages: C<pre_advice> (C<stock_status: 'main'>) and
C<stock_received>

See: sub C<receive_and_fasttrack_sample>.

=item b

create a sample request

Messages: nothing

See: sub C<request_and_ship_sample>.

=item c

fulfill the sample request with normal stock

Messages: C<shipment_request>, with C<shipment_type: 'sample'>
*let's assume* that IWS will pick from normal stock if we don't have
anything in the "holding area for fast-tracked goods in"

Then, of course, C<picking_commenced>, C<shipment_ready>,
C<shipment_received>, C<shipment_packed>

See: sub C<request_and_ship_sample>.

=item d

fast track goods in, then putaway to "the special location"

Messages: same as L</a>

See: sub C<receive_and_fasttrack_sample>, called with C<< {location=>'GI'} >>

=item e

fulfill the sample request with fast-tracked goods in

Messages: same as L</c>, Ravni picks from "the special location"

See: sub C<request_and_ship_sample>, called with C<< {location=>'GI'} >>

=item f

return samples to normal stock

Messages: same as L</a>, but C<pre_advice> with C<is_return: true>

See: sub C<return_sample>

=item g

vendor samples in

Messages: nothing

=item h

book vendor samples into normal stock

Messages: same as L</a>

=item i

test putaway via C<stock_received> only, no Ravni, for sample returns
& vendor samples

See: sub C<return_sample>, called with C<< {skip_ravni=>1} >>

=back

#TAGS toobig iws inventory sample fasttrack return goodsin checkruncondition whm

=head1 METHODS

=cut

use NAP::policy qw/tt test/;

use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants::FromDB
    qw(
          :authorisation_level
          :flow_status
          :purchase_order_type
          :shipment_status
          :stock_action
          :stock_order_item_type
          :stock_order_status
          :stock_order_type
          :stock_process_type
          :stock_transfer_type
  );
use Test::XTracker::MessageQueue;
# According to the original author, this was never meant to work in DC2...
# ... and yet there's loads of code that checks for dc/phase :/
use Test::XTracker::RunCondition dc => 'DC1', export => [qw< $distribution_centre $iws_rollout_phase >];
use Test::XTracker::PrintDocs;
use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Data::Container;
use JSON::XS;
use Carp::Always;
use XTracker::Database::Stock 'get_located_stock';

sub startup : Test(startup) {
    my $self = shift;

    my $flow = $self->{flow} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Data::Location',
            'Test::XT::Flow::GoodsIn',
            'Test::XT::Flow::Samples',
            'Test::XT::Data::Samples',
            'Test::XT::Flow::Fulfilment',
            'Test::XT::Flow::StockControl',
            'Test::XT::Flow::PrintStation',
            'Test::XT::Flow::WMS',

        ],
    );
    $flow->mech->force_datalite(1);

    if ( Test::XTracker::Data->whatami eq 'DC2' ) {
        $flow->data__location__initialise_non_iws_test_locations;
    }

    note 'Clearing all test locations';
    $flow->data__location__destroy_test_locations;
}

sub xt_to_wms {
    Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
}

sub request_sample_from_existing_stock_and_cancel_it : Tests {
    my $self = shift;
    $self->request_and_ship_sample({cancel_it=>1});
}

sub request_sample_from_existing_stock_and_return_it : Tests {
    my $self = shift;
    my $sample = $self->request_and_ship_sample();
    $self->return_sample($sample);
}

sub request_sample_from_inexistent_stock_fasttrack_and_return_it_no_ravni : Tests {
    my $self = shift;

    my $channel = Test::XTracker::Data->channel_for_nap;
    my $fast_track_location
        = $self->schema->resultset('Public::Location')->search({
            location => 'GI',
        })->slice(0,0)->single;

    my $sample = $self->receive_and_fasttrack_sample({
        channel => $channel,
        location=> $fast_track_location->location,
        fast_track => 1
    });
    $sample = $self->request_and_ship_sample({
        %$sample,
        location=> $fast_track_location->location,
    });

    $self->return_sample({
        %$sample,
        skip_ravni=> 1,
        fast_track => 1
    });
}

sub request_vendor_sample_and_return_it : Tests {
    my $self = shift;
    my $sample = $self->request_and_receive_vendor_sample();
    $self->vendor_sample_to_stock($sample);
}

sub request_vendor_sample_and_return_it_faulty : Tests {
    my $self = shift;
    my $sample = $self->request_and_receive_vendor_sample();
    $self->vendor_sample_to_stock({ %$sample, qc_decision=>'Faulty'  });
}

sub request_vendor_sample_and_return_it_no_ravni : Tests {
    my $self = shift;
    my $sample = $self->request_and_receive_vendor_sample();
    $self->vendor_sample_to_stock({ %$sample, skip_ravni=>1  });
}

sub request_vendor_sample_and_return_it_faulty_no_ravni : Tests {
    my $self = shift;
    my $sample = $self->request_and_receive_vendor_sample();
    $self->vendor_sample_to_stock({
        %$sample,
        qc_decision=>'Faulty',
        skip_ravni=>1,
    });
}

sub _setup_po {
    my ($self, $args) = @_;
    $args ||= {};

    my $channel = $args->{channel} ||= Test::XTracker::Data->channel_for_nap;

    my $return;
    subtest 'Setup data' => sub {
        isa_ok(my $po = Test::XTracker::Data->create_from_hash({
            channel_id      => $channel->id,
            placed_by       => 'Test User',
            ( $args->{vendor_sample} ? ( type_id => $PURCHASE_ORDER_TYPE__SAMPLE ) : () ),
            stock_order     => [{
                status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
                ( $args->{vendor_sample} ? ( type_id => $STOCK_ORDER_TYPE__SAMPLE ) : () ),
                product         => {
                    product_type_id => 6, # Dresses
                    style_number    => 'Test Style',
                    variant         => [{
                        ( $args->{vendor_sample} ? ( type_id => 3 ) : () ),
                        stock_order_item    => {
                            ( $args->{vendor_sample} ? ( type_id => $STOCK_ORDER_ITEM_TYPE__SAMPLE ) : () ),
                            quantity            => ($args->{quantity} || 10),
                        },
                    }],
                    product_channel => [{
                        channel_id      => $channel->id,
                        live            => 0,
                    }],
                    product_attribute => {
                        description     => 'Test Description',
                    },
                },
            }],
        }), 'XTracker::Schema::Result::Public::PurchaseOrder');

        my ($delivery) = Test::XTracker::Data->create_delivery_for_po($po->id, 'qc');
        my ($sp) = Test::XTracker::Data->create_stock_process_for_delivery($delivery);

        my $variant = $po->stock_orders
            ->related_resultset('stock_order_items')
            ->related_resultset('variant')->single;

        my $reg_variant = $variant->product->search_related('variants',{
            size_id => $variant->size_id,
            type_id => 1,
        })->slice(0,0)->single;
        if (! $reg_variant) {
            my %cols = $variant->get_inflated_columns();
            delete $cols{id};$cols{type_id}=1;
            Test::XTracker::Data->bump_sequence('variant');
            $reg_variant = $self->schema->resultset('Public::Variant')->create(\%cols);
        }
        isa_ok( $reg_variant, 'XTracker::Schema::Result::Public::Variant' );

        $return = {
            %$args,
            purchase_order => $po,
            delivery => $delivery,
            stock_process => $sp,
            variant => $variant,
            reg_variant => $reg_variant,
        };
    };
    return $return;
}

=head2 receive_and_fasttrack_sample

=cut

sub receive_and_fasttrack_sample {
    my ($self, $args) = @_;
    $args ||= {};

    $args = $self->_setup_po($args);

    my ($channel,$po,$delivery,$sp,$variant) = @{$args}{qw(
        channel
        purchase_order
        delivery
        stock_process
        variant
    )};

    my $product = $variant->product;
    ok(!defined $product->storage_type_id,'no storage type defined');

    subtest 'Goods In' => sub {
        my $flow = $self->{flow};
        $flow->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__MANAGER => [
                'Goods In/Quality Control',
                'Goods In/Bag And Tag',
                'Goods In/Putaway',
            ]},
            dept => 'Distribution'
        });

        my $pre_advice;
        {
        my $xt_to_wms = $self->xt_to_wms;
        $flow->flow_mech__goodsin__fasttrack_deliveryid($delivery->id)
            ->flow_mech__goodsin__fasttrack_submit({
                fast_track => { $variant->sku => 1, }
            });
        ($pre_advice) = $xt_to_wms->expect_messages({
            messages => [ { 'type'   => 'pre_advice', } ]
        });
        }
        my $ft_sp = $self->schema->resultset('Public::StockProcess')->search({
            delivery_item_id => $sp->delivery_item_id,
            type_id => $STOCK_PROCESS_TYPE__FASTTRACK,
        })->slice(0,0)->single;
        $flow->flow_mech__goodsin__bagandtag_processgroupid($ft_sp->group_id)
            ->flow_mech__goodsin__bagandtag_processgroupid_submit();

        $product->discard_changes;
        # storage type should not be set when fast-tracking
        ok(!defined $product->storage_type_id,'no storage type defined after fast-track');

        $self->_do_putaway({
            %$args,
            product_id => $variant->product_id,
            sku => $variant->sku,
            is_return => 0,
            pre_advice => $pre_advice,
            test_prefix => 'Fast Track Putaway',
            stock_action => $STOCK_ACTION__PUT_AWAY,
            destination => 'sample',
        });

        $product->discard_changes;
        ok(!defined $product->storage_type_id,'no storage type defined after putaway');

    };
    return {
        product => {
            variant_id => $variant->id,
            pid => $variant->product_id,
            sku => $variant->sku,
            product => $product,
            variant => $variant,
        },
        channel => $channel,
    };
}

=head2 request_and_ship_sample

=cut

sub request_and_ship_sample {
    my ($self, $args) = @_;
    $args ||= {};

    my ($channel,$product) = @{$args}{qw/channel product/};
    if (!$args->{product}) {
        subtest 'Setup data' => sub {
            my $pids;
            # get a product with stock
            $args->{channel} ||= Test::XTracker::Data->channel_for_nap;
            ($channel,$pids) = Test::XTracker::Data->grab_products({
                channel  => $args->{channel},
                force_create => 1,
            });
            $product = $pids->[0];
        };
    }

    note 'Create Sample Request';

    my $flow = $self->{flow};
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Stock Control/Sample',
            'Stock Control/Inventory',
        ]},
        dept => 'Sample'
    });

    # prod overview → request stock
    # (reason "sample", test also "press" & "editorial"; what is
    # "sample return"?)
    $flow->flow_mech__stockcontrol__sample_request_stock__by_variant($product->{variant_id})
        ->flow_mech__stockcontrol__sample_request_stock_submit(
            $args->{transfer_type} || $STOCK_TRANSFER_TYPE__SAMPLE
        );

    note 'Approve request';

    # latest request, should be ours
    my $transfer = $self->schema->resultset('Public::StockTransfer')->search({
        variant_id => $product->{variant_id},
    },{
        order_by => { -desc => 'date' },
    })->slice(0,0)->single;

    # dept "Stock Control"
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Stock Control/Sample',
            'Stock Control/Inventory',
            'Fulfilment/Selection',
            ($iws_rollout_phase ? () : 'Fulfilment/Picking'),
            'Fulfilment/Packing',
            'Fulfilment/Dispatch',
        ]},
        dept => 'Stock Control'
    });

    # stock control / sample, approve the request
    $flow->flow_mech__stockcontrol__sample_requests()
        ->flow_mech__stockcontrol__sample_requests_submit($transfer->id);

    # ... picking up globals as we advance... :/
    my ($tote_id,$shipment,$picking_sheet);
    subtest 'Fulfilling request' => sub {
        # latest shipment for the just-created request (there should be
        # only one, but "just in case"...)
        $shipment = $transfer->link_stock_transfer__shipments
            ->search_related('shipment',{
            },{
                order_by => { -desc => 'date' },
            })->slice(0,0)->single;

        # fulfilment / selection / transfer shipments
        # select it
        my $shipment_request;
        {
        my $xt_to_wms = $self->xt_to_wms;
        if ($iws_rollout_phase) {
            $flow->flow_mech__fulfilment__selection_transfer
                ->flow_mech__fulfilment__selection_submit($shipment->id);
        }
        else {
            $picking_sheet =
                $flow->flow_task__fulfilment__select_shipment_return_printdoc( $shipment->id );
        }
        ($shipment_request) = $xt_to_wms->expect_messages( {
            messages => [ { 'type'   => 'shipment_request',
                            'details' => { shipment_id => 's-'.$shipment->id }
                        } ]
        } );
        }

        is($shipment_request->payload_parsed->{shipment_type},'sample',
        'correct shipment type');
        is($shipment_request->payload_parsed->{stock_status},'main',
        'correct stock status');
        is($shipment_request->payload_parsed->{premier},JSON::XS::false,
        'not a premier shipment');

        ($tote_id)=Test::XT::Data::Container->get_unique_ids;
    };

    if ($args->{cancel_it}) {
        subtest 'Cancelling request' => sub {
            {
            my $xt_to_wms = $self->xt_to_wms;
            $flow->flow_mech__stockcontrol__sample_requests()
                ->flow_mech__stockcontrol__sample_cancel_shipment($shipment->id);

            $xt_to_wms->expect_messages({
                messages => [{
                    'type'   => 'shipment_cancel',
                    'details' => { shipment_id => 's-'.$shipment->id }
                }]
            });
            }
            $shipment->discard_changes;
            is($shipment->shipment_status_id,$SHIPMENT_STATUS__CANCELLED,'shipment cancelled');

            if ($iws_rollout_phase) {
                # Fake a ShipmentReady from IWS
                $flow->flow_wms__send_shipment_ready(
                    shipment_id => $shipment->id,
                    container => { $tote_id => [ $product->{sku} ], },
                );
            }
        };

        return {
            transfer => $transfer,
            shipment => $shipment,
            product => $product,
            channel => $channel,
        }
    }

    subtest 'Fulfilling request continued' => sub {
        $flow->task__picking($shipment);

        $flow->mech__fulfilment__set_packing_station( $channel->id );

        {
        my $xt_to_wms = $self->xt_to_wms;
        $flow->flow_mech__fulfilment__packing
            ->flow_mech__fulfilment__packing_submit( $tote_id );
        $xt_to_wms->expect_messages({
            messages => [{
                'type'   => 'shipment_received',
                'details' => { shipment_id => 's-'.$shipment->id }
            }]
        });

        is($flow->mech->uri->path,
        '/Fulfilment/Packing/PackShipment',
        'shipment being packed, no QC');

        $flow->flow_mech__fulfilment__packing_packshipment_submit_sku(
                $product->{sku}
            )->flow_mech__fulfilment__packing_packshipment_submit_boxes(
                channel_id => $channel->id,
            )->flow_mech__fulfilment__packing_packshipment_complete
                # there's a JS redirect on the page to do the auto-rescan
                # we'll do it manually
            ->flow_mech__fulfilment__packing
            ->flow_mech__fulfilment__packing_submit( $tote_id )
            ->flow_mech__fulfilment__packing_emptytote_submit('yes');


        $xt_to_wms->expect_messages({
            messages => [{
                'type'   => 'shipment_packed',
                'details' => { shipment_id => 's-'.$shipment->id }
            }]
        });
        }

        $flow->flow_mech__fulfilment__dispatch
            ->flow_mech__fulfilment__dispatch_shipment($shipment->id);

        $flow->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Sample',
                'Stock Control/Inventory',
            ]},
            dept => 'Sample'
        });

        # stock control / sample / "sample transfer in"
        # mark it as received
        $flow->flow_mech__samples__stock_control_sample_goodsin()
            ->flow_mech__samples__stock_control_sample_goodsin__mark_received(
                $shipment->id,$channel->id,
            );
    };

    return {
        transfer => $transfer,
        shipment => $shipment,
        product => $product,
        channel => $channel,
    };
}

sub set_printer_station {
    my ($self,$section,$subsection,$channel_id) = @_;

    my $flow = $self->{flow};
    $flow
        ->flow_mech__select_printer_station({
            section => $section,
            subsection => $subsection,
            channel_id => $channel_id,
        });
    $flow->flow_mech__select_printer_station_submit;

    return;
}

=head1 return_sample

=cut

sub return_sample {
    my ($self,$args) = @_;

    my $flow = $self->{flow};
    my ($product,$rma);
    subtest 'RMA Sample' => sub {
        $flow->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Sample',
                'Stock Control/Inventory',
            ]},
            dept => 'Sample'
        });

        $product = $args->{product};

        # prod overview -> return stock, mark "return"
        $flow
            ->flow_mech__stockcontrol__sample_return_stock__by_variant(
                $product->{variant_id},
            );
        my $data=$flow->mech->as_data();
        my ($row) = grep { $_->{Sku}{value} eq $product->{sku} } @{$data->{stock_table}};
        my ($location_id) = ($row->{Location}{input_name} =~ m{-(\d+)$});
        $flow
            ->flow_mech__stockcontrol__sample_return_submit({
                variant_id => $product->{variant_id},
                location_id => $location_id,
                channel_id => $args->{channel}->id,
            });
        # read RMA number
        $rma = $flow->mech->uri->query_param('rma');
        ok(defined($rma),'obtained an RMA');
    };

    subtest 'Return Sample In' => sub {
        # goods in / returns in
        $flow->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__MANAGER => [
                'Goods In/Stock In',
                'Goods In/Item Count',
                'Goods In/Quality Control',
                'Goods In/Bag And Tag',
                'Goods In/Putaway',
                'Goods In/Returns In',
                'Goods In/Returns QC',
            ]},
            dept => 'Stock Control'
        });

        $self->set_printer_station('GoodsIn','ReturnsIn',$args->{channel}->id);

        $flow->flow_mech__goodsin__returns_in()
            ->flow_mech__goodsin__returns_in_submit($rma)
            ->flow_mech__goodsin__returns_in__book_in($product->{sku})
            ->flow_mech__goodsin__returns_in__complete_book_in('premier');

        $self->set_printer_station('GoodsIn','ReturnsQC',$args->{channel}->id);

        # scan RMA number
        my $pre_advice;
        {
        my $xt_to_wms = $self->xt_to_wms;
        $flow->flow_mech__goodsin__returns_qc()
            ->flow_mech__goodsin__returns_qc_submit($rma)
                # scan SKU
                # scan return AWB "premier" (yes, literally)
                # goods in / returns qc (printer station!)
                # scan RMA number (or delivery#)
                # pass, no labels
            ->flow_mech__goodsin__returns_qc__process();
        ($pre_advice) = $xt_to_wms->expect_messages({
            messages => [ { 'type'   => 'pre_advice', } ]
        });
        }

        $self->_do_putaway({
            %$args,
            product_id => $product->{pid},
            sku => $product->{sku},
            is_return => 1,
            test_prefix => 'Return Putaway',
            stock_action => $STOCK_ACTION__SAMPLE_RETURN,
            pre_advice => $pre_advice,
        });
    };
}

sub _do_putaway {
    my ($self,$args) = @_;

    $args->{stock_status} ||= $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
    $args->{log_stock} = 1 unless defined $args->{log_stock};

    my $schema = $self->{schema};
    my $stock_status_name = $schema->resultset('Flow::Status')
        ->find($args->{stock_status})
        ->iws_name();

    my $pre_advice = $args->{pre_advice};
    is($pre_advice->payload_parsed->{items}[0]{pid},
       $args->{product_id},
       'pre_advice pid correct');
    is($pre_advice->payload_parsed->{items}[0]{skus}[0]{sku},
       $args->{sku},
       'pre_advice sku correct');
    is($pre_advice->payload_parsed->{is_return},
       ($args->{is_return} ? JSON::XS::true : JSON::XS::false),
       'pre_advice is_return');
    is($pre_advice->payload_parsed->{destination},
       ($args->{destination} || 'main'),
       'pre_advice destination correct');
    is($pre_advice->payload_parsed->{stock_status},
       $stock_status_name,
       'pre_advice stock status correct');
    # uh... should a "fast track" be set anywhere?

    my $quantities_before_msg;
    my ($pgid) = ( $pre_advice->payload_parsed->{pgid} =~ m{^p-(\d+)$});

    my $sp_rs =  $schema->resultset('Public::StockProcess')->search({
        group_id => $pgid,
    });

    # Soooo, I hear you might have a PGID outstanding! That means you're going
    # to stop us doing a channel transfer, right? Thought so:
    my $ct_product   = $sp_rs->first->variant->product;
    my $from_channel = $ct_product->get_product_channel->channel;
    my $to_channel = Test::XTracker::Data->get_local_channel( {
        NAP => 'OUTNET',
        OUT => 'MRP',
        MRP => 'NAP'
    }->{ substr( $from_channel->web_name, 0, 3 ) } );
    if ( $args->{'fast_track' } ) {
        note "Skipping channel transfer for fast track";
    } else {
        note "Transfer from channel " . $from_channel->id . " TO " . $to_channel->id;
    }

    my $transfer;

    my $flow = $self->{flow};
    if ( $distribution_centre eq 'DC2' ) {
        # get variant object
        my $variant = $sp_rs->first->variant;
        # get src_location for $variant in $from_channel
        my $location_rs = Test::XTracker::Data->get_schema->resultset('Public::Location');
        my $src_locations = get_located_stock(
            Test::XTracker::Data->get_dbh,
            {
                type => 'variant_id',
                id => $variant->id,
                iws_rollout_phase => $iws_rollout_phase,
            },
            'stock_main'
        )->{$from_channel->name}{$variant->id};
        my @main_stock_locations = grep { exists($src_locations->{$_}->{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS}) } keys %$src_locations;
        my $src_location = $location_rs->find($main_stock_locations[0])->location;
        # find suitable dst_location for $variant in $to_channel
        my $floor = $to_channel->is_on_outnet ? 2 : 1;
        my $dst_location = $location_rs->get_locations({ floor => $floor })->first->location;
        $transfer = $flow->flow_task__stock_control__channel_transfer_phase_0({
            product      => $ct_product,
            channel_from => $from_channel,
            channel_to   => $to_channel,
            src_location => $src_location,
            dst_location => $dst_location,
            extra_permissions => [
                'Goods In/Stock In',
                'Goods In/Item Count',
                'Goods In/Quality Control',
                'Goods In/Bag And Tag',
                'Goods In/Putaway',
                'Goods In/Returns In',
                'Goods In/Returns QC',
            ],
            expect_error =>
                qr/PID \d+ has units that are transfer pending and cannot be transferred to another channel\./
        }) unless $args->{'fast_track'};
    }
    else {
        $transfer = $flow->flow_task__stock_control__channel_transfer_auto({
            product      => $ct_product,
            channel_from => $from_channel,
            channel_to   => $to_channel,
            extra_permissions => [
                'Goods In/Stock In',
                'Goods In/Item Count',
                'Goods In/Quality Control',
                'Goods In/Bag And Tag',
                'Goods In/Putaway',
                'Goods In/Returns In',
                'Goods In/Returns QC',
            ],
            expect_error =>
                qr/PID \d+ has units that are transfer pending and cannot be transferred to another channel\./
        }) unless $args->{'fast_track'};
    }

    for my $sp ($sp_rs->all) {
        $quantities_before_msg->{$sp->variant->id}
            = $schema->resultset('Public::Quantity')
                ->search({
                    variant_id => $sp->variant->id,
                    status_id  => $args->{stock_status},
                })
                    ->get_column('quantity')->sum;
    }

    my $stock_received;
    {
    my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');
    # goods in / putaway
    if ($args->{skip_ravni} || $iws_rollout_phase ) {
        subtest $args->{test_prefix}.' - no RAVNI' => sub {
            $flow->wms_receipt_dir->new_files();
            $flow->flow_wms__send_stock_received(
                sp_group_rs => $sp_rs,
                operator    => $flow->mech->logged_in_as_object,
            );
        };
    }
    else {
        subtest $args->{test_prefix} => sub {
            my ($pgid) = ( $pre_advice->payload_parsed->{pgid} =~ m{^p-(\d+)$});

            my $location = $args->{location} || $flow->data__location__create_new_locations({
                quantity    => 1,
                channel_id  => $args->{channel}->id,
            })->[0];

            $flow
                ->flow_mech__goodsin__putaway
                    ->flow_mech__goodsin__putaway_submit($pgid);
            $flow->errors_are_fatal(0);
            $flow->flow_mech__goodsin__putaway_book_submit( $location, 1 );
            $flow->errors_are_fatal(1);
            if (($flow->mech->app_error_message()||'') =~ m{Ignored Suggested Location}) {
                $flow->flow_mech__goodsin__putaway_book_submit( $location, 1 );
            }
            if (($flow->mech->app_status_message()||'') !~ /put away successfully/) {
                $flow->flow_mech__goodsin__putaway_book_complete;
            }
        };
    }
    ($stock_received) = $wms_to_xt->expect_messages( {
        messages => [ { 'type'   => 'stock_received',
                    } ]
    } );
    }
    is($stock_received->payload_parsed->{pgid},
       "p-$pgid",
       'stock_received pgid correct');
    is($stock_received->payload_parsed->{items}[0]{sku},
       $args->{sku},
       'stock_received sku correct');
    is($stock_received->payload_parsed->{items}[0]{quantity},
       ($args->{quantity} || 1),
       'stock_received quantity correct');

    for my $sp ($sp_rs->all) {
        my $variant_id = $sp->variant->id;
        my $new_quantity = $schema->resultset('Public::Quantity')->search({
            variant_id => $variant_id,
            status_id  => $args->{stock_status},
        })->get_column('quantity')->sum;
        my $sku = $sp->variant->sku;
        my $old_quantity = $quantities_before_msg->{$variant_id} || 0;
        my $quantity = $stock_received->payload_parsed->{items}[0]{quantity} || 0;
        my $putaway_quantity = 0;
        my ($pgid) = $stock_received->payload_parsed->{pgid} =~ /p\-(\d+)/;
        if ($sku eq $args->{sku} and $sp->group_id == $pgid){
            is($new_quantity, $old_quantity + $quantity , "quantity ok for variant: $variant_id");
            $putaway_quantity = $quantity;
        }
        else{
            is($new_quantity, $old_quantity , "quantity ok for variant: $variant_id");
        }
        if ($args->{log_stock}) {
            my $log_stock = $schema->resultset('Public::LogStock')
                ->search(
                    {
                        variant_id => $variant_id,
                        channel_id => $args->{channel}->id,
                    },
                    { order_by => { -desc => 'date' } }
                )->slice(0,0)->single;

            is( $log_stock->quantity, $putaway_quantity, 'quantity logged correctly' );
            is( $log_stock->balance, $sp->variant->current_stock_on_channel( $args->{channel}->id ), 'balance logged correctly' );
            is( $log_stock->stock_action_id, $args->{stock_action}, 'stock action logged correctly' );
        }
    }

    # Channel transfer should now work just fine...
    $flow->flow_task__stock_control__channel_transfer_auto({
        product      => $ct_product,
        channel_from => Test::XTracker::Data->channel_for_nap,
        channel_to   => Test::XTracker::Data->channel_for_out,
        extra_permissions => [
            'Goods In/Stock In',
            'Goods In/Item Count',
            'Goods In/Quality Control',
            'Goods In/Bag And Tag',
            'Goods In/Putaway',
            'Goods In/Returns In',
            'Goods In/Returns QC',
        ],
        transfer => $transfer,
    }) unless $args->{'fast_track'};

}

=head2 request_and_receive_vendor_sample

=cut

sub request_and_receive_vendor_sample {
    my ($self,$args)=@_;
    $args ||= {};

    $args = $self->_setup_po({ %$args, vendor_sample => 1, quantity => 1 });

    my $flow = $self->{flow};
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Stock Control/Sample',
            'Stock Control/Inventory',
        ]},
        dept => 'Sample'
    });

    subtest 'Vendor Sample In' => sub {
        # reset AMQ sent message monitor
        my $xt_to_wms = $self->xt_to_wms;
        $flow
            ->flow_mech__stockcontrol__sample_goods_in_variant($args->{variant}->id)
            ->flow_mech__stockcontrol__sample_goods_in_submit({
                $args->{variant}->sku => 1,
            });

        # test *NO* pre_advice
        my $new_messages =()= $xt_to_wms->new_files();
        is($new_messages,0,'pre_advice not sent');
    };
    return $args;
}

=head2 vendor_sample_to_stock

=cut

sub vendor_sample_to_stock {
    my ($self,$args) = @_;

    my $flow = $self->{flow};
    subtest 'Vendor Sample to Stock' => sub {
        $flow->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Sample',
                'Goods In/Vendor Sample In',
                'Goods In/Bag And Tag',
                'Goods In/Putaway',
            ]},
            dept => 'Sample'
        });

        my @ship_ids = $args->{variant}->shipment_items->get_column('id')->all;
        # http://10.5.16.75/StockControl/Sample/GoodsOut?variant_id=1120705
        # tick checkbok
        $flow
            ->flow_mech__stockcontrol__sample_goods_out_variant($args->{variant}->id)
            ->flow_mech__stockcontrol__sample_goods_out_submit({
                goods_out => [ $args->{variant}->sku ],
            });

        # test stock transfer
        my @shipment_items = $args->{variant}->search_related('shipment_items',{
            id => { -not_in => \@ship_ids },
        })->all;
        is(scalar(@shipment_items),1,'one transfer shipment item');
        my $shipment=$shipment_items[0]->shipment;

        # http://10.5.16.75/GoodsIn/VendorSampleIn
        # scan SKU
        $flow
            ->flow_mech__goodsin__vendor_sample_in
            ->flow_mech__goodsin__vendor_sample_in_submit({
                channel_id => $args->{channel}->id,
                sku => $args->{variant}->sku,
            });

        my $stock_status = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
        my $log_stock = 1;
        $args->{qc_decision} ||= 'Pass';
        if ($args->{qc_decision} =~ /faulty/i) {
            $args->{qc_faulty_reason} ||= 'Unknown';
            $stock_status = $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS;
            # we don't log stock transfers that don't end in main stock
            # and yes, this is a stock transfer
            $log_stock = 0;
        }
        my $pre_advice;
        {
        my $xt_to_wms = $self->xt_to_wms;
        $flow
            ->flow_mech__goodsin__vendor_sample_in__process({
                decision => $args->{qc_decision},
                faulty_reason => $args->{qc_faulty_reason},
            });
        ($pre_advice) = $xt_to_wms->expect_messages({
            messages => [ { 'type'   => 'pre_advice', } ]
        });
        }

        # qc pass (no print) -> putaway main
        # qc fail (no print) -> putaway dead (?)

        $self->_do_putaway({
            %$args,
            product_id => $args->{variant}->product_id,
            sku => $args->{variant}->sku,
            is_return => 0,
            log_stock => $log_stock,
            pre_advice => $pre_advice,
            test_prefix => 'Vendor Sample Putaway',
            stock_action => $STOCK_ACTION__PUT_AWAY,
            stock_status => $stock_status,
        });
    };
}
