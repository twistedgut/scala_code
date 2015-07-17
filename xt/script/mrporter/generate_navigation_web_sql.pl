#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Config::Local qw( config_var );
use XTracker::Database qw( get_database_handle );
use XTracker::Database::Channel qw( get_channels );

use Fcntl ':flock';
use Readonly;

# Which DC environment are we in
Readonly my $dc => config_var('DistributionCentre', 'name');
die q{Couldn't determine the DC} unless $dc;

my $channel_id = 5;
if ($dc eq 'DC2') {
    $channel_id = 6;
}

# Database connections
my $dbh = get_database_handle( { name => 'xtracker', type => 'transaction' } )
    || die print "Error: Unable to connect to DB";
my $schema = undef;

my $query = "select pn.id, pn.parent_id, pa.id, pa.name, pn.sort_order, 1
    from product.navigation_tree pn, product.attribute pa
    where pa.id=pn.attribute_id
    and pa.channel_id=?
    and pa.attribute_type_id=?";

my $sth = $dbh->prepare($query);

my %atts_seen;

foreach my $level (0..3) {
    my $level_name = "NONE";
    if ($level) {
        $level_name = "NAV_LEVEL$level";
    }

    $sth->execute($channel_id, $level);

    while (my ($id, $parent_id, $att_id, $att_name, $sort, $visible) = $sth->fetchrow_array) {
        $visible = 1 if ($visible);
        $parent_id ||= "null";

        if (!$atts_seen{$att_id}) {
            print "INSERT INTO _navigation_category (id, name, type_id) values ($att_id, '$att_name', '$level_name');\n";
        }

        print "INSERT INTO _navigation_tree (id, parent_id, category_id, type_id, sort, visibility) values ($id, $parent_id, $att_id, '$level_name', $sort, $visible);\n";

        $atts_seen{$att_id} = 1;
    }
}

$dbh->disconnect();

exit;

