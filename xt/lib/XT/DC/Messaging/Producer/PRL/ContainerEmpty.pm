package XT::DC::Messaging::Producer::PRL::ContainerEmpty;
use NAP::policy "tt", 'class';
use strict;
use warnings;
use Carp qw/croak/;

use XT::DC::Messaging::Spec::PRL;

with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

use MooseX::Params::Validate qw[validated_hash];

=head1 NAME

NAP::MQ::ActiveMQ::Producer::PRL::ContainerEmpty

=head1 DESCRIPTION

Sends the container_empty message from XT to a PRL

=head1 SYNOPSIS

    # standard usage, destination queues will come from config
    $factory->send(
        'PRL::ContainerEmpty' => {
            container => $container,
        }
    );

    # but you can specify the queue(s)/topic(s) explicitly if you want:

    # in case if message is sent to one destination
    $factory->send(
        'PRL::ContainerEmpty' => {
            container => $container,
            destinations => '/queue/test.1',
        }
    );

    OR

    # in case when message is sent to specified list of destinations
    $factory->send(
        'PRL::ContainerEmpty' => {
            container => $container,
            destinations => ['/queue/test.1', '/topic/test.topic'],
        }
    );


=head1 METHODS

=cut

has '+type' => ( default => 'container_empty' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->container_empty();
}

=head2 transform

Accepts the AMQ header (which will be provided by the message producer),
and following HASHREF:

    container => <Container object>,
    destinations => <arrayref of destinations where message is to be sent>

=cut

sub transform {
    my ($self, $header, $args ) = @_;

    my %valid_args = validated_hash(
        [ $args ],
        container    => {
            isa      => 'XTracker::Schema::Result::Public::Container',
        },
        destinations => {
            isa      => 'Str|ArrayRef',
            optional => 1,
        },
    );

    my $destinations = $valid_args{destinations} || $self->destinations;
    croak "No destinations given" unless $destinations;
    # handle case when user has passed one destination as a scalar
    $destinations = [$destinations] unless 'ARRAY' eq uc ref $destinations;

    my $container = $valid_args{container};

    # Pack in AMQ cruft
    return $self->amq_cruft({
        header       => $header,
        payload      => {
            container_id => $container->id . '', # force stringification
        },
        destinations => $destinations,
    });
}

1;
