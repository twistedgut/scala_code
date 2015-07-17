package XTracker::DHLDeliveryTimes::SFTPMonitor;

use NAP::policy 'tt', 'class';
with 'XTracker::Role::WithSchema';

use Net::SFTP;
use XTracker::Config::Local 'config_var';
use XTracker::Logfile 'xt_logger';
use File::Spec::Functions 'catfile';

use Encode 'encode';

=head1 SFTPMonitor

This module is responcible for connecting to one of DHL's
SFTP servers, looking for unprocessed files that import into
XTracker and downloading them.

=cut

has 'sftp_handle' => (
    is      => 'rw',
    isa     => 'Net::SFTP',
    default => sub { return _connect_to_sftp_server() },
    lazy    => 1
);

=head2 _connect_to_sftp_server

Returns an active handle to DHL's SFTP server.

=cut

sub _connect_to_sftp_server {

    # required config variables
    my $sftp_server = config_var('DHLDeliverySFTPServer', 'server');
    my $username    = config_var('DHLDeliverySFTPServer', 'username');
    my $password    = config_var('DHLDeliverySFTPServer', 'password');
    my $debug       = config_var('DHLDeliverySFTPServer', 'debug');

    xt_logger->info("Attempting to connect to SFTP Site: $sftp_server");

    my $sftp_handle = Net::SFTP->new($sftp_server, (
        user     => $username,
        password => $password,
        debug    => $debug,
    )) || die ("Unable to connect to DHL SFTP Server: (server=$sftp_server,error=$@)\n");

    return $sftp_handle;
}

=head2 check_directory

This function and check_file() are the main processing drivers for the solution. Once invoked it performs as 'ls' on
the sftp server and uses a simple algorithm on the results to categorise the work required.

Files already processed are ignored.
New files are identified and logged in the database are requiring processing.
    (which is then actioned by FFSTATParser->process_files() called elsewhere)
Files who's epoch have changed are marked to be reprocessed.

Note: Even though download_file() is in this module (and rightly so), it's not driven
by check_directory(). This function doesn't modify/download files on the local filesystem
in any way.

=cut

sub check_directory {
    my $self = shift;

    my $directory   = config_var('DHLDeliverySFTPServer', 'directory');
    xt_logger->info("Fetching contents of directory");

    $self->sftp_handle->ls($directory, sub {
        my $file_hash = shift;

        # skip these. (yes they are returned)
        return if ($file_hash->{filename} eq '.' || $file_hash->{filename} eq '..');

        $self->check_file(
            $file_hash->{filename},
            $file_hash->{a}->mtime     # mtime, represented as an epoch
        );
    });

}

=head2 check_file

This function works with the function above to help it achieve its listed goals.

=cut

sub check_file {
    my ($self, $filename, $mtime_epoch) = @_;

    # see if file exists or mtime has changed.
    my $dhl_delivery_file = $self->schema->resultset('Public::DHLDeliveryFile')->find({
        filename => $filename
    });

    if (!defined($dhl_delivery_file)) { # we've never seen this file before, process it

        $dhl_delivery_file = $self->schema->resultset('Public::DHLDeliveryFile')->create({
            filename => $filename,
            remote_modification_epoch => $mtime_epoch
        });

        xt_logger->info("first time we've seen $filename, adding to database");

    } elsif ($mtime_epoch > $dhl_delivery_file->remote_modification_epoch) {
       # file contents changed. needs reprocessing

        xt_logger->info("epoch on $filename has changed, preparing to reprocess");
        $dhl_delivery_file->mark_to_reprocess($mtime_epoch);
        $dhl_delivery_file->delete_file();

    }
}

=head2 download_file

Give it a DHLDeliveryFile row from the database and it'll download it to the
local file system.

This is used by FFSTATParser::process_files() when it wants to process a file.

=cut

sub download_file {
    my ($self, $dhl_delivery_file) = @_;

    my $directory = config_var('DHLDeliverySFTPServer', 'directory');
    my $abs_local_file = $dhl_delivery_file->get_absolute_local_filename();
    my $server_filename = catfile($directory, $dhl_delivery_file->filename);

    # find out the file size prior to download...
    my $file_size = $self->get_filesize($dhl_delivery_file);

    xt_logger->info("Performing file download from DHL SFTP server. (name=". $server_filename .", size=$file_size, local file: $abs_local_file)");

    my $file_returned = $self->sftp_handle->get(encode('utf-8', $server_filename), $abs_local_file);

    if (!defined($file_returned)) {
        die("File Download failed (name=". $dhl_delivery_file->filename .", error=$@)");
    } else {
        xt_logger->info("Download of file complete (name=". $dhl_delivery_file->filename . ")");
        return $file_returned;
    }

}

=head2 get_filesize

This is invoked before downloading a file so if the system pauses for a while
it can be used to make sure if that's just because the file is big. To be honest,
the files are all very small and this isn't really that interesting.

It returns an integer describing the file size in bytes.

=cut

sub get_filesize {
    my ($self, $dhl_delivery_file) = @_;

    my $directory   = config_var('DHLDeliverySFTPServer', 'directory');
    my $match;

    $self->sftp_handle->ls($directory, sub {
        my $file_hash = shift;

        if ($dhl_delivery_file->filename eq $file_hash->{filename}) {
            $match = $file_hash->{a}->size;
        }

    });

    die("File not found: $dhl_delivery_file") if (!defined($match));

    return $match;

}

