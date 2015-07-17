package Test::XTracker::PrintDocs;

=head1 NAME

Test::XTracker::PrintDocs

=head2 DESCRIPTION

Monitor the printer-output and return documents as data

=head2 SYNOPSIS

 # Start monitoring
 my $print_directory = Test::XTracker::PrintDocs->new();

 ... do some stuff ...

 # See what's been added - returns Test::XTracker::PrintDocs::File objects
 my @docs = $print_directory->new_files;

 # Those have some useful methods
 for my $doc ( @docs ) {
    print "Filename: " . $doc->filename  . "\n"; # Relative to printdoc dir
    print "Filetype: " . $doc->file_type . "\n"; # Non-numeric part of filename
    print "File ID : " . $doc->file_id   . "\n"; # Numeric part of filename
    print "Content : " . $doc->content   . "\n"; # File contents as string

    # File contents as data structure, courtesy of Test::XTracker::Client
    print Dumper $doc->as_data;
 }

=cut

use strict;
use warnings;
use File::Slurp;
use URI;
use Moose;

use XTracker::Config::Local qw/config_var/;
use JSON;
use File::Spec;
use File::Basename;
use XTracker::PrintFunctions;

extends 'Test::XTracker::Artifacts';

=head1 Test::XTracker::PrintDocs METHODS

=head2 new

 my $dir = Test::XTracker::PrintDocs->new( read_directory => 'optional' );

Instantiate our monitor. All existing files in the print directory are counted
as 'seen', so that only new files are returned by C<new_files>.

=cut

# Configuration

has '+read_directory' => (
    required => 0,
    default => sub {[
        # At some point we might want to consider having two monitors, one for
        # the temp and another for the kept documents, but this will do for now
        map { config_var('SystemPaths',$_) } qw/document_dir document_temp_dir/
    ]},
);

has '+important_events' => (
    required => 0,
    default => sub { ['create', 'modify'] },
);

has '+filter_regex' => (
    required => 0,
    default => sub { qr/\.html$/ },
);

has '+exclude' => (
    required => 0,
    default => sub { [ qr/\/printjobs\// ] }, # do not watch for files in the printjobs directory
);

=head2 new_files

 my @docs = $dir->new_files;

Returns a list representing new files in the monitored directory since you last
called this method (or since the object was instantiated). Only files that look
like printer docs will be returned (that is, they match: C</(.+)\-(\d+)\.html/>)
and files will be returned as C<Test::XTracker::PrintDocs::File> objects.

=head2 wait_for_new_files

 my @docs = $dir->wait_for_new_files(
    seconds      => 5, # How many seconds to wait for
    files        => 2, # How many new files we're looking for
 );

Some of the work of DCEA causes different processes to write print files. This
can lead to race conditions. This method loops around C<new_files>, and returns
whatever it found when either condition is true.

Why two conditions? Because a naïve implementation would just return when it
had found a file, and we might be expecting more than one file. We also don't
want to wait forever (or longer than we have to) for files.

C<seconds> defaults to 30, and C<files> defaults to 1.

B<NOTE: the appearance of a print file IS NOT A GOOD INDICATOR THAT THE MSG
CONSUMER HAS FINISHED DOING STUFF.> If you're going to be checking for a write
to the database (ie: printlogs), then you'll create a further race condition if
you check for it once the document has appeared. Instead, use
L<Test::XTracker::Artifacts::RAVNI> and check for the AMQ receipt.

=cut

# Turn a filename in to a Test::XTracker::PrintDocs::File object
sub process_file {
    my ( $self, $event_type, $full_path, $rel_path ) = @_;

    # We're not interested in directories
    return () if -d $full_path;

    # Regexp to match "filename.extension" and "filename"
    # We won't force the filename to have any extension whatsoever since that's
    # done by Test::XTracker::Artifacts with its filewatcher
    my ( undef, $file_type, $file_id ) = basename($rel_path) =~ m/((.*)[-_](.*?))?(\.[^.]*)?$/;

    # Labels aren't caught by the RE above, so I'm hacking this in... sorry!
    if ( $rel_path =~ m{(\d+)\.lbl$} ) {
        ( $file_type, $file_id ) = ( 'label', basename($1) );
    }
    # And barcodes! :(
    elsif ( $rel_path =~ m{(.*?)\.png$} ) {
        ( $file_type, $file_id ) = ( 'barcode', basename($1) );
    }

    # Return explicit empty list so it doesn't show up in the map command this
    # is wrapped by.
    return () unless ($file_type && $file_id);

    # TODO: maybe fix it to work with label printers as well
    my $printjob_data = {};

    # If a printjob file has been created, read the details from it
    my $filename_no_extension = ( fileparse( $full_path, qr{\.[^.]*$} ) )[0];
    my $printjob_path = File::Spec->catfile( dirname( $full_path ), 'printjobs', $filename_no_extension );
    if ( -f $printjob_path ) {
        $printjob_data = JSON::decode_json( read_file( $printjob_path ) || '' );
    }

    my $printdocs_file = Test::XTracker::PrintDocs::File->new(
        content      => read_file( $full_path ) || '', # From File::Slurp
        filename     => basename( $rel_path ),
        file_type    => $file_type,
        file_id      => $file_id,
        full_path    => $full_path,
        # Text::XTracker::Client needs a URI to decide how to parse it. Add a
        # matchable tag at the front to say what we're doing
        uri          => URI->new( 'printdoc/' . $rel_path ),
        printer_name => ( defined( $printjob_data->{printer} ) ) ? $printjob_data->{printer} : undef,
        copies       => ( defined( $printjob_data->{copies} ) ) ? $printjob_data->{copies} : undef,
    );
    return $printdocs_file;
}

sub path_for_filename {
    my ( $self, $filename ) = @_;

    return XTracker::PrintFunctions::path_for_print_document({
        %{ XTracker::PrintFunctions::document_details_from_name( $filename ) },
        ensure_directory_exists => 0,
    });
}

package Test::XTracker::PrintDocs::File; ## no critic(ProhibitMultiplePackages)

use strict;
use warnings;
use HTML::TreeBuilder::XPath;
use Moose;
use Data::Printer;

=head1 Test::XTracker::PrintDocs::File ATTRIBUTES

=head2 content

File content as string

=head2 filename

Relative filename

=head2 file_type

Non-numeric portion of the filename (minus suffix)

=head2 file_id

Numeric portion of the filename

=head1 Test::XTracker::PrintDocs::File METHODS

=head2 as_data

Parse the contents using Test::XTracker::Client

=cut

has 'content' => ( is => 'ro', isa => 'Str', required => 1 );
has 'tree'    => (
    is => 'ro',
    isa => 'HTML::TreeBuilder::XPath',
    handles => [qw( find_xpath )],
    lazy_build => 1,
    init_arg => undef,
);
has 'filename'      => ( is => 'ro', isa => 'Str'  );
has 'full_path'     => ( is => 'ro', isa => 'Str'  );
has 'file_type'     => ( is => 'ro', isa => 'Str'  );
has 'file_id'       => ( is => 'ro', isa => 'Str'  );
has 'uri'           => ( is => 'ro', isa => 'URI'  );
has 'printer_name'  => ( is => 'ro', required => 0, isa => 'Maybe[Str]' );
has 'copies'        => ( is => 'ro', required => 0, isa => 'Maybe[Int]' );

with 'Test::XTracker::Client';

sub _build_tree {
    my ($self)=@_;

    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse( $self->content );
    return $tree;
}

# Set up the object
around BUILDARGS => sub {
    my ( $orig, $class, %args ) = @_;

    # Transform the URI
    $args{'uri'} = URI->new( $args{'uri'}, 'http' ) if exists $args{'uri'};
    return $class->$orig( %args );
};

sub _data_printer { # custom dump format for Data::Printer
    my ( $self ) = shift;

    my $coloured = !!$ENV{XT_DEBUG_COLOUR};

    SMARTMATCH:
    use experimental 'smartmatch';
    my $debug_output = {
        (
            map { ($_ => $self->$_) }
                grep { ! ($_ ~~ [qw( client_parse_cell_deeply content tree uri )]) } # don't dump these!
                    map { $_->name }
                        $self->meta->get_all_attributes,
        ),
        uri => $self->uri->as_string,
    };

    return Data::Printer::p( $debug_output, colored => $coloured );
}

=head2 file_age() : $age

Return the age of the file in days.

=cut

sub file_age {
    my ( $self ) = @_;
    return -M $self->full_path;
}

1;
