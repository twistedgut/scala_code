#!/opt/xt/xt-perl/bin/perl -w
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use lib "/opt/xt/deploy/xtracker/lib/";
use FindBin::libs qw( base=lib_dynamic );
use warnings;

use Getopt::Long;

use XTracker::Database qw( :common );
use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use XTracker::DB::Factory::ProductNavigation;
use XTracker::DB::Factory::ProductAttribute;

use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;

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
my $schema      = get_database_handle( { name => 'xtracker_schema', type => 'transaction' } );  # get schema
my $transfer_dbh_ref                    = get_transfer_sink_handle({ environment => 'live', channel => $channel_name });          # get web transfer handles
$transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;                  # pass the schema handle in as the source for the transfer

# set up attribute factory object
my $factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });

# get sold out slug attribute from XT
my $slug_attr = $factory->get_attribute( { 'attribute_name' => 'soldout', 'attribute_type' => 'Slug Image', channel_id => $channel_id } );

if (!$slug_attr) {
    die "Could not find sold out slug attribute\n";
}



# get More Stock Coming Soon slug and products to exclude
my %exclude         = ();
my $more_slug_attr  = $factory->get_attribute( { 'attribute_name' => 'More_stock_coming_soon', 'attribute_type' => 'Slug Image', channel_id => $channel_id } );

if (!$more_slug_attr) {
    die "Could not find More Stock Coming Soon slug attribute\n";
}

my $more_slug_products = $factory->get_attribute_products( { 'attribute_id' => $more_slug_attr->id, 'live' => undef, 'visible' => undef});
while (my $prod = $more_slug_products->next) {
    $exclude{ $prod->id } = 1;
}



# get stock and visible info from website into a hash with pid as the key
my %web_data = ();
my $qry = "select sp.id, sp.is_visible, sum(sl.no_in_stock) as stock
           from searchable_product sp, stock_location sl
           where sp.id = substring_index( sl.sku, '-', 1 )
           group by sp.id, sp.is_visible";
my $sth = $transfer_dbh_ref->{dbh_sink}->prepare( $qry );
$sth->execute();
while ( my $row = $sth->fetchrow_hashref() ) {
        $web_data{ $row->{id} } = $row;
}


# get products with attribute assigned from XT and populate hash with pid as the key
my %xt_data = ();
my $slugged_prods = $factory->get_attribute_products(
                                                        {
                                                            'attribute_id' => $slug_attr->id, 
                                                            'live' => undef, 
                                                            'visible' => undef
                                                        }
);
while (my $record = $slugged_prods->next) {
    $xt_data{ $record->id } = 1;
}



# perform slug maintenance

# loop over existing slugs and remove where required
foreach my $pid ( keys %xt_data ) {

    # product now invisible or in stock - remove slug
    if ( $web_data{$pid}{is_visible} eq 'F' || $web_data{$pid}{stock} > 0 ) {
    
        eval {

            # transaction wraps XT and Website updates
            $schema->txn_do( sub {
                $factory->remove_product_attribute( {
                                                        'attribute_id' => $slug_attr->id, 
                                                        'product_id' => $pid, 
                                                        'transfer_dbh_ref' => $transfer_dbh_ref,
                                                        'operator_id' => 1,
                                                        'channel_id'        => $channel_id,
                } );

                # commit website changes
                $transfer_dbh_ref->{dbh_sink}->commit();
            } );
        };

        if ($@) {
            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();
            print "Error removing slug from PID: $pid - $@\n";
        }
        else {
            print "Slug removed from PID: $pid\n";
        }

    }

}


# loop over website products and slug as sold out where necessary
foreach my $pid ( keys %web_data ) {

    # product visible with no stock - add slug
    if ( $web_data{$pid}{is_visible} eq 'T' && $web_data{$pid}{stock} < 1 && !$xt_data{$pid} ) {

        if ( $exclude{ $pid } ) {
            print "$pid skipped - slugged as More Stock Coming Soon\n";
            next;
        }
    
        eval {

            # transaction wraps XT and Website updates
            $schema->txn_do( sub {

                # remove other slugs first - only one slug at a time allowed
                my $cur_slug_id = $factory->get_product_attribute( { 'product_id' => $pid, 'attribute_type' => 'Slug Image', 'channel_id' => $channel_id } );

                if ( $cur_slug_id ) {
                    $factory->remove_product_attribute( {
                                                            'attribute_id' => $cur_slug_id, 
                                                            'product_id' => $pid, 
                                                            'transfer_dbh_ref' => $transfer_dbh_ref,
                                                            'operator_id' => 1,
                                                            'channel_id'        => $channel_id,
                    } );
                }

                # add sold out slug
                $factory->create_product_attribute( {
                                                        'attribute_id' => $slug_attr->id, 
                                                        'product_id' => $pid, 
                                                        'transfer_dbh_ref' => $transfer_dbh_ref,
                                                        'operator_id' => 1,
                                                        'channel_id'        => $channel_id,
                } );

                # commit website changes
                $transfer_dbh_ref->{dbh_sink}->commit();
            } );
        };

        if ($@) {
            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();
            print "Error adding slug from PID: $pid - $@\n";
        }
        else {
            print "Slug added for PID: $pid\n";
        }

    }

}


# disconnect website transfer handles
$transfer_dbh_ref->{dbh_source}->disconnect() if $transfer_dbh_ref->{dbh_source};
$transfer_dbh_ref->{dbh_sink}->disconnect() if $transfer_dbh_ref->{dbh_sink};



1;

