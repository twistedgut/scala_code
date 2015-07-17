use strict;
use warnings;

package Test::XTracker::Data::DB;

=head1 NAME

Test::XTracker::Data::DB - DB shite.

=head1 DESCRIPTION

When C<import> is called (as it is by C<use>), certain tables in the
database are wiped: L<Test::XTracker::Data::DB|Test::XTracker::Data::DB>.see C<@COLS_TO_TRUNC>.

=cut

use Data::Dump 'pp';
use Log::Log4perl ':easy';
use XTracker::Database;

our $Called_Import;

INIT {
    # Call import even if required (as in use base):
    __PACKAGE__->import;
}


# See default_fixture()
our @DEFAULT_FIXTURE = (
    # Default designer
    "INSERT INTO public.designer VALUES (0, 'None', 'None')",
    # "INSERT INTO delivery VALUES (1,'777-12-31',0,0,0,true,false)",
);

# Convenience
our $DEFAULT_FIXTURE_TABLES = {
    map {
        /^\s*INSERT\s+INTO\s+(\S+)/ && ( $1 => 1 )
    } @DEFAULT_FIXTURE
} ;


sub import {
    return if $Called_Import++ > 0; # Only call this routine once
    my ($class, $arg) = @_;
    $class->reset_db; # if $arg and $arg =~ /^:?clea[rn]_?db$/;
}


=head2 C<@TRUNCATED_TABLES>

A list of all tables truncated in the test DB by F<script/db_truncate.pl>.

=cut

our @TRUNCATED_TABLES = qw(
   audit.action audit.event_detail audit.product audit.promotion_customer_customergroup dbadmin.applied_patch
   designer.log_attribute_value designer.log_website_state designer.website_state editorial.list_info
   editorial.list_listinfo event.coupon event.customer_customergroup event.detail event.detail_customer
   event.detail_customergroup event.detail_customergroupjoin_listtype event.detail_designers event.detail_product
   event.detail_products event.detail_producttypes event.detail_seasons event.detail_shippingoptions
   event.detail_websites list.child list.comment list.item list.list operator.message
   orders.log_payment_fulfilled_change orders.payment photography.image
   photography.image_amend photography.image_collection photography.image_collection_item photography.image_note
   photography.list_info photography.list_listinfo photography.sample_information product.attribute
   product.attribute_value product.list_item product.log_attribute_value product.log_navigation_tree
   product.navigation_tree product.navigation_tree_lock product.pws_product_sort_variable_value
   product.pws_sort_order product.pws_sort_variable_weighting product.stock_summary
   public.address public.cancelled_item public.card_payment
   public.card_refund public.channel_transfer public.channel_transfer_pick public.channel_transfer_putaway
   public.conversion_rate public.customer public.customer_category_log public.customer_credit
   public.customer_credit_log public.customer_flag public.customer_note public.customer_segment
   public.customer_segment_log public.delivery public.delivery_item public.delivery_item_fault
   public.delivery_note public.designer public.designer_channel public.designer_rtv_address
   public.designer_rtv_carrier public.division public.duty_rule_value public.gift_credit public.hotlist_value
   public.hs_code public.legacy_designer_supplier public.legacy_upload
   public.legacy_upload_product public.link_classification__product_type public.link_delivery__return
   public.link_delivery__shipment public.link_delivery__stock_order public.link_delivery_item__quarantine_process
   public.link_delivery_item__return_item public.link_delivery_item__shipment_item
   public.link_delivery_item__stock_order_item public.link_manifest__shipment public.link_orders__shipment
   public.link_product__ship_restriction public.link_product_type__sub_type public.link_return_renumeration
   public.link_routing_export__return public.link_routing_export__shipment public.link_rtv__process_group
   public.link_rtv__shipment public.link_shipment__promotion public.link_shipment_item__price_adjustment
   public.link_shipment_item__promotion public.link_stock_transfer__shipment public.log_channel_transfer
   public.log_delivery public.log_delivery_sample public.log_designer_description public.log_location
   public.log_location_move public.log_order_access public.log_pws_stock public.log_rtv_stock
   public.log_shipment_rtcb_state public.log_stock public.manifest
   public.manifest_status_log public.navigation_colour_mapping
   public.nji_lookup_fx_rates public.nji_lookup_fx_rates2 public.nji_mpa_static public.old_location
   public.operator public.operator_authorisation public.operator_preferences
   public.order_address public.order_address_log public.order_email_log public.order_flag public.order_note
   public.order_promotion public.order_status_log public.orders public.outfit public.outfit_product
   public.payment_deposit public.payment_settlement_discount public.price_adjustment public.price_default
   public.price_purchase public.product public.product_approval_archive public.product_attribute
   public.product_comment public.product_sales_data public.product_type
   public.promotion_type public.promotion_type_customer public.purchase_order public.putaway public.quantity
   public.quantity_audit public.quantity_details public.quarantine_process public.recommended_product
   public.renumeration public.renumeration_change_log public.renumeration_item public.renumeration_status_log
   public.reservation public.reservation_consistency public.reservation_log public.return public.return_arrival
   public.return_delivery public.return_item public.return_item_status_log public.return_note
   public.return_status_log public.returns_charge public.rma_request public.rma_request_detail
   public.rma_request_detail_status_log public.rma_request_note public.rma_request_status_log
   public.routing_export public.routing_export_status_log public.routing_request_log public.rsd_docs public.rtv
   public.rtv_inspection_pick public.rtv_inspection_pick_request public.rtv_inspection_pick_request_detail
   public.rtv_nonfaulty_location public.rtv_quantity public.rtv_shipment public.rtv_shipment_detail
   public.rtv_shipment_detail_result public.rtv_shipment_detail_status_log public.rtv_shipment_pack
   public.rtv_shipment_pick public.rtv_shipment_status_log public.rtv_stock_process
   public.dbl_submit_token public.sample_receiver
   public.sample_request public.sample_request_cart public.sample_request_conf public.sample_request_conf_det
   public.sample_request_det public.sample_request_det_status_log public.sample_request_receiver
   public.sample_request_type_operator public.season public.season_conversion_rate public.sessions
   public.shipment public.shipment_address_log public.shipment_box public.shipment_email_log public.shipment_flag
   public.shipment_hold public.shipment_item public.shipment_item_status_log public.shipment_print_log
   public.shipment_status_log public.shipping_attribute public.stock_consistency public.stock_count
   public.stock_count_category_summary public.stock_count_summary public.stock_count_variant public.stock_order
   public.stock_order_item public.stock_process public.stock_transfer public.sub_type public.supplier
   public.variant public.variant_measurement public.world upload.list_info
   upload.transfer upload.transfer_log upload.transfer_summary web_content.content web_content.instance
   web_content.page web_content.published_log
);

=head2 C<@COLS_TO_TRUNC>

See C<_wipe_db>
I'm adding tables to clear before test as they are come across
as wiping all takes several seconds

=cut

our @COLS_TO_TRUNC = qw(
 public.classification
 public.customer
 public.designer
 public.division
 public.orders
 public.product
 public.shipping_account
 public.variant
 public.dbl_submit_token
 public.delivery
 public.world
 public.hs_code
);


# Class singletons:

=head2 get_schema

=head2 get_dbh

=cut

{
    sub get_schema {
        return XTracker::Database::schema_handle;
    }
}

{
    my $dbh;
    sub get_dbh {
        $dbh ||= XTracker::Database::get_database_handle( {
            name => 'xtracker',
            type => 'readonly'
        } )
            || LOGCONFESS "Unable to connect to DB";
        return $dbh;
    }
}


=head2 schema_table2class

Turns a C<schema.table> string into a C<Schmea::Table> string.

=cut

sub schema_table2class {
    my ($class, $subject) = @_;
    LOGCONFESS "No subject" if not defined $subject;

    # todo
    $subject =~ s/hscode/HSCode/gi;
    #      link_orders__shipment => 'LinkOrderShipment',

    my $rv = $subject;
    $rv =~ s/\./::/;
    return camelize($rv);
}


# String::CamelCase
sub camelize($) { ## no critic(ProhibitSubroutinePrototypes)
    return join('', map{ ucfirst $_ } split(/(?<=[A-Za-z])_(?=[A-Za-z])|\b/, $_[0]));
}

sub decamelize($) { ## no critic(ProhibitSubroutinePrototypes)
    my $s = shift;
    LOGCONFESS "No arg?" unless defined $s;
    $s =~ s{([^a-zA-Z]?)([A-Z]*)([A-Z])([a-z]?)}{
        my $fc = pos($s)==0;
        my ($p0,$p1,$p2,$p3) = ($1,lc$2,lc$3,$4);
        my $t = $p0 || $fc ? $p0 : '_';
        $t .= $p3 ? $p1 ? "${p1}_$p2$p3" : "$p2$p3" : "$p1$p2";
        $t;
    }ge;
    $s;
}

=head2 class2schema_table

Turn a perl class name (C<Public::Product>) into two strings (returned) usable by the DB,
schema name and table name.

=cut

sub class2schema_table {
    my ($class, $subject) = @_;
    # TRACE "Enter for ", $subject;
    my ($schema, $table) = split /::/, $subject;
    if ($schema and not $table) {
        $table = $schema;
        $schema = 'public';
    }
    $schema = lc $schema;
    $table = decamelize($table);

    # script/schema_loader.pl moniker_map:

    if ($table eq 'hscode') {
        $table = "hs_code" ;
    }
    #elsif ($table eq 'Uorders'){
    # $table = 'orders';
    #}
    elsif ($table eq 'linkordershipment') {
        $table = "link_orders__shipment";
    }

    # TRACE "Leave with $schema, $table";
    return $schema, $table;
}


=head2 reset_db

Resets the DB to a usefully blank state.

Most dynamic tables are wiped, some have to have some data in to function.

See C<__wipe_db>.

This method is called when the module is loaded, but can re-called any time.

This can become nice fixtures when it is time to create fixtures.

=cut

sub reset_db {
    TRACE "Enter";
    my $class = shift;
    my $dbh = __PACKAGE__->get_dbh;

    $class->__wipe_db;       # if $arg and $arg =~ /^:?clea[rn]_?db$/;
    $class->install_default_fixture;
    TRACE "Leave";
}



=head2 install_default_fixture

Installs a minimum set of data in otherwise dynamic tables

=cut

sub install_default_fixture {
    TRACE "Enter";
    my $class = shift;
    my $dbh = __PACKAGE__->get_dbh;
    $dbh->do($_) foreach @DEFAULT_FIXTURE;
    TRACE "Leave";
}

# Clears the database of dynamic data.  Truncates the tables listed in
# C<@COLS_TO_TRUNC>.
# See also L<reset_db>.
sub __wipe_db {
    INFO "Truncating DB tables";
    my $class = shift;
    my $dbh = $class->get_dbh;
    $dbh->do(
        'SET client_min_messages=ERROR; TRUNCATE ' . $_ . ' CASCADE',
        { PrintWarn => 0 } # useless against NOTICE:
    ) foreach @COLS_TO_TRUNC;
    INFO "Truncated DB tables";
}


=head2 wipe

Wipes any table or tables passed as arguments,
using C<TRUNCATE $table CASCADE>. Errors are fatal.

=cut

sub wipe {
    my ($class, @tables) = @_;
    my $dbh = $class->get_dbh;
    foreach my $t (@tables) {
        my $c = __PACKAGE__->schema_table2class($t);
        eval { $dbh->do("TRUNCATE $t CASCADE") };
        LOGCONFESS $@ if $@;
    }
    TRACE 'Cleared table(s): ', join ",", @tables;
}


=head2 empty_tables

Returns a list of columns which are empty when the DB inits.

Could or should rely upon C<TRUNCATED_TABLES>.

=cut

sub empty_tables {
    my $class = shift;
    my $dbh = $class->get_dbh;
    my @rv;

    # Collect empty tables:
    my $sth_tables = $dbh->table_info('%','%','%','TABLE');
    $sth_tables->execute();

    while (my $table=$sth_tables->fetchrow_hashref) {
        next if $table->{TABLE_SCHEM} =~ /^(information_schema|pg_catalog)$/;
        # Ignore logs
        next if $table->{TABLE_SCHEM} =~ /log/;

        my $table = $table->{TABLE_SCHEM} .'.'. $table->{TABLE_NAME};
        my $sql =
            my $c = $dbh->selectrow_array( 'SELECT COUNT(*) FROM ' . $table );
        # TRACE sprintf '%8d in %-s', $c, $table;
        push @rv, $table if $c == 0;
    }

    # Some tables will not be null because of base fixtures:
    push @rv, map {/^\s*INSERT\s+INTO\s+(\S+)/} @DEFAULT_FIXTURE;

    return \@rv;
}


1;
