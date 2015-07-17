package Test::XT::Data::PreOrder;

use NAP::policy "tt",     qw( test role );

# Also Required is 'customer' & 'channel' but the 'requires'
# doesn't seem to reconginise the 'has' property for these
# things in other modules. See USAGE for other 'Test::XT::Data::'
# modules required for this one to work.
requires qw(
            schema
        );

=head1 NAME

Test::XT::Data::PreOrder

=head1 SYNOPSIS

Used for creating Pre-Orders.

By Default this will create a 'Complete' Pre-Order with 5 Pre-Order Items & their Reservations
and a 'pre_order_payment' record.

=head2 USAGE

    use Test::XT::Flow;
            or
    use Test::XT::Data;

    my $framework = Test::XT::(Data|Flow)->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',      <--- required
            'Test::XT::Data::Customer',     <--- required
            'Test::XT::Data::PreOrder',
        ],
    );

    # Returns a Pre-Order
    my $pre_order   = $framework->pre_order;

    # Returns All Reservations created for the Pre-Order Items,
    # when used on its own will create the Pre-Order first.
    my $array_ref   = $framework->reservations;

=cut

use XTracker::Utilities             qw( remove_discount );
use XTracker::Constants::FromDB     qw(
                                        :pre_order_status
                                        :pre_order_item_status
                                        :reservation_status
                                    );
use Test::XTracker::Data;

# use Log::Log4perl ':easy';
# Log::Log4perl->easy_init({ level => $INFO });

=head2 MOOSE ACCESSORS

The following can be overridden with an object(s) of your own choosing before the Pre-Order is created.

    $framework->pre_order_status        ( "An integer" );
    $framework->pre_order_item_status   ( "An Integer" );

    $framework->shipment_address        ( 'Public::OrderAddress' );
    $framework->invoice_address         ( 'Public::OrderAddress' );
    $framework->currency                ( 'Public::Currency' );
    $framework->shipping_charge         ( 'Public::ShippingCharge' );
    $framework->packaging_type          ( 'Public::PackagingType' );
    $framework->reservation_source      ( 'Public::ReservationSource' );
    $framework->reservation_type        ( 'Public::ReservationType' );
    $framework->operator                ( 'Public::Operator' );

    # for Applying Discounts to Pre-Orders
    $framework->discount_percentage     ( 5 );                  # default is 0% discount
    $framework->discount_operator       ( 'Public::Operator' )  # default is 'undef'

    # the following 2 will determin how many Pre-Order Items are Created, defaults to 5
    $framework->products( "An Array Ref of PIDs that you get back from 'Test::XTracker::Data->grab_products' method" );
    $framework->variants( "An Array Ref of 'Public::Variant' objects" );

    # item Pricing by Product Id, this will default to each item increasing its unit price by 100
    $framework->item_product_prices     ( {
        pid => { unit_price => 100.00, tax => 20.00, duty => 10.00 },
        ...
    } );
    # original item Pricing by Product Id, this will default to whatever the Item Price is with
    # any 'discount_percentage' removed
    $framework->original_item_product_prices     ( {
        pid => { unit_price => 120.00, tax => 22.00, duty => 11.00 },
        ...
    } );

=cut

has pre_order => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_pre_order',
);

has pre_order_status => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => $PRE_ORDER_STATUS__COMPLETE,
);

has pre_order_item_status => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => $PRE_ORDER_ITEM_STATUS__COMPLETE,
);

has shipment_address => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_shipment_address',
);

has invoice_address => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_invoice_address',
);

has currency => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_currency',
);

has shipping_charge => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_shipping_charge',
);

has packaging_type => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_packaging_type',
);

has reservation_source => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_reservation_source',
);

has reservation_type => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_reservation_type',
);
has products    => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_set_products',
);

has product_quantity => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => 5,
);

has product_live_state => (
    is      => 'rw',
    isa     => 'Bool',
    lazy    => 1,
    default => 0,
);

has variants    => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_set_variants',
);

has variant_order_quantity => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => 10,
);

has operator    => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_operator',
);

has product_id    => (
    is      => 'rw',
    isa     => 'Int',
);

has create_reservations => (
    is      => 'rw',
    isa     => 'Bool',
    lazy    => 1,
    default => 1,
);

has create_payment => (
    is      => 'rw',
    isa     => 'Bool',
    lazy    => 1,
    default => 1,
);

has reservation_status => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => $RESERVATION_STATUS__PENDING,
);

# return a list of reservations
has reservations    => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_set_reservations',
);

# the number of Variants per Product to create
has variants_per_product => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => 3,
    required=> 1,
);

has item_product_prices => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {}; },
    required => 0,
);

has original_item_product_prices => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {}; },
    required => 0,
);

has discount_percentage => (
    is      => 'rw',
    isa     => 'Num',
    default => 0.00,
);

has discount_operator => (
    is      => 'rw',
    isa     => 'Object|Undef',
    default => undef,
);


# Create a Pre-Order
sub _set_pre_order {
    my $self    = shift;

    my $total_value = 0;

    # getting the Variants here means any messages it
    # generates are clear of this method's messages
    my @variants    = @{ $self->variants };

    my $pre_order   = $self->schema->resultset('Public::PreOrder')->create( {
        customer_id             => $self->customer->id,
        pre_order_status_id     => $self->pre_order_status,
        reservation_source_id   => $self->reservation_source->id,
        reservation_type_id     => $self->reservation_type->id,
        shipment_address_id     => $self->shipment_address->id,
        invoice_address_id      => $self->invoice_address->id,
        shipping_charge_id      => $self->shipping_charge->shipping_charge_id,
        packaging_type_id       => $self->packaging_type->id,
        currency_id             => $self->currency->id,
        telephone_day           => $self->config_var('DistributionCentre','fax'),      # get a telephone like number
        total_value             => $total_value,
        operator_id             => $self->operator->id,
        applied_discount_percent     => $self->discount_percentage,
        applied_discount_operator_id => ( $self->discount_operator ? $self->discount_operator->id : undef ),
    } );

    note "Pre Order created, Id: " . $pre_order->id;

    # now create each Pre Order Item & Reservation
    my $unit_price  = 0;
    foreach my $variant ( @variants ) {
        $unit_price += 100;
        my $item    = $unit_price;
        my $tax     = $item * 0.05;
        my $duty    = $item * 0.10;

        # use the supplied Prices for the Product if available
        if ( my $item_price = $self->item_product_prices->{ $variant->product_id } ) {
            ( $item, $tax, $duty ) = (
                $item_price->{unit_price},
                $item_price->{tax},
                $item_price->{duty},
            );
        }

        # get the Original Item Prices
        my $original_item   = remove_discount( $item, $pre_order->applied_discount_percent );
        my $original_tax    = remove_discount( $tax, $pre_order->applied_discount_percent );
        my $original_duty   = remove_discount( $duty, $pre_order->applied_discount_percent );

        # use the supplied Original Prices for the Product if available
        if ( my $item_price = $self->original_item_product_prices->{ $variant->product_id } ) {
            ( $original_item, $original_tax, $original_duty ) = (
                $item_price->{unit_price},
                $item_price->{tax},
                $item_price->{duty},
            );
        }

        $total_value += ( $item + $tax + $duty );

        my $reservation_id = undef;

        if ( $self->create_reservations ) {
            my $reservation = $self->schema->resultset('Public::Reservation')->create( {
                                            ordering_id             => 0,
                                            variant_id              => $variant->id,
                                            customer_id             => $self->customer->id,
                                            operator_id             => $self->operator->id,
                                            status_id               => $self->reservation_status,
                                            channel_id              => $self->channel->id,
                                            reservation_source_id   => $self->reservation_source->id,
                                            reservation_type_id     => $self->reservation_type->id,
                                        } );

            $reservation_id = $reservation->id;
        }

        my $pre_order_item  = $pre_order->create_related( 'pre_order_items', {
                                            variant_id               => $variant->id,
                                            reservation_id           => $reservation_id,
                                            pre_order_item_status_id => $self->pre_order_item_status,
                                            tax                      => $tax,
                                            duty                     => $duty,
                                            unit_price               => $item,
                                            original_unit_price      => $original_item,
                                            original_tax             => $original_tax,
                                            original_duty            => $original_duty,
                                } );
        $pre_order_item->update_status( $pre_order_item->pre_order_item_status_id );

        if ( $self->create_reservations ) {
            note "---> Pre Order Item for SKU: " . $variant->sku . ", Reservation Id: " . $reservation_id;
        }
        else {
            note "---> Pre Order Item for SKU: " . $variant->sku;
        }
    }

    # update the Total Value now we know what it is
    $pre_order->update( { total_value => $total_value } );
    note "---> Pre Order Total: $total_value";

    # create a Payment Record For It
    if ( $self->create_payment ) {
        my $psp_refs    = Test::XTracker::Data->get_new_psp_refs();
        note "---> Create Pre Order Payment with:";
        note "                        psp_ref       - " . $psp_refs->{psp_ref};
        note "                        preauth_ref   - " . $psp_refs->{preauth_ref};
        note "                        settle_ref    - " . $psp_refs->{settle_ref};
        $pre_order->create_related( 'pre_order_payment', {
                                        psp_ref     => $psp_refs->{psp_ref},
                                        preauth_ref => $psp_refs->{preauth_ref},
                                        settle_ref  => $psp_refs->{settle_ref},
                                    } );
    }

    return $pre_order->discard_changes;
}

# gets the operator for the Reservation
sub _set_operator {
    my $self    = shift;

    return $self->schema->resultset('Public::Operator')
                    ->search( { username => 'it.god' } )
                        ->first;
}

# Create X Products with no stock but with stock on order to use for PreOrders
sub _set_products {
    my $self    = shift;

    my @products = Test::XTracker::Data->create_test_products({
        how_many          => $self->product_quantity,
        channel_id        => $self->channel->id,
        product_quantity  => $self->variant_order_quantity,
        how_many_variants => $self->variants_per_product,
        is_live_on_channel=> $self->product_live_state,
    });

    return \@products;
}

sub _set_variants {
    my $self = shift;

    my @variants = ();

    if ( $self->product_id ) {
        my $product = $self->schema->resultset('Public::Product')
            ->find($self->product_id);
        Test::XTracker::Data->ensure_product_storage_type( $product );
        my @variants = $product->variants();
    } else {
        foreach my $product (@{$self->products}) {
            Test::XTracker::Data->ensure_product_storage_type( $product );
            push(@variants, $product->variants->first);
        }
    }

    return \@variants;
}

# return 'LookBook' Source which is appropriate for Pre-Orders
sub _set_reservation_source {
    my $self    = shift;

    return $self->schema->resultset('Public::ReservationSource')
                    ->find( { source => 'LookBook'} );
}

sub _set_reservation_type {
    my $self = shift;

    return $self->schema->resultset('Public::ReservationType')->search->first;

}

sub _set_shipment_address {
    my $self    = shift;
    return Test::XTracker::Data->create_order_address_in('current_dc');
}

# by Default Invoice Address is the same as Shipment Address
sub _set_invoice_address {
    my $self    = shift;
    return $self->shipment_address;
}

# default the Currency to the DC
sub _set_currency {
    my $self    = shift;

    my $local_default   = $self->config_var('Currency','local_currency_code');
    return $self->schema->resultset('Public::Currency')
                        ->find( { currency => $local_default } );
}

# just get a Shipping Charge for the Shipping Country
sub _set_shipping_charge {
    my $self    = shift;

    my $ship_country    = $self->shipment_address->country_table;
    return $ship_country->country_shipping_charges
                            ->search( { channel_id => $self->channel->id } )
                                ->first;
}

# get Signature Packaging
sub _set_packaging_type {
    my $self    = shift;

    return $self->schema->resultset('Public::PackagingType')
                            ->search( { name => 'SIGNATURE' } )
                                ->first;
}

# return all of the Reservations for the Pre-Order
sub _set_reservations {
    my $self    = shift;

    my $pre_order   = $self->pre_order;
    my @reservations= map { $_->reservation }
                            $pre_order->pre_order_items
                                ->search( undef, { order_by => 'id' } )
                                    ->all;

    return \@reservations;
}

1;
