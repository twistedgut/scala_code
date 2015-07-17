#!/opt/xt/xt-perl/bin/perl
##
# Copies the root level designer category + nav tree entry from NAP to MRP.
# Creates attribute/category and navigation tere entries in xtracked and web db.
# We need it so we can make designer categories underneath it.
##

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Config::Local qw( config_var );
use XTracker::Database qw( get_database_handle );
use XTracker::Database::Channel qw( get_channels );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use Readonly;

Readonly my $dc => config_var('DistributionCentre', 'name');
die q{Couldn't determine the DC} unless $dc;

my $channel_id = 5;
my $nap_channel_id = 1;
if ($dc eq 'DC2') {
    $channel_id = 6;
    $nap_channel_id = 2;
}

# Database connections
my $xtracker_dbh = get_database_handle( { name => 'xtracker', type => 'transaction' } );
my $mrp_web_dbh = get_transfer_sink_handle({ environment => 'live', channel => "MRP" })->{dbh_sink};

my $xtracker_create_attribute = $xtracker_dbh->prepare("
    insert into product.attribute (name, attribute_type_id, deleted, synonyms, manual_sort, channel_id)
    select name, attribute_type_id, deleted, synonyms, manual_sort, ?
    from product.attribute
    where channel_id=? and name='Designer' and attribute_type_id=0
");
$xtracker_create_attribute->execute($channel_id, $nap_channel_id);
my $attribute_id = $xtracker_dbh->last_insert_id(undef, 'product', 'attribute', undef);

my $xtracker_create_nav = $xtracker_dbh->prepare("
    insert into product.navigation_tree (attribute_id, parent_id, sort_order, visible, deleted)
    select ?, pn.parent_id, pn.sort_order, pn.visible, pn.deleted
    from product.attribute pa, product.navigation_tree pn
    where pa.id=pn.attribute_id
    and pa.channel_id=? and pa.name='Designer' and pa.attribute_type_id=0
");
$xtracker_create_nav->execute($attribute_id, $nap_channel_id);
my $nav_id = $xtracker_dbh->last_insert_id(undef, 'product', 'navigation_tree', undef);

my $mrp_web_cat_insert_query = "
    insert into _navigation_category (id, name, synonyms, type_id)
    values (?, 'Designer', null, 'NONE')
";
my $mrp_web_cat_insert_sth = $mrp_web_dbh->prepare($mrp_web_cat_insert_query);
$mrp_web_cat_insert_sth->execute($attribute_id);

my $mrp_web_tree_insert_query = "
    insert into _navigation_tree (id, parent_id, category_id, type_id, sort, visibility, 
            feature_product_id, feature_product_image, touched_ts, activate_ts, expire_ts)
    values (?, ?, ?, 'NONE', 6, 0, null, null,
            '2008-03-28 00:00:00', '2000-12-31 00:00:00', '2020-12-31 00:00:00')
    on duplicate key update touched_ts=now()
";
my $mrp_web_tree_insert_sth = $mrp_web_dbh->prepare($mrp_web_tree_insert_query);
$mrp_web_tree_insert_sth->execute($nav_id, $nav_id, $attribute_id);

$xtracker_dbh->commit();
$mrp_web_dbh->commit();


1;
