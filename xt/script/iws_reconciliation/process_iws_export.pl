#!/opt/xt/xt-perl/bin/perl
#
# check if a complete IWS file has appeared on a remote SMB share, and,
# if so, copy it to the processing area, kick off a reconcilation process,
# and move it to one side on the SMB share
#
#
# this script is designed to be run from cron every few minutes,
# and to return quickly if there is nothing to do.
#
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)

=head1 Daily reconciliation reporting.


=head2 Overview

Here is the approach I'm taking for now:

=over 4

=item get a new IWS reconcilation dump

=over 2

=item at present, this means watching an SMB share somewhere waiting for a new dump file to appear, then scooping it up

=item we need to be careful that we don't scoop up the file while it's still being written to

=back

=item create a working dir for the reconciliation run in a date-stamped directory [which is currently defined as /var/data/xt_static/reports/reconciliation/]

=item dump a matching XT reconciliation dump (so it's timed as closely as possible with the IWS dump) into the working dir

=item  run the reconcilation process in the working dir use its output to create a report on what happened, saved in the same directory

=item e-mail that report to whomever

=item tidy up, maybe

=back

=head2 Structure

The core script that drives the process is:

    script/iws_reconciliation/process_iws_export.pl

This script is designed to be run frequently from cron
(say, every few minutes), and it will either quickly exit
if there is nothing to do, or it will hand off to three
other scripts, all in the same directory, to:

=over 4

=item dump XT

    script/iws_reconciliation/xt_export_all.sh

=item run a reconciliation and email report

    script/iws_reconciliation/reconcile_with_iws.pl

=back

Of those, the first two are pre-existing scripts, and the
last one is also new.

=head2 Config

Credentials and config information are the usual places in conf/xtracker*,
and there are some new properties in nap*.properties that set some of those up.

Note that the values in the commits are generic, and guaranteed not to work.
You'll need to set up an SMB share somewhere for testing this.

=head2 Dependencies

Also, this code requires Filesys::SmbClient, which, in turn, requires
libsmbclient to be installed.  I don't yet know the proper process for
getting these added to the build/perl-nap/whatever, but I guess we
have a couple of weeks to find out, because there must be some way to
to it.  (I asked Chisel, but am not sure I explained it right: he
suggested pushing to master, then cherry-picking, which is surely
answering a different questions.  Anyway.)

=cut

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Date::Format;

use File::Spec::Functions qw( catdir catfile );
use Filesys::SmbClient;

use XTracker::Config::Local q(config_var);

my $dirs = {
    reports  => {
       desc => 'Reconciliation reports directory',
       path => catdir(config_var('SystemPaths','reports_dir'),
                      config_var('Reconciliation','reports_dir'))
    },
    script => {
       desc => 'Reconciliation script directory',
       path => catdir(config_var('SystemPaths','script_dir'),
                      config_var('Reconciliation','script_dir'))
    }
};

my $files = {
    iws_stock_export => {
        desc => 'IWS stock export file',
        name => config_var('Reconciliation','iws_stock_export_file')
    },
    xt_stock_export  => {
        desc => 'XT stock export file',
        name => config_var('Reconciliation','xt_stock_export_file')
    }
};

my @actions = (
     {
        desc => 'XT dump',
        script => 'xt_export_all.sh'
     },
     {
        desc => 'XT reconciliation',
        script => 'reconcile_with_iws.pl'
     },
);

my $params = {
    smb => {
        username    => config_var('Reconciliation','iws_samba_username'),
        password    => config_var('Reconciliation','iws_samba_password'),
        workgroup   => config_var('Reconciliation','iws_samba_workgroup')   || '',
        read_size   => config_var('Reconciliation','iws_samba_read_size')   || 131072,
        create_mask => config_var('Reconciliation','iws_samba_create_mask') || '0775'
    },
    dir => {
        create_mask => config_var('Reconciliation','dir_create_mask') || '0775'
    },
    stability => {
        seconds_until_stable   => config_var('Reconciliation','seconds_until_stable')   ||  20,
        seconds_between_checks => config_var('Reconciliation','seconds_between_checks') ||   5,
        max_stability_checks   => config_var('Reconciliation','max_stability_checks')   || 100
    }
};

# allow over-riding of the target shares for testing
my $shares = {
    incoming => {
         desc => 'Incoming IWS SMB share',
        share => $ARGV[0] || config_var('Reconciliation','iws_incoming_share_path'),
    },
    processed => {
         desc => 'Processed IWS SMB share',
        share => $ARGV[1] || config_var('Reconciliation','iws_processed_share_path'),
    }
};

################################################################
#
# okay, here we go...
#

foreach my $dir (keys %$dirs) {
    die "$dirs->{$dir}{desc} '$dirs->{$dir}{path}' cannot be found\n"
        unless -d $dirs->{$dir}{path};
}

my $smb = Filesys::SmbClient->new(
    username  => $params->{smb}{username},
    password  => $params->{smb}{password},
    workgroup => $params->{smb}{workgroup}
);

my (@filenames, $incoming_uri, $processed_uri);
my @iws_hostnames = split m{ }, config_var(qw{Reconciliation iws_hostnames});
for my $host ( @iws_hostnames ) {
    my $uri = sprintf('smb://%s%s', $host, $shares->{incoming}{share});
    # We shouldn't die if we can't open the dir - we probably *do* have a
    # problem. However we want to check the other server in case the dump is
    # there.
    my $DIR;
    unless ( $DIR = $smb->opendir($uri) ) {
        warn "Unable to read $shares->{incoming}{desc} $uri: $!\n";
        next;
    }

    # check if there is a file in that directory that we're expecting
    @filenames = grep { m{\.csv$}i } $smb->readdir($DIR);

    $smb->closedir($DIR);

    next unless @filenames;
    # If we have found files at this point, this is the server we're interested
    # in, so set the uris to what they should be and break the loop
    $incoming_uri = $uri;
    $processed_uri = sprintf('smb://%s%s', $host, $shares->{processed}{share});
    last;
}
exit 0 unless @filenames;

# that doesn't look right...
die "More than one candidate file found in $shares->{incoming}{desc} $incoming_uri\n"
  if @filenames >1;

my $incoming_fileshare = "$incoming_uri/$filenames[0]";

sub get_file_info {
    my $filename = shift;

    my @file_stat = $smb->stat($filename);

    return @file_stat[9,7]; # mtime, size
}

# why do we do file stability checks?
# Because we might spot the file while it's still being
# written, so we want to wait until that looks done.
#
# As some network writes aren't synchronized to all clients
# instantly, we apply a little delay in the checking process.

my ($file_mtime,$file_size) = get_file_info($incoming_fileshare);

if ((time() - $file_mtime) < $params->{stability}{seconds_until_stable}) {
    my $checks_remaining = $params->{stability}{max_stability_checks};

    my $last_file_size = -1;  # drive us around the loop at least once

    while ( (my $file_age = time() - $file_mtime) < $params->{stability}{seconds_until_stable}
          || ($file_size != $last_file_size)) {

        die "File $incoming_fileshare is taking too long to stabilize\n"
            unless $checks_remaining-- > 0;

        my $seconds_until_stable = $params->{stability}{seconds_between_checks} - $file_age;

        sleep ( $seconds_until_stable > $params->{stability}{seconds_between_checks}
                ? $seconds_until_stable
                : $params->{stability}{seconds_between_checks}
              ) ;

        $last_file_size = $file_size;

        ($file_mtime,$file_size) = get_file_info($incoming_fileshare);
    }
}

# create target directory for incoming files

my $date_time_name = time2str('%Y%m%d-%H%M%S',time);

my $reports_dirpath = catdir($dirs->{reports}{path},$date_time_name);

mkdir $reports_dirpath, oct($params->{dir}{create_mask})
    or die "Unable to create $dirs->{reports}{desc} $reports_dirpath: $!\n";

# doesn't use catfile, because that will eat the '//' at the start
my $processed_dirshare = "$processed_uri/$date_time_name";

$smb->mkdir($processed_dirshare, oct($params->{smb}{create_mask}) )
    or die "Unable to create $shares->{processed}{desc} $processed_dirshare: $!\n";

my $iws_stock_export_path = catdir($reports_dirpath,$files->{iws_stock_export}{name});

# We are reading in bytes, so we need to just rewrite them, hence using the
# ':raw' layer.
open( my $iws_stock_export_fd, '>:raw', $iws_stock_export_path )
    or die "Unable to open $iws_stock_export_path for writing: $!\n";

my $incoming_fd = $smb->open($incoming_fileshare)
    or die "Unable to open $incoming_fileshare for reading: $!\n";

CHUNK:
while (defined(my $buf = $smb->read($incoming_fd, $params->{smb}{read_size}))) {
    last CHUNK unless $buf;

    print $iws_stock_export_fd $buf
        or die "Unable to write ".(length $buf)."-sized chunk to $iws_stock_export_path: $!\n";
}

close $iws_stock_export_fd
   or warn "Unable to close $iws_stock_export_path -- trying to continue: $!\n";

if ($smb->close($incoming_fd) == -1) {
    warn "Unable to close $incoming_fileshare -- trying to continue: $!\n";
}

################################################################
#
# push the remote file to one side on the remote share,
# so we don't process it again next time

my $processed_fileshare = "$processed_dirshare/$filenames[0]";

$smb->rename($incoming_fileshare, $processed_fileshare)
    or warn "Unable to move $incoming_fileshare to $processed_fileshare -- trying to continue: $!\n";

################################################################
#
# run the reconciliation
#

my $recon_dir=$dirs->{script}{path};

my $db_host=config_var('Database_xtracker','db_host');
my $db_name=config_var('Database_xtracker','db_name');

ACTION:
foreach my $action (@actions) {
    my $env = qq{XT_RECON_HOME='$recon_dir' DB_HOST='$db_host' DB_NAME='$db_name'};

    my $cmd_return = eval {
        my $cmdline = qq!$env '$recon_dir/$action->{script}' '$reports_dirpath'!;

        `$cmdline`; ## no critic(ProhibitBacktickOperators)
    };

    if (my $e = $@) {
        die "$action->{desc} failed: $e\n";
    }

    if ($cmd_return) {
        die "$action->{desc} returned $cmd_return\n";
    }
}
