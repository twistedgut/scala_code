package XT::DC::Messaging::Model::Schema;

use Moose;
extends 'Catalyst::Model::DBIC::Schema';

use XTracker::Database 'xtracker_schema';

__PACKAGE__->config(
    schema_class => 'XTracker::Schema',
    connect_info => { dsn => 'dummy' }
);

=head2 setup() :

Override setup() in parent class, see docs there.

=cut

sub setup {
    my $self = shift;
    $self->schema( xtracker_schema() );
    $self->connect_info( $self->schema->storage->connect_info );
}

1;
