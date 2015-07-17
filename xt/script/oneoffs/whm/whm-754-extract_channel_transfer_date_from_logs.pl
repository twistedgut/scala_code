#!/opt/xt/xt-perl/bin perl

use strict;
use warnings;

# Hard-code lib directory so this script can be run from any dir on live
use lib '/opt/xt/deploy/xtracker/lib';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/schema_handle/;
use XTracker::Constants::FromDB qw( :product_channel_transfer_status :channel_transfer_status);

my $schema = schema_handle;

## get channel transfer logs for completed channel transfers

my @log_channel_transfer = $schema->resultset('Public::LogChannelTransfer')->search({status_id => $CHANNEL_TRANSFER_STATUS__COMPLETE})->all;

foreach my $log (@log_channel_transfer){
    my $channel_transfer = $log->channel_transfer;
    my $product = $channel_transfer->product;
    my $product_channels  = $product->product_channel->search({transfer_status_id => $PRODUCT_CHANNEL_TRANSFER_STATUS__TRANSFERRED}); ## should be only one
    ## but just in case loop
    while (my $product_channel = $product_channels->next){
        next if $product_channel->transfer_date;
        print "Setting transfer date for product ". $product->id ." and product channel ".$product_channel->id."\n";
        $product_channel->update({transfer_date => $log->date});
    }
    
}

