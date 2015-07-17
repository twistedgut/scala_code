#!/opt/xt/xt-perl/bin/perl

use warnings;
use strict;
use Carp;

use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( get_database_handle );

#my $dbh = fcp_staging_handle();
my $dbh = get_database_handle( { name => 'Web_Staging_NAP', type => 'readonly', } );

#
# Add the category names in here
# 
my %category = ( 
#'fw08/mil'  => 1,
'040409/issue'  => 1,
#'0502/summer'  => 1,
            );


foreach my $id ( keys %category ){

    # for product cats ( create category )
    my $qry_cat = "insert into category values ( ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL , 'T', 0, now(), 'SYSTEM', now(), 'SYSTEM', NULL )";
    my $sth_cat = $dbh->prepare( $qry_cat );
    $sth_cat->execute( $id, $id, $id, $id );

    my $qry_cath1 = "insert into category_hierarchy values ( ?, 'PRODUCT_CATEGORY', ?, NULL, 'T', now(), 'SYSTEM', now(), 'SYSTEM' )";
    my $sth_cath1 = $dbh->prepare( $qry_cath1 );
    $sth_cath1->execute( $id, $id, );
}
    
$dbh->commit();
$dbh->disconnect();

__END__

