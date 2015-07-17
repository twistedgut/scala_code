package XTracker::Document::LargeSKULabel;

use NAP::policy 'class';

use XTracker::Config::Local 'config_var';
use XTracker::XTemplate;

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::LargeSKULabel - A class modelling large SKU label documents.

=head1 SYNOPSIS

    my $large_label = XTracker::Document::LargeSKULabel->new(
        colour   => $colour,
        designer => $designer,
        season   => $season,
        size     => $size,
        sku      => $sku,
    );
    $large_label->print_at_location($location, $copies);

=head1 ATTRIBUTES

=head2 printer_type : 'large_label'

=cut

sub build_printer_type { 'large_label' }

=head2 colour

=head2 designer

=head2 season

=head2 size

=head2 sku

=cut

has [ qw/colour designer season size sku/ ] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has date => ( is => 'ro', isa => 'Maybe[DateTime]' );

=head2 template_path

String representing the path to the template of
the document

=cut

has '+template_path' => (
    default => 'print/large_sku_label.tt',
);

=head1 METHODS

=head2 gather_data() : \%data

This method is used to generate a temp file that gets printed when you call
this class's parent method L<XTracker::Document::print_at_location>, don't call
it directly as it won't contain the number of copies.

=cut

sub gather_data {
    my $self = shift;

    my %data = (
        dc_name  => config_var(qw/DistributionCentre name/),
        map { $_ => $self->$_ } qw/colour copies designer season size sku date/
    );

    return \%data;
}

with qw{
    XTracker::Document::Role::CopiesInContent
    XTracker::Document::Role::TempFile
};
