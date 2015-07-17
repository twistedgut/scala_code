package Test::XTracker::Schema::ResultSet::Public::Quantity;

use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';

    with 'Test::Role::WithSchema';
    with 'Test::XT::Data::RTV';
    with 'XTracker::Role::WithIWSRolloutPhase';
    with 'XTracker::Role::WithPRLs';
};

use Test::XT::Data;
use Test::XTracker::Data;

use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw(
    :flow_status
    :rma_request_detail_status
);

sub startup :Tests {
    my $self = shift;

    $self->SUPER::startup();

    $self->{framework} = Test::XT::Data->new_with_traits(
        traits => [qw/
            Test::XT::Data::Location
            Test::XT::Data::Quantity
        /],
    );
    $self->{framework}->data__location__destroy_test_locations;

    @{$self}{qw/channel variant/} = map {
        $_->[0], $_->[1][0]{variant}
    } [Test::XTracker::Data->grab_products({ force_create => 1 })];
}

sub test_move_stock : Tests {
    my $self = shift;

    my $framework = $self->{framework};
    my $schema = $framework->schema;
    my $variant = $self->{variant};

    # Create locations that accept a status we'd expect to have matching rtv
    # quantity statuses in
    for (
        [ 'main stock' => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS, 0, 0 ],
        [ 'rtv goods in' => $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS, 1, 0 ],
        [ 'stock marked for rtv' => $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS, 1, 1 ],
    ) {
        my ( $test_for_status, $stock_status_id, $with_rtv_quantity, $marked_for_rtv ) = @$_;
        subtest "test $test_for_status scenarios" => sub {
            my ( $from_location, $to_location ) = map {
                $framework->schema->resultset('Public::Location')->find({location => $_})
            } @{$framework->data__location__create_new_locations({
                quantity => 2, allowed_types => [$stock_status_id],
            })};

            # Create quantity in the quantity table
            my $total_quantity = 3;
            my $from_quantity = $framework->data__quantity__insert_quantity({
                quantity => $total_quantity,
                location_name => $from_location->location,
                variant => $variant,
                channel => $self->{channel},
                status_id => $stock_status_id,
            });

            # Create matching entry in the rtv_quantity table
            my ($rtv_quantity, $rma_request_detail);
            if($with_rtv_quantity) {
                $rtv_quantity = $from_quantity->create_related('rtv_quantity', {
                    quantity => $total_quantity,
                    origin => 'GI',
                });

                # Also create the RMA Request
                my $rma_request = $self->create_a_request_rma($rtv_quantity);
                $rma_request_detail = $rma_request->search_related('rma_request_details', {
                    rtv_quantity_id => $rtv_quantity->id(),
                })->single();

                # A big cheat this, as we're not properly creating an RTV shipment,
                # but the beloved RTV code has almost no test libraries except all that
                # horrendous Flow stuff. So this will do. Otherwise I'd be here til
                # Xmas.
                $rma_request_detail->update({
                    status_id => $RMA_REQUEST_DETAIL_STATUS__RTV,
                }) if $marked_for_rtv;
            }

            my $move_stock_count = 2;
            subtest 'partial move' => sub {
                my $return_now;
                # Move some of the stock
                try {
                    $schema->resultset('Public::Quantity')->move_stock({
                        variant  => $variant->id,
                        channel  => $self->{channel}->id,
                        quantity => $move_stock_count,
                        from     => { location => $from_location, status => $stock_status_id, },
                        to       => { location => $to_location, status => $stock_status_id, },
                        log_location_as => $APPLICATION_OPERATOR_ID,
                    });
                    $return_now=0;
                } catch {
                    die $_ unless $marked_for_rtv;
                    isa_ok($_, 'NAP::XT::Exception::Stock::RTVQuantityMove',
                        'move_stock() dies with correct exception when stock is already'
                        . ' marked for RTV');
                    $return_now=1;
                };
                return if $return_now;
                fail('move_stock() should throw exception when stock is already marked for RTV')
                    if $marked_for_rtv;


                # Make sure we have the correct amount of stock left at the sources
                is( $from_quantity->discard_changes->quantity, $total_quantity - $move_stock_count,
                    'quantity at source after partial move ok' );
                if($with_rtv_quantity) {
                    is( $from_quantity->rtv_quantity->quantity,
                        $total_quantity - $move_stock_count,
                        'rtv quantity at source after partial move ok'
                    );
                    $rma_request_detail->discard_changes();
                    is($rma_request_detail->quantity(), $total_quantity - $move_stock_count,
                       'RMA request detail quantity at source updated correctly');
                }

                # Make sure we have the correct number of stock at the destinations
                my $to_quantity = $framework->schema->resultset('Public::Quantity')->find({
                    variant_id => $variant->id,
                    location_id => $to_location->id,
                });
                is( $to_quantity->quantity, $move_stock_count,
                    'quantity at destination after partial move ok' );
                if($with_rtv_quantity) {
                    my $to_rtv_quantity = $to_quantity->rtv_quantity();
                    is( $to_rtv_quantity->quantity, $move_stock_count,
                        'rtv quantity at destination after partial move ok'
                    );
                    my $new_rma_request_detail
                        = $schema->resultset('Public::RmaRequestDetail')->find({
                            rtv_quantity_id => $to_rtv_quantity->id(),
                        });
                    ok(defined($new_rma_request_detail),
                        'RMA Request detail generated for new RTV quantity');
                    is($new_rma_request_detail->quantity(), $move_stock_count,
                        'RMA Request detail contains correct quantity');
                }
            };

            subtest 'full move' => sub {
                my $return_now;
                # Move some of the stock
                try {
                    $schema->resultset('Public::Quantity')->move_stock({
                        variant  => $variant->id,
                        channel  => $self->{channel}->id,
                        quantity => $total_quantity - $move_stock_count,
                        from     => { location => $from_location, status => $stock_status_id, },
                        to       => { location => $to_location, status => $stock_status_id, },
                        log_location_as => $APPLICATION_OPERATOR_ID,
                    });
                    $return_now=0;
                } catch {
                    die $_ unless $marked_for_rtv;
                    isa_ok($_, 'NAP::XT::Exception::Stock::RTVQuantityMove',
                        'move_stock() dies with correct exception when stock is already'
                        . ' marked for RTV');
                    $return_now=1;
                };
                return if $return_now;
                fail('move_stock() should throw exception when stock is already marked for RTV')
                    if $marked_for_rtv;

                # Make sure there's nothing left at the sources
                ok( !$from_quantity->discard_changes->in_storage,
                    'empty source quantity deleted' );
                if($with_rtv_quantity) {
                    ok( !$schema->resultset('Public::RTVQuantity')->find({
                            variant_id => $variant->id,
                            location_id => $from_location->id,
                        }), 'empty source rtv quantity deleted'
                    );
                    $rma_request_detail->discard_changes();
                    ok(! $rma_request_detail->in_storage(),
                        'Original rma_request_detail has been deleted');
                }

                # Make sure we have the correct number of stock at the destinations
                my $to_quantity = $framework->schema->resultset('Public::Quantity')->find({
                    variant_id => $variant->id,
                    location_id => $to_location->id,
                });
                is( $to_quantity->quantity, $total_quantity,
                    'quantity at destination after full move ok' );
                if($with_rtv_quantity) {
                    my $to_rtv_quantity = $to_quantity->rtv_quantity();
                    is( $to_rtv_quantity->quantity(), $total_quantity,
                        'rtv quantity at destination after full move ok'
                    );
                    my $new_rma_request_detail
                        = $schema->resultset('Public::RmaRequestDetail')->find({
                            rtv_quantity_id => $to_rtv_quantity->id(),
                        });
                    ok(defined($new_rma_request_detail),
                        'RMA Request detail generated for new RTV quantity');
                    is($new_rma_request_detail->quantity(), $total_quantity,
                        'RMA Request detail contains correct quantity');
                }

            };
        };
    }
}

sub test__adjust_quantity_and_log :Tests {
    my ($self) = @_;

    SKIP: {
        skip 'adjust_quantity_and_log only applies with PRL or IWS',
            unless ($self->iws_rollout_phase or $self->prl_rollout_phase());

        # Create quantity in the quantity table
        my $location = Test::XTracker::Data->get_main_stock_location();
        my $quantity_row = $self->{framework}->data__quantity__insert_quantity({
            quantity    => 2,
            location    => $location,
            variant     => $self->{variant},
            channel     => $self->{channel},
        });

        lives_ok(sub {
            $self->schema()->resultset('Public::Quantity')->adjust_quantity_and_log({
                sku             => $self->{variant}->sku(),
                status          => $quantity_row->status(),
                reason          => 'Too ugly',
                quantity_change => 1,
                client          => $self->{channel}->client()->get_client_code(),
                location        => $location,
            });
        }, 'call to adjust_quantity_and_log() lives');

        $quantity_row->discard_changes();
        is($quantity_row->quantity(), 3, 'quantity has been updated');

        throws_ok {
            $self->schema()->resultset('Public::Quantity')->adjust_quantity_and_log({
                sku             => $self->{variant}->sku(),
                status          => $quantity_row->status(),
                reason          => 'Waaaaay too ugly',
                quantity_change => 1,
                client          => 'Wibble',
                location        => $location,
            });
        } 'NAP::XT::Exception::Message::MismatchingClient',
            'Correct exception thrown if client in message does not match that of sku';
    }
}
