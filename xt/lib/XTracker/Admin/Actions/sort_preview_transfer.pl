#!/usr/local/perl5.8/bin/perl

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/../../../";
use Carp;
use Data::Dumper;
use File::Glob                              qw(:glob);

use XTracker::Comms::DataTransfer           qw(transfer_product_sort_data :transfer_handles);
use XTracker::Database                      qw(:common);
use XTracker::Database::Product::SortOrder  qw(update_pws_sort_data);
use XTracker::Logfile                       qw(xt_logger);

local $| = 1;


my $lockname    = '/tmp/xt_sort_preview_transfer';
my $lockglob    = $lockname . '_*.lock';
my $lockfile    = $lockname . '_' . time . '.lock';

my $environment = 'staging';
my $destination = 'preview';

## initialise logger (text file)
my $logger  = xt_logger('XTracker::Comms::DataTransfer');

## validation regexps
my $regexp_source       = qr{\Axt_(?:intl|am)\z};
my $regexp_sink         = qr{\Apws_(?:intl|am)\z};
my $regexp_environment  = qr{\A(?:live|staging)\z};
my $regexp_destination  = qr{\A(?:preview|main)\z};

## validate option arguments
my $msg_option_error = '';
$msg_option_error .= "Invalid environment ($environment)\n" if $environment !~ m{$regexp_environment}xms;
$msg_option_error .= "Invalid destination ($destination)\n" if $destination !~ m{$regexp_destination}xms;
if ( ($destination eq 'preview') && ($environment ne 'staging') ) {
    $msg_option_error .= "environment must be 'staging' for destination 'preview'";
}
$logger->logcroak($msg_option_error) if $msg_option_error;


## check for lock file, and create if none exist
my @lock_list = bsd_glob($lockglob);

if ( scalar @lock_list ) {
    die "Lockfile/s already exist: (@{[join(', ', @lock_list)]})\n";
}
else {
    open( my $fh, '>', $lockfile ) or die "Cannot open $lockfile for writing\n";
    print $fh $$;
    close $fh;
}


my $dbh_ref = get_transfer_db_handles( { source_type => 'readonly', environment => $environment } );


eval {
    $logger->info(">>>>> PWS Product Sort Order - Staging Preview\n\n");

    my $sort_pids_ref = update_pws_sort_data( { destination => $destination } );
    $logger->info("Transferring @{[scalar @{$sort_pids_ref}]} PIDs...");

    foreach my $product_id ( @{$sort_pids_ref} ) {
        $logger->info("Begin data transfer (PID: $product_id, $environment, $destination)");
        transfer_product_sort_data({
            dbh_ref     => $dbh_ref,
            product_ids => $product_id,
            destination => $destination,
        });
        $logger->info("[ Committed (PID: $product_id, $environment, $destination) ]\n") if $dbh_ref->{dbh_sink}->commit;
    };

};
if ($@) {
    $logger->info("ERROR: $@\n");
    $logger->info("[ ** Rolled Back ($environment, $destination) ** ]\n") if $dbh_ref->{dbh_sink}->rollback;
}


$dbh_ref->{dbh_sink}->disconnect;


END {
    $dbh_ref->{dbh_sink}->disconnect if $dbh_ref->{dbh_sink};
    $logger->info("PWS Product Sort Order - Staging Preview <<<<<\n\n");

    ## remove lock file
    unlink($lockfile);
}

__END__
