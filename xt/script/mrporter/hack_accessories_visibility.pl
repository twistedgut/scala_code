#!/opt/xt/xt-perl/bin/perl
# This would make far more sense if it was done as a simple update to the
# web db, but in case this is the only way we can get it done, here is a
# horrible hack to set the hardcoded top level accessories category to
# visible.

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Config::Local qw( config_var );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use Readonly;

# Which DC environment are we in
Readonly my $dc => config_var('DistributionCentre', 'name');
die q{Couldn't determine the DC} unless $dc;

my $acc_tree_id = 8192;
if ($dc eq 'DC2') {
    $acc_tree_id = 8042;
}

foreach my $env ('live', 'staging') {

    my $mrp_web_dbh = get_transfer_sink_handle({ environment => $env, channel => "MRP" })->{dbh_sink};
    my $query = "update _navigation_tree set visibility = 1 where id = ?";
    my $sth = $mrp_web_dbh->prepare($query);

    $sth->execute($acc_tree_id);

    $mrp_web_dbh->commit();
}

exit;

