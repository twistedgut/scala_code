package XT::DC::Messaging::Producer::PRL::Deliver;

use NAP::policy 'tt', 'class';
use Carp qw/confess/;

use XT::DC::Messaging::Spec::PRL;

with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

use XTracker::Config::Local;

=head1 NAME

XT::DC::Messaging::Producer::PRL::Deliver

=head1 DESCRIPTION

Sends C<Deliver> message to PRL.

=head1 SYNOPSIS

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::Deliver' => {
            allocation_id => $allocation_id,
        }
    );

Where C<$prepare_data> is data structure that satisfies C<prepare> from
L<XT::DC::Messaging::Spec::PRL>.

=head1 METHODS

=cut

has '+type' => ( default => 'deliver' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->deliver;
}

=head2 transform

Accepts the AMQ header (which will be provided by the message producer),
and following HASH ref:

    allocation : The allocation to ask PRL to deliver (DBIC object).

Notes:

All possible exceptions occurring while validating passed data structure
are propagated further.

=cut

sub transform {
    my ($self, $header, $args) = @_;

    confess 'Expected a hashref of arguments' unless 'HASH' eq ref $args;

    my $allocation = $args->{allocation}
        // confess 'Expected a value for $args->{allocation}';

    # Message body
    my $payload = {
        allocation_id => $allocation->id,
    };

    my $destinations = [$allocation->prl->amq_queue];

    return $self->amq_cruft({
        header       => $header,
        payload      => $payload,
        destinations => $destinations,
    });
}

__PACKAGE__->meta->make_immutable;
