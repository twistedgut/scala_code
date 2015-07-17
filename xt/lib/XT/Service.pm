package XT::Service;

use strict;
use warnings;
use Class::Std;

use Readonly;

use base qw/ Exporter Helper::Class::Schema /;

Readonly our $OK        => 1;
Readonly our $FAILED    => 0;

our @EXPORT_OK = ( qw/$OK $FAILED/ );

{

    my %handler_of          :ATTR( get => 'handler', set => 'handler',                   init_arg => 'handler' );

    sub get_handler_schema {
        my($self) = @_;
        my $handler = $self->get_handler;

        return $handler->{schema};
    }

    sub execute {
        my($self,$method) = @_;
        $method = 'process' if (not defined $method);

        # check if method exists;
        if (not $self->can($method)) {
            die __PACKAGE__ .": Trying to call '$method' on ". ref($self);
        }

        return $self->$method();
    }

    sub remap_hash {
        my($self,$source,$target,$mapping) = @_;

        die __PACKAGE__ .":remap_hash - source is not hash ref"
            if (ref($source) ne 'HASH');

        die __PACKAGE__ .":remap_hash - target is not hash ref"
            if (ref($target) ne 'HASH');

        die __PACKAGE__ .":remap_hash - mapping is not hash ref"
            if (ref($mapping) ne 'HASH');

        foreach my $key (keys %{$mapping}) {
            if (defined $source->{$key}) {
                $target->{ $mapping->{$key} } = $source->{$key};
            }
        }

        return $target;
    }
}
1;

__END__

=pod

=head1 NAME

XT::Tier::Service;

=head1 AUTHOR

Jason Tang

=cut

