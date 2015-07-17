package XT::DC::Messaging::Producer::PRL::Advice;

use Moose;

use Carp qw/croak/;
use XT::DC::Messaging::Spec::PRL;

with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs';

use XTracker::Constants '$DEFAULT_TOTE_COMPARTMENT_CONFIGURATION';

=head1 NAME

XT::DC::Messaging::Producer::PRL::Advice

=head1 DESCRIPTION

Sends C<Advice> message to PRL.

=head1 SYNOPSIS

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::Advice' => {
            destinations => ['test.1'],
            advice => $advice_data,
        }
    );

OR

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::Advice' => {
            advice => $advice_data,
        }
    );

Where C<$advice_data> is data structure that satisfies C<advice> from
L<XT::DC::Messaging::Spec::PRL>.

In order to send Advice message it recommended to use C<send_advice_to_prl>
from L<XTracker::Schema::Result::Public::PutawayPrepContainer>:

    $putaway_prep_container = $schema->resultset('PutawayPrepContainer')
        ->find_in_progress({ container_id => $container_id });

    $putaway_prep_container->send_advice_to_prl;

=head1 METHODS

=cut

has '+type' => ( default => 'advice' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->advice();
}

=head2 transform

B<Description>

Accepts the AMQ header (which will be provided by the message producer),
and following HASH ref:

=over

=item destinations

ARRAY ref or simple scalar with string of destination(s) where message is to be sent.

=item advice

Data structure representing C<Advice> message, it should satisfy definition from
L<XT::DC::Messaging::Spec::PRL> C<advice>.

B<Note>

It allows to omit C<container_fullness> entry for advice - default one of '100%'
is used. Also C<compartment_configuration> is populated by default one - 'TOTE'.

=back

B<Notes>

All possible exceptions occurring while validating passed data structure are propagated
further.

=cut

sub transform {
    my ( $self, $header, $args ) = @_;

    croak 'Arguments are incorrect' unless 'HASH' eq uc ref $args;

    my $destinations = $args->{destinations};
    croak 'Mandatory parameter "destinations" was omitted'
        unless $destinations;

    # handle case when user's passed one destination as a scalar
    $destinations = [$destinations] unless 'ARRAY' eq uc ref $destinations;

    my $message = $args->{advice};
    croak 'Mandatory parameter "advice" was omitted'
        unless 'HASH' eq uc ref ($message||'');

    # by default populate container fullness as just empty string
    # (for more details refer to XTracker config section
    # "PRLs > putaway_prep_container_specific_questions > container_fullness")
    $message->{container_fullness} //= '';

    # populate default configuration of container
    $message->{compartment_configuration} //=
        $DEFAULT_TOTE_COMPARTMENT_CONFIGURATION;

    # Pack in AMQ cruft
    return $self->amq_cruft({
        header       => $header,
        payload      => $message,
        destinations => $destinations,
    });
}

__PACKAGE__->meta->make_immutable;

1;
