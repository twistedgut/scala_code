#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database qw( get_database_handle );

use Getopt::Long;

my $upload_date     = undef;
my $channel_id      = undef;
my $channel_name    = undef;

GetOptions(
    'upload_date=s'     => \$upload_date,
    'channel_id=i'      => \$channel_id,
    'channel_name=s'    => \$channel_name,
);

if (!$upload_date) {
    die "Please specify an upload date.\n\n";
}

if (!$channel_id) {
    die "Please specify an channel id.\n\n";
}

if (!$channel_name) {
    die "Please specify a channel name (e.g. NAP or OUTNET).\n\n";
}


my $dbh_read    = get_database_handle( { name => 'xtracker', type => 'readonly' } );
my $dbh_web     = get_database_handle( { name => 'Web_Staging_'.$channel_name, type => 'transaction' } ) || die print "Error: Unable to connect to Staging website DB for channel: $channel_name";

eval {

    # remove current whats new products 

    print "Removing products from Whats New...\n";

    my $qry = "delete from attribute_value where pa_id = 'WHATS_NEW' and value = (select id from _navigation_category where name = 'This_Week')";
    my $sth = $dbh_web->prepare($qry);
    $sth->execute();


    # add new products to Whats New

    print "Adding products to Whats New...\n";

    $qry = "select p.id as product_id 
                from product p, price_default pd 
                where p.id in (select product_id from product_channel where channel_id = ? and upload_date = ?) 
                and p.id = pd.product_id
                order by pd.price desc";
    $sth = $dbh_read->prepare($qry);
    $sth->execute( $channel_id, $upload_date );

    while(my $row = $sth->fetchrow_hashref){

    print "$row->{product_id},";
    
    my $ins = "insert into attribute_value values (default, (select id from _navigation_category where name = 'This_Week'), 'WHATS_NEW', NULL, ?, '', 1)";
    my $ins_sth = $dbh_web->prepare($ins);
        $ins_sth->execute($row->{product_id});
    }

    print "\n";

    print "Running Cuongs summary table refresh...\n";
    $qry = "call sp_populateProductSummary";
    $sth = $dbh_web->prepare($qry);
    $sth->execute();
    print "Done.\n\n";

    # commit transfer changes
    $dbh_web->commit();
};

if ($@) {
    # rollback website updates on error - XT updates rolled back as part of txn_do
    $dbh_web->rollback();
    print "ERROR: ".$@."\n";
}


$dbh_read->disconnect();
$dbh_web->disconnect();

