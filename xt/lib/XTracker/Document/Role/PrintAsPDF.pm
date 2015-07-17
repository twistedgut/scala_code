package XTracker::Document::Role::PrintAsPDF;

use NAP::policy 'role';

use PDF::WebKit;
use XTracker::Config::Local qw( config_var app_root_dir );

=head1 NAME

XTracker::Document::Role::PrintAsPDF - Convert html to PDF and print

=head1 DESCRIPTION

Consume this role if you have an html document that you want to print, and you
want to print its PDF representation.

This role works by applying an C<around> statement modifier to the C<filename>
method to convert the html to the pdf document, which we then return.

=head2 NOTE

This means that the html file won't be returned when you call C<filename>.  I
don't know if this is always the desired behaviour, so something to think
about.

=head1 REQUIRED METHODS

=head2 filename

=cut

# The logic for this is taken from
# XTracker::PrintFunctions::create_pdf_file_with_webkit. Look at removing once
# we've ported everything to use document classes.
around 'filename' => sub {
    my ($orig, $self, @data) = @_;

    my $in_file = $self->$orig(@data);

    (my $out_file = $in_file) =~ s/\.html$/.pdf/;

    my $dummy_html = app_root_dir . 'root/base/print/dummy_for_webkit.html';
    my %print_options = (
        encoding      => 'UTF-8',
        margin_top    => 10,
        margin_bottom => 10,
        margin_left   => 8,
        margin_right  => 8,
        header_spacing  => 5,
        footer_spacing  => 5,
        header_html  => $dummy_html,
        footer_html  => $dummy_html,
    );

    my $orientation;
    if (defined($orientation)) {
        $print_options{'--orientation'} = $orientation;
    }

    # set appropriate page size for DC
    $print_options{page_size} = config_var('DistributionCentre', 'paper_size');

    my $webkit = PDF::WebKit->new($in_file, %print_options);

    $webkit->to_file($out_file) || die("Unable to create file $out_file");

    return $out_file;
};
