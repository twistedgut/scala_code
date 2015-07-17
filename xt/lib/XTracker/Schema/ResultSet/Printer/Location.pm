package XTracker::Schema::ResultSet::Printer::Location;

use NAP::policy;

use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Printer::Location

=head1 METHODS

=head2 locations_for_section($section) : $location_rs || @locations

Returns the locations for the given section ordered by location name.

=cut

sub locations_for_section {
    my ( $self, $section ) = @_;

    my $me = $self->current_source_alias;

    return $self->search(
        { 'section.name' => $section },
        { join => 'section', order_by => "${me}.name" },
    );
}

=head2 locations_with_printer_type($printer_type) : $location_rs || @locations

Return a Printer::Location set with the given printer type ordered by location
name.

=cut

sub locations_with_printer_type {
    my ( $self, $printer_type ) = @_;

    my $me = $self->current_source_alias;
    return $self->search(
        { 'type.name' => $printer_type },
        { join => { printers => 'type' }, order_by => "${me}.name" }
    );
}

=head2 find_by_name($location_name) : $location_row

Pass a C<$location_name> to get a DBIC row.

=cut

sub find_by_name {
    my ($self,$name) = @_;
    my $me = $self->current_source_alias;
    return $self->find({"${me}.name" => $name});
}
