#!/usr/bin/env perl
use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/schema_handle/;

my $schema = schema_handle;
my $dbh = $schema->storage->dbh;
my $logs = $schema->resultset('Public::LogPutawayDiscrepancy');


my $qry = qq{ update log_putaway_discrepancy set channel_id = ? where stock_process_id = ? };
my $sth = $dbh->prepare($qry);
while (my $dlog = $logs->next ){
    print "Adding channel to log_putaway_discrepancy for this stock process : " .$dlog->stock_process_id."\n";
    eval{
        my $channel_id = $dlog->stock_process->channel->id;
        
        my $stock_process_id = $dlog->stock_process_id;
        $sth->execute($channel_id, $stock_process_id);
    };
    if ( $@ ) {
        print "\n Could not add channel \n".$@;
    }
    
}


