package XT::DC::Model::Returns;

use Moose;
extends 'Catalyst::Model';

with 'Catalyst::Component::InstancePerContext';
use XTracker::Role::WithAMQMessageFactory;
use XT::Domain::Returns;

sub build_per_context_instance {
    my ($self, $c) = @_;

    my $schema = $c->model('DB')->schema;
    my $msg_factory = XTracker::Role::WithAMQMessageFactory->build_msg_factory;

    return XT::Domain::Returns->new(
        schema => $schema,
        msg_factory => $msg_factory
    );
}

1;
