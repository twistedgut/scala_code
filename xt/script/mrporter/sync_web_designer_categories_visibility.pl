#!/opt/xt/xt-perl/bin/perl
# 
# make sure visibility of designer categories is the same in
# the web db as in xtracker
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
GetOptions(
    'logging=s' => \$logging,
);


my $logger = xt_logger('XTracker');

my $channel_id = 5;
if ($dc eq 'DC2') {
    $channel_id = 6;
}

# Database connections
my $xtracker_dbh = get_database_handle( { name => 'xtracker', type => 'readonly' } )
    || die print "Error: Unable to connect to xtracker DB";
my $mrp_web_dbh = get_transfer_sink_handle({ environment => 'live', channel => "MRP" })->{dbh_sink};

$logger->warn("all connected") if ($logging);

my $query = "
    select pa.id, pa.name
    from product.attribute pa
    where pa.channel_id=?
    and pa.attribute_type_id=9
";

my $sth = $xtracker_dbh->prepare($query);
$sth->execute($channel_id);

my $mrp_xt_tree_des_query = "
    select id, parent_id, sort_order, visible, deleted, feature_product_id, feature_product_image
    from product.navigation_tree
    where attribute_id = ?
";
my $mrp_xt_tree_des_sth = $xtracker_dbh->prepare($mrp_xt_tree_des_query);

my $mrp_xt_tree_nav_query = "
    select id, attribute_id, sort_order, visible, deleted, feature_product_id, feature_product_image
    from product.navigation_tree
    where parent_id = ?
    and id != parent_id
";
my $mrp_xt_tree_nav_sth = $xtracker_dbh->prepare($mrp_xt_tree_nav_query);

my $mrp_web_tree_update_query = "
    update _navigation_tree 
    set visibility = ?
    where id = ?
";
my $mrp_web_tree_update_sth = $mrp_web_dbh->prepare($mrp_web_tree_update_query);

while (my $pa = $sth->fetchrow_hashref) {
    
    $logger->warn("updating des cat visibility in web db for ".$pa->{id}.", ".$pa->{name}) if ($logging);

    # find xt designer 
    $mrp_xt_tree_des_sth->execute($pa->{id});
    my $xt_des = $mrp_xt_tree_des_sth->fetchrow_hashref;

    # find xt nav data for designer
    $mrp_xt_tree_nav_sth->execute($xt_des->{id});
    while (my $xt_nav = $mrp_xt_tree_nav_sth->fetchrow_hashref) {
        $logger->warn("setting ".$xt_nav->{id}." visibility to ".($xt_nav->{visible} ? 1 : 0)) if ($logging);
        $mrp_web_tree_update_sth->execute (
            $xt_nav->{visible} ? 1 : 0,
            $xt_nav->{id}
        );
    }

}

# but we do want to commit mrp web db changes
$mrp_web_dbh->commit();

exit;

