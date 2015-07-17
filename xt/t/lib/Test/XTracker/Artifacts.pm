package Test::XTracker::Artifacts;

=head1 NAME

Test::XTracker::Artifacts

=head2 DESCRIPTION

Base class for modules that monitor directories; the base class for
Test::XTracker::PrintDocs and Test::XTracker::Artifacts::Manifest.

=cut

use NAP::policy "tt", 'test';
use Carp qw/croak longmess shortmess/;
use Path::Class;
use Moose;

use File::ChangeNotify;
use Scalar::Util qw(weaken);
use Data::Printer;
use Moose::Util::TypeConstraints;

=head1 CONFIGURATION

Setting up a subclass for this is a matter of over-riding certain methods.

=head2 read_directory_default

Must return a string of the directory to monitor. Recursive.

=head2 filter_regex

Must return a regular expression that we'll be using to decide which files
we're interested in. eg: C<qr/\.html$/> (HTML files), C<qr/./> (all files).

=head2 important_events

Must return an arrayref of L<File::ChangeNotify> events we're interested in.
Examples are C<create> and C<modify>.

=head1 METHODS TO OVERRIDE

=head2 process_file

Each event is passed to this method, and its return value is what is returned
to the user. This method is called as:

 ->process_file( event_type, full_file_path, relative_file_path )

So you can grab everything you need from that!

=head1 INTERFACE

=head2 new

 my $dir = Test::XTracker::Artifacts->new( read_directory => 'optional' );

Instantiate our monitor. The state of the directory at this point is considered
'normal', so existing files won't be marked as new.

=cut

subtype 'ArrayOfStr', as 'ArrayRef[Str]';
coerce 'ArrayOfStr', from 'Str', via { [$_] };

# Directory we're monitoring
has 'read_directory' => (
    isa      => 'ArrayOfStr',
    is       => 'rw',
    required => 1,
    coerce   => 1,
);

# Where we keep track of files seen
has 'watcher' => (
    isa      => 'File::ChangeNotify::Watcher',
    is       => 'rw',
    required => 0,
    init_arg => undef,
);

has 'important_events' => (
    isa => 'ArrayRef',
    is => 'rw',
    required => 1,
);

has 'filter_regex' => (
    isa => 'Maybe[RegexpRef]',
    is => 'rw',
);

has 'exclude' => (
    isa => 'Maybe[ArrayRef]',
    is => 'rw',
    required => 0,
);

has 'strict_mode' => (
    isa => 'Int',
    is  => 'ro',
    default => 1
);

has 'shutdown_nicely' => (
    isa => 'Bool',
    is  => 'rw',
    default => 0
);

has title => (
    isa => 'Str',
    is => 'rw',
    default => 'untitled',
);

has create_location => (
    is      => "ro",
    default => sub {
        join(
            "\n",
            grep { ! m|/opt/| }
            split( qr/\n/, longmess() ),
        ),
    },
);

my @created = ();

# On build, start the directory watcher
sub BUILD {
    my $self = shift;

    diag "*** Creating $self (".$self->title.')' if $self->debug_messages;

    dir($_)->mkpath() for @{$self->read_directory};

    my @watcher_options = ( 'directories' => $self->read_directory() );
    push @watcher_options, ( 'filter' => $self->filter_regex() ) if( defined( $self->filter_regex() ) );
    push @watcher_options, ( 'exclude' => $self->exclude() ) if( defined( $self->exclude() ) );
    $self->watcher( File::ChangeNotify->instantiate_watcher( @watcher_options ) );

    # Take a copy for shutdown time
    push(@created, $self);
    weaken( $created[-1] );

    return $self;
}

=head2 new_files

 my @docs = $dir->new_files;

Looks for all events you're monitoring, passes them through C<process_file>,
and returns them, if the file matches the filter regex.

Please note that this will only return 1 element per file, even if
multiple events fired for that file. The element will be the result of
processing the file as it appeared after the latest event fired for it.

=cut

sub new_files {
    my $self = shift;

    # Filter events for the important ones only
    SMARTMATCH:
    use experimental 'smartmatch';
    my @events = grep { $_->type ~~ $self->important_events } $self->watcher->new_events;

    my @return_events;
    my %seen_files_pos;
    # Process the events
    for my $event ( @events ) {
        my ( $event_type, $full_path ) = ( $event->type, $event->path );

        next unless -f $full_path;

        my $full_path_obj=file($full_path);
        # Get the atomic filename
        my $relative_path;
        for my $dir (@{$self->read_directory}) {
            if (dir($dir)->subsumes($full_path_obj)) {
                $relative_path = $full_path_obj->relative($dir)->stringify;
            }
        }
        $relative_path //= $full_path;

        if (defined $seen_files_pos{$full_path}) {
            $return_events[$seen_files_pos{$full_path}]
                = $self->process_file( $event_type, $full_path, $relative_path );
        }
        else {
            push(@return_events,
                 $self->process_file( $event_type, $full_path, $relative_path )
             );
            $seen_files_pos{$full_path}=$#return_events;
        }
    }

    return @return_events;
}

=head2 wait_for_new_files

 my @docs = $dir->wait_for_new_files(
    seconds => 5, # How many seconds to wait for
    files   => 2, # How many new files we're looking for
 );

Some of the work of DCEA causes different processes to write files. This
can lead to race conditions. This method loops around C<new_files>, and returns
whatever it found when either condition is true.

Why two conditions? Because a naïve implementation would just return when it
had found a file, and we might be expecting more than one file. We also don't
want to wait forever (or longer than we have to) for files.

C<seconds> defaults to 60, and C<files> defaults to 1.

If this function returns without the requested number of files found, it will
cause a fatal error, as that's almost always the right thing to do. You can turn
this off by passing in C<<no_die => 1>>, although that almost always means you
are doing something wrong.

=cut

my $default_wait = 60;
sub wait_for_new_files {
    my ( $self, %args ) = @_;
    if ( $args{'seconds'} ) {
        if ( $args{'seconds'} < $default_wait && ! $args{'no_time_warning'} ) {
            diag "You have manually set the seconds value in wait_for_new_files"
                . " to less than default $default_wait. That's not recommended" .
                ", as it's unlikely to speed up your test";
        }
    } else {
        $args{'seconds'} = $default_wait;
    }
    $args{'files'}   =  1 unless $args{'files'};

    my $name = uc(ref($self));
    $name =~ s/.+:://;
    my $title = $self->title;

    note "$name: ($title) Monitoring the directory @{$self->read_directory} for either $args{'files'}" .
        " file(s) or until $args{'seconds'} seconds elapsed";

    my $start_time = time();
    my @files = ();
    my %seen_files_pos;

    my $i;
    my $timed_out = 0;

    while (1) {
        $i++;
        my @new_files = $self->new_files;

        for my $file (@new_files) {
            note "$name: ($title) New file found: [" . $file->filename . "] after ". (time()-$start_time) ." seconds on iteration $i";
            if ($self->debug_messages) {
                diag "*** Message details:";
                diag p($file,
                    colored => $ENV{XT_DEBUG_COLOUR},
                );
                diag "***";
            }
        }

        for my $new_file (@new_files) {
            my $idx=$seen_files_pos{$new_file->full_path};
            if (defined $idx) {
                $files[$idx] = $new_file;
            }
            else {
                push @files,$new_file;
                $seen_files_pos{$new_file->full_path}=$#files;
            }
        }

        if ((time() - $start_time) >= $args{'seconds'}) {
            note "$name: ($title) $args{'seconds'} second(s) elapsed - exiting";
            $timed_out++;
            last;
        }
        if (scalar @files >= $args{'files'}) {
            note "$name: ($title) $args{'files'} file(s) found - exiting";
            last;
        }
    }

    if (scalar @files > $args{'files'}) {
        fail("Too many files found. That's also not ok. We were expecting " . $args{'files'} .
            " and found " . scalar @files);
    }

    if ( $timed_out && ( ! $args{'no_die'} ) ) {
        croak "Requested " . $args{'files'} .
            " file(s) not found in allowable time, only found " . scalar(@files) . " files";
    }

    return @files;
}

=head2 wait_for_new_filename_object(%args) : %file_name_object

The same as wait_for_new_files, but return a hash (keys: file names,
values: Test::XTracker::PrintDocs::File objects) instead of a list.

=cut

sub wait_for_new_filename_object {
    my ($self, %args) = @_;

    my %file_name_object =
        map { $_->filename => $_ }
        $self->wait_for_new_files(%args);

    return %file_name_object;
}

# Why this DEMOLISH() sub? It's far too easy to get sloppy about artifact
# monitoring, and create all sorts of race conditions. A process that you set
# off with a request several requests ago suddenly drops its files when you
# thought you'd moved on...
sub DEMOLISH {
    my $self = shift;
    $self->shutdown_monitor;
}

sub shutdown_monitor {
    my $self = shift;
    diag "*** Destroying $self (".$self->title.')' if $self->debug_messages;
    return if $self->shutdown_nicely;
    $self->shutdown_nicely(1);

    my @files_unaccounted_for = $self->new_files;
    if ( @files_unaccounted_for ) {
        diag "*** Your " . $self->title . ' ' . ref($self);
        diag "*** object which was created at:\n" . $self->create_location;
        diag "*** is being destroyed, but there";
        diag "*** are new files you've not dealt with yet available. This is";
        diag "*** bad and you can read about why in";
        diag "*** t/lib/Test/XTracker/Artifacts.pm which is where this error";
        diag "*** has originated. We now follow with some useful diagnostics:";
        diag "***";
        diag "*** Files remaining: [" . @files_unaccounted_for . '] (at least)';
        diag "***       Directory: [@{$self->read_directory}]";
        diag "***          Filter: [" . ($self->filter_regex // '<none>') . ']';
        diag "***";
        diag "*** Here's a stacktrace:";
        diag "***";
        diag longmess('Stacktrace');
        diag "***";
        diag "***";
        diag "*** Messages unaccounted for:";
        diag p(@files_unaccounted_for,
            colored => $ENV{XT_DEBUG_COLOUR},
        );
        diag "***";
        if ( $self->strict_mode ) {
            diag "*** Calling a fail, so you notice...";
            fail "Files still found while tearing down artifact monitor";
        } else {
            diag "*** For now, you get a free pass. In the future, this will";
            diag "*** cause a test failure.";
        }
    }
}

# set XT_DEBUG_MESSAGES=1 to get full details of the messages handled by
# Test::XTracker::Artifacts.
sub debug_messages {
    return !!$ENV{XT_DEBUG_MESSAGES};
}

=head2 file_not_present_ok( $filename, $message )

Check that the specified print document does not exist. Automatically
determines the correct path for the supplied filename.

=cut

sub file_not_present_ok {
    my ( $self, $filename, $message ) = @_;

    $message //= "$filename should not exist";
    my $path = $self->path_for_filename( $filename );

    ok(! -e $path, $message)
        || diag "('$path' unexpectedly found)";
}

=head2 non_empty_file_exists_ok( $filename, $message )

Check that the specified print document exists and is non-empty. Automatically
determines the correct path for the supplied filename.

Note that this method B<doesn't> clear the watcher of the file you're testing.

=cut

sub non_empty_file_exists_ok {
    my ( $self, $filename, $message ) = @_;

    $message //= "$filename should exist and be non-empty";
    my $path = $self->path_for_filename( $filename );

    ok -s $path, $message or diag "('$path' not found)";
}

=head2 delete_file( $filename )

Remove the specified file, automatically determining the correct path from
the filename.

=cut

sub delete_file {
    my ( $self, $filename ) = @_;

    my $path = $self->path_for_filename( $filename );

    if ( -e $path ) {
        unlink $path || die "Failed to delete $filename: $!";
    }
}

=head2 path_for_filename( $filename ) : $path

Returns the path for the specified filename. Default implementation just
returns the filename, but subclasses may want to change this (for print
documents, messages, etc.)

=cut

sub path_for_filename {
    my ( $self, $filename ) = @_;
    return $filename;
}

=head2 file_age( $filename ) : $age_in_days

Returns the script start time minus the file modification time in days. It
determines the correct path for the supplied filename.

=cut

sub file_age {
    my ( $self, $filename ) = @_;
    return -M $self->path_for_filename( $filename );
}

END { $_->shutdown_monitor for grep { defined  } @created; }

1;
