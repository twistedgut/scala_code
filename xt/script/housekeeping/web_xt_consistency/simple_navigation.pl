#!/opt/xt/xt-perl/bin/perl
#
# Reports on mismatches between nav cat and designer cat 
# data in web db compared to xtracker.
# (The assumption is that xtracker has the correct data -
# if not then that needs to be addressed separately.)
# 
# Doesn't attempt to fix anything automatically, just
# displays any issues it finds.
#

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;

use XTracker::Logfile qw(xt_logger);
use XTracker::Config::Local qw( config_var );
use XTracker::Database qw( get_database_handle );
use XTracker::Database::Channel qw( get_channels );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);


use Fcntl ':flock';
use Readonly;

# Which DC environment are we in
Readonly my $dc => config_var('DistributionCentre', 'name');
die q{Couldn't determine the DC} unless $dc;

my $logging;
my $channel_id;
my $channel_name;
GetOptions(
    'logging=s' => \$logging,
    'channel_id=s'      => \$channel_id,
    'channel_name=s'    => \$channel_name,

);


my $logger = xt_logger('XTracker');

# Database connections
my $xtracker_dbh = get_database_handle( { name => 'xtracker', type => 'readonly' } )
    || die print "Error: Unable to connect to xtracker DB";
my $web_dbh = get_transfer_sink_handle({ environment => 'live', channel => "$channel_name" })->{dbh_sink};

$logger->warn("all connected") if ($logging);


# Check nav level 1, 2, and 3 plus designers
my $level_1_cats = check_nav_and_des();


sub check_nav_and_des {

    my $xt_query = "
        select pa.id as att_id, pa.name as att_name,
        pn.id as tree_id, pn.parent_id as tree_parent_id,
        pat.web_attribute as web_type_id
        from product.attribute pa, product.navigation_tree pn,
        product.attribute_type pat, designer_channel dc, designer d
        where pa.id = pn.attribute_id and pa.attribute_type_id = pat.id
        and dc.designer_id = d.id and d.url_key = pa.name
        and pa.channel_id = ? and dc.channel_id = pa.channel_id
        and pa.attribute_type_id in (1,2,3,9)
        order by pa.attribute_type_id, pn.parent_id, pn.id
    ";

    my $xt_sth = $xtracker_dbh->prepare($xt_query);
    $xt_sth->execute($channel_id);

    my $web_query = "
        select nc.name
        from _navigation_category nc, _navigation_tree nt
        where nc.id = nt.category_id
        and nc.type_id = ?
        and nt.type_id = ?
        and nt.parent_id = ?
        and nc.id = ? and nt.id = ?
    ";
    my $web_sth = $web_dbh->prepare($web_query);

    while (my $xt_item = $xt_sth->fetchrow_hashref) {
        my $exists = 0;
        $web_sth->execute($xt_item->{web_type_id}, $xt_item->{web_type_id},
            $xt_item->{tree_parent_id}, $xt_item->{att_id}, $xt_item->{tree_id});
        my ($web_cat_name) = $web_sth->fetchrow_array();
        if (defined $web_cat_name) {
            $exists = 1;
            if ($web_cat_name ne $xt_item->{att_name}) {
                print "WARNING: cat $xt_item->{att_id}: web cat name is $web_cat_name, xtracker name is $xt_item->{att_name}\n";
            }
        } else {
            print "ERROR: missing web data for $xt_item->{web_type_id} attribute $xt_item->{att_id} / $xt_item->{att_name} - tree id $xt_item->{tree_id}\n";
        }
    }

}

# not that we changed anything anyway
$web_dbh->rollback();

exit;

