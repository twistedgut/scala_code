package Test::XTracker::Artifacts::OutputFile;

use NAP::policy "tt",     qw( class test );
extends 'Test::XTracker::Artifacts';

=head1 NAME

Test::XTracker::Artifacts::OutputFile

=head2 DESCRIPTION

Monitor a directory for any general Output Files that Scripts might produce. Such as for Extracts or any part
of the System that might product Data files.

=head2 SYNOPSIS

 # Start monitoring
 my $directory  = Test::XTracker::Artifacts::OutputFile->new( ... );

 ... do some stuff ...

 # See what's been added - returns Test::XTracker::Artifacts::OutputFile::TypeOfPlugIn::File objects
 my @files  = $directory->new_files;

 # Those have some useful methods
 for my $file ( @files ) {
    print "Filename: " . $file->filename  . "\n"; # Relative to printdoc dir
    print "File ID : " . $file->file_id   . "\n"; # Id of filename
    print "Content : " . $file->content   . "\n"; # File contents as string
 }

=cut

=head1 Test::XTracker::Artifacts::OutputFile METHODS

=head2 new

 my $dir = Test::XTracker::Artifacts::OutputFile->new( {
                                            # required
                                            file_type       => 'TypeOfFilePlugIn',      # there should be an associated plugin module
                                                                                        # in the 'Test::XTracker::Artifacts::OutputFile::*'
                                                                                        # namespace
                                            read_directory  => '/some/path/where/files/appear',
                                            filter_regex    => qr/filenames to look out for/,

                                            # optional
                                            file_id_regex   => qr/filename_(id)/,
                                        } );

Instantiate our monitor. All existing files in the print directory are counted
as 'seen', so that only new files are returned by C<new_files>.

=cut

use Module::Pluggable::Object;
use File::Find::Rule;


# Configuration

=head2 file_type

This will be the name of a Class in the 'Test::XTracker::Artifacts::OutputFile::*' namespace which
will be plugged in and used as the Parser to read in the files. These plugins may require extra
attributes to be set at the point of Construction.

Currently the following types are available:
    * 'PlainText' - for handling plain text files such as 'csv'

The object that is returned from 'Test::XTracker::Artifacts::OutputFile->new()' will actually be of
the class for the plugin.

=cut

has file_type => (
    is      => 'ro',
    isa     => 'Str',
    required=> 1,
);

=head2 read_directory

The directory to monitor where the files will appear.

=cut

has '+read_directory' => (
    required => 1,
);

=head2 important_events

The events to monitor in the directory which are 'create' & 'modify'.

=cut

has '+important_events' => (
    required => 0,
    default => sub { ['create', 'modify'] },
);

=head2 filter_regex

Only filenames in the directory will be looked at that match this RegEx.

=cut

has '+filter_regex' => (
    required => 1,
);

=head2 file_id_regex

This will be used to set the 'file_id' for each file that is found. It will get the Id
from only ONE capture in the RegEx.

This is optional and the 'file_id' will be left empty if this attribute is not populated.

Example:
    Filename: 'ORDER_2323424.txt'
    Filter  : qr/^ORDER_(\d+)\.txt/
    This will end up with the numeric part of the filename being the 'file_id'

=cut

has 'file_id_regex' => (
    is  => 'rw',
);

=head2 new_files

    my @files  = $dir->new_files;

Returns a list representing new files in the monitored directory since you last
called this method (or since the object was instantiated). Only files that look
like the 'filter_regex' will be returned. They will be returned as Objects of the
Class C<Test::XTracker::Artifacts::OutputFile::TypeOfFilePlugIn::File>.

See C<Test::XTracker::Artifacts> for more information.

=head2 wait_for_new_files

    my @files   = $dir->wait_for_new_files(
                                    files   => 3,   # number of files to wait for
                                    seconds => 65,  # number of seconds to wait for files to appear
                                );

See C<Test::XTracker::Artifacts> for more information.

=cut

# find the relevant module to plugin
# based on the 'file_type' attribute
sub BUILD {
    my ( $self, $args )     = @_;

    my $class   = ref( $self );
    if ( __PACKAGE__ eq $class ) {
        my $finder  = Module::Pluggable::Object->new(
                                search_path     => [ __PACKAGE__ ],
                                require         => 1,
                                inner           => 0,
                            );
        my $type_class  = "${class}::" . $self->file_type;

        my @type    = grep { m/^${type_class}$/ } $finder->plugins;
        if ( !@type ) {
            croak "Couldn't Find a File Type Class '$type_class' when building '" . __PACKAGE__ . "'";
        }
        elsif ( @type > 1 ) {
            croak "Found more than one class for File Type Class '$type_class' when building '" . __PACKAGE__ . "'";
        }

        # Re-Bless $self so that it is now the Plugin's Class, BUILD & BUILDARGS
        # won't be called but Attributes will be populated with contents of %{ $args }
        $type_class->meta->rebless_instance( $self, %{ $args } );
        $self->BUILD( $args );      # call the BUILD on the new object, to cleanup anything that needs it
    }

    return $self;
}

=head2 purge_directory_of_files

    $num_files_deleted  = $dir->purge_directory_of_files;

This will delete from the directory specified with 'read_directory' all of the files that
match the 'filter_regex' attribute.

=cut

sub purge_directory_of_files {
    my $self    = shift;

    my @files_to_delete = File::Find::Rule
                            ->file
                                ->name( $self->filter_regex )
                                    ->in( @{$self->read_directory} );
    return 0    if ( !@files_to_delete );

    foreach my $file ( @files_to_delete ) {
        unlink $file;
    }

    my $name= uc( ref( $self ) );
    $name   =~ s/.+:://;

    note "${name}: (" . $self->title . ') Purged ' . @files_to_delete . ' files from ' . join ', ',@{$self->read_directory};

    return scalar( @files_to_delete );
}


1;
