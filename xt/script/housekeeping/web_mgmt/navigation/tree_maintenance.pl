#!/opt/xt/xt-perl/bin/perl -w

use strict;
use lib "/opt/xt/deploy/xtracker/lib/";
use FindBin::libs qw( base=lib_dynamic );
use warnings;


die "This script is deprecated and should have been removed from crontab in 2.10 release";
__END__

use Getopt::Long;
use XTracker::Database qw( :common );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);
use XTracker::DB::Factory::ProductNavigation;
use XTracker::DB::Factory::ProductAttribute;
use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;
use XT::Domain::Messages;
use XTracker::Constants::FromDB qw( :department );


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

my $schema      = get_database_handle( { name => 'xtracker_schema', type => 'transaction' } );  # get schema
my $transfer_dbh_ref                    = get_transfer_sink_handle({ environment => 'live', channel => $channel_name }); # get web transfer handles
$transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;                  # pass the schema handle in as the source for the transfer

my %to_do = ();
my %log = ();

my $nav_factory = XTracker::DB::Factory::ProductNavigation->new({ schema => $schema });
my $attr_factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });


# get roots
my $roots = $nav_factory->get_roots( $channel_id );

# loop through the roots
while (my $root = $roots->next) {

    my $root_id = $root->get_column('id');

    # get branches for root
    my $branches = $nav_factory->get_branches( $root_id );

    # loop through the branches
    while (my $branch = $branches->next) {

        my $branch_id = $branch->get_column('id');
        my $num_products = 0;

        # vars to keep track of leaf data
        my $num_visible_leaves = 0;
        my $num_product_leaves = 0;

        # get leaves for the branch
        my $leaves = $nav_factory->get_leaves( $root_id, $branch_id );

        # first pass through the leaves to get leaf data
        while (my $leaf = $leaves->next) {

            my $leaf_id = $leaf->get_column('id');

            $num_products += $leaf->get_column('num_live_prods');

            # first do our branch counters
            if ( $leaf->get_column('visible') == 1 ) {
                $num_visible_leaves++;

                if ( $leaf->get_column('num_live_prods') > 10) {
                    $num_product_leaves++;
                }
            }

        }

        my $empty = $leaves->reset;

        # second pass through the leaves to check visibility status
        while (my $leaf = $leaves->next) {

            my $leaf_id = $leaf->get_column('id');

            # leaf invisible with products - make visible if 12 leaf rule not exceeded
            if ( ($leaf->get_column('num_live_prods') > 0 && $leaf->get_column('visible') == 0) && $num_visible_leaves < 12 ) {

                $to_do{ $leaf_id } = 1;

                $num_visible_leaves++;

                if ( $leaf->get_column('num_live_prods') > 10) {
                    $num_product_leaves++;
                }

                $log{'leaf'}{'visible'}{$leaf_id} = $root->get_column('name')." : ".$branch->get_column('name')." : ".$leaf->get_column('name');
            }


            # leaf visible with no products
            if ( $leaf->get_column('num_live_prods') == 0 && $leaf->get_column('visible') == 1 ) {

                $to_do{ $leaf_id } = 1;

                $num_visible_leaves--;

                $log{'leaf'}{'invisible'}{$leaf_id} = $root->get_column('name')." : ".$branch->get_column('name')." : ".$leaf->get_column('name');
            }

        }

        $empty = $leaves->reset;

        # now check the status of the branch based on leaf data
        # If only one L3 category mapped to L2 category, or only one L3 category contains >10 PIDS then the L3 categories will not display

        # hide all leaves
        if ( $num_visible_leaves == 1 || $num_product_leaves < 2) {

            while (my $leaf = $leaves->next) {

                my $leaf_id = $leaf->get_column('id');

                delete $to_do{ $leaf_id };
                delete $log{'leaf'}{'invisible'}{$leaf_id};
                delete $log{'leaf'}{'visible'}{$leaf_id};

                if ( $leaf->get_column('visible') == 1 ) {

                    $to_do{ $leaf_id } = 1;

                    if ( $num_visible_leaves == 1 ) {
                        $log{'leaf'}{'invisible'}{$leaf_id} = $root->get_column('name')." : ".$branch->get_column('name')." : ".$leaf->get_column('name');
                    }

                    if ( $num_product_leaves < 2 ) {
                        $log{'leaf'}{'invisible'}{$leaf_id} = $root->get_column('name')." : ".$branch->get_column('name')." : ".$leaf->get_column('name');
                    }

                }
            }
        }


        # check branch invisible with products
        if ( $num_products > 0 && $branch->get_column('visible') == 0 ) {
            $to_do{ $branch_id } = 1;
            $log{'branch'}{'visible'}{$branch_id} = $root->get_column('name')." : ".$branch->get_column('name');
        }

        # check branch visible with no products
        if ( $num_products == 0 && $branch->get_column('visible') == 1 ) {
            $to_do{ $branch_id } = 1;
            $log{'branch'}{'invisible'}{$branch_id} = $root->get_column('name')." : ".$branch->get_column('name');
        }

    }
}


eval {

    foreach my $node_id ( keys %to_do ) {

        print "Processing node id: ". $node_id ."<br>";

        # update visible flag - XT and website
        $schema->txn_do( sub {
                             $nav_factory->set_node_visibility( {
                                 'node_id'               => $node_id,
                                 'transfer_dbh_ref'      => $transfer_dbh_ref,
                                 'operator_id'           => 1
                             } );
                         } );

        # commit transfer changes
        $transfer_dbh_ref->{dbh_sink}->commit();

    }

};

if ($@) {

    # rollback website changes on error
    $transfer_dbh_ref->{dbh_sink}->rollback();

    print "ERROR: ". $@ ."<br>";
}
else {

    my $msg = '';

    $msg .= "Made Visible<br>------------------<br>";

    if ( keys %{$log{'branch'}{'visible'}} ) {
        foreach my $node_id ( keys %{ $log{'branch'}{'visible'} } ) {
            $msg .= $log{'branch'}{'visible'}{$node_id}."<br>";
        }
    }
    else {
        #$msg .= "None<br>";
    }

    if ( keys %{$log{'leaf'}{'visible'}} ) {
        foreach my $node_id ( keys %{ $log{'leaf'}{'visible'} } ) {
            $msg .= $log{'leaf'}{'visible'}{$node_id}."<br>";
        }
    }
    else {
        #$msg .= "None<br>";
    }

    $msg .= "<br>";

    $msg .=  "Made Invisible<br>------------------<br>";

    if ( keys %{$log{'branch'}{'invisible'}} ) {
        foreach my $node_id ( keys %{ $log{'branch'}{'invisible'} } ) {
            $msg .= $log{'branch'}{'invisible'}{$node_id}."<br>";
        }
    }
    else {
        #$msg .= "None<br>";
    }

    if ( keys %{$log{'leaf'}{'invisible'}} ) {
        foreach my $node_id ( keys %{ $log{'leaf'}{'invisible'} } ) {
            $msg .= $log{'leaf'}{'invisible'}{$node_id}."<br>";
        }
    }
    else {
        #$msg .= "None<br>";
    }

    $msg .= "<br>";

    my $messages = XT::Domain::Messages->new({ schema => $schema });

    # send update message to Product Merchandising Dept.
    $messages->send_message(
        {
            department_id   => $DEPARTMENT__PRODUCT_MERCHANDISING,
            subject         => q{Navigation Tree Updates},
            message         => $msg,
        }
    );

    #print $msg;
}



# disconnect website transfer handles
$transfer_dbh_ref->{dbh_source}->disconnect() if $transfer_dbh_ref->{dbh_source};
$transfer_dbh_ref->{dbh_sink}->disconnect() if $transfer_dbh_ref->{dbh_sink};



1;

