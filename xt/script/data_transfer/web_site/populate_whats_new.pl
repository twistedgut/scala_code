#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database qw( :common );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use Getopt::Long;

use XTracker::DB::Factory::ProductAttribute;

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

my $schema      = get_database_handle( { name => 'xtracker_schema', type => 'transaction' } );  # get schema
my $transfer_dbh_ref                    = get_transfer_sink_handle({ environment => 'live', channel => $channel_name }); # get web transfer handles
$transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;                  # pass the schema handle in as the source for the transfer

# use the schema handle as our read handle so we're in the same transaction
my $dbh = $schema->storage->dbh;

my $factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });



# get whats new last week attribute id
my $last_week_id;

my $qry = "select id 
                from product.attribute 
                where name = 'Last_Four_Weeks' 
                and channel_id = ?
                and attribute_type_id = (select id from product.attribute_type where web_attribute = 'WHATS_NEW')";
my $sth = $dbh->prepare($qry);
$sth->execute( $channel_id );

while(my $row = $sth->fetchrow_hashref){
    $last_week_id = $row->{id};
}


# remove products which are now older than 4 weeks from WN Last Four Weeks list
eval {

    $schema->txn_do( sub {

        print "Removing products older than 4 weeks from WN Last Four Weeks...\n";

        my $qry = "select av.attribute_id, av.product_id 
                    from product.attribute_value av, product_channel pch
                    where av.deleted = false 
                    and av.attribute_id = (select id from product.attribute where channel_id = ? and name = 'Last_Four_Weeks' and attribute_type_id = (select id from product.attribute_type where web_attribute = 'WHATS_NEW'))
                    and av.product_id = pch.product_id
                    and pch.channel_id = ?
                    and pch.upload_date < current_timestamp - interval '4 weeks 1 day'";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $channel_id, $channel_id );

        while(my $row = $sth->fetchrow_hashref){

            $factory->remove_product_attribute( {
                                                    'attribute_id' => $row->{attribute_id}, 
                                                    'product_id' => $row->{product_id}, 
                                                    'transfer_dbh_ref' => $transfer_dbh_ref,
                                                    'operator_id' => 1, # admin user
                                                    'channel_id' => $channel_id,
            } );

            print "$row->{product_id},";

        }

        print "\n\n";

    } );

    # commit transfer changes
    $transfer_dbh_ref->{dbh_sink}->commit();
};

if ($@) {
    # rollback website updates on error - XT updates rolled back as part of txn_do
    $transfer_dbh_ref->{dbh_sink}->rollback();
    die "ERROR: ".$@."\n";
}


# move products older than 6 days from WN This Week to WN Last Four Weeks
eval {

    $schema->txn_do( sub {
        print "Moving products older than 6 days from WN This Week to WN Last Four Weeks...\n";

        my $qry = "select av.attribute_id, av.product_id 
                    from product.attribute_value av, product_channel pch
                    where av.deleted = false 
                    and av.attribute_id = (select id from product.attribute where channel_id = ? and name = 'This_Week' and attribute_type_id = (select id from product.attribute_type where web_attribute = 'WHATS_NEW'))
                    and av.product_id = pch.product_id
                    and pch.channel_id = ?
                    and pch.upload_date < current_timestamp - interval '6 days'";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $channel_id, $channel_id );

        while(my $row = $sth->fetchrow_hashref){

            $factory->remove_product_attribute( {
                                                    'attribute_id' => $row->{attribute_id}, 
                                                    'product_id' => $row->{product_id}, 
                                                    'transfer_dbh_ref' => $transfer_dbh_ref,
                                                    'operator_id' => 1, # admin user
                                                    'channel_id' => $channel_id,
            } );

            $factory->create_product_attribute( {
                                                    'attribute_id' => $last_week_id, 
                                                    'product_id' => $row->{product_id}, 
                                                    'transfer_dbh_ref' => $transfer_dbh_ref,
                                                    'operator_id' => 1, # admin user
                                                    'channel_id' => $channel_id,
            } );

            print "$row->{product_id},";

        }

        print "\n\n";
    } );

    # commit transfer changes
    $transfer_dbh_ref->{dbh_sink}->commit();
};

if ($@) {
    # rollback website updates on error - XT updates rolled back as part of txn_do
    $transfer_dbh_ref->{dbh_sink}->rollback();
    die "ERROR: ".$@."\n";
}


# get whats new this week attribute id
my $this_week_id;

$qry = "select id 
                from product.attribute 
                where name = 'This_Week' 
                and channel_id = ?
                and attribute_type_id = (select id from product.attribute_type where web_attribute = 'WHATS_NEW')";
$sth = $dbh->prepare($qry);
$sth->execute( $channel_id );

while(my $row = $sth->fetchrow_hashref){
    $this_week_id = $row->{id};
}


# need to store them to add back in later
my @pids_to_add;

eval {

    $schema->txn_do( sub {

        # temporarily remove any remaining whats new prods to add back in after new ones
        print "Removing remaining Whats New products temporarily...\n";

        # get products currently in whats new
        my $qry = "select product_id, sort_order
                    from product.attribute_value 
                    where deleted = false 
                    and attribute_id = ?
                    order by sort_order asc
                    ";
        my $sth = $dbh->prepare($qry);
        $sth->execute($this_week_id);

        while(my $row = $sth->fetchrow_hashref){

            push @pids_to_add, $row->{product_id};

            $factory->remove_product_attribute( {
                                                    'attribute_id' => $this_week_id, 
                                                    'product_id' => $row->{product_id}, 
                                                    'transfer_dbh_ref' => $transfer_dbh_ref,
                                                    'operator_id' => 1, # admin user
                                                    'channel_id' => $channel_id,
            } );

            print "$row->{product_id},";

        }

        print "\n\n";

        # add new products to WN This Week
        print "Adding new products to WN This Week...\n";

        $qry = "select p.id as product_id 
                    from product p, price_default pd 
                    where p.id in (select product_id from product_channel where channel_id = ? and upload_date = ?) 
                    and p.id = pd.product_id
                    order by pd.price desc";
        $sth = $dbh->prepare($qry);
        $sth->execute( $channel_id, $upload_date );

        while(my $row = $sth->fetchrow_hashref){

            $factory->create_product_attribute( {
                                                    'attribute_id' => $this_week_id, 
                                                    'product_id' => $row->{product_id}, 
                                                    'transfer_dbh_ref' => $transfer_dbh_ref,
                                                    'operator_id' => 1, # admin user
                                                    'channel_id' => $channel_id,
            } );

            print "$row->{product_id},";

        }

        print "\n\n";

    } );

    # commit transfer changes
    $transfer_dbh_ref->{dbh_sink}->commit();
};

if ($@) {
    # rollback website updates on error - XT updates rolled back as part of txn_do
    $transfer_dbh_ref->{dbh_sink}->rollback();
    die "ERROR: ".$@."\n";
}


# add products we removed back into WN This Week
eval {

    $schema->txn_do( sub {
        print "Adding existing products back in to WN This Week...\n";

        foreach my $pid (@pids_to_add) {

            $factory->create_product_attribute( {
                                                    'attribute_id' => $this_week_id, 
                                                    'product_id' => $pid, 
                                                    'transfer_dbh_ref' => $transfer_dbh_ref,
                                                    'operator_id' => 1, # admin user
                                                    'channel_id' => $channel_id,
            } );

            print "$pid,";

        }

        print "\n";


    } );

    # commit transfer changes
    $transfer_dbh_ref->{dbh_sink}->commit();
};

if ($@) {
    # rollback website updates on error - XT updates rolled back as part of txn_do
    $transfer_dbh_ref->{dbh_sink}->rollback();
    die "ERROR: ".$@."\n";
}


$dbh->disconnect();

# disconnect website transfer handles
$transfer_dbh_ref->{dbh_source}->disconnect() if $transfer_dbh_ref->{dbh_source};
$transfer_dbh_ref->{dbh_sink}->disconnect() if $transfer_dbh_ref->{dbh_sink};
