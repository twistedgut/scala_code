#!/opt/xt/xt-perl/bin/perl -w

use strict;
use lib "/opt/xt/deploy/xtracker/lib/";
use FindBin::libs qw( base=lib_dynamic );
use warnings;


die "This script is deprecated and should have been removed from crontab in 2.12 release";
__END__

use Getopt::Long;
use XTracker::Database qw( :common );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use XTracker::DB::Factory::ProductNavigation;
use XTracker::DB::Factory::ProductAttribute;
use XTracker::DB::Factory::Designer;

use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;


my $channel_id      = undef;
my $channel_name    = undef;

GetOptions(
    'channel_id=s'      => \$channel_id,
    'channel_name=s'    => \$channel_name,
);

if (!$channel_name) {
    die "No channel name provided";
}

if (!$channel_id) {
    die "No channel id provided";
}


my $dbh = read_handle();

my $schema      = get_database_handle( { name => 'xtracker_schema', type => 'transaction' } ); # get schema
my $transfer_dbh_ref = get_transfer_sink_handle({ environment => 'live', channel => $channel_name }); # get web transfer handles
$transfer_dbh_ref->{dbh_source} = $schema->storage->dbh; # pass the schema handle in as the source for the transfer

my $nav_factory = XTracker::DB::Factory::ProductNavigation->new({ schema => $schema });
my $attr_factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });
my $des_factory = XTracker::DB::Factory::Designer->new({ schema => $schema });


# first we need to build a hash lookup of designer tree nodes
# format $nodes{Designer Name}{Category Name}{node_id} = Node ID
# format $nodes{Designer Name}{Category Name}{visible} = 0/1

my %designer_nodes = ();
my %nodes = ();

# get designer tree nodes
my $qry = "SELECT nt.id, d.designer 
            FROM product.navigation_tree nt, product.attribute a, designer d
            WHERE nt.attribute_id = a.id
            AND a.attribute_type_id = 9
            AND a.name like '%_Sale'
            AND replace(a.name, '_Sale', '') = d.url_key
            AND a.channel_id = ?
            ";
my $sth = $dbh->prepare($qry);
$sth->execute( $channel_id );

while (my $row = $sth->fetchrow_hashref) {

    $designer_nodes{ $row->{id} } = $row->{designer};
}

# get second level designer tree nodes
$qry = "SELECT nt.id, nt.parent_id, nt.visible, a.name 
            FROM product.navigation_tree nt, product.attribute a
            WHERE nt.attribute_id = a.id
            AND a.attribute_type_id = 1
            AND nt.parent_id IN (SELECT id FROM product.navigation_tree WHERE attribute_id IN (SELECT id FROM product.attribute WHERE name like '%_Sale' and attribute_type_id = 9))
            AND a.channel_id = ?";
$sth = $dbh->prepare($qry);
$sth->execute( $channel_id );

while (my $row = $sth->fetchrow_hashref) {

    if ($designer_nodes{ $row->{parent_id} }) {
        $nodes{ $designer_nodes{ $row->{parent_id} } }{ $row->{name} }{node_id} = $row->{id};
        $nodes{ $designer_nodes{ $row->{parent_id} } }{ $row->{name} }{visible} = $row->{visible};
    }
}



# query to get number of a type of product per designer
$qry = "SELECT d.id, d.designer, count(p.*) AS num_products
            FROM designer d
                LEFT JOIN product p 
                ON d.id = p.designer_id
                AND p.classification_id = (SELECT id FROM classification WHERE classification = ?)
                AND p.id IN (SELECT product_id FROM price_adjustment WHERE percentage > 0 AND current_timestamp BETWEEN date_start AND date_finish)
                AND p.id IN (SELECT product_id FROM product_channel WHERE channel_id = $channel_id AND visible = true)
            GROUP BY d.id, d.designer";
$sth = $dbh->prepare($qry);


# loop through the 4 product categories
foreach my $cat_name ( qw(Clothing Bags Shoes Accessories) ) { 

    $sth->execute($cat_name);

    while (my $row = $sth->fetchrow_hashref) {


        # TREE VISIBILITY UPDATES

        # designer has products and nav tree not currently invisible
        if ( $row->{num_products} > 0 && $nodes{ $row->{designer} }{ $cat_name } ) {

            if ($nodes{ $row->{designer} }{ $cat_name }{visible} == 0) {

                # make it visible
                eval {

                    print "Making ".$row->{designer}." : ".$cat_name." visible\n"; 

                    $schema->txn_do( sub {
                                         $nav_factory->set_node_visibility( {
                                             'node_id' => $nodes{ $row->{designer} }{ $cat_name }{node_id}, 
                                             'transfer_dbh_ref' => $transfer_dbh_ref,
                                             'operator_id' => 1
                                         } );
                                     } );

                    # commit transfer changes
                    $transfer_dbh_ref->{dbh_sink}->commit();

                };

                if ($@) {

                    # rollback website changes on error
                    $transfer_dbh_ref->{dbh_sink}->rollback();

                    print "ERROR: Could not make ".$row->{designer}." : ".$cat_name." visible - ". $@ ."\n";
                }
            }

        }


        # designer has no products and nav tree currently visible
        if ( $row->{num_products} == 0 && $nodes{ $row->{designer} }{ $cat_name } ) {

            if ( $nodes{ $row->{designer} }{ $cat_name }{visible} == 1 ) {

                # make it visible
                eval {

                    print "Making ".$row->{designer}." : ".$cat_name." invisible\n"; 

                    $schema->txn_do( sub {
                                         $nav_factory->set_node_visibility( {
                                             'node_id' => $nodes{ $row->{designer} }{ $cat_name }{node_id}, 
                                             'transfer_dbh_ref' => $transfer_dbh_ref,
                                             'operator_id' => 1
                                         } );
                                     } );

                    # commit transfer changes
                    $transfer_dbh_ref->{dbh_sink}->commit();

                };

                if ($@) {

                    # rollback website changes on error
                    $transfer_dbh_ref->{dbh_sink}->rollback();

                    print "ERROR: Could not make ".$row->{designer}." : ".$cat_name." invisible - ". $@ ."\n";
                }
            }

        }




    }

}



# disconnect website transfer handles
$transfer_dbh_ref->{dbh_source}->disconnect() if $transfer_dbh_ref->{dbh_source};
$transfer_dbh_ref->{dbh_sink}->disconnect() if $transfer_dbh_ref->{dbh_sink};



1;

