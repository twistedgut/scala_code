package XT::DC::Model::DB;
use Moose;
use namespace::autoclean;

extends 'Catalyst::Model::DBIC::Schema';

use XTracker::Database 'xtracker_schema';

__PACKAGE__->config(
    schema_class => 'XTracker::Schema',
    connect_info => { dsn => 'dummy' }
);

sub setup {
    my $self = shift;
    $self->schema( xtracker_schema() );
    $self->connect_info( $self->schema->storage->connect_info );
}

sub ACCEPT_CONTEXT {
    my ( $self, $c ) = @_;

    # Set the operator_id accessor on the schema object. We need the 'if'
    # condition as sometimes $c is the application class name, and this will
    # blow up.
    $self->schema->operator_id($c->session->{operator_id}) if ref $c;
    return $self;
}

=head1 NAME

XT::DC::Model::DB - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Rob Edwards,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
