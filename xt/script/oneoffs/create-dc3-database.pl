#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;
use File::Temp;

# FIXME: For now we just create a copy of DC2 called XTDC3.
my $dc      = 2;
my $db_name = 'xtdc3';

# Fetch blank database.
`script/download_blank_db.pl -d $dc -t $db_name`; ## no critic(ProhibitBacktickOperators)

print "Updating the target database\n";
my $sql_file = File::Temp->new;

# Create perlydev user.
print $sql_file q[
    CREATE ROLE perlydev LOGIN
    PASSWORD 'perlydev'
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE;
];

# Create www user.
print $sql_file q[
    CREATE ROLE www LOGIN
    PASSWORD 'www'
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE;
];

# We'll be running everything in a transaction, so it either all gets commited
# or none of it does.

print $sql_file q[
    BEGIN WORK;
];

# Append APAC/DC3 Related rows to relevant tables.

print $sql_file q[
    INSERT INTO event.website (
        id,
        name
    )
    VALUES
    ( 5, 'APAC' ),
    ( 6, 'OUT-APAC' );
];

#print $sql_file q[
#    INSERT INTO distrib_centre (
#        id,
#        name
#    )
#    VALUES
#    ( 3, 'DC3' );
#];

# Create the new channels in the channel table (we need to keep the originals
# for now, as constraints would prevent them from being deleted until all their
# children have been moved to the new channels). The 'x' prefix is required
# to satisfy the unique constraint.

print $sql_file q[
    INSERT INTO channel (
        id,
        name,
        business_id,
        distrib_centre_id,
        web_name,
        is_enabled,
        timezone,
        company_registration_number,
        default_tax_code
        )
    VALUES
    ( 9,  'xNET-A-PORTER.COM', 1, 3, 'NAP-APAC',    TRUE, 'Asia/Hong_Kong', '00000000', '' ),
    ( 10, 'xtheOutnet.com',    2, 3, 'OUTNET-APAC', TRUE, 'Asia/Hong_Kong', '00000000', '' ),
    ( 11, 'xMRPORTER.COM',     3, 3, 'MRP-APAC',    TRUE, 'Asia/Hong_Kong', '00000000', '' ),
    ( 12, 'xJIMMYCHOO.COM',    4, 3, 'JC-APAC',     TRUE, 'Asia/Hong_Kong', '00000000', '' );
];

# We now go through the following tables updating the channel_id (or other column)
# to point to the new channels.

my %tables = (

# The following tables are not required, but need to be updated:

    'channel_transfer'                          => 'from_channel_id',
    'channel_transfer'                          => 'to_channel_id',
    'channel_branding'                          => undef,
    'customer'                                  => undef,
    'customer_credit'                           => undef,
    'designer_channel'                          => undef,
    'hotlist_value'                             => undef,
    'log_designer_description'                  => undef,
    'log_location'                              => undef,
    'log_putaway_discrepancy'                   => undef,
    'log_pws_stock'                             => undef,
    'log_rtv_stock'                             => undef,
    'log_stock'                                 => undef,
    'old_log_location'                          => undef,
    'orders'                                    => undef,
    'postcode_shipping_charge'                  => undef,
    'voucher.product'                           => undef,
    'quantity'                                  => undef,
    'recommended_product'                       => undef,
    'reservation'                               => undef,
    'rtv_quantity'                              => undef,
    'rtv_shipment'                              => undef,
    'sample_classification_default_size'        => undef,
    'sample_product_type_default_size'          => undef,
    'sample_request_cart'                       => undef,
    'sample_request'                            => undef,
    'sample_size_scheme_default_size'           => undef,
    'shipping_account__country'                 => undef,
    'shipping_account'                          => undef,
    'shipping_charge'                           => undef,
    'state_shipping_charge'                     => undef,
    'super_purchase_order'                      => undef,
    'upload.transfer'                           => undef,
    # This was found using information_schema.columns, where column_name was 'channel_id', but no constraint was present on the channel table.
    'routing_export'                            => undef,

# The following tables are required:

    'shipping.account'                          => undef,
    'designer.attribute'                        => undef,
    'product.attribute'                         => undef,
    'box'                                       => undef,
    'bulk_reimbursement'                        => undef,
    'carrier_box_weight'                        => undef,
    'shipping.charge'                           => undef,
    'system_config.config_group'                => undef,
    'country_shipment_type'                     => undef,
    'country_shipping_charge'                   => undef,
    'country_tax_code'                          => undef,
    'credit_hold_threshold'                     => undef,
    'inner_box'                                 => undef,
    'location_zone_to_zone_mapping'             => undef,
    'designer.log_website_state'                => undef,
    'navigation_colour_mapping'                 => undef,
    'web_content.page'                          => undef,
    'operator_preferences'                      => 'pref_channel_id',
    'product_channel'                           => undef,
    'product_type_measurement'                  => undef,
    'promotion_type'                            => undef,
    'voucher.purchase_order'                    => undef,
    'purchase_order'                            => undef,
    'product.pws_product_sort_variable_value'   => undef,
    'product.pws_sort_order'                    => undef,
    'product.pws_sort_variable_weighting'       => undef,
    'quarantine_process'                        => undef,
    'reservation_consistency'                   => undef,
    'returns_charge'                            => undef,
    'rma_request'                               => undef,
    'stock_consistency'                         => undef,
    'product.stock_summary'                     => undef,
    'stock_transfer'                            => undef,
    'correspondence_subject'                    => undef,

);

foreach my $table ( sort keys %tables ) {

    my $column = $tables{$table} || 'channel_id';

#    print $sql_file qq[
#
#        UPDATE  $table AS me
#        SET     $column = (
#            SELECT  id
#            FROM    channel
#            WHERE   name = (
#                SELECT  'x' || name
#                FROM    channel
#                WHERE   id = me.$column
#            )
#        );
#
#    ];

    print $sql_file qq[

        UPDATE  $table
        SET     $column = 9
        WHERE   $column = 2;

        UPDATE  $table
        SET     $column = 10
        WHERE   $column = 4;

        UPDATE  $table
        SET     $column = 11
        WHERE   $column = 6;

        UPDATE  $table
        SET     $column = 12
        WHERE   $column = 8;

    ];

}

# Now all the child tables have been updated, we can remove the original channels
# and remove the 'x' prefix of each channel name.

print $sql_file q[
    DELETE  FROM channel
    WHERE   id < 9;
];

print $sql_file q[
    UPDATE  channel
    SET     name = substr( name, 2 );
];

# Update the system_config table to reflect the new APAC distribution centre instead
# of AM.

print $sql_file q[
    UPDATE  system_config.config_group_setting
    SET     setting = 'NAP-APAC_Order_Threshold'
    WHERE   setting = 'NAP-AM_Order_Threshold';
];

print $sql_file q[
    UPDATE  system_config.config_group_setting
    SET     setting = 'OUTNET-APAC_Order_Threshold'
    WHERE   setting = 'OUTNET-AM_Order_Threshold';
];

# The following TABLES/VIEWS can all be dropped (confirmed by Roy Mohanan/MIS), as
# they are no longer used.

print $sql_file q[
    DROP VIEW njiv_pws_log_stock_reporting;
    DROP VIEW njiv_pws_log_stock_reporting_outnet;
    DROP VIEW njiv_product_ordered_qty;
    DROP VIEW njiv_product_ordered_qty_outnet;
    DROP VIEW njiv_combined_season_outnet;
    DROP VIEW njiv_1st_sold_out;
    DROP VIEW njiv_1st_sold_out_outnet;
    DROP VIEW njiv_cancellations;
    DROP VIEW njiv_cancellations_outnet;
    DROP VIEW njiv_combined_season;
    DROP VIEW njiv_daily_totals;
    DROP VIEW njiv_daily_totals_2;
    DROP VIEW njiv_daily_totals_2_outnet;
    DROP VIEW njiv_daily_totals_currency_2;
    DROP VIEW njiv_daily_totals_currency_2_outnet;
    DROP VIEW njiv_daily_totals_outnet;
    DROP VIEW njiv_daily_ukl;
    DROP VIEW njiv_daily_ukl_outnet;
    DROP VIEW njiv_ftbc_gross_orders;
    DROP VIEW njiv_ftbc_gross_orders_outnet;
    DROP VIEW njiv_ftbc_gross_sales;
    DROP VIEW "njiv_ftbc_gross_sales_OLD";
    DROP VIEW njiv_ftbc_gross_sales_outnet;
    DROP VIEW njiv_ftbc_merch_cancellations;
    DROP VIEW njiv_ftbc_merch_cancellations_outnet;
    DROP VIEW njiv_ftbc_merch_returns;
    DROP VIEW njiv_ftbc_merch_returns_outnet;
    DROP VIEW njiv_gross_order_totals_currency;
    DROP VIEW njiv_gross_order_totals_currency_outnet;
    DROP VIEW njiv_last_invoice_address;
    DROP VIEW njiv_master_free_stock;
    DROP VIEW njiv_master_free_stock_outnet;
    DROP VIEW njiv_master_product_attributes;
    DROP VIEW njiv_master_product_attributes_outnet;
    DROP VIEW njiv_merch_sales_season;
    DROP VIEW njiv_merch_sales_season_outnet;
    DROP VIEW njiv_net_sales;
    DROP VIEW njiv_net_sales_outnet;
    DROP VIEW njiv_net_sales_variant;
    DROP VIEW njiv_orders;
    DROP VIEW njiv_orders2;
    DROP VIEW njiv_orders_outnet;
    DROP VIEW njiv_preorder_returns_dispatchdate;
    DROP VIEW njiv_preorder_returns_dispatchdate_outnet;
    DROP VIEW njiv_prod_orders;
    DROP VIEW njiv_prod_orders_outnet;
    DROP VIEW njiv_returns;
    DROP VIEW njiv_returns_outnet;
    DROP VIEW njiv_rm_cancellations;
    DROP VIEW njiv_rm_cancellations_outnet;
    DROP VIEW njiv_rm_daily_totals_currency;
    DROP VIEW njiv_rm_daily_totals_currency_dispatch;
    DROP VIEW njiv_rm_daily_totals_currency_dispatch_outnet;
    DROP VIEW njiv_rm_daily_totals_currency_outnet;
    DROP VIEW njiv_rm_returns;
    DROP VIEW njiv_rm_returns_outnet;
    DROP VIEW njiv_sales_team_orders__placed_by;
    DROP VIEW njiv_sales_team_orders__reservation;
    DROP VIEW njiv_stock_by_location;
    DROP VIEW njiv_stock_by_location_outnet;
    DROP VIEW njiv_variant_free_stock;
    DROP VIEW njiv_variant_free_stock_outnet;
    DROP TABLE nji_lookup_fx_rates;
    DROP TABLE notes_product;
];

# Commit all the changes.

print $sql_file q[
    COMMIT;
];

# Now we have built the SQL file, run it!

print "psql -q -U postgres -h localhost -d $db_name -f " . $sql_file->filename . "\n";

if ( system( "psql -q -U postgres -h localhost -d $db_name -f " . $sql_file->filename ) ) {

    print "Failed!\n";

} else {

    print "Success\n";

}

# Create the Job Queue Database.

print "Creating the JOB_QUEUE database\n";

print "createdb -U postgres -T template1 job_queue\n";
if ( system( 'createdb -U postgres -T template1 job_queue > /dev/null' ) ) {

    print "Failed!\n";

} else {

    print "psql -U postgres -d job_queue < db_schema/current_jq/00_base_schema.sql\n";
    if ( system( 'psql -U postgres -d job_queue < db_schema/current_jq/00_base_schema.sql > /dev/null' ) ) {

        print "Failed!\n";

    } else {

        print "Success\n";

    }

}
