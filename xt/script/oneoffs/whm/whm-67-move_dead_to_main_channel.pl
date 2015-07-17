#!/usr/bin/env perl
use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/schema_handle/;
use XTracker::Constants::FromDB qw(
    :flow_status
    :channel_transfer_status 
);
use XTracker::Config::Local;

my $schema = schema_handle;

# get all variants 
my $quantity_rs = $schema->resultset('Public::Quantity')->search({status_id => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
                                                                                     quantity  =>  {">" => 0}});
print "Moving current dead stock is on the same channel as it's main channel counter part \n";
while (my $quantity_dead = $quantity_rs->next){
    ## check if main channel id is the same as dead channel id 
    
    my $quantity_main = $schema->resultset('Public::Quantity')->search({status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                                                                        variant_id => $quantity_dead->variant_id,
                                                                        channel_id => { q{!=} => $quantity_dead->channel_id },
                                                                        })->slice(0,0)->single;
    my $variant = $quantity_dead->variant;

    if ( defined $quantity_dead and defined $quantity_main
                                and ($quantity_dead->channel_id != $quantity_main->channel_id)){
        ## get last transfer id
        
        my $transfer = $schema->resultset('Public::ChannelTransfer')->search({product_id      => $variant->product_id,
                                                                              from_channel_id => $quantity_dead->channel_id,
                                                                              to_channel_id   => $quantity_main->channel_id,
                                                                              status_id       => $CHANNEL_TRANSFER_STATUS__COMPLETE,
                                                                    })->slice(0,0)->single;
        next if !$transfer;
        print "Moving dead stock for variant ".$variant->id." and transfer ".$transfer->id." from channel ".$quantity_dead->channel_id." to channel ". $quantity_main->channel_id."\n";

        # do we have any dead stock on the destination channel already?
        my $current_dead_stock = $schema->resultset('Public::Quantity')->search({
                                                                status_id   => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
                                                                location_id => $quantity_dead->location_id,
                                                                channel_id  => $quantity_main->channel_id,
                                                                variant_id  => $quantity_dead->variant_id,
                                                            })->slice(0,0)->single;
        if ($current_dead_stock){
            my $txn = $schema->txn_scope_guard;
            my $new_quantity = $current_dead_stock->quantity + $quantity_dead->quantity;
            if ($new_quantity){
                $current_dead_stock->update({
                            quantity => $new_quantity
                        });

                $quantity_dead->delete;

                $txn->commit;
            }
            else{
                $current_dead_stock->delete;
                $quantity_dead->delete;
                $txn->commit;

            }
        }
        else{
            $quantity_dead->update({
                channel_id => $quantity_main->channel_id
            });
        }
    }
}



