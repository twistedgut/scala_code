package Test::XTracker::Artifacts::Labels;

=head1 NAME

Test::XTracker::Artifacts::Labels

=head2 DESCRIPTION

Monitor the label output and return documents as data

=head2 SYNOPSIS

 # Start monitoring
 my $label_directory = Test::XTracker::Artifacts::Labels->new();

 ... do some stuff ...

 # See what's been added - returns Test::XTracker::Artifacts::Labels::File objects
 my @docs = $label_directory->new_files;

 # Those have some useful methods
 for my $doc ( @docs ) {
    print "Filename: " . $doc->filename  . "\n"; # Relative to printdoc dir
    print "File ID : " . $doc->file_id   . "\n"; # Numeric part of filename
    print "Content : " . $doc->content   . "\n"; # File contents as string

 }

=cut

use strict;
use warnings;
use File::Slurp;
use URI;
use Moose;

use XTracker::Config::Local qw/config_var/;
use XTracker::PrintFunctions;
use File::Basename;

extends 'Test::XTracker::Artifacts';

=head1 Test::XTracker::Artifacts::Labels METHODS

=head2 new

 my $dir = Test::XTracker::PrintDocs->new( read_directory => 'optional' );

Instantiate our monitor. All existing files in the print directory are counted
as 'seen', so that only new files are returned by C<new_files>.

=cut

# Configuration

has '+read_directory' => (
    required => 0,
    default => sub {[
        map { config_var('SystemPaths', $_) } qw/document_dir document_temp_dir/,
    ]},
);

has '+important_events' => (
    required => 0,
    default => sub { ['create', 'modify'] },
);

has '+filter_regex' => (
    required => 0,
    default => sub { qr/\.lbl$/ },
);

=head2 new_files

 my @docs = $dir->new_files;

Returns a list representing new files in the monitored directory since you last
called this method (or since the object was instantiated). Only files that look
like label docs will be returned (that is, they match: C<\.lbl$>)
and files will be returned as C<Test::XTracker::Artifacts::Labels::File> objects.

=cut

# Turn a filename in to a Test::XTracker::Artifacts::Labels::File object

sub process_file {
    my ( $self, $event_type, $full_path, $rel_path ) = @_;

    my ( $file_id ) = $rel_path =~ $self->filter_regex;

    # Return explicit empty list so it doesn't show up in the map command this
    # is wrapped by.
    return () unless (defined $file_id && -f $full_path);

    my $object = Test::XTracker::Artifacts::Labels::File->new(
        content   => read_file( $full_path ) || '', # From File::Slurp
        filename  => basename($rel_path),
        file_id   => $file_id,
        full_path => $full_path,
    );

    return $object;
}

sub path_for_filename {
    my ( $self, $filename ) = @_;

    return XTracker::PrintFunctions::path_for_print_document({
        %{ XTracker::PrintFunctions::document_details_from_name( $filename ) },
        ensure_directory_exists => 0,
    });
}

package Test::XTracker::Artifacts::Labels::File; ## no critic(ProhibitMultiplePackages)

use strict;
use warnings;
use Moose;
use Data::Printer;

=head1 Test::XTracker::Artifacts::Labels::File ATTRIBUTES

=head2 content

File content as string

=head2 filename

Relative filename

=head2 file_id

Numeric portion of the filename

=cut

has 'content'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'filename'      => ( is => 'ro', isa => 'Str'  );
has 'full_path'     => ( is => 'ro', isa => 'Str'  );
has 'file_id'       => ( is => 'ro', isa => 'Int'  );

sub _data_printer { # custom dump format for Data::Printer
    my ( $self ) = shift;

    my $coloured = !!$ENV{XT_DEBUG_COLOUR};

    SMARTMATCH:
    use experimental 'smartmatch';
    my $debug_output = {
        (
            map { ($_ => $self->$_) }
                grep { ! ($_ ~~ [qw( content )]) } # don't dump these!
                    map { $_->name }
                        $self->meta->get_all_attributes,
        ),
    };

    return Data::Printer::p( $debug_output, colored => $coloured );
}

1;
