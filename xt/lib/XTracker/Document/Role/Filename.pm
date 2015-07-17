package XTracker::Document::Role::Filename;

use NAP::policy 'role';

use File::Spec;

requires qw( content basename );


=head1 NAME

XTracker::Document::Role::Filename

=head1 DESCRIPTION

=head1 SYNOPSIS

    package MyPackage;

    use NAP::policy 'class';

    with 'XTracker::Document::Role::Filename';

=head1 DESCRIPTION

Consuming this role in your class, it will provide the
'filename' method that will generate the absolute path
for your document.

=head1 METHODS

=head2 filename

Returns the filename for printing. Note that this will write an html file, but
due to using the L<XTracker::Document::Role::PrintAsPDF> role this will be
first converted to a C<.pdf> file and then a C<.ps> file for printing. If you
want to consume this role in your class please make sure that you have set the
reader as 'directory' on the directory attribute
Courtesy: Darius

=cut

sub filename {
    my $self = shift;

    # Some attributes needs to be initialized so that is why
    # we run this before setting our filename as it initialises
    # for example '_type' attr
    my $content = $self->content;

    my $dir = $self->directory
        or die sprintf( 'No directory associated with this file: %s', $self->basename );

    my $filename = File::Spec->catfile(
        $self->directory,
        sprintf('%s.html', $self->basename)
    );

    open my $fh, '>', $filename
        or die "Couldn't open '$filename': $!\n";
    binmode $fh;

    print $fh $content;
    close $fh;

    return $filename;
}
