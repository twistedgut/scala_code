#!/opt/xt/xt-perl/bin/perl -w

#
# http://jira4.nap/browse/APS-904
#
# find live products matching --colour in DC and update web databases filter colour and navigation colour to --colour_filter and --colour_nav
# defaults to all channels unless --channel option is given 
#

use strict;
use lib "/opt/xt/deploy/xtracker/lib/";
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use XTracker::Database qw( :common );
use XTracker::Database::Product qw( get_fcp_sku );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;
use Data::Dumper;

my ($colour,$colour_filter,$colour_nav,$user_channel);

my $schema = get_database_handle( {
    name => 'xtracker_schema',
} );

my $dbh = $schema->storage->dbh;

my $sql;
foreach my $channel ($schema->resultset('Public::Channel')->search({'name' => 'theOutnet.com'})) 
{

    my $channel_short = (split(/-/,$channel->web_name))[0];

     my $pid_rs = $schema->resultset('Public::Product')->search({
            'business.config_section' => $channel_short,
            'product_channel.live' => 'true',
            },{
                join => [
                   'colour',
                   {
                       product_channel => { channel => 'business' }
                   }
               ],
               order_by => 'me.id' 
           } 
        );

    my $count = 0;
    my $transfer_dbh_ref = get_transfer_sink_handle({ environment => 'live', channel => $channel_short });
    
    my %good_colours;
    my %bad_colours;
    foreach my $product ($pid_rs->all)
    {
        $sql = "update product set colour = ? where search_prod_id = ?;";

        my $upd_product = $transfer_dbh_ref->{dbh_sink}->prepare($sql);
        $upd_product->execute($product->colour->colour, $product->id);
    }
 
    $transfer_dbh_ref->{dbh_sink}->commit();
    $transfer_dbh_ref->{dbh_sink}->disconnect();

}


1;
