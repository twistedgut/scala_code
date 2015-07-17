package XT::Role::DC;

use Moose::Role;

use XTracker::Config::Local qw( config_var );

has dc => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => config_var('DistributionCentre', 'name'),
);

1;

__END__

=head1 NAME

XT::Role::DC

=head1 SYNOPSIS

    use Moose;
    with 'XT::Role::DC';

    my $dc = $self->dc;

=head1 DESCRIPTION

Role to provide a dc attribute which can be used to determine which DC the code
is running in.

=head1 ATTRIBUTES

=head2 dc

Lazily built from the value in the config file.

=head1 AUTHOR

Adam Taylor <adam.taylor@net-a-porter.com>
