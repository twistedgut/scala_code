package XT::DC::Messaging::Producer::PRL::RouteRequest;
use NAP::policy "tt", 'class';
use MooseX::Params::Validate qw( validated_list );
use Carp qw/confess/;

use XTracker::Config::Local qw( config_var );
use XT::DC::Messaging::Spec::PRL;

with 'XT::DC::Messaging::Role::Producer',
     'XT::DC::Messaging::Producer::PRL::ReadyToSendRole',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

=head1 NAME

XT::DC::Messaging::Producer::PRL::RouteRequest

=head1 DESCRIPTION

Send a request for a container to be routed to a specified destination

=head1 SYNOPSIS

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::RouteRequest' => {
            container_id => $container_id,
            destination => '/queue/test.1',
        }
    );

=head1 METHODS

=cut

has '+type' => ( default => 'route_request' );

sub message_spec {
    return XT::DC::Messaging::Spec::PRL->route_request();
}

=head2 transform

Accepts the AMQ header (which will be provided by the message producer),
and the following hashref:
    {
      container_id => Str|NAP::DC::Barcode::Container
      container_destination => Str
    }

=cut

sub transform {
    my $self = shift;
    my $header = shift;
    my ( $container_id, $container_destination ) = validated_list(
        \@_,
        # TODO: Fix container_id so it's always a NAP::DC::Barcode
        container_id => { isa => 'Str|NAP::DC::Barcode::Container' },
        container_destination => { isa => 'Str' },
    );

    my $destination_id = XT::Domain::PRLs::get_conveyor_destination_id(
        $container_destination,
    );
    my $payload = {
        container_id => $container_id,
        destination  => $destination_id,
    };

    my $message_destination = config_var('PRL', 'conveyor_queue')
        or confess 'PRL/conveyor_queue value not defined in config';
    $self->schema->resultset('Public::ActivemqMessage')->log_message({
        message_type => $self->type,
        entity       => $container_id,
        entity_type  => 'container',
        queue        => $message_destination,
        content      => $payload,
    });

    # Pack in AMQ cruft
    return $self->amq_cruft({
        header       => $header,
        payload      => $payload,
        destinations => [ $message_destination ],
    });
}

1;
