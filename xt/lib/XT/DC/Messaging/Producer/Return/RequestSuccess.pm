package XT::DC::Messaging::Producer::Return::RequestSuccess;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'return_request_ack' );
has '+set_at_type' => ( default => 0 );

=head1 NAME

XT::DC::Messaging::Producer::Return::RequestSuccess

=head1 DESCRIPTION

AMQ producer to send confirmation of a successful request to raise a return.

=head1 METHODS

=head2 transform

Accepts a XT::Domain::Return object as input and produces a message
confirming that the return has been accepted including the RMA identifier
in the message.

=cut

sub transform {
    my ($self, $header, $data )   = @_;

    unless ( exists $data->{return} && ref $data->{return} &&
        $data->{return}->isa('XTracker::Schema::Result::Public::Return' ) ) {

        die "You must pass in the XTracker::Schema::Result::Public::Return object as return";
    }

    my $return = $data->{return};

    my $response = {
        status              => "success",
        rmaNumber           => $return->rma_number,
        orderNumber         => $return->link_order__shipment->order->order_nr,
        channel             => $return->link_order__shipment->order->channel->web_name,
        returnExpiryDate    => $return->expiry_date->set_time_zone( 'UTC' )->strftime("%FT%H:%M:%S%z"),
        returnCreationDate  => $return->creation_date->set_time_zone( 'UTC' )->strftime("%FT%H:%M:%S%z"),
        returnRequestDate   => $data->{return_request_date}
    };

    foreach my $return_item ( $return->return_items->all ) {
        my $item = {
            sku                 => $return_item->shipment_item->variant->get_third_party_sku,
            externalLineItemId  => $return_item->shipment_item->pws_ol_id
        };

        if ( $return_item->exchange_shipment_item_id ) {
            $item->{exchangeSku} = $return_item->exchange_shipment_item->variant->get_third_party_sku;
        }

        push @{ $response->{returnItems} }, $item;
    }

    return ( { %$header }, $response );
}

