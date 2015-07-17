#!/opt/xt/xt-perl/bin/perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)

use strict;
use warnings;
use lib             qw(/opt/xt/deploy/xtracker/lib);
use FindBin::libs qw( base=lib_dynamic );
use Carp;
#use Data::Dumper;
use Getopt::Long;
use Time::HiRes     qw(usleep);

use XTracker::Comms::DataTransfer   qw(:transfer_handles :transfer :upload_transfer list_pids_to_upload set_pws_visibility set_xt_product_status);
use XTracker::Constants::FromDB     qw(:upload_transfer_status :upload_transfer_log_action);
use XTracker::Database              qw(get_database_handle);
use XTracker::Database::Channel     qw(get_channel);
use XTracker::Logfile               qw(xt_logger);

local $| = 1;

my $dsp_spacer_start    = "\n" . '>' x 80 . "\n";   #}
my $dsp_spacer_end      = "\n" . '<' x 80 . "\n";   #} for log display
my $dsp_spacer          = "\n" . '~' x 80 . "\n";   #}

my $error_flag      = 0;
my $msg_status      = '';
my $transfer_status = $UPLOAD_TRANSFER_STATUS__UNKNOWN;
my $operator_id;
my $num_products;

## option variables
my $upload_date = undef;
my $channel_id  = undef;
my $environment = undef;
my $locale      = undef;

GetOptions(
    'upload_date=s' => \$upload_date,
    'channel_id=i'  => \$channel_id,
    'environment=s' => \$environment,
    'locale=s'      => \$locale,
);

## initialise logger (text file)
my $logger  = xt_logger('XTracker::Comms::DataTransfer');

## validation regexps
my $regexp_id           = qr{\A\d+\z};
my $regexp_date         = qr{\A\d{4}-\d{2}-\d{2}\z};
my $regexp_locale       = qr{\A(intl|am)\z};
my $regexp_environment  = qr{\A(live|staging)\z};

$logger->logcroak("Invalid upload_date ($upload_date), expecting format YYYY-MM-DD") if $upload_date !~ m{$regexp_date}xms;
$logger->logcroak("Invalid channel_id ($channel_id)") if $channel_id !~ m{$regexp_id}xms;
$logger->logcroak("Invalid environment ($environment), expecting 'live' or 'staging'") if $environment !~ m{$regexp_environment}xms;
$logger->logcroak("Invalid source ($locale), expecting 'intl' or 'am'") if $locale !~ m{$regexp_locale}xms;

my $source  = 'xt_'.$locale;
my $sink    = 'pws_'.$locale;

if ( $environment eq 'live' ) {
    print "WARNING: Uploading to live website!\n\n";  
}

my $dbh_log = get_database_handle( { name => 'xtracker', type => 'readonly' } );

# create upload transfer record
my $transfer_id = insert_upload_transfer( 
    { 
        dbh         => $dbh_log, 
        upload_date => $upload_date, 
        operator_id => 1, 
        source      => $source, 
        sink        => $sink, 
        environment => $environment, 
        channel_id  => $channel_id,
    } 
);

## check for transfers in-progress for the specified upload date
my $upload_transfers_ref = get_upload_transfers( { dbh => $dbh_log, select_by => { fname => 'upload_date', value => $upload_date } } );

foreach my $transfer_ref ( @{ $upload_transfers_ref } ) {
    if ( $transfer_ref->{transfer_status_id} == $UPLOAD_TRANSFER_STATUS__IN_PROGRESS ) {
        $error_flag = 1;
        my $transfer_id = $transfer_ref->{id};
        $logger->logdie("xTracker indicates that there is already a transfer in progress for upload date $upload_date (transfer_id $transfer_id)");
    }
}

my $channel_data = get_channel( $dbh_log, $channel_id );

my $db_log_ref = {
    operator_id => $operator_id,
    transfer_id => $transfer_id,
    dbh_log     => $dbh_log,
};

my $dbh_ref         = get_transfer_db_handles( { source_type => 'transaction', environment => $environment, channel => $channel_data->{config_section} } );
my $product_ids_ref = list_pids_to_upload( { dbh_ref => $dbh_ref, upload_date => $upload_date, channel_id => $channel_id } );
my $num_products    = @{$product_ids_ref};

my $msg_start    = "$dsp_spacer_start\n";
$msg_start      .= "Upload Date: id $upload_date, ";
$msg_start      .= "$num_products products, ";
$msg_start      .= "source: $source\nsink: $sink (environment: $environment)\n";
$msg_start      .= "$dsp_spacer\n";
$msg_start      .= "Beginning transfer: transfer_id $transfer_id\n\n";

$logger->info($msg_start);

my $status_ref = {
    general     => { attempted => 0, succeeded  => [], failed   => [] },
    related     => { attempted => 0, succeeded  => [], failed   => [] },
    inventory   => { attempted => 0, succeeded  => [], failed   => [] },
    reservation => { attempted => 0, succeeded  => [], failed   => [] },
};

set_upload_transfer_status({
    dbh         => $dbh_log,
    transfer_id => $transfer_id,
    status_id   => $UPLOAD_TRANSFER_STATUS__IN_PROGRESS,
});


## Ok, let's transfer some stuff!
PRODUCT:
foreach my $product_id ( @{$product_ids_ref} ) {

    usleep(100000);

    $logger->info(">>>>> Product $product_id\n");

    ## transfer product data (general: catalogue_product catalogue_attribute catalogue_sku catalogue_pricing catalogue_markdown)
    eval {
        $status_ref->{general}{attempted}++;
        transfer_product_data({
            dbh_ref             => $dbh_ref,
            channel_id          => $channel_id,
            product_ids         => $product_id,
            transfer_categories => ['catalogue_product', 'catalogue_attribute', 'navigation_attribute', 'list_attribute', 'catalogue_sku', 'catalogue_pricing', 'catalogue_markdown'],
            sql_action_ref      => {
                                        catalogue_product       => {insert => 1},
                                        catalogue_attribute     => {insert => 1},
                                        navigation_attribute    => {insert => 1},
                                        list_attribute          => {insert => 1},
                                        catalogue_sku           => {insert => 1},
                                        catalogue_pricing       => {insert => 1},
                                        catalogue_markdown      => {insert => 1},
                                   },
            db_log_ref          => $db_log_ref,
        });
        
        if ( $dbh_ref->{dbh_sink}->commit() ) {
            $logger->info("Product data transfer (general) committed: $product_id\n\n");
        }
        push @{ $status_ref->{general}{succeeded} }, $product_id;
    };
    if ($@) {
        if ( $dbh_ref->{dbh_sink}->rollback() ) {
            $logger->info("Product data transfer (general) ** Rolled Back **: $product_id\n\n");
        }
        $logger->debug("Error! Product: $product_id - $@\n");
        push @{ $status_ref->{general}{failed} }, $product_id;
        $error_flag = 1;
        next PRODUCT;
    }


    ## transfer product inventory
    eval {
        $status_ref->{inventory}{attempted}++;
        transfer_product_inventory({
            dbh_ref         => $dbh_ref,
            channel_id      => $channel_id,
            product_ids     => $product_id,
            sql_action_ref  => { saleable_inventory => {insert => 1} },
            db_log_ref      => $db_log_ref,
        });

        if ( $dbh_ref->{dbh_sink}->commit() ) {
            $logger->info("Product inventory transfer committed: $product_id\n");
        }
        $dbh_ref->{dbh_source}->commit() if ($dbh_ref->{sink_environment} eq 'live');
        push @{ $status_ref->{inventory}{succeeded} }, $product_id;
    };
    if ($@) {
        if ( $dbh_ref->{dbh_sink}->rollback() ) {
            $logger->info("Product inventory transfer ** Rolled Back **: $product_id\n");
        }
        $logger->info("Product inventory logging ** Rolled Back ** in source: $product_id\n\n") if $dbh_ref->{dbh_source}->rollback();
        $logger->debug("Error! Product: $product_id - $@\n");
        push @{ $status_ref->{inventory}{failed} }, $product_id;
        $error_flag = 1;
        next PRODUCT;
    }


    if ($dbh_ref->{sink_environment} eq 'live') {
    
        ## transfer product reservations
        eval {
            $status_ref->{reservation}{attempted}++;
            transfer_product_reservations({
                dbh_ref     => $dbh_ref,
                channel_id  => $channel_id,
                product_ids => $product_id,
                db_log_ref  => $db_log_ref,
            });
            
            $logger->info("Product reservation transfer committed: $product_id\n") if $dbh_ref->{dbh_sink}->commit();
            $logger->info("Product reservation logging/updates committed to source: $product_id\n\n") if $dbh_ref->{dbh_source}->commit();
            push @{ $status_ref->{reservation}{succeeded} }, $product_id;
        };
        if ($@) {
            $logger->info("Product reservation transfer ** Rolled Back **: $product_id\n") if $dbh_ref->{dbh_sink}->rollback();
            $logger->info("Product reservation logging/updates ** Rolled Back ** in source: $product_id\n\n") if $dbh_ref->{dbh_source}->rollback();
            $logger->debug("Error! Product: $product_id - $@\n");
            push @{ $status_ref->{reservation}{failed} }, $product_id;
            $error_flag = 1;
            next PRODUCT;
        }
    
    }
    else {

        $logger->info("Product reservation transfer skipped - sink_environment is $dbh_ref->{sink_environment}\n\n");
        
        ## set visibility/status (staging)
        eval {
            set_pws_visibility( { dbh => $dbh_ref->{dbh_sink}, product_ids => $product_id, type => 'product', visible => 1 } );
            set_pws_visibility( { dbh => $dbh_ref->{dbh_sink}, product_ids => $product_id, type => 'pricing', visible => 1 } );
            set_xt_product_status( { dbh => $dbh_ref->{dbh_source}, product_ids => $product_id, staging => 1, channel_id => $channel_id } );
            $logger->info("PWS ($dbh_ref->{sink_environment}) product 'is_visible' flag set: $product_id\n") if $dbh_ref->{dbh_sink}->commit();
            $logger->info("xT product 'staging' and 'visible' flags set: $product_id\n") if $dbh_ref->{dbh_source}->commit();
        };
        if ($@) {
            $logger->info("Failed to set PWS product 'is_visible' flag: $product_id\n") if $dbh_ref->{dbh_sink}->rollback();
            $logger->info("Failed to set xT product 'staging' and 'visible' flags: $product_id\n") if $dbh_ref->{dbh_source}->rollback();
            $logger->debug("Error! Product: $product_id - $@\n");
        }

    }

} continue {
    $logger->info("Product $product_id <<<<<\n\n");
} ## END PRODUCT

my @pids_inventory_succeeded    = @{ $status_ref->{inventory}{succeeded} };
my @pids_reservation_succeeded  = @{ $status_ref->{reservation}{succeeded} };

## set visibility/status (live)
if ( ($dbh_ref->{sink_environment} eq 'live') && scalar @pids_reservation_succeeded ) {

    ## set PWS visibility and xT product statuses
    eval {
        $logger->info("Setting product visibility and status flags...\n");
        set_xt_product_status( { dbh => $dbh_ref->{dbh_source}, product_ids => \@pids_reservation_succeeded, live => 1, channel_id => $channel_id } );
        $logger->info("xT product 'live' and 'visible' flags set\n") if $dbh_ref->{dbh_source}->commit();
    };
    if ($@) {
        $logger->info("Failed to set xT product 'live' and 'visible' flags\n") if $dbh_ref->{dbh_source}->rollback();
        $logger->debug("Error! $@\n");
        $error_flag = 1;
    }
   
}


## transfer related products
foreach my $product_id (@pids_inventory_succeeded) {

    eval {
        $status_ref->{related}{attempted}++;
        transfer_product_data({
            dbh_ref             => $dbh_ref,
            product_ids         => $product_id,
            transfer_categories => 'related_product',
            sql_action_ref      => { related_product => {insert => 1} },
            db_log_ref          => $db_log_ref,
            channel_id          => $channel_id,
        });
        
        if ( $dbh_ref->{dbh_sink}->commit() ) {
            $logger->info("Product data transfer (related products) committed: $product_id\n\n");
        }
        push @{ $status_ref->{related}{succeeded} }, $product_id;
    };
    if ($@) {
        if ( $dbh_ref->{dbh_sink}->rollback() ) {
            $logger->info("Product data transfer (related products) ** Rolled Back **: $product_id\n\n");
        }
        $logger->debug("Error! Product: $product_id - $@\n");
        push @{ $status_ref->{related}{failed} }, $product_id;
        $error_flag = 1;
    }

} ## END foreach



$transfer_status = $UPLOAD_TRANSFER_STATUS__COMPLETED_SUCCESSFULLY;

$dbh_ref->{dbh_source}->disconnect;
$dbh_ref->{dbh_sink}->disconnect;

$logger->info("Transfer done: upload_date $upload_date; transfer_id $transfer_id\n\n");


## build status message and summary data
my $transfer_summary_ref = { transfer_id => $transfer_id, summary_records => [] };
my $summary_record_ref;

STATUS_CATEGORY:
foreach my $status_category ( qw(general inventory reservation related) ) {

    my $attempted = $status_ref->{$status_category}{attempted};

    my $summary_record_ref = { category => $status_category, num_pids_attempted => $attempted };    
    
    if (not $attempted) {
        $msg_status .= "\nData transfer ($status_category) skipped!\n\n";
        next STATUS_CATEGORY;
    }
    

    foreach my $status ( qw(succeeded failed) ) {
        
        my $product_count   = scalar @{ $status_ref->{$status_category}{$status} };
        
        $summary_record_ref->{ 'num_pids_' . $status } = $product_count;

        $msg_status .= "\nData transfer ($status_category) $status for $product_count of $attempted products";
        
        if ($product_count) {
            $msg_status .= ":-\n@{ [ join( ', ', @{ $status_ref->{$status_category}{$status} } ) ] }";   
        }

    }
    $msg_status .= "\n\n";
    
    push @{ $transfer_summary_ref->{summary_records} }, $summary_record_ref;

} ## END STATUS_CATEGORY

$logger->info($msg_status);



END {

    $dbh_ref->{dbh_source}->disconnect if $dbh_ref->{dbh_source};
    $dbh_ref->{dbh_sink}->disconnect if $dbh_ref->{dbh_sink};
    
    
    if ($transfer_id) {

        if ( $error_flag || $@ ) {
            $transfer_status = $UPLOAD_TRANSFER_STATUS__COMPLETED_WITH_ERRORS;
        }
        
        set_upload_transfer_status({
            dbh         => $dbh_log,
            transfer_id => $transfer_id,
            status_id   => $transfer_status,
        });

        insert_upload_transfer_summary({
            dbh                 => $dbh_log,
            summary_data_ref    => $transfer_summary_ref,
        });

    }
    
    $dbh_log->disconnect;
    
    my $msg_exit = $error_flag ? "Uh-oh!  Looks like there were errors." : "*** END ***";
    $logger->info("$msg_exit$dsp_spacer_end\n\n");
    
    #print "\n$msg_status\n\n$msg_exit$dsp_spacer_end\n";
}



__END__

