package XT::DC::Messaging::Model::Returns;

use Moose;

use XT::Domain::Returns;

extends 'Catalyst::Model';
with 'Catalyst::Component::InstancePerContext';

sub build_per_context_instance {
    my ($class, $c) = @_;

    return XT::Domain::Returns->new(
        schema => $c->model('Schema')->schema,
        msg_factory => $c->model('MessageQueue'),
        requested_from_arma => 1,
    );
}

1;
