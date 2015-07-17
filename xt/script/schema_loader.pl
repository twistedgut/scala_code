#!/opt/xt/xt-perl/bin/perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)

=head1 NAME

schema_loader.pl - generate DBIC classes from the database

=head1 SYNOPSIS

schema_loader.pl

=cut

use strict;
use warnings;

use DBIx::Class::Schema::Loader 0.07041 qw/ make_schema_at /;
use Getopt::Long;
use List::AllUtils qw(any);
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database 'xtracker_schema';

my ($override, %options);
GetOptions(
    'option=s' => \%options,
);

# Derive the dsn.
# There's probably a better way to derive this without needing to instantiate
# a schema object but I'm too lazy to put the 'which dc' logic in here
# NOTE: We may get inconsistencies here between the DC1 and DC2 schemas. We
# should see this as an opportunity to iron them out :)
my $dsn = $ARGV[0] // xtracker_schema->storage->connect_info->[0];

make_schema_at(
  "XTracker::Schema",
  {
    %options,
    dump_directory => './lib',
    use_namespaces => 1,
    qualify_objects => 1,
    moniker_parts => [qw(schema name)],
    moniker_part_separator => '::',
    components => ["InflateColumn::DateTime"],
    naming => 'v5',
    generate_pod => 0,
    omit_version => 1,
    omit_timestamp => 1,
    overwrite_modifications => 1,
    default_resultset_class => 'ResultSetBase',

    # Schemas to dump
    db_schema => [qw(acl audit dbadmin designer event flow fraud operator orders printer product public shipping sos system_config upload voucher web_content)],
    # Tables to exclude from each schema
    exclude => [
        [ qr/\Aaudit\z/ => qr/\A(?:
            action |
            event_detail |
            product |
            product_attribute |
            product_channel |
            product_department |
            promotion_customer_customergroup
          )\z/x
        ],
        [ qr/\Aproduct\z/ => qr/\Apws_(?!sort_order\z)/ ],
        [ qr/\Apublic\z/ => qr/\A(?:
            cancel_reason |
            colour_navigation |
            conversion_rate |
            currency_glyph |
            customer_category_log |
            customer_promotion |
            customer_segment(?:_log)? |
            delivery_item_fault |
            designer_rtv_(?:address|carrier) |
            dhl_outbound_tariff |
            gift_credit |
            instance |
            legacy_(?!designer_supplier).* |
            link_classification__product_type |
            link_currency__currency_glyph |
            link_product_type__sub_type |
            link_rtv__process_group |
            link_rtv__shipment |
            location_zone_to_zone_mapping |
            log_delivery_sample |
            log_location_move |
            log_order_access |
            nap_size |
            navigation_colour_mapping |
            notes_.* |
            old_.* |
            product_approval_archive |
            product_channel_transfer_status |
            product_comment |
            promotion_type_customer |
            pws_action |
            quantity_audit |
            quantity_details |
            quantity_operation_log |
            rma_request_detail_(?:status|type) |
            rma_request_note |
            rma_request_status(?:_log)? |
            routing_request_log |
            rtv |
            rtv_(?: action | address | carrier ) |
            rtv_inspection_pick(?:_request_status)? |
            rtv_nonfaulty_location |
            rtv_shipment_detail_(?: result(?:_type)? | status(?:_log)? ) |
            rtv_shipment_p[ai]ck |
            sample_request(?!_type\z).* |
            season_lookup |
            segment |
            segment_param_(?:spend|time) |
            segment_type |
            shipment_shipping_charge_change_log |
            shipping_account__postcode |
            shipping_zone |
            ship_restriction_location |
            stock_action |
            stock_count |
            stock_count_(?:origin|status|(?:category_)?summary) |
            stock_faulty_reason |
            system_to_english_errors |
            upload_status |
            variant_type |
            super_variant |
            vw_.*
          )\z/x
        ],
        [ qr/\Aupload\z/ =>  qr/\A(?:
            transfer_(?:log(?:_action)?|summary) |
            vw_transfers
          )\z/x
        ],
        [ qr/\Avoucher\z/ =>  qr/\A(?:
            old_.*
          )\z/x
        ],
    ],
    # Override the default naming for some tables. Most will get it right
    moniker_map => sub {
        my ($table, $default, $orig) = @_;

        if ($table->schema eq 'event') {
            my $new = $default;
            $new =~ s/Customergroup((?:join)?)/CustomerGroup\u$1/g;
            $new =~ s/Listtype/ListType/g;
            return $new if $new ne $default;
        }

        return $orig->({
            acl => {
                url_path => 'ACL::URLPath',
                link_authorisation_role__url_path => 'ACL::LinkAuthorisationRoleURLPath',
            },
            event => {
                detail_products => 'Promotion::DetailProducts',
                detail_producttypes => 'Promotion::DetailProductTypes',
                detail_designers => 'Promotion::DetailDesigners',
                detail_seasons => 'Promotion::DetailSeasons',
                detail_shippingoptions => 'Promotion::DetailShippingOptions',
                detail_websites => 'Promotion::DetailWebsites',
            },
            public => {
                orders => 'Public::Orders',
                link_orders__shipment => 'Public::LinkOrderShipment',
                hs_code => 'Public::HSCode',
                dhl_delivery_file => 'Public::DHLDeliveryFile',
                sessions => 'Public::Sessions',
                purchase_orders_not_editable_in_fulcrum => 'Public::PurchaseOrderNotEditableInFulcrum',
                rtv_inspection_pick_request => 'Public::RTVInspectionPickRequest',
                rtv_inspection_pick_request_detail => 'Public::RTVInspectionPickRequestDetail',
                rtv_quantity => 'Public::RTVQuantity',
                rtv_shipment => 'Public::RTVShipment',
                rtv_shipment_detail => 'Public::RTVShipmentDetail',
                rtv_shipment_status => 'Public::RTVShipmentStatus',
                rtv_shipment_status_log => 'Public::RTVShipmentStatusLog',
            },
            product => {
                pws_sort_order => 'Product::PWSSortOrder',
            },
        });
    },
    # Unless the whole name is mapped explicitly above,
    # individual parts can be overriden here
    moniker_part_map => {
        schema => {
            acl => 'ACL',
            sos => 'SOS',
            dbadmin => 'DBAdmin',
            event => 'Promotion',
        },
    },
    relationship_attrs => sub {
        my %param = @_;
        return { order_by => 'shipment.date' }
            if $param{rel_type} eq 'many_to_many' &&
               $param{local_source}->source_name eq 'Public::Orders' &&
               $param{remote_source}->source_name eq 'Public::Shipment';

        return { %{$param{attrs}}, join_type => 'LEFT' }
            if $param{local_source}->source_name eq 'Public::OperatorPreference' &&
               $param{rel_type} eq 'belongs_to' &&
               $param{rel_name} eq 'operator';

        # Schema::Loader doesn't do has_one, so explictly set INNER on
        # the might_haves instead, which is equivalent
        return { %{$param{attrs}}, join_type => 'INNER' },
            if $param{local_source}->source_name eq 'Public::Product' &&
               $param{rel_type} eq 'might_have' &&
               any { $param{rel_name} eq $_ }
                   qw(price_default price_purchase pws_sort_order shipping_attribute);

        return { %{$param{attrs}}, join_type => 'INNER' },
            if $param{local_source}->source_name eq 'Voucher::Product' &&
               $param{rel_type} eq 'might_have' &&
               $param{rel_name} eq 'variant';

        return { %{$param{attrs}},  order_by => { -asc => 'id' } }
            if $param{local_source}->source_name eq 'Public::Product' &&
               $param{rel_type} eq 'has_many' &&
               $param{rel_name} eq 'external_image_urls';

        return;
    },
    rel_name_map => sub {
        my ($info, $orig) = @_;
        return 'purchase_orders'
            if $info->{type} eq 'has_many' &&
               $info->{name} eq 'purchase_orders' &&
               $info->{remote_moniker} eq 'Public::PurchaseOrder';

        return 'voucher_purchase_orders'
            if $info->{type} eq 'has_many' &&
               $info->{name} eq 'purchase_orders' &&
               $info->{remote_moniker} eq 'Voucher::PurchaseOrder';

        if ($info->{type} eq 'has_many' &&
            $info->{local_moniker} !~ /\APromotion::/ &&
            $info->{remote_moniker} =~ /\APromotion::Detail(?:\w+s)?\z/
        ) {
            my $name = $info->{name} =~ s/_((?:last_)?modified|created)_bies\z/s_$1/r;
            return "promotion_$name";
        }

        if ($info->{type} eq 'has_many' &&
            $info->{name} eq 'detail_products' &&
            $info->{remote_moniker} =~ /\APromotion::DetailProduct(s?)\z/
        ) {
            my $name = "detail_product$1";
            return ($info->{local_moniker} =~ /\APromotion::/ ? '' : 'promotion_' ) . $name;
        }

        # ProductVisibility didn't use to be in the schema, avoid
        # clobbering the column accessors with related objects
        return "$info->{name}_obj"
            if $info->{type} eq 'belongs_to' &&
               $info->{remote_moniker} eq 'Promotion::ProductVisibility' &&
               $info->{name} =~ /_visibility\z/ &&
               $info->{local_columns}->[0] =~ /_visibility\z/;

        return 'detail'
            if $info->{name} eq 'event' &&
               $info->{local_moniker} =~ /\APromotion::Detail\w+/;

        return $orig->({
            'Designer::Attribute' => {
                attribute_type => 'type',
                attribute_values => 'designer_attribute',
            },
            'Designer::AttributeType' => {
                attributes => 'attribute',
            },
            'Designer::LogWebsiteState' => {
                from_value => 'from_state',
                to_value => 'to_state',
            },
            'Designer::WebsiteState' => {
                log_website_state_from_values => 'logs_from_state',
                log_website_state_to_values => 'logs_to_state',
            },
            'Flow::Status' => {
                next_status_current_status_ids => "next_status",
                next_status_next_status_ids => "prev_status",
                current_statuses => "list_prev_status",
                next_statuses => "list_next_status",
            },
            'Fraud::OrdersRuleOutcome' => {
                order => 'orders',
            },
            'Orders::LogPaymentPreauthCancellation' => {
                orders_payment => 'payment',
            },
            'Orders::Payment' => {
                order => 'orders',
            },
            'Orders::ReplacedPayment' => {
                order  => 'orders',
            },
            'Orders::Tender' => {
                voucher_code => 'voucher_instance',
            },
            'Public::AuthorisationSection' => {
                authorisation_sub_sections => 'sub_section',
            },
            'Public::AuthorisationSubSection' => {
                authorisation_roles => 'acl_roles',
                authorisation_section => 'section',
            },
            'Orders::LogPaymentPreauthCancellation' => {
                orders_payment => 'payment',
            },
            'Orders::Payment' => {
                order => 'orders',
            },
            'Orders::Tender' => {
                voucher_code => 'voucher_instance',
            },
            'Promotion::Coupon' => {
                event => 'promotion_detail',
            },
            'Promotion::CustomerCustomerGroup' => {
                created_by => 'created',
                modified_by => 'modified',
            },
            'Promotion::CustomerGroup' => {
                customer_customergroups => 'customers',
                detail_customergroups => 'detail_promotions',
            },
            'Promotion::Detail' => {
                detail_customergroupjoin_listtypes => 'detail_customergroup_joins',
            },
            'Promotion::DetailCustomerGroupJoinListType' => {
                customergroup_listtype => 'listtype',
            },
            'Promotion::DetailShippingOptions' => {
                shippingoption => 'shipping_option',
            },
            'Product::Attribute' => {
                attribute_type => 'type',
                attribute_values => 'product_attribute',
            },
            'Product::AttributeType' => {
                attributes => 'attribute',
            },
            'Product::NavigationTree' => {
                parent => 'parent_tree',
                navigation_trees => 'child_trees',
            },
            'Product::NavigationTreeLock' => {
                navigation_tree => 'tree',
            },
            'Public::CardRefund' => {
                invoice => 'renumeration',
            },
            'Public::CustomerIssueType' => {
                group => 'customer_issue_type_group',
            },
            'Public::Channel' => {
                staging_rules => 'fraud_staging_rules',
                archived_rules => 'fraud_archived_rules',
                live_rules => 'fraud_live_rules',
                products => 'voucher_products',
            },
            'Public::Currency' => {
                products => 'voucher_products',
            },
            'Public::DeliveryNote' => {
                created_by => 'creator',
                modified_by => 'modifier',
            },
            'Public::LinkOrderShipment' => {
                order => 'orders',
            },
            'Public::Location' => {
                statuses => 'allowed_statuses',
            },
            'Public::LogDesignerDescription' => {
                designer => 'designer_id',
            },
            'Public::OperatorAuthorisation' => {
                authorisation_level => 'auth_level',
                authorisation_sub_section => 'auth_sub_section',
            },
            'Public::OperatorPreference' => {
                default_home_page => 'default_home_page_sub_section',
            },
            'Public::Operator' => {
                archived_condition_created_by_operator_ids => 'fraud_archived_conditions_created',
                archived_condition_expired_by_operator_ids => 'fraud_archived_conditions_expired',
                archived_list_created_by_operator_ids => 'fraud_archived_lists_created',
                archived_list_expired_by_operator_ids => 'fraud_archived_lists_expired',
                archived_rule_created_by_operator_ids => 'fraud_archived_rules_created',
                archived_rule_expired_by_operator_ids => 'fraud_archived_rules_expired',
                change_logs => 'fraud_change_logs',
                pre_order_applied_discount_operator_ids => 'pre_order_applied_discounts',
                pre_order_operator_ids => 'pre_orders',
                pre_order_operator_log_operator_ids => 'pre_order_operator_log_operator',
                pre_order_operator_log_from_operator_ids => 'pre_order_operator_log_from_operator',
                pre_order_operator_log_to_operator_ids => 'pre_order_operator_log_to_operator',
                reservation_operator_log_operator_ids => 'reservation_operator_log_operator',
                reservation_operator_log_from_operator_ids => 'reservation_operator_log_from_operator',
                reservation_operator_log_to_operator_ids => 'reservation_operator_log_to_operator',
                delivery_note_created_bies => 'delivery_notes_created',
                delivery_note_modified_bies => 'delivery_notes_modified',
                instance_created_bies => 'web_content_instances_created',
                instance_last_updated_bies => 'web_content_instances_last_updated',
                shipping_attribute_operator_ids => 'shipping_attributes',
                shipping_attribute_packing_note_operator_ids => 'shipping_attribute_packing_notes',
                products => 'voucher_products',
                customer_customergroup_created_bies => 'promotion_customer_customergroups_created',
                customer_customergroup_modified_bies => 'promotion_customer_customergroups_modified',
                recents => 'recent_audits',
                log_back_fill_job_runs => 'dbadmin_log_back_fill_job_runs',
                log_back_fill_job_statuses => 'dbadmin_log_back_fill_job_statuses',
            },
            'Public::OrderStatus' => {
                staging_rules => 'fraud_staging_rules',
                archived_rules => 'fraud_archived_rules',
                live_rules => 'fraud_live_rules',
            },
            'Public::OrderStatusLog' => {
                order_status => 'status',
            },
            'Public::PackLane' => {
                pack_lane_has_attributes => 'pack_lanes_has_attributes',
                attributes => 'assigned_attributes',
            },
            'Public::PackLaneAttribute' => {
                pack_lane_has_attributes => 'pack_lanes_has_attributes',
            },
            'Public::PackLaneHasAttribute' => {
                pack_lane_attribute => 'attribute',
            },
            'Public::Product' => {
                attribute_values => 'attribute_value',
                price_regions => 'price_region',
                price_countries => 'price_country',
                product_attribute => 'attribute',
                product_channels => 'product_channel',
                stock_orders => 'stock_order',
                stock_summaries => 'stock_summary',
                recommended_product_product_ids => 'recommended_master_products',
                recommended_product_recommended_product_ids => 'recommended_products',
            },
            'Public::PutawayPrepContainer' => {
                user => 'operator',
            },
            'Public::ReturnItem' => {
                return_type => 'type',
                return_item_status => 'status',
            },
            'Public::ReturnItemStatusLog' => {
                return_item_status => 'status',
            },
            'Public::RTVInspectionPickRequest' => {
                rtv_inspection_pick_request_details => 'details',
            },
            'Public::RTVQuantity' => {
                fault_type => 'item_fault_type',
            },
            'Public::Shipment' => {
                shipping_charge => 'shipping_charge_table',
            },
            'Public::ShipmentStatusLog' => {
                shipment_status => 'status',
            },
            'Public::ShippingCharge' => {
                class => 'shipping_charge_class',
                description => 'shipping_description',
            },
            'Public::ShippingChargeClass' => {
                shipping_charge_classes => 'upgradable_from',
                upgrade => 'upgradable_to',
            },
            'Public::StockOrder' => {
                product => 'public_product',
            },
            'Public::StockOrderItem' => {
                codes => 'voucher_codes',
            },
            'Voucher::CreditLog' => {
                spent_on_shipment => 'shipment',
            },
            'Voucher::Variant' => {
                voucher_product => 'product',
            },
            'WebContent::Instance' => {
                created_by => 'operator_created',
                last_updated_by => 'operator_updated',
            },
        });
    },
    result_components_map => {
        # Load specific components for specific results
        'Public::Carrier' => [ 'InflateColumn::Time' ],
        "SOS::NominatedDaySelectionTime" => ["InflateColumn::Time"],
        "SOS::ProcessingTime" => ["InflateColumn::Interval"],
        "SOS::TruckDeparture" => ["InflateColumn::Time"],
        "SOS::TruckDepartureException" => ["InflateColumn::Time"],
        "SOS::WmsPriority" => ["InflateColumn::Interval"],
    },
  },
  [  $dsn, "postgres", "www" ]
);
