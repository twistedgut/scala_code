package XTracker::Printers;

use NAP::policy "tt", 'class';

use XTracker::Printers::Source;

with 'XTracker::Role::WithSchema';

=head1 NAME

XTracker::Printers - A helper class for printers

=head1 SYNOPSIS

    use XTracker::Printers;

    use NAP::policy "tt", 'class';

    my $xp = XTracker::Printers->new;

    # Get DBIC locations for a given section/with a given type
    $xp->locations_for_section($section_name);
    $xp->locations_with_type($printer_type);

    # Get a Printer::Location row (the names are unique)
    $xp->location($location_name);

=head1 ATTRIBUTES

=head2 location_rs

A shortcut to get a C<Printer::Location> resultset.

=head3 HANDLED METHODS

=over

=item locations_for_section

See L<XTracker::Schema::ResultSet::locations_for_section>.

=item locations_with_printer_type

See L<XTracker::Schema::ResultSet::locations_with_printer_type>.

=item location

See L<XTracker::Schema::ResultSet::find_by_name>.

=back

=cut

has location_rs => (
    is      => 'ro',
    isa     => 'XTracker::Schema::ResultSet::Printer::Location',
    lazy    => 1,
    builder => '_build_location_rs',
    handles => {
        locations_for_section       => 'locations_for_section',
        locations_with_printer_type => 'locations_with_printer_type',
        location                    => 'find_by_name',
    },
);
sub _build_location_rs {
    return scalar shift->schema->resultset('Printer::Location');
}
