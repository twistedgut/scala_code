package Test::NAP::Samples;

=head1 NAME

Test::NAP::Samples - Test inventory functions related to samples

=head1 DESCRIPTION

Test inventory functions related to samples.

#TAGS inventory sample packing loops intermittentfailure needswork toobig iws needsrefactor todo

=head1 METHODS

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition export => qw{$iws_rollout_phase};

use Test::XT::Data::Container;
use Test::XT::Flow;
use Test::XTracker::Data;
use Test::XTracker::Data::AccessControls;
use Test::XTracker::ParamCheck;

use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :delivery_item_status
    :flow_status
    :return_item_status
    :return_status
    :shipment_class
    :shipment_item_status
    :shipment_status
    :shipment_type
    :stock_transfer_status
    :stock_transfer_type
    :variant_type
);
use XTracker::Database::Channel qw( get_channel );
use Test::XTracker::Data::PackRouteTests qw(like_live_packlane_configuration);

use Data::Dump  qw( pp );

use parent 'NAP::Test::Class';

sub startup : Test(startup => 2) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    subtest 'test imports' => sub {
        use_ok('XTracker::Database', qw( :common ));
        use_ok('XTracker::Database::Product', 'request_product_sample' );
        use_ok('XTracker::Database::Sample', qw(
            get_sample_variant_with_stock
            get_sample_stock_qty
        ));
        use_ok('XTracker::Database::Delivery', qw(
            get_incomplete_delivery_items_by_variant
        ));
    };

    $self->{flow} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Fulfilment',
            'Test::XT::Flow::GoodsIn',
            'Test::XT::Flow::PrintStation',
            'Test::XT::Flow::Samples',
            'Test::XT::Flow::StockControl',
            'Test::XT::Flow::WMS',
        ],
    );

    $self->{schema} = $self->{flow}->schema;

    $self->{permissions} = [
        'Fulfilment/Dispatch',
        'Fulfilment/Packing',
        'Goods In/Returns In',
        'Goods In/Returns QC',
        'Goods In/Returns Faulty',
        'Stock Control/Sample',
        'Stock Control/Sample Adjustment',
    ];
    $self->{flow}->login_with_permissions({
        dept => 'Stock Control',
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => $self->{permissions},
        },
    });
}

sub setup : Tests( setup ) {
    my ( $self ) = @_;
    $self->SUPER::setup;
    $self->{flow}->errors_are_fatal(1);
}

=head2 test_sample_adjustment

     * get shipment to sample room
     * test badly formed product id
     * test badly formed variant id
     * test nonexistent product id
     * test nonexistent variant id
     * cannot return lost shipment

=cut

sub test_sample_adjustment : Tests {
    my ( $self ) = @_;

    my $channel = Test::XTracker::Data->any_channel;
    my $variant = (Test::XTracker::Data->grab_products({
        channel_id => $channel->id,
        force_create => 1,
    }))[1][0]->{variant};

    my $flow = $self->{flow};
    my $shipment;
    subtest 'get shipment to sample room' => sub {
        $shipment = $self->variant_ready_for_packing($channel->id, $variant->id);
        $self->pack_shipment( $channel->id, $shipment->id, $variant->sku );
        $self->dispatch_shipment( $shipment->id );
        # Move this into a separate sub?
        $flow->flow_mech__samples__stock_control_sample_goodsin;
        $flow->flow_mech__samples__stock_control_sample_goodsin__mark_received(
            $shipment->id, $channel->id );
    };

    # Stock Control/Sample Adjustment

    subtest 'test badly formed product id' => sub {
        $flow->mech__samples__sample_adjustment();
        $flow->catch_error(
            q{Please enter a valid PID},
            q{should show error when attempting to adjust invalid pid},
            mech__samples__sample_adjustment => {
                product_id => 'bogus',
            }
        );
    };

    subtest 'test badly formed variant id' => sub {
        $flow->mech__samples__sample_adjustment();
        $flow->catch_error(
            q{Please enter a valid variant ID},
            q{should show error when attempting to adjust invalid variant id},
            mech__samples__sample_adjustment => {
                variant_id => 'bogus',
            }
        );
    };

    my $schema = $self->{schema};
    subtest 'test nonexistent product id' => sub {
        my $nonexistent_product_id = $schema
            ->resultset('Public::Product')
            ->get_column('id')
            ->max + 1;
        $flow->mech__samples__sample_adjustment();
        $flow->catch_error(
            qq{Could not find PID $nonexistent_product_id},
            q{should show error when attempting to adjust nonexistent product id},
            mech__samples__sample_adjustment => {
                product_id => $nonexistent_product_id,
            }
        );
    };

    subtest 'test nonexistent variant id' => sub {
        my $nonexistent_variant_id = $schema
            ->resultset('Public::Variant')
            ->get_column('id')
            ->max + 1;
        $flow->mech__samples__sample_adjustment();
        $flow->catch_error(
            qq{Could not find variant $nonexistent_variant_id},
            q{should show error when attempting to adjust nonexistent variant id},
            mech__samples__sample_adjustment => {
                variant_id => $nonexistent_variant_id,
            }
        );
    };

    $flow->mech__samples__sample_adjustment({variant_id => $variant->id});
    is( $self->_mech_ready_to_lose_shipment_count( $channel->id ),
        1, 'found one ready-to-lose shipment' );

    my $location = $schema->resultset('Public::Location')->find({location => 'Sample Room'});
    $flow->catch_error(
        q{You must enter some text into the 'Notes' field},
        q{Cannot submit without 'Notes' field},
        mech__samples__lose_sample_submit => {
            channel_id => $channel->id, location_name => $location->location,
        }
    );

    my $notes;
    for my $test (
        # The first test - we have an item in the sample room, and we lose it.
        # We check that all the db updates are done properly
        {
            before_losing => sub { $notes = 'Lose in Sample Room'; },
            after_losing => sub {
                # Test the db has been updated correctly
                ok( !$variant->search_related('quantities', {
                        status_id => { q{!=} => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS }
                    })->count,
                    sprintf('there should be no sample quantity rows for variant %d', $variant->id)
                );
                ok( $shipment->discard_changes->is_lost,
                    sprintf( 'shipment_id %d should be lost', $shipment->id )
                ) || diag sprintf(q{... but it's %s}, $shipment->shipment_status->status);
                for ( $shipment->shipment_items->all ) {
                    ok( $_->is_lost, sprintf('shipment_item_id %d should be lost', $_->id) )
                        || diag sprintf(q{... but it's %s}, $_->shipment_item_status->status);
                    is( $_->lost_at_location->location, $location->location,
                        'should have set lost at location' );
                }
            },
        },
        # We return stock for the sample shipment, and we check we can still lose/find it
        {
            before_losing => sub {
                $notes = 'Lose after return stock';
                $self->mech_return_stock( $variant->id, $location->id, $channel->id );
                # Set $location in the parent scope
                $location = $schema->resultset('Public::Location')->find({location => 'Transfer Pending'})
            },
            after_losing => sub {
                my $return = $shipment->returns->single;
                is( $return->return_status_id, $RETURN_STATUS__LOST, q{return should be 'Lost'} );
                is( $return->return_items->single->return_item_status_id,
                    $RETURN_ITEM_STATUS__AWAITING_RETURN,
                    q{return item should be unchanged ('awaiting return')} );
                ok( $return->search_related('return_status_logs',
                    { return_status_id => $RETURN_STATUS__LOST },
                    { rows => 1 })
                    ->single,
                    q{return status for 'Lost' has been logged} );
            },
            after_finding => sub {
                my $return = $shipment->returns->single;
                is( $return->return_status_id, $RETURN_STATUS__AWAITING_RETURN,
                    q{return should be 'Awaiting Return'} );
                is( $return->return_items->single->return_item_status_id,
                    $RETURN_ITEM_STATUS__AWAITING_RETURN,
                    q{return item should be unchanged ('Awaiting Return')} );
                ok( $return->search_related('return_status_logs',
                    { return_status_id => $RETURN_STATUS__AWAITING_RETURN },
                    { rows => 1 })
                    ->single,
                    q{return status for 'Awaiting Return' has been logged} );
            },
        },
    ) {
        $_ && $_->() for $test->{before_losing};

        $flow->mech__samples__sample_adjustment({variant_id => $variant->id});
        # Ensure the sample is there
        is( $self->_mech_ready_to_lose_shipment_count( $channel->id ),
            1, 'found one ready-to-lose shipment' );

        # Lose the sample
        $self->mech_lose_sample_ok( $channel->id, $location->location, $notes );
        $_ && $_->() for $test->{after_losing};

        # Find the sample
        $self->mech_find_sample_ok( $_ ) for $shipment->shipment_items->get_column('id')->all;
        $_ && $_->() for $test->{after_finding};
    }

    # Check if we lose the sample we can't return it
    subtest cannot_return_lost_shipment => sub {
        $flow->mech__samples__sample_adjustment({variant_id => $variant->id});
        $self->mech_lose_sample_ok( $channel->id, $location->location, $notes );
        $flow->errors_are_fatal(0);
        $self->mech_bookin_return( $channel->id, $shipment->id, $variant->sku );
        $flow->mech->has_feedback_error_ok(qr{Cannot book in a return that is lost});
        $flow->errors_are_fatal(1);
    };
    # Find sample again so we can continue with the next tests
    $flow->mech__samples__sample_adjustment({variant_id => $variant->id});
    $self->mech_find_sample_ok( $_ ) for $shipment->shipment_items->get_column('id')->all;

    # Book in the return... for real this time
    $self->mech_bookin_return( $channel->id, $shipment->id, $variant->sku );

    # Check we can't lose it any more
    $flow->mech__samples__sample_adjustment({variant_id => $variant->id});
    is( $self->_mech_ready_to_lose_shipment_count( $channel->id ),
        0, 'no ready-to-lose shipments' );
}

sub mech_return_stock {
    my ($self,  $variant_id, $location_id, $channel_id ) = @_;

    my $flow = $self->{flow};
    $flow->flow_mech__stockcontrol__sample_return_stock__by_variant( $variant_id );
    $flow->flow_mech__stockcontrol__sample_return_submit({
        variant_id => $variant_id,
        location_id => $location_id,
        channel_id => $channel_id,
    });
    ok( $flow->mech->find_xpath(q{//h1[text() =~ /^Sample Stock - RMA/})->pop,
        'should find sample stock page that users print' );
}

sub mech_bookin_return {
    my ($self,  $channel_id, $shipment_id, $sku ) = @_;

    my $flow = $self->{flow};
    $flow->flow_mech__select_printer_station({
        section => 'GoodsIn',
        subsection => 'ReturnsIn',
        channel_id => $channel_id,
    });
    $flow->flow_mech__select_printer_station_submit;

    $flow->flow_mech__goodsin__returns_in;
    $flow->flow_mech__goodsin__returns_in_submit( $shipment_id );
    $flow->flow_mech__goodsin__returns_in__book_in( $sku );
    $flow->flow_mech__goodsin__returns_in__complete_book_in;
}

sub mech_find_sample_ok {
    my ( $self, $shipment_item_id ) = @_;
    my $flow = $self->{flow};
    $flow->mech__samples__find_sample_submit( $shipment_item_id );
    $flow->mech->has_feedback_success_ok( 'SKU marked as found' );
}

sub mech_lose_sample_ok {
    my ( $self, $channel_id, $location_name, $notes ) = @_;
    my $flow = $self->{flow};
    $flow->mech__samples__lose_sample_submit({
        channel_id    => $channel_id,
        location_name => $location_name,
        notes         => $notes,
    });
    $flow->mech->has_feedback_success_ok( 'SKU marked as lost' );
}

sub _mech_ready_to_lose_shipment_count {
    my ( $self, $channel_id ) = @_;
    return $self->{flow}->mech->find_xpath(qq{id('dispatched_samples_$channel_id')/tbody/tr})->size;
}

=head2 test_pack_sample_shipment

Happy path mech test to pack a sample shipment

=cut

sub test_pack_sample_shipment : Tests {
    my ( $self ) = @_;

    my $plt = Test::XTracker::Data::PackRouteTests->new({ schema => $self->schema });
    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    my $channel = Test::XTracker::Data->any_channel;
    my $variant = (Test::XTracker::Data->grab_products({
        channel_id => $channel->id,
    }))[1][0]->{variant};

    my $shipment;
    subtest 'shipment ready for packing' => sub {
        $shipment = $self->variant_ready_for_packing($channel->id, $variant->id)
    };

    # We put the container into a packlane so we can verify it has been removed from that
    # packlane after packing.
    my $container = $shipment->shipment_items->single->container;
    $container->choose_packlane();

    $self->pack_shipment( $channel->id, $shipment->id, $variant->sku );

    $container->discard_changes();
    is($container->pack_lane_id, undef, 'container has been removed from packlane');
}

sub variant_ready_for_packing {
    my ( $self, $channel_id, $variant_id ) = @_;
    my $shipment = $self->{flow}->db__samples__create_shipment({
        channel_id => $channel_id,
        variant_id => $variant_id,
    });
    my ( $container_id ) = Test::XT::Data::Container->get_unique_ids;
    for my $si ( $shipment->shipment_items ) {
        $si->set_selected( $APPLICATION_OPERATOR_ID );
        $si->pick_into( $container_id, $APPLICATION_OPERATOR_ID );
        ok( $si->is_picked, sprintf( 'shipment item %d is picked', $si->id ) );
        ok( $si->container_id, sprintf 'shipment item %d is in container',
            $si->id, $si->container_id );
    }
    return $shipment;
}

sub pack_shipment {
    my ( $self, $channel_id, $shipment_id, $sku ) = @_;

    my $flow = $self->{flow};
    $flow->mech__fulfilment__set_packing_station( $channel_id );

    # Begin packing shipment
    $flow->flow_mech__fulfilment__packing();
    $flow->flow_mech__fulfilment__packing_submit( $shipment_id );

    # Pack skus
    $flow->flow_mech__fulfilment__packing_packshipment_submit_sku( $sku );

    # Add sku to box
    $flow->flow_mech__fulfilment__packing_packshipment_submit_boxes(
        channel_id => $channel_id,
    );

    # Complete packing
    $flow->flow_mech__fulfilment__packing_packshipment_complete();
    $flow->mech->has_feedback_success_ok( qr/Shipment $shipment_id has now been packed\./ );
}

sub dispatch_shipment {
    my ( $self, $shipment_id ) = @_;

    my $flow = $self->{flow};
    $flow->flow_mech__fulfilment__dispatch
         ->flow_mech__fulfilment__dispatch_shipment( $shipment_id );
    $flow->mech->has_feedback_success_ok( qr{The shipment was successfully dispatched} );

}

=head2 test_return_sample_after_channel_transfer

Don't execute this test for non-IWS WMSes as we have two methods (i.e.
doing the channel transfer and the putaway) that vary significantly and
they currently don't work for this test.

This is a TODO for another day.

Tests:

    * channel transfer with lost shipment
    * putaway sample shipment

=cut

sub test_return_sample_after_channel_transfer : Tests {
    my $self = shift;

    return unless $iws_rollout_phase; # IWS only

    my $source_channel = Test::XTracker::Data->channel_for_nap;
    my $dest_channel = Test::XTracker::Data->channel_for_out;
    my $variant = (Test::XTracker::Data->grab_products({
        channel_id => $source_channel->id,
        force_create => 1,
    }))[1][0]->{variant};

    my $flow = $self->{flow};
    my $schema = $self->{schema};
    my $shipment;
    my $location = $schema->resultset('Public::Location')->find({location => 'Sample Room'});
    subtest 'channel_transfer_with_lost_shipment' => sub {
        $shipment = $self->variant_ready_for_packing($source_channel->id, $variant->id);
        $self->pack_shipment( $source_channel->id, $shipment->id, $variant->sku );
        $self->dispatch_shipment( $shipment->id );
        $flow->flow_mech__samples__stock_control_sample_goodsin;
        $flow->flow_mech__samples__stock_control_sample_goodsin__mark_received(
            $shipment->id, $source_channel->id );
        $flow->mech__samples__sample_adjustment({variant_id => $variant->id});

        # Lose the sample so our channel transfer doesn't fail
        $self->mech_lose_sample_ok(
            $source_channel->id, $location->location, 'Lose for channel transfer'
        );

        $flow->task__stock_control__channel_transfer({
            product           => $variant->product,
            channel_from      => $source_channel,
            channel_to        => $dest_channel,
            schema            => $schema,
            extra_permissions => $self->{permissions},
            # TODO: src_location and dst_location for dc2 transfers
        });
    };

    # Find the sample
    $flow->mech__samples__sample_adjustment({variant_id => $variant->id});
    my $shipment_item = $shipment->shipment_items->single;
    $self->mech_find_sample_ok( $shipment_item->id );

    my @quantities = $variant->search_related('quantities',
        { location_id => $location->id }
    )->all;
    is( scalar @quantities, 1, 'found 1 quantity' );
    is( $quantities[0]->channel_id, $source_channel->id,
        'found quantity in source channel id' );

    # Make sure we can return the shipment on the source channel
    $self->mech_return_stock( $variant->id, $location->id, $source_channel->id );

    $location = $schema->resultset('Public::Location')->find({location => 'Transfer Pending'});

    # Lose/find sample
    $flow->mech__samples__sample_adjustment({variant_id => $variant->id});
    $self->mech_lose_sample_ok(
        $source_channel->id, $location->location, 'Lose for channel transfer'
    );
    $self->mech_find_sample_ok( $shipment_item->id );
    @quantities = $variant->search_related('quantities',
        { location_id => $location->id }
    )->all;
    is( scalar @quantities, 1, 'found 1 quantity' );
    is( $quantities[0]->channel_id, $source_channel->id,
        'found quantity in source channel id' );

    my $return;
    subtest 'putaway_sample_shipment' => sub {
        $self->mech_bookin_return( $source_channel->id, $shipment->id, $variant->sku );
        $flow->mech->has_feedback_success_ok( 'Successfully booked in return' );

        $flow->flow_mech__select_printer_station({
            section => 'GoodsIn',
            subsection => 'ReturnsQC',
            channel_id => $source_channel->id,
        });
        $flow->flow_mech__select_printer_station_submit;

        # Get the shipment's return row
        $return = $shipment->returns->single;
        isa_ok( $return, 'XTracker::Schema::Result::Public::Return' );

        # Return is now booked in - visit Returns QC
        $flow->flow_mech__goodsin__returns_qc;

        # We display a warning that the product now lives on another channel,
        # so we need to make errors not fatal for just this one call
        $flow->errors_are_fatal(0);
        $flow->flow_mech__goodsin__returns_qc_submit( $return->rma_number );
        $flow->errors_are_fatal(1);
        $flow->flow_mech__goodsin__returns_qc__process;
        $flow->mech->has_feedback_success_ok('Quality control check completed successfully');

        # Get current quantity in main stock
        my $pre_putaway_quantity = $variant->quantity_on_channel( $dest_channel->id );

        # Get pgid
        my $sp_rs = $return->deliveries
                           ->related_resultset('delivery_items')
                           ->related_resultset('stock_processes');
        is( $sp_rs->count, 1, 'should have just one stock process' );

        # Test we put item away in destinatino channel
        if ( $iws_rollout_phase ) {
            $flow->flow_wms__send_stock_received(
                sp_group_rs => $sp_rs,
                operator    => $flow->mech->logged_in_as_object,
            );
            is( $variant->quantity_on_channel( $dest_channel->id ),
                $pre_putaway_quantity + 1,
                'item was putaway in destination channel' );
        }
        else {
            # TODO: DC2 Put away return
        }
    };
}

=head2 test_cant_cancel_after_packed

=cut

sub test_cant_cancel_after_packed : Tests {
    my ( $self ) = @_;

    my $flow = $self->{flow};

    my $channel = Test::XTracker::Data->any_channel;
    my $pid_hash = (Test::XTracker::Data->grab_products({
        channel_id => $channel->id,
    }))[1][0];
    my $shipment = $flow->db__samples__create_shipment({
        channel_id => $channel->id,
        variant_id => $pid_hash->{variant}->id,
    });
    $flow->flow_mech__stockcontrol__sample_requests;
    # Unfortunately $flow->mech->as_data is tricky to implement here as the
    # cell we need to check against is a form and the cell has no strings.
    # Should look at changing the way as_data works behind the scenes so it can
    # return a nodeset. So we're doing this manually using xpath.
    my $xpath = sprintf
        q{id('approved_table_%s')//tr[@id='%d']/td[last()]/form},
        $channel->business->config_section, $shipment->id;
    my $mech = $flow->mech;
    ok($mech->find_xpath($xpath)->pop,
        sprintf('we can cancel shipment %d', $shipment->id));

    # In order to test this second bit of functionality we need to cancel a
    # shipment that's already packed - we don't get a form to do that once it's
    # packed, hence the roundabout way of doing this

    # Open a new tab where we can still cancel the shipment
    $flow->flow_mech__stockcontrol__sample_requests;
    # Check user can see cancel button
    ok($mech->find_xpath($xpath)->pop,
        sprintf('can cancel packed shipment %d', $shipment->id));

    # Pack shipment
    $shipment->shipment_items->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED
    });

    # Submit the form
    $mech->request($mech->form_name('cancelShipment'.$shipment->id)->make_request);

    # Check user doesn't see cancel button
    ok(!$mech->find_xpath($xpath)->pop,
        sprintf('cannot cancel packed shipment %d', $shipment->id));
    $flow->errors_are_fatal(0);

    $mech->has_feedback_error_ok( map {
        qr{$_}
    } sprintf(
        q{Shipment %d cannot be cancelled as it has already been packed},
        $shipment->id
    ));
}

=head2 test_sample_required_parameters

Test that the functions are checking for required parameters

=cut

sub test_sample_required_parameters : Tests {
    my ( $self ) = @_;
    my $dbh = $self->{schema}->storage->dbh;

    my $param_check = Test::XTracker::ParamCheck->new();

    $param_check->check_for_params(  \&get_sample_variant_with_stock,
                        'get_sample_variant_with_stock',
                        [ $dbh, 12345, { 12 => '1231231' }, [ 12 ], 1231231, { name => 'test' } ],
                        [ "No DBH Connection Passed", "No Product Id Passed",
                            "No Variant HASH Passed", "No Variant Sizes Passed",
                            "No Ideal Size VID Passed", "No Sales Channel Ref Passed or isn't a HASH Ref",
                        ],
                        [ undef, undef, undef, undef, undef, 1 ],
                        [ undef, undef, undef, undef, undef, "No Sales Channel Ref Passed or isn't a HASH Ref" ],
                    );
    $param_check->check_for_params(  \&get_sample_stock_qty,
                        'get_sample_stock_qty',
                        [ $dbh, { type => 'product', id => 1, channel_id => 1 } ],
                        [ "No DBH Connection Passed", "No ARGS Hash Ref Passed" ],
                        [ undef, 2 ],
                        [ undef, "No ARGS Hash Ref Passed" ]
                    );
    $param_check->check_for_hash_params(  \&get_sample_stock_qty,
                        'get_sample_stock_qty',
                        [ $dbh, { type => 'product', id => 1, channel_id => 1 } ],
                        [ "No DBH Connection Passed", {
                                type        => "No Type Specified in ARGS",
                                id          => "No ID Specified in ARGS",
                                channel_id  => "No Channel Id Specified in ARGS",
                            } ],
                        [ undef, { type => 'fred' } ],
                        [ undef, { type => "Invalid Type Specified in ARGS" } ]
                    );
    $param_check->check_for_params(  \&get_incomplete_delivery_items_by_variant,
                        'get_incomplete_delivery_items_by_variant',
                        [ $dbh, 123456, 1 ],
                        [ "No DBH Handler passed in",
                            "No variant_id defined for get_incomplete_delivery_items_by_variant()",
                            "No channel_id defined for get_incomplete_delivery_items_by_variant()",
                        ],
                    );
}

=head2 test_stock_checks

This tests the functions used to do the stock checks

=cut

sub test_stock_checks : Tests {
    my ( $self ) = @_;

    my $schema = $self->{schema};
    my $dbh    = $schema->storage->dbh;

    my $channel    = Test::XTracker::Data->any_channel;
    my $channel_id = $channel->id;
    my (undef,$product) = Test::XTracker::Data->grab_products( {
        channel_id => $channel_id,
        force_create => 1,
    } );

    my $tmp;
    my $expected;

    note "TESTING Stock Check Functions";

    my $variant_id  = $product->[0]{variant_id};
    my $product_id  = $product->[0]{pid};

    note "Testing 'get_sample_stock_qty' func";
    my $location= $schema->resultset('Public::Location')->search( {
        'location_allowed_statuses.status_id' => $FLOW_STATUS__SAMPLE__STOCK_STATUS
    }, {
        rows => 1,
        join => [ 'location_allowed_statuses' ],
    } )->first;

    # add some quantity of stock for the variant in the Sample Room
    my $new_qty = $schema->resultset('Public::Quantity')->create( {
        variant_id      => $variant_id,
        location_id     => $location->id,
        quantity        => 5,
        channel_id      => $channel_id,
        status_id       => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
    } );
    # use variant first
    $tmp    = get_sample_stock_qty( $dbh, { type => 'variant', id => $variant_id, channel_id => $channel_id } );
    isa_ok( $tmp, 'HASH', "Return from func" );
    ok( exists $tmp->{ $variant_id }, "Variant Id found in HASH" );
    cmp_ok( $tmp->{ $variant_id }, '==', 5, "Quantity for Variant as expected" );

    # now use product should get the same response
    $expected= get_sample_stock_qty( $dbh, { type => 'product', id => $product_id, channel_id => $channel_id } );
    is_deeply( $expected, $tmp, "Return for Product same as Variant" );
    cmp_ok( $expected->{ $variant_id }, '==', 5, "Quantity for Variant as expected" );

    # Adding a Stock Transfer Request
    $self->{flow}
        ->db__samples__create_stock_transfer( $channel_id, $variant_id );
    $tmp    = get_sample_stock_qty( $dbh, { type => 'variant', id => $variant_id, channel_id => $channel_id } );
    cmp_ok( $tmp->{ $variant_id }, '==', 6, "Quantity Returned after Stock Transfer Request as expected" );

    # Adding a Stock Transfer Approved
    $self->{flow}->db__samples__create_shipment({
        channel_id => $channel_id,
        variant_id => $variant_id,
    });
    $tmp    = get_sample_stock_qty( $dbh, { type => 'variant', id => $variant_id, channel_id => $channel_id } );
    cmp_ok( $tmp->{ $variant_id }, '==', 7, "Quantity Returned after Stock Transfer Approved as expected" );

    note "Testing 'get_incomplete_delivery_items_by_variant' func";
    $schema->txn_do( sub {
        my @ldisoi  = $schema->resultset('Public::LinkDeliveryItemStockOrderItem')
                                ->search(
                                    {
                                        'stock_order_item.variant_id'   => $variant_id,
                                        'delivery_item.status_id'       => { '<' => $DELIVERY_ITEM_STATUS__COMPLETE },
                                    },
                                    {
                                        join    => [ qw( stock_order_item delivery_item ) ],
                                    }
                                )->all;
        # update all current delivery items for variant to Complete
        $_->delivery_item->update({ status_id => $DELIVERY_ITEM_STATUS__COMPLETE })
            for @ldisoi;

        # create a purchase order
        my $po      = Test::XTracker::Data->create_dummy_po( $product_id, $variant_id, $channel_id );
        my $deliv   = Test::XTracker::Data->create_delivery_for_so( $po->stock_orders->first );
        my $dlv_itm = $deliv->delivery_items->first;

        # nothing should be found first;
        $tmp    = get_incomplete_delivery_items_by_variant( $dbh, $variant_id, $channel_id );
        ok( !defined $tmp, "Nothing returned as expected" );

        # add a packing slip value
        $dlv_itm->update( { packing_slip => 1 } );
        $tmp    = get_incomplete_delivery_items_by_variant( $dbh, $variant_id, $channel_id );
        isa_ok( $tmp, 'HASH', "Return Value" );
        ok( exists( $tmp->{ $dlv_itm->id } ), "Found Delivery Item after Packing Slip Qty Set" );

        # clear packing slip and add quantity
        $dlv_itm->update( { packing_slip => 0, quantity => 1 } );
        $tmp    = get_incomplete_delivery_items_by_variant( $dbh, $variant_id, $channel_id );
        isa_ok( $tmp, 'HASH', "Return Value" );
        ok( exists( $tmp->{ $dlv_itm->id } ), "Found Delivery Item after Quantity Set" );

        # set packing slip and quantity
        $dlv_itm->update( { packing_slip => 1, quantity => 1 } );
        $tmp    = get_incomplete_delivery_items_by_variant( $dbh, $variant_id, $channel_id );
        isa_ok( $tmp, 'HASH', "Return Value" );
        ok( exists( $tmp->{ $dlv_itm->id } ), "Found Delivery Item after Both Packing Slip & Quantity Set" );

        # complete delivery item status, should return nothing
        $dlv_itm->update( { status_id => $DELIVERY_ITEM_STATUS__COMPLETE } );
        $tmp    = get_incomplete_delivery_items_by_variant( $dbh, $variant_id, $channel_id );
        ok( !defined $tmp, "Nothing returned when status is 'Completed' as expected" );

        $schema->txn_rollback();
    } );
}

=head2 test_sample_request

Tests functions used to make a sample request

=cut

sub test_sample_request : Tests {
    my ( $self ) = @_;

    my $schema = $self->{schema};
    my $dbh    = $schema->storage->dbh;

    my $channels    = {
        map { $_->id => { id => $_->id, config_section => $_->business->config_section } }
            $schema->resultset('Public::Channel')->all
    };
    my $channel_id  = (sort { $a <=> $b } keys %{ $channels })[0];
    my $channel     = $schema->resultset('Public::Channel')->find( $channel_id );
    my $channel_ref = get_channel($dbh, $channel_id);
    my $tmp;
    my $expected;
    my $nap_channel;
    my $out_channel;
    my $mrp_channel;

    # get NAP & OUTNET channels
    for my $channel ( keys %{ $channels } ) {
        if ( $channels->{ $channel }{config_section} eq "OUTNET" ) {
            $out_channel    = $channels->{ $channel };
        }
        if ( $channels->{ $channel }{config_section} eq "NAP" ) {
            $nap_channel    = $channels->{ $channel };
        }
        if ( $channels->{ $channel }{config_section} eq "MRP" ) {
            $mrp_channel    = $channels->{ $channel };
        }
    }

    note "TESTING Sample Request Functions";
    my (undef,$pids) = Test::XTracker::Data->grab_products({
        channel => $channel,
        how_many => 1,
        how_many_variants => 6,
    });
    cmp_ok( @{ $pids }, '==', 1, "Found a PID with at least 6 variants" );
    my $product = $pids->[0]{product};

    my @variants = $schema->resultset('Public::Variant')->search({
        'me.product_id' => $product->id,
        'me.type_id'    => $VARIANT_TYPE__STOCK,
    },{
        join            => 'product',
        order_by        => 'me.size_id ASC',
    })->all;

    note "Testing 'get_sample_variant_with_stock' func";
    $schema->txn_do( sub {
        my %var_hash;
        my @var_sizes;
        my @var_ids;

        # clear existing stock first, stock transfer & delivery items
        _clear_out_stock_stuff( $schema, \@variants, \%var_hash, \@var_sizes, \@var_ids );

        $tmp    = get_sample_variant_with_stock( $dbh, $product->id, \%var_hash, \@var_sizes, $variants[2]->id, $channel_ref );
        cmp_ok( $tmp, '==', $variants[2]->id, "With No Stock Variant Id as expected" );

        # This has been intermittently failing. It's a good test, but it's
        # laid out in a confusing way, and with no documentation. Hence:
        #
        # get_sample_variant_with_stock() looks for alternatives to the
        # suggested size where possible, in the order +1,-1,+2,-2...
        #
        # Thus, if we have a list of variants, ordered by size, and we
        # request the one that's index n, it should try, in order:
        # n, n+1, n-1, n+2, n-2, n+3
        #
        # We have our variants in @variants. Our test set is the first 6.
        # Our ideal item is the third one, which is index 2. First let's
        # generate our expected search sequence:
        my $n = 2;
        my @preference_sequence = ( $n, $n+1, $n-1, $n+2, $n-2, $n+3 );

        my %preference_sequence_ref = map {
            my $index = $_;

            # Calculate this as an offset to n
            my $offset = $index - $n;
            $offset = "+$offset" if $offset > 0;

            # Look up the variant id
            ( $index, [ $offset, $variants[ $index ]->id, $variants[ $index ]->size_id ] );
        } @preference_sequence;

        # Let the user know what we're doing
        note "Preference sequence: " . join ', ', map {
            'n' . ($preference_sequence_ref{ $_ }->[0] || '')
        } @preference_sequence;
        note "Variants: (offset from n, id, size_id)";
        note pp( \%preference_sequence_ref );

        my $target_variant_id = $variants[ $n ]->id;

        # Assuming there is 0 quantity for each variant, we should be able
        # to work backwards through the preference sequence, adding a
        # quantity, and getting that item back.
        note "Working through preference sequence.";
        note "n is $n, which is [" . $variants[$n]->id . ']';

        for my $index ( reverse @preference_sequence ) {
            my ( $offset, $variant_id ) = @{$preference_sequence_ref{ $index }};

            # 100,000 may seem excessive, but some items in the DB have
            # negative quantities, so the test was intermittently failing
            # when it found some like that.
            Test::XTracker::Data->set_product_stock({
                variant_id => $variant_id,
                quantity   => 100_000,
                channel_id => $channel_id
            });

            my $received_variant_id = get_sample_variant_with_stock(
                $dbh, $product->id, \%var_hash, \@var_sizes,
                $target_variant_id, $channel_ref
            );

            if ( $received_variant_id == $variant_id ) {
                pass( "Offset $offset returned [$variant_id]" );
            # If that didn't pass, find out where in the sequence the actual
            # returned id is
            } else {
                # Find the index of it
                my $incorrect_index;
                my $variant_index = 0;
                for my $variant ( @variants ) {
                    if ( $received_variant_id eq $variant->id ) {
                        $incorrect_index = $variant_index;
                    }
                    $variant_index++;
                }
                if ( ! defined $incorrect_index ) {
                    fail("Unknown variant id [$received_variant_id] received");
                } else {
                    my $incorrect_offset = $incorrect_index - $n;
                    $incorrect_offset = "+$incorrect_offset" if $incorrect_offset > 0;
                    fail("Expected variant offset $offset [$variant_id], " .
                        "but received $incorrect_offset [$received_variant_id]");
                }
            }
        }

        # clear the stock down again
        my $qty = $schema->resultset('Public::Quantity')->search( { variant_id => { 'in' => \@var_ids } } );
        $qty->delete        if ( defined $qty );

        # now check we find the right variant with stock
        # in the sample room and then that has had stock delivered
        my @lsts    = $schema->resultset('Public::LinkStockTransferShipment')->search( undef, { rows => 1 } )->all;
        my $location= $schema->resultset('Public::Location')->search( {
            'location_allowed_statuses.status_id' => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        }, {
            rows => 1,
            join => [ 'location_allowed_statuses' ],
        } )->first;

        # add some quantity of stock for the 5th variant in the Sample Room
        my $new_qty = $schema->resultset('Public::Quantity')->create( {
            variant_id      => $variants[4]->id,
            location_id     => $location->id,
            quantity        => 5,
            channel_id      => $channel_id,
            status_id       => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        } );
        $tmp    = get_sample_variant_with_stock( $dbh, $product->id, \%var_hash, \@var_sizes, $variants[2]->id, $channel_ref );
        cmp_ok( $tmp, '==', $variants[4]->id, "Stock in the Sample room for the 5th Variant returns the 5th Variant Id" );

        # create a purchase order and incomplete delivery for the 2nd variant
        my $po      = Test::XTracker::Data->create_dummy_po( $product->id, $variants[1]->id, $channel_id );
        my $deliv   = Test::XTracker::Data->create_delivery_for_so( $po->stock_orders->first );
        my $dlv_itm = $deliv->delivery_items->first->update( { packing_slip => 1} );        # give it some quantity
        $tmp    = get_sample_variant_with_stock( $dbh, $product->id, \%var_hash, \@var_sizes, $variants[2]->id, $channel_ref );
        cmp_ok( $tmp, '==', $variants[1]->id, "Incomplete Delivery for the 2nd Variant returns the 2nd Variant Id" );

        $schema->txn_rollback();
    } );

    note "Testing 'request_product_sample' func";
    $schema->txn_do( sub {

        # get some data for later use
        my $prdtyp_defsizes = $schema->resultset('Public::SampleProductTypeDefaultSize');
        my $prdcls_defsizes = $schema->resultset('Public::SampleClassificationDefaultSize');
        my $scheme_defsizes = $schema->resultset('Public::SampleSizeSchemeDefaultSize');

        my $clothing_class  = $schema->resultset('Public::Classification')->search( { 'me.classification' => 'Clothing' } )->first;
        my $lingerie_prdtyp = $schema->resultset('Public::ProductType')->search( { 'me.product_type' => 'Lingerie' } )->first;

        my $size_rs = $schema->resultset('Public::Size');
        my @nap_prdtyp_sizes= $size_rs->search( { 'me.size' => { 'IN' => [ qw( 1 34B ) ] } } )->all;
        my @nap_class_sizes = $size_rs->search( { 'me.size' => { 'IN' => [ 'x small', 'small' ] } } )->all;

        my @out_prdtyp_sizes= $size_rs->search( { 'me.size' => { 'IN' => [ qw( 1 34C ) ] } } )->all;
        my @out_class_sizes = $size_rs->search( { 'me.size' => { 'IN' => [ 'small' ] } } )->all;

        my @mrp_scheme_sizes= $size_rs->search( { 'me.size' => { 'IN' => [ qw( L ) ] } } )->all;

        my @ling_var_sizes  = $size_rs->search( { 'me.size' => { 'IN' => [ qw( 32B 34B 36B 32C 34C 36C ) ] } }, { order_by => 'me.id ASC' } )->all;
        my @cloth_var_sizes = $size_rs->search( { 'me.size' => { 'IN' => [ 'xx small', 'x small', 'small', 'medium', 'large', 'x large' ] } }, { order_by => 'me.id ASC' } )->all;
        my @socks_var_sizes = $size_rs->search( { 'me.size' => { 'IN' => [ 'S', 'M', 'L', 'XL' ] } }, { order_by => 'me.id ASC' } )->all;

        # set-up sizes used to set the variants to initially to make sure
        # none of the current ones clash with the test sizes that will be used
        my @test_sizes      = map { $_->id } (
            @nap_prdtyp_sizes,
            @nap_class_sizes,
            @out_prdtyp_sizes,
            @out_class_sizes,
            @ling_var_sizes,
            @cloth_var_sizes,
            @mrp_scheme_sizes,
            @socks_var_sizes,
        );
        my @tmp_sizes       = $size_rs->search( { 'me.id' => { 'NOT IN' => \@test_sizes } }, { order_by => 'me.id ASC', rows => scalar( @variants ) } )->all;
        foreach ( 0..$#variants ) {
            $variants[ $_ ]->update( { size_id => $tmp_sizes[ $_ ]->id } );
        }

        my $one_size;
        my %var_hash;
        my @var_sizes;
        my @var_ids;

        # change the Classification & Product Type for the product
        $product->update( { classification_id => $clothing_class->id, product_type_id => $lingerie_prdtyp->id } );

        # clear existing stock first, stock transfer & delivery items
        _clear_out_stock_stuff( $schema, \@variants, \%var_hash, \@var_sizes, \@var_ids );

        my $stck_xfer_rs    = $schema->resultset('Public::StockTransfer')->search( { 'me.variant_id' => { 'IN' => \@var_ids } }, { order_by => 'me.id DESC' } );

        # clear all product types and classifications should
        # find nearest size for NAP & middle size for OUTNET and MRP
        $prdtyp_defsizes->delete;
        $prdcls_defsizes->delete;
        $scheme_defsizes->delete;

        # test NAP
        if ( $nap_channel->{id} ) {
            request_product_sample( $dbh, $product->id, $nap_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            cmp_ok( $tmp->variant_id, '==', $variants[0]->id, "NAP Variant Selected is Smallest Size" );
            # as it's the first time check the rest of the Stock Transfer record got created properly
            cmp_ok( $tmp->channel_id, '==', $nap_channel->{id}, "Stock Transfer Channel Id as expected" );
            cmp_ok( $tmp->type_id, '==', 8, "Stock Transfer Type Id set as 'Upload' as expected" );
            cmp_ok( $tmp->status_id, '==', 1, "Stock Transfer Status Id set as 'Requested' as expected" );
        }

        # test MRP
        if ( $mrp_channel ) {
            request_product_sample( $dbh, $product->id, $mrp_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            cmp_ok( $tmp->variant_id, '==', $variants[0]->id, "MRP Variant Selected is Smallest Size" );
            # as it's the first time check the rest of the Stock Transfer record got created properly
            cmp_ok( $tmp->channel_id, '==', $mrp_channel->{id}, "Stock Transfer Channel Id as expected" );
            cmp_ok( $tmp->type_id, '==', 8, "Stock Transfer Type Id set as 'Upload' as expected" );
            cmp_ok( $tmp->status_id, '==', 1, "Stock Transfer Status Id set as 'Requested' as expected" );
        }

        # test OUTNET, previous Stock Transfer record shouldn't matter as it's for a different Sales Channel
        if ( $out_channel ) {
            my $idx = int( (scalar @variants) / 2 );
            request_product_sample( $dbh, $product->id, $out_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            cmp_ok( $tmp->variant_id, '==', $variants[ $idx ]->id, "OUTNET Variant Selected is Middle Size" );
            cmp_ok( $tmp->channel_id, '==', $out_channel->{id}, "OUTNET Stock Transfer Channel Id as expected" );
        }

        # now try with a one size product, should return the only size
        # NAP first
        if ( $nap_channel->{id} ) {
            $one_size   = _find_one_size_product( $schema, $nap_channel->{id} );
            _clear_out_stock_stuff( $schema, [ $one_size->[0]->variants->all ], \%var_hash, \@var_sizes, \@var_ids );
            request_product_sample( $dbh, $one_size->[0]->id, $nap_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            cmp_ok( $tmp->variant_id, '==', $one_size->[0]->variants->first->id, "One Size, NAP Variant Selected is Only Variant" );
        }
        # OUTNET second
        if ( $out_channel ) {
            $one_size   = _find_one_size_product( $schema, $out_channel->{id} );
            _clear_out_stock_stuff( $schema, [ $one_size->[0]->variants->all ], \%var_hash, \@var_sizes, \@var_ids );
            request_product_sample( $dbh, $one_size->[0]->id, $out_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            cmp_ok( $tmp->variant_id, '==', $one_size->[0]->variants->first->id, "One Size, OUTNET Variant Selected is Only Variant" );
        }

        # now try with stock added, NAP should still be smalles,
        # OUTNET should return the one with stock
        _clear_out_stock_stuff( $schema, \@variants, \%var_hash, \@var_sizes, \@var_ids );
        Test::XTracker::Data->set_product_stock( { variant_id => $variants[3]->id, quantity => 5, channel_id => $nap_channel->{id} } );
        if ( $out_channel ) {
            Test::XTracker::Data->set_product_stock( { variant_id => $variants[5]->id, quantity => 5, channel_id => $out_channel->{id} } );
        }
        # NAP first
        request_product_sample( $dbh, $product->id, $nap_channel->{id} );
        $tmp    = $stck_xfer_rs->reset->first;
        cmp_ok( $tmp->variant_id, '==', $variants[0]->id, "With Stock NAP Variant Selected is Smallest Size" );
        # OUTNET first
        if ( $out_channel ) {
            request_product_sample( $dbh, $product->id, $out_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            cmp_ok( $tmp->variant_id, '==', $variants[5]->id, "With Stock OUTNET Variant Selected is the one With Stock" );
        }

        # check that classification ideal sizes are picked up
        _clear_out_stock_stuff( $schema, \@variants, \%var_hash, \@var_sizes, \@var_ids );
        if ( $nap_channel->{id} ) {
            foreach ( @nap_class_sizes ) { # NAP
                $prdcls_defsizes->create( { classification_id => $clothing_class->id, size_id => $_->id, channel_id => $nap_channel->{id} } );
            }
        }
        if ( $out_channel ) {
            foreach ( @out_class_sizes ) { # OUTNET
                $prdcls_defsizes->create( { classification_id => $clothing_class->id, size_id => $_->id, channel_id => $out_channel->{id} } );
            }
        }
        # change the Variants Sizes to match test data
        foreach ( 0..5 ) {
            $variants[ $_ ]->update( { size_id => $cloth_var_sizes[ $_ ]->id } );
        }
        # NAP first
        if ( $nap_channel->{id} ) {
            request_product_sample( $dbh, $product->id, $nap_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            is( $tmp->variant->size->size, 'x small', "NAP Classification ideal size chosen" );
        }
        # OUTNET second
        if ( $out_channel ) {
            request_product_sample( $dbh, $product->id, $out_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            is( $tmp->variant->size->size, 'small', "OUTNET Classification ideal size chosen" );
        }

        # now do the same again but with product types that should be ignored
        _clear_out_stock_stuff( $schema, \@variants, \%var_hash, \@var_sizes, \@var_ids );
        if ( $nap_channel->{id} ) {
            foreach ( @nap_prdtyp_sizes ) { # NAP
                $prdtyp_defsizes->create( { product_type_id => $lingerie_prdtyp->id, size_id => $_->id, channel_id => $nap_channel->{id} } );
            }
        }
        if ( $out_channel ) {
            foreach ( @out_prdtyp_sizes ) { # OUTNET
                $prdtyp_defsizes->create( { product_type_id => $lingerie_prdtyp->id, size_id => $_->id, channel_id => $out_channel->{id} } );
            }
        }
        # NAP first
        if ( $nap_channel->{id} ) {
            request_product_sample( $dbh, $product->id, $nap_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            is( $tmp->variant->size->size, 'x small', "Ignore Product Type, NAP Classification ideal size chosen" );
        }
        # OUTNET second
        if ( $out_channel ) {
            request_product_sample( $dbh, $product->id, $out_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            is( $tmp->variant->size->size, 'small', "Ignore Product Type, OUTNET Classification ideal size chosen" );
        }

        # check that product type ideal sizes are picked up
        _clear_out_stock_stuff( $schema, \@variants, \%var_hash, \@var_sizes, \@var_ids );
        # change the Variants Sizes to match test data
        foreach ( 0..5 ) {
            $variants[ $_ ]->update( { size_id => $ling_var_sizes[ $_ ]->id } );
        }
        # NAP first
        if ( $nap_channel->{id} ) {
            request_product_sample( $dbh, $product->id, $nap_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            is( $tmp->variant->size->size, '34B', "NAP Product Type ideal size chosen" );
        }
        # OUTNET second
        if ( $out_channel ) {
            request_product_sample( $dbh, $product->id, $out_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            is( $tmp->variant->size->size, '34C', "OUTNET Product Type ideal size chosen" );
        }

        # now do the same again but with classifications that should be ignored
        _clear_out_stock_stuff( $schema, \@variants, \%var_hash, \@var_sizes, \@var_ids );
        # set-up classification with appropriate sizes which should get ignored
        # for each Sales Channel
        $prdcls_defsizes->delete;
        foreach ( $nap_channel->{id}, ($out_channel ? $out_channel->{id} : ()) ) {
            $prdcls_defsizes->create( { classification_id => $clothing_class->id, size_id => $ling_var_sizes[0]->id, channel_id => $_ } );
            $prdcls_defsizes->create( { classification_id => $clothing_class->id, size_id => $ling_var_sizes[5]->id, channel_id => $_ } );
        }
        # NAP first
        if ( $nap_channel->{id} ) {
            request_product_sample( $dbh, $product->id, $nap_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            is( $tmp->variant->size->size, '34B', "Ignore Classification, NAP Product Type ideal size chosen" );
        }
        # OUTNET second
        if ( $out_channel ) {
            request_product_sample( $dbh, $product->id, $out_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            is( $tmp->variant->size->size, '34C', "Ignore Classification, OUTNET Product Type ideal size chosen" );
        }

        # add some stock to another size for each Sales Channel
        # NAP should still return ideal size, OUTNET should return the
        # one with stock, also OUTNET should ignore NAP's stock
        _clear_out_stock_stuff( $schema, \@variants, \%var_hash, \@var_sizes, \@var_ids );
        Test::XTracker::Data->set_product_stock( { variant_id => $variants[3]->id, quantity => 5, channel_id => $nap_channel->{id} } );
        if ( $out_channel ) {
            Test::XTracker::Data->set_product_stock( { variant_id => $variants[2]->id, quantity => 5, channel_id => $out_channel->{id} } );
        }
        # NAP first
        if ( $nap_channel->{id} ) {
            request_product_sample( $dbh, $product->id, $nap_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            is( $tmp->variant->size->size, '34B', "With Stock, NAP ideal size chosen" );
        }
        # OUTNET second
        if ( $out_channel ) {
            request_product_sample( $dbh, $product->id, $out_channel->{id} );
            $tmp    = $stck_xfer_rs->reset->first;
            is( $tmp->variant->size->size, '36B', "With Stock, OUTNET size with stock chosen" );
        }

        $schema->txn_rollback();
    } );
}

#--------------------------------------------------------------

# this clears out stock, delivery items & stock transfer requests
# for a list of variants, it also builds a HASH of variants indexed
# by size, an arrays of variant sizes and an array of variant ids
sub _clear_out_stock_stuff {

    my ( $schema, $variants, $var_hash, $var_sizes, $var_ids )   = @_;

    foreach ( @{ $variants } ) {
        # clear any stock level
        my $qty = $schema->resultset('Public::Quantity')->search( { variant_id => $_->id } );
        $qty->delete                            if ( defined $qty );
        # clear any pending stock transfers to the sample room
        my $st  = $schema->resultset('Public::StockTransfer')->search( { variant_id => $_->id } );
        $st->update( { status_id => 3 } )       if ( defined $st );     # update them to 'Cancelled' status
        # clear any deliveries for variant
        my @ldisoi  = $schema->resultset('Public::LinkDeliveryItemStockOrderItem')
                                ->search(
                                    {
                                        'stock_order_item.variant_id'   => $_->id,
                                        'delivery_item.status_id'       => { '<' => $DELIVERY_ITEM_STATUS__COMPLETE },
                                    },
                                    {
                                        join    => [ qw( stock_order_item delivery_item ) ],
                                    }
                                )->all;
        # update all current delivery items for variant to Complete
        $_->delivery_item->update({ status_id => $DELIVERY_ITEM_STATUS__COMPLETE })
            for @ldisoi;

        # set-up vars for the test while we're at it
        $var_hash->{ $_->size_id }  = $_->id;
        push @{ $var_sizes }, $_->size_id;
        push @{ $var_ids }, $_->id;
    }

    return;
}

# this finds a product with a 'One size' variant
sub _find_one_size_product {
    my $schema      = shift;
    my $channel_id  = shift;
    my $num_pids    = shift || 1;

    my (undef,$single_variant_pids) = Test::XTracker::Data->grab_products({
        channel_id => $channel_id,
        how_many => $num_pids,
        how_many_variants => { '=' => 1 },
    });

    return [
        map { $schema->resultset('Public::Product')->find($_->{pid}) } @$single_variant_pids
    ];
}

=head2 test_sample_return_faulty

=over

=item Create a sample shipment and place it in the Sample Room

=item Demand a return

=item Book it in

=item Mark it as faulty

=item Accept that the item is faulty at Returns Faulty

=item Check it can't be returned to customer

=item Return the item to stock

=back

=cut

sub test_sample_faulty_return : Tests {
    my $self = shift;

    # Create a sample shipment and place it in the sample room
    my $flow = $self->{flow};
    my $shipment = $flow->db__samples__create_shipment({
        shipment => { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED },
        shipment_item => {
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED
        },
    });
    ok( $shipment, 'created shipment ' . $shipment->id );

    my $variant = $shipment->shipment_items->related_resultset('variant')->single;
    my $channel = $shipment->get_channel;
    my $sample_room = $self->{schema}
        ->resultset('Public::Location')->find({location => 'Sample Room'});
    $variant->create_related(quantities => {
        location_id => $sample_room->id,
        quantity => 1,
        channel_id => $channel->id,
        status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
    });

    # Demand sample return the item!
    $self->mech_return_stock( $variant->id, $sample_room->id, $channel->id );

    # Ahhh, my precioussss...
    $self->mech_bookin_return( $channel->id, $shipment->id, $variant->sku );

    # Boring printer malarkey
    $flow->task__set_printer_station( 'GoodsIn', 'ReturnsQC' );

    # Found my return!
    isa_ok( my $return = $shipment->returns->single,
        'XTracker::Schema::Result::Public::Return' );

    # OH NO! IT'S FAULTY!
    $flow->flow_mech__goodsin__returns_qc;
    $flow->flow_mech__goodsin__returns_qc_submit( $return->rma_number );
    $flow->flow_mech__goodsin__returns_qc__process({decision => 'fail'});
    $flow->mech->has_feedback_success_ok('Quality control check completed successfully');

    # Resign yourself to the truth, and accept the item's faultiness. Samples
    # will have to pay!
    my $stock_process = $return->return_items->single->incomplete_stock_process;
    $flow->flow_mech__goodsin__returns_faulty;
    $flow->flow_mech__goodsin__returns_faulty_submit($stock_process->group_id);
    $flow->flow_mech__goodsin__returns_faulty_decision('accept');

    # Just because it's faulty doesn't mean samples get their item back! The
    # cheek! Let's check and make sure that can't happen.
    my $el = $flow->mech->find_xpath(
        q{//form[@name='faultyReturn']/table//input[@type='radio' and @value='rtc']}
    )->pop;
    ok( !$el, q{'Return to Customer' isn't available for sample shipment returns} );

    # This step is here just to complete the returns faulty page. To be honest
    # I don't understand how a faulty item can get sent back to stock, but I
    # don't make the rules.
    lives_ok(
        sub { $flow->flow_mech__goodsin__returns_faulty_process('return to stock'); },
        'can return sample shipment to stock'
    );
}
