package XT::DC::Messaging::Producer::Order::Reimbursement;
use NAP::policy "tt", 'class';
use Carp;

with 'XT::DC::Messaging::Role::Producer';

=head1 NAME

XT::DC::Messaging::Producer::Order::Reimbursement

=head1 DESCRIPTION

Producer for bulk reimbursement updates.

=cut

sub message_spec {
    return {
        type        => '//rec',
        required    => {
            reimbursement_id    => '//int',
        },
    };
}

has '+type' => ( default => 'bulk' );

sub transform {
    my ($self, $header, $data) = @_;

    # Return the message.
    return ( $header, $data );

}

1;

