package XT::DC::Messaging::Producer::PRL::ReadyToSendRole;

use Storable qw/dclone/;
use Moose::Role;

=head1 NAME

XT::DC::Messaging::Producer::PRL::ReadyToSendRole - provides
utilities for AMQ messages.

=head1 DESCRIPTION

Introduces method to prepare message data for actual sending
it via AMQ.

=head1 METHODS

=head2 amq_cruft

Adds C<version> to the payload, and the destination to the header,
before returning an array of pairs: the header and the payload for
each message to send.

=cut

sub amq_cruft {
    my ( $self, $args) = @_;

    # get passed parameters
    my ($header, $payload, $destinations) = @$args{qw/header payload destinations/};

    # array of result data
    my @results;

    # Version
    $payload->{'version'} = '1.0';

    # clone message into all specified destinations
    foreach my $destination (@$destinations) {
        my ($header, $payload) = (dclone($header), dclone($payload));
        $header->{destination} = $destination;
        push @results, $header, $payload;
    }

    return @results;
}

1;

=head1 SEE ALSO

L<XT::DC::Messaging::Producer::PRL::SKUUpdate>

L<XT::DC::Messaging::Producer::PRL::Advice>

=cut
