package XT::Business::Logic::MRP::OrderImporter;

use Moose;
use Readonly;
use XTracker::Constants::FromDB qw/ :currency /;

extends 'XT::Business::Base';

# Messages for packing if items qualify for garment bag
Readonly my $BASIC_BAG_MESSAGE  => 'Provide basic garment bag for ';
Readonly my $LUXURY_BAG_MESSAGE => 'Provide luxury garment bag for ';
Readonly my @QUALIFYING_PRODUCT_TYPES => (
    'Casual Jackets',
    'Coats',
    'Formal Jackets',
    'Jackets',
    'Suits',
);

=head1 NAME

XT::Business::Logic::MRP::OrderImporter - business specific logic for order
importer

=head1 apply_welcome_pack

We have a Welcome Pack. It is a single language to be added to new Mr Porter
customers

=cut

sub apply_welcome_pack {
    my($self,$order) = @_;

    return unless $self->local_welcome_pack_qualification( $order );

    $self->apply_default_welcome_pack($order);

    return;
}


=head1 shipment_modifier

* on packing screen in 'other information', if item in order is product
  sub-type (coats, jackets, suits) display 'use basic garment bag'

* if non-discounted is more than £1000, $1500, EUR1000) display luxury
  garment bag

=cut

sub shipment_modifier {
    my($self,$shipment) = @_;

    if (ref($shipment) ne 'XTracker::Schema::Result::Public::Shipment') {
        die __PACKAGE__ ." - expecting "
            ."XTracker::Schema::Result::Public::Shipment object";
    }


    my $items = $shipment->shipment_items;
    my $bag = {
        basic => undef,
        luxury => undef,
    };
    while (my $item = $items->next) {

        # ignore any Gift Vouchers
        next        if ( $item->is_voucher );

        # check that it is a coat, jacket, suit as a subtype
        my $product = $item->variant->product;

        next if (not $product->has_product_type_of(\@QUALIFYING_PRODUCT_TYPES));

        # these qualify for the luxury bags.. ooooooo!
        # GBP
        if (!$item->is_discounted && (
            ($shipment->order->currency_id == $CURRENCY__GBP &&
            $item->purchase_price >= 1200)
            or
        # USD
            ($shipment->order->currency_id == $CURRENCY__USD &&
            $item->purchase_price >= 1920)
            or
        # EUR
            ($shipment->order->currency_id == $CURRENCY__EUR &&
            $item->purchase_price >= 1440))) {
            push @{$bag->{luxury}}, $item->variant->sku;
        } else {
            push @{$bag->{basic}}, $item->variant->sku;
        }
    }

    my $message = undef;
    if (defined $bag->{luxury}) {
        $message .= $self->_generate_packing_other_info_message(
            $LUXURY_BAG_MESSAGE, $bag->{luxury}
        );
    }
    if (defined $bag->{basic}) {
        $message .= (defined $message?' ':'')
            . $self->_generate_packing_other_info_message(
            $BASIC_BAG_MESSAGE, $bag->{basic}
        );
    }


    if (defined $message) {
        $shipment->update({
            packing_other_info => $message,
        });
    }
}

sub _generate_packing_other_info_message {
    my($self,$prefix,$skus) = @_;

    my $message = $prefix || '';
#    my $ = map { } @{$skus};
    return $message . join(' ', @{$skus}) .'.';
}

1;
