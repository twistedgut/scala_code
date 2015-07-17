package XT::DC::Messaging::Producer::Order::VirtualVoucherCode;
use NAP::policy "tt", 'class';
use Scalar::Util    qw( blessed );
use Carp;

with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'generate_virtual_voucher_code' );

sub transform {
    my ($self, $header, $shipment ) = @_;

    confess __PACKAGE__ . "::transform needs a Public::Shipment row"
        unless (blessed($shipment) && $shipment->isa('XTracker::Schema::Result::Public::Shipment'));

    # set-up parts of the message first
    my $msg = {
        channel_id  => $shipment->order->channel_id,
    };
    my $ship    = {
            shipment_id => $shipment->id,
        };

    # get virtual voucher items only
    my @items   = $shipment->shipment_items->search( {}, { order_by => 'me.id ASC' } )->all;

    foreach my $item ( @items ) {
        # is it a virtual voucher with no code assigned
        if ( $item->voucher_variant_id
             && !$item->get_true_variant->product->is_physical
             && !defined $item->voucher_code_id ) {

            # add the item and voucher pid to the request
            push @{ $ship->{shipment_items} }, {
                                shipment_item_id=> $item->id,
                                voucher_pid     => $item->get_true_variant->product_id,
                            };
        }
    }

    # finish of the message by adding in the
    # shipment with the items wanting codes
    push @{ $msg->{shipments} }, $ship;

    return (
        $header,
        $msg
    );
}

1;
