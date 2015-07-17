package XT::Data::PRL::Conveyor::Route::ToIntegration;
use NAP::policy "tt", "class";
with (
    "XT::Data::PRL::Conveyor::Route::Role::SendMessage",
    "XT::Data::PRL::Conveyor::Route::Role::WithContainers",
);
use Moose::Util::TypeConstraints;

has integration_prl_row => (
    is      => "rw",
    isa     => "Maybe[XTracker::Schema::Result::Public::Prl]",
);

has allocation_row => (
    is      => "rw",
    isa     => "Maybe[XTracker::Schema::Result::Public::Allocation]",
);

=head1 NAME

XT::Data::PRL::Conveyor::Route::ToIntegration - A route to Integration

=head1 DESCRIPTION

This is a Route for Containers to an integration area


=head1 METHODS

=head2 get_route_destination($allocation_rows) : $destination_name | undef

For now, the only place we integrate is at the GOH Integration lane,
so this will either return that or undef.

=cut

sub get_route_destination {
    my ($self, $allocation_rows) = @_;

    return undef unless $self->find_integration_prl($allocation_rows);

    return $self->integration_prl_row->default_integration_destination;
}

=head2 find_integration_prl ($allocation_rows) : boolean

If the container should go to integration, return a true value and set
integration_prl_row and allocation_row appropriately.

Return false if it shouldn't.

=cut

sub find_integration_prl {
    my ($self, $allocation_rows) = @_;

    # Sanity check - for now we would only be sending one container at a
    # time to integration, so if something has called this with more than
    # one container, we shouldn't integrate.
    return 0 unless ($self->container_rows && (scalar @{$self->container_rows} == 1));
    my $container_row = $self->container_rows->[0];

    # Only single item shipments can be grouped in the same container, so
    # unless this container has exactly one allocation it can't be part of
    # a multi-prl shipment anyway, so no point checking any further.
    return 0 unless $allocation_rows;
    return 0 if ((scalar @{$allocation_rows}) != 1);
    $self->allocation_row($allocation_rows->[0]);

    if (my $prl = $self->allocation_row->prl_for_integration) {
        $self->integration_prl_row($prl);
        return 1;
    }

    return 0;
}

