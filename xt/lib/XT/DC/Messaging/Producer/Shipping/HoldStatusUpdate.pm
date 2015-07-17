package XT::DC::Messaging::Producer::Shipping::HoldStatusUpdate;
use NAP::policy "tt", 'class';
use DateTime;

with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'shipment_hold_status_info');
has '+set_at_type' => ( default => 0 );

=head1 NAME

XT::DC::Messaging::Producer::Shipping::HoldStatusUpdate

=head1 DESCRIPTION

Producer for updates to an shipment's hold status.

=cut

sub message_spec {
    return {
        type => '//rec',
        required => {
            order_number     => '//str',
            shipment_id      => '//str',
            shipment_status  => '//str',
            brand            => '//str',
            region           => '//str',
            timestamp        => '//str',
            hold_reason      => '//str',
            comment          => '//str'
        }
    };
}

=head2 transform

Takes a hold order update object as input and produces a message
 for mercury to forward to Salesforce

=cut

sub transform {
    my ($self, $header, $data) = @_;

    my $date = DateTime->now()->set_time_zone("UTC")->strftime("%FT%T%z");
    $data->{timestamp} = $date;
    # Return the message.
    return ( $header, $data );
}

1;

