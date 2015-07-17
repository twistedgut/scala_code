package XT::DC::Messaging::Spec::Reimbursement;

use Moose;

=head1 NAME

XT::DC::Messaging::Spec::Reimbursement

=head1 DESCRIPTION

Queue spec for bulk reimbursement updates.

=cut

sub bulk {
    return {
        type        => '//rec',
        required    => {
            reimbursement_id    => '//int',
        },
    };
}

__PACKAGE__->meta->make_immutable;

1;
