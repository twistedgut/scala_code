package XT::DC::Model::ACL;
use NAP::policy "tt", 'class';
extends 'Catalyst::Model';

with 'Catalyst::Component::InstancePerContext';

use XT::AccessControls;

sub build_per_context_instance {
    my ( $class, $c ) = @_;

    my $operator_id = $c->session->{operator_id};
    return      if ( !$operator_id );

    my $operator = $c->model('DB::Public::Operator')->find( $operator_id );

    return XT::AccessControls->new( {
        operator => $operator,
        session  => $c->session,
    } );
}
