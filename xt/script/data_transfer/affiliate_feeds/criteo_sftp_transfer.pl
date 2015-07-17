#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;

=head1 criteo_sftp_transfer.pl

=head2 USAGE

This will be run as a daily cronjob, at the same time as the cronjob
to transfer the linkshare affiliate feed.

It requires no arguments, and will silently succeed or throw exceptions
on failure.

It depends on the internal sFTP server being running and that the cronjob 
to create the feed for linkshare has completed (because it uses that feed
file).

=head2 BACKGROUND

This is a temporary solution to transfer a product feed to a company called
Criteo. It uses the feed generated daily for linkshare and copies it to a
NAP managed sFTP server that Criteo have access to.

They will be grabbing this feed daily so they can show personalised ads to
users who abandoned their cart.

This script will be removed as soon as work to enhance the API is complete.

Full details can be seen in http://jira.nap/browse/EN-1358.

=cut

## The NAP sFTP server doesn't allow setattr operations (or something similar)
## and you used to be able to pass Net::SFTP::put() an option to tell it not
## to bother with the do_fsetstat call but now you can't so we are 
## monkey patching. This isn't ideal but this is a temporary solution
## anyway. If we don't do this the transfer fails.
use Net::SFTP;
*Net::SFTP::do_fsetstat = sub { };

use DateTime;

use Exception::Class (
    'FileNotFoundException' => {
        description => 'File does not exist in location specified',
        fields => 'filename',
    },
    'FileTransferException' => {
        description => 'There was a problem sFTPing the file to the host',
        fields => [ 'filename', 'host', 'port', 'username' ],
    }
);

my $sftp = setup_sftp_connection();
copy_feed_via_sftp( $sftp );

=head2 METHODS

=head3 setup_sftp_connection

Instantiates a Net::SFTP object with hardcoded arguments to open a connection
to the NAP sFTP server for dumping affiliate feeds.

=cut
sub setup_sftp_connection {

    my $host                = 'lamp01.gs2.nap';
    my $port                = '22';
    my $user                = 'criteo';
    my $id_files            = [ '/usr/local/httpd/keys/affiliate_sftp' ];
    my $known_hosts_file    = '/usr/local/httpd/keys/known_hosts';

    my $sftp = Net::SFTP->new(
        $host,
        user     => $user,
        debug    => 0,
        ssh_args => {
            port           => $port,
            identity_files => $id_files,
            protocol       => 2, # Net::SFTP requires Net::SSH::Perl::SSH2
            options        => ['UserKnownHostsFile '. $known_hosts_file]
        }
    );
    return $sftp;

}

=head3 copy_feed_via_sftp

Checks the feed file exists and then sFTPs the file if so. Requires a Net::SFTP
object.

=cut
sub copy_feed_via_sftp {
    my ( $sftp ) = @_;

    my $filename;

    foreach (qw/ AM INTL /) {
        $filename = check_file_exists( $_ );
        sftp_file( $sftp, $filename, $_ );
    }

}

=head3 check_file_exists

Generates the correct filename, based on the date, and checks it exists.
Returns the fully-qualified filename if it exists or throws a FileNotFound
exception if it doesn't exist.

=cut
sub check_file_exists {
    my ( $location ) = @_;

    my $base_filename;
    if ($location eq 'AM') {
        $base_filename = '35291_nmerchandis';
    }
    elsif ($location eq 'INTL') {
        $base_filename = '35290_nmerchandis';
    }

    my $directory = '/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/';
    my $format = '.txt';
    my $dt = DateTime->now;
    my $date = $dt->year . sprintf("%02d", $dt->month) . sprintf("%02d", $dt->day);

    my $filename = $base_filename . $date . $format; 
    
    my $absolute_filename = $directory . $filename;
    if ( -e $absolute_filename ) {
        return $absolute_filename;
    } 
    else {
        FileNotFoundException->throw(
            error => 'Unable to locate the affiliate feed file',
            filename => $absolute_filename, 
        );
    }

}

=head3 sftp_file

Use a Net::SFTP object to sFTP a given file. Assumes the file exists.
Will throw a FileTransferException if the status after transfering is not
'SSH2_FX_OK' - which is what it should be on success, according to the 
Net::SFTP documentation.

=cut
sub sftp_file {
    my ( $sftp, $filename, $location ) = @_;
   
    my $remote_filename;
    
    if ( $location eq 'AM' ) {
        $remote_filename = '/transfer/criteo_product_feed_AM.txt';
    }
    elsif ( $location eq 'INTL' ) {
        $remote_filename = '/transfer/criteo_product_feed_INTL.txt';
    }
    
    $sftp->put( $filename, $remote_filename );
    
    #print STDERR "\$sftp->status == " . $sftp->status. "\n";
    
    ## Comment the following out as it seems to never return
    ## 'SSH2_FX_OK'
    #if ( $sftp->status ne 'SSH2_FX_OK' ) {
    #    FileTransferException->throw(
    #        error => 'Unable to transfer the feed file to the sFTP server',
    #        filename => $filename,
    #        host => 'lamp01.gs2.nap',
    #        port => '22',
    #        username => 'criteo',
    #    ) 
    #};

}
