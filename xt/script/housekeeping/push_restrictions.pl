#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( :common );
use XTracker::Comms::DataTransfer   qw(:transfer_handles :transfer clear_catalogue_ship_restriction);
use Data::Dump 'pp';

my $dbh_xt = get_database_handle( { name => 'xtracker', type => 'readonly' } );
my $schema = get_schema_using_dbh($dbh_xt, 'xtracker_schema');

my $qry = "
    select product_id 
    from link_product__ship_restriction 
    where product_id in (
        select product_id from product_channel
        where channel_id = ? and live = true
    )
    order by product_id asc
--  limit 1
";

my $channels= $schema->resultset('Public::Channel')->get_channels();

print pp $channels;

foreach my $channel ( values %{ $channels } ) {

    print pp $channel;
    my $channel_id = $channel->{id};
    my $channel_name = $channel->{config_section};

    print "Processing channel $channel_id:$channel_name\n";


    if($channel->{fulfilment_only}){
       warn "Skipping channel $channel_id because it's fulfilment_only\n";
       next;
    }
    my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => 'live', channel => $channel_name  });
    $transfer_dbh_ref->{dbh_source} = $dbh_xt;
    my $sth = $dbh_xt->prepare( $qry );
    $sth->execute( $channel_id );
    while ( my $row = $sth->fetchrow_hashref() ) {

        eval{
            my $prod_id = $row->{product_id};

            print "Processing product $prod_id...\n";

            clear_catalogue_ship_restriction(
                {
                    dbh         => $transfer_dbh_ref->{dbh_sink},
                    product_ids => $prod_id,
                }
            );
            transfer_product_data(
                {
                    dbh_ref             => $transfer_dbh_ref,
                    channel_id          => $channel_id,
                    product_ids         => $prod_id,
                    transfer_categories => 'catalogue_ship_restriction',
                    sql_action_ref      => { catalogue_ship_restriction => {insert => 1} },
                }
            );

            $transfer_dbh_ref->{dbh_sink}->commit();

        };

        if ($@) {
                $transfer_dbh_ref->{dbh_sink}->rollback();
                print $@."\n\n";
        }
        else {
                print "\n";
        }
    }
    $transfer_dbh_ref->{dbh_sink}->disconnect();
}
$dbh_xt->disconnect();
