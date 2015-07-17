#!/usr/bin/perl -w
#############################################################################
# This is just an example. It's the script I used to create the sql needed 
# to alter the length of variant.legacy_sku, which turned out to be a huge
# patch because lots of views reference it either directly or indirectly.
#
# The views you need to change will obviously depend on which column you're
# altering.
#
# Also, this script only deals with the relatively simple case where the
# change you're making doesn't require any actual changes to the view
# definitions. 
#############################################################################
use strict;
use warnings;

my @views = qw(
vw_rtv_shipment_validate_pick 
vw_rtv_shipment_picklist 
vw_rtv_shipment_validate_pack
vw_rtv_shipment_packlist
vw_rtv_shipment_details_with_results
vw_rtv_shipment_details
vw_rma_request_details
vw_rtv_inspection_validate_pick
vw_rtv_inspection_list
vw_rtv_inspection_pick_requested
vw_rtv_inspection_pick_request_details
vw_rtv_workstation_stock
vw_rtv_inspection_stock
vw_rtv_stock_details
vw_list_rma
vw_product_variant
vw_sample_request_dets
super_variant
njiv_variant_free_stock_outnet
njiv_variant_free_stock
);

foreach my $db ('xtracker','xtracker_dc2') {

    my $pg_dump_cmd = "pg_dump $db -h 127.0.0.1 -U postgres -s ";

    my $sql_drop="";
    my $sql_recreate="";
    foreach my $view (@views) {
        $sql_drop .= "drop view $view;\n";
        my $create_statement = `$pg_dump_cmd -t $view`; ## no critic(ProhibitBacktickOperators)
        $sql_recreate = $create_statement."\n\n".$sql_recreate; # at the start
    }

    my $sql = qq(
BEGIN;

-- Drop all the views that use variant.legacy_sku:
$sql_drop

-- The actual change we want to make:
alter table variant alter column legacy_sku type varchar(255);

-- And now recreate all the views:
$sql_recreate
COMMIT;
);

    open my $FH, '>',"/tmp/00_legacy_sku_length_$db.sql";
    print $FH $sql;
    close $FH;

}
