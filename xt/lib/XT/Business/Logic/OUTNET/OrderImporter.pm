package XT::Business::Logic::OUTNET::OrderImporter;

use Moose;
use Readonly;
use XTracker::Constants::FromDB qw/ :currency /;

use Data::Dump 'pp';

extends 'XT::Business::Base';

# Messages for packing if items qualify for garment bag
Readonly my $BASIC_BAG_MESSAGE  => 'Provide basic garment bag for ';
Readonly my $LONG_BAG_MESSAGE => 'Provide long garment bag for ';
Readonly my $LENGTH_THRESHOLD => 95;
Readonly my $GBP_THRESHOLD => 300;
Readonly my $EUR_THRESHOLD => 350;
Readonly my $USD_THRESHOLD => 400;
Readonly my @QUALIFYING_CLASSIFICATIONS => ( 'Clothing' );

=head1 NAME

XT::Business::Logic::OUTNET::OrderImporter - business specific logic for order
importer

=head1 shipment_modifier

* on packing screen in 'other information', if item in order is product
  classification (Clothing) and more than £300, EUR350, $400 display
  'use basic garment bag' or similar

* if item in order is product classification (Clothing) and
  length is > 950m display 'use long garment bag' or similar

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
        long => undef,
    };
    while (my $item = $items->next) {

        # ignore any Gift Vouchers
        next        if ( $item->is_voucher );

        # check that it is clothing
        my $product = $item->variant->product;

        next if (not $product->has_classification_of(\@QUALIFYING_CLASSIFICATIONS));

        # these qualify for bags
        # GBP
        if ( ($shipment->order->currency_id == $CURRENCY__GBP &&
            $item->purchase_price >= $GBP_THRESHOLD)
            or
        # EUR
            ($shipment->order->currency_id == $CURRENCY__EUR &&
            $item->purchase_price >= $EUR_THRESHOLD)
            or
        # USD
            ($shipment->order->currency_id == $CURRENCY__USD &&
            $item->purchase_price >= $USD_THRESHOLD) ) {

            # these qualify for long bags
            if ( exists ($item->variant->get_measurements->{'Length'}) and $item->variant->get_measurements->{'Length'} >= $LENGTH_THRESHOLD ) {
                push @{$bag->{long}}, $item->variant->sku;
            } else {
                push @{$bag->{basic}}, $item->variant->sku;
            }
        }
    }

    my $message = undef;
    if (defined $bag->{long}) {
        $message .= $self->_generate_packing_other_info_message(
            $LONG_BAG_MESSAGE, $bag->{long}
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
