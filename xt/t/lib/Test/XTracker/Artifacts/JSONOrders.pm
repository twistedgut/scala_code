package Test::XTracker::Artifacts::JSONOrders;

=head1 NAME

Test::XTracker::Artifacts::JSONOrders

=head2 DESCRIPTION

Monitor the JSON Order directories output and return files as data

=head2 SYNOPSIS

 # Start monitoring
 my $order_directory = Test::XTracker::Artifacts::JSONOrders->new( read_directory => "optional, will default to 'processed' dir" );

 ... do some stuff ...

 # See what's been added - returns Test::XTracker::Artifacts::JSONOrders::File objects
 my @docs = $order_directory->new_files;

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

extends 'Test::XTracker::Artifacts';

=head1 Test::XTracker::Artifacts::JSONOrders METHODS

=head2 new

 my $dir = Test::XTracker::JSONOrders->new( read_directory => 'optional' );

Instantiate our monitor. All existing files in the print directory are counted
as 'seen', so that only new files are returned by C<new_files>.

=cut

# Configuration

has '+read_directory' => (
    required => 0,
    default => config_var('AMQOrders', 'proc_dir'),
);

has '+important_events' => (
    required => 0,
    default => sub { ['create', 'modify'] },
);

has '+filter_regex' => (
    required => 0,
    default => sub { qr/order_/ },
);

=head2 new_files

 my @docs = $dir->new_files;

Returns a list representing new files in the monitored directory since you last
called this method (or since the object was instantiated). Only files that look
match 'filter_regex' will be returned as C<Test::XTracker::Artifacts::JSONOrders::File> objects.

=cut

# Turn a filename in to a Test::XTracker::Artifacts::JSONOrders::File object

sub process_file {
    my ( $self, $event_type, $full_path, $rel_path ) = @_;

    my ( $order_nr )    = $rel_path =~ m/order_(\w+)$/;

    # Return explicit empty list so it doesn't show up in the map command this
    # is wrapped by.
    return () unless ($order_nr);

    my $object = Test::XTracker::Artifacts::JSONOrders::File->new(
        content   => read_file( $full_path ) || '', # From File::Slurp
        filename  => $rel_path,
        file_id   => $order_nr,
        full_path => $full_path,
    );

    return $object;
}

package Test::XTracker::Artifacts::JSONOrders::File; ## no critic(ProhibitMultiplePackages)

use strict;
use warnings;
use Moose;

=head1 Test::XTracker::Artifacts::JSONOrders::File ATTRIBUTES

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
has 'file_id'       => ( is => 'ro', isa => 'Str'  );

1;
