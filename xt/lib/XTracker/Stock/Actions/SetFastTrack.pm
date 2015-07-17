package XTracker::Stock::Actions::SetFastTrack;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Utilities         qw( unpack_handler_params );
use XTracker::Database;
use XTracker::Database::Logging qw( log_delivery );
use XTracker::Database::Product qw( get_product_id get_product_data );
use XTracker::Database::Delivery qw( :DEFAULT get_delivery_channel );
use XTracker::Database::StockProcess;
use XTracker::Database::Attributes qw(:update);
use XTracker::Barcode;
use XTracker::PrintFunctions;
use XTracker::Constants::FromDB qw( :stock_process_status :stock_process_type );
use XTracker::Error;
use XTracker::Config::Local 'config_var';

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $sp_ref      = ();
    my $delivery_id = 0;

    my $operator_id = $handler->operator_id;

    eval{

        # unpack request parameters
        my ( $data_ref, $rest_ref ) = unpack_handler_params($handler->{param_of});

        my $guard = $handler->schema->txn_scope_guard;
        foreach my $stock_process_id ( keys %{$data_ref} ) {
            push @{$sp_ref},
                { stock_process_id => $stock_process_id,
                  fasttrack        => $data_ref->{$stock_process_id}->{fasttrack},
                  counted          => $data_ref->{$stock_process_id}->{counted},
                  quantity         => $data_ref->{$stock_process_id}->{quantity},
                  sku              => $data_ref->{$stock_process_id}->{sku},
                };
        }

        # save delivery_id in case of errors
        $delivery_id = $rest_ref->{delivery_id};

        # create stock_process entries
        my $data = { stock_process_items => $sp_ref, };

        # set the fast track values
        set_fast_track( $handler, $data, $delivery_id, $operator_id );

        # redirect to delivery scan
        $guard->commit();
    };
    if( my $err = $@ ){
        # error - redirect to qc booking
        xt_warn("$err");
    }

    return $handler->redirect_to( "Book?delivery_id=$delivery_id" );
}

### Subroutine : set_fast_track            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_fast_track {
    my ( $handler, $data_ref, $delivery_id, $operator_id ) = @_;

    my $dbh = $handler->{dbh};
    my $main_group    = 0;
    my $fasttrack_group  = 0;

    my $total_fasttrack = 0;

    # Save main group
    $main_group    = get_process_group_id( $dbh, $data_ref->{stock_process_items}->[0]->{stock_process_id} );

    foreach my $sp_ref ( @{ $data_ref->{stock_process_items} } ) {

        my $delivery_item_id = stock_process_data( $dbh,
                                                   $sp_ref->{stock_process_id},
                                                   'delivery_item_id' );

        if ( $sp_ref->{fasttrack} ) {

            if ( ! $sp_ref->{quantity} ) {
                my $sku = $sp_ref->{sku} // '???';
                xt_warn "Fast track with SKU $sku has been requested with zero quantity.";
                next;
            }

            if ($sp_ref->{quantity} > $sp_ref->{counted}) {
                $sp_ref->{quantity} = $sp_ref->{counted};
            }

            my $new_sp = split_stock_process( $dbh,
                                              $STOCK_PROCESS_TYPE__FASTTRACK,
                                              $sp_ref->{stock_process_id},
                                              $sp_ref->{quantity},
                                              \$fasttrack_group,
                                              $delivery_item_id );

            set_stock_process_status( $dbh, $new_sp, $STOCK_PROCESS_STATUS__APPROVED );

            $total_fasttrack += $sp_ref->{quantity};
        }

        my $complete = check_stock_process_complete( $dbh,
                                                     'stock_process',
                                                     $sp_ref->{stock_process_id} );

        if ($complete) {
            complete_stock_process( $dbh, $sp_ref->{stock_process_id} );
        }
    }

    # printing
    if( $fasttrack_group ){
        my $sp_group = $handler->{schema}->resultset('Public::StockProcess')
            ->get_group($fasttrack_group);

        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::PreAdvice',
            {
                sp_group_rs => $sp_group,
            },
        );

        print_group( $handler, $delivery_id, $fasttrack_group, 'fasttrack' );
    }

    # logging
    if( $total_fasttrack ){

        log_delivery( $dbh, { "delivery_id" => $delivery_id, "action" => 3, "quantity" => $total_fasttrack, "operator" => $operator_id, "type_id" => 7 } );
    }

    return;
}


### Subroutine : print_group                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub print_group {

    my ( $handler, $delivery_id, $group_id, $type ) = @_;

    my $dbh = $handler->schema->storage->dbh;
    my $sku_ref = get_stock_process_items( $dbh, 'process_group', $group_id );

    my $product_id = get_product_id( $dbh, { type => 'delivery_id', id   => $delivery_id } );

    my $data = { process_group_items => $sku_ref,
                 delivery_id         => $delivery_id,
                 group_id            => $group_id,
                 product             => get_product_data( $dbh, { type => 'product_id', id => $product_id } ),
                 sales_channel       => get_delivery_channel( $dbh, $delivery_id ),
               };

    # TODO: convert to utility subroutine
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    $data->{print_date} = $mday . "-" . ($mon+1) . "-" . ( $year + 1900 ) . " " . $hour . ":" . $min;

    create_barcode( "delivery-$delivery_id", $delivery_id, 'small', 3, 1, 65);
    if ($handler->iws_rollout_phase == 0) {
        create_barcode( "sub_delivery-$group_id", $group_id, 'small', 3, 1, 65);
    }
    else {
        create_barcode( "sub_delivery-$group_id", "p-$group_id", 'small', 3, 1, 65);
    }

    create_document("$type-$group_id", "print/$type.tt", $data);

    my $product = $handler->schema->resultset('Public::Product')->find({ id => $product_id });
    my $config_section = $product->get_product_channel()->channel->config_name;
    my $printer_name = config_var('FastTrackChannelPrinterName', $config_section);

    print_document("$type-$group_id", $printer_name, 1);

    return;
}

1;

__END__

