package Test::Role::Printers;

use NAP::policy 'role';

use Data::UUID;

use XT::Data::Printer;
use XTracker::Printers::Populator;
use XTracker::Printers::Source::ArrayRef;

with 'XTracker::Role::WithSchema';

=head1 NAME

Test::Role::Printers - A role with some helpful test methods for printers

=head1 SYNOPSIS

    package Foo;

    use NAP::policy qw/tt class/;

    with 'Test::Role::Printers';

    sub populate_printers {
        my $self = shift;

        # Create a default printer
        my $printer = $self->default_printer;

        # Generate a new XTracker::Printers::Populator passing an arrayref of
        # printer hashes
        my $xpp = $self->new_printers_from_arrayref([$printer]);

        # Populate your printer data
        $xpp->populate_if_updated;
    }

=head1 METHODS

=head2 new_printers_from_arrayref(\@printers) : XTracker::Printers

Pass this method an arrayref of hashrefs with printer data and you get back a
L<XTracker::Printers> object that you can use to populate your printer tables.

=cut

sub new_printers_from_arrayref {
    my ( $self, $printers ) = @_;
    return XTracker::Printers::Populator->new(
        source => XTracker::Printers::Source::ArrayRef->new(source => $printers)
    );
}

=head2 default_printer() : HashRef

Returns a hashref representing a valid printer.

=cut

sub default_printer {
    my $ug = Data::UUID->new;
    return {
        location => $ug->create_str,
        lp_name  => $ug->create_str,
        section  => ${XT::Data::Printer::sections}->[0],
        type     => [(sort keys %XT::Data::Printer::type_name)]->[0],
    };
}

=head2 location_with_type($printer_type) : $location_row

Return any DBIC printer.location row that has the given printer type.

=cut

sub location_with_type {
    my ( $self, $printer_type ) = @_;

    return $self->schema
        ->resultset('Printer::Location')
        ->locations_with_printer_type($printer_type)
        ->search(undef, { rows => 1 })
        ->single;
}
