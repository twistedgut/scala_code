package XT::Importer::FCPImport;
use strict;
use warnings;

use Perl6::Export::Attrs;

use Try::Tiny;
use File::stat;
use File::Copy;
use File::Path;
use File::Spec;

use XT::Order::Importer;
use XTracker::Config::Local qw( config_var config_section_slurp );
use XTracker::Logfile qw( xt_logger );
use XML::LibXML;

use DateTime;

use XTracker::Database qw( schema_handle get_database_handle );

use Fcntl ':flock';
use Readonly;

my $logger = xt_logger( qw( OrderImporter ) );

sub import_all_files {
    $logger->debug( "About to open $0" );

    my $self_fd;

    # check if import script already running
    unless ( open ($self_fd, '<', $0) ) {
        $logger->info( "Import $0 already running" );

        return;
    }

    unless( flock ($self_fd, LOCK_EX | LOCK_NB) ) {
        $logger->info( "$0 already locked by another process" ) ;

        return;
    }

    my $return_status = 1;

    # working directories
    my $waitdir  =                config_var('SystemPaths', 'xmlwaiting_dir');
    my $procdir  = todays_subdir(config_var('SystemPaths', 'xmlproc_dir'));
    my $errordir = todays_subdir(config_var('SystemPaths', 'xmlproblem_dir'));

    # read in waiting directory
    my @sorted_files = read_sorted_xml_filenames_from_directory( $waitdir );

    if ( @sorted_files ) {
        my $schema = get_database_handle({ name => 'xtracker_schema' })
            or $logger->logdie( "Error: Unable to connect to DB" );

      ORDERFILE:
        foreach my $file ( @sorted_files ) {
            my $inputfile = "$waitdir/$file";

            if ( -z $inputfile )  {
                # file is empty - check modification time
                my $modification_time = time() - stat($inputfile)->mtime;

                if ($modification_time > 60 * 20) { # 20 minutes
                    move( $inputfile, "$errordir/$file" );

                    $logger->warn( "Moved zero-sized file to '$errordir/$file'" );
                }

                next ORDERFILE;
            }

            try {
                import_one_file({      schema => $schema,
                                    readyfile => "$waitdir/$file",
                                  successfile => "$procdir/$file",
                                  failurefile => "$errordir/$file"
                               });
            }
            catch {
                $logger->warn( "Problem processing '$waitdir/$file': $_\n" );

                $return_status = 0;
            };
        }
    }

    close( $self_fd) ; # this will unflock it too

    return $return_status;
}

=head2 import_some_files

Given a list of path names representing order files in the parallel
area, imports them via C<import_one_file> and handles the
success/failure renaming as appropriate.

Expects a list of filenames, which need to have a path following the
structure in the parallel XML work area.  That is:

  I<shipping-method>/I<brand-id>/ready/order-12345-001.xml

The success and failure names are derived from the C<ready> name.

The files are processed in the order supplied, so any specific
sequencing can, and must, be determined by the caller.

=cut

sub import_some_files {
    my @filenames = @_;

    $logger->logdie( "Must provide at least one path name\n" ) unless @filenames;

    my $xmparallel_dir = config_var('SystemPaths','xmparallel_dir');

    my $names = config_section_slurp('ParallelOrderImporterNames');

    my $schema = get_database_handle({ name => 'xtracker_schema' })
        or $logger->logdie( "Error: Unable to connect to DB" );

    my $return_status = 1;

  FILE:
    foreach my $filename ( @filenames ) {
        # filenames are expected to be relative to $xmparallel_dir
        # filenames are expected to be in the correct order for processing

        $filename =~ m{\A(?<stream_name>.*)/\Q$names->{ready}\E/(?<order_file_name>[^/]+\.xml)\z};

        my ($stream_name,$order_file_name) = ($+{stream_name},$+{order_file_name});

        unless ($stream_name) {
            $logger->warn( "Unable to extract stream name from '$filename' -- SKIPPING\n" );

            next FILE;
        }

        unless ($order_file_name) {
            $logger->warn( "Unable to extract order file name from '$filename' -- SKIPPING\n" );

            next FILE;
        }

        my $paths = {
            map { $_ => "$xmparallel_dir/$stream_name/$names->{$_}/$order_file_name" } keys %$names
        };

        unless ( -f $paths->{ready} ) {
            $logger->warn( "Unable to find order file '$paths->{ready}' -- SKIPPING\n" );

            next FILE;
        }

        if ( -f $paths->{success} ) {
            $logger->warn( "Success file '$paths->{success}' already exists -- REMOVING '$paths->{ready}'\n" );

            unlink( $paths->{ready} )
                or $logger->warn( "Failed to remove ready file '$paths->{ready}'\n" );

            next FILE;
        }

        if ( -f $paths->{failure} ) {
            $logger->warn( "Failure file '$paths->{failure}' already exists, will be removed on success\n" );
        }

        $logger->debug( "About to import order file '$order_file_name' for stream '$stream_name'" );

        try {
            import_one_file( {      schema => $schema,
                                 readyfile => $paths->{ready},
                               successfile => $paths->{success},
                               failurefile => $paths->{failure} } );
        }
        catch {
            # watch us cavalierly presume that $logger isn't the source of the problem

            $logger->warn( "Problem processing '$paths->{ready}': $_\n" );

            if ( -f $paths->{ready} && ! -f $paths->{failure} ) {
                rename( $paths->{ready}, $paths->{failure} )
                    or $logger->warn( "Failed to move '$paths->{ready}' to '$paths->{failure}'\n" );
            }

            $return_status = 0;
        };
    }

    return $return_status;
}

=head2 import_one_file

Imports a single order file.  Expects a hash with three mandatory
args, for the order file itself, where to move it to on success, and
where to move it to on failure.  A fourth, optional, schema may also
be provided.  If it isn't, we acquire our own for processing the file.

=cut

sub import_one_file {
    my $args = shift;

    my ($schema, $readyfile, $successfile, $failurefile)
      = ($args->{schema},
         $args->{readyfile},
         $args->{successfile},
         $args->{failurefile});

    die "Must provide ready file name\n"    unless $readyfile;
    die "Must provide success file name\n"  unless $successfile;
    die "Must provide failure file name\n"  unless $failurefile;

    $logger->warn( "Input file '$readyfile' does not exist, or is not a regular file\n" )
        unless -f $readyfile;

    # we do *not* specify an encoding layer for the input FD, because
    # LibXML wants to work it out for itself, apparently

    my $input_fd;

    unless ( open($input_fd, '<', $readyfile) && flock($input_fd, LOCK_EX | LOCK_NB ) ) {
        $logger->info( "Input file '$readyfile' already claimed -- IGNORING PROCESSING REQUEST" );

        return 1;
    }

    if ( -z $readyfile ) {
        $logger->warn( "May not process an empty file\n" );

        close( $input_fd ); # this will unflock it too

        return 1;
    }

    $logger->info( "Processing '$readyfile'\n" );

    unless ( $schema ) {
        $schema = get_database_handle({ name => 'xtracker_schema' })
            or $logger->logdie( "Error: Unable to connect to DB\n" );
    }

    my $err;
    try {
        $logger->debug( "About to parse '$readyfile'" );

        my $order_xml = XML::LibXML->load_xml( IO => $input_fd );

        $logger->debug( 'About to call import_orders()' );

        if ( -f $successfile ) {
            if ( -f $readyfile ) {
                $logger->info( "File '$readyfile' has already been processed successfully -- REMOVING\n" );

                # yes, you can unlink before unlocking, and that's the right
                # thing to do to avoid another process claiming the lock
                # before we remove the file

                unlink( $readyfile )
                    or $logger->warn( "Failed to remove '$readyfile'\n" );
            }
        }
        else {
            XT::Order::Importer->import_orders({ schema => $schema,
                                                   data => $order_xml,
                                                 logger => $logger })
                or die "Failed to process all the orders in '$readyfile'\n";
        }
        $err=0;
    }
    catch {
        $logger->warn( $_ );

        # we *don't* remove unexpected success files, because if the
        # import has succeeded once, a subsequent attempt at importing
        # should fail, but that shouldn't cause the previous success
        # to be discarded

        rename( $readyfile, $failurefile )
            or $logger->warn( "Failed to move '$readyfile' to '$failurefile'\n" );

        close( $input_fd ); # this will unflock it too

        $err=1;
    };
    return 0 if $err;

    if ( -f $failurefile ) {
        $logger->debug( "Removing unexpected failure file '$failurefile'\n" );

        unlink( $failurefile )
            or $logger->warn( "Failed to remove failure file '$failurefile'\n" );

        # okay to carry on
    }

    # malarkey to mitigate the consequences of a concurrent process
    # monkeying with our files...

    if ( -f $successfile ) {
        if ( -f $readyfile ) {
            $logger->info( "File '$readyfile' has already been processed successfully -- REMOVING\n" );

            unlink( $readyfile )
                or $logger->warn( "Failed to remove '$readyfile'\n" );
        }
        else {
            $logger->debug( "File '$readyfile' already moved to '$successfile' ... BY ELVES!\n" );
        }
    }
    else {
        if ( -f $readyfile ) {
            if ( rename($readyfile, $successfile) ) {
                $logger->debug( "Order file '$readyfile' moved to '$successfile'" );
            }
            else {
                $logger->warn( "Failed to move '$readyfile' to '$successfile'" );
            }
        }
        else {
            unless ( -f $successfile || -f $failurefile ) {
                $logger->warn( "Order file '$readyfile' has been STOLEN! Probably BY ELVES!\n" );
            }
        }
    }

    # yep, close after rename; don't worry, it works just fine
    close( $input_fd ); # this will unflock it too

    return 1;
}

=head2

Create a subdirectory, based on today's date, in the directory named as the sole argument.

Uses UTC (well, GMT, but that's close enough).  It does this to be
consistent with the timestamps in XML file names.

=cut

sub todays_subdir {
    my $dirname = shift;

    die "Must provide a directory name"
        unless $dirname && -d $dirname;

    my ( $mday, $mon, $year ) = (gmtime)[3..5];

    my $sub_path = "$dirname/".sprintf('%04d%02d%02d', $year + 1900, $mon + 1, $mday);

    mkdir($sub_path) unless -d $sub_path;

    return $sub_path;
}

=head1 XML File utilities

=head2 xml_filename_cmp

Given two strings representing filenames (basenames only, not paths)
that name XML files for the order importer, return -1, 0 or 1
according to how they compare for sorting.  The comparison is done on
the date/time components of the filenames only; the rest of the file
names are ignored.

This means, for example that C<NAP_INTL_orders_20120101_010101.xml>
and C<MRP_AM_orders_20120101_010101.xml> will compare as I<equal>.

=cut

sub xml_filename_cmp :Export(:xml_filename) {
    my ( $a, $b ) = @_;

    return unless defined $a && defined $b;

    my $parts = {};

    $parts->{a} = split_xml_filename($a);
    $parts->{b} = split_xml_filename($b);

    if (    $parts->{a}
         && $parts->{b}
         && $parts->{a}{datetime}
         && $parts->{b}{datetime}  ) {
        return $parts->{a}{datetime} cmp $parts->{b}{datetime};
    }
    else {
        return $a cmp $b;
    }
}

=head2 split_xml_filename

Given a string representing the filename (basename only, not a path)
that names an XML file for the order importer, return a hash
containing the component parts of that filename.

Presently, these are:

=over 2

=item channel

The I<channel> portion of the filename, such as C<NAP_INTL>,
C<MRP_AM>, etc.

=item type

The I<type> portion of the filename.  At present, this can only be
C<orders>.

=item date

The eight-digit I<date> portion of the filename, formatted as
C<YYYYMMDD>.

=item time

The six-digit I<time> portion of the filename, formatted as C<HHMMSS>.

=item datetime

The concatenation of the I<date> and I<time> portions as a single
14-digit value, formatted as C<YYYYMMDDHHMMSS>.

=item filename

The entire filename handed in, unchanged.  This is included mainly to
make it easy for a caller to know which filename was passed in.

=back

Note that, if the filename passed in cannot be parsed and split, then
the return value will be a hash that only contains the C<filename>
element.

Note further that, if the filename passed in is undefined or empty,
then the function will just return.

=cut

sub split_xml_filename :Export(:xml_filename) {
    my $filename = shift;

    # split filename into component parts, separated by underscores
    #
    # anchor at start and end of expression to force this expression
    # to match the entire string
    my $xml_filename_regex = qr{
        \A
        (?<channel>(?:MRP|NAP|OUT|OUTNET|JC|JCHOO)_(?:INTL|AM|APAC))
        _
        (?<type>orders)
        _
        (?<date>\d{8}) # expecting YYYYMMDD
        _
        (?<time>\d{6}) # expecting HHMMSS
        \.xml
        \z
    }x;

    if ( $filename ) {
        if ( $filename =~ m{$xml_filename_regex} ) {
            return {  channel => $+{channel},
                         type => $+{type},
                         date => $+{date},
                         time => $+{time},
                     datetime => $+{date}.$+{time},
                     filename => $filename };
        }
        else {
            return { filename => $filename };
        }
    }
    else {
        return;
    }
}

=head2 make_xml_filename

Given a channel name, and optionally a datetime object, return a
filename that match the structure of Order Importer XML filenames.

We don't use this in this module, but other scripts do, and it makes
sense to keep it together with the functions that decode XML
filenames, so that if we ever have to change the structure of the
filenames, we can do it all in one place, with minimal disturbance
elsewhere.

=cut

sub make_xml_filename :Export(:xml_filename) {
    my $channel = shift;
    my $datetime = shift || DateTime->now( time_zone => 'UTC' );

    die "Optional parameter not a datetime object"
        unless ref $datetime eq 'DateTime';

    $channel =~ m{
        \A
        (?<brand>MRP|NAP|OUT|OUTNET|JC|JCHOO)
        [-_]
        (?<region>INTL|AM|APAC)
        \z
    }ix;

    die "Cannot identify channel '$channel'\n"
        unless $+{brand} && $+{region};

    my $datetime_formatter = DateTime::Format::Strptime->new(
        pattern => q{%Y%m%d_%H%M%S}
    );

    $datetime->set_formatter( $datetime_formatter );

    return sprintf(
        "%s_%s_orders_%s.xml",
         uc $+{brand},
         uc $+{region},
         $datetime
    );
}

=head2 sort_xml_filenames

Given an array of strings that represent filenames (basenames only, not paths)
that name XML files for the order importer, return an array containing those filenames
sorted according to their datetime values alone.

Note that any filenames that cannot be split by C<split_xml_filename>
will be B<omitted> from the returned array.

=cut

sub sort_xml_filenames :Export(:xml_filename) {
    my @files = @_;

    if ( scalar( @files ) > 1 ) {
        return  map { $_->{filename} }
               sort { $a->{datetime} cmp $b->{datetime} }
               grep { defined $_
                        && ref $_ eq 'HASH'
                        && exists $_->{datetime}
                    }
                map { split_xml_filename( $_ ) }
                    @files
              ;
    }
    else {
        # list is too small to need sorting
        return @files;
    }
}

=head2 read_sorted_xml_filenames_from_directory

Given a directory name, read in any XML files it contains, sort them
and return the list.

=cut

sub read_sorted_xml_filenames_from_directory :Export(:xml_filename) {
    my $dirname = shift;

    die "Must provide an XML directory name\n"
        unless $dirname;

    die "Unable to find XML filename directory '$dirname'\n"
        unless -d $dirname;

    opendir(my $xml_waiting_fd, $dirname) or $logger->logdie( $! );

    # throw away anything that isn't a regular file
    my @files = grep { -f File::Spec->catfile( $dirname, $_ ) } readdir( $xml_waiting_fd );

    closedir( $xml_waiting_fd );

    return unless @files;

    # trust this to prune non-XML names from the list
    return sort_xml_filenames( @files );
}


1;
