package XT::DC::Messaging::Producer::PRL::StockCheck;

use Moose;
use Carp qw/croak/;
use XT::DC::Messaging::Spec::PRL;

with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithPRLs';

=head1 NAME

XT::DC::Messaging::Producer::PRL::Stockcheck

=head1 DESCRIPTION

Sents C<stock_check> message to PRL.

=head1 SYNOPSIS

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::Advice' => {
         }
    );

=head1 METHODS

=cut

has '+type' => ( default => 'stock_check' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->stock_check();
}

sub transform {
    my ( $self, $header, $args ) = @_;

    croak 'Arguments are incorrect' unless 'HASH' eq uc ref $args;

    my $destinations = $args->{destinations};
    croak 'Mandatory parameter "destinations" was omitted'
        unless $destinations;

    # handle case when user's passed one destination as a scalar
    $destinations = [$destinations] unless 'ARRAY' eq uc ref $destinations;

    my $message = $args->{stock_check};
    croak 'Mandatory parameter "stock_check" was omitted'
        unless 'HASH' eq uc ref ($message||'');

    # Pack in AMQ cruft
    return $self->amq_cruft({
        header       => $header,
        payload      => $message,
        destinations => $destinations,
    });
}

__PACKAGE__->meta->make_immutable;

1;
