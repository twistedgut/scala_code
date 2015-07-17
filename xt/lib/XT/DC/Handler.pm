package XT::DC::Handler;
use NAP::policy "tt", 'class';

use MooseX::Types::Moose qw/Int/;

has context => (
    is      => 'ro',
    isa     => 'XT::DC',
);

has schema => (
    is      => 'ro',
    isa     => 'XTracker::Schema',
    writer  => 'set_schema',
);

has department_id => (
    is      => 'ro',
    isa     => Int,
    writer  => 'set_department_id',
);

has operator_id => (
    is      => 'ro',
    isa     => Int,
    writer  => 'set_operator_id',
);

no Moose;

sub BUILD {
    my $self = shift;

    $self->set_schema(
        $self->context->model('DB')->schema
    );
    $self->set_department_id(
        $self->context->session->{department_id} // -1
    );
    $self->set_operator_id(
        $self->context->session->{operator_id} // -1
    );

    $self->_populate_default_stash;
}

sub _populate_default_stash {
    my $self    = shift;
    my $c       = $self->context;

    $c->stash(
        name            => 'Default Name',
        username        => 'Default Username',

        section         => q{},
        subsection      => q{},
        subsubsection   => q{},
    );
}
