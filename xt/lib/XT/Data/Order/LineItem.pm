package XT::Data::Order::LineItem;

use Moose;
use namespace::autoclean;
use Carp;

use XT::Data::Types qw(PosInt);
use XT::Data::Money;
use XTracker::Constants::FromDB qw{ :variant_type
                                    :shipment_item_returnable_state
                                    :shipment_item_on_sale_flag
                                  };

=head1 NAME

XT::Data::Order::LineItem - A line item for an order for fulfilment

=head1 DESCRIPTION

This class represents a line item for an order that is to be inserted into
XT's order database.

=head1 ATTRIBUTES

=head2 id

=cut

=head1 NAME

XT::Data::Order::LineItem - A line item for an order for fulfilment

=head1 DESCRIPTION

This class represents a line item for an order that is to be inserted into
XT's order database.

=head1 ATTRIBUTES

=head2 schema

=cut

with 'XTracker::Role::WithSchema';

=head2 id

=cut

has id => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 description

=cut

has description => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 sku

=cut

has sku => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 third_party_sku

=cut

has third_party_sku => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 quantity

Attribute must be a positive integer.

=cut

has quantity => (
    is          => 'rw',
    isa         => PosInt,
    required    => 1,
);

=head2 sequence

=cut

has sequence => (
    is          => 'rw',
    isa         => 'Int',
    required    => 0,
);

=head2 unit_net_price

Attribute is of class L<XT::Data::Money>.

=cut

has unit_net_price => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
    required    => 1,
);

=head2 tax

Attribute is of class L<XT::Data::Money>.

=cut

has tax => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
    required    => 1,
);

=head2 duties

Attribute is of class L<XT::Data::Money>.

=cut

has duties => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
    required    => 1,
);

has cost_reduction => (
    is          => 'rw',
    isa         => 'XT::Data::Order::CostReduction',
);

has is_voucher => (
    is          => 'rw',
    isa         => 'Bool',
    required    => 1,
    default     => 0,
);

has is_gift => (
    is          => 'rw',
    isa         => 'Bool',
    required    => 1,
    default     => 0,
);

has gift_message => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => undef,
);

has gift_from => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => undef,
);

has gift_to => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => undef,
);

has voucher_variant_id => (
    is          => 'rw',
    isa         => 'Int|Undef',
    default     => undef,
);

has voucher_code_id => (
    is          => 'rw',
    isa         => 'Int|Undef',
    default     => undef,
);

# Added for CANDO-74
has gift_recipient_email => (
    is          => 'rw',
    isa         => 'Str|Undef',
    required    => 0,
);

# Added for CANDO-2885
has returnable_state => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => undef,
    # for backward & third party compatibility
    required    => 0,
);

has _returnable_states => (
    is          => 'ro',
    isa         => 'HashRef',
    init_arg    => undef,
    lazy_build  => 1,
);

sub _build__returnable_states {
    my $self    = shift;

    my %states  = (
        map { uc( $_->pws_key ) => $_->id }
                $self->schema->resultset('Public::ShipmentItemReturnableState')->all
    );

    return \%states;
}

has on_sale_flag => (
    is          => 'ro',
    isa         => 'Str|Undef',
    default     => undef,
    required    => 0,
);

has _valid_on_sale_flags => (
    is          => 'ro',
    isa         => 'HashRef',
    init_arg    => undef,
    lazy_build  => 1,
);

sub _build__valid_on_sale_flags {
    my $self = shift;

    my %flags = (
        map { uc( $_->pws_key ) => $_->id }
                $self->schema->resultset('Public::ShipmentItemOnSaleFlag')->all
    );

    return \%flags;
}

=head2 preprocess_cost_reduction

To explain,

    line_item_price = quantity * unit_price
    line_item_tax = quantity * unit_tax
    line_item_duty = quantity * unit_duty

We know the discount on a line_item

    $line_item->cost_reduction->value

To determine the discount for a unit's unit_price, tax and duty, let
DiscountRatio (DR) be

                DR = $line_item->cost_reduction->value / quantity
                     --------------------------------------------
                     (unit_price + unit_tax + unit_duty)

noting that

    unit_price = $line_item->unit_net_price,
    unit_tax = $line_item->tax
    unit_duty = $line_item->duty

Then the calculations we do here are:

    unit_price_discount = $line_item->unit_net_price * DR
    unit_tax_discount = $line_item->tax * DR
    unit_duty_discount = $line_item->duty * DR

=cut

sub _2dp {
    return sprintf("%.2f", shift // 0);
}

sub preprocess_cost_reduction {
    my $self = shift;

    return unless $self->cost_reduction;

    my $DR = ( $self->cost_reduction->value / $self->quantity ) / (
        $self->unit_net_price->value
        + $self->tax->value
        + $self->duties->value
    );

    # previously we used to truncate $DR to 2dp, then do the sums
    # this is bad and can lead to the total being more than the original value
    # - calculate with the full value, and truncate the result!

    $self->cost_reduction->unit_net_price(
        _2dp($self->unit_net_price->value * $DR)
    );
    $self->cost_reduction->unit_tax(
        _2dp($self->tax->value * $DR)
    );
    $self->cost_reduction->unit_duties(
        _2dp($self->duties->value * $DR)
    );

}

=head2 shipping_charge

Return shipping charge info for this line item if it is a shipping charge

=cut

sub shipping_charge {
    my $self = shift;

    return $self->schema->resultset('Public::ShippingCharge')->find_by_sku($self->sku);
}

=head2 packing_instruction

Return packing instruction info for this line item if it is a packing instruction

=cut

sub packing_instruction {
    my $self = shift;

    return $self->schema->resultset('Public::PackagingType')->find_by_sku($self->sku);
}

=head2 total

=Returns total value of line item

=cut

sub total {
    my $self = shift;

    my $total = $self->unit_net_price + $self->tax + $self->duties;
    $total->multiply_value( $self->quantity );
    return $total;
}

=head2 is_physical_voucher

=cut

sub is_physical_voucher {
    my $self = shift;

    return unless $self->is_voucher;

    return $self->variant->product->is_physical;
}

=head2 is_physical

Returns true if the LineItem represents either a physical product or a physical
voucher.

=cut

sub is_physical {
    my ( $self ) = @_;

    if ( $self->is_voucher ) {
        return $self->variant->product->is_physical;
    }
    elsif ( $self->shipping_charge || $self->packing_instruction ) {
        return 0;
    }
    else {
        return 1;
    }

}

=head2 variant

=cut

sub variant {
    my $self = shift;

    if ($self->is_voucher) {
        return $self->schema->resultset('Voucher::Variant')->find_by_sku($self->sku);
    }

    return $self->schema->resultset('Public::Variant')->find_by_sku($self->sku,undef,0,$VARIANT_TYPE__STOCK);
}

=head2 get_returnable_state_id

    $integer = $self->get_returnable_state_id;

Returns the appropriate Returnable State for the Line Item
based on the 'returnable_state' attribute. Will always
return 'No' for Gift Voucher lines.

=cut

sub get_returnable_state_id {
    my $self    = shift;

    # if a Voucher then default to 'no'
    return $SHIPMENT_ITEM_RETURNABLE_STATE__NO      if ( $self->is_voucher );

    # if nothing was specified then default to 'yes'
    return $SHIPMENT_ITEM_RETURNABLE_STATE__YES     if ( !$self->returnable_state );

    my $states  = $self->_returnable_states;

    if ( my $state_id = $states->{ uc( $self->returnable_state ) } ) {
        return $state_id;
    }
    else {
        # default to 'yes'
        carp "Couldn't find Returnable State for '" . $self->returnable_state . "' defaulting to 'Yes'";
        return $SHIPMENT_ITEM_RETURNABLE_STATE__YES;
    }
}

=head2 get_on_sale_flag_id

    $integer = $self->get_on_sale_flag_id;

Returns the on_sale_flag_id appropriate to the Sale attribute in the
order_line item. Defaults to the id for 'No'.

=cut

sub get_on_sale_flag_id {
    my $self = shift;

    return if ! $self->on_sale_flag;

    if ( my $id = $self->_valid_on_sale_flags->{ uc( $self->on_sale_flag ) } ) {
        return $id;
    }
    else {
        carp "Could not find valid on_sale_flag for '".$self->on_sale_flag."' - defaulting to 'No'";
        return $SHIPMENT_ITEM_ON_SALE_FLAG__NO;
    }
};

=head1 SEE ALSO

L<XT::Data::Order>

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>

=cut

__PACKAGE__->meta->make_immutable;

1;
