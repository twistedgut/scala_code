#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Carp;
use Data::Dumper;
use Getopt::Long;

use XTracker::Comms::DataTransfer           qw(transfer_product_sort_data :transfer_handles);
use XTracker::Database                      qw(:common);
use XTracker::Database::Product::SortOrder  qw(update_pws_sort_data);
use XTracker::Database::Channel             qw(get_channel_details);
use XTracker::Logfile                       qw(xt_logger);

local $| = 1;

## option variables
my $environment     = undef;
my $destination     = undef;
my $channel_name    = undef;

GetOptions(
    'environment=s' => \$environment,
    'destination=s' => \$destination,
    'channel_name=s'     => \$channel_name,
);
$environment = defined $environment ? $environment : '';
$destination = defined $destination ? $destination : '';

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
$msg_option_error .= "Undefined channel_name\n" if not defined $channel_name;
if ( ($destination eq 'preview') && ($environment ne 'staging') ) {
    $msg_option_error .= "environment must be 'staging' for destination 'preview'";
}
$logger->logcroak($msg_option_error) if $msg_option_error;

my $dbh_xt  = get_database_handle( { name => 'xtracker', type => 'readonly' } );
my $channel = get_channel_details( $dbh_xt, $channel_name);

my $dbh_ref; # initialise web handle after call to update_pws_sort_data, so that it doesnt expire

eval {

    $logger->info(">>>>> PWS Product Sort Order\n\n");

    my $sort_pids_ref = update_pws_sort_data( { destination => $destination, channel_id => $channel->{id} } );

    $dbh_ref = get_transfer_db_handles( { source_type => 'readonly', environment => $environment, channel => $channel->{config_section} } );

    $logger->info("Begin data transfer (PIDs: @$sort_pids_ref, $environment, $destination)");
    transfer_product_sort_data({
        dbh_ref     => $dbh_ref,
        product_ids => $sort_pids_ref,
        channel_id  => $channel->{id},
        destination => $destination,
    });
    $logger->info("[ Committed (PIDs: @$sort_pids_ref, $environment, $destination) ]\n") if $dbh_ref->{dbh_sink}->commit;

    $dbh_ref->{dbh_sink}->disconnect;
    $dbh_ref->{dbh_source}->disconnect;
};
if ($@) {
    $logger->info("ERROR: $@\n");
    $logger->info("[ ** Rolled Back ( $environment, $destination) ** ]\n") if $dbh_ref->{dbh_sink}->rollback;
}

END {
    $dbh_ref->{dbh_source}->disconnect if $dbh_ref->{dbh_source};
    $dbh_ref->{dbh_sink}->disconnect if $dbh_ref->{dbh_sink};
    $logger->info("PWS Product Sort Order <<<<<\n\n");
}

__END__
