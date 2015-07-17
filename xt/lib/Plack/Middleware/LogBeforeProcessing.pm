package Plack::Middleware::LogBeforeProcessing;

use strict;
use warnings;

use parent 'Plack::Middleware';
use Plack::Util::Accessor   qw( json_obj );
use JSON;
use Clone 'clone';
use Try::Tiny;

=head1 NAME

Plack::Middleware::LogBeforeProcessing

=head1 DESCRIPTION

Plack Middleware to log request before processing

=head2 prepare_app

Basic preparation done once only at process start. Here we just
initialise the JSON object.

=cut

sub prepare_app {
    my $self = shift;

    my $json = JSON->new->canonical->pretty;
    $self->json_obj($json);
}

=head2 call

Called for each request processed by the application, clones $env and,
after removing the logger from the clone, logs the cloned $env.

=cut

sub call {
    my ( $self, $env ) = @_;

    if ( defined $env->{'psgix.logger'} ) {

        # clone $env and remove the logger and those psgi/psgix bits we don't need
        try {
            my $clone_env = clone( $env );
            delete @{$clone_env}{qw| psgix.logger
                                     psgi.errors
                                     psgi.input
                                     psgix.io
                                   |};

            $env->{'psgix.logger'}->( {
                level   => 'info',
                message => $self->json_obj->encode($clone_env),
            } );
        } catch {
            $env->{'psgix.logger'}->( {
                level   => 'warn',
                message => "Cannot log Plack Request details - $_",
            } );
        };
    }

    return $self->app->($env);
}

1;
