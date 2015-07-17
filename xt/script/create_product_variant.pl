#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( get_database_handle );
use XTracker::Database::Product qw( get_product_channel get_product_channel_info create_variant );
use XTracker::Database::Channel     qw(get_channel);
use XTracker::Comms::DataTransfer   qw(:transfer_handles :transfer :upload_transfer list_pids_to_upload set_pws_visibility set_xt_product_status);



my $dbh_xt_dc1 = get_database_handle( { name => 'XTracker_DC1', type => 'transaction' } );
my $dbh_xt_dc2 = get_database_handle( { name => 'XTracker_DC2', type => 'transaction' } );

# read in data
open my $IN,'<',"sizes.txt" || die "Cannot open site input file: $! - ";

while ( my $line = <$IN> ) {

    $line =~ s/\r//;
    $line =~ s/\n//;

    my ($product_id, $size, $designer_size) = split(/\t/, $line);

    eval {

        # get id's for sizes
        my $size_id             = _get_size_id( $dbh_xt_dc1, $size );
        my $designer_size_id    = _get_size_id( $dbh_xt_dc1, $designer_size );

        die 'Could not find size - ' . $size if !$size_id;
        die 'Could not find designer size - ' . $designer_size if !$designer_size_id;

        print "Creating size: $size for product: $product_id\n";

        # create variant on DC1 db
        my $var_id = create_variant (
                $dbh_xt_dc1,
                $product_id,
                {
                    'legacy_sku'        => $product_id,
                    'type_id'           => 1,
                    'size_id'           => $size_id,
                    'designer_size_id'  => $designer_size_id,
                }
        );

        # create variant on DC2 database
        create_variant (
                $dbh_xt_dc2,
                $product_id,
                {
                    'legacy_sku'        => $product_id,
                    'type_id'           => 1,
                    'size_id'           => $size_id,
                    'designer_size_id'  => $designer_size_id,
                    'variant_id'        => $var_id,
                }
        );


        # push new size to websites if required

        # check current DC1 web status
        my $dc1_active_channel  = get_product_channel( $dbh_xt_dc1, $product_id );
        my $dc1_channel_data    = get_product_channel_info( $dbh_xt_dc1, $product_id );

        # product is live on active channel - update site
        if ( $dc1_channel_data->{ $dc1_active_channel }{live} == 1 ) {

            my $channel_data        = get_channel( $dbh_xt_dc1, $dc1_channel_data->{ $dc1_active_channel }{channel_id} );
            my $transfer_dbh_ref    = get_transfer_db_handles( { source_type => 'transaction', environment => 'live', channel => $channel_data->{config_section} } );
            $transfer_dbh_ref->{dbh_source} = $dbh_xt_dc1;
        
            eval {
                transfer_product_data({
                    dbh_ref             => $transfer_dbh_ref,
                    channel_id          => $dc1_channel_data->{ $dc1_active_channel }{channel_id},
                    product_ids         => $product_id,
                    transfer_categories => ['catalogue_sku', 'catalogue_pricing', 'catalogue_markdown'],
                    sql_action_ref      => {
                                                catalogue_sku           => {insert => 1, update => 1},
                                                catalogue_pricing       => {insert => 1, update => 1},
                                                catalogue_markdown      => {insert => 1, update => 1},
                                           }
                });

                transfer_product_inventory({
                    dbh_ref         => $transfer_dbh_ref,
                    channel_id      => $dc1_channel_data->{ $dc1_active_channel }{channel_id},
                    product_ids     => $product_id,
                    sql_action_ref  => { saleable_inventory => { insert => 1, update => 1 } },
                });

                $transfer_dbh_ref->{dbh_sink}->commit();
            };

            if ($@) {
                $transfer_dbh_ref->{dbh_sink}->rollback();
                die "Could not push size to INTL website - " . $@ . "\n";                        
            }
            else {
                print "Size pushed to INTL website\n";
            }

            $transfer_dbh_ref->{dbh_sink}->disconnect();
        }


        # check current DC2 web status
        my $dc2_active_channel  = get_product_channel( $dbh_xt_dc2, $product_id );
        my $dc2_channel_data    = get_product_channel_info( $dbh_xt_dc2, $product_id );

        # product is live on active channel - update site
        if ( $dc2_channel_data->{ $dc2_active_channel }{live} == 1 ) {

            my $channel_data        = get_channel( $dbh_xt_dc2, $dc2_channel_data->{ $dc2_active_channel }{channel_id} );
            my $transfer_dbh_ref    = get_transfer_db_handles( { source_type => 'transaction', environment => 'live', channel => $channel_data->{config_section} } );
            $transfer_dbh_ref->{dbh_source} = $dbh_xt_dc2;

            eval {
                transfer_product_data({
                    dbh_ref             => $transfer_dbh_ref,
                    channel_id          => $dc2_channel_data->{ $dc2_active_channel }{channel_id},
                    product_ids         => $product_id,
                    transfer_categories => ['catalogue_sku', 'catalogue_pricing', 'catalogue_markdown'],
                    sql_action_ref      => {
                                                catalogue_sku           => {insert => 1, update => 1},
                                                catalogue_pricing       => {insert => 1, update => 1},
                                                catalogue_markdown      => {insert => 1, update => 1},
                                           }
                });

                transfer_product_inventory({
                    dbh_ref         => $transfer_dbh_ref,
                    channel_id      => $dc2_channel_data->{ $dc2_active_channel }{channel_id},
                    product_ids     => $product_id,
                    sql_action_ref  => { saleable_inventory => { insert => 1, update => 1 } },
                });    
            
                $transfer_dbh_ref->{dbh_sink}->commit();
            };

            if ($@) {
                $transfer_dbh_ref->{dbh_sink}->rollback(); 
                die "Could not push size to AM website - " . $@ . "\n";                
            }
            else {
                print "Size pushed to AM website\n";
            }

            $transfer_dbh_ref->{dbh_sink}->disconnect();
        }

        $dbh_xt_dc1->commit();           
        $dbh_xt_dc2->commit();
    };

    if ($@) {
        print "Error creating size - " . $@ . "\n\n";
        $dbh_xt_dc1->rollback();           
        $dbh_xt_dc2->rollback();           
    }
    else {
        print "New size created\n\n";
    }

}


$dbh_xt_dc1->disconnect();           
$dbh_xt_dc2->disconnect();     



sub _get_size_id {

    my ( $dbh, $size ) = @_;

    my $size_id;

    my $qry = 'SELECT id FROM size WHERE size = ?';
    my $sth = $dbh->prepare($qry);
    $sth->execute( $size );

    my $data = $sth->fetchrow_hashref();

    if ($data->{id}) {
        $size_id = $data->{id}
    }

    return $size_id;
}
