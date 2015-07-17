package Emitter;
# vim: ts=8 sts=4 et sw=4 sr sta

use Moose;
use MooseX::Types::Moose qw/HashRef/;
use Data::Dump qw/pp/;

use Module::Pluggable
    search_path    => 'Emitter',
    sub_name        => 'available_emitters',
    require         => 1;


#has 'config' => (
#    is          => 'ro',
#    isa         => 'HashRef',
#    required    => 1,
#);

has 'emit_to' => (
    is          => 'ro',
    required    => 1,
);

has 'plugins' => (
    is          => 'ro',
    required    => 1,
);

has 'namespace' => (
    is          => 'ro',
    lazy_build  => 1,
);

has 'emitters' => (
    is          => 'ro',
    isa         => 'HashRef',
    init_arg    => undef,
    default     => sub { {} },
);

sub BUILD {
    my($self) = @_;

    my $nspace = $self->namespace;

    foreach my $module ($self->available_emitters) {
        (my $label = $module) =~ s/^$nspace\:{2}//;

        # pull out the config relevant
        my $plugin_config = (defined $self->plugins->{$label})
            ? $self->plugins->{$label} : undef;


        # instantiate with local config
        my $emitter = (defined $plugin_config) ?
            $module->new($plugin_config) : $module->new();

        die __PACKAGE__ .": 'emit' method doesn't exist in $module"
            if (!$emitter->can('emit'));

        $self->emitters->{$label} = $emitter;

    }

    return;

}

sub _build_namespace {
    my($self) = @_;

    my $ref = ref($self);

    return $ref;
}

sub emit {
    my($self,$stuff) = @_;

    my $list = $self->emit_to;

    # make it into an array ref if its a scalar
    if (not ref($list)) {
        $list = [ $list ];
    }

    foreach my $foo_foo (@{$list}) {
        my $emitter = (defined $self->emitters->{$foo_foo})
            ? $self->emitters->{$foo_foo} : undef;

        if ($emitter) {
            $emitter->emit($stuff);
        }
    }
}

1;
