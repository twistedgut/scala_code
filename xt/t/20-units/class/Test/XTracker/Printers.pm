package Test::XTracker::Printers;

use NAP::policy "tt", qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
}

use XT::Data::Printer;
use XTracker::Printers;

=head1 NAME

Test::XTracker::Printers

=cut

sub test_locations_for_section : Tests {
    my $self = shift;

    # Define printers in two different sections
    my %section = ( expected => 'item_count', other => 'stock_in' );
    my $printers = [map {
        +{ %{$self->default_printer}, section => $_ }
    } values %section];

    $self->schema->txn_dont(sub{
        $self->new_printers_from_arrayref($printers)->populate_if_updated;

        my $xp = XTracker::Printers->new;
        # Check our sub returns locations belonging to the expected section only
        isa_ok( my $location_rs = $xp->locations_for_section($section{expected}),
            'XTracker::Schema::ResultSet::Printer::Location' );
        is( $_->section->name, $section{expected},
            "section '$section{expected}' matches expected"
        ) for $location_rs->all;
    });
}

sub test_location : Tests {
    my $self = shift;

    my $printer = $self->default_printer;
    $self->schema->txn_dont(sub{
        $self->new_printers_from_arrayref([$printer])->populate_if_updated;

        my $xp = XTracker::Printers->new;
        isa_ok( my $location = $xp->location($printer->{location}),
            'XTracker::Schema::Result::Printer::Location' );
        is( $location->name, $printer->{location}, 'found expected location' );
        is( $xp->location($printer->{location} . q{ }), undef,
            "Couldn't find inexistent printer" );
    });
}

sub test_locations_with_printer_type : Tests {
    my $self = shift;

    # Define printers with two different types
    my %type = ( expected => 'large_label', other => 'small_label' );
    my $printers = [map {
        +{ %{$self->default_printer}, type => $_ }
    } values %type];

    $self->schema->txn_dont(sub{
        $self->new_printers_from_arrayref($printers)->populate_if_updated;

        my $xp = XTracker::Printers->new;
        # Check our sub returns locations with the expected type only
        isa_ok( my $location_rs = $xp->locations_with_printer_type($type{expected}),
            'XTracker::Schema::ResultSet::Printer::Location' );
        ok( $_->search_related('printers',
                { 'type.name' => $type{expected}, },
                { join => 'type' }
            )->count,
            "location has expected type '$type{expected}'"
        ) for $location_rs->all;
    });
}
