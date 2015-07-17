package Test::XT::BlankDB;

use strict;
use warnings;

use List::MoreUtils qw(uniq);
use XTracker::Config::Local qw( iws_location_name );
use XTracker::BuildConstants;
use XTracker::Constants::FromDB qw( :flow_status :product_attribute_type );
use XTracker::Printers::Populator;

=head2 reference_tables

Returns a list of table names to use as 'reference' tables

=cut

# Get a list of the reference tables
sub reference_tables {

    my $fixture_tables_to_exclude = {
        map  { $_->[0] => 1 }
        grep { $_->[1]->{exclude_from_reference_table} }
        fixture_tables()
    };
    my @reference_tables =
        grep { ! $fixture_tables_to_exclude->{ $_ } } # Don't include some fixture tables
        uniq(
            (
                map {
                    my $name = $_->{table_name};
                    $name = 'public.' . $name unless $name =~ m/^\w+\./;
                    $name;
                } @{ XTracker::BuildConstants->new({no_connect=>1})->{'constant_data_list'} }
            ),
            (
            # tables added here will have their data copied into the blank db
            'dbadmin.applied_patch',

            'display.list_itemstate',
            'audit.action',
            'public.runtime_property',
            'system_config.config_group',
            'system_config.config_group_setting',
            'system_config.parameter',
            'system_config.parameter_type',
            'system_config.parameter_group',

            # flow.next_status required for Main Stock->Transfer Pending
            'flow.next_status',

            # Required for nav and login
            'public.operator',
            'public.role',
            'public.operator_authorisation',
            'public.operator_preferences',
            'public.authorisation_section',
            'public.authorisation_sub_section',

            'public.classification', # The type of product. Like: Handbag, Clothing
            'public.colour',         # Colours, obv
            'public.colour_filter',  # Colours, obv
            'public.filter_colour_mapping', # Colours to colours
            'public.division',              # Men, Women, Children
            'public.hs_code', # Some kind of wildlife code. The website cares about these
            'public.product_department', # Thongs? Clogs? Broooooches?
            'public.link_classification__product_type',
            'public.product_type', # Thongs? Clogs? Broooooches?
            'public.link_product_type__sub_type',
            'public.sub_type',  # Thongs? Clogs? Broooooches?
            'public.season',    # Seasons...
            'public.world', # It's a small world after all, it's a small world etc RAGE
            'public.size',  # Size
            'public.size_scheme', # Size scheme
            'public.size_scheme_variant_size', # the join table between sizes & schemes
            'public.location_type', # What kind of locations you can have
            'public.measurement',   # Types of things you can measure
            'public.product_type_measurement', # Mapping of measurements to product types
            'public.item_fault_type', # What could be wrong with it
            'public.stock_faulty_reason',
            'public.stock_count_category',

            # Dispatch Lane Routing
            'public.dispatch_lane',
            'public.dispatch_lane_offset',
            'public.link_shipment_type__dispatch_lane',

            'public.customer_class',
            'public.flag_type',
            'public.region',
            'public.season_lookup',
            'public.shipping_zone',
            'public.premier_routing',
            'public.routing_export_status',
            'public.shipping_account',
            'public.shipping_account__country',
            'public.shipping_account__postcode',
            'public.shipping_charge',
            'public.postcode_shipping_charge',
            'public.state_shipping_charge',
            'public.country_shipping_charge',
            'public.country_shipment_type', # required for creating orders generally
            'public.std_group',
            'public.country_duty_rate',
            'public.country_tax_rate',
            'public.country_tax_code',
            'public.tax_rule',
            'public.tax_rule_value',
            'public.duty_rule',
            'public.duty_rule_value',
            'public.product_type_tax_rate',
            'public.conversion_rate',
            'public.season_conversion_rate',
            'public.sales_conversion_rate',
            'public.returns_charge',
            'public.promotion_type',
            'public.promotion_class',
            'public.country_promotion_type_welcome_pack',
            'public.packaging_type',
            'public.customer_category_defaults',

            'public.box',
            'public.inner_box',

            # Currency magic
            'public.currency_glyph',
            'public.link_currency__currency_glyph',

            'product.pws_sort_adjust', # Caedite eos! Novit enim Dominus qui sunt eius!
            'product.pws_sort_variable',
            'product.pws_sort_destination',

            'public.payment_term',
            'public.payment_deposit',
            'public.payment_settlement_discount',
            'public.credit_hold_threshold',
            'public.bulk_reimbursement_status',

            # required for return refunds & charges
            'public.return_country_refund_charge',
            'public.return_sub_region_refund_charge',

            'web_content.type_field',

            # Sales Channel Branding
            'public.channel_branding',

            # Routing Schedule (CANDO-373)
            'public.routing_schedule_status',
            'public.routing_schedule_type',

            # Correspondence Subject Method Tables
            'public.correspondence_subject',
            'public.correspondence_subject_method',
            'public.csm_exclusion_calendar',

            # Reservation Source
            'public.reservation_source',
            'public.reservation_type',

            # Putaway Prep
            'public.putaway_prep_container_status',
            'public.putaway_prep_group_status',

            # Language
            'public.language',

            # Vertex area
            'public.vertex_area',

            # Fraud Hot-List
            'public.hotlist_field',
            'public.hotlist_type',

            # Localised Email Addresses
            'public.localised_email_address',

            # Pack lane data
            'public.pack_lane',

            # Promotion Type (as this has been removed
            # from the constants it needs to be populated here)
            'public.promotion_type',

            # Fraud Rules Engine tables
            'fraud.list_type',
            'fraud.method',
            'fraud.conditional_operator',
            'fraud.return_value_type',
            'fraud.link_return_value_type__conditional_operator',

            # Product shipping restrictions
            'public.ship_restriction',

            'public.language__promotion_type',
            'public.renumeration_reason',

            'public.marketing_gender_proxy',

            # For ACL Protection
            'acl.authorisation_role',
            'acl.url_path',
            'acl.link_authorisation_role__authorisation_sub_section',
            'acl.link_authorisation_role__url_path',

            # For UPS
            'public.ups_service',
            'public.ups_service_availability',

            # For SOS (Shipping Option Service)
            'sos.shipment_class',
            'sos.shipment_class_attribute',
            'sos.week_day',
            'sos.country',
            'sos.region',
            'sos.carrier',
            'sos.nominated_day_selection_time',
            'sos.processing_time',
            'sos.processing_time_override',
            'sos.truck_departure',
            'sos.truck_departure__class',
            'sos.truck_departure__day',
            'sos.wms_priority',
            'sos.channel',

            'orders.payment_method',
            'orders.third_party_payment_method_status_map',

            # For PRL
            'public.allocation_status_pack_space_allocation_time',

            # for Product Ship Restrictions (originally for LQ HAZMAT)
            'public.ship_restriction_allowed_country',
            'public.ship_restriction_exclude_postcode',
            'public.ship_restriction_allowed_shipping_charge',

            'public.shipment_item_on_sale_flag',

            'public.customer_issue_type_category',

            )
        );

    warn "Reference_tables: " . Dumper({ reference_tables => \@reference_tables, fixture_tables_to_exclude => $fixture_tables_to_exclude }); use Data::Dumper;

    return @reference_tables;
}

our @reset_sequence_tables = (
    'operator',
    'return_item_status',
);

sub set_seqval {
    my ($target,$tab,$col,$skip)=@_;
    $col||='id';
    $skip||=100;
    $target->storage->dbh_do(
        sub {
            my ($storage,$dbh)=@_;
            $dbh->do(qq|select setval('${tab}_${col}_seq',(select max($col) from $tab)+$skip)|);
        }
    );
}

sub copy_resultset {
    my ( $rs_public_name, $source, $target ) = @_;
    my $rs_name = "Public::$rs_public_name";

    my $target_prl_rs = $target->resultset($rs_name);

    my @prl_rows = $source->resultset($rs_name)->search();
    for my $prl_row (@prl_rows) {
        $target_prl_rs->create({ $prl_row->get_columns() });
    }
}

=head2 fixture_tables() : @fixture_tables

Fixture tables are loaded after reference tables. This is for table
data which isn't a straight dump from live.

E.g. locations are only a small subset of special locations, not the
usual warehouse ones.

E.g. prl can't be loaded as a reference table because it has a FK to
the location table, which isn't populated until here.

E.g. system_config.config_group which has an additional row just here.

=cut

sub fixture_tables {
    my @fixture_tables = (
        [ 'public.location', {
            create => sub {
                my ( $source, $target ) = @_;
                # Retrieve non-IWS non-normal locations
                my $locs = $source->resultset('Public::Location')->search({
                    location => {
                        -not_ilike => '0%',
                        '!=' => 'IWS',
                    },
                });

                # Recreate them in the target
                my $tl = $target->resultset('Public::Location');
                while (my $srcloc = $locs->next) {
                    my $location_id = $srcloc->id;
                    my $location = $srcloc->location;
                    warn "Creating Location ($location_id) ($location)\n";
                    my $trgloc = $tl->create({
                        id       => $location_id,
                        location => $location,
                    });
                    # Copy over the allowed statuses
                    for my $status (
                        $srcloc->location_allowed_statuses->get_column('status_id')->all
                    ) {
                        $trgloc->create_related('location_allowed_statuses',{
                            status_id => $status,
                        });
                    }
                }

                # Unbreak the location_id sequence
                set_seqval($target,'location');

                # Create the IWS location
                my $iws_loc = $target->resultset('Public::Location')->find_or_create({
                    location => iws_location_name(),
                });

                # Update its allowable statuses
                $iws_loc->delete_related('location_allowed_statuses');
                $iws_loc->create_related('location_allowed_statuses',{
                    status_id => $_,
                }) for (
                    ( $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS || 1),
                    ( $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS || 11)
                );
            },
        } ],

        [ 'public.prl', {
            create => sub {
                my ( $source, $target ) = @_;
                copy_resultset("Prl", $source, $target);
            },
            exclude_from_reference_table => 1,
        }],
        [ 'public.prl_delivery_destination', {
            create => sub {
                my ( $source, $target ) = @_;
                copy_resultset("PrlDeliveryDestination", $source, $target);
            },
            exclude_from_reference_table => 1,
        }],
        [ 'public.prl_pick_trigger_order', {
            create => sub {
                my ( $source, $target ) = @_;
                copy_resultset("PrlPickTriggerOrder", $source, $target);
            },
            exclude_from_reference_table => 1,
        }],
        [ 'public.prl_integration', {
            create => sub {
                my ( $source, $target ) = @_;
                copy_resultset("PrlIntegration", $source, $target);
            },
            exclude_from_reference_table => 1,
        }],

        [ 'public.sample_request_type', {
            create => sub {
                my ( $source, $target ) = @_;

                # Just add everything. Doing it here means the locations will
                # already exist.

                my $source_rows = $source->resultset('Public::SampleRequestType');

                # Recreate each row in the target
                my $target_rows = $target->resultset('Public::SampleRequestType');
                while ( my $source_row = $source_rows->next ) {
                    my $target_row = $target_rows->create({
                        map { ( $_ => $source_row->$_ ) } qw(
                            id
                            code
                            type
                            bookout_location_id
                            source_location_id
                        )
                    });
                }

                # Unbreak the id sequence
                set_seqval( $target, 'public.sample_request_type' );
            },
        } ],
        [ 'public.supplier', {
            create => sub {
                my ( $source, $target ) = @_;
                my $sups = $source->resultset('Public::Supplier')->search({
                    id => { -in => [0,1] },
                });
                my $ts = $target->resultset('Public::Supplier');

                while (my $srcsup = $sups->next) {
                    $ts->create({
                        id => $srcsup->id,
                        code => $srcsup->code,
                        description => $srcsup->description,
                    });
                }

                set_seqval($target,'supplier');
            },
        }],
        [ 'public.designer', {
            create => sub {
                my ( $source, $target ) = @_;
                for (
                    [1, "R\x{e9}publique \x{272a} Ceccarelli", 'ivotedforberlusconi'],
                    [2, "Cruella de Vil",                      'dalmationcreations' ],
                ) {
                    $target->resultset('Public::Designer')->create({
                        id       => $_->[0],
                        designer => $_->[1],
                        url_key  => $_->[2],
                    });
                }

                set_seqval($target,'designer');
            },
        }],
        [ 'system_config.config_group', {
            create => sub {
                my ( $source, $target ) = @_;

                $target->resultset('SystemConfig::ConfigGroup')->find_or_create({
                    name => 'Blank DB Marker',
                    active => 1,
                });
            }
        }],
        [ 'product.attribute', {
            create => sub {
                my ( $source, $target ) = @_;
                for my $attribute (
                    $source->resultset('Product::Attribute')->search({
                        attribute_type_id => $PRODUCT_ATTRIBUTE_TYPE__WHAT_APOS_S_NEW,
                    })
                ) {
                    $target->resultset('Product::Attribute')->create({
                        map { $_ => $attribute->$_ } qw( name attribute_type_id deleted synonyms manual_sort page_id channel_id )
                    });
                }
            },
        }],
    );

    return @fixture_tables;
}

=head2 check_blank_db

Attempts to check if the DB you're connected to is 'blank' or not. Looks for a
flag in system_config.config_group called 'Blank DB Marker'.

=cut

sub check_blank_db {
    my ( $target ) = @_;
    my ( $flag ) = $target->resultset('SystemConfig::ConfigGroup')->search({
        name => 'Blank DB Marker',
        active => 1,
    });
    return !! $flag;
}

=head2 create_fixtures

=head2 remove_fixtures

Create and remove fixtures using the C<%fixtures_tables> values. For create you
need to pass in a reference and target schema, for delete, just a target schema

=cut

sub create_fixtures {
    my ( $source, $target ) = @_;

    for my $fixture ( map { $_->[1]->{'create'} } fixture_tables() ) {
        eval { $fixture->( $source, $target ) };
        if ( $@ ) {
            print STDERR "***** FIXTURE CREATION FAILED\n";
            print STDERR "***** This is a pretty big deal, your blank-db will\n";
            print STDERR "***** probably be unusable as a result. The error was:\n";
            print STDERR $@;
            die "Fixture creation failed: $@";
        }
    }
    # ALWAYS populate printers so we have a known working starting config
    eval { XTracker::Printers::Populator->new(schema => $target)->populate_db; };
    if ( $@ ) {
        die "Failed to populate printers: $@";
    }

    set_seqval($target, $_) for @reset_sequence_tables;
}

=head2 non_reference_tables

Takes a list of all non-system (pg_catalog, information_schema) tables, and
removes our reference tables from them (but not fixture tables) - giving you a
list of tables that contain non-reference data. Returns a list of table names.
You must pass in a schema.

=cut

sub non_reference_tables {
    my ( $target ) = @_;

    my $stm = $target->storage->dbh->prepare(
        q!SELECT schemaname||'.'||tablename FROM
            pg_tables
        WHERE schemaname NOT IN
            ('information_schema','pg_catalog');!
    );
    $stm->execute();
    my @all_tables = map { $_->[0] } @{ $stm->fetchall_arrayref };

    my %reference_tables = map { $_ => 1 } reference_tables();
    return grep {! $reference_tables{$_}} @all_tables;
}

=head2 reset_database

Removes data from non-reference tables, having checked we're against a blank db,
and then runs the fake_fixtures.

=cut

sub reset_database {
    my ( $source, $target ) = @_;

    die "Target needs to be marked as a blank DB" unless check_blank_db( $target );

    $target->txn_do(
        sub{
            # Remove all bad old data
            $target->storage->dbh_do(
                sub {
                    my ($storage,$dbh)=@_;
                    $dbh->do('SET CONSTRAINTS ALL DEFERRED');
                    $dbh->do('TRUNCATE ' . join ',', non_reference_tables( $target ) );
                });

            # Rebuild fixtures
            create_fixtures( $source, $target );
        }
    );
}

1;
