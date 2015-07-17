package XTracker::Document::Role::StaticDir;

use NAP::policy 'role';

use Digest::MD5 qw( md5_hex );

use File::Path qw( make_path );
use File::Spec;

use MooseX::Types::Path::Class qw( Dir );

use XTracker::Config::Local qw( config_var );
use XTracker::DBEncode qw( encode_it );

requires qw( document_type basename );

=head1 NAME

XTracker::Document::Role::StaticDir

=head1 DESCRIPTION

=head1 SYNOPSIS

    package MyPackage;

    use NAP::policy 'class';

    with 'XTracker::Document::Role::StaticDir';

=head1 DESCRIPTION

If the document need to remain on disk for further printings,
add this role to the document class.
B<Note>
This might be just a temporary class until all the printers are
moved to the new format. But until then we will keep it this way, in
order to not broke other places that use existing documents to print.

The code is ported from  XTracker::PrintFunctions::path_for_print_document
Code can be added on top of this, but please be sure you port only the needed
code

=head1 ATTRIBUTES

=head2 static_dir: Path::Class::Dir

Static directory to place the created documents

=cut

has static_dir => (
    is        => 'ro',
    isa       => Dir,
    lazy      => 1,
    coerce    => 1,
    builder   => '_build_dir',
    reader    => 'directory',
);

sub _build_dir {
    my $self = shift;

    my $document_dir = File::Spec->catdir(
        # Base directory
        config_var( qw( SystemPaths document_dir ) ),
        # Document type...
        $self->document_type,
        # First 2 characters of MD5 hash of basename
        substr( md5_hex( encode_it($self->basename) ), 0, 2 )
    );

    unless ( -d $document_dir ) {
        make_path( $document_dir, { mode => oct(775), verbose => 0 } )
            or die "Couldn't create print documents subdirectory '$document_dir': $!";
    }

    return $document_dir;
}
