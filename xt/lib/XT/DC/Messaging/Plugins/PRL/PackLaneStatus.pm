package XT::DC::Messaging::Plugins::PRL::PackLaneStatus;

use Data::Dumper;
use NAP::policy "tt", 'class';

=head1 NAME

XT::DC::Messaging::Plugins::PRL::PackLaneStatus - Handle pack_lane_status
message from PRL

=head1 DESCRIPTION

Handle pack_lane_status from PRL

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'pack_lane_status' }

=head2 handler

Receives the class name, context, and pre-validated payload.

=cut

sub handler {
    my ( $self, $c, $msg ) = @_;
    $c->log->debug('Received ' . $self->message_type . ' with: ' . Dumper( $msg ) );

    my $pack_lane = $c->model('Schema')->resultset('Public::PackLane')
        ->find_by_status_identifier($msg->{spur});
    $pack_lane->update( { container_count => $msg->{count} } );

    return;
}
