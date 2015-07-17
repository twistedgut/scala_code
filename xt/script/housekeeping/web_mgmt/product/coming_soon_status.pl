#!/opt/xt/xt-perl/bin/perl -w

use strict;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use warnings;

use Getopt::Long;
use XTracker::Comms::DataTransfer   qw(:transfer_handles);
use XTracker::Database qw( get_database_handle );

my $channel_id   = undef;
my $channel_name = undef;

GetOptions(
    'channel_id=s' => \$channel_id,
    'channel_name=s' => \$channel_name,
);

if (!$channel_id) {
    die "No channel id provided";
}
if (!$channel_name) {
    die "No channel name provided";
}


# set up database handles
my $dbh     = get_database_handle( { name => 'xtracker', type => 'transaction' } );
my $dbh_fcp = get_database_handle( { name => 'Web_Live_'.$channel_name, type => 'transaction' } );


eval {
    # reset status of products which are currently "Coming Soon"
    my $web_reset_qry = "update product set prd_status = '' where prd_status = 'Coming Soon'";
    my $web_reset_sth = $dbh_fcp->prepare( $web_reset_qry );
    $web_reset_sth->execute();


    # set up website update statement
    my $web_up_qry = "update product set prd_status = 'Coming Soon' where sku = ?";
    my $web_up_sth = $dbh_fcp->prepare( $web_up_qry );


    # get products from XT which need status to be set
    my $qry = "select product_id || '-' || sku_padding(size_id) as sku 
                from variant 
                where product_id in (
                    select product_id from product_channel where channel_id = ? and live = true and visible = true
                ) 
                and id in (
                    select variant_id from stock_order_item where status_id < 3 and cancel = false and stock_order_id in (
                        select id from stock_order where not type_id = 3
                        and cancel_ship_date + interval '15 days' > current_timestamp and purchase_order_id in (
                            select id from purchase_order where channel_id = ?
                        )
                    )
                )";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $channel_id, $channel_id );
    while ( my $row = $sth->fetchrow_hashref() ) {

        # set website status
        $web_up_sth->execute( $row->{sku} );

#        print "Updated ".$row->{sku}."\n";
    }

    # commit website updates
    $dbh_fcp->commit();
};

if ($@) {
    print $@;
    $dbh_fcp->rollback();
}

# disconnect db handles
$dbh_fcp->disconnect();
$dbh->disconnect();



1;

