#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database                  qw( get_database_handle );
use XTracker::Database::Product         qw( product_present create_product_channel );
use XTracker::Database::ChannelTransfer qw( set_product_transfer_status );
use XTracker::Database::Stock           qw( update_quantity insert_quantity delete_quantity check_stock_location get_stock_location_quantity );
use XTracker::Database::Channel         qw( get_channels );
use XTracker::Database::Logging         qw( log_pws_stock log_stock log_location );
use XTracker::Comms::FCP                qw( update_web_stock_level );
use XTracker::Constants::FromDB         qw( :channel_transfer_status );

use XT::JQ::DC;

use DateTime;
use Getopt::Long;

my $source_channel  = undef;
my $dest_channel    = undef;
my $input_file      = undef;
my $dt              = DateTime->now(time_zone => "local");

GetOptions( 
    'source_channel=i'  => \$source_channel, 
    'dest_channel=i'    => \$dest_channel, 
    'input_file=s'      => \$input_file, 
); 
 
die 'No source_channel defined' if not defined $source_channel; 
die 'No dest_channel defined' if not defined $dest_channel;
die 'No input_file defined' if not defined $input_file;


# get an xt db connection
my $dbh = get_database_handle( { name => 'xtracker', type => 'transaction' } );

# get web handles for stock adjustments
my %dbh_web;
my $channels = get_channels($dbh);
foreach my $channel_id ( keys %{$channels} ) {
    $dbh_web{$channel_id} = get_database_handle( { name => 'Web_Live_'.$channels->{$channel_id}{config_section}, type => 'transaction' } ) || die "Could not connect to web db for channel id: $channel_id";   
}

$dbh->commit();

# read in products to be transferred from input file
open ( my $IN, '<', $input_file ) || die "Cannot open input file: $input_file - $!";

eval{

    while (my $product_id = <$IN>) {

        $product_id =~ s/\r//;
        $product_id =~ s/\n//;
        
        print "Processing $product_id...\n";

        # set transfer status on source channel
        set_product_transfer_status(
            $dbh,
            {
                product_id  => $product_id,
                channel_id  => $source_channel,
                status_id   => $CHANNEL_TRANSFER_STATUS__TRANSFERRED,
                operator_id => 1,
            }
        );


        # something to track total qty transferred
        my $transfer_qty = 0;

        # transfer stock
        my $qry = "select q.*, l.location from quantity q, location l where q.channel_id = ? and q.variant_id in (select id from variant where product_id = ?) and q.location_id = l.id and l.type_id = 1 and quantity > 0";
        my $sth = $dbh->prepare( $qry );
        $sth->execute( $source_channel, $product_id );

        while ( my $row = $sth->fetchrow_hashref() ) {

            # adjust of source channel and log
            update_quantity(
                $dbh,
                {
                    variant_id  => $row->{variant_id},
                    location    => $row->{location},
                    quantity    => ($row->{quantity} * -1),
                    type        => 'dec',
                    channel_id  => $row->{channel_id},
                 }
            );

            # log update
            log_stock(
                $dbh,
                {
                    variant_id  => $row->{variant_id},
                    action      => 14,  # Channel Transfer Out
                    quantity    => ($row->{quantity} * -1),
                    operator_id => 1,
                    notes       => 'Bulk Channel Transfer',
                    channel_id  => $row->{channel_id},
                },
            );

            # delete quantity record if location now empty
            my $old_quantity = get_stock_location_quantity(
                $dbh,
                {   variant_id  => $row->{variant_id},
                    location    => $row->{location},
                    channel_id  => $row->{channel_id},
                }
            );
            if ( $old_quantity == 0 ) {
                delete_quantity(
                    $dbh,
                    {
                        variant_id  => $row->{variant_id},
                        location    => $row->{location},
                        channel_id  => $row->{channel_id}
                    }
                );

                log_location(
                    $dbh,
                    {
                        variant_id  => $row->{variant_id},
                        location_id => $row->{location_id},
                        operator_id => 1,
                        channel_id  => $row->{channel_id}
                     }
                );
            }

            if ( product_present( $dbh, { type => 'variant_id', id => $row->{variant_id}, channel_id => $row->{channel_id} } ) ) {

                update_web_stock_level(
                        $dbh,
                        $dbh_web{ $row->{channel_id} },
                        {
                            quantity_change => ($row->{quantity} * -1),
                            variant_id      => $row->{variant_id}
                        }
                );

                log_pws_stock(
                        $dbh,
                        {
                            variant_id  => $row->{variant_id},
                            action      => 14,  # Channel Transfer Out
                            quantity    => ($row->{quantity} * -1),
                            operator_id => 1,
                            notes       => 'Bulk Channel Transfer',
                            channel_id  => $row->{channel_id},
                        }
                );

            }

            # adjust onto dest channel and log
            if ( check_stock_location( $dbh, { variant_id => $row->{variant_id}, location => $row->{location}, channel_id => $dest_channel }) ) {
                update_quantity(
                    $dbh,
                    {
                        variant_id  => $row->{variant_id},
                        location    => $row->{location},
                        quantity    => $row->{quantity},
                        type        => 'inc',
                        channel_id  => $dest_channel,
                     }
                );
            }
            else {
                insert_quantity( 
                    $dbh, 
                    { 
                        variant_id  => $row->{variant_id}, 
                        location    => $row->{location}, 
                        quantity    => $row->{quantity}, 
                        channel_id  => $dest_channel,
                    } 
                );
            }

            # log update
            log_stock(
                $dbh,
                {
                    variant_id  => $row->{variant_id},
                    action      => 15,  # Channel Transfer In
                    quantity    => $row->{quantity},
                    operator_id => 1,
                    notes       => 'Bulk Channel Transfer',
                    channel_id  => $dest_channel,
                },
            );

            print "Transferred $row->{quantity} units of $row->{variant_id}\n";

            # keep track of transferred qty
            $transfer_qty += $row->{quantity};
        }

        # set ordered quantity as qty transferred on dest channel
        $qry = "UPDATE product.stock_summary SET ordered = ? WHERE product_id = ? AND channel_id = ?";
        $sth = $dbh->prepare( $qry );
        $sth->execute( $transfer_qty, $product_id, $dest_channel );

        print "Set ordered qty as - $transfer_qty\n";

        # create fulcrum transfer job
        my %fulcrum_payload = (
            source_channel  => $source_channel,
            dest_channel    => $dest_channel,
            transfer_date   => $dt->date,
            product_id      => $product_id,
            quantity        => $transfer_qty,            
        );

        my $job = XT::JQ::DC->new({ funcname => 'Send::Product::Transfered' });
        $job->set_payload( \%fulcrum_payload );
        $job->send_job();


    }

    $dbh->commit();

    # commit web handles
    foreach my $channel_id ( keys %{$channels} ) {
        $dbh_web{$channel_id}->commit();
    }

};

if ($@){
    $dbh->rollback();
    
    # rollback web handles
    foreach my $channel_id ( keys %{$channels} ) {
        $dbh_web{$channel_id}->rollback();
    }

    print "ERROR: $@\n\n";
}
else {
    print "DONE\n\n";
}


$dbh->disconnect();

# disconnect web handles
foreach my $channel_id ( keys %{$channels} ) {
    $dbh_web{$channel_id}->disconnect();
}
