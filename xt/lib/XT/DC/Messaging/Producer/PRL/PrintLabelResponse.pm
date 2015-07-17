package XT::DC::Messaging::Producer::PRL::PrintLabelResponse;

use Moose;
use XT::DC::Messaging::Spec::PRL;
use XTracker::Constants qw/:prl_type/;
use MooseX::Params::Validate;
use XT::Domain::PRLs;

with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithPRLs';

=head1 NAME

XT::DC::Messaging::Producer::PRL::PrintLabelResponse

=head1 DESCRIPTION

Sends C<PrintLabelResponse> message to PRL.

=head1 SYNOPSIS

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::PrintLabelResponse' => {
            message => \@array_of_allocations_and_printers
        }
    );

=head1 METHODS

=cut

has '+type' => ( default => 'print_label_response' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->print_label_response();
}

=head2 transform

Accepts the AMQ header from the message producer

=cut

sub transform {
    my ( $self, $header, $args ) = @_;
    my $message = {
        location    => $args->{location},
        allocations => $args->{message}
    };

    # Pack in AMQ cruft
    my @message_parts = $self->amq_cruft({
        header       => $header,
        payload      => $message,
        destinations =>
            [XT::Domain::PRLs::get_amq_queue_from_prl_name({
                prl_name => 'Dematic',
            })],
    });
    return @message_parts;
}

# Some message factories add a 'schema' method to the class they work on. If
# it's immutable, that fails. So don't make it immutable!
#__PACKAGE__->meta->make_immutable;

1;
