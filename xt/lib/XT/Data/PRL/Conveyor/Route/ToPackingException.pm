package XT::Data::PRL::Conveyor::Route::ToPackingException;
use NAP::policy "tt", "class";
with (
    "XT::Data::PRL::Conveyor::Route::Role::SendMessage",
    "XT::Data::PRL::Conveyor::Route::Role::WithContainers",
);

=head1 NAME

XT::Data::PRL::Conveyor::Route::ToPackingException - A route to the Packing Exception area

=head1 DESCRIPTION

This is a Route for Containers to the Packing Exception area.


=head1 METHODS

=head2 get_route_destination($args) : $destination_name

Just return the destination name for the Packing Exception area.

=cut

sub get_route_destination {
    my $self = shift;
    return "PackingOperations/packing_exception";
}
