#!/opt/xt/xt-perl/bin/perl

use NAP::policy 'tt';
use FindBin::libs;
use FindBin::libs 'base=lib_dynamic';
use XTracker::Database qw( schema_handle );

use XTracker::DHLDeliveryTimes::SFTPMonitor;
use XTracker::DHLDeliveryTimes::FFSTATParser;

=head1 dhl_delivery_time_reader

This is a script that connects to a remote sftp server
at DHL and downloads pipe delimited CSV files that
contain the times that shipments were actually delivered to
peoples' houses.

This information can be used to derive end-to-end metrics and
to feed in information about SLAs.

=cut


my $sftp_monitor; # global to allow for reuse

sub main {

    given ($ARGV[0]) {
        when (undef) {
            check();
            process_files();
        }
        when ('--check-only') {
            check();
        }
        when ('--process-only') {
            process_files();
        }
        when ('--status') {
            status();
        }
        default {
            print_usage();
        }
    };

}

sub print_usage {
  print STDERR "Usage: $0 [--check-only|--process-only|--status]\n";
  exit 1;
}

sub check {
    $sftp_monitor = XTracker::DHLDeliveryTimes::SFTPMonitor->new();
    $sftp_monitor->check_directory();
}

sub process_files {
    # reuse existing connection if possible.
    my $args = (defined($sftp_monitor) ? { sftp_monitor => $sftp_monitor } : {});

    my $parser = XTracker::DHLDeliveryTimes::FFSTATParser->new($args);
    $parser->process_files();
}

sub status {
    my $schema = schema_handle();
    my $remaining = $schema->resultset('Public::DHLDeliveryFile')->get_remaining_count();
    print "Remaining files to process: $remaining\n";
}

main();
