package XTracker::Barcode;

use strict;
use warnings;

use Carp;
use Perl6::Export::Attrs;
use Barcode::Code128 ();
use XTracker::PrintFunctions;

=head1 NAME

XTracker::Barcode

=head1 FUNCTIONS

=head2 create_barcode($name, $value, $font_size, $scale, $show_text, $height) : $filename|undef

Generate a label file with a C<.png> extension in the barcode directory.
Returns the filename on success or undef if it couldn't create it.

=head3 NOTE

Use this function sparingly (it'd be nice to deprecate it if we can) as it
creates barcodes in the print_docs/barcode directory. Barcodes are completely
reproducible (just pass it a string), so we shouldn't need to keep these any
longer than we need for our document creation. Consider using the other
functions in this module if you don't want your barcode to persist.

=cut

sub create_barcode :Export(:DEFAULT) {
    my ( $name, $value, $font_size, $scale, $show_text, $height ) = @_;

    my $pngfile = XTracker::PrintFunctions::path_for_print_document({
        document_type => 'barcode',
        id => $name,
        extension => 'png',
    });
    ### we've got our image - don't need to make a new one do we!
    return $pngfile if -e $pngfile;

    my $png = generate_png($value, {
        name      => $name,
        font_size => $font_size,
        scale     => $scale,
        show_text => $show_text,
        height    => $height,
    });
    generate_file($pngfile, $png);

    return -e $pngfile ? $pngfile : undef;
}

=head2 generate_png($value, {:$font=small, :$scale=2, :$show_text=0, :$height=auto_size}) : $png

Generate a barcode with the given arguments.

=cut

sub generate_png :Export(:DEFAULT) {
    my ($value, $args) = @_;

    # If not specified, height and width are set to a bit bigger than the
    # barcode image, see Barcode::Code128 docs under 'png'
    my $barcode = Barcode::Code128->new;
    $barcode->option("font",$args->{font_size}||'small');
    $barcode->option("border",1);
    $barcode->option("font_align","center");
    $barcode->option("scale", $args->{scale}||2);
    $barcode->option("show_text", $args->{show_text}||0);
    $barcode->option("height", $args->{height}); # auto-size if undef

    return $barcode->png($value);
}

=head2 generate_file($filename, $png) : $filename

Print the given C<$png> string to the given C<$filename>.

=cut

sub generate_file :Export(:DEFAULT) {
    my ($pngfile, $png) = @_;

    open(my $png_fh, ">", "$pngfile") or croak "Couldn't open file for writing: $!";
    binmode($png_fh);
    print $png_fh $png;
    close($png_fh);

    return $pngfile;
}

1;
