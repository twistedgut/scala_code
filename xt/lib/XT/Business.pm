package XT::Business;
use Moose;
use Module::Pluggable::Object;
use MooseX::Types::Moose qw/Undef Str ArrayRef HashRef Bool/;

has 'plugin_for' => (
    is          => 'ro',
    isa         => HashRef,
    init_arg    => undef,
    default     => sub { {} },
);
has 'instance_of' => (
    is          => 'ro',
    isa         => HashRef,
    init_arg    => undef,
    default     => sub { {} },
);
has 'namespace' => (
    is          => 'ro',
    isa         => Str,
    default     => sub{ 'XT::Business::Logic' },
);

has 'plugin_prefix' => (
    is          => 'rw',
    isa         => Str,
    default     => sub{ '' },
);
has search_path => (
    is          => 'rw',
    isa         => ArrayRef|Str,
    default     => sub { [qw/XT::Business::Logic/] },
    required    => 1,
);


sub BUILD {
    my $self = shift;

    my $finder = Module::Pluggable::Object->new(
        search_path     => $self->search_path,
#        sub_name        => 'available_plugins',
        require         => 1,
    );


    my $namespace       = $self->namespace;
    my $plugin_prefix  = $self->plugin_prefix;
    my $to_chop         = "${namespace}${plugin_prefix}";

    foreach my $plugin ($finder->plugins) {
        my $shortname = $plugin;
        $shortname =~ s/^${to_chop}:://;

        if (not $plugin->isa('XT::Business::Base')) {
            confess __PACKAGE__ .": plugin '$shortname' needs to implement "
                ."'XT::Business::Base'";
        }

        if (exists $self->plugin_for->{$shortname}) {
            confess __PACKAGE__ .": plugin already exists for '$shortname'";
        }

        $self->plugin_for->{$shortname} = $plugin;
    }

    return;
}

sub find {
    my($self,$label) = @_;
    my $name = $self->plugin_for->{$label} || undef;

    if (not defined $label) {
        warn __PACKAGE__ .": Cannot find plugin for '$label'";
        return;
    }

    # use an existing instance or create a new one.. and keep ref to it
    my $instance = $self->instance_of->{$label}
        || (defined $name ? $name->new :undef);

    if ($instance && (not defined $self->instance_of->{$label})) {
        $self->instance_of->{$label} = $instance;
    }

    return $instance;
}

=head2 find_plugin

Given dbix channel row, and the name of the component ie 'OrderImporter' it will
see if there is a module for the given business/component combo. Returns undef
otherwise

=cut
sub find_plugin {
    my($self,$channel,$component) = @_;

    if (ref($channel) !~ /Public::Channel$/) {
        die __PACKAGE__ .": parameter is not dbix channel row";
    }

    return $self->find(
        $channel->business->short_name
        ."::" .$component);


}
1;
