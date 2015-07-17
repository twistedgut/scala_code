package Test::XT::Domain::Payment::Basket;
use NAP::policy qw( tt class test );
BEGIN {
    extends 'NAP::Test::Class';
};

use Test::XT::Data::Return;
use Mock::Quick;

=head1 NAME

Test::XT::Domain::Payment:Basket

=head1 DESCRIPTION

Tests the 'XT::Domain::Payment::Basket' Class.

=cut

sub test__startup : Tests( startup => no_plan ) {
    my $self = shift;

    $self->SUPER::startup();

    use_ok 'XTracker::Config::Local';
    use_ok 'XT::Domain::Payment::Basket';
    use_ok 'Test::XT::Data';


    $self->{voucher} = Test::XTracker::Data->create_voucher;

    my ($channel,$pids) = Test::XTracker::Data->grab_products( {
        force_create => 1, how_many => 2, how_many_variants => 2,
    });

    $self->{channel} = $channel;

    my ($order) = Test::XTracker::Data->apply_db_order( {
        pids => [ @{$pids}, $pids->[0], $pids->[0]],
        base => {
            tenders => [
                {
                    type  => 'store_credit',
                    value => 40,
                },
                {
                    type  => 'voucher_credit',
                    value => 60,
                },
                {
                    type  => 'voucher_credit',
                    value => 10,
                },

            ],
        }
    });

    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    Test::XTracker::Data->create_payment_for_order( $order, $payment_args );
    $self->{shipment} = $order->shipments->first;
    $self->{order} = $order;
    note "Created Order Id/order_number :" . $order->id."/". $order->order_nr;
}

=head1 TEST OBJECT INSTANTIATION

=head2 test__instantiation_success

Make sure instantiation succeeds with all the required attributes.

=cut

sub test__instantiation_success : Tests {
    my $self = shift;

    $self->basket_object_ok;

}

=head2 test__instantiation_missing_shipment

Test that instantiating the object with a missing shipment attribute fails.

=cut

sub test__instantiation_missing_shipment : Tests {
    my $self = shift;

    throws_ok( sub {
        $self->basket_object(
        );
    }, qr/Attribute \(shipment\) is required at/,
    'Correct exception is thrown for a missing shipment' );

}

=head2 test__instantiation_incorrect_shipment

Test that instantiating the object with an incorrect shipment attribute fails.

=cut

sub test__instantiation_incorrect_shipment : Tests {
    my $self = shift;

    throws_ok( sub {
        $self->basket_object(
            shipment => 'Should be an XTracker::Schema::Result::Public::Shipment',
        );
    }, qr/Attribute \(shipment\) does not pass the type constraint/,
    'Correct exception is thrown for an incorrect shipment' );

}

=head2 test__instantiation_incorrect_log

Test that instantiating the object with an incorrect log attribute fails.

=cut

sub test__instantiation_incorrect_log : Tests {
    my $self = shift;

    throws_ok( sub {
        $self->basket_object(
            shipment => $self->shipment,
            log      => 'Should be a Log::Log4perl::Logger',
        );
    }, qr/Attribute \(log\) does not pass the type constraint/,
    'Correct exception is thrown for an incorrect log' );

}


=head2 test__attribute_log

Test the log attribute.

=cut

sub test__attribute_log : Tests {
    my $self = shift;

    my $object = $self->basket_object_ok;

    ok( $object->log,
        'The attribute is defined' );

    isa_ok( $object->log,
        'Log::Log4perl::Logger',
        '  ... and is' );

}

=head2 test__shipment_items_data

Test checks if shipment_item array of hash is
populated correctly.

=cut

sub test__shipment_items_data : Tests {
    my $self = shift;

    my $object          = $self->basket_object_ok;
    my $shipment_items  = $object->shipment_items;
    my @expected_keys   =  sort(
        'amount',
        'name',
        'quantity',
        'sku',
        'tax',
        'vat'
    );

    my $expected = {
        'elements' => 2,
        'expt_keys' => \@expected_keys,
        'quantity' => [ sort(3,1)],
    };

    #extract keys
    my @keys = sort keys %{@$shipment_items[0]};
    #extract quantity
    my @quantity = sort grep { $_}
        map { $_->{quantity} }
        @$shipment_items;

    my $got = {
        'elements'  => scalar( @$shipment_items),
        'expt_keys' => \@keys,
        'quantity'  => \@quantity,
    };

    is_deeply( $got, $expected, "Shipment Items are populated correctly");
}


sub test__gift_voucher_data : Tests {
    my $self = shift;

    my $object          = $self->basket_object_ok;
    my $gift_voucher    = $object->gift_voucher;
    my @expected_keys   = sort(
        'amount',
        'name',
        'quantity',
        'sku',
        'tax',
        'vat'
    );

    my $expected = {
        'expt_keys' => \@expected_keys,
        quantity => 1,
    };

    my @keys =  sort keys %{$gift_voucher};
    my $got = {
        'expt_keys'   => \@keys,
       'quantity'    => $gift_voucher->{quantity},
    };
    is_deeply( $got, $expected, "Virtual Voucher is populated correctly");
}


sub test__store_credit_data : Tests {
    my $self = shift;

    my $object          = $self->basket_object_ok;
    my $store_credit    = $object->store_credit;
    my @expected_keys   = sort(
        'amount',
        'name',
        'quantity',
        'sku',
        'tax',
        'vat'
    );

    my $expected = {
        'expt_keys' => \@expected_keys,
        quantity => 1,
    };

    my @keys =  sort keys %{$store_credit};
    my $got = {
        'expt_keys'   => \@keys,
       'quantity'    => $store_credit->{quantity},
    };
    is_deeply( $got, $expected, "Store Credit is populated correctly");
}

sub test__shipping_data : Tests {
    my $self = shift;

    my $object   = $self->basket_object_ok;

    # Override the calculation for shipping tax
    my $control = qtakeover ('XTracker::Schema::Result::Public::Shipment');
    $control->override( calculate_shipping_tax => sub { return 8.76 } );

    my $shipping = $object->shipping();

    # examine shipping, basket total etc
    my $expected = {
        'expt_keys' => [
            'amount',
            'name',
            'quantity',
            'sku',
            'tax',
            'vat'
        ],
        quantity => 1,
        amount   => 1000,
        tax      => 0,    # This is hardcoded to 0
        vat      => 876   # This is shipping tax in pence (overriden above)
    };
    my @keys = sort keys %{$shipping};
    my $got = {
        expt_keys => \@keys,
        quantity  => $shipping->{quantity},
        amount    => $shipping->{amount},
        tax       => $shipping->{tax},
        vat       => $shipping->{vat},
    };

    is_deeply( $got, $expected, "Shipping data is populated correctly");
}

sub test__get_balance : Tests {
    my $self = shift;

    my $object          = $self->basket_object_ok;
    my $shipping    = $object->shipping;
    my $store_credit    = $object->store_credit;
    my $gift_voucher    = $object->gift_voucher;
    my $shipment_items  = $object->all_shipment_items;

    my $total  = $object->total_item_value
    + $shipping->{amount}
    + $gift_voucher->{amount}
    + $store_credit->{amount};

    cmp_ok ( $total,'==', $object->get_balance, " Balance amount is calculated correctly");

}

sub test__send_basket_to_psp : Tests {
    my $self = shift;

    my $object = $self->basket_object_ok;

    dies_ok sub { $object->send_basket_to_psp() },
    "Dies due to invalid details";

}


sub test__update_psp_with_item_changes : Tests {
    my $self = shift;

    #Create a new order with 3 variants
    my $order_obj = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order', 'Test::XT::Data::Return' ]
    );

    my $order_objects = $order_obj->dispatched_order(
        products => 3,
        channel => 'nap',
        how_many_variants => 3,
        ensure_stock => 1,
        ensure_stock_all_variants =>1,
    );

    my $order = $order_objects->{order_object};
    my $shipment_id = $order_objects->{shipment_id};
    my $shipment = $order->shipments->first;
    my @shipment_items = $shipment->non_cancelled_items->all;

    my @orignal_si =  map { $_->id } @shipment_items;

    # make sure order has payment record.
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    Test::XTracker::Data->create_payment_for_order( $order, $payment_args );

    #create a related return
    my $return = $order_obj->new_return({
        shipment_id => $shipment_id,
        items => {
            $shipment_items[0]->id => {
                type => 'Exchange',
                exchange_variant =>  $shipment_items[1]->variant->id,
            },
            $shipment_items[2]->id => {
                type => 'Exchange',
                exchange_variant =>  $shipment_items[2]->variant->id,

            }

        }
    });

    # Instantiate Object
    my $object = $self->basket_object_ok(
        shipment => $shipment
    );

    dies_ok sub {  $object->update_psp_with_item_changes() },
    "Dies due to no arguments are passed";

    is( $object->update_psp_with_item_changes([]), 1, "Returns 1 for empty list");

    #checks  attribute shipment_items_for_order
    my @keys = keys % { $object->shipment_items_for_order };
    cmp_ok($#keys+1, '==', 5, "Order has 5 shipment items in total ");

    my @change_items;
    push(@change_items, { orig_item_id => $orignal_si[0], new_item_id => $orignal_si[2]  } ) ;
    push(@change_items, { orig_item_id => $orignal_si[0], new_item_id => $orignal_si[1]  } ) ;
    push(@change_items, { orig_item_id => $orignal_si[0], new_item_id => $orignal_si[0]  } ) ;

    my $got = $object->construct_item_replacement_data_for_psp(\@change_items);

    # Check number of items  are as expected
    cmp_ok(scalar @{$got},'==', 2, "Hash has only 2 items as Expected ");
}

=head2 basket_object( %arguments )

Returns a new instance of L<XT::Domain::Payment::Basket>, with no defaults, so
you must pass any C<%arguments> that you require.

=cut

sub basket_object {
    my $self = shift;
    my ( %arguments ) = @_;

    return XT::Domain::Payment::Basket->new(
        %arguments );

}

=head2 basket_object_ok( %arguments )

Returns a new instance of an L<XT::Domain::Payment::Basket>, making sure it is
of the correct type and that the C<new> method lives ok.

A default handler is created for the object and the test shipment C<Shipment> is used.

=cut

sub basket_object_ok {
    my $self = shift;
    my ( %arguments ) = @_;

    my $shipment = $arguments{shipment} // $self->shipment;
    my %object_arguments = (
        shipment    => $shipment,
    );

    my $object;

    lives_ok( sub { $object = $self->basket_object( %object_arguments ) },
        'Domain:Payment::Basket does not die when being instantiated' );

    isa_ok( $object, 'XT::Domain::Payment::Basket',
        'Domain Payment Basket' );

    return $object;

}

=head1 ATTRIBUTES

=head2 Accessors

    shipment

=cut

sub shipment        { return shift->{shipment} }

