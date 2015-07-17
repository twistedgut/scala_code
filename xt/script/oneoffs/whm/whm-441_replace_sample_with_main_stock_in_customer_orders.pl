#!/opt/xt/xt-perl/bin perl

use strict;
use warnings;

## Hard-code lib directory so this script can be run from any dir on live
use lib '/opt/xt/deploy/xtracker/lib';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/schema_handle/;
use XTracker::Constants::FromDB qw( :variant_type :delivery_type);
my $schema = schema_handle;

my $variants = $schema->resultset('Public::Variant')->search(
    {
        'me.type_id'       => $VARIANT_TYPE__SAMPLE,
        'delivery.type_id' => $DELIVERY_TYPE__CUSTOMER_RETURN,
    },
    {
        '+select' => ['return_items.id'],
        '+as'     => [qw/ri_id/],
        join       => {
            'return_items' =>
              { 'return' => { 'link_delivery__returns' => 'delivery' } }
        },
    },
);

my @result = $variants->all;
foreach my $variant (@result){
    my $main_stock_variant = $schema->resultset('Public::Variant')->search({
                                            product_id => $variant->product_id,
                                            size_id    => $variant->size_id,
                                            type_id    => $VARIANT_TYPE__STOCK
                                        })->slice(0,0)->single;
    
    if ($main_stock_variant){
        my $return_item_id = $variant->get_column('ri_id');
        my $return_item = $schema->resultset('Public::ReturnItem')->find($return_item_id);
        print "Updating variant id for return_item ". $return_item->id. " with variant id ". $main_stock_variant->id ." from variant id " . $variant->id."\n";
        $return_item->update({variant_id => $main_stock_variant->id});
    }

}
