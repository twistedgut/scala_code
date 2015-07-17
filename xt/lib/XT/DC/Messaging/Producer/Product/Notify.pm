package XT::DC::Messaging::Producer::Product::Notify;
use NAP::policy "tt", 'class';
use XTracker::Config::Local 'config_var';
with 'XT::DC::Messaging::Role::Producer';

=head1 NAME

XT::DC::Messaging::Producer::Product::Notify - Send product messages to the
product service.

=head1 DESCRIPTION

This AMQ producer is called when we want XT to nofity the product service about
the existance of a product. This is usually when a product is first received
in XT after product generation.

=head1 METHODS

=head2 message_spec

L<Data::Rx> specification for the messages.

=cut

sub message_spec {
    return {
        type => '//any',
        of => [
            {
                type => '//rec',
                required => {
                    product_id => '//int',
                    channel_id => '//int',
                },
            },
            {
                type => '//rec',
                required => {
                    voucher_id => '//int',
                    channel_id => '//int',
                },
            },
        ],
    }
}

has '+type' => ( default => 'product_data_request' );

=head2 transform

Transform the given data into the appropriate format to send to the product
service.

=cut

sub transform {
    my ($self,$header,$data) = @_;

    croak "Either a product_id or a voucher_id should be supplied"
        unless $data->{product_id} // $data->{voucher_id};

    croak "This message expects one of product_id OR voucher_id"
        if $data->{product_id} && $data->{voucher_id};

    return ($header,$data);
}

1;
