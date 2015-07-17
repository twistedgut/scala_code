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

my ($colour,$colour_filter,$colour_nav,$user_channel);

GetOptions(
    'colour=s' => \$colour,
    'colour-filter=s' => \$colour_filter,
    'colour-nav=s' => \$colour_nav,
    'channel=s' => \$user_channel,
);

if (!(defined($colour) && defined($colour_filter) && defined($colour_nav))) {
    print "Usage: $0 --colour [Teal] --colour-filter [Blue] --colour-nav [Blue]\n";
    exit 1;
}

my $schema = get_database_handle( {
    name => 'xtracker_schema',
} );

my $dbh = $schema->storage->dbh;

my $params_ok =0;

if ($schema->resultset('Public::Colour')->search({ colour => $colour })) {
    if ($schema->resultset('Public::ColourFilter')->search({ colour_filter => $colour_filter })) {
        # no schema for colour_navigation
        my $colour_navigation = $dbh->prepare('select id from colour_navigation where colour = ?');
        $colour_navigation->execute($colour_nav);

        if ($colour_navigation->fetchrow_hashref) {
            $params_ok=1;
        }
    }
}

if (!$params_ok) {
    print "$0 - invalid colour specified for option\n";
    exit 1;
}

my $sql;

print "\n";

foreach my $channel ($schema->resultset('Public::Channel')->all) {

    my $channel_short = (split(/-/,$channel->web_name))[0];

    next if (defined($user_channel) && ($channel_short ne $user_channel));

    if ($channel_short ne 'JC') {

        my $pid_rs = $schema->resultset('Public::Product')->search({
            'colour.colour' => $colour,
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

        my @pids_to_update = map { $_->id } $pid_rs->all;

        my $transfer_dbh_ref = get_transfer_sink_handle({ environment => 'live', channel => $channel_short });

        # make sure colour exists in web db
        $sql = 'select id from colour where colour = ?';
        my $qry_colour = $transfer_dbh_ref->{dbh_sink}->prepare($sql);
        $qry_colour->execute($colour_nav);

        if ((my $nav_colour = $qry_colour->fetchrow_hashref) && (@pids_to_update)) { 

            print "$channel_short, updating ". scalar(@pids_to_update) . " pids.\n\n";

            print "@pids_to_update \n\n";
            $sql = "update product set colour = ? where search_prod_id in (" . join(',',@pids_to_update) . ");";

            my $upd_product = $transfer_dbh_ref->{dbh_sink}->prepare($sql);
            $upd_product->execute(($channel->colour_detail_override) ? $colour : $colour_filter);

            $sql = "update attribute_value set value = ? where pa_id = 'COLOUR' and search_prd_id in (" . join(',',@pids_to_update) . ");";

            my $upd_product_attribute = $transfer_dbh_ref->{dbh_sink}->prepare($sql);
            $upd_product_attribute->execute($nav_colour->{id});

        } elsif (!$nav_colour) {
            print "Unable to update $channel_short, as navigation colour $colour_nav does not exist.\n";
        } elsif (!@pids_to_update) {
            print "No pids to update.\n";
        }

        $qry_colour->finish();
        $transfer_dbh_ref->{dbh_sink}->commit();
        $transfer_dbh_ref->{dbh_sink}->disconnect();

    }
}


1;
