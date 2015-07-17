#!/opt/xt/xt-perl/bin/perl
#
# check if complete Route Monkey XML files have appeared on a remote
# SMB share, and, if so, copy them to the processing area, kick off a
# data import process, and move it to one side on the SMB share
#
#
# this script is designed to be run from cron every few minutes,
# and to return quickly if there is nothing to do.
#
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)

=head1 RouteMonkey routing data import.


=head2 Overview

Here is the approach I'm taking for now:

=over 4

=item get new RouteMonkey routing files

=over 2

=item at present, this means watching an SMB share somewhere waiting for new export files to appear, then scooping them up

=item we need to be careful that we don't scoop up files while they're still being written to

=item the way we do that is to read the directory for candidates to transfer, 
      identify the I<most recently-written> file in that set, and wait for that file to
      stabilize (this is based on the not-entirely insane assumption that the RouteMonkey
      software does not re-visit a previously-written file after moving on to a subsequent one;
      no doubt, there will be a case where this assumption breaks)

=item once the candidate latest-written file stabilizes, we fetch I<only> those files in the set we discovered earlier -- we do I<not> refetch the list of files to work on, since the next invocation of this process will handle those anyway

=item we transfer the files to local names derived according to a same naming policy, rather than the one used by RouteMonkey, and we set the last modification time on each file to its value on the remote system -- this is important for subsequent process scheduling

=item as a belt-and-braces action, we also name the files in a way that they will collate in the best order for local processing anyway

=back

=item drop the files we've captured into a local incoming directory

=item move aside on the remote server those files that we have I<successfully> captured 

=item push the same I<successfully> captured files into the local ready directory

=item kick off the local XT routing inhalation process

=item send an e-mail report on what we've done

=back

=head2 Structure

The core script that drives the process is:

    script/routing/process_routing_files.pl

This script is designed to be run frequently from cron
(say, every few minutes), and it will either quickly exit
if there is nothing to do, or it will hand off to one
other script to:

=over 4

=item process new XML files

    script/routing/import_routing_files.pl

=item and prepare an e-mail report

    script/routing/send_routing_report.pl

=back

=head2 Config

Credentials and config information are in the usual places in conf/xtracker*,
and there are some new properties in nap*.properties that set some of those up.

Note that the values in the commits are generic, and guaranteed not to work.
You'll need to set up an SMB share somewhere for testing this.

=head2 Dependencies

Also, this code requires Filesys::SmbClient, which, in turn, requires
libsmbclient to be installed.  This library is included in perl-nap
as of version 2011.06.

=cut

use NAP::policy "tt", qw( test );

# use Carp::Always;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Date::Format;

use File::Spec::Functions qw( catdir catfile );
use Filesys::SmbClient;

BEGIN { $ENV{XT_LOGCONF} = 'process_routing.conf'; }

use XTracker::Config::Local qw( config_var );
use XTracker::Logfile       qw( xt_logger );

use Readonly;

my @smb_stat_names = (
    qw( device inode protection num_links uid gid dev_type size blocksize num_blocks atime mtime ctime )
);

Readonly my %SMB_STATS => (
    map { $smb_stat_names[$_] => $_ } (0..$#smb_stat_names)
);

my $dirs = {
    incoming  => {
       desc => 'Routing incoming directory',
       path => config_var('SystemPaths','routing_schedule_incoming_dir')
    },
    ready  => {
       desc => 'Routing ready directory',
       path => config_var('SystemPaths','routing_schedule_ready_dir')
    },
    reports => {
       desc => 'Routing reports directory',
       path => config_var('SystemPaths','routing_reports_dir')
    },
    script => {
       desc => 'Routing script directory',
       path => catdir(config_var('SystemPaths','script_dir'),
                      config_var('Routing','script_dir'))
    }
};

my @actions = (
     {
        desc => 'Import routing files',
        script => 'import_routing_files.pl'
     },
#     {
#        desc => 'Send routing report',
#        script => 'send_routing_report.pl'
#     },
);

my $params = {
    smb => {
        username    => config_var('Routing','samba_username'),
        password    => config_var('Routing','samba_password'),
        workgroup   => config_var('Routing','samba_workgroup')   || '',
        read_size   => config_var('Routing','samba_read_size')   || 131072,
        create_mask => config_var('Routing','samba_create_mask') || '0775'
    },
    dir => {
        create_mask => config_var('Routing','dir_create_mask') || '0775'
    },
    stability => {
        seconds_until_stable   => config_var('Routing','seconds_until_stable')   ||  20,
        seconds_between_checks => config_var('Routing','seconds_between_checks') ||   5,
        max_stability_checks   => config_var('Routing','max_stability_checks')   || 100
    }
};

# allow over-riding of the target shares for testing
my @shares = (
    {
        desc     => 'Pre-delivery shares',
        incoming => {
                         desc => 'Incoming Routing Pre-delivery share',
                        share => $ARGV[0] || config_var('Routing','incoming_predelivery_share'),
                       format => "pre-%s-%04d.xml"
        },
        processed => {
                         desc => 'Processed Routing Pre-delivery share',
                        share => $ARGV[1] || config_var('Routing','processed_predelivery_share')
        }
    },
    {
        desc     => 'Post-delivery shares',
        incoming => {
                         desc => 'Incoming Routing Post-delivery share',
                        share => $ARGV[2] || config_var('Routing','incoming_postdelivery_share'),
                       format => "post-%s-%04d.xml"
        },
        processed => {
                         desc => 'Processed Routing Post-delivery share',
                        share => $ARGV[3] || config_var('Routing','processed_postdelivery_share')
        }
    },
);

foreach my $share (@shares) {
  SHARE_TYPE:
    foreach my $share_type (keys %{$share}) {
        next SHARE_TYPE unless    ref $share->{$share_type} eq 'HASH'
                            && exists $share->{$share_type}{share};

        $share->{$share_type}{uri} = 'smb:'.($share->{$share_type}{share});
    }
}

################################################################
#
# capture the time once for filenaming purposes
#

my $time = time;

################################################################
#
# incorporate the timezone to avoid clock-rewind problems
# (the alternative is UTC in filenames that look out-of-sync
#  for more than half the year)
#

my $date_time_zone_name = time2str('%Y%m%d-%H%M%S-%Z',$time);
my $date_name           = time2str('%Y%m%d',          $time);

################################################################
#
# set up logging to be some kind of sensible
#

################################################################
#
# announce that we're starting with the same time as above
# to make correlating files and a specific program run easier
#

xt_logger->info( "START: processing routing files" );

################################################################
#
# actually do nothing unless we're configured to do something
#

unless ( $params->{smb}{username} && $params->{smb}{password} ) {
    xt_logger->info( "DONE: no SMB username or password configured -- NOTHING TO DO" );

    exit 0;
}

################################################################
#
# okay, here we go...
#

# do all the local directories we need exist already,
# and can we write to them?

foreach my $dir (keys %$dirs) {
    xt_logger->logdie( "$dirs->{$dir}{desc} '$dirs->{$dir}{path}' cannot be found\n" )
        unless -d $dirs->{$dir}{path} && -w $dirs->{$dir}{path};
}

# get a connect to the SMB server -- this dies if it can't connect
my $smb;

eval {
    $smb = Filesys::SmbClient->new( username  => $params->{smb}{username},
                                    password  => $params->{smb}{password},
                                    workgroup => $params->{smb}{workgroup}
                                  );
};

if (my $se = $@) {
    xt_logger->logdie( "Unable to get SMB client object with username $params->{smb}{username}: $se\n" );
}

sub read_files_from {
    my $share = shift;

    xt_logger->logdie( "Must provide a share with an incoming URI" )
        unless $share && exists $share->{incoming} && exists $share->{incoming}{uri};

    my $DIR = $smb->opendir($share->{incoming}{uri})
        or xt_logger->logdie( "Unable to read $share->{incoming}{desc} '$share->{incoming}{uri}': $!\n" );

    my @filenames = grep { /\.xml$/i } $smb->readdir($DIR);

    $smb->closedir($DIR);

    return @filenames;
}

################################################################
#
# abstracted out in case we need to be fancier when
# coping with filenames that are insane, such as full
# of spaces and random characters and text messages
#
# ...which actually happens with RouteMonkey
#

sub make_sharename {
    my ($uri, $filename) = @_;

    # doesn't use catfile, because that will eat the '//' at the start
    return "$uri/$filename";
}

sub get_file_info {
    my ($fileshare, @stats) = @_;

    xt_logger->logdie( "BUG: get_file_info() requires a share and at least one stat index" )
        unless $fileshare && @stats;

    my @file_stat = $smb->stat($fileshare);

    return unless @file_stat;

    return  @file_stat[@stats];
}

sub find_newest_file {
    my ($share, @filenames) = @_;

    # let's be quick in the trivial cases

    return unless @filenames;

    return $filenames[0] if scalar(@filenames) == 1;

    my $filemtimes;

    foreach my $filename (@filenames) {
        my ($mtime,$size) = get_file_info( make_sharename( $share->{incoming}{uri}, $filename ),
                                           @SMB_STATS{qw{ mtime size }});

        # perhaps we should be harsher if we can't stat a file whose
        # name we've just been given...
        $filemtimes->{$filename} = $mtime || 0;
    }

    return ( sort { $filemtimes->{$a} <=> $filemtimes->{$b} } @filenames )[-1];
}

sub wait_for_stabilization {
    my ($share, $filename) = @_;

    my $incoming_fileshare = make_sharename( $share->{incoming}{uri}, $filename );

    # why do we do file stability checks?
    # Because we might spot the file while it's still being
    # written, so we want to wait until that looks done.
    #
    # As some network writes aren't synchronized to all clients
    # instantly, we apply a little delay in the checking process.

    my ($file_mtime,$file_size) = get_file_info( $incoming_fileshare, 
                                                 @SMB_STATS{qw{ mtime size }});

    if ((time() - $file_mtime) < $params->{stability}{seconds_until_stable}) {
        my $checks_remaining = $params->{stability}{max_stability_checks};

        my $last_file_size = -1;  # drive us around the loop at least once

        while ( (my $file_age = time() - $file_mtime) < $params->{stability}{seconds_until_stable}
              || ($file_size != $last_file_size)) {

            unless ( $checks_remaining-- > 0 ) {
                return 0;
            }

            my $seconds_until_stable = $params->{stability}{seconds_between_checks} - $file_age;

            sleep ( $seconds_until_stable > $params->{stability}{seconds_between_checks}
                    ? $seconds_until_stable
                    : $params->{stability}{seconds_between_checks}
                  ) ;

            $last_file_size = $file_size;

            ($file_mtime, $file_size) = get_file_info( $incoming_fileshare,
                                                       @SMB_STATS{qw{ mtime size }});
        }
    }

    return 1;
}

sub fetch_and_move_files {
    my ($share, $processing_id, @filenames) = @_;

    my $sequence = 0;

    my $processed_dirshare = $share->{processed}{uri};
    my $processed_date_dirshare = make_sharename($share->{processed}{uri},$date_name);

    my $processed_dir = $smb->opendir($processed_date_dirshare);

    if ( $processed_dir ) {
        # okay, it's there
        $smb->closedir( $processed_dir );
    }
    else {
        # get the parent into play

        if ( my $parent_dir = $smb->opendir( $processed_dirshare ) ) {
            # it's there
            $smb->closedir( $parent_dir );
        }
        else {
            $smb->mkdir($processed_dirshare, oct($params->{smb}{create_mask}) )
                or xt_logger->logdie( "Unable to create $share->{processed}{desc} '$processed_dirshare': $!\n" );
        }

        $smb->mkdir($processed_date_dirshare, oct($params->{smb}{create_mask}) )
            or xt_logger->logdie( "Unable to create dated subdir of $share->{processed}{desc} '$processed_date_dirshare': $!\n" );
    }

    my $processed;

  FILE:
    foreach my $filename (@filenames) {
        my $remote_fileshare = make_sharename($share->{incoming}{uri}, $filename);

        my $formatted_filename = sprintf($share->{incoming}{format},
                                         $processing_id,
                                         $sequence++);

        my $incoming_path = catdir($dirs->{incoming}{path}, $formatted_filename);

        my ($size,$atime,$mtime) = get_file_info($remote_fileshare,
                                                 @SMB_STATS{qw{size atime mtime}});

        my $remote_fd = $smb->open($remote_fileshare);

        # local subroutine via closure
        #
        # done this way within the loop so that it can pick up
        # loop-local variables to work on without having
        # to have them passed in as parameters all the time

        local *warn_failure = sub { ## no critic(ProhibitLocalVars)
            my $reason = shift;

            xt_logger->logdie( "BUG: warn_failure() not provided with a reason" )
                unless $reason;

            $processed->{failed}{$filename}={ remote_fileshare   => $remote_fileshare,
                                              formatted_filename => $formatted_filename,
                                              reason             => $reason
                                            };

            xt_logger->logwarn( "$reason\n" );
        };

        unless ( $remote_fd ) {
            warn_failure( "Unable to open $remote_fileshare for reading -- SKIPPING: $!" );

            next FILE;
        }

        # we explode on being unable to write locally, because that's
        # unlikely to be some transitory or recoverable situation within
        # the lifetime of this program's run

        open( my $incoming_fd, '>:utf8', $incoming_path )
            or xt_logger->logdie( "Unable to open $incoming_path for writing: $!\n" );

        my $fetched_size = 0;

      CHUNK:
        while (defined(my $buf = $smb->read($remote_fd, $params->{smb}{read_size}))) {
            last CHUNK unless $buf;

            print $incoming_fd $buf
                or xt_logger->logdie( "Unable to write ".(length $buf)."-sized chunk to $incoming_path: $!\n" );

            $fetched_size += length $buf;
        }

        # don't treat this as fatal, mainly because I'm not sure under what
        # conditions this might happen (other that writing to a network drive,
        # but that's not expected for production use, and it's not clear how
        # b0rked the file would be in that case)

        unless ( close $incoming_fd ) {
            warn_failure( "Unable to close $incoming_path -- trying to continue: $!" );

            unlink $incoming_path; # we'll try again later

            next FILE;
        }

        if ($smb->close($remote_fd) == -1) {
            warn_failure( "Unable to close $remote_fileshare -- trying to continue: $!" );

            # keep going in this case
        }

        unless ($size == $fetched_size) {
            warn_failure( "Fetch $incoming_path size ($fetched_size) differs from original ($size) -- SKIPPING\n" );

            unlink $incoming_path;

            next FILE;
        }

        unless ( utime($atime, $mtime, $incoming_path) ) {
            warn_failure( "Unable to set times on $incoming_path -- trying to continue: $!" );

            # keep going in this case as well
        }

        ################################################################
        #
        # push the remote file to one side on the remote share,
        # so we don't process it again next time

        my $processed_fileshare = make_sharename($processed_date_dirshare, $filename);

        unless ( $smb->rename( $remote_fileshare, $processed_fileshare ) ) {
            warn_failure( "Unable to move $remote_fileshare to $processed_fileshare -- trying to continue: $!" );

            # keep going in this case as well
        }

        ################################################################
        #
        # and make the file available for local processing
        #

        ################################################################
        #
        # should we skip empty files?  we know they won't be processed successfully,
        # but if we just throw them away, we'll not know, by examining the file system,
        # that the file was handled, but ignored
        #

        my $ready_path = catdir($dirs->{ready}{path}, $formatted_filename);

        unless ( rename($incoming_path, $ready_path) ) {
            warn_failure( "Unable to move $formatted_filename to $dirs->{ready}{path}: $!" );

            next FILE;
        }

        $processed->{ready}{$filename}={ remote_fileshare   => $remote_fileshare,
                                         formatted_filename => $formatted_filename,
                                         size_in_bytes      => $size,
                                         mtime              => $mtime,
                                       };
    }

    return $processed;
}

sub report_problems {
    my @problems = @_;

    foreach my $problem (@problems) {
        xt_logger->logwarn( "PROBLEM with '$problem->{remote_fileshare}'/'$problem->{formatted_filename}': $problem->{reason}\n" );
    }
}

my (@to_be_processed,@to_be_reported)=((),());

my $processing_id = $date_time_zone_name.q{-}.sprintf("%05d",$$); # shouldn't repeat on this box

SHARE:
foreach my $share (@shares) {
    local $@;

    my @filenames;

    # done as a pile of independent evals, rather than one big one,
    # because perl doesn't like it when you exit an eval with a next,
    # for reasons that at all to do with how perl is implemented, and
    # not to do with what works or makes sense

    eval {
        @filenames = read_files_from( $share );
    };

    if (my $e = $@) {
        xt_logger->logdie( "Fatal error while reading share '$share->{desc}': $e\n" );
    }

    next SHARE unless @filenames;

    my $newest_file;

    eval {
        $newest_file = find_newest_file( $share, @filenames );
    };

    if (my $e2 = $@) {
        xt_logger->logdie( "Fatal error while sorting files from share '$share->{desc}': $e2\n" );
    }

    my $stabilized = 0;

    eval {
        $stabilized = wait_for_stabilization( $share, $newest_file );
    };

    if (my $e3 = $@) {
        xt_logger->logdie( "Fatal error while waiting for files to stablize on '$share->{desc}': $e3\n" );
    }

    unless ( $stabilized ) {
        xt_logger->logwarn( "File $newest_file on share $share->{desc} took too long to stabilize\n" );

        next SHARE;
    }

    eval {
        my $processed = fetch_and_move_files( $share, $processing_id, @filenames );

        push @to_be_processed, values %{$processed->{ready}};
        push @to_be_reported,  values %{$processed->{failed}};
    };

    if (my $e4 = $@) {
        xt_logger->logdie( "Fatal error while fetching data from share '$share->{desc}': $e4\n" );
    }
}

if ( @to_be_reported ) {
    report_problems( @to_be_reported );
}

unless ( @to_be_processed ) {
    xt_logger->info( "DONE: no routing files to process" );

    # return 0 iff there were no problems, 1 otherwise
    # relies on exit '' aliasing to exit 0 (which it does)

    exit !! @to_be_reported;
}

# okay, now we need somewhere to stick the processing report for emailing, maybe
my $dated_reports_dirpath = catdir($dirs->{reports}{path},$date_time_zone_name);

mkdir $dated_reports_dirpath, oct($params->{dir}{create_mask})
    or xt_logger->logdie( "Unable to create $dirs->{reports}{desc} $dated_reports_dirpath: $!\n" );

################################################################
#
# run the routing
#

my $routing_dir=$dirs->{script}{path};

my $db_host=config_var('Database_xtracker','db_host');
my $db_name=config_var('Database_xtracker','db_name');

ACTION:
foreach my $action (@actions) {
    my $env = qq{XT_ROUTING_HOME='$routing_dir'; DB_HOST='$db_host'; DB_NAME='$db_name'; export XT_ROUTING_HOME DB_HOST DB_NAME; };

    my $cmd_return = eval {
        my $cmdline = qq{$env '$routing_dir/$action->{script}' '$dated_reports_dirpath'};

        `$cmdline`; ## no critic(ProhibitBacktickOperators)
    };

    if (my $e = $@) {
        xt_logger->logdie( "$action->{desc} failed: $e\n" );
    }

    if ($cmd_return) {
        xt_logger->logdie( "$action->{desc} returned $cmd_return\n" );
    }
}

xt_logger->info( "DONE: processing routing files" );

exit 0;
