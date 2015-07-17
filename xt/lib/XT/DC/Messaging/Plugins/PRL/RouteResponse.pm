package XT::DC::Messaging::Plugins::PRL::RouteResponse;
use NAP::policy "tt", 'class';

use XTracker::Logfile qw(xt_logger);

=head1 NAME

XT::DC::Messaging::Plugins::PRL::RouteResponse - Handle route responses

=head1 DESCRIPTION

Handle route response message from the conveyor hardware

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'route_response' }

=head2 handler

Receives the class name, context, and pre-validated payload.

Logs the message in the database.

=cut

use XTracker::Constants::FromDB ':prl';
use vars '$PRL__DEMATIC';

sub handler {
    my ($self, $c, $message) = @_;
    my $schema = $c->model('Schema');

    $schema->resultset('Public::ActivemqMessage')->log_message({
        message_type => $self->message_type,
        entity       => $message->{container_id}, # must exist in valid messages
        entity_type  => 'container',
        queue        => undef, # queue not available for incoming messages
        content      => $message,
    });

    my $container_id = NAP::DC::Barcode->new_from_id($message->{container_id});
    if ($container_id->isa("NAP::DC::Barcode::Container::Tote")) {
        # If it's a tote id (i.e. not a carton) then we want to find the
        # matching container in the db so we can update its arrival info
        my $container = $c->model('Schema')->resultset('Public::Container')->find( $message->{container_id} );
        # If we didn't find this container, that's a bit strange but
        # there's nothing we can do to fix it here.
        unless ($container) {
            xt_logger->warn("route_response: couldn't find matching container for ".$message->{container_id});
            return;
        }
        $container->maybe_mark_has_arrived;

        # If there is more than one related shipment, then they must all
        # be single-item DCD shipments and no further action is required.
        if ($container->related_shipment_rs->count > 1) {
            xt_logger->info("route_reponse: multiple shipments in container (container_id: $container_id)");
            return;
        }

        my $dcd_allocation = $container
            ->related_allocation_rs
            ->search({ prl_id => $PRL__DEMATIC })
            ->first;

        # If we haven't found any allocation, then again there's nothing
        # more we can do here. Maybe it's a tote containing a box/bag on
        # its way to shipping - not necessarily a sign of problems.
        unless ($dcd_allocation) {
            xt_logger->info("route_response: couldn't find any allocation currently in container ".$message->{container_id});
            return;
        }

        # Don't anything if more integration containers are expected.
        if ($dcd_allocation->integration_containers_expected) {
            xt_logger->info("route_response: no integration containers expected ".$message->{container_id});
            return;
        }

        # If there's no GOH allocation associated with this DCD allocation,
        # no further action is required.
        if ($dcd_allocation->goh_siblings->count == 0) {
            xt_logger->info("route_response: no goh siblings ".$message->{container_id});
            return;
        }

        # there could be multiple goh allocations if a size change happens which
        # leaves an old goh allocation sitting in the secondary buffers and starts
        # a new allocation.

        my @prepared_goh_allocations = grep
            { $_->is_prepared }
            $dcd_allocation->goh_siblings;

        # Don't do anything if no GOH allocations are prepared
        if (!@prepared_goh_allocations) {
            xt_logger->info("route_response: no goh allocations have been prepared ".$message->{container_id});
            return;
        }

        # If we've got to this point, we want to send a deliver message
        # for all the GOH allocations
        $_->send_deliver_message foreach (@prepared_goh_allocations);
    }
}

1;
