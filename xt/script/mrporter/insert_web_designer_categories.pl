#!/opt/xt/xt-perl/bin/perl

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
my $nap_channel_id = 1;
if ($dc eq 'DC2') {
    $channel_id = 6;
    $nap_channel_id = 2;
}

# Database connections
my $xtracker_dbh = get_database_handle( { name => 'xtracker', type => 'readonly' } )
    || die print "Error: Unable to connect to xtracker DB";
my $nap_web_dbh = get_transfer_sink_handle({ environment => 'live', channel => "NAP" })->{dbh_sink};
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

my $nap_xt_query = "
    select pa.id
    from product.attribute pa
    where pa.channel_id=?
    and pa.name=?
    and pa.attribute_type_id=9
";
my $nap_xt_sth = $xtracker_dbh->prepare($nap_xt_query);

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

my $nap_web_cat_query = "
    select name, synonyms
    from _navigation_category
    where id=?
";
my $nap_web_cat_sth = $nap_web_dbh->prepare($nap_web_cat_query);

my $mrp_web_cat_insert_query = "
    insert into _navigation_category (id, name, synonyms, type_id)
    values (?, ?, ?, 'DESIGNER')
    on duplicate key update synonyms=concat(synonyms,'|',?)
";
my $mrp_web_cat_insert_sth = $mrp_web_dbh->prepare($mrp_web_cat_insert_query);

my $mrp_web_tree_insert_query = "
    insert into _navigation_tree (id, parent_id, category_id, type_id, sort, visibility, 
            feature_product_id, feature_product_image, touched_ts, activate_ts, expire_ts)
    values (?, ?, ?, ?, ?, 1, ?, ?,
            '2008-03-28 00:00:00', '2000-12-31 00:00:00', '2020-12-31 00:00:00')
    on duplicate key update touched_ts=now()
";
my $mrp_web_tree_insert_sth = $mrp_web_dbh->prepare($mrp_web_tree_insert_query);


while (my $pa = $sth->fetchrow_hashref) {
    
    $logger->warn("going to insert/update web db for ".$pa->{id}.", ".$pa->{name}) if ($logging);
    $nap_xt_sth->execute($nap_channel_id, $pa->{name});
    my ($nap_pa_id) = $nap_xt_sth->fetchrow_array();
    if (!$nap_pa_id) {
        $logger->warn("no nap product.attribute matching name ".$pa->{name}) if ($logging);
        next;
    }

    $nap_web_cat_sth->execute($nap_pa_id);
    my ($nap_cat_name, $nap_cat_synonyms) = $nap_web_cat_sth->fetchrow_array();
    $nap_cat_name||="";
    $nap_cat_synonyms||="";
    unless ($pa->{name} eq $nap_cat_name) {
        $logger->warn("name mismatch: nap web db has $nap_cat_name, xtracker has ".$pa->{name}) if ($logging);
    }
    $logger->warn("got $nap_cat_name, $nap_cat_synonyms for ".$pa->{name}. "(looked with $nap_pa_id)") if ($logging);
    $mrp_web_cat_insert_sth->execute($pa->{id}, $nap_cat_name||$pa->{name}, $nap_cat_synonyms, $nap_cat_synonyms);

    # find xt tree data for designer
    $mrp_xt_tree_des_sth->execute($pa->{id});
    my $xt_des = $mrp_xt_tree_des_sth->fetchrow_hashref;
    # insert tree entry for designer
    unless ($xt_des->{id}) {
        $logger->warn("no product.navigation_tree in xtracker for ".$pa->{id}) if ($logging);
        next;
    }

    $mrp_web_tree_insert_sth->execute($xt_des->{id}, $xt_des->{id}, $pa->{id},
        'DESIGNER', $xt_des->{sort_order},
        $xt_des->{feature_product_id},
        $xt_des->{feature_product_image});

    # find xt nav data for designer and insert into web db
    $mrp_xt_tree_nav_sth->execute($xt_des->{id});
    while (my $xt_nav = $mrp_xt_tree_nav_sth->fetchrow_hashref) {
        $logger->warn("found ".$xt_nav->{id}) if ($logging);
        unless ($xt_nav->{sort_order}) {
            $logger->warn("missing sort order for ".$xt_nav->{id});
            next;
        }
        $mrp_web_tree_insert_sth->execute ($xt_nav->{id}, $xt_des->{id}, $xt_nav->{attribute_id},
            'NAV_LEVEL1', $xt_nav->{sort_order},
            $xt_nav->{feature_product_id},
            $xt_nav->{feature_product_image});
    }

}

# didn't even want a write connection to the nap db anyway
$nap_web_dbh->rollback();

# but we do want to commit mrp web db changes
$mrp_web_dbh->commit();

exit;

