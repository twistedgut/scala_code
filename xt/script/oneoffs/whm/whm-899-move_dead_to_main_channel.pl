#!/opt/xt/xt-perl/bin perl

use strict;
use warnings;

# Hard-code lib directory so this script can be run from any dir on live
use lib '/opt/xt/deploy/xtracker/lib';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/schema_handle/;
use XTracker::Constants::FromDB qw( :flow_status );

my $schema = schema_handle;

# get all variants in dead stock
my @dead_quantities
    = $schema->resultset('Public::Quantity')
             ->search(
                 { 'me.status_id' => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS, },
                 { join => 'product_variant',
                   order_by => [qw{
                       product_variant.product_id
                       product_variant.size_id
                   }], },
             )->all;

printf "Found %d dead quantity stock\n", scalar @dead_quantities;
my $how_many = 0;

eval {
    my $guard = $schema->txn_scope_guard;
    for my $quantity ( @dead_quantities ) {
        my $variant = $quantity->variant;
        my $product_channel = $variant->product->get_product_channel;

        my $original_channel_id = $quantity->channel_id;

        next if $original_channel_id == $product_channel->channel_id;

        my $new_quantity = $schema->resultset('Public::Quantity')->find({
            channel_id => $product_channel->channel_id,
            (map {; $_ => $quantity->$_ } qw/variant_id location_id status_id/),
        });
        if ( $new_quantity ) {
            my ( $source_q, $target_q ) = ( $quantity->quantity, $new_quantity->quantity );
            $schema->txn_do(sub{
                $new_quantity->update({ quantity => \"quantity + $source_q" });
                $quantity->delete;
            });
            printf "Summed dead stock channel quantities for %s from %d (%d) to %d (%d) (total %d)\n",
                $variant->sku, $original_channel_id, $source_q,
                $product_channel->channel_id, $target_q, $new_quantity->discard_changes->quantity;
        }
        else {
            $quantity->update({channel_id => $product_channel->channel_id});
            printf "Updated dead stock channel for %s from %d to %d (total %d)\n",
                $variant->sku, $original_channel_id, $product_channel->channel_id, $quantity->discard_changes->quantity;
        }
        $how_many++;
    }
    $guard->commit;
};
if ( $@ ) {
    $how_many = 0;
    print "Failed to update dead stock variants - rolling back: $@\n";
}
print "Updated $how_many dead stock variants\n";
