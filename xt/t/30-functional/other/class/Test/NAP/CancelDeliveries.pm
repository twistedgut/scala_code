package Test::NAP::CancelDeliveries;

use NAP::policy "tt", 'test';

=head1 NAME

Test::NAP::CancelDeliveries - Test cancelling deliveries

=head1 DESCRIPTION

Test cancelling deliveries at various stages of Goods In.

#TAGS goodsin stockin qualitycontrol cancel

=head1 METHODS

=cut

use FindBin::libs;

use Test::XTracker::Data;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :delivery_item_status
    :delivery_status
    :stock_order_status
    :stock_process_status
    :stock_process_type
);
use XTracker::Constants qw( :database );
use Test::XT::Flow;

use feature ':5.14';

use parent 'NAP::Test::Class';

sub startup : Test(startup => 1) {
    my ( $self ) = @_;

    $self->{flow} = Test::XT::Flow->new_with_traits({
        traits => 'Test::XT::Flow::GoodsIn'
    });

    $self->{flow}->login_with_permissions({
        perms => {
            # Lowest level required to work on page
            $AUTHORISATION_LEVEL__READ_ONLY => [
                'Goods In/Delivery Cancel',
                'Goods In/Stock In',
            ],
        },
    });
}

sub setup : Test(setup) {
    my ( $self ) = @_;
    # Ensure these are enabled at the beginning of every test as there are
    # times we set this to false
    $self->{flow}->errors_are_fatal(1);
}

=head2 test_cancel_multiple_deliveries

=cut

sub test_cancel_multiple_deliveries : Tests {
    my ( $self ) = @_;

    my $channel = Test::XTracker::Data->any_channel;
    my @pos = map { $self->create_test_po($channel->id) } 0..1;

    my @deliveries = map {
        $_->stock_orders->slice(0,0)->single->deliveries->slice(0,0)->single
    } @pos;
    my $flow = $self->{flow};
    $flow->mech__goodsin__cancel_delivery
        ->mech__goodsin__cancel_delivery_list_submit({
            channel_id => $pos[0]->channel->id,
            delivery_id => [map { $_->id } @deliveries],
        });
    $flow->mech->has_feedback_success_ok(map { qr{$_} } sprintf(
        'Deliveries %s cancelled',
        join q{, }, sort { $a <=> $b } map { $_->id } @deliveries
    ));
}

=head2 test_cancel_delivery_pre_qc

=cut

sub test_cancel_delivery_pre_qc : Tests {
    my ( $self ) = @_;

    my $po = $self->create_test_po;
    my $delivery
        = $po->stock_orders->slice(0,0)->single->deliveries->slice(0,0)->single;
    ok(!$delivery->is_cancelled,
        sprintf(q{delivery %d is not cancelled}, $delivery->id));

    my $flow = $self->{flow};
    $flow->mech__goodsin__cancel_delivery
        ->mech__goodsin__cancel_delivery_list_submit(
            { channel_id => $po->channel_id, delivery_id => $delivery->id, }
        );
    my $mech = $flow->mech;
    $mech->has_feedback_success_ok(
        map { qr{$_} } sprintf q{Delivery %s cancelled}, $delivery->id);

    # test it can't be cancelled twice
    $flow->errors_are_fatal(0);
    $flow->mech__goodsin__cancel_delivery_manual_submit($delivery->id);
    $mech->has_feedback_error_ok(
        map { qr{$_} } sprintf q{Delivery %s already cancelled}, $delivery->id);
}

=head2 test_cancel_delivery_validation

=cut

sub test_cancel_delivery_validation : Tests {
    my ( $self ) = @_;
    my $po = $self->create_test_po;
    my $delivery
        = $po->stock_orders->slice(0,0)->single->deliveries->slice(0,0)->single;

    my $flow = $self->{flow};
    my $mech = $self->{flow}->mech;
    $flow->errors_are_fatal(0);
    $flow->mech__goodsin__cancel_delivery;

    # Not an int
    my $input = $delivery->id."mvmc";
    $flow->mech__goodsin__cancel_delivery_manual_submit($input);
    $mech->has_feedback_error_ok( qr/Invalid delivery Id: '$input'/ );

    # Inexistent delivery
    $input = 1 + Test::XTracker::Data->get_schema
                                     ->resultset('Public::Delivery')
                                     ->get_column('id')->max;
    $flow->mech__goodsin__cancel_delivery_manual_submit($input);
    $mech->has_feedback_error_ok( qr{Could not find delivery $input} );

    # Ignore whitespace
    $input = sprintf ' %d ', $delivery->id;
    $flow->mech__goodsin__cancel_delivery_manual_submit($input);
    $mech->has_feedback_success_ok(
        map { qr{$_} } sprintf q{Delivery %s cancelled}, $delivery->id);
}

=head2 test_cancel_delivery_after_qc_pre_putaway

=cut

sub test_cancel_delivery_after_qc_pre_putaway : Tests {
    my ( $self ) = @_;

    my $po = $self->create_test_po;

    my $delivery
        = $po->stock_orders->slice(0,0)->single->deliveries->slice(0,0)->single;
    ok(!$delivery->is_cancelled,
        sprintf('delivery %d is not cancelled', $delivery->id));

    $delivery->update( { status_id => $DELIVERY_STATUS__PROCESSING } );
    $delivery->delivery_items->update({
        packing_slip => 10,
        quantity => 10,
        status_id => $DELIVERY_ITEM_STATUS__PROCESSING,
    });

    my $type_rs = $self->{flow}
                       ->schema
                       ->resultset('Public::StockProcessType')
                       ->search({id => { -in => [
                         $STOCK_PROCESS_TYPE__DEAD,
                         $STOCK_PROCESS_TYPE__FASTTRACK,
                         $STOCK_PROCESS_TYPE__MAIN,
                         $STOCK_PROCESS_TYPE__QUARANTINE_FIXED,
                         $STOCK_PROCESS_TYPE__SURPLUS, ] } });
    for my $type ( $type_rs->all ) {
        state @stock_processes;
        @stock_processes
            = @stock_processes
            ? (map { $_->update({type_id => $type->id}) } @stock_processes)
            : map {
                $_->stock_processes->create({
                    quantity  => $_->quantity,
                    type_id   => $type->id,
                    status_id => $STOCK_PROCESS_STATUS__APPROVED,
                    complete  => 0,
                })
            } $delivery->delivery_items->all;
        my $flow = $self->{flow};
        $flow->errors_are_fatal(0);
        $flow->mech__goodsin__cancel_delivery;
        $flow->mech__goodsin__cancel_delivery_manual_submit($delivery->id);
        $flow->mech->has_feedback_error_ok(map { qr{$_} } sprintf(
            'Cannot cancel delivery %d as there are process groups that are yet to be put away: %s',
            $delivery->id,
            join q{, }, sort { $a <=> $b } map {
                $_->discard_changes->group_id
            } @stock_processes
        ));
        ok(!$delivery->discard_changes->is_cancelled, sprintf(
            'delivery %d is not cancelled for %s', $delivery->id, $type->type
        ));
    }
}

=head2 test_cancel_delivery_after_putaway

=cut

sub test_cancel_delivery_after_putaway : Tests {
    my ( $self ) = @_;

    my $po = $self->create_test_po;

    my $delivery
        = $po->stock_orders->slice(0,0)->single->deliveries->slice(0,0)->single;
    ok(!$delivery->is_cancelled,
        sprintf('delivery %d is not cancelled', $delivery->id));

    my $location = Test::XTracker::Data->get_main_stock_location;
    $delivery->update( { status_id => $DELIVERY_STATUS__COMPLETE } );
    $delivery->delivery_items->update({
        packing_slip => 10,
        quantity => 10,
        status_id => $DELIVERY_ITEM_STATUS__COMPLETE,
    });

    foreach my $item ( $delivery->delivery_items->all ) {
        my $sp = $item->stock_processes->create({
            quantity    => $item->quantity,
            type_id     => $STOCK_PROCESS_TYPE__MAIN,
            status_id   => $STOCK_PROCESS_STATUS__PUTAWAY,
            complete    => 1,
        });
        $sp->putaways->create({
            location_id => $location->id,
            quantity    => $item->quantity,
            complete    => 1,
        });
    }


    my $flow = $self->{flow};
    $flow->mech__goodsin__cancel_delivery
        ->mech__goodsin__cancel_delivery_manual_submit($delivery->id);
    $flow->mech->has_feedback_success_ok(map { qr{$_} } sprintf(
        'Delivery %d has been cancelled, but please verify stock levels as the cancellation is being done after putaway',
        $delivery->id
    ));

    # Check at db level
    ok($delivery->discard_changes->cancel, sprintf('Delivery %d is Cancelled',$delivery->id));
    foreach my $item ( $delivery->delivery_items->all ) {
        ok( $item->is_cancelled, sprintf('Delivery item %d is cancelled', $item->id) );
        is( $item->stock_processes->count, 0,
            sprintf('all stock processes linked to delivery item %d have been deleted', $item->id) );
    }
}

sub create_test_po {
    my ( $self, $channel_id ) = @_;
    $channel_id //= Test::XTracker::Data->any_channel->id;
    return Test::XTracker::Data->create_from_hash({
        channel_id      => $channel_id,
        placed_by       => 'Test::NAP::CancelDeliveries',
        stock_order     => [{
            status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
            product         => {
                product_type_id => 6,
                style_number    => 'Any Style',
                variant         => [{
                    size_id => 1,
                    stock_order_item => { quantity => 40, },
                }],
                product_channel => [{
                    channel_id => $channel_id,
                    live       => 0,
                }],
                product_attribute => { description => 'New Description', },
                delivery => { status_id => $DELIVERY_STATUS__PROCESSING, },
            },
        }],
    });
}
1;
