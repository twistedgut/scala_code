package XT::DC::Messaging::Producer::PurchaseOrder::ImportResponse;
# vim: ts=8 sts=4 et sw=4 sr sta

use NAP::policy "tt", 'class';

with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'po_imported' );

use XTracker::Constants qw(
    :message_response
);

=head1 NAME

XT::DC::Messaging::Producer::PurchaseOrder::ImportResponse - send purchase order import status

=head1 METHODS

=head2 C<transform>

    $amq->transform_and_send( 'XT::DC::Messaging::Producer::PurchaseOrder::ImportResponse', {
        status => $status,
        po_number => $purchase_order_number,
        message => $error_message
    } );

Given some data about the purchase order import, creates a message to
be sent with its status

=cut

sub transform {
    my ($self, $header, $data) = @_;

    # yes, we need this
    $data->{'@type'} = 'po_imported';

    # Catch Rx failures - not just a single sku
    if ($data->{rx_failure}) {
        delete $data->{rx_failure};
    }else{

        # required fields
        for (qw(status po_number)) {
            confess $_ . ' data key is required' unless $data->{ $_ };
        }
        if ($data->{status} eq $MESSAGE_RESPONSE_STATUS_ERROR) {
            for (qw(message)) {
                confess $_ . ' data key is required if status is error' unless $data->{ $_ };
            }
        }

    }
    return ($header, $data);
}
