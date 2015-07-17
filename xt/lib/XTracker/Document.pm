package XTracker::Document;

use NAP::policy 'class';

use Moose::Util::TypeConstraints;

use XT::Data::Printer;
use XTracker::Printers;

=head1 NAME

XTracker::Document - A base class for documents in XTracker

=head1 SYNOPSIS

    package XTracker::Document::Foo;

    use NAP::policy 'class';

    extends 'XTracker::Document';

    # The path to the template
    has '+template_path' => ( default => 'foo/bar/' );

    # The printer type this document can be printed on
    sub build_printer_type { $valid_printer_type }

    # This document's filename
    sub filename { $filename; }

    # A hashref representing the data to be passed to the template
    sub gather_data { \%data }

=head1 CLASS ATTRIBUTES

=head2 printer_type

An attribute that defines what kind of printer the document expects. These are
defined in L<XT::Data::Printer::type_name>. Your subclass will have to provide
a method called C<build_printer_type> to instantiate this.

=cut

has printer_type => (
    is      => 'ro',
    isa     => enum([keys %XT::Data::Printer::type_name]),
    lazy    => 1,
    builder => 'build_printer_type',
);

sub build_printer_type { die 'Abstract method'; }

=head2 template_path

String representing the path to the template of
the document

=cut

has template_path => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    lazy     => 1,
    default  => sub { die 'you forgot to override template_path in your subclass'; },
);

=head1 METHODS

=head2 print_at_location($location, $copies) :

Print the document at the given location.

=cut

sub print_at_location {
    my ( $self, $location_name, $copies ) = @_;

    my $location = XTracker::Printers->new->location($location_name)
        or croak "Couldn't find printer location '$location_name'\n";
    my $printer = $location->printer_for_type($self->printer_type)
        or croak sprintf(
            q{Couldn't find printer type '%s' at location '%s'},
            $self->printer_type, $location->name
        );

    $printer->print_file($self->filename, $copies);
}

=head2 content

Having all the data for the document, it will send it to
the template in order to create the final document

=cut

sub content {
    my $self = shift;

    my $data = $self->gather_data;

    return unless ( $data && ( ref($data) eq 'HASH' ) );

    my $html = q{};
    XTracker::XTemplate->template->process(
        $self->template_path,
        {template_type => 'none', %{ $data } },
        \$html
    );

    return $html
}

=head2 filename() : $filename

The document's filename. You will need to subclass this.

=cut

sub filename { die 'Abstract method'; }

