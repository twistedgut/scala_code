package XTracker::Comms::DataTransfer;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Data::Dump "pp";
use Data::Printer;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

use Perl6::Export::Attrs;
use Encode                              qw(encode decode);
use XTracker::DBEncode                  qw(decode_it);
use Hash::Util                          qw(lock_hash);
use Readonly;
use Storable                            qw(dclone);

use XTracker::Config::Local             qw( config_var config_section_slurp use_optimised_upload );

use XTracker::Constants                 qw($PG_MAX_INT);
use XTracker::Constants::FromDB qw(
    :department
    :flow_status
    :pre_order_item_status
    :pws_action
    :reservation_status
    :shipment_item_status
    :upload_transfer_log_action
    :upload_transfer_status
    :variant_type
);

use XTracker::Database                  qw(get_database_handle get_schema_using_dbh schema_handle);
use XTracker::Database::Channel         'get_channel';
use XTracker::Database::Product         qw(get_product_id product_present);
use XTracker::Database::Reservation     qw(log_reservation update_reservation_status update_reservation_upload_date update_reservation_expiry_date upload_reservation);
use XTracker::Database::StockTransfer;
use XTracker::Database::Utilities       qw(last_insert_id results_list);
use XTracker::Logfile                   qw(xt_logger);
use XTracker::Stock::Measurement::Edit;
use XTracker::Upload::Transfer::Log;
use XTracker::Utilities                 qw(:string);
use XTracker::Markup;
use Try::Tiny;
use XTracker::Role::WithAMQMessageFactory;


################################################################################
# Constants
################################################################################

Readonly my $INPUT_ENCODING     => 'UTF-8';
Readonly my $OUTPUT_ENCODING    => 'iso-8859-1';

## location of the upload transfer script (initiated from within xT)
Readonly my $XT_PATH                            => config_var('SystemPaths','xtdc_base_dir').'/lib/XTracker';
Readonly my $UPLOAD_TRANSFER_SCRIPT_PATH        => "$XT_PATH/Upload/Actions/upload_transfer.pl";
Readonly my $SORT_PREVIEW_TRANSFER_SCRIPT_PATH  => "$XT_PATH/Admin/Actions/sort_preview_transfer.pl";

## conversion rate from centimetres to inches
Readonly my $INCHES_CONVERSION  => 0.3937;


Readonly my $DEFAULT_SQL_ACTION_EXECUTE     => 1;
## Transfer category attributes:-
## write_permitted      - list of sink tables for which writes will be allowed
## default_sql_action   - sql actions permitted by default for the specified transfer category
my %TRANSFER_CATEGORY_ATTRIBUTE = (
    catalogue_product => {
        write_permitted     => ['searchable_product'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    catalogue_attribute => {
        write_permitted     => ['attribute_value'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    navigation_attribute => {
        write_permitted     => ['attribute_value'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    list_attribute => {
        write_permitted     => ['attribute_value'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 1, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    navigation_category => {
        write_permitted     => ['_navigation_category'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 1, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    navigation_tree => {
        write_permitted     => ['_navigation_tree'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 1, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    designer => {
        write_permitted     => ['designer'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    designer_attribute_type => {
        write_permitted     => ['designer_attribute'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    designer_attribute_value => {
        write_permitted     => ['designer_attribute_value'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 1, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    catalogue_sku => {
        write_permitted     => ['product'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    catalogue_pricing => {
        write_permitted     => ['channel_pricing'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    catalogue_markdown => {
        write_permitted     => ['price_adjustment'],
        default_sql_action  => {'update' => 1, 'insert' => 1, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    catalogue_ship_restriction => {
        write_permitted     => ['shipping_restriction'],
        default_sql_action  => {'update' => 1, 'insert' => 1, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    saleable_inventory => {
        write_permitted     => ['stock_location'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    product_sort => {
        write_permitted     => ['searchable_product'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    related_product => {
        write_permitted     => ['related_product'],
        default_sql_action  => {'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    web_cms_page => {
        write_permitted     => ['page'],
        default_sql_action  => {'update' => 1, 'insert' => 1, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    web_cms_page_instance => {
        write_permitted     => ['page_instance'],
        default_sql_action  => {'update' => 1, 'insert' => 1, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
    web_cms_page_content => {
        write_permitted     => ['page_content'],
        default_sql_action  => {'update' => 1, 'insert' => 1, 'delete' => 0, 'execute' => $DEFAULT_SQL_ACTION_EXECUTE},
    },
);
lock_hash(%TRANSFER_CATEGORY_ATTRIBUTE);

my %ATTRIBUTE = (
    catalogue   => ['WORLD', 'DIVISION', 'CLASSIFICATION', 'PRODUCT_TYPE', 'SUB_TYPE', 'DESIGNER', 'SEASON', 'SIZE_CHART_CM', 'SIZE_CHART_INCHES', 'COLOUR', 'SALE'],
    navigation  => ['NAV_LEVEL1', 'NAV_LEVEL2'],
    # EN-1587: this list used to have 'NAV_LEVEL3', but we removed that to
    # stop uploading of the navigation.
    list        => ['CUSTOM_LIST', 'WHATS_NEW', 'WHATS_HOT', 'SLUG_IMAGE'],
);
lock_hash(%ATTRIBUTE);

my %FORMAT_REGEXP = (
    transfer_category       => qr{\A(?:@{[join('|', keys %TRANSFER_CATEGORY_ATTRIBUTE)]})\z}xms,
    environment             => qr{\A(?:live|staging)\z}xms,
    empty_or_whitespace     => qr{\A\s*\z}xms,
    int_positive            => qr{\A[1-9]\d*\z}xms,
    id                      => qr{\A\d+\z}xms,
    date                    => qr{\A\d{4}-\d{2}-\d{2}\z}xms,
    sku                     => qr{\A(\d+)-(\d{3,})\z}xms,
    db_object_name          => qr{\A\w{1,31}\z}xmsi,
    db_key_value            => qr{\A[\w\-]+\z}xms,
    catalogue_attribute     => qr{\A(?:@{[ join('|', @{$ATTRIBUTE{catalogue}}) ]})\z}xms,
    navigation_attribute    => qr{\A(?:@{[ join('|', @{$ATTRIBUTE{navigation}}) ]})\z}xms,
    list_attribute          => qr{\A(?:@{[ join('|', @{$ATTRIBUTE{list}}) ]})\z}xms,
);
lock_hash(%FORMAT_REGEXP);

#--------------------------------------
# Database handle lookup (source/sink)
#--------------------------------------
my %DBH_LOOKUP = %{ config_section_slurp( 'pws_data_transfer' ) };
#lock_hash(%DBH_LOOKUP);

#--------------------
# Data Sink Mappings
#--------------------
Readonly my $AUDIT_APPLICATION          => 'XTRACKER';  ## written to audit fields such as 'created_by' and 'last_updated_by'
Readonly my %audit_insert_values        => ( created_by => $AUDIT_APPLICATION, created_dts => '[% CURRENT_DATETIME %]' );
Readonly my %audit_update_values        => ( last_updated_by => $AUDIT_APPLICATION );

my %DATA_SINK_MAP = (
    catalogue_product => {
        searchable_product => {
            key_field_map => {
                key_fields => {
                    product_id  => 'id',
                },
            },
            data_field_map => {
                product_id          => [ ['id'] ],
                short_description   => [ ['short_description'] ],
                long_description    => [ ['long_description'] ],
                name                => [ ['title'] ],
                keywords            => [ ['keywords'] ],
                editors_comments    => [ ['notes01'] ],
                size_fit            => [ ['notes02'] ],
                related_facts       => [ ['notes03'] ],
                sort_order          => [ ['sort_order'] ],
                season_id           => [ ['season'] ],
                product_type_id     => [ ['product_type'] ],
                designer_id         => [ ['designer_id'] ],
                visible             => [ ['is_visible'] ],
                canonical_product_id => [ ['canonical_product_id'] ],
                style_number        =>  [ ['style_number'] ],
            },
            audit_insert_values => \%audit_insert_values,
            audit_update_values => \%audit_update_values,
        },
    },
    catalogue_attribute => {
        attribute_value => {
            key_field_map => {
                key_fields => {
                    product_id      => 'search_prd_id',
                    attribute_id    => 'pa_id',
                },
            },
            data_field_map => {
                product_id      => [ ['search_prd_id'] ],
                attribute_id    => [ ['pa_id'] ],
                attribute_value => [ ['value'] ],
            },
        },
    },
    navigation_attribute => {
        attribute_value => {
            key_field_map => {
                key_fields => {
                    product_id      => 'search_prd_id',
                    attribute_id    => 'pa_id',
                },
            },
            data_field_map => {
                product_id      => [ ['search_prd_id'] ],
                attribute_id    => [ ['pa_id'] ],
                attribute_value => [ ['value'] ],
            },
        },
    },
    list_attribute => {
        attribute_value => {
            key_field_map => {
                key_fields => {
                    product_id      => 'search_prd_id',
                    attribute_id    => 'pa_id',
                    attribute_value => 'value',
                },
                updateable_key_fields => ['attribute_value'],
            },
            data_field_map => {
                product_id      => [ ['search_prd_id'] ],
                attribute_id    => [ ['pa_id'] ],
                attribute_value => [ ['value'] ],
                sort_order      => [ ['sort_order'] ],
            },
        },
    },
    catalogue_sku => {
        product => {
            key_field_map => {
                key_fields => {
                    sku => 'sku',
                },
            },
            data_field_map => {
                sku                 => [ ['sku'] ],
                product_id          => [ ['search_prod_id'] ],
                std_size_id         => [ ['standardised_size_id'] ],
                short_description   => [ ['short_description', 'public_short_description'] ],
                long_description    => [ ['long_description', 'public_long_description'] ],
                name                => [ ['name', 'title', 'public_name', 'public_title'] ],
                editors_comments    => [ ['notes01'] ],
                size_fit            => [ ['notes02'] ],
                related_facts       => [ ['notes03'] ],
                colour              => [ ['colour'] ],
                designer            => [ ['manufacturer'] ],
                product_type_id     => [ ['vat_code'] ],
                size                => [ ['size'] ],
                hs_code             => [ ['hs_code'] ],
                stock_ordered       => [ ['is_visible'] ],
            },
            audit_insert_values => \%audit_insert_values,
            audit_update_values => \%audit_update_values,
        },
    },
    catalogue_pricing => {
        channel_pricing => {
            key_field_map => {
                key_fields => {
                    id          => 'id',
                    sku         => 'sku',
                    locality    => 'locality',
                },
            },
            data_field_map => {
                id              => [ ['id'] ],
                sku             => [ ['sku'] ],
                price           => [ ['offer_price'] ],
                locality        => [ ['locality'] ],
                locality_type   => [ ['locality_type'] ],
                currency        => [ ['currency'] ],
                is_visible      => [ ['is_visible'] ],
            },
            audit_insert_values => \%audit_insert_values,
            audit_update_values => \%audit_update_values,
        },
    },
    catalogue_markdown => {
        price_adjustment => {
            key_field_map => {
                key_fields => {
                    sku         => 'sku',
                    date_start  => 'start_date',
                },
            },
            data_field_map => {
                sku             => [ ['sku'] ],
                percentage      => [ ['percentage'] ],
                date_start      => [ ['start_date'] ],
                date_finish     => [ ['end_date'] ],
                adjustment_type => [ ['adjustment_type'] ],
            },
        },
    },
    catalogue_ship_restriction => {
        shipping_restriction => {
            key_field_map => {
                key_fields => {
                    product_id          => 'pid',
                    restriction_code    => 'restriction_code',
                    location            => 'location',
                    location_type       => 'location_type',
                },
            },
            data_field_map => {
                product_id          => [ ['pid'] ],
                restriction_code    => [ ['restriction_code'] ],
                location            => [ ['location'] ],
                location_type       => [ ['location_type'] ],
            },
        },
    },
    saleable_inventory => {
        stock_location => {
            key_field_map => {
                key_fields => {
                    id  => 'id',
                    sku => 'sku',
                },
            },
            data_field_map => {
                id              => [ ['id'] ],
                sku             => [ ['sku'] ],
                quantity        => [ ['no_in_stock'] ],
                is_sellable     => [ ['is_sellable'] ],
            },
            audit_insert_values => \%audit_insert_values,
            audit_update_values => \%audit_update_values,
        },
    },
    product_sort => {
        searchable_product => {
            key_field_map => {
                key_fields => {
                    product_id  => 'id',
                },
            },
            data_field_map => {
                product_id          => [ ['id'] ],
                sort_order          => [ ['sort_order'] ],
            },
            audit_update_values => { last_updated_by => $AUDIT_APPLICATION . '_SORT' },
        },
    },
    related_product => {
        related_product => {
            key_field_map => {
                key_fields => {
                    product_id          => 'search_prod_id',
                    related_product_id  => 'related_prod_id',
                    type                => 'type_id',
                },
            },
            data_field_map => {
                product_id          => [ ['search_prod_id'] ],
                related_product_id  => [ ['related_prod_id'] ],
                type                => [ ['type_id'] ],
                sort_order          => [ ['sort_order'] ],
                slot                => [ ['position'] ],
            },
            audit_insert_values => \%audit_insert_values,
            audit_update_values => \%audit_update_values,
        },
    },
    navigation_category => {
        _navigation_category => {
            key_field_map => {
                key_fields => {
                    navigation_category_id  => 'id',
                },
            },
            data_field_map => {
                navigation_category_id  => [ ['id'] ],
                navigation_category     => [ ['name'] ],
                synonyms                => [ ['synonyms'] ],
                type_id                 => [ ['type_id'] ],
            },
        },
    },
    navigation_tree => {
        _navigation_tree => {
            key_field_map => {
                key_fields => {
                    node_id => 'id',
                },
            },
            data_field_map => {
                node_id                 => [ ['id'] ],
                parent_id               => [ ['parent_id'] ],
                category_id             => [ ['category_id'] ],
                type_id                 => [ ['type_id'] ],
                sort_order              => [ ['sort'] ],
                is_visible              => [ ['visibility'] ],
                feature_product_id      => [ ['feature_product_id'] ],
                feature_product_image   => [ ['feature_product_image'] ],
            },
        },
    },
    designer => {
        designer => {
            key_field_map => {
                key_fields => {
                    designer_id => 'id',
                },
            },
            data_field_map => {
                designer_id => [ ['id'] ],
                name        => [ ['name'] ],
                page_id     => [ ['page_id'] ],
                state       => [ ['state'] ],
                url_key     => [ ['url_key'] ],
                description => [ ['description' ] ],
            },
        },
    },
    designer_attribute_type => {
        designer_attribute => {
            key_field_map => {
                key_fields => {
                    web_attribute  => 'id',
                },
            },
            data_field_map => {
                web_attribute       => [ ['id', 'name'] ],
                description         => [ ['description'] ],
                type                => [ ['type'] ],
                version             => [ ['version'] ],
                sort_order          => [ ['sort_order'] ],
            },
            audit_insert_values => \%audit_insert_values,
            audit_update_values => \%audit_update_values,
        },
    },
    designer_attribute_value => {
        designer_attribute_value => {
            key_field_map => {
                key_fields => {
                    designer_id     => 'designer_id',
                    attribute_id    => 'da_id',
                    attribute_value => 'value',
                },
                updateable_key_fields => ['attribute_value'],
            },
            data_field_map => {
                designer_id     => [ ['designer_id'] ],
                attribute_id    => [ ['da_id'] ],
                attribute_value => [ ['value'] ],
                sku             => [ ['sku'] ],
                retailer_id     => [ ['retailer_id'] ],
                sort_order      => [ ['sort_order'] ],
            },
        },
    },
    web_cms_page => {
        page => {
            key_field_map => {
                key_fields => {
                    id  => 'id',
                },
            },
            data_field_map => {
                id          => [ ['id'] ],
                name        => [ ['name'] ],
                type_id     => [ ['page_type_id'] ],
                template_id => [ ['template_id'] ],
                page_key    => [ ['page_key'] ],
                channel     => [ ['channel'] ]
            },
        },
    },
    web_cms_page_instance => {
        page_instance => {
            key_field_map => {
                key_fields => {
                    id  => 'id',
                },
            },
            data_field_map => {
                id              => [ ['id'] ],
                page_id         => [ ['page_id'] ],
                label           => [ ['label'] ],
                status          => [ ['status'] ],
                preview_hash    => [ ['preview_hash'] ],
                created         => [ ['created_dts'] ],
                created_by      => [ ['created_by'] ],
                last_updated    => [ ['last_updated_dts'] ],
                last_updated_by => [ ['last_updated_by'] ],
            },
        },
    },
    web_cms_page_content => {
        page_content => {
            key_field_map => {
                key_fields => {
                    instance_id => 'page_instance_id',
                    field_id    => 'field_id',
                },
            },
            data_field_map => {
                instance_id             => [ ['page_instance_id'] ],
                field_id                => [ ['field_id'] ],
                content                 => [ ['content'] ],
                category_id             => [ ['category_id'] ],
                searchable_product_id   => [ ['searchable_product_id'] ],
                page_snippet_id         => [ ['page_snippet_id'] ],
            },
        },
    },
);
lock_hash(%DATA_SINK_MAP);

#--------------------
# Log Actions
#--------------------
my %LOG_ACTION_MAP = (
    catalogue_product           => $UPLOAD_TRANSFER_LOG_ACTION__PRODUCT_DATA,
    catalogue_attribute         => $UPLOAD_TRANSFER_LOG_ACTION__PRODUCT_ATTRIBUTES,
    navigation_attribute        => $UPLOAD_TRANSFER_LOG_ACTION__NAVIGATION_ATTRIBUTES,
    list_attribute              => $UPLOAD_TRANSFER_LOG_ACTION__LIST_ATTRIBUTES,
    catalogue_sku               => $UPLOAD_TRANSFER_LOG_ACTION__PRODUCT_SKUS,
    catalogue_pricing           => $UPLOAD_TRANSFER_LOG_ACTION__PRODUCT_PRICING,
    catalogue_markdown          => $UPLOAD_TRANSFER_LOG_ACTION__PRODUCT_MARKDOWN,
    related_product             => $UPLOAD_TRANSFER_LOG_ACTION__RELATED_PRODUCTS,
    saleable_inventory          => $UPLOAD_TRANSFER_LOG_ACTION__PRODUCT_INVENTORY,
    product_reservations        => $UPLOAD_TRANSFER_LOG_ACTION__PRODUCT_RESERVATIONS,
);
lock_hash(%LOG_ACTION_MAP);

#------------------------
# xT Form Field Mappings
#------------------------
my %XT_FORMFIELD_MAP = (
    editorial => {
        name => {
            catalogue_product   => 'name',
            catalogue_sku       => 'name'
        },
        keywords => {
            catalogue_product   => 'keywords',
        },
        short_description => {
            catalogue_product   => 'short_description',
            catalogue_sku       => 'short_description',
        },
        long_description => {
            catalogue_product   => 'long_description',
            catalogue_sku       => 'long_description',
        },
        editors_comments => {
            catalogue_product   => 'editors_comments',
            catalogue_sku       => 'editors_comments',
        },
        size_fit => {
            catalogue_product   => 'size_fit',
            catalogue_sku       => 'size_fit',
        },
    },
    pws_details => {
        keywords => {
            catalogue_product   => 'keywords',
        },
    },
    classification => {
        world => {
            catalogue_attribute => 'WORLD',
        },
        designer => {
            catalogue_attribute => 'DESIGNER',
            catalogue_sku       => 'designer',
        },
        division => {
            catalogue_attribute => 'DIVISION',
        },
        classification => {
            catalogue_attribute => 'CLASSIFICATION',
        },
        product_type => {
            catalogue_attribute => 'PRODUCT_TYPE',
        },
        sub_type => {
            catalogue_attribute => 'SUB_TYPE',
        },
        season => {
            catalogue_attribute => 'SEASON',
        },
        colour => {
            catalogue_attribute => 'COLOUR',
            catalogue_sku       => 'colour',
        },
    },
    shipping_details => {
        hs_code => {
            catalogue_sku       => 'hs_code',
        },
    },
);
lock_hash(%XT_FORMFIELD_MAP);


################################################################################
# Logging
################################################################################
my $logger  = xt_logger(__PACKAGE__);
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


################################################################################
# Upload process
################################################################################

# set use_optimized_upload as a global variable
my $optimized_upload_config_per_channel;
sub init_optimized_upload {
    my ($dbh,$channel_id) = @_;
    my $business_shortname = get_channel($dbh,$channel_id)->{config_section};
    $optimized_upload_config_per_channel->{$channel_id} = use_optimised_upload($business_shortname);
    $logger->info("Using optimized upload for $business_shortname: ".($optimized_upload_config_per_channel->{$channel_id} ? "Yes" : "No"));
    return $optimized_upload_config_per_channel->{$channel_id};
}

sub get_transfer_log_actions :Export(:upload_transfer) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};

    my $qry = q{SELECT id, log_action FROM upload.transfer_log_action ORDER BY id};
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my ($id, $log_action);

    $sth->bind_columns(\($id, $log_action));

    my $log_actions_ref;
    while ( $sth->fetch() ) {
        $log_actions_ref->{$id} = $log_action;
    }

    return $log_actions_ref;

} ## END sub get_transfer_log_actions



sub initiate_upload_transfer :Export(:upload_transfer) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $transfer_id = $arg_ref->{transfer_id};

    $logger->logcroak("Invalid transfer_id ($transfer_id)") if $transfer_id !~ $FORMAT_REGEXP{id};

    my $transfer_ref
        = get_upload_transfers( { dbh => $dbh, select_by => { fname => 'id', value => $transfer_id } } );

    my $upload_id   = $transfer_ref->[0]{upload_id};
    my $operator_id = $transfer_ref->[0]{operator_id};
    my $source      = $transfer_ref->[0]{source};
    my $sink        = $transfer_ref->[0]{sink};
    my $environment = $transfer_ref->[0]{environment};

    my $arg_error = '';
    $arg_error  .= "Invalid upload_id ($upload_id)\n" if $upload_id !~ $FORMAT_REGEXP{id};
    $arg_error  .= "Invalid operator_id ($operator_id)\n" if $operator_id !~ $FORMAT_REGEXP{id};
    $arg_error  .= "Invalid source ($source)\n" unless is_valid_region( $source, 'xt_'  );
    $arg_error  .= "Invalid sink ($sink)\n" unless is_valid_region( $sink,   'pws_' );
    $arg_error  .= "Invalid environment ($environment)\n" if $environment !~ $FORMAT_REGEXP{environment};
    $logger->logcroak($arg_error) if $arg_error;

    my $transfer_options = "--transfer_id=$transfer_id";

    system("$^X $UPLOAD_TRANSFER_SCRIPT_PATH $transfer_options &");

    if ($? == -1) {
        $logger->warn("upload transfer: failed to execute: $!\n");
    }
    elsif ($? & 127) {
        $logger->warn(sprintf "upload transfer: child died with signal %d, %s coredump\n",
            ($? & 127),  ($? & 128) ? 'with' : 'without');
    }
    else {
        $logger->info(sprintf "upload transfer: child exited with value %d\n", $? >> 8);
    }

    return;

} ## END sub initiate_upload_transfer



sub insert_upload_transfer :Export(:upload_transfer) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $upload_date = $arg_ref->{upload_date};
    my $channel_id  = $arg_ref->{channel_id};
    my $operator_id = $arg_ref->{operator_id};
    my $source      = defined $arg_ref->{source} ? $arg_ref->{source} : 'xt_'  . lc( config_var( 'XTracker', 'instance' ) );
    my $sink        = defined $arg_ref->{sink} ? $arg_ref->{sink}     : 'pws_' . lc( config_var( 'XTracker', 'instance' ) );
    my $environment = $arg_ref->{environment};
    my $upload_id   = $arg_ref->{upload_id};

    $logger->logcroak("Invalid source ($source)")               unless is_valid_region( $source, 'xt_'  );
    $logger->logcroak("Invalid sink ($sink)")                   unless is_valid_region( $sink,   'pws_' );
    $logger->logcroak("Invalid upload_date ($upload_date)")     if $upload_date !~ $FORMAT_REGEXP{date};
    $logger->logcroak("Invalid channel_id ($channel_id)")       if $channel_id !~ $FORMAT_REGEXP{id};
    $logger->logcroak("Invalid operator_id ($operator_id)")     if $operator_id !~ $FORMAT_REGEXP{id};
    $logger->logcroak("Invalid upload_id ($upload_id)")         if $upload_id !~ $FORMAT_REGEXP{id};

    my $sql
        = q{INSERT INTO upload.transfer (upload_date, channel_id, operator_id, transfer_status_id, source, sink, environment, dtm, upload_id)
                VALUES (?, ?, ?, default, ?, ?, ?, default, ?)
        };

    my $sth = $dbh->prepare($sql);
    $sth->execute($upload_date, $channel_id, $operator_id, $source, $sink, $environment, $upload_id);

    my $transfer_id = last_insert_id($dbh, 'upload.transfer_id_seq');

    return $transfer_id;

} ## END sub insert_upload_transfer



sub set_upload_transfer_status :Export(:upload_transfer) {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $transfer_id         = $arg_ref->{transfer_id};
    my $status_id           = $arg_ref->{status_id};

    $logger->logcroak("Invalid transfer_id ($transfer_id)") if $transfer_id !~ $FORMAT_REGEXP{id};
    $logger->logcroak("Invalid status_id ($status_id)") if $status_id !~ $FORMAT_REGEXP{id};

    my $sql = q{UPDATE upload.transfer SET transfer_status_id = ? WHERE id = ?};
    my $sth = $dbh->prepare($sql);

    $sth->execute($status_id, $transfer_id);

    return;

} ## END sub set_upload_transfer_status



sub insert_upload_transfer_summary :Export(:upload_transfer) {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $summary_data_ref    = $arg_ref->{summary_data_ref};

    my $arg_error_msg = '';

    $arg_error_msg .= "Invalid transfer_id ($summary_data_ref->{transfer_id})\n" if $summary_data_ref->{transfer_id} !~ $FORMAT_REGEXP{id};

    foreach my $summary_record_ref ( @{ $summary_data_ref->{summary_records} } ) {
        $arg_error_msg .= "No category was specified\n" if $summary_record_ref->{category} =~ $FORMAT_REGEXP{empty_or_whitespace};
        foreach ( qw(num_pids_attempted num_pids_succeeded num_pids_failed) ) {
            $arg_error_msg .= "Invalid $_ ($summary_record_ref->{$_})\n" if $summary_record_ref->{$_} !~ m{\A\d+\z};
        }
    }

    if ($arg_error_msg) {
        $logger->logwarn($arg_error_msg);
        #return;
    }

    my $transfer_id = $summary_data_ref->{transfer_id};

    foreach my $summary_record_ref ( @{ $summary_data_ref->{summary_records} } ) {

        my $category            = $summary_record_ref->{category};
        my $num_pids_attempted  = $summary_record_ref->{num_pids_attempted};
        my $num_pids_succeeded  = $summary_record_ref->{num_pids_succeeded};
        my $num_pids_failed     = $summary_record_ref->{num_pids_failed};

        my $sql
            = q{INSERT INTO upload.transfer_summary (transfer_id, category, num_pids_attempted, num_pids_succeeded, num_pids_failed)
                    VALUES (?, ?, ?, ?, ?)
            };
        my $sth = $dbh->prepare($sql);

        $sth->execute($transfer_id, $category, $num_pids_attempted, $num_pids_succeeded, $num_pids_failed);

    }

    return;

} ## END sub insert_upload_transfer_summary



sub get_upload_transfers :Export(:upload_transfer) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $select_by   = $arg_ref->{select_by};

    $logger->logcroak("Invalid field name ($select_by->{fname})") if $select_by->{fname} !~ $FORMAT_REGEXP{db_object_name};

    $select_by->{fname} = lc(trim($select_by->{fname}));

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    for ($select_by->{fname}) {
        m{\Aid\z}xmsi           && do { $where_clause = 'id = ?'; push @exec_args, $select_by->{value}; last; };
        m{\Aupload_date\z}xmsi    && do { $where_clause = 'upload_date = ?'; push @exec_args, $select_by->{value}; last; };
        $logger->logcroak("Invalid field name ($_)");
    }

    my $qry = q{SELECT * FROM upload.vw_transfers};
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $upload_transfers_ref = results_list($sth);

    return $upload_transfers_ref;

} ## END sub get_upload_transfers



sub list_upload_transfer_log :Export(:upload_transfer) {

    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $select_by       = $arg_ref->{select_by};
    my $status_ids      = $arg_ref->{status_ids};
    my $columnsort_ref  = $arg_ref->{columnsort};

    $logger->logcroak("Invalid field name ($select_by->{fname})") if $select_by->{fname} !~ $FORMAT_REGEXP{db_object_name};
    $logger->logcroak("Invalid 'select_by' value specified for field '$select_by->{fname}' ($select_by->{value})")
        unless $select_by->{value} =~ $FORMAT_REGEXP{id};
    $select_by->{fname} = lc(trim($select_by->{fname}));

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    for ($select_by->{fname}) {
        m{\Aid\z}xmsi           && do { $where_clause = 'id = ?'; push @exec_args, $select_by->{value}; last; };
        m{\Atransfer_id\z}xmsi  && do { $where_clause = 'transfer_id = ?'; push @exec_args, $select_by->{value}; last; };
        m{\Aupload_id\z}xmsi    && do { $where_clause = 'upload_id = ?'; push @exec_args, $select_by->{value}; last; };
        $logger->logcroak("Invalid field name ($_)");
    }

    if ( defined $status_ids ) {
        my $status_ids_ref  = _validate_items( { items => $status_ids, type => 'id' } );
        $where_clause .= ' AND transfer_status_id IN (';
        $where_clause .= join( ', ', @{$status_ids_ref} );
        $where_clause .= ')';
    }

    ## build 'order by' clause
    my $sort_clause = undef;
    my $asc_desc    = defined $columnsort_ref->{asc_desc} ? $columnsort_ref->{asc_desc} : 'ASC';
    my $order_by    = defined $columnsort_ref->{order_by} ? $columnsort_ref->{order_by} : '';
    for ($order_by) {
        m{\Aupload_id\z}xmsi    && do   { $sort_clause = "upload_id $asc_desc, transfer_id, id"; last; };
        m{\Atransfer_id\z}xmsi  && do   { $sort_clause = "upload_id, transfer_id $asc_desc, id"; last; };
        m{\Aid\z}xmsi           && do   { $sort_clause = "upload_id, transfer_id, id $asc_desc"; last; };
        m{\Adtm\z}xmsi          && do   { $sort_clause = "upload_id, transfer_id, dtm $asc_desc"; last; };
                                        { $sort_clause = "upload_id, transfer_id, id $asc_desc"; };
    }

    my $qry = q{SELECT * FROM upload.vw_transfer_log};
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry .= qq{ ORDER BY $sort_clause} if defined $sort_clause;

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $upload_transfer_log_ref = results_list($sth);

    return $upload_transfer_log_ref;

} ## END sub list_upload_transfer_log



sub get_transfer_progress_header :Export(:upload_transfer) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $transfer_id = $arg_ref->{transfer_id};

    $logger->logcroak("Invalid transfer_id ($transfer_id)") if $transfer_id !~ $FORMAT_REGEXP{id};

    my $transfer_header_ref
        = get_upload_transfers( { dbh => $dbh, select_by => { fname => 'id', value => $transfer_id } } );

    my $result_set_ref = {
        ResultSet => {
            totalResultsAvailable   => scalar @{$transfer_header_ref},
            Result                  => $transfer_header_ref,
        }
    };

    return $result_set_ref;

} ## END sub get_transfer_progress_header



sub get_transfer_progress_details :Export(:upload_transfer) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $transfer_id = $arg_ref->{transfer_id};

    $logger->logcroak("Invalid transfer_id ($transfer_id)") if $transfer_id !~ $FORMAT_REGEXP{id};

    my $result_set_ref;
    my $log_actions_ref = get_transfer_log_actions( { dbh => $dbh } );

    my $transfer_header_ref
        = get_upload_transfers( { dbh => $dbh, select_by => { fname => 'id', value => $transfer_id } } );

    if ( not defined $transfer_header_ref->[0]{id} ) {
        $result_set_ref = {
            ResultSet => {
                totalResultsAvailable   => 0,
                Result                  => [],
            }
        };
        return $result_set_ref;
    }

    my $transfer_log_ref
        = list_upload_transfer_log({
            dbh         => $dbh,
            select_by   => { fname => 'transfer_id', value => $transfer_header_ref->[0]{id} },
        });

    my %output_record;

    LOG_RECORD:
    foreach my $log_record ( @{$transfer_log_ref} ) {
        LOG_ACTION:
        foreach my $log_action_id ( keys %{$log_actions_ref} ) {
            if ( $log_record->{transfer_log_action_id} == $log_action_id ) {
                if ( $log_record->{level} eq 'info' ) {
                    $output_record{ $log_record->{product_id} }{$log_action_id} = 'OK';
                }
                elsif ( $log_record->{level} eq 'error' ) {
                    $output_record{ $log_record->{product_id} }{$log_action_id} = 'ERROR';
                }
            }
        } ## END LOG_ACTION
    } ## END LOG_RECORD

    my @output_recordset = ();


    foreach my $product_id ( sort { $b <=> $a } keys %output_record ) {

        my %record;
        $record{product_id} = $product_id;

        foreach my $log_action_id ( keys %{$log_actions_ref} ) {
            my $log_action_label = $log_actions_ref->{$log_action_id};
            $log_action_label = lc($log_action_label);
            $log_action_label =~ s{\s+}{_}g;
            $record{$log_action_label} = $output_record{$product_id}{$log_action_id};
        }
        push @output_recordset, \%record;

    }


    $result_set_ref = {
        ResultSet => {
            totalResultsAvailable   => scalar @output_recordset,
            Result                  => \@output_recordset,
        }
    };

    return $result_set_ref;

} ## END sub get_transfer_progress_details



sub get_transfer_summary :Export(:upload_transfer) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $select_by   = $arg_ref->{select_by};

    $logger->logcroak("Invalid field name ($select_by->{fname})") if $select_by->{fname} !~ $FORMAT_REGEXP{db_object_name};
    $logger->logcroak("Invalid 'select_by' value specified for field '$select_by->{fname}' ($select_by->{value})")
        unless $select_by->{value} =~ $FORMAT_REGEXP{id};

    $select_by->{fname} = lc(trim($select_by->{fname}));

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    for ($select_by->{fname}) {
        m{\Aupload_id\z}xmsi    && do { $where_clause = 'upload_id = ?'; push @exec_args, $select_by->{value}; last; };
        m{\Atransfer_id\z}xmsi  && do { $where_clause = 'transfer_id = ?'; push @exec_args, $select_by->{value}; last; };
        $logger->logcroak("Invalid field name ($_)");
    }

    my $qry = q{SELECT * FROM upload.vw_transfer_summary};
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry .= q{ ORDER BY upload_id, transfer_id};

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $transfer_summary_ref = results_list($sth);

    return $transfer_summary_ref;

} ## END sub get_transfer_summary

=head2 transfer_product_data

This uploads the given data to the web site.

 transfer_product_date({
   dbh_ref => ...
   ...
 });

This takes a hash of parameters as follows:

=head3 skip_navcat

If set, disables updates of transfer categories starting "navigation_",
currently navigation_attribute, navigation_category and navigation_tree.

=cut

sub transfer_product_data :Export(:transfer) {

    my %args = ref $_[0] ? %{ +shift } : @_;
    my ($dbh_ref, $channel_id, $product_ids, $transfer_categories,
        $attributes, $sql_action_ref, $db_log_ref, $skip_navcat)
        = @args{qw/ dbh_ref channel_id product_ids transfer_categories
                    attributes sql_action_ref db_log_ref skip_navcat /};

    my %dbh = %{ $dbh_ref || {} };
    my ($dbh_source, $dbh_sink, $sink_environment, $sink_site)
        = @dbh{qw/ dbh_source dbh_sink sink_environment sink_site /};

    # EN-1587:
    #     If there is no connected Web DB Handle then just return.
    #     This is an easy way of stopping xTracker from updating the WEB
    #     when we don't want it to.
    if ( !$dbh_sink ) {
        return;
    }

    ## initialise db logging if required
    $db_log_ref = validate_log_ref($db_log_ref);
    my $logger_db;
    if ($db_log_ref) {
        $logger_db = XTracker::Upload::Transfer::Log->new(
            name        => 'dbi',
            min_level   => 'info',
            dbh         => $db_log_ref->{dbh_log},
        );
    }

    # Now we make sure that the global "use optimized upload" variable for this channel is initialized
    my $use_optimized_upload = init_optimized_upload($dbh_source, $channel_id);

    eval {

        ## set default transfer categories to process if none specified
        if ( not $transfer_categories ) {
            $transfer_categories = ['catalogue_product', 'catalogue_attribute', 'navigation_attribute', 'list_attribute', 'catalogue_sku', 'catalogue_pricing', 'catalogue_markdown', 'catalogue_ship_restriction'];
        }

        # TODO: when related_product comes in, we probably can check if this product is one that is related to itself... so no need to upload again?

        $logger->info("Transfer categories: ". (ref $transfer_categories ? (join ",", @$transfer_categories) : $transfer_categories));

        my $transfer_categories_ref = _validate_items( { items => $transfer_categories, type => 'transfer_category' } );
        my $product_ids_ref         = _validate_items( { items => $product_ids, type => 'id' } );

        PRODUCT:
        foreach my $product_id ( @{$product_ids_ref} ) {

            TRANSFER_CATEGORY:
            foreach my $transfer_category ( @{$transfer_categories_ref} ) {
                # do not update navigation_category or navigation_tree if
                # $skip_navcat is set. This is part of the EN-1587 fixes.
                next if $skip_navcat && $transfer_category =~ /^navigation_/;

                ## Override default SQL actions
                my %required_sql_action = %{ $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{default_sql_action} };
                foreach my $sql_action ( keys %{ $sql_action_ref->{$transfer_category} } ) {
                    $required_sql_action{$sql_action} = $sql_action_ref->{$transfer_category}{$sql_action};
                }

                $logger->info("Product data transfer start ($transfer_category, @{[ uc($sink_site) ]} $sink_environment): $product_id");

                my $param_ref = { product_ids => $product_id };

                if ( defined $channel_id ) {
                    $param_ref->{channel_id} = $channel_id;
                }

                ## allow attribute selection, or default to 'all_attributes' if none specified
                if ( $transfer_category =~ m{\A(?:catalogue|navigation|list)_attribute\z}xms ) {
                    if ( (not defined $attributes) or ($attributes eq 'all_attributes') ) {
                        $param_ref->{attributes} = 'all_attributes';
                    }
                    else {
                        $param_ref->{attributes} = _validate_items( { items => $attributes, type => $transfer_category } );
                    }
                }


                eval {

                    my $sink_data_ref
                        = fetch_and_transform_data({
                                dbh_source          => $dbh_source,
                                sink_environment    => $sink_environment,
                                sink_site           => $sink_site,
                                transfer_category   => $transfer_category,
                                params              => $param_ref,
                                use_optimized_upload => $use_optimized_upload
                        })->{sink_data};

                    build_and_execute_sql({
                        dbh             => $dbh_sink,
                        data            => $sink_data_ref,
                        action          => \%required_sql_action,
                        write_permitted => $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{write_permitted},
                        use_optimized_upload => $use_optimized_upload
                    });

                };
                if ($@) {
                    if ($db_log_ref) {
                        $logger_db->log_message(
                            $db_log_ref,
                            {
                                product_id  => $product_id,
                                action_id   => $LOG_ACTION_MAP{$transfer_category},
                                level       => 'error',
                                message     => $@,
                            }
                        );
                    }
                    die $@;
                }

                $logger->info("Product data transfer done ($transfer_category, @{[ uc($sink_site) ]} $sink_environment): $product_id \n");

                if ($db_log_ref) {
                    $logger_db->log_message(
                        $db_log_ref,
                        {
                            product_id  => $product_id,
                            action_id   => $LOG_ACTION_MAP{$transfer_category},
                        }
                    );
                }

            } ## END TRANSFER_CATEGORY

            #$logger->info("Product data transfer commit pending: $product_id \n");

        } ## END PRODUCT

    };
    if ($@) {
        $logger->logcroak($@);
    }

    return;

} ## END sub transfer_product_data



### Subroutine : transfer_product_inventory
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub transfer_product_inventory :Export(:transfer) {

    my ($arg_ref)           = @_;
    my $dbh_ref             = $arg_ref->{dbh_ref};
    my $channel_id          = $arg_ref->{channel_id};
    my $product_ids         = $arg_ref->{product_ids};
    my $sql_action_ref      = $arg_ref->{sql_action_ref};
    my $db_log_ref          = $arg_ref->{db_log_ref};
    my $new_variant         = $arg_ref->{new_variant} || 0;

    my $dbh_source          = $dbh_ref->{dbh_source};
    my $dbh_sink            = $dbh_ref->{dbh_sink};
    my $sink_environment    = $dbh_ref->{sink_environment};
    my $sink_site           = $dbh_ref->{sink_site};

    my $schema_source = get_schema_using_dbh($dbh_source, 'xtracker_schema');

    my $transfer_category   = 'saleable_inventory';


    ## initialise db logging if required
    $db_log_ref = validate_log_ref($db_log_ref);
    my $logger_db;
    if ($db_log_ref) {
        $logger_db = XTracker::Upload::Transfer::Log->new(
            name        => 'dbi',
            min_level   => 'info',
            dbh         => $db_log_ref->{dbh_log},
        );
    }


    eval {

        my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

        PRODUCT:
        foreach my $product_id ( @{$product_ids_ref} ) {

            ## Override default SQL actions
            my %required_sql_action = %{ $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{default_sql_action} };
            foreach my $sql_action ( keys %{ $sql_action_ref->{$transfer_category} } ) {
                $required_sql_action{$sql_action} = $sql_action_ref->{$transfer_category}{$sql_action};
            }

            $logger->info("Product inventory transfer start (@{[ uc($sink_site) ]} $sink_environment): $product_id");

            eval {

                my $data_ref
                    = fetch_and_transform_data({
                            dbh_source          => $dbh_source,
                            sink_environment    => $sink_environment,
                            sink_site           => $sink_site,
                            transfer_category   => $transfer_category,
                            params              => { product_ids => $product_id, channel_id => $channel_id },
                    });
                my $source_data_ref = $data_ref->{source_data};
                my $sink_data_ref   = $data_ref->{sink_data};

                build_and_execute_sql({
                    dbh             => $dbh_sink,
                    data            => $sink_data_ref,
                    action          => \%required_sql_action,
                    write_permitted => $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{write_permitted},
                });

                $logger->info("Product inventory transfer done (pending commit): $product_id\n");

                if ($db_log_ref) {
                    $logger_db->log_message(
                        $db_log_ref,
                        {
                            product_id  => $product_id,
                            action_id   => $LOG_ACTION_MAP{$transfer_category},
                        }
                    );
                }

                ## insert xT log_pws_stock records iff sink_environment is 'live'
                if (($sink_environment eq 'live') && (!$new_variant)) {

                    SOURCE_RECORD:
                    foreach my $source_record_ref ( @{ $source_data_ref->{results_ref} } ) {

                        next SOURCE_RECORD unless $source_record_ref->{quantity} > 0;

                        $schema_source->resultset('Public::LogPwsStock')->log_stock_change(
                            variant_id      => $source_record_ref->{variant_id},
                            channel_id      => $channel_id,
                            pws_action_id   => $PWS_ACTION__UPLOAD,
                            quantity        => $source_record_ref->{quantity},
                        );

                    } ## END SOURCE RECORD

                } ## END if

            };
            if ($@) {
                if ($db_log_ref) {
                    $logger_db->log_message(
                        $db_log_ref,
                        {
                            product_id  => $product_id,
                            action_id   => $LOG_ACTION_MAP{$transfer_category},
                            level       => 'error',
                            message     => $@,
                        }
                    );
                }
                die $@;
            }

        } ## END PRODUCT

    };
    if ($@) {
        $logger->logcroak($@);
    }


    return;

} ## END sub transfer_product_inventory



### Subroutine : transfer_product_reservations
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub transfer_product_reservations :Export(:transfer) {

    my ($arg_ref)   = @_;
    my $dbh_ref     = $arg_ref->{dbh_ref};
    my $channel_id  = $arg_ref->{channel_id};
    my $product_ids = $arg_ref->{product_ids};
    my $db_log_ref  = $arg_ref->{db_log_ref};
    my $stock_manager = $arg_ref->{stock_manager};

    my $sink_environment    = $dbh_ref->{sink_environment};
    my $sink_site           = $dbh_ref->{sink_site};

    my $transfer_category   = 'product_reservations';

    ## don't transfer reservations unless sink_environment is 'live'
    if ($sink_environment ne 'live') {
        $logger->info("Skipping reservations transfer (sink environment is not 'live')");
        return;
    };

    ## initialise db logging if required
    $db_log_ref = validate_log_ref($db_log_ref);
    my $logger_db;
    if ($db_log_ref) {
        $logger_db = XTracker::Upload::Transfer::Log->new(
            name        => 'dbi',
            min_level   => 'info',
            dbh         => $db_log_ref->{dbh_log},
        );
    }


    eval {

        my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

        PRODUCT:
        foreach my $product_id ( @{$product_ids_ref} ) {

            $logger->info("Product reservations transfer start: $product_id");

            eval {
                my $reservations_ref = list_reservations( { dbh => $dbh_ref->{dbh_source}, product_ids => $product_id, channel_id => $channel_id } );

                if ( scalar @{$reservations_ref} ) {
                    RESERVATION_RECORD:
                    foreach my $reservation_record_ref ( @{$reservations_ref} ) {

                        $logger->info("Reservation id: $reservation_record_ref->{reservation_id} for customer $reservation_record_ref->{email}");

                        _transfer_reservation({
                            dbh_ref             => $dbh_ref,
                            reservation_record  => $reservation_record_ref,
                            department_id       => $DEPARTMENT__PERSONAL_SHOPPING,
                            stock_manager       => $stock_manager,
                        });

                    } ## END RESERVATION_RECORD
                }
                else {
                    $logger->info("No pending reservations found for product $product_id");
                }
            };
            if (my $error = $@) {
                if ($db_log_ref) {
                    $logger_db->log_message(
                        $db_log_ref,
                        {
                            product_id  => $product_id,
                            action_id   => $LOG_ACTION_MAP{$transfer_category},
                            level       => 'error',
                            message     => $error,
                        }
                    );
                }
                die $error;
            }

            $logger->info("Product reservations transfer done (pending commit): $product_id\n");

            if ($db_log_ref) {
                $logger_db->log_message(
                    $db_log_ref,
                    {
                        product_id  => $product_id,
                        action_id   => $LOG_ACTION_MAP{$transfer_category},
                    }
                );
            }

        } ## END PRODUCT

    };
    if (my $error = $@) {
        $logger->logcroak($error);
    }

    return;

} ## END sub transfer_product_reservations



### Subroutine : transfer_product_sort_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub transfer_product_sort_data :Export(:transfer) {

    my ($arg_ref)           = @_;
    my $dbh_ref             = $arg_ref->{dbh_ref};
    my $channel_id          = $arg_ref->{channel_id};
    my $product_ids         = $arg_ref->{product_ids};
    my $destination         = $arg_ref->{destination};

    my $dbh_source          = $dbh_ref->{dbh_source};
    my $dbh_sink            = $dbh_ref->{dbh_sink};
    my $sink_environment    = $dbh_ref->{sink_environment};
    my $sink_site           = $dbh_ref->{sink_site};

    croak "Invalid destination ($destination).  Must be be 'preview' or 'main'" if $destination !~ m{\A(?:preview|main)\z}xms;
    croak "Undefined channel_id" if not defined $channel_id;

    if ( ($destination eq 'preview') && ($sink_environment ne 'staging') ) {
        croak "sink_environment must be 'staging' for product sort preview";
    }

    my $transfer_category   = 'product_sort';

    eval {

        my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

        ## Override default SQL actions
        my %required_sql_action = %{ $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{default_sql_action} };

        $logger->info("Product Sort transfer start ($transfer_category, @{[ uc($sink_site) ]} $sink_environment)");

        my $sink_data_ref
            = fetch_and_transform_data({
                    dbh_source          => $dbh_source,
                    sink_environment    => $sink_environment,
                    sink_site           => $sink_site,
                    transfer_category   => $transfer_category,
                    params              => { product_ids => $product_ids_ref, destination => $destination, channel_id => $channel_id },
            })->{sink_data};

        build_and_execute_sql({
            dbh             => $dbh_sink,
            data            => $sink_data_ref,
            action          => \%required_sql_action,
            write_permitted => $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{write_permitted},
        });

        XTracker::Role::WithAMQMessageFactory->build_msg_factory
              ->transform_and_send('XT::DC::Messaging::Producer::Product::SortOrder',{
                  channel_id => $channel_id,
                  environment => $sink_environment,
                  destination => $destination,
                  product_ids => $product_ids_ref,
              });

        $logger->info("Product Sort data transfer done ($transfer_category, @{[ uc($sink_site) ]} $sink_environment)\n");

    };
    if ($@) {
        $logger->logcroak($@);
    }

    return;

} ## END sub transfer_product_sort_data



sub initiate_sort_preview_transfer :Export() {

    system("$^X $SORT_PREVIEW_TRANSFER_SCRIPT_PATH &");

    if ($? == -1) {
        $logger->warn("sort preview transfer: failed to execute: $!\n");
    }
    elsif ($? & 127) {
        $logger->warn(sprintf "sort preview transfer: child died with signal %d, %s coredump\n",
            ($? & 127),  ($? & 128) ? 'with' : 'without');
    }
    else {
        $logger->info(sprintf "sort preview transfer: child exited with value %d\n", $? >> 8);
    }

    return $?;

}



################################################################################
# Category Navigation data transfer
################################################################################

### Subroutine : transfer_navigation_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub transfer_navigation_data :Export(:transfer) {

    my ($arg_ref)           = @_;
    my $dbh_ref             = $arg_ref->{dbh_ref};
    my $transfer_category   = $arg_ref->{transfer_category};
    my $ids                 = $arg_ref->{ids};
    my $sql_action_ref      = $arg_ref->{sql_action_ref};

    my $dbh_source          = $dbh_ref->{dbh_source};
    my $dbh_sink            = $dbh_ref->{dbh_sink};
    my $sink_environment    = $dbh_ref->{sink_environment};
    my $sink_site           = $dbh_ref->{sink_site};

    # EN-1587:
    #     If there is no connected Web DB Handle then just return.
    #     This is an easy way of stopping xTracker from updating the WEB
    #     when we don't want it to.
    if ( !$dbh_sink ) {
        return;
    }


    eval {

        my $ids_ref;

        if ( $ids =~ m{\Aall_(?:categories|nodes)\z}xmsi ) {
            $ids_ref = $ids;
        }
        else {
            $ids_ref = _validate_items( { items => $ids, type => 'id' } );
        }

        my %params = (
            navigation_category => { category_ids   => $ids_ref },
            navigation_tree     => { node_ids       => $ids_ref },
        );
        die "Invalid transfer_category ($transfer_category)" unless grep {m{\A$transfer_category\z}xms} keys %params;

        ## Override default SQL actions
        my %required_sql_action = %{ $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{default_sql_action} };
        foreach my $sql_action ( keys %{ $sql_action_ref->{$transfer_category} } ) {
            $required_sql_action{$sql_action} = $sql_action_ref->{$transfer_category}{$sql_action};
        }

        $logger->info("Navigation data transfer start ($transfer_category, @{[ uc($sink_site) ]} $sink_environment)");

        my $sink_data_ref
            = fetch_and_transform_data({
                    dbh_source          => $dbh_source,
                    sink_environment    => $sink_environment,
                    sink_site           => $sink_site,
                    transfer_category   => $transfer_category,
                    params              => $params{$transfer_category},
            })->{sink_data};

        build_and_execute_sql({
            dbh             => $dbh_sink,
            data            => $sink_data_ref,
            action          => \%required_sql_action,
            write_permitted => $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{write_permitted},
        });

        $logger->info("Navigation data transfer done ($transfer_category, @{[ uc($sink_site) ]} $sink_environment)\n");

    };
    if ($@) {
        $logger->logcroak($@);
    }

    return;

} ## END sub transfer_navigation_data



################################################################################
# Designer data transfer
################################################################################

### Subroutine : transfer_designer_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub transfer_designer_data :Export(:transfer) {

    my ($arg_ref)           = @_;
    my $dbh_ref             = $arg_ref->{dbh_ref};
    my $transfer_category   = $arg_ref->{transfer_category};
    my $ids                 = $arg_ref->{ids};
    my $sql_action_ref      = $arg_ref->{sql_action_ref};
    my $channel_id          = $arg_ref->{channel_id};

    my $dbh_source          = $dbh_ref->{dbh_source};
    my $dbh_sink            = $dbh_ref->{dbh_sink};
    my $sink_environment    = $dbh_ref->{sink_environment};
    my $sink_site           = $dbh_ref->{sink_site};


    eval {
        die "No Channel Id Provided"        if ( !$channel_id && $transfer_category eq "designer" );

        my $ids_ref;

        if ( $ids =~ m{\Aall_(?:designers|designer_attribute_types|designer_attribute_values)\z}xmsi ) {
            $ids_ref = $ids;
        }
        else {
            $ids_ref = _validate_items( { items => $ids, type => 'id' } );
        }

        my %params = (
            designer                    => { designer_ids                   => $ids_ref, channel_id => $channel_id },
            designer_attribute_type     => { designer_attribute_type_ids    => $ids_ref },
            designer_attribute_value    => { designer_attribute_value_ids   => $ids_ref },
        );
        die "Invalid transfer_category ($transfer_category)" unless grep {m{\A$transfer_category\z}xms} keys %params;

        ## Override default SQL actions
        my %required_sql_action = %{ $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{default_sql_action} };
        foreach my $sql_action ( keys %{ $sql_action_ref } ) {
            $required_sql_action{$sql_action} = $sql_action_ref->{$sql_action};
        }

        $logger->info("Designer data transfer start ($transfer_category, @{[ uc($sink_site) ]} $sink_environment)");

        my $sink_data_ref
            = fetch_and_transform_data({
                    dbh_source          => $dbh_source,
                    sink_environment    => $sink_environment,
                    sink_site           => $sink_site,
                    transfer_category   => $transfer_category,
                    params              => $params{$transfer_category},
            })->{sink_data};

        build_and_execute_sql({
            dbh             => $dbh_sink,
            data            => $sink_data_ref,
            action          => \%required_sql_action,
            write_permitted => $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{write_permitted},
        });

        $logger->info("Designer data transfer done ($transfer_category, @{[ uc($sink_site) ]} $sink_environment)\n");

    };
    if ($@) {
        $logger->logcroak($@);
    }

    return;

} ## END sub transfer_designer_data



################################################################################
# Web CMS data transfer
################################################################################


### Subroutine : _random_string
#
# usage        : my $random = _random_string(32);
# description  : generates a random string of specified length
# parameters   : string length (characters), integer (default 32)
# returns      : random string consisting of both upper and lowercase letters, and digits
#
sub _random_string {

    my $length  = shift;
    $length     = defined $length ? $length : 32;

    my $random_string = '';
    my @chars = (0..9, 'a'..'z', 'A'..'Z');
    $random_string .= @chars[rand(@chars)] for (1..$length);
    return $random_string;

} ## END _random_string



### Subroutine : insert_web_cms_placeholder
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub insert_web_cms_placeholder :Export(:web_cms_transfer) {

    my ($arg_ref)           = @_;
    my $dbh_ref             = $arg_ref->{dbh_ref};
    my $transfer_category   = $arg_ref->{transfer_category};
    my $page_id             = defined $arg_ref->{page_id} ? $arg_ref->{page_id} : '';           ## only required for transfer_category 'web_cms_page_instance' or staging
    my $instance_id         = defined $arg_ref->{instance_id} ? $arg_ref->{instance_id} : '';   ## only required for staging

    my $dbh_source          = $dbh_ref->{dbh_source};
    my $dbh_sink            = $dbh_ref->{dbh_sink};
    my $sink_environment    = $dbh_ref->{sink_environment};
    my $sink_site           = $dbh_ref->{sink_site};

    $logger->debug("Web CMS - INSERTing placeholder ($transfer_category, @{[ uc($sink_site) ]} $sink_environment)");

    my $sql_insert;
    my $id;
    my $random = _random_string();

    for ($transfer_category) {
        m{\Aweb_cms_page\z}xms && do {
            if ($page_id) {
                $logger->logcroak("Invalid page_id ($page_id)") if $page_id !~ $FORMAT_REGEXP{id};
                $sql_insert
                    = qq{INSERT INTO page (id, template_id, name, page_type_id, page_key, channel, preview_url, jsp)
                            VALUES ($page_id, 1, 'XT_PLACEHOLDER_$random', 1, NULL, 1, NULL, NULL)
                    };
            }
            else {
                $sql_insert
                    = qq{INSERT INTO page (template_id, name, page_type_id, page_key, channel, preview_url, jsp)
                            VALUES (1, 'XT_PLACEHOLDER_$random', 1, NULL, 1, NULL, NULL)
                    };
            }
            last;
        };
        m{\Aweb_cms_page_instance\z}xms && do {
            $logger->logcroak("Invalid page_id ($page_id)") if $page_id !~ $FORMAT_REGEXP{id};

            if ($instance_id) {
                $logger->logcroak("Invalid instance_id ($instance_id)") if $instance_id !~ $FORMAT_REGEXP{id};
                $sql_insert
                    = qq{INSERT INTO page_instance (id, label, status, preview_hash, page_id, created_by, created_dts, last_updated_by, last_updated_dts)
                            VALUES ($instance_id, 'XT_PLACEHOLDER', '0', 'XT_PLACEHOLDER_$random', $page_id, '$AUDIT_APPLICATION', now(), '', now())
                    };
            }
            else {
                $sql_insert
                    = qq{INSERT INTO page_instance (label, status, preview_hash, page_id, created_by, created_dts, last_updated_by, last_updated_dts)
                            VALUES ('XT_PLACEHOLDER', '0', 'XT_PLACEHOLDER_$random', $page_id, '$AUDIT_APPLICATION', now(), '', now())
                    };
            }

            last;
        };
        $logger->logcroak("Invalid transfer_category ($_)");
    }

    eval {
        my $sth_insert = $dbh_sink->prepare($sql_insert);
        $sth_insert->execute();

        $id = $dbh_sink->{ q{mysql_insertid} };
        $logger->debug("Web CMS - INSERTed placeholder ($transfer_category, @{[ uc($sink_site) ]} $sink_environment) - id: $id");
    };
    if ($@) {
        $logger->logcroak($@);
    }

    return $id;

} ## END sub insert_web_cms_placeholder



### Subroutine : transfer_web_cms_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub transfer_web_cms_data :Export(:web_cms_transfer) {

    my ($arg_ref)           = @_;
    my $dbh_ref             = $arg_ref->{dbh_ref};
    my $transfer_category   = $arg_ref->{transfer_category};
    my $ids                 = $arg_ref->{ids};

    my $dbh_source          = $dbh_ref->{dbh_source};
    my $dbh_sink            = $dbh_ref->{dbh_sink};
    my $sink_environment    = $dbh_ref->{sink_environment};
    my $sink_site           = $dbh_ref->{sink_site};


    eval {

        my $ids_ref = _validate_items( { items => $ids, type => 'id' } );

        my %params = (
            web_cms_page => {
                params  => { page_ids => $ids_ref },
            },
            web_cms_page_instance => {
                params  => { instance_ids => $ids_ref },
            },
            web_cms_page_content => {
                params  => { content_ids => $ids_ref },
            },
        );
        die "Invalid transfer_category ($transfer_category)" unless grep {m{\A$transfer_category\z}xms} keys %params;

        $logger->debug("Web CMS data transfer start ($transfer_category, @{[ uc($sink_site) ]} $sink_environment)");

        my $sink_data_ref
            = fetch_and_transform_data({
                    dbh_source          => $dbh_source,
                    sink_environment    => $sink_environment,
                    sink_site           => $sink_site,
                    transfer_category   => $transfer_category,
                    params              => $params{$transfer_category}{params},
            })->{sink_data};


        build_and_execute_sql({
            dbh             => $dbh_sink,
            data            => $sink_data_ref,
            action          => $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{default_sql_action},
            write_permitted => $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{write_permitted},
        });

        $logger->debug("Web CMS data transfer done ($transfer_category, @{[ uc($sink_site) ]} $sink_environment)\n");

    };
    if ($@) {
        $logger->logcroak($@);
    }

    return;

} ## END sub transfer_web_cms_data



### Subroutine : web_cms_records_match
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub web_cms_records_match :Export(:web_cms_transfer) {

    my ($arg_ref)           = @_;
    my $dbh_ref             = $arg_ref->{dbh_ref};
    my $transfer_category   = $arg_ref->{transfer_category};
    my $id                  = $arg_ref->{id};

    my $dbh_source          = $dbh_ref->{dbh_source};
    my $dbh_sink            = $dbh_ref->{dbh_sink};
    my $sink_environment    = $dbh_ref->{sink_environment};
    my $sink_site           = $dbh_ref->{sink_site};

    my ($qry_source, $qry_sink);
    my @exec_args_source    = ();
    my @exec_args_sink      = ();
    my ($check_hash_source, $check_hash_sink) = ('', '');

    for ($transfer_category) {
        m{\Aweb_cms_page\z}xms && do {
            $qry_source
                = q{SELECT md5(tmplt.id || tmplt.name || p.name || type.id || type.name || p.page_key) AS check_hash
                    FROM web_content.page p
                    INNER JOIN web_content.type type
                        ON (p.type_id = type.id)
                    INNER JOIN web_content.template tmplt
                        ON (p.template_id = tmplt.id)
                    WHERE p.id = ?
                };
            push @exec_args_source, $id;

            $qry_sink
                = qq{SELECT MD5(CONCAT(tmplt.id, tmplt.name, p.name, type.id, type.name, p.page_key)) AS check_hash
                    FROM page p
                    INNER JOIN page_type type
                        ON (p.page_type_id = type.id)
                    INNER JOIN template tmplt
                        ON (p.template_id = tmplt.id)
                    WHERE p.id = ?
                };
            push @exec_args_sink, $id;

            my $sth_source      = $dbh_source->prepare($qry_source);
            my $sth_sink        = $dbh_sink->prepare($qry_sink);
            $sth_source->execute(@exec_args_source);
            $sth_sink->execute(@exec_args_sink);
            $check_hash_source  = $sth_source->fetchrow_arrayref()->[0];
            $check_hash_sink    = $sth_sink->fetchrow_arrayref()->[0];

            last;
        };
        m{\Aweb_cms_page_instance\z}xms && do {
            $qry_source
                = qq{SELECT md5(wci.id || wci.page_id || wci.label || upper(wcis.status) || op_created.name) AS check_hash
                    FROM web_content.instance wci
                    INNER JOIN web_content.instance_status wcis
                        ON (wci.status_id = wcis.id)
                    INNER JOIN operator op_created
                        ON (wci.created_by = op_created.id)
                    WHERE wci.id = ?
                };
            push @exec_args_source, $id;

            $qry_sink
                = qq{SELECT MD5(CONCAT(id, page_id, label, status, created_by)) AS check_hash
                    FROM page_instance WHERE id = ?
                };
            push @exec_args_sink, $id;

            my $sth_source      = $dbh_source->prepare($qry_source);
            my $sth_sink        = $dbh_sink->prepare($qry_sink);
            $sth_source->execute(@exec_args_source);
            $sth_sink->execute(@exec_args_sink);
            $check_hash_source  = $sth_source->fetchrow_arrayref()->[0];
            $check_hash_sink    = $sth_sink->fetchrow_arrayref()->[0];

            last;
        };
        m{\Aweb_cms_page_content\z}xms && do {
            $qry_source
                = qq{SELECT
                        c.instance_id
                    ,   c.field_id
                    ,   md5(c.instance_id || c.field_id || f.name || c.content) AS check_hash
                    FROM web_content.content c
                    INNER JOIN web_content.field f
                        ON (c.field_id = f.id)
                    WHERE c.id = ?
                };
            push @exec_args_source, $id;

            my $sth_source          = $dbh_source->prepare($qry_source);
            $sth_source->execute(@exec_args_source);

            my $results_ref_source  = $sth_source->fetchrow_hashref();
            my $page_instance_id    = $results_ref_source->{instance_id};
            my $field_id            = $results_ref_source->{field_id};
            $check_hash_source      = $results_ref_source->{check_hash};

            $qry_sink
                = qq{SELECT MD5(CONCAT(pc.page_instance_id, pc.field_id, f.name, pc.content)) AS check_hash
                    FROM page_content pc
                    INNER JOIN field f
                        ON (pc.field_id = f.id)
                    WHERE page_instance_id = ? AND field_id = ?
                };
            push @exec_args_sink, ($page_instance_id, $field_id);

            my $sth_sink        = $dbh_sink->prepare($qry_sink);
            $sth_sink->execute(@exec_args_sink);
            $check_hash_sink    = $sth_sink->fetchrow_arrayref()->[0];

            last;
        };
        $logger->logcroak("Invalid transfer_category ($_)");
    }

    return $check_hash_source eq $check_hash_sink ? 1 : 0;

} ## END sub web_cms_records_match



################################################################################
# xTracker Product Update
################################################################################

### Subroutine : build_category_map
#
# usage        : $category_ref = build_category_map( { form => $form_ref } );
# description  : builds a hash map of transfer categories and field names
#              :
# parameters   : form (hash-ref):-
#              : { name => 'form_name', fields => ['fieldname1', 'fieldname2', ... ] }
#              :
# returns      : hash-ref
#
sub build_category_map :Export(:justfortest) {

    my ($arg_ref)       = @_;
    my $form_ref        = $arg_ref->{form};

    my $formname            = $form_ref->{name};
    my $formfields          = $form_ref->{fields};
    my $formfield_map_ref   = $XT_FORMFIELD_MAP{$formname};

    my $formfields_ref  = _validate_items( { items => $formfields, type => 'db_object_name' } );
    my %category_map    = ();


    foreach my $form_field ( @{$formfields_ref} ) {

        my @transfer_categories = keys %{ $formfield_map_ref->{$form_field} };

        foreach my $transfer_category (@transfer_categories) {
            push @{ $category_map{$transfer_category} }, $formfield_map_ref->{$form_field}{$transfer_category};
        }

    }

    return \%category_map;

} ## END sub build_category_map



### Subroutine : transfer_form_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub transfer_form_data :Export(:xt_form_data) {

    my ($arg_ref)       = @_;
    my $dbh_source      = $arg_ref->{dbh_source};
    my $dbh_sink_ref    = $arg_ref->{dbh_sink_ref};
    my $product_id      = $arg_ref->{product_id};
    my $form_ref        = $arg_ref->{form};

    my $dbh_sink            = $dbh_sink_ref->{dbh_sink};
    my $sink_environment    = $dbh_sink_ref->{sink_environment};
    my $sink_site           = $dbh_sink_ref->{sink_site};

    my $status_msg          = '';
    my $rows_were_affected  = 0;

    if ( not product_present( $dbh_source, { type => 'product_id', id => $product_id, environment => $sink_environment } ) ) {
        return "xTracker reports that product $product_id is not present on $sink_environment\n";
    }


    eval {

        my $product_id_ref      = _validate_items( { items => $product_id, type => 'id' } );
        my $category_map_ref    = build_category_map( { form => $form_ref } );

        PRODUCT:
        foreach my $product_id ( @{$product_id_ref} ) {

            TRANSFER_CATEGORY:
            foreach my $transfer_category ( keys %{$category_map_ref} ) {

                my $fields_ref = _validate_items( { items => $category_map_ref->{$transfer_category}, type => 'db_object_name' } );

                $logger->info("xT Form data ($form_ref->{name}) transfer start ($transfer_category, $sink_environment, @{[ uc($sink_site) ]}): $product_id");
                $logger->info("Fields: @{[ join(', ', @{$fields_ref} ) ]}");

                my $sink_data_ref
                    = fetch_and_transform_data({
                            dbh_source          => $dbh_source,
                            sink_environment    => $sink_environment,
                            sink_site           => $sink_site,
                            transfer_category   => $transfer_category,
                            params              => { product_ids => $product_id, fields => $fields_ref },
                    })->{sink_data};

                my $num_rows_affected
                    = build_and_execute_sql({
                        dbh             => $dbh_sink,
                        data            => $sink_data_ref,
                        action          => { 'update' => 1, 'insert' => 0, 'delete' => 0, 'execute' => 1 },
                        write_permitted => $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{write_permitted},
                    });

                $rows_were_affected = $num_rows_affected ? 1 : 0;

                $logger->info("xT Form data ($form_ref->{name}) transfer done ($transfer_category, $sink_environment, @{[ uc($sink_site) ]}): $product_id \n");

            } ## END TRANSFER_CATEGORY

            #$logger->info("$form_ref->{name} transfer commit pending: $product_id \n");

        } ## END PRODUCT

        $status_msg = $rows_were_affected ? "Updated @{[ uc($sink_site) ]} $sink_environment" : '';

    };
    if ($@) {
        $logger->logcroak($@);
    }

    return $status_msg;

} ## END sub transfer_form_data



### Subroutine : transfer_custom_lists
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub transfer_custom_lists :Export(:transfer) {

    my ($arg_ref)           = @_;
    my $dbh_source          = $arg_ref->{dbh_source};
    my $dbh_sink_ref        = $arg_ref->{dbh_sink_ref};
    my $product_ids         = $arg_ref->{product_ids};

    my $dbh_sink            = $dbh_sink_ref->{dbh_sink};
    my $sink_environment    = $dbh_sink_ref->{sink_environment};
    my $sink_site           = $dbh_sink_ref->{sink_site};

    my $transfer_category   = 'catalogue_product';

    eval {

        my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

        PRODUCT:
        foreach my $product_id ( @{$product_ids_ref} ) {

            $logger->info("Custom List data transfer start ($transfer_category, @{[ uc($sink_site) ]} $sink_environment): $product_id");

            my $sink_data_ref
                = fetch_and_transform_data({
                        dbh_source          => $dbh_source,
                        sink_environment    => $sink_environment,
                        sink_site           => $sink_site,
                        transfer_category   => $transfer_category,
                        params              => { product_ids => $product_id, fields => 'keywords' },
                })->{sink_data};

            build_and_execute_sql({
                dbh             => $dbh_sink,
                data            => $sink_data_ref,
                action          => $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{default_sql_action},
                write_permitted => $TRANSFER_CATEGORY_ATTRIBUTE{$transfer_category}{write_permitted},
            });

            $logger->info("Custom List data transfer done ($transfer_category, @{[ uc($sink_site) ]} $sink_environment): $product_id \n");
            #$logger->info("Custom List data transfer commit pending: $product_id \n");

        } ## END PRODUCT

    };
    if ($@) {
        $logger->logcroak($@);
    }


    return;

} ## END sub transfer_custom_lists




################################################################################
# Source Data subs
################################################################################
#
#
#

### Subroutine : fetch_catalogue_product_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub fetch_catalogue_product_data :Export() {

    my ($arg_ref)            = @_;
    my $dbh                  = $arg_ref->{dbh};
    my $sink_environment     = $arg_ref->{sink_environment};
    my $sink_site            = $arg_ref->{sink_site};
    my $channel_id           = $arg_ref->{channel_id};
    my $product_ids          = $arg_ref->{product_ids};
    my $fields               = $arg_ref->{fields};
    my $use_optimized_upload = $arg_ref->{use_optimized_upload};

    my $TRANSFER_CATEGORY   = 'catalogue_product';
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $where_clause        = 'p.id IN (' . join(', ', @{$product_ids_ref}) . ')';

    ## If the optimized upload is being used, we just want the below fields to be passed to WebDB
    my @optimized_upload_fields = qw(product_id short_description name sort_order season_id product_type_id designer_id visible canonical_product_id);

    my $source_map_ref = {
        key_ref     => ['product_id'],
        field_ref   => {
            product_id          => [ ['id'] ],
            short_description   => [ ['short_description'] ],
            long_description    => [ ['long_description'],
                                        {
                                            transform   => [ \&src_tform_long_description, { dbh => $dbh, site => $sink_site, product_id => $product_ids } ],
                                        },
                                   ],
            name                => [ ['name'] ],
            keywords            => [ ['keywords', 'custom_lists'],
                                        {
                                            transform   => [ \&src_tform_concat ],
                                        },
                                   ],
            editors_comments    => [ ['editors_comments'],
                                        {
                                            transform   => [ \&src_tform_editors_comments, { dbh => $dbh, site => $sink_site, product_id => $product_ids } ],
                                        },
                                   ],
            size_fit            => [ ['size_fit'],
                                        {
                                            transform   => [ \&src_tform_size_fit, { dbh => $dbh, site => $sink_site, product_id => $product_ids } ],
                                        },
                                    ],
            sort_order          => [ ['sort_order'] ],
            season_id           => [ ['season_id'] ],
            product_type_id     => [ ['product_type_id'] ],
            designer_id         => [ ['designer_id'] ],
            visible             => [ ['visible'] ],
            related_facts       => [ ['related_facts'],
                                        {
                                            transform   => [ \&src_tform_related_facts, { dbh => $dbh, site => $sink_site, product_id => $product_ids } ],
                                        },
                                   ],
            canonical_product_id => [ ['canonical_product_id'] ],
            style_number         => [ ['style_number'] ],
        },
    };

    # Deleting all unecessary fields for this transfer category
    if ($use_optimized_upload) {
        $source_map_ref = _delete_unnecessary_fields($source_map_ref,\@optimized_upload_fields,$TRANSFER_CATEGORY);
    }

    ## specify validation subs to execute
    foreach my $field ( qw(name long_description) ) {
        my $check = $sink_environment eq 'live'    ? 'is_not_blank'
                  : $sink_environment eq 'staging' ? 'test_exception'
                  : undef;
        last unless $check; # What environment are we in?

        my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');
        my $channel = $schema->resultset('Public::Channel')->find($channel_id);
        $source_map_ref->{field_ref}{$field}[1]{validate} = [ \&_validate_format, { checks => $check } ];
    }

    my $filtered_source_map_ref = _create_filtered_source_map( { source_map => $source_map_ref, fields => $fields } );

    my $qry
        = qq{SELECT
                p.id
            ,   pa.short_description
            ,   pa.long_description
            ,   pa.name
            ,   pa.keywords
            ,   pa.custom_lists
            ,   pa.editors_comments
            ,   pa.size_fit
            ,   pso.sort_order
            ,   p.season_id
            ,   lpad(CAST(p.product_type_id AS varchar), 3, '0') as product_type_id
            ,   p.designer_id
            ,   CASE WHEN pch.visible is true THEN 'T' ELSE 'F' END AS visible
            ,   pa.related_facts
            ,   p.canonical_product_id
            ,   p.style_number
            FROM product p
            INNER JOIN product_attribute pa
                ON (p.id = pa.product_id)
            INNER JOIN product_channel pch
                ON (p.id = pch.product_id AND pch.channel_id = $channel_id)
            LEFT JOIN product.pws_sort_order pso
                ON (p.id = pso.product_id AND pso.channel_id = $channel_id AND pso.pws_sort_destination_id = (SELECT id FROM product.pws_sort_destination WHERE name = 'main'))
            WHERE $where_clause
            ORDER BY p.id
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref = results_list($sth);

    my $catalogue_product_data_ref  = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $filtered_source_map_ref,
        results_ref         => $results_ref,
    };

    return $catalogue_product_data_ref;

} ## END sub fetch_catalogue_product_data



### Subroutine : fetch_catalogue_attribute_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub fetch_catalogue_attribute_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $channel_id          = $arg_ref->{channel_id};
    my $product_ids         = $arg_ref->{product_ids};
    my $attributes          = $arg_ref->{attributes} eq 'all_attributes'
                            ? $ATTRIBUTE{catalogue}
                            : $arg_ref->{attributes}
                            ;

    my $TRANSFER_CATEGORY   = 'catalogue_attribute';
    my $attributes_ref      = _validate_items( { items => $attributes, type => 'catalogue_attribute' } );
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $where_clause        = 'attr.id IN (' . join(', ', @{$product_ids_ref}) . ')';

    my $source_map_ref  = {
        key_ref     => ['product_id', 'attribute_id'],
        field_ref   => {
            product_id      => [ ['product_id'] ],
            attribute_id    => [ ['attribute_id'] ],
            attribute_value => [ ['attribute_value'] ],
        },
    };

    ## specifiy validation subs to execute
    foreach ( qw(attribute_id attribute_value) ) {
        push @{ $source_map_ref->{field_ref}{$_} }, { validate => [ \&_validate_format, { checks => 'is_not_blank' } ] };
    }

    my %product_attribute_value = (
        WORLD               => q{lpad(CAST(p.world_id AS varchar), 2, '0')},
        DIVISION            => q{lpad(CAST(p.division_id AS varchar), 2, '0')},
        CLASSIFICATION      => q{lpad(CAST(p.classification_id AS varchar), 2, '0')},
        PRODUCT_TYPE        => q{lpad(CAST(p.product_type_id AS varchar), 3, '0')},
        SUB_TYPE            => q{lpad(CAST(p.sub_type_id AS varchar), 3, '0')},
        DESIGNER            => q{sku_padding(p.designer_id)},
        SEASON              => q{lpad(CAST(p.season_id AS varchar), 3, '0')},
        SIZE_CHART_CM       => q{''},
        SIZE_CHART_INCHES   => q{''},
        COLOUR
            => qq{(SELECT cast(cn.id AS varchar)
                    FROM product
                        INNER JOIN filter_colour_mapping fcm
                            ON product.colour_id = fcm.colour_id
                        INNER JOIN navigation_colour_mapping ncm
                            ON fcm.filter_colour_id = ncm.colour_filter_id AND ncm.channel_id = $channel_id
                        INNER JOIN colour_navigation cn
                            ON ncm.colour_navigation_id = cn.id
                    WHERE product.id = p.id)
            },
        SALE
            => qq{(SELECT CASE WHEN price_adjustment.percentage > 0 THEN 'T' ELSE 'F' END AS on_sale
                FROM product
                LEFT JOIN price_adjustment
                    ON product.id = price_adjustment.product_id
                    AND current_timestamp between price_adjustment.date_start AND price_adjustment.date_finish
                WHERE product.id = p.id)
            },
    );

    my @product_attribute_queries;

    foreach my $attribute ( @{$attributes_ref} ) {
        push @product_attribute_queries, qq{SELECT p.id, '$attribute' AS attribute_id, $product_attribute_value{$attribute} AS attribute_value FROM product p};
    }

    my $attribute_subquery  = @product_attribute_queries
                            ? join(' UNION ', @product_attribute_queries)
                            : q{SELECT 0 AS id, '' AS attribute_id, '' AS attribute_value}
                            ;

    my $qry
        = qq{SELECT attr.id AS product_id, attr.attribute_id, attr.attribute_value
             FROM ( $attribute_subquery ) attr
             WHERE $where_clause
        };
    #$logger->debug("$qry\n");

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my ($product_id, $attribute_id, $attribute_value);
    $sth->bind_columns(\($product_id, $attribute_id, $attribute_value));

    my $results_ref;

    while ( $sth->fetch() ) {

        if ( $attribute_id eq 'SIZE_CHART_CM' ) {
            $attribute_value = XTracker::Stock::Measurement::Edit::create_size_chart($product_id);
            next if $attribute_value =~ $FORMAT_REGEXP{empty_or_whitespace};
        }

        if ( $attribute_id eq 'SIZE_CHART_INCHES' ) {
            $attribute_value = XTracker::Stock::Measurement::Edit::create_size_chart($product_id, $INCHES_CONVERSION);
            next if $attribute_value =~ $FORMAT_REGEXP{empty_or_whitespace};
        }

        croak "Empty value for attribute '$attribute_id' is invalid" if $attribute_value =~ $FORMAT_REGEXP{empty_or_whitespace};

        my $record_ref = {
            product_id      => $product_id,
            attribute_id    => $attribute_id,
            attribute_value => $attribute_value
        };

        push @{$results_ref}, $record_ref;

    }

    my $catalogue_attribute_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $source_map_ref,
        results_ref         => $results_ref,
    };

    return $catalogue_attribute_data_ref;

} ## END sub fetch_catalogue_attribute_data



### Subroutine : fetch_list_attribute_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub fetch_list_attribute_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $channel_id          = $arg_ref->{channel_id};
    my $product_ids         = $arg_ref->{product_ids};
    my $attributes          = $arg_ref->{attributes} eq 'all_attributes'
                            ? $ATTRIBUTE{list}
                            : $arg_ref->{attributes}
                            ;

    my $TRANSFER_CATEGORY   = 'list_attribute';
    my $attributes_ref      = _validate_items( { items => $attributes, type => 'list_attribute' } );
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $where_clause        = 'attr.id IN (' . join(', ', @{$product_ids_ref}) . ')';

    my $source_map_ref  = {
        key_ref     => ['product_id', 'attribute_id'],
        field_ref   => {
            product_id      => [ ['product_id'] ],
            attribute_id    => [ ['attribute_id'] ],
            attribute_value => [ ['attribute_value'] ],
            sort_order      => [ ['sort_order'] ],
        },
        delete_field    => 'deleted',
    };

    ## specifiy validation subs to execute
    foreach ( qw(attribute_id attribute_value) ) {
        push @{ $source_map_ref->{field_ref}{$_} }, { validate => [ \&_validate_format, { checks => 'is_not_blank' } ] };
    }
#.
    my $qry = qq{SELECT
                pav.product_id
            ,   pat.web_attribute AS attribute_id
            ,   CASE WHEN pat.web_attribute = 'SLUG_IMAGE' THEN pa.name ELSE CAST(pa.id AS varchar) END AS attribute_value
            ,   pav.sort_order
            ,   pav.deleted
            FROM product.attribute_value pav
            INNER JOIN product.attribute pa
                ON (pav.attribute_id = pa.id AND pa.channel_id = ?)
            INNER JOIN product.attribute_type pat
                ON (pa.attribute_type_id = pat.id)
            WHERE pav.product_id IN ('@{[ join('\', \'', @{$product_ids_ref}) ]}')
            AND pat.web_attribute IN ('@{[ join('\', \'', @{$attributes_ref}) ]}')
        };
    #$logger->debug("$qry\n");

    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id );
    my $results_ref = results_list($sth);

    my $list_attribute_data_ref  = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $source_map_ref,
        results_ref         => $results_ref,
    };

    return $list_attribute_data_ref;

} ## END sub fetch_list_attribute_data



### Subroutine : fetch_navigation_attribute_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub fetch_navigation_attribute_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $channel_id          = $arg_ref->{channel_id};
    my $product_ids         = $arg_ref->{product_ids};
    my $attributes          = $arg_ref->{attributes} eq 'all_attributes'
                            ? $ATTRIBUTE{navigation}
                            : $arg_ref->{attributes}
                            ;

    my $TRANSFER_CATEGORY   = 'navigation_attribute';
    my $attributes_ref      = _validate_items( { items => $attributes, type => 'navigation_attribute' } );
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $where_clause        = 'attr.id IN (' . join(', ', @{$product_ids_ref}) . ')';

    my $source_map_ref  = {
        key_ref     => ['product_id', 'attribute_id'],
        field_ref   => {
            product_id      => [ ['product_id'] ],
            attribute_id    => [ ['attribute_id'] ],
            attribute_value => [ ['attribute_value'] ],
        },
        delete_field    => 'deleted',
    };

    ## specifiy validation subs to execute
    foreach ( qw(attribute_id attribute_value) ) {
        push @{ $source_map_ref->{field_ref}{$_} }, { validate => [ \&_validate_format, { checks => 'is_not_blank' } ] };
    }

    my $qry
        = qq{SELECT
                pav.product_id
            ,   pat.web_attribute AS attribute_id
            ,   CAST(pa.id AS varchar) as attribute_value
            ,   pav.deleted
            FROM product.attribute_value pav
            INNER JOIN product.attribute pa
                ON (pav.attribute_id = pa.id AND pa.channel_id = ?)
            INNER JOIN product.attribute_type pat
                ON (pa.attribute_type_id = pat.id)
            WHERE pav.product_id IN ('@{[ join('\', \'', @{$product_ids_ref}) ]}')
            AND pat.web_attribute IN ('@{[ join('\', \'', @{$attributes_ref}) ]}')
        };
    #$logger->debug("$qry\n");

    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id );
    my $results_ref = results_list($sth);

    my $navigation_attribute_data_ref  = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $source_map_ref,
        results_ref         => $results_ref,
    };

    return $navigation_attribute_data_ref;

} ## END sub fetch_list_attribute_data



### Subroutine : fetch_navigation_category_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub fetch_navigation_category_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $category_ids        = $arg_ref->{category_ids};

    my $TRANSFER_CATEGORY   = 'navigation_category';

    my $where_clause        = undef;

    if ( $category_ids ne 'all_categories' ) {
        my $category_ids_ref    = _validate_items( { items => $category_ids, type => 'id' } );
        $where_clause           = 'pa.id IN (' . join(', ', @{$category_ids_ref}) . ')';
    }


    my $source_map_ref  = {
        key_ref     => ['navigation_category_id'],
        field_ref   => {
            navigation_category_id  => [ ['id'] ],
            navigation_category     => [ ['name'] ],
            synonyms                => [ ['synonyms'] ],
            type_id                 => [ ['type'] ],
        },
        delete_field => 'deleted',
    };


    ## specifiy validation subs to execute
    foreach ( qw(navigation_category) ) {
        push @{ $source_map_ref->{field_ref}{$_} }, { validate => [ \&_validate_format, { checks => 'is_not_blank' } ] };
    }

    my $qry
        = qq{SELECT pa.id, pa.name, pa.deleted, pa.synonyms, pat.web_attribute as type
            FROM product.attribute pa, product.attribute_type pat
            WHERE pa.attribute_type_id = pat.id
        };
    $qry .= qq{ AND $where_clause} if defined $where_clause;

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref = results_list($sth);

    my $navigation_category_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $source_map_ref,
        results_ref         => $results_ref,
    };

    return $navigation_category_data_ref;

} ## END sub fetch_navigation_category_data



### Subroutine : fetch_navigation_tree_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub fetch_navigation_tree_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $node_ids            = $arg_ref->{node_ids};

    my $TRANSFER_CATEGORY   = 'navigation_tree';

    my $where_clause        = undef;

    if ( $node_ids ne 'all_nodes' ) {
        my $node_ids_ref    = _validate_items( { items => $node_ids, type => 'id' } );
        $where_clause       = 'pnt.id IN (' . join(', ', @{$node_ids_ref}) . ')';
    }

    my $source_map_ref  = {
        key_ref     => ['node_id'],
        field_ref   => {
            node_id                 => [ ['id'] ],
            category_id             => [ ['attribute_id'] ],
            parent_id               => [ ['parent_id'] ],
            sort_order              => [ ['sort_order'] ],
            type_id                 => [ ['web_attribute'] ],
            is_visible              => [ ['visible'] ],
            feature_product_id      => [ ['feature_product_id'] ],
            feature_product_image   => [ ['feature_product_image'] ],
        },
        delete_field => 'deleted',
    };

    ## specifiy validation subs to execute
    foreach ( qw(type_id) ) {
        push @{ $source_map_ref->{field_ref}{$_} }, { validate => [ \&_validate_format, { checks => 'is_not_blank' } ] };
    }

    my $qry
        = qq{SELECT
                pnt.id
            ,   pnt.attribute_id
            ,   pnt.parent_id
            ,   pnt.sort_order
            ,   pat.web_attribute
            ,   pnt.visible
            ,   pnt.deleted
            ,   pnt.feature_product_id
            ,   pnt.feature_product_image
            FROM product.navigation_tree pnt
            INNER JOIN product.attribute pa
                ON (pnt.attribute_id = pa.id)
            INNER JOIN product.attribute_type pat
                ON (pa.attribute_type_id = pat.id)
        };
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry .= qq{ ORDER BY pnt.id};

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref = results_list($sth);

    my $navigation_tree_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $source_map_ref,
        results_ref         => $results_ref,
    };

    return $navigation_tree_data_ref;

} ## END sub fetch_navigation_tree_data



### Subroutine : fetch_designer_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub fetch_designer_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $designer_ids        = $arg_ref->{designer_ids};
    my $channel_id          = $arg_ref->{channel_id};

    my $TRANSFER_CATEGORY   = 'designer';

    my $where_clause        = undef;

    if ( $designer_ids ne 'all_designers' ) {
        my $designer_ids_ref    = _validate_items( { items => $designer_ids, type => 'id' } );
        $where_clause           = 'd.id IN (' . join(', ', @{$designer_ids_ref}) . ')';
        $where_clause           .= ' AND dc.channel_id = '.$channel_id;
    }

    my $source_map_ref  = {
        key_ref     => ['designer_id'],
        field_ref   => {
            designer_id => [ ['id'] ],
            name        => [ ['name'] ],
            page_id     => [ ['page_id'] ],
            state       => [ ['state'] ],
            url_key     => [ ['url_key'] ],
            description => [ ['description'] ],
        },
    };

    ## specifiy validation subs to execute
    foreach ( qw(name state) ) {
        push @{ $source_map_ref->{field_ref}{$_} }, { validate => [ \&_validate_format, { checks => 'is_not_blank' } ] };
    }

    my $qry
        = qq{SELECT
                d.id
            ,   d.designer AS name
            ,   dc.page_id
            ,   dws.state
            ,   d.url_key
            ,   dc.description
            FROM    designer d,
                    designer_channel dc
                        INNER JOIN designer.website_state dws
                            ON dc.website_state_id = dws.id
            WHERE   d.id = dc.designer_id
        };
    $qry .= qq{ AND $where_clause}      if defined $where_clause;
    $qry .= qq{ ORDER BY d.id};

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref = results_list($sth);

    my $designer_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $source_map_ref,
        results_ref         => $results_ref,
    };

    return $designer_data_ref;

} ## END sub fetch_designer_data



### Subroutine : fetch_designer_attribute_type_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub fetch_designer_attribute_type_data :Export() {

    my ($arg_ref)                   = @_;
    my $dbh                         = $arg_ref->{dbh};
    my $sink_environment            = $arg_ref->{sink_environment};
    my $sink_site                   = $arg_ref->{sink_site};
    my $designer_attribute_type_ids = $arg_ref->{designer_attribute_type_ids};

    my $TRANSFER_CATEGORY   = 'designer_attribute_type';

    my $where_clause        = undef;

    if ( $designer_attribute_type_ids ne 'all_designer_attribute_types' ) {
        my $designer_attribute_type_ids_ref = _validate_items( { items => $designer_attribute_type_ids, type => 'id' } );
        $where_clause                       = 'id IN (' . join(', ', @{$designer_attribute_type_ids_ref}) . ')';
    }

    my $source_map_ref  = {
        key_ref     => ['web_attribute'],
        field_ref   => {
            web_attribute   => [ ['web_attribute'] ],
            type            => [ ['type'] ],
            version         => [ ['version'] ],
            sort_order      => [ ['sort_order'] ],
        },
    };

    my $qry
        = qq{SELECT
                web_attribute
            ,   'text' AS type
            ,   0 AS version
            ,   0 AS sort_order
            FROM designer.attribute_type
        };
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry .= qq{ ORDER BY id};

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref = results_list($sth);

    my $navigation_tree_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $source_map_ref,
        results_ref         => $results_ref,
    };

    return $navigation_tree_data_ref;

} ## END sub fetch_designer_attribute_type_data



### Subroutine : fetch_designer_attribute_value_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub fetch_designer_attribute_value_data :Export() {

    my ($arg_ref)                       = @_;
    my $dbh                             = $arg_ref->{dbh};
    my $sink_environment                = $arg_ref->{sink_environment};
    my $sink_site                       = $arg_ref->{sink_site};
    my $designer_attribute_value_ids    = $arg_ref->{designer_attribute_value_ids};

    my $TRANSFER_CATEGORY   = 'designer_attribute_value';

    my $where_clause        = undef;

    if ( $designer_attribute_value_ids ne 'all_designer_attribute_values' ) {
        my $designer_attribute_value_ids_ref    = _validate_items( { items => $designer_attribute_value_ids, type => 'id' } );
        $where_clause                           = 'dav.id IN (' . join(', ', @{$designer_attribute_value_ids_ref}) . ')';
    }

    my $source_map_ref  = {
        key_ref     => ['designer_id', 'attribute_id'],
        field_ref   => {
            designer_id     => [ ['designer_id'] ],
            attribute_id    => [ ['attribute_id'] ],
            attribute_value => [ ['value'] ],
            retailer_id     => [ ['retailer_id'] ],
            sort_order      => [ ['sort_order'] ],
        },
        delete_field    => 'deleted',
    };

    ## specifiy validation subs to execute
    foreach ( qw(attribute_value) ) {
        push @{ $source_map_ref->{field_ref}{$_} }, { validate => [ \&_validate_format, { checks => 'is_not_blank' } ] };
    }

    my $qry
        = qq{SELECT
                dav.designer_id
            ,   dat.web_attribute AS attribute_id
            ,   CAST(da.name AS varchar) AS value
            ,   NULL AS retailer_id
            ,   0 AS sort_order
            ,   dav.deleted
            FROM designer.attribute da
            INNER JOIN designer.attribute_value dav
                ON (dav.attribute_id = da.id)
            INNER JOIN designer.attribute_type dat
                ON (da.attribute_type_id = dat.id)
        };
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry .= qq{ ORDER BY dav.id};

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref = results_list($sth);

    my $list_attribute_data_ref  = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $source_map_ref,
        results_ref         => $results_ref,
    };

    return $list_attribute_data_ref;

} ## END sub fetch_designer_attribute_value_data



### Subroutine : fetch_catalogue_sku_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub fetch_catalogue_sku_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $channel_id          = $arg_ref->{channel_id};
    my $product_ids         = $arg_ref->{product_ids};
    my $fields              = $arg_ref->{fields};
    my $use_optimized_upload = $arg_ref->{use_optimized_upload};

    my $TRANSFER_CATEGORY   = 'catalogue_sku';
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $where_clause        = 'p.id IN (' . join(', ', @{$product_ids_ref}) . ') AND v.type_id = 1';
    my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');
    # APS-2637 has shown us that we can't trust that we'll always look up a
    # valid channel
    # We might as well die with something more helpful than:
    #     Can't call method "colour_detail_override" on an u ndefined value
    my $channel = $schema->resultset('Public::Channel')->find($channel_id);
    die qq{couldn't find a channel with id=$channel_id}
        if (not defined $channel);
    my $colour_clause;
    my $colour_table = "";
    if($channel->colour_detail_override)
    {
        $colour_clause = " colour ";
        $colour_table = " LEFT JOIN colour ON (colour.id = p.colour_id) ";
    }
    else
    {
        $colour_clause = " cf.colour_filter ";
    }

    ## If the optimized upload is being used, we just want the below fields to be passed to WebDB
    my @optimized_upload_fields = qw(sku product_id stock_ordered name);

    my $source_map_ref = {
        key_ref     => ['sku'],
        field_ref   => {
            sku                 => [ ['sku'] ],
            product_id          => [ ['product_id'] ],
            std_size_id         => [ ['std_size_id'] ],
            short_description   => [ ['short_description'] ],
            long_description    => [ ['long_description'],
                                        {
                                            transform   => [ \&src_tform_long_description, { dbh => $dbh, product_id => $product_ids } ],
                                        },
                                   ],
            name                => [ ['name'] ],
            editors_comments    => [ ['editors_comments'],
                                        {
                                            transform   => [ \&src_tform_editors_comments, { dbh => $dbh, product_id => $product_ids } ],
                                        },
                                   ],
            size_fit            => [ ['size_fit'],
                                        {
                                            transform   => [ \&src_tform_size_fit, { dbh => $dbh, product_id => $product_ids } ],
                                        },
                                   ],
            colour              => [ ['colour'] ],
            designer            => [ ['designer'] ],
            product_type_id     => [ ['product_type_id'] ],
            size                => [ ['designer_size'] ],
            hs_code             => [ ['hs_code'],
                                        {
                                            transform   => [ \&src_tform_hs_code ],
                                        },
                                   ],
            stock_ordered       => [ ['stock_ordered'] ],
            related_facts       => [ ['related_facts'],
                                        {
                                            transform   => [ \&src_tform_related_facts, { dbh => $dbh, product_id => $product_ids } ],
                                        },
                                   ],
        },
    };

    # Deleting all unecessary fields for this transfer category
    if ($use_optimized_upload) {
        $source_map_ref =_delete_unnecessary_fields($source_map_ref,\@optimized_upload_fields,$TRANSFER_CATEGORY);
    }

    ## specify validation subs to execute
    foreach my $field ( qw(name long_description) ) {
        my $check = $sink_environment eq 'live'    ? 'is_not_blank'
                  : $sink_environment eq 'staging' ? 'test_exception'
                  : undef;
        last unless $check; # What environment are we in?

        $source_map_ref->{field_ref}{$field}[1]{validate} = [ \&_validate_format, { checks => $check } ];
    }

    $source_map_ref->{field_ref}{hs_code}[1]{validate} = [ \&_validate_format, { checks => 'is_not_unknown' } ]
        if $sink_environment eq 'live';

    my $filtered_source_map_ref = _create_filtered_source_map( { source_map => $source_map_ref, fields => $fields } );

    my $qry
        = qq{SELECT
                v.product_id
            ,   v.product_id || '-' || sku_padding(v.size_id) as sku
            ,   v.std_size_id
            ,   pa.short_description
            ,   pa.long_description
            ,   pa.name
            ,   pa.editors_comments
            ,   pa.size_fit
            ,   $colour_clause AS colour
            ,   d.designer
            ,   lpad(CAST(p.product_type_id AS varchar), 3, '0') AS product_type_id
            ,   CASE
                    WHEN ss.short_name <> '' THEN ss.short_name || ' ' || s.size
                    ELSE s.size
                END AS designer_size
            ,   hs.hs_code
            ,   CASE
                    WHEN qty.variant_id IS NOT NULL THEN 'T'
                    WHEN soi.variant_id IS NULL THEN 'F'
                    ELSE 'T'
                END AS stock_ordered
            ,   pa.related_facts
            FROM product p
            INNER JOIN designer d
                ON (p.designer_id = d.id)
            INNER JOIN shipping_attribute sa
                ON (p.id = sa.product_id)
            INNER JOIN hs_code hs
                ON (p.hs_code_id = hs.id)
            INNER JOIN product_attribute pa
                ON (pa.product_id = p.id)
            INNER JOIN size_scheme ss
                ON (pa.size_scheme_id = ss.id)
            INNER JOIN variant v
                ON (v.product_id = p.id)
            INNER JOIN size s
                ON (v.designer_size_id = s.id)
            LEFT JOIN filter_colour_mapping fcm
                ON (p.colour_id = fcm.colour_id)
            INNER JOIN colour_filter cf
                ON (fcm.filter_colour_id = cf.id)
            $colour_table
            LEFT JOIN
                (SELECT DISTINCT variant_id
                FROM quantity
                WHERE channel_id = ?) qty
                ON (qty.variant_id = v.id)
            LEFT JOIN
                (SELECT DISTINCT soi.variant_id
                FROM stock_order_item soi, stock_order so, purchase_order po
                WHERE soi.cancel IS NOT True
                AND soi.stock_order_id = so.id
                AND so.purchase_order_id = po.id
                AND po.channel_id = ?) soi
                ON (soi.variant_id = v.id)
            WHERE $where_clause
            ORDER BY v.product_id, v.size_id
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id, $channel_id );
    my $results_ref = results_list($sth);

    my $catalogue_sku_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $filtered_source_map_ref,
        results_ref         => $results_ref,
    };

    return $catalogue_sku_data_ref;

} ## END sub fetch_catalogue_sku_data



### Subroutine : fetch_catalogue_pricing_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub fetch_catalogue_pricing_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $product_ids         = $arg_ref->{product_ids};
    my $fields              = $arg_ref->{fields};

    my $TRANSFER_CATEGORY   = 'catalogue_pricing';
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $where_clause        = 'prc.product_id IN (' . join(', ', @{$product_ids_ref}) . ')';

    my $source_map_ref = {
        key_ref     => ['id', 'sku', 'locality'],
        field_ref   => {
            id              => [ ['id'] ],
            sku             => [ ['sku'] ],
            price           => [ ['price'] ],
            locality        => [ ['locality'] ],
            locality_type   => [ ['locality_type'] ],
            currency        => [ ['currency'] ],
            is_visible      => [ ['is_visible'] ],
        },
    };

    ## specifiy validation subs to execute
    if ( $sink_environment eq 'live' ) {
        $source_map_ref->{field_ref}{price}[1]{validate}  = [ \&_validate_format, { checks => 'is_gtr_zero' } ];
    }

    my $filtered_source_map_ref = _create_filtered_source_map( { source_map => $source_map_ref, fields => $fields } );

    my $qry
        = qq{SELECT prc.*
            FROM (
                /* DEFAULT */
                SELECT
                    pd.product_id
                ,   pd.product_id || '-' || sku_padding(v.size_id) as sku
                ,   'DEFAULT' AS locality
                ,   'DEFAULT' AS locality_type
                ,   pd.price AS price
                ,   c.currency AS currency
                ,   'T' AS is_visible
                FROM product p
                INNER JOIN price_default pd
                    ON (pd.product_id = p.id)
                INNER JOIN currency c
                    ON (pd.currency_id = c.id)
                INNER JOIN variant v
                    ON (v.product_id = p.id)
                WHERE v.type_id = 1

                UNION

                /* TERRITORY */
                SELECT
                    pr.product_id
                ,   pr.product_id || '-' || sku_padding(v.size_id) as sku
                ,   r.region AS LOCALITY
                ,   'TERRITORY' AS locality_type
                ,   pr.price AS price
                ,   c.currency AS currency
                ,   'T' AS is_visible
                FROM product p
                INNER JOIN price_region pr
                    ON (pr.product_id = p.id)
                INNER JOIN region r
                    ON (pr.region_id = r.id)
                INNER JOIN currency c
                    ON (pr.currency_id = c.id)
                INNER JOIN variant v
                    ON (v.product_id = p.id)
                WHERE v.type_id = 1

                UNION

                /* COUNTRY */
                SELECT
                    pc.product_id
                ,   pc.product_id || '-' || sku_padding(v.size_id) as sku
                ,   ctry.code AS locality
                ,   'COUNTRY' AS locality_type
                ,   pc.price AS price
                ,   c.currency AS currency
                ,   'T' AS is_visible
                FROM product p
                INNER JOIN price_country pc
                    ON (pc.product_id = p.id)
                INNER JOIN country ctry
                    ON (pc.country_id = ctry.id)
                INNER JOIN currency c
                    ON (pc.currency_id = c.id)
                INNER JOIN variant v
                    ON (v.product_id = p.id)
                WHERE v.type_id = 1
            ) prc
            WHERE $where_clause
            ORDER BY prc.product_id, prc.locality_type, prc.currency
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref     = results_list($sth);

    ## deep copy $results_ref
    my $results_ref_2   = dclone($results_ref);

    ## add 'id' fields
    $_->{id} = 1 foreach ( @{$results_ref} );
    $_->{id} = 2 foreach ( @{$results_ref_2} );

    push @{$results_ref}, @{$results_ref_2};

    my $catalogue_pricing_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $filtered_source_map_ref,
        results_ref         => $results_ref,
    };

    return $catalogue_pricing_data_ref;

} ## END sub fetch_catalogue_pricing_data



### Subroutine : fetch_catalogue_markdown_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub fetch_catalogue_markdown_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $product_ids         = $arg_ref->{product_ids};
    my $fields              = $arg_ref->{fields};

    my $TRANSFER_CATEGORY   = 'catalogue_markdown';
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $where_clause        = 'pa.product_id IN (' . join(', ', @{$product_ids_ref}) . ')';

    my $source_map_ref = {
        key_ref     => ['sku', 'date_start'],
        field_ref   => {
            sku             => [ ['sku'] ],
            percentage      => [ ['percentage'] ],
            date_start      => [ ['date_start'] ],
            date_finish     => [ ['date_finish'] ],
            adjustment_type => [ ['adjustment_type'] ],
        },
    };
    my $filtered_source_map_ref = _create_filtered_source_map( { source_map => $source_map_ref, fields => $fields } );

    my $qry
        = qq{SELECT
                    pa.product_id
                ,   pa.product_id || '-' || sku_padding(v.size_id) as sku
                ,   (pa.percentage * -1) AS percentage
                ,   date_trunc('minute', pa.date_start) AS date_start
                ,   date_trunc('minute', pa.date_finish) AS date_finish
                ,   'Main Sale' AS adjustment_type
                FROM price_adjustment pa, variant v
                WHERE $where_clause
                AND v.product_id = pa.product_id
                AND v.type_id = 1
                ORDER BY pa.product_id, pa.date_start
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref     = results_list($sth);

    my $catalogue_markdown_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $filtered_source_map_ref,
        results_ref         => $results_ref,
    };

    return $catalogue_markdown_data_ref;

} ## END sub fetch_catalogue_markdown_data



### Subroutine : fetch_catalogue_ship_restriction_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub fetch_catalogue_ship_restriction_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $product_ids         = $arg_ref->{product_ids};
    my $fields              = $arg_ref->{fields};

    my $TRANSFER_CATEGORY   = 'catalogue_ship_restriction';
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $where_clause        = 'lpsr.product_id IN (' . join(', ', @{$product_ids_ref}) . ')';

    my $source_map_ref = {
        key_ref     => ['product_id', 'restriction_code', 'location', 'location_type'],
        field_ref   => {
            product_id          => [ ['product_id'] ],
            restriction_code    => [ ['restriction_code'] ],
            location            => [ ['location'] ],
            location_type       => [ ['location_type'] ],
        },
    };
    my $filtered_source_map_ref = _create_filtered_source_map( { source_map => $source_map_ref, fields => $fields } );

    my $qry
        = qq{SELECT
                    lpsr.product_id
                ,   sr.code AS restriction_code
                ,   srl.location
                ,   srl.type AS location_type
                FROM ship_restriction sr, ship_restriction_location srl, link_product__ship_restriction lpsr
                WHERE $where_clause
                AND lpsr.ship_restriction_id = sr.id
                AND sr.id = srl.ship_restriction_id
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref     = results_list($sth);

    my $catalogue_ship_restriction_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $filtered_source_map_ref,
        results_ref         => $results_ref,
    };

    return $catalogue_ship_restriction_data_ref;

} ## END sub fetch_catalogue_ship_restriction_data



### Subroutine : fetch_saleable_inventory_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub fetch_saleable_inventory_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $channel_id          = $arg_ref->{channel_id};
    my $product_ids         = $arg_ref->{product_ids};
    my $fields              = $arg_ref->{fields};

    my $TRANSFER_CATEGORY   = 'saleable_inventory';
    my $schema              = schema_handle();
    my $pws_stock_location  = $schema->resultset('Public::DistribCentre')->find_alias( $sink_site )->name;
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $having_clause       = 'saleable.product_id IN (' . join(', ', @{$product_ids_ref}) . ')';

    my $source_map_ref = {
        key_ref     => ['id', 'sku'],
        field_ref   => {
            id              => [ ['id'] ],
            sku             => [ ['sku'] ],
            quantity        => [ ['quantity'] ],
            is_sellable     => [ ['is_sellable'] ],
        },
    };
    my $filtered_source_map_ref = _create_filtered_source_map( { source_map => $source_map_ref, fields => $fields } );

    my $qry
        = qq{SELECT
                '$pws_stock_location' AS id
            ,   saleable.variant_id
            ,   saleable.product_id || '-' || saleable.size_id as sku
            ,   sum(saleable.quantity) AS quantity
            ,   'T' AS is_sellable
            FROM (
                    SELECT v.id AS variant_id, coalesce(sum(q.quantity), 0) AS quantity, v.product_id, sku_padding(v.size_id) as size_id
                    FROM variant v
                    LEFT JOIN quantity q
                        ON ( q.variant_id = v.id AND q.channel_id = ? AND q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS )
                    WHERE v.type_id = $VARIANT_TYPE__STOCK
                    GROUP BY v.id, v.product_id, v.size_id

                    UNION ALL

                    SELECT si.variant_id, -count(*) AS quantity, v.product_id, sku_padding(v.size_id) as size_id
                    FROM orders o, link_orders__shipment los, shipment_item si, variant v
                    WHERE si.variant_id = v.id
                    AND v.type_id = $VARIANT_TYPE__STOCK
                    AND si.shipment_item_status_id IN ( $SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED )
                    AND si.shipment_id = los.shipment_id
                    AND los.orders_id = o.id
                    AND o.channel_id = ?
                    GROUP BY si.variant_id, v.product_id, v.size_id

                    UNION ALL

                    SELECT si.variant_id, -count(*) AS quantity, v.product_id, sku_padding(v.size_id) as size_id
                    FROM stock_transfer st, link_stock_transfer__shipment lsts, shipment_item si, variant v
                    WHERE si.variant_id = v.id
                    AND v.type_id = $VARIANT_TYPE__STOCK
                    AND si.shipment_item_status_id IN ( $SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED )
                    AND si.shipment_id = lsts.shipment_id
                    AND lsts.stock_transfer_id = st.id
                    AND st.channel_id = ?
                    GROUP BY si.variant_id, v.product_id, v.size_id
                ) AS saleable
            GROUP BY saleable.variant_id, saleable.product_id, saleable.size_id
            HAVING $having_clause
            ORDER BY saleable.variant_id, saleable.product_id, saleable.size_id, sum(saleable.quantity)
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $arg_ref->{channel_id}, $arg_ref->{channel_id}, $arg_ref->{channel_id} );
    my $results_ref = results_list($sth);

    my $saleable_inventory_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $filtered_source_map_ref,
        results_ref         => $results_ref,
    };

    return $saleable_inventory_data_ref;

} ## END sub fetch_saleable_inventory_data



### Subroutine : fetch_product_sort_data
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub fetch_product_sort_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $channel_id          = $arg_ref->{channel_id};
    my $product_ids         = $arg_ref->{product_ids};
    my $destination         = defined $arg_ref->{destination} ? $arg_ref->{destination} : '';

    croak "Invalid destination ($destination).  Must be be 'preview' or 'main'" if $destination !~ m{\A(?:preview|main)\z}xms;
    croak "Undefined channel_id" if not defined $channel_id;

    if ( ($destination eq 'preview') && ($sink_environment ne 'staging') ) {
        croak "sink_environment must be 'staging' for product sort preview";
    }

    my $TRANSFER_CATEGORY   = 'product_sort';
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $where_clause        = 'pso.product_id IN (' . join(', ', @{$product_ids_ref}) . ')';
    $where_clause           .= ' AND psd.name = ?';

    my $source_map_ref = {
        key_ref     => ['product_id'],
        field_ref   => {
            product_id          => [ ['product_id'] ],
            sort_order          => [ ['sort_order'] ],
        },
    };

    my $qry
        = qq{SELECT
                pso.product_id
            ,   pso.sort_order
            FROM product.pws_sort_order pso
            INNER JOIN product.pws_sort_destination psd
                ON (pso.pws_sort_destination_id = psd.id)
            WHERE $where_clause
            AND pso.channel_id = ?
            ORDER BY pso.product_id
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($destination, $channel_id);
    my $results_ref = results_list($sth);

    my $product_sort_data_ref  = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $source_map_ref,
        results_ref         => $results_ref,
    };

    return $product_sort_data_ref;

} ## END sub fetch_product_sort_data



### Subroutine : fetch_related_product_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub fetch_related_product_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $channel_id          = $arg_ref->{channel_id};
    my $product_ids         = $arg_ref->{product_ids};

    my $TRANSFER_CATEGORY   = 'related_product';
    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );

    croak "colour_variation no longer handled by fetch_related_product_data method as the data is no longer stored in XTracker"
        if $arg_ref->{type} eq 'colour_variation';


    my $where_clause  = 'rp.product_id IN (' . join(', ', @{$product_ids_ref}) . ')';
       $where_clause .= q{ AND rpt.type = 'Recommendation' AND rp.channel_id = pch.channel_id};

    my $source_map_ref = {
        key_ref     => ['product_id', 'related_product_id', 'type'],
        field_ref   => {
            product_id          => [ ['product_id'] ],
            related_product_id  => [ ['recommended_product_id'] ],
            type                => [ ['type'] ],
            sort_order          => [ ['sort_order'] ],
            slot                => [ ['slot'] ],
        },
    };

    my $qry
        = qq{SELECT
                rp.product_id
            ,   rp.recommended_product_id
            ,   rp.sort_order
            ,   rp.slot
            ,   CASE rpt.type
                    WHEN 'Recommendation' THEN 'Recommended'
                    ELSE 'Unknown'
                END AS type
            FROM recommended_product rp
                    INNER JOIN recommended_product_type rpt ON rp.type_id = rpt.id
                    INNER JOIN product_channel pch ON rp.recommended_product_id = pch.product_id
                                                  AND pch.channel_id = ?
                                                  AND ( pch.live= true OR pch.staging = true )
            WHERE $where_clause
            ORDER BY rp.id, rp.recommended_product_id, rp.sort_order, rp.slot
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id );
    my $results_ref = results_list($sth);

    my $related_product_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $source_map_ref,
        results_ref         => $results_ref,
    };

    return $related_product_data_ref;

} ## END sub fetch_related_product_data



### Subroutine : fetch_web_cms_page_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub fetch_web_cms_page_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $page_ids            = $arg_ref->{page_ids};
    my $fields              = $arg_ref->{fields};

    my $TRANSFER_CATEGORY   = 'web_cms_page';
    my $page_ids_ref        = _validate_items( { items => $page_ids, type => 'id' } );

    my $where_clause        = 'id IN (' . join(', ', @{$page_ids_ref}) . ')';

    my $source_map_ref = {
        key_ref     => ['id'],
        field_ref   => {
            id          => [ ['id'] ],
            name        => [ ['name'] ],
            type_id     => [ ['type_id'] ],
            template_id => [ ['template_id'] ],
            page_key    => [ ['page_key'] ],
            channel     => [ ['channel'] ]
        },
    };

    my $filtered_source_map_ref = _create_filtered_source_map( { source_map => $source_map_ref, fields => $fields } );

    my $qry
        = qq{SELECT
                id
            ,   name
            ,   type_id
            ,   template_id
            ,   page_key
            ,   1 AS channel
            FROM web_content.page
            WHERE $where_clause
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref = results_list($sth);

    my $web_cms_page_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $filtered_source_map_ref,
        results_ref         => $results_ref,
    };

    return $web_cms_page_data_ref;

} ## END sub fetch_web_cms_page_data



### Subroutine : fetch_web_cms_page_instance_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub fetch_web_cms_page_instance_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $instance_ids        = $arg_ref->{instance_ids};
    my $fields              = $arg_ref->{fields};

    my $TRANSFER_CATEGORY   = 'web_cms_page_instance';
    my $instance_ids_ref    = _validate_items( { items => $instance_ids, type => 'id' } );

    my $where_clause        = 'wci.id IN (' . join(', ', @{$instance_ids_ref}) . ')';

    my $source_map_ref = {
        key_ref     => ['id'],
        field_ref   => {
            id              => [ ['id'] ],
            page_id         => [ ['page_id'] ],
            label           => [ ['label'] ],
            status          => [ ['status'] ],
            preview_hash    => [ ['preview_hash'] ],
            created         => [ ['created'] ],
            created_by      => [ ['created_by'] ],
            last_updated    => [ ['last_updated'] ],
            last_updated_by => [ ['last_updated_by'] ],
        },
    };

    my $filtered_source_map_ref = _create_filtered_source_map( { source_map => $source_map_ref, fields => $fields } );

    my $qry
        = qq{SELECT
                wci.id
            ,   wci.page_id
            ,   wci.label
            ,   upper(wcis.status) AS status
            ,   wci.id AS preview_hash
            ,   wci.created
            ,   op_created.name AS created_by
            ,   wci.last_updated
            ,   op_updated.name AS last_updated_by
            FROM web_content.instance wci
            INNER JOIN web_content.instance_status wcis
                ON (wci.status_id = wcis.id)
            LEFT JOIN operator op_created
                ON (wci.created_by = op_created.id)
            LEFT JOIN operator op_updated
                ON (wci.last_updated_by = op_updated.id)
            WHERE $where_clause
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref = results_list($sth);

    my $web_cms_page_instance_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $filtered_source_map_ref,
        results_ref         => $results_ref,
    };

    return $web_cms_page_instance_data_ref;

} ## END sub fetch_web_cms_page_instance_data



### Subroutine : fetch_web_cms_page_content_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub fetch_web_cms_page_content_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh                 = $arg_ref->{dbh};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $content_ids         = $arg_ref->{content_ids};
    my $fields              = $arg_ref->{fields};

    my $TRANSFER_CATEGORY   = 'web_cms_page_content';
    my $content_ids_ref     = _validate_items( { items => $content_ids, type => 'id' } );

    my $where_clause        = 'id IN (' . join(', ', @{$content_ids_ref}) . ')';

    my $source_map_ref = {
        key_ref     => ['id'],
        field_ref   => {
            instance_id             => [ ['instance_id'] ],
            field_id                => [ ['field_id'] ],
            content                 => [ ['content'] ],
            category_id             => [ ['category_id'] ],
            searchable_product_id   => [ ['searchable_product_id'] ],
            page_snippet_id         => [ ['page_snippet_id'] ],
            page_list_id            => [ ['page_list_id'] ],
        },
    };

    my $filtered_source_map_ref = _create_filtered_source_map( { source_map => $source_map_ref, fields => $fields } );

    my $qry
        = qq{SELECT
                instance_id
            ,   field_id
            ,   content
            ,   category_id
            ,   searchable_product_id
            ,   page_snippet_id
            ,   page_list_id
            FROM web_content.content
            WHERE $where_clause
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $results_ref = results_list($sth);

    my $web_cms_page_content_data_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        source_map_ref      => $filtered_source_map_ref,
        results_ref         => $results_ref,
    };

    return $web_cms_page_content_data_ref;

} ## END sub fetch_web_cms_page_content_data


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


################################################################################
# Data Validation Subs
################################################################################
# These validations are specified as code-refs in the source/sink mapping structures.
# Field values are passed in the parameter hash-ref 'source_fields'.
# Additional arguments may be passed in the parameter hash-ref 'extra_args'.
#
# N.B. These should return FALSE upon successful validation.
#

sub _validate_format :Export(:justfortest) {

    my ($arg_ref)           = @_;
    my $source_fields_ref   = $arg_ref->{source_fields};
    my $extra_args_ref      = $arg_ref->{extra_args};

    my $checks_ref          = $extra_args_ref->{checks};
    my $typeof_checks_ref   = ref($checks_ref);

    my %dispatch_check = (
        is_not_blank    => sub { my $source_val = shift; die "\n" if $source_val =~ $FORMAT_REGEXP{empty_or_whitespace}; },
        is_not_unknown  => sub { my $source_val = shift; die "\n" if $source_val =~ $FORMAT_REGEXP{empty_or_whitespace} || $source_val =~ m{\bUnknown\b}gi; },
        is_positive_int => sub { my $source_val = shift; die "\n" if $source_val !~ $FORMAT_REGEXP{int_positive}; },
        test_exception  => sub { my $source_val = shift; die "\n" if $source_val =~ m{\bvalidation_test_string\b}g; },
        is_gtr_zero     => sub { my $source_val = shift; die "\n" if ( ($source_val * 1) <= 0 ); },
    );

    if ( $typeof_checks_ref eq '' ) {
        croak "Invalid format validation check '$checks_ref'" unless grep {m{\A$checks_ref\z}xms} keys %dispatch_check;
        $checks_ref = [$checks_ref];
    }
    elsif ( $typeof_checks_ref eq 'ARRAY' ) {
        map { croak "Invalid format validation check '$_'" unless grep {m{\A$_\z}xms} keys %dispatch_check } @{$checks_ref};
    }
    else {
        croak "Invalid argument type ($typeof_checks_ref).  'checks' Must be string or array-ref";
    }


    my %failed  = ();

    my $arg_position  = 0;

    foreach my $source_field ( @{$source_fields_ref} ) {

        $arg_position++;

        foreach my $check ( @{$checks_ref} ) {

            eval {
                $dispatch_check{$check}->($source_field);
            };
            if ($@) {
                push @{ $failed{$arg_position} }, $check;
            }

        }

    }


    my @msg_failure = ();

    foreach my $arg_position ( keys %failed ) {
        push @msg_failure, "Arg $arg_position - (@{ [join( ', ', @{ $failed{$arg_position} } ) ] })";
    }

    if ( scalar @msg_failure ) {
        die "The following checks failed: @{[join('; ', @msg_failure)]}\n";
    }

    return 0;   ## success

} ## END _validate_format


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



################################################################################
# Data Transformation Subs
################################################################################
# These transformations are specified as code-refs in the mapping structures.
# Field values are passed in the parameter hash-ref 'source_fields'.
# Additional arguments may be passed in the parameter hash-ref 'extra_args'.
#

###########
# Generic
###########

sub src_tform_concat :Export() {

    my ($arg_ref)           = @_;
    my $source_fields_ref   = $arg_ref->{source_fields};
    my $extra_args_ref      = $arg_ref->{extra_args};
    return undef if scalar @{$source_fields_ref} == 0;
    return $source_fields_ref->[0] if scalar @{$source_fields_ref} == 1;
    my $concat_string   = defined $extra_args_ref->{concat_string} ? $extra_args_ref->{concat_string} : ' ';
    my $output = join( $concat_string, @{$source_fields_ref} );
    return $output;
} ## END sub src_tform_concat


##################
# Field-specific
##################
sub src_tform_editors_comments :Export() {

    my ($arg_ref)           = @_;
    my $source_fields_ref   = $arg_ref->{source_fields};
    my $extra_args_ref      = $arg_ref->{extra_args};
    my $dbh                 = $extra_args_ref->{dbh};
    my $site                = defined $extra_args_ref->{site} ? $extra_args_ref->{site} : '';
    my $product_id          = defined $extra_args_ref->{product_id} ? $extra_args_ref->{product_id} : '';
    return unless $product_id;
    my $editors_comments    = defined $source_fields_ref->[0] ? $source_fields_ref->[0] : '';
    return unless $editors_comments;

    my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');

    my $markup = XTracker::Markup->new({
        schema => $schema,
        product_id => $product_id,
    });

    return try {
        # Perform the transformation
        return $markup->editors_comments({
            editors_comments => $editors_comments,
            site => $site
        });
    }
    catch {
        # Return whatever we were given if there's a problem
        $logger->warn("There was a problem transforming the markup: $_");
        return $editors_comments;
    };

} ## END sub src_tform_editors_comments


sub src_tform_long_description :Export() {

    my ($arg_ref)           = @_;
    my $source_fields_ref   = $arg_ref->{source_fields};
    my $extra_args_ref      = $arg_ref->{extra_args};
    my $dbh                 = $extra_args_ref->{dbh};
    my $product_id          = defined $extra_args_ref->{product_id} ? $extra_args_ref->{product_id} : '';
    my $site                = defined $extra_args_ref->{site} ? $extra_args_ref->{site} : '';
    return unless $product_id;
    my $long_description = defined $source_fields_ref->[0] ? $source_fields_ref->[0] : '';
    return unless $long_description;

    my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');

    my $markup = XTracker::Markup->new({
        schema => $schema,
        product_id => $product_id,
    });

    return try {
        # Perform the transformation
        return $markup->long_description({
            long_description => $long_description,
            site => $site
        });
    }
    catch {
        # Return whatever we were given if there's a problem
        $logger->warn("There was a problem transforming the markup: $_ ");
        return $long_description;
    };

} ## END sub src_tform_long_description


sub src_tform_size_fit :Export() {

    my ($arg_ref)           = @_;
    my $source_fields_ref   = $arg_ref->{source_fields};
    my $extra_args_ref      = $arg_ref->{extra_args};
    my $dbh                 = $extra_args_ref->{dbh};
    my $product_id          = defined $extra_args_ref->{product_id} ? $extra_args_ref->{product_id} : '';
    my $site                = defined $extra_args_ref->{site} ? $extra_args_ref->{site} : '';
    return unless $product_id;
    my $output            = defined $source_fields_ref->[0] ? $source_fields_ref->[0] : '';
    return unless $output;

    my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');

    my $markup = XTracker::Markup->new({
        schema => $schema,
        product_id => $product_id,
    });

    return try {
        # Perform the transformation
        return $markup->size_fit({ size_fit => $output, site => $site });
    }
    catch {
        # Return whatever we were given if there's a problem
        $logger->warn("There was a problem transforming the markup: $_ ");
        return $output;
    };


} ## END sub src_tform_size_fit


sub src_tform_related_facts :Export() {

    my ($arg_ref)           = @_;
    my $source_fields_ref   = $arg_ref->{source_fields};
    my $extra_args_ref      = $arg_ref->{extra_args};
    my $dbh                 = $extra_args_ref->{dbh};
    my $product_id          = defined $extra_args_ref->{product_id} ? $extra_args_ref->{product_id} : '';
    my $site                = defined $extra_args_ref->{site} ? $extra_args_ref->{site} : '';
    return unless $product_id;
    my $related_facts            = defined $source_fields_ref->[0] ? $source_fields_ref->[0] : '';
    return unless $related_facts;

    my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');

    my $markup = XTracker::Markup->new({
        schema => $schema,
        product_id => $product_id,
    });

    return try {
        # Perform the transformation
        return $markup->related_facts({ related_facts => $related_facts, site => $site });
    }
    catch {
        # Return whatever we were given if there's a problem
        $logger->warn("There was a problem transforming the markup: $_ ");
        return $related_facts;
    };

} ## END sub src_tform_related_facts



sub src_tform_hs_code :Export() {

    my ($arg_ref)           = @_;
    my $source_fields_ref   = $arg_ref->{source_fields};
    my $extra_args_ref      = $arg_ref->{extra_args};

    my $hs_code = $source_fields_ref->[0];

    my $output  = $hs_code eq 'Unknown' ? undef : $hs_code;

    return $output;

} ## END sub src_tform_hs_code


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


################################################################################
# General selection, mapping and transfer subs
################################################################################

### Subroutine : get_transfer_source_handle
#
# usage        : $dbh_source = get_transfer_source_handle( { source_type => $source_type } );
# description  : returns an xT db handle - source for data transfer
# parameters   :
#              :
# returns      : xT database handle (source)
#
sub get_transfer_source_handle :Export(:transfer_handles) {

    my ($arg_ref)   = @_;
    my $source_type = defined $arg_ref->{source_type} ? $arg_ref->{source_type} : 'readonly';

    croak "Invalid source_type ($source_type).  Must be 'readonly' or 'transaction'" if $source_type !~ m{\A(?:readonly|transaction)\z}xms;

    my $source_name = $DBH_LOOKUP{source_name};

    my $dbh_source;

    eval {
        $dbh_source = get_database_handle( { name => $source_name, type => $source_type } );
        die "no db handle was returned for source '$source_name'\n" unless defined $dbh_source;
    };
    if ($@) {
        $logger->logcroak("Unable to get database handle: $@");
    }

    return $dbh_source;

} ## END get_transfer_source_handle



### Subroutine : get_transfer_sink_handle
#
# usage        : $dbh_sink_ref = get_transfer_sink_handle( { environment => $environment } );
# description  : returns a pws db handle - sink for data transfer
# parameters   :
#              :
# returns      : hashref : { dbh_sink => ?, sink_environment => ?, sink_site => ? }
#
sub get_transfer_sink_handle :Export(:transfer_handles) {

    my ($arg_ref)   = @_;
    my $environment = $arg_ref->{environment};
    my $channel     = $arg_ref->{channel};      # get sales channel config section

    croak "Invalid environment ($environment)" if $environment !~ m{\A(?:live|staging)\z}xms;
    croak "No channel defined " if !$channel;

    my $sink_name           = $DBH_LOOKUP{sink}{$environment}{sink_name};
    my $sink_environment    = $DBH_LOOKUP{sink}{$environment}{sink_environment};
    my $sink_site           = $DBH_LOOKUP{sink}{$environment}{sink_site};

    my $dbh_sink;

    my $sink_handle = $sink_name .'_'.$channel;

    eval {
        $dbh_sink = get_database_handle({
            name => $sink_handle,
            type => 'transaction'
        });
        die "no db handle was returned for sink '$sink_handle'\n" unless defined $dbh_sink;
    };
    if ($@) {
        $logger->logcroak("Unable to get database handle: $@");
    }

    my $dbh_sink_ref = {
        dbh_sink            => $dbh_sink,
        sink_environment    => $sink_environment,
        sink_site           => $sink_site,
    };

    return $dbh_sink_ref;

} ## END get_transfer_sink_handle



### Subroutine : get_transfer_db_handles
#
# usage        :
# description  :
# parameters   :
#              :
# returns      : hashref : { dbh_source => ?, dbh_sink => ?, sink_environment => ?, sink_site => ? }
#
sub get_transfer_db_handles :Export(:transfer_handles) {

    my ($arg_ref)   = @_;
    my $source_type = defined $arg_ref->{source_type} ? $arg_ref->{source_type} : 'readonly';
    my $environment = $arg_ref->{environment};
    my $channel     = $arg_ref->{channel};      # get sales channel config section

    croak "Invalid source_type ($source_type).  Must be 'readonly' or 'transaction'" if $source_type !~ m{\Areadonly|transaction\z}xms;
    croak "Invalid environment ($environment)" if $environment !~ m{\A(?:live|staging)\z}xms;

    my $source_name         = $DBH_LOOKUP{source_name};
    my $sink_name           = $DBH_LOOKUP{sink}{$environment}{sink_name}.'_'.$channel;
    my $sink_environment    = $DBH_LOOKUP{sink}{$environment}{sink_environment};
    my $sink_site           = $DBH_LOOKUP{sink}{$environment}{sink_site};

    my $dbh_source = $arg_ref->{dbh_source};
    my $dbh_sink;

    eval {
        $dbh_source ||= get_database_handle( { name => $source_name, type => $source_type } );
        $dbh_sink   = get_database_handle( { name => $sink_name, type => 'transaction' } );
        die "no db handle was returned for source '$source_name'\n" unless defined $dbh_source;
        die "no db handle was returned for sink '$sink_name'\n" unless defined $dbh_sink;
    };
    if ($@) {
        $logger->logcroak("Unable to get database handle: $@");
    }

    my $dbh_ref = {
        dbh_source          => $dbh_source,
        dbh_sink            => $dbh_sink,
        sink_environment    => $sink_environment,
        sink_site           => $sink_site,
    };

    return $dbh_ref;

} ## END sub get_transfer_db_handles


### Subroutine : toggle_the_sprocs
#
# usage        : $toggle_ok = toggle_the_sprocs( $web_xfer_dbh, $toggle, $hash_ptr_to_exceptions );
# description  : This stops the SPROCS that update product tables on the web-site from running which should
#                help the upload scripts to complete. It updates a table called 'system_status' and sets a
#                field called 'status_value' for a record with a 'status_key' of 'PRODUCT_UPLOAD' to either
#                1 (off) or 0 (on) meaning the product upload is running and the SPROCS can't run or the reverse.
#                The exceptions you pass in is a list of possible failures to update such as locking problems,
#                if a die is encountered when updating it will check $@ against this list and if the reason is
#                retryable it will then wait a second before retrying a maximum of 3 times.
# Parameters   : A Web Transfer DB Handle (from get_transfer_db_handles), Toggle either 'on' or 'off', A HASH
#                Ptr of exceptions to test for if the update fails with the die message as the key and a value
#                saying what to do next such as 'retry'.
# returns      : Returns 1 if updated successfully and 0 if not.
#
sub toggle_the_sprocs :Export() {

    my ( $web_xfer_dbh, $toggle, $exceptions )  = @_;

    my $toggle_value= ( uc($toggle) eq 'ON' ? '0' : '1' );

    die "No Web DB Connection!"     if ( !defined $web_xfer_dbh->{dbh_sink} );

    my $web_dbh     = $web_xfer_dbh->{dbh_sink};
    my $max_retries = 3;
    my $toggle_ok   = 0;

    my $sql =<<UPD
UPDATE system_status
    SET status_value    = ?,
        last_updated_dts= CURRENT_TIMESTAMP
WHERE status_key = 'PRODUCT_UPLOAD'
UPD
;
    my $upd_sth = $web_dbh->prepare( $sql );

    while ( $max_retries >= 0 ) {
        eval {
            $upd_sth->execute( $toggle_value );
        };
        if ( my $err = $@ ) {

            # check to see if it can retry
            my $action  = "";
            foreach my $exception ( keys %$exceptions ) {
                if ( $err =~ /$exception/ ) {
                    $action = $exceptions->{$exception};
                    last;
                }
            }

            if ( ( $action eq "retry" ) && ( $max_retries > 0 ) ) {
                $max_retries--;
            }
            else {
                die $err;
            }
        }
        else {
            $toggle_ok  = 1;
            last;
        }

        # wait before trying again
        sleep(1);
    }

    return $toggle_ok;
}


sub list_web_attributes :Export() {
    ##TODO
    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $attribute_type  = $arg_ref->{attribute_type};

    my $qry = undef;
    my @exec_args       = ();
    for ($attribute_type) {
        m{\Acatalogue\z}xms     && do { $qry = ''; push @exec_args, $attribute_type; last; };
        m{\Anavigation\z}xms    && do { $qry = 'SELECT * FROM product.attribute_type WHERE navigational IS True'; push @exec_args, $attribute_type; last; };
        m{\Adesigner\z}xms      && do { $qry = 'SELECT * FROM designer.attribute_type'; push @exec_args, $attribute_type; last; };
        m{\Alist\z}xms          && do { $qry = ''; push @exec_args, $attribute_type; last; };
        $logger->logcroak("Unknown attribute_type ($_)");
    }

}



### Subroutine : list_pids_to_upload
#
# usage        : my $pids_to_upload_ref = list_pids_to_upload( { dbh_ref => $dbh_ref, type => 'date' value => $date } );
# description  : list pids for a specified upload.  Exclude any which have already been uploaded if sink_environment is 'live'
# parameters   : dbh_ref (hashref, as returned by get_transfer_db_handles) : { dbh_source => ?, dbh_sink => ?, sink_environment => ?, sink_site => ? }
#              : upload_id
#              :
# returns      : array-ref; product_ids
#
sub list_pids_to_upload :Export() {

    my ($arg_ref)   = @_;
    my $dbh_ref     = $arg_ref->{dbh_ref};
    my $upload_date = $arg_ref->{upload_date};
    my $channel_id  = $arg_ref->{channel_id};

    my $dbh_source          = $dbh_ref->{dbh_source};
    my $dbh_sink            = $dbh_ref->{dbh_sink};
    my $sink_environment    = $dbh_ref->{sink_environment};

    my $qry_xt
        = qq{SELECT product_id
            FROM product_channel
            WHERE upload_date = ?
            AND channel_id = ?
            ORDER BY product_id
        };
    my $sth_xt = $dbh_source->prepare($qry_xt);
    $sth_xt->execute($upload_date, $channel_id);

    my $product_id_xt;
    $sth_xt->bind_columns(\$product_id_xt);

    my @upload_pids;
    while ( $sth_xt->fetch() ) {
        push @upload_pids, $product_id_xt;
    }

    ## if sink environment is not 'live', we're all done...
    if ( (not scalar @upload_pids) || ($sink_environment ne 'live') ) {
        return \@upload_pids;
    }

    ## ...if sink environment is 'live', double-check for pids which have already been uploaded, and exclude them
    ## (these should have been excluded by upload_status above, but it's not too painful to double-check)
    my $qry_pws = qq{SELECT id FROM searchable_product WHERE id IN (@{[ join(', ', @upload_pids) ]})};
    my $sth_pws = $dbh_sink->prepare($qry_pws);
    $sth_pws->execute();

    my $product_id_pws;
    $sth_pws->bind_columns(\$product_id_pws);

    my @uploaded_pids;
    while ( $sth_pws->fetch() ) {
        push @uploaded_pids, $product_id_pws;
    }

    my @pids_to_upload  = ();

    my %seen;
    @seen {@upload_pids} = ();
    delete @seen {@uploaded_pids};
    @pids_to_upload = sort { $a <=> $b } keys %seen;

    return \@pids_to_upload;

} ## END sub list_pids_to_upload



### Subroutine : get_upload_info
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub get_upload_info :Export(:transfer) {

    my ($arg_ref)   = @_;
    my $dbh_ref     = $arg_ref->{dbh_ref};
    my $type        = $arg_ref->{type};
    my $value       = $arg_ref->{value};

    my $dbh_source          = $dbh_ref->{dbh_source};
    my $dbh_sink            = $dbh_ref->{dbh_sink};
    my $sink_environment    = $dbh_ref->{sink_environment};


    ## build 'having' clause
    my $having_clause   = undef;
    my @exec_args       = ();
    for ($type) {
        m{\Aupload_id\z}xms     && do { $having_clause = 'u.id = ?'; push @exec_args, $value; last; };
        m{\Aupload_date\z}xms   && do { $having_clause = 'u.upload_date = ?'; push @exec_args, $value; last; };
        $logger->logcroak("Unknown type ($_)");
    }

    my $qry
        = qq{SELECT
                u.id AS upload_id
            ,   u.upload_date
            ,   to_char(u.upload_date, 'DD-Mon-YYYY') AS txt_upload_date
            ,   u.description
            ,   u.target_value
            ,   u.actual_value
            ,   count(up.product_id) AS number_of_products
            ,   u.upload_status_id
            ,   us.status AS upload_status
            FROM upload u
            INNER JOIN upload_product up
                ON (up.upload_id = u.id)
            INNER JOIN upload_status us
                ON (u.upload_status_id = us.id)
            GROUP BY u.id, u.upload_date, u.description, u.target_value, u.actual_value, u.upload_status_id, us.status
            HAVING $having_clause
            ORDER BY u.id
        };
    my $sth = $dbh_source->prepare($qry);
    $sth->execute(@exec_args);

    my $upload_info_ref = results_list($sth);

    return $upload_info_ref;

} ## END sub get_upload_info



### Subroutine : list_reservations
#
# usage        : my $reservations_ref = list_reservations( { dbh => $dbh_source, product_ids => $product_ids_ref } );
# description  :
# parameters   : dbh (object - database handle)
#              :
#              :
#              :
# returns      :
#
sub list_reservations :Export() {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $product_ids = $arg_ref->{product_ids};
    my $channel_id  = $arg_ref->{channel_id};

    my $product_ids_ref     = _validate_items( { items => $product_ids, type => 'id' } );
    my $where_clause        = 'r.status_id = 1 AND v.product_id IN (' . join(', ', @{$product_ids_ref}) . ')';

    # See CANDO-986: for an explanation for the use of 'COALESCE'
    my $qry
        = qq{SELECT
                r.id AS reservation_id
            ,   r.variant_id
            ,   v.product_id || '-' || sku_padding(v.size_id) as sku
            ,   c.is_customer_number
            ,   c.first_name
            ,   c.last_name
            ,   c.email
            ,   COALESCE( poisl.date, '2100-12-31 23:59:59' ) AS pre_order_item_log_date
            ,   poi.pre_order_id
            FROM reservation r
            INNER JOIN customer c
                ON (r.customer_id = c.id)
            INNER JOIN variant v
                ON (r.variant_id = v.id)
            LEFT JOIN pre_order_item poi ON poi.reservation_id = r.id
            LEFT JOIN pre_order_item_status_log poisl ON poisl.pre_order_item_id = poi.id
                                                      AND poisl.id = (
                                                            -- only want ONE row if more than one exists
                                                            SELECT  MIN(poisl2.id) AS poisl2_id
                                                            FROM    pre_order_item_status_log poisl2
                                                            WHERE   poisl2.pre_order_item_id = poi.id
                                                            AND     poisl2.pre_order_item_status_id = $PRE_ORDER_ITEM_STATUS__COMPLETE
                                                      )
            WHERE $where_clause
            AND r.channel_id = ?
            ORDER BY r.variant_id, pre_order_item_log_date, r.ordering_id
        };

    $logger->debug("\n$qry\n");

    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id );
    my $reservations_ref = results_list($sth);

    return $reservations_ref;

} ## END sub list_reservations



### Subroutine : fetch_and_transform_data
#
# usage        :
# description  :
# parameters   :
#              :
# returns      :
#
sub fetch_and_transform_data :Export() {

    my ($arg_ref)           = @_;
    my $dbh_source          = $arg_ref->{dbh_source};
    my $sink_environment    = $arg_ref->{sink_environment};
    my $sink_site           = $arg_ref->{sink_site};
    my $transfer_category   = $arg_ref->{transfer_category};
    my $param_ref           = $arg_ref->{params};
    my $use_optimized_upload = $arg_ref->{use_optimized_upload};

    croak "Invalid sink_site ($sink_site)" unless is_valid_region( $sink_site );
    croak "Ivalid sink_environment ($sink_environment)" if $sink_environment !~ $FORMAT_REGEXP{environment};

    $transfer_category      = lc($transfer_category);
    my $typeof_param_ref    = ref($param_ref);

    my $source_data_ref;

    if ( $transfer_category eq 'catalogue_product' ) {

        my $channel_id = $param_ref->{channel_id};
        croak 'No channel_id was specified' unless defined $channel_id;
        my $product_ids_ref = $param_ref->{product_ids};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        my $fields_ref      = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_catalogue_product_data({
                dbh                  => $dbh_source,
                sink_environment     => $sink_environment,
                sink_site            => $sink_site,
                product_ids          => $product_ids_ref,
                fields               => $fields_ref,
                channel_id           => $channel_id,
                use_optimized_upload => $use_optimized_upload
            });

    }
    elsif ( $transfer_category eq 'catalogue_attribute' ) {

        my $channel_id = $param_ref->{channel_id};
        croak 'No channel_id was specified' unless defined $channel_id;
        my $product_ids_ref = $param_ref->{product_ids};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        my $attributes_ref  = defined $param_ref->{attributes} ? $param_ref->{attributes} : 'all_attributes';

        $source_data_ref
            = fetch_catalogue_attribute_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                product_ids         => $product_ids_ref,
                attributes          => $attributes_ref,
                channel_id          => $channel_id,
            });

    }
    elsif ( $transfer_category eq 'navigation_attribute' ) {

        my $channel_id = $param_ref->{channel_id};
        croak 'No channel_id was specified' unless defined $channel_id;
        my $product_ids_ref = $param_ref->{product_ids};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        my $attributes_ref  = defined $param_ref->{attributes} ? $param_ref->{attributes} : 'all_attributes';

        $source_data_ref
            = fetch_navigation_attribute_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                product_ids         => $product_ids_ref,
                attributes          => $attributes_ref,
                channel_id          => $channel_id,
            });

    }
    elsif ( $transfer_category eq 'list_attribute' ) {

        my $channel_id = $param_ref->{channel_id};
        croak 'No channel_id was specified' unless defined $channel_id;
        my $product_ids_ref = $param_ref->{product_ids};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        my $attributes_ref  = defined $param_ref->{attributes} ? $param_ref->{attributes} : 'all_attributes';

        $source_data_ref
            = fetch_list_attribute_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                product_ids         => $product_ids_ref,
                attributes          => $attributes_ref,
                channel_id          => $channel_id,
            });

    }
    elsif ( $transfer_category eq 'catalogue_sku' ) {

        my $channel_id = $param_ref->{channel_id};
        croak 'No channel_id was specified' unless defined $channel_id;
        my $product_ids_ref = $param_ref->{product_ids};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        my $fields_ref      = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_catalogue_sku_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                product_ids         => $product_ids_ref,,
                fields              => $fields_ref,
                channel_id          => $channel_id,
                use_optimized_upload => $use_optimized_upload,
            });

    }
    elsif ( $transfer_category eq 'catalogue_pricing' ) {

        my $product_ids_ref = $param_ref->{product_ids};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        my $fields_ref      = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_catalogue_pricing_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                product_ids         => $product_ids_ref,
                fields              => $fields_ref,
            });

    }
    elsif ( $transfer_category eq 'catalogue_markdown' ) {

        my $product_ids_ref = $param_ref->{product_ids};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        my $fields_ref      = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_catalogue_markdown_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                product_ids         => $product_ids_ref,
                fields              => $fields_ref,
            });

        # set markdown exported status to true for current markdown
        # as required by reporting and internal XT functions
        _set_markdown_exported({
                dbh         => $dbh_source,
                product_ids => $product_ids_ref,
        });

    }
    elsif ( $transfer_category eq 'catalogue_ship_restriction' ) {

        my $product_ids_ref = $param_ref->{product_ids};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        my $fields_ref      = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_catalogue_ship_restriction_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                product_ids         => $product_ids_ref,
                fields              => $fields_ref,
            });

    }
    elsif ( $transfer_category eq 'saleable_inventory' ) {

        my $channel_id = $param_ref->{channel_id};
        croak 'No channel_id was specified' unless defined $channel_id;
        my $product_ids_ref = $param_ref->{product_ids};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        my $fields_ref      = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_saleable_inventory_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                product_ids         => $product_ids_ref,
                fields              => $fields_ref,
                channel_id          => $channel_id,
            });

    }
    elsif ( $transfer_category eq 'product_sort' ) {

        my $channel_id = $param_ref->{channel_id};
        croak 'No channel_id was specified' unless defined $channel_id;
        my $product_ids_ref = $param_ref->{product_ids};
        my $destination     = $param_ref->{destination};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        croak "Invalid destination ($destination).  Must be be 'preview' or 'main'" if $destination !~ m{\A(?:preview|main)\z}xms;
        my $fields_ref      = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_product_sort_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                product_ids         => $product_ids_ref,
                fields              => $fields_ref,
                destination         => $destination,
                channel_id          => $channel_id,
            });

    }
    elsif ( $transfer_category eq 'related_product' ) {

        my $channel_id = $param_ref->{channel_id};
        croak 'No channel_id was specified' unless defined $channel_id;
        my $product_ids_ref = $param_ref->{product_ids};
        croak 'No product_ids were specified' unless defined $product_ids_ref;
        my $fields_ref      = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_related_product_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                product_ids         => $product_ids_ref,
                fields              => $fields_ref,
                channel_id          => $channel_id,
            });
    }
    elsif ( $transfer_category eq 'navigation_category' ) {

        my $category_ids_ref = $param_ref->{category_ids};

        $source_data_ref
            = fetch_navigation_category_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                category_ids        => $category_ids_ref,
            });

    }
    elsif ( $transfer_category eq 'navigation_tree' ) {

        my $node_ids_ref = $param_ref->{node_ids};

        $source_data_ref
            = fetch_navigation_tree_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                node_ids            => $node_ids_ref,
            });

    }
    elsif ( $transfer_category eq 'designer' ) {

        my $designer_ids_ref    = $param_ref->{designer_ids};
        my $channel_id          = $param_ref->{channel_id};
        croak 'No designer_ids were specified'  unless defined $designer_ids_ref;
        croak 'No channel id was specified'     unless defined $channel_id;

        $source_data_ref
            = fetch_designer_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                designer_ids        => $designer_ids_ref,
                channel_id          => $channel_id
            });

    }
    elsif ( $transfer_category eq 'designer_attribute_type' ) {

        my $designer_attribute_type_ids_ref = $param_ref->{designer_attribute_type_ids};
        croak 'No designer_attribute_type_ids were specified' unless defined $designer_attribute_type_ids_ref;

        $source_data_ref
            = fetch_designer_attribute_type_data({
                dbh                         => $dbh_source,
                sink_environment            => $sink_environment,
                sink_site                   => $sink_site,
                designer_attribute_type_ids => $designer_attribute_type_ids_ref,
            });

    }
    elsif ( $transfer_category eq 'designer_attribute_value' ) {

        my $designer_attribute_value_ids_ref    = $param_ref->{designer_attribute_value_ids};
        croak 'No designer_attribute_value_ids were specified' unless defined $designer_attribute_value_ids_ref;

        $source_data_ref
            = fetch_designer_attribute_value_data({
                dbh                             => $dbh_source,
                sink_environment                => $sink_environment,
                sink_site                       => $sink_site,
                designer_attribute_value_ids    => $designer_attribute_value_ids_ref,
            });

    }
    elsif ( $transfer_category eq 'web_cms_page' ) {

        my $page_ids_ref    = $param_ref->{page_ids};
        croak 'No page_ids were specified' unless defined $page_ids_ref;
        my $fields_ref      = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_web_cms_page_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                page_ids            => $page_ids_ref,
                fields              => $fields_ref,
            });

    }
    elsif ( $transfer_category eq 'web_cms_page_instance' ) {

        my $instance_ids_ref    = $param_ref->{instance_ids};
        croak 'No instance_ids were specified' unless defined $instance_ids_ref;
        my $fields_ref          = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_web_cms_page_instance_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                instance_ids        => $instance_ids_ref,
                fields              => $fields_ref,
            });

    }
    elsif ( $transfer_category eq 'web_cms_page_content' ) {

        my $content_ids_ref = $param_ref->{content_ids};
        croak 'No content_ids were specified' unless defined $content_ids_ref;
        my $fields_ref      = defined $param_ref->{fields} ? $param_ref->{fields} : 'all_fields';

        $source_data_ref
            = fetch_web_cms_page_content_data({
                dbh                 => $dbh_source,
                sink_environment    => $sink_environment,
                sink_site           => $sink_site,
                content_ids         => $content_ids_ref,
                fields              => $fields_ref,
            });

    }
    else {
        $logger->logcroak("Invalid transfer category '$transfer_category'");
    }

#    $logger->debug('$source_data_ref: ', Dumper($source_data_ref), "\n\n");

    my $transfer_data_ref   = map_source_data( { source_data => $source_data_ref } );
#    $logger->debug('$transfer_data_ref: ', Dumper($transfer_data_ref), "\n\n");

    my $sink_data_ref       = map_sink_data( { transfer_data => $transfer_data_ref } );
#    $logger->debug('$sink_data_ref: ', Dumper($sink_data_ref), "\n\n");


    my $data_ref = {
        source_data     => $source_data_ref,
        transfer_data   => $transfer_data_ref,
        sink_data       => $sink_data_ref,
    };

    return $data_ref;

} ## END sub fetch_and_transform_data



### Subroutine : _transfer_reservation
#
# usage        :
# description  :
#              :
# parameters   :
#              :
# returns      :
#
sub _transfer_reservation :Export(:justfortest) {

    my ($arg_ref)               = @_;
    my $dbh_ref                 = $arg_ref->{dbh_ref};
    my $reservation_record_ref  = $arg_ref->{reservation_record};
    my $operator_id             = defined $arg_ref->{operator_id} ? $arg_ref->{operator_id} : 1;
    my $department_id           = defined $arg_ref->{department_id} ? $arg_ref->{department_id} : $DEPARTMENT__PERSONAL_SHOPPING;

    my $dbh_source              = $dbh_ref->{dbh_source};
    my $dbh_sink                = $dbh_ref->{dbh_sink};
    my $sink_environment        = $dbh_ref->{sink_environment};
    my $sink_site               = $dbh_ref->{sink_site};
    my $schema                  = schema_handle();
    my $pws_stock_location      = $schema->resultset('Public::DistribCentre')->find_alias( $sink_site )->name;
    my $stock_manager           = $arg_ref->{stock_manager};

    my $arg_error_msg = '';

    foreach ( qw(reservation_id variant_id is_customer_number) ) {
        $arg_error_msg .= "Invalid $_ ($reservation_record_ref->{$_})\n" if $reservation_record_ref->{$_} !~ $FORMAT_REGEXP{id};
    }

    $arg_error_msg .= "Invalid sku ($reservation_record_ref->{sku})\n" if $reservation_record_ref->{sku} !~ $FORMAT_REGEXP{sku};

    # not required fields
    #foreach ( qw(first_name last_name email) ) {
    #    $arg_error_msg .= "Invalid $_ ($reservation_record_ref->{$_})\n" if $reservation_record_ref->{$_} =~ $FORMAT_REGEXP{empty_or_whitespace};
    #}

    $arg_error_msg .= "Invalid operator_id ($operator_id)\n" if $operator_id !~ $FORMAT_REGEXP{id};
    $arg_error_msg .= "Invalid department_id ($department_id)\n" if $department_id !~ $FORMAT_REGEXP{id};

    die $arg_error_msg if $arg_error_msg;

    my $reservation_id      = $reservation_record_ref->{reservation_id};
    my $variant_id          = $reservation_record_ref->{variant_id};
    my $sku                 = $reservation_record_ref->{sku};
    my $is_customer_number  = $reservation_record_ref->{is_customer_number};
    my $first_name          = $reservation_record_ref->{first_name};
    my $last_name           = $reservation_record_ref->{last_name};
    my $email               = $reservation_record_ref->{email};

    # if the Reservation is for a Pre-Order then
    # we need to do something slightly different
    my $pre_order_flag      = ( $reservation_record_ref->{pre_order_id} ? 1 : 0 );

    my %key_data = (
        key_fields  => {
            customer_id => $is_customer_number,
            sku         => $sku,
        }
    );

    # check pws stock available
    my @exec_args = ($pws_stock_location, $sku);
    my $sql_pws_stock_check = q{SELECT no_in_stock FROM stock_location WHERE id = ? AND sku = ?};

    $logger->debug("$sql_pws_stock_check\n/*[", join("]*/\n/*[", @exec_args), "]*/\n\n\n");

    my $sth_check = $dbh_sink->prepare($sql_pws_stock_check);
    $sth_check->execute(@exec_args);

    my $free_stock_level  = $sth_check->fetchrow_arrayref()->[0];

    # free stock available to create reservation
    if ( $free_stock_level > 0 ) {

        if ($department_id == $DEPARTMENT__CUSTOMER_CARE) {

            upload_reservation(
                $dbh_source,
                $stock_manager,
                {
                    reservation_id => $reservation_id,
                    variant_id     => $variant_id,
                    operator_id    => $operator_id,
                    customer_nr    => $is_customer_number,
                    channel_id     => $stock_manager->channel_id,
                    reservation_expiry_date => "10 days",
                    product_reservation_upload => 1,
                }
            );

        }
        else {

            upload_reservation(
                $dbh_source,
                $stock_manager,
                {
                    reservation_id => $reservation_id,
                    variant_id     => $variant_id,
                    operator_id    => $operator_id,
                    customer_nr    => $is_customer_number,
                    channel_id     => $stock_manager->channel_id,
                    reservation_expiry_date => "1 day",
                    product_reservation_upload => 1,
                }
            );

        }

    }
    # no free stock available to create reservation
    else {

        $logger->info("No stock available to create reservation for customer: $is_customer_number\n");

    }

    return;

} ## END sub transfer_reservation



### Subroutine : _validate_items
#
# usage        : $items_ref = _validate_items( { items => $string_or_array_ref, type => 'id' } );
# description  : Checks that supplied item values have a valid format (very basic).
#              : Returns an array-ref, even if a single value is passed as a string.
# parameters   : string or array-ref
#              :
# returns      : array-ref: validated items values/s
#
sub _validate_items :Export(:justfortest) {

    my ($arg_ref)   = @_;
    my $items       = $arg_ref->{items};
    my $type        = defined $arg_ref->{type} ? $arg_ref->{type} : 'id';

    croak "Invalid format type ($type) specified" unless grep {m{\A$type\z}xms} keys %FORMAT_REGEXP;

    my $typeof_items = ref($items);

    if ( $typeof_items eq '' ) {
        $logger->logcroak("No items were specified (type: $type)") unless $items;
        $logger->logcroak("Invalid $type ($items)") if $items !~ $FORMAT_REGEXP{$type};
        $items = [$items];
    }
    elsif ( $typeof_items eq 'ARRAY' ) {
        $logger->logcroak("No items were specified (type: $type)") unless scalar @{$items};
        map { $logger->logcroak("Invalid $type ($_)") if $_ !~ $FORMAT_REGEXP{$type} } @{$items};
    }
    else {
        $logger->logcroak("Invalid argument type ($typeof_items).  'items' must be scalar or array ref.");
    }

    return $items;

} ## END sub _validate_items



### Subroutine : _create_filtered_source_map
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub _create_filtered_source_map :Export(:justfortest) {

    my ($arg_ref)       = @_;
    my $source_map_ref  = $arg_ref->{source_map};
    my $fields          = $arg_ref->{fields};

    my $typeof_fields   = ref($fields);
    my $fields_ref      = _validate_items( { items => $fields, type => 'db_object_name' } );

    my $source_map_keys_ref     = $source_map_ref->{key_ref};
    my $source_map_fields_ref   = $source_map_ref->{field_ref};
    my $source_map_delete_field = $source_map_ref->{delete_field};
    my $filtered_source_map_ref = { key_ref => $source_map_keys_ref };


    if ( lc($fields) eq 'all_fields' ) {
        return $source_map_ref;
    }
    elsif ( $typeof_fields eq '' ) {
        $fields_ref = [$fields];
    }
    elsif ( $typeof_fields eq 'ARRAY' ) {
        $fields_ref = $fields;
    }
    else {
        $logger->logcroak("Invalid argument type: 'fields' ($typeof_fields).  'fields' must be string (single field) or array-ref.");
    }

    ## add key field names
    push @{$fields_ref}, $_ foreach ( @{$source_map_keys_ref} );

    my @invalid_fields = ();

    foreach my $field_name ( @{$fields_ref} ) {
        push(@invalid_fields, $field_name) unless grep {m{\A$field_name\z}xms} keys %{$source_map_fields_ref};
        next if scalar @invalid_fields;
        $filtered_source_map_ref->{field_ref}{$field_name} = $source_map_fields_ref->{$field_name};
    }

    if ( (defined $source_map_delete_field) && ($source_map_delete_field =~ $FORMAT_REGEXP{db_object_name}) ) {
        $filtered_source_map_ref->{delete_field} = $source_map_delete_field;
    }

    if ( scalar @invalid_fields ) {
        $logger->logcroak("The following field/s are not present in the source mapping: '@{[join('\', \'', @invalid_fields)]}'");
    }

    return $filtered_source_map_ref;

} ## END sub _create_filtered_source_map



### Subroutine : map_source_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub map_source_data :Export() {

    my ($arg_ref)           = @_;
    my $source_ref          = $arg_ref->{source_data};

    my $source_map_key_ref      = $source_ref->{source_map_ref}{key_ref};
    my $source_map_field_ref    = $source_ref->{source_map_ref}{field_ref};
    my $source_map_delete_field = $source_ref->{source_map_ref}{delete_field};
    my $TRANSFER_CATEGORY       = $source_ref->{transfer_category};
    my $source_data_ref         = $source_ref->{results_ref};
    my $transfer_data_ref;

    SOURCE_RECORD:
    foreach my $source_record_ref ( @{$source_data_ref} ) {

        my $transfer_record_ref;

        TRANSFER_FIELD:
        foreach my $transfer_field_name ( keys %{$source_map_field_ref} ) {

            my @source_fields = ();

            SOURCE_FIELD:
            foreach my $source_field ( @{$source_map_field_ref->{$transfer_field_name}[0]} ) {
                push @source_fields, $source_record_ref->{$source_field};
            } ## END SOURCE_FIELD


            ## source validation
            eval {
                if ( ref($source_map_field_ref->{$transfer_field_name}[1]{validate}[0]) eq 'CODE' ) {
                    my $validation_coderef  = $source_map_field_ref->{$transfer_field_name}[1]{validate}[0];
                    my $extra_args_ref      = $source_map_field_ref->{$transfer_field_name}[1]{validate}[1];
                    ## execute source validation
                    $transfer_record_ref->{$transfer_field_name}
                        = $validation_coderef->( { extra_args => $extra_args_ref, source_fields => \@source_fields } );
                }
            };
            if ($@) {
                die "Source validation of '$transfer_field_name' failed: $@\n";
            }


            ## source transformation
            eval {
                if ( ref($source_map_field_ref->{$transfer_field_name}[1]{transform}[0]) eq 'CODE' ) {
                    my $tform_coderef   = $source_map_field_ref->{$transfer_field_name}[1]{transform}[0];
                    my $extra_args_ref  = $source_map_field_ref->{$transfer_field_name}[1]{transform}[1];

                    ## execute source transformation
                    $transfer_record_ref->{$transfer_field_name}
                        = $tform_coderef->( { extra_args => $extra_args_ref, source_fields => \@source_fields } );
                }
                else {
                    ## concatenate by default if multiple source fields are specified
                    if (scalar @source_fields > 1) {
                        $transfer_record_ref->{$transfer_field_name} = src_tform_concat( { source_fields => \@source_fields } );
                    }
                    else {
                        $transfer_record_ref->{$transfer_field_name} = $source_fields[0];
                    }
                }
            };
            if ($@) {
                die "Source transformation of '$transfer_field_name' failed: $@\n";
            }


            ## indicate if record is flagged for deletion
            if ( (defined $source_map_delete_field) && ($source_record_ref->{$source_map_delete_field} == 1) ) {
                $transfer_record_ref->{'[% FLAGGED_FOR_DELETION %]'} = 1;
            }

        } ## END TRANSFER_FIELD

        push @{$transfer_data_ref}, $transfer_record_ref;

    } ## END SOURCE_RECORD

    my $transfer_ref  = {
        transfer_category   => $TRANSFER_CATEGORY,
        transfer_data_ref   => $transfer_data_ref,
    };

    return $transfer_ref;

} ## END sub map_source_data



### Subroutine : map_sink_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub map_sink_data :Export() {

    my ($arg_ref)       = @_;
    my $transfer_ref    = $arg_ref->{transfer_data};

    my $TRANSFER_CATEGORY   = $transfer_ref->{transfer_category};
    my $transfer_data_ref   = $transfer_ref->{transfer_data_ref};
    my $sink_map_ref        = $DATA_SINK_MAP{$TRANSFER_CATEGORY};
    my $sink_data_ref;


    SINK_TABLE:
    foreach my $sink_table_name ( keys %{$sink_map_ref} ) {

        my $key_map_ref             = $sink_map_ref->{$sink_table_name}{key_field_map};
        my $field_map_ref           = $sink_map_ref->{$sink_table_name}{data_field_map};
        my $audit_insert_values_ref = $sink_map_ref->{$sink_table_name}{audit_insert_values};
        my $audit_update_values_ref = $sink_map_ref->{$sink_table_name}{audit_update_values};

        TRANSFER_RECORD:
        foreach my $transfer_record_ref ( @{$transfer_data_ref} ) {

            my $sink_record_ref;
            my $sink_record_fields_ref;

            ## get key data
            my $key_data_ref;
            foreach my $key_name ( keys %{ $key_map_ref->{key_fields} } ) {
                $logger->logcroak("Invalid field name ('$key_map_ref->{key_fields}{$key_name}') for key '$key_name'") if $key_map_ref->{key_fields}{$key_name} !~ $FORMAT_REGEXP{db_object_name};
                $key_data_ref->{key_fields}{ $key_map_ref->{key_fields}{$key_name} } = $transfer_record_ref->{$key_name};
            }

            ## add updateable key fields
            UPDATEABLE_KEY_FIELD:
            foreach my $updateable_key_field ( @{ $key_map_ref->{updateable_key_fields} } ) {
                push @{ $key_data_ref->{updateable_key_fields} }, $key_map_ref->{key_fields}{$updateable_key_field};
            }

            TRANSFER_FIELD:
            foreach my $transfer_field_name ( keys %{$transfer_record_ref} ) {

                eval {
                    if ( ref($field_map_ref->{$transfer_field_name}[1]) eq 'CODE' ) {
                        my $tform_coderef   = $field_map_ref->{$transfer_field_name}[1];
                        ## execute sink transformation
                        $transfer_record_ref->{$transfer_field_name}    = $tform_coderef->($transfer_record_ref->{$transfer_field_name});
                    }
                };
                if ($@) {
                    die "Sink transformation of '$transfer_field_name' failed: $@\n";
                }

                foreach my $sink_field_name ( @{ $field_map_ref->{$transfer_field_name}[0] } ) {
                    $sink_record_fields_ref->{$sink_field_name} = $transfer_record_ref->{$transfer_field_name};
                }

                ## indicate if record is flagged for deletion
                if ( (exists $transfer_record_ref->{'[% FLAGGED_FOR_DELETION %]'}) && ($transfer_record_ref->{'[% FLAGGED_FOR_DELETION %]'} == 1) ) {
                    $sink_record_ref->{flagged_for_deletion} = 1;
                }

                $sink_record_ref->{key_data}                = $key_data_ref;
                $sink_record_ref->{field_data}              = $sink_record_fields_ref;
                $sink_record_ref->{audit_insert_values}     = $audit_insert_values_ref if $audit_insert_values_ref;
                $sink_record_ref->{audit_update_values}     = $audit_update_values_ref if $audit_update_values_ref;

            } ## END TRANSFER_FIELD

            push @{ $sink_data_ref->{$sink_table_name} }, $sink_record_ref;

        } ## END TRANSFER_RECORD

    } ## END SINK_TABLE

    my $sink_ref = {
        transfer_category   => $TRANSFER_CATEGORY,
        sink_data_ref       => $sink_data_ref,
    };

    return $sink_ref;

} ## END sub map_sink_data



### Subroutine : build_and_execute_sql
#
# usage        : build_and_execute_sql( { dbh=> $dbh, data => $sink_ref, action => $action_ref, write_permitted => $write_permitted_ref } );
# description  : construct and execute an SQL insert/update statements
# parameters   : dbh (object - database handle)
#              : data (hash-ref - update table/field structure):-
#              :    {
#              :        table_name1 => [
#              :            {
#              :                key_data    => {
#              :                    key_name => key_value,
#              :                    ...,
#              :                },
#              :                field_data  => {
#              :                    field_name => value,
#              :                    ...,
#              :                },
#              :                audit_insert_values => {
#              :                    audit_field_name => audit_field_value,  ## e.g. last_inserted_by => 'XTRACKER'
#              :                    ...,
#              :                },
#              :                audit_update_values => {
#              :                    audit_field_name => audit_field_value,  ## e.g. last_updated_by => 'XTRACKER'
#              :                    ...,
#              :                },
#              :            },
#              :        ],
#              :        ...,
#              :    }
# returns      :
#
sub build_and_execute_sql :Export(:exec_sql) {
    ## no critic(ProhibitDeepNests)

    my ($arg_ref)            = @_;
    my $dbh_trans            = $arg_ref->{dbh};
    my $data_ref             = $arg_ref->{data};
    my $action_ref           = $arg_ref->{action};
    my $write_permitted_ref  = $arg_ref->{write_permitted};
    my $use_optimized_upload = $arg_ref->{use_optimized_upload};

    my $TRANSFER_CATEGORY    = $data_ref->{transfer_category};
    my $sink_data_ref        = $data_ref->{sink_data_ref};

    my $action_update        = $action_ref->{'update'}   ? 1 : 0;
    my $action_insert        = $action_ref->{'insert'}   ? 1 : 0;
    my $action_delete        = $action_ref->{'delete'}   ? 1 : 0;
    my $action_execute       = defined $action_ref->{'execute'}  ? $action_ref->{'execute'} : 1;
    $action_execute          = $action_execute ? 1 : 0;

    my $num_rows_affected    = undef;

    my $t0 = [gettimeofday];
    my $optimized_sql_compilation;
    my $queries_executed = 0;
    TABLE:
    foreach my $table_name ( keys %{$sink_data_ref} ) {
        die "Invalid table name ('$table_name')\n" if $table_name !~ $FORMAT_REGEXP{db_object_name};

        unless ( grep {m{\A$table_name\z}xms} @{$write_permitted_ref} ) {
            die "Table '$table_name' does not appear on the write-permitted list for transfer_category '$TRANSFER_CATEGORY'\n";
        }

        RECORD:
        foreach my $record_ref ( @{ $sink_data_ref->{$table_name} } ) {

            my $key_data_ref            = $record_ref->{key_data};
            my $field_data_ref          = $record_ref->{field_data};
            my @field_names             = keys %{ $field_data_ref };
            my $flagged_for_deletion    = defined $record_ref->{flagged_for_deletion} ? $record_ref->{flagged_for_deletion} : 0;
            $flagged_for_deletion       = $flagged_for_deletion ? 1 : 0;
            my $audit_insert_values_ref = $record_ref->{audit_insert_values};
            my $audit_update_values_ref = $record_ref->{audit_update_values};
            my $sql_statement           = '';
            my $exec_args_ref;


            if ( !$action_delete && !$action_update && $action_insert ) {

                if ( !$flagged_for_deletion ) {

                    ## add audit_insert_values
                    foreach ( keys %{$audit_insert_values_ref} ) {
                        $field_data_ref->{$_} = $audit_insert_values_ref->{$_};
                        if ( $field_data_ref->{$_} eq '[% CURRENT_DATETIME %]' ) {
                            $field_data_ref->{$_} = _current_datetime();
                        }
                    }

                    ($sql_statement, $exec_args_ref)
                        = _build_sql_insert( { table_name => $table_name, field_data => $field_data_ref } );

                }

            }
            elsif ( !$action_delete && $action_update && !$action_insert ) {

                if ( !$flagged_for_deletion ) {

                    if ( _record_exists( { dbh => $dbh_trans, table_name => $table_name, key_data => $key_data_ref } ) ) {

                        ## add audit_update_values
                        foreach ( keys %{$audit_update_values_ref} ) {
                            $field_data_ref->{$_} = $audit_update_values_ref->{$_};
                            if ( $field_data_ref->{$_} eq '[% CURRENT_DATETIME %]' ) {
                                $field_data_ref->{$_} = _current_datetime();
                            }
                        }

                        ($sql_statement, $exec_args_ref)
                            = _build_sql_update( { table_name => $table_name, key_data => $key_data_ref, field_data => $field_data_ref } );

                    }

                }

            }
            elsif ( !$action_delete && $action_update && $action_insert ) {

                if ( !$flagged_for_deletion ) {

                    if ( _record_exists( { dbh => $dbh_trans, table_name => $table_name, key_data => $key_data_ref } ) ) {

                        ## add audit_update_values
                        foreach ( keys %{$audit_update_values_ref} ) {
                            $field_data_ref->{$_} = $audit_update_values_ref->{$_};
                            if ( $field_data_ref->{$_} eq '[% CURRENT_DATETIME %]' ) {
                                $field_data_ref->{$_} = _current_datetime();
                            }
                        }

                        ($sql_statement, $exec_args_ref)
                            = _build_sql_update( { table_name => $table_name, key_data => $key_data_ref, field_data => $field_data_ref } );

                    }
                    else {

                        ## add audit_insert_values
                        foreach ( keys %{$audit_insert_values_ref} ) {
                            $field_data_ref->{$_} = $audit_insert_values_ref->{$_};
                            if ( $field_data_ref->{$_} eq '[% CURRENT_DATETIME %]' ) {
                                $field_data_ref->{$_} = _current_datetime();
                            }
                        }

                        ($sql_statement, $exec_args_ref)
                            = _build_sql_insert( { table_name => $table_name, field_data => $field_data_ref } );
                    }

                }

            }
            elsif ( $action_delete && !$action_update && !$action_insert ) {

                if ( $flagged_for_deletion ) {

                    ($sql_statement, $exec_args_ref)
                        = _build_sql_delete( { table_name => $table_name, key_data => $key_data_ref } );

                }

            }
            elsif ( $action_delete && !$action_update && $action_insert ) {

                if ( $flagged_for_deletion ) {

                    ($sql_statement, $exec_args_ref)
                        = _build_sql_delete( { table_name => $table_name, key_data => $key_data_ref } );

                }
                else {

                    ## add audit_insert_values
                    foreach ( keys %{$audit_insert_values_ref} ) {
                        $field_data_ref->{$_} = $audit_insert_values_ref->{$_};
                        if ( $field_data_ref->{$_} eq '[% CURRENT_DATETIME %]' ) {
                            $field_data_ref->{$_} = _current_datetime();
                        }
                    }

                    ($sql_statement, $exec_args_ref)
                        = _build_sql_insert( { table_name => $table_name, field_data => $field_data_ref } );

                }

            }
            elsif ( $action_delete && $action_update && !$action_insert ) {

                if ( $flagged_for_deletion ) {

                    ($sql_statement, $exec_args_ref)
                        = _build_sql_delete( { table_name => $table_name, key_data => $key_data_ref } );

                }
                elsif ( _record_exists( { dbh => $dbh_trans, table_name => $table_name, key_data => $key_data_ref } ) ) {

                    ## add audit_update_values
                    foreach ( keys %{$audit_update_values_ref} ) {
                        $field_data_ref->{$_} = $audit_update_values_ref->{$_};
                        if ( $field_data_ref->{$_} eq '[% CURRENT_DATETIME %]' ) {
                            $field_data_ref->{$_} = _current_datetime();
                        }
                    }

                    ($sql_statement, $exec_args_ref)
                        = _build_sql_update( { table_name => $table_name, key_data => $key_data_ref, field_data => $field_data_ref } );

                }

            }
            elsif ( $action_delete && $action_update && $action_insert ) {

                if ( $flagged_for_deletion ) {

                    ($sql_statement, $exec_args_ref)
                        = _build_sql_delete( { table_name => $table_name, key_data => $key_data_ref } );

                }
                elsif ( _record_exists( { dbh => $dbh_trans, table_name => $table_name, key_data => $key_data_ref } ) ) {

                    ## add audit_update_values
                    foreach ( keys %{$audit_update_values_ref} ) {
                        $field_data_ref->{$_} = $audit_update_values_ref->{$_};
                        if ( $field_data_ref->{$_} eq '[% CURRENT_DATETIME %]' ) {
                            $field_data_ref->{$_} = _current_datetime();
                        }
                    }

                    ($sql_statement, $exec_args_ref)
                        = _build_sql_update( { table_name => $table_name, key_data => $key_data_ref, field_data => $field_data_ref } );

                }
                else {

                    ## add audit_insert_values
                    foreach ( keys %{$audit_insert_values_ref} ) {
                        $field_data_ref->{$_} = $audit_insert_values_ref->{$_};
                        if ( $field_data_ref->{$_} eq '[% CURRENT_DATETIME %]' ) {
                            $field_data_ref->{$_} = _current_datetime();
                        }
                    }

                    ($sql_statement, $exec_args_ref)
                        = _build_sql_insert( { table_name => $table_name, field_data => $field_data_ref } );

                }

            }


            if ( $sql_statement and scalar @{$exec_args_ref} ) {

                my $sql_comment = $action_execute   ? "\n" : " -- SQL Execution suppressed!\n";

                #TODO: Comment this line before sending this code live, it's just to understand what sql queries are being executed
                #$logger->info("$sql_statement $sql_comment/*[", join("]*/\n/*[", @{$exec_args_ref}), "]*/\n\n");

                if($use_optimized_upload){
                    push @{$optimized_sql_compilation->{$sql_statement}}, $exec_args_ref;
                }else{
                    my $sth = $dbh_trans->prepare($sql_statement);

                    if ($action_execute) {
                        $num_rows_affected = 0;
                        $num_rows_affected = $sth->execute( @{$exec_args_ref} );
                        $queries_executed++;
                    }
                }

            }
            else {
                my $msg_debug   = "No SQL statement was generated - table: $table_name\n";
                $msg_debug     .= "key_ref: @{[ Dumper($key_data_ref) ]}\n";
                $msg_debug     .= "action_ref: @{[ Dumper($action_ref) ]}\n\n";
                $logger->debug($msg_debug);
            }

        } ## END RECORD

    } ## END TABLE

    if($use_optimized_upload && $action_execute){
        $logger->info("UPOP: Grouping the same SQL queries: ");
        for my $st ( keys %$optimized_sql_compilation ) {
            my $sth = $dbh_trans->prepare($st);
            my $repetitions = scalar (@{ $optimized_sql_compilation->{$st} });

            if($repetitions == 1){
                # Just one repetition, executing the query the usual way
                $sth->execute( @{$optimized_sql_compilation->{$st}->[0]} );
                $queries_executed++;
                next;
            }

            my $number_of_args = scalar @{$optimized_sql_compilation->{$st}->[0]};

            my ($human_readable_st) = $st =~ m#^([^(]+)#;
            $logger->info("UPOP: Statement \"$human_readable_st\" has $number_of_args arguments and is repeated $repetitions times");

            my $bind_params;

            for my $n ( 0 .. $number_of_args-1 ) {
                for my $arg_list ( @{ $optimized_sql_compilation->{$st} } ) {
                    push @{ $bind_params->{$n+1} }, $arg_list->[$n];
                }
            }

            for my $k ( sort { $a <=> $b } keys %$bind_params ) {
                $sth->bind_param_array($k, $bind_params->{$k});
            }

            $sth->execute_array( { ArrayTupleStatus => \my @tuple_status } );
            $queries_executed += $repetitions;

        }
    }
    my $time_taken = tv_interval ( $t0 );
    $logger->info("UPOP: build_and_execute_sql done in $time_taken Seconds; $queries_executed queries executed. ".($queries_executed > 0 ? ($time_taken/$queries_executed)." seconds per query." : ""));
    return $num_rows_affected;

} ## END build_and_execute_sql



### Subroutine : _record_exists
#
# usage        :
# description  :
# parameters   :
#              :
# returns      :
#
sub _record_exists :Export(:justfortest) {

    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $table_name      = $arg_ref->{table_name};
    my $key_data_ref    = $arg_ref->{key_data};

    $logger->logcroak("Invalid table name ('$table_name')") if $table_name !~ $FORMAT_REGEXP{db_object_name};
    $logger->logcroak("Invalid parameter type; 'key_data' must be a hash-ref") if ref($key_data_ref) ne 'HASH';

    my @key_names           = ();
    my @key_values          = ();
    my @where_clause_terms  = ();

    foreach my $key_name ( keys %{ $key_data_ref->{key_fields} } ) {
        $logger->logcroak("Invalid key name ('$key_name')") if $key_name !~ $FORMAT_REGEXP{db_object_name};
        unshift @key_names, $key_name;
        unshift @where_clause_terms, "$key_name = ?";
        unshift @key_values, $key_data_ref->{key_fields}{$key_name};
    }

    my $qry = qq|SELECT @{[join(', ', @key_names)]} FROM $table_name WHERE @{[join(' AND ', @where_clause_terms)]}|;
    $logger->debug("RECORD EXISTS\n------------------\n$qry\n/*[", join("]*/\n/*[", @key_values), "]*/\n\n\n");
    my $sth = $dbh->prepare($qry);
    $sth->execute(@key_values);

    my $results_ref = results_list($sth);
    my $num_rows    = scalar @{$results_ref};

    $logger->logcroak("Supplied key is not unique in:\n$qry") if $num_rows > 1;

    return $num_rows;

} ## END sub _record_exists



### Subroutine : _build_sql_update
#
# usage        :
# description  :
# parameters   :
#              :
# returns      :
#
sub _build_sql_update :Export(:justfortest) {

    my ($arg_ref)       = @_;
    my $table_name      = $arg_ref->{table_name};
    my $key_data_ref    = $arg_ref->{key_data};
    my $field_data_ref  = $arg_ref->{field_data};

    $logger->logcroak("Invalid table name ('$table_name')") if $table_name !~ $FORMAT_REGEXP{db_object_name};
    $logger->logcroak('No fields were specified') unless keys %{$field_data_ref};

    my @set_list_fields     = ();
    my @where_clause_terms  = ();
    my $where_clause        = '';
    my @exec_args           = ();

    FIELD:
    foreach my $field_name ( keys %{$field_data_ref} ) {
        $logger->logcroak("Invalid fieldname ('$field_name')") if $field_name !~ $FORMAT_REGEXP{db_object_name};

        ## skip non-updateable key fields
        my $participates_in_key   = grep {m{\A$field_name\z}xmsi} keys %{ $key_data_ref->{key_fields} };
        my $is_updateable         = grep {m{\A$field_name\z}xmsi} @{ $key_data_ref->{updateable_key_fields} };
        next FIELD if ($participates_in_key && !$is_updateable);

        push @set_list_fields, $field_name;
        push @exec_args, $field_data_ref->{$field_name};
    }

    $logger->logcroak("Error building UPDATE statement") unless scalar @set_list_fields;

    KEY_FIELD:
    foreach my $key_field_name ( keys %{ $key_data_ref->{key_fields} } ) {
        $logger->logcroak("Invalid key fieldname ('$key_field_name')") if $key_field_name !~ $FORMAT_REGEXP{db_object_name};
        push @where_clause_terms, "$key_field_name = ?";
        push @exec_args, $key_data_ref->{key_fields}{$key_field_name};
    }
    $where_clause = join(' AND ', @where_clause_terms);

    my $str_set_list    = join(' = ?, ', @set_list_fields) . ' = ?';
    my $sql_update      = qq{UPDATE $table_name SET $str_set_list WHERE $where_clause};

    @exec_args = _encode_data(\@exec_args);

    return ($sql_update, \@exec_args);

} ## END sub _build_sql_update



### Subroutine : _build_sql_insert
#
# usage        :
# description  :
# parameters   :
#              :
# returns      :
#
sub _build_sql_insert :Export(:justfortest) {

    my ($arg_ref)       = @_;
    my $table_name      = $arg_ref->{table_name};
    my $field_data_ref  = $arg_ref->{field_data};

    $logger->logcroak("Invalid table name ('$table_name')") if $table_name !~ $FORMAT_REGEXP{db_object_name};
    $logger->logcroak('No fields were specified') unless keys %{$field_data_ref};

    my @insert_fields   = ();
    my @exec_args       = ();

    FIELD:
    foreach my $field_name ( keys %{$field_data_ref} ) {
        $logger->logcroak("Invalid fieldname ('$field_name')") if $field_name !~ $FORMAT_REGEXP{db_object_name};
        push @insert_fields, $field_name;
        push @exec_args, $field_data_ref->{$field_name};
    }

    my $str_insert_list = '(' . join(', ', @insert_fields) . ')';
    my $sql_insert      = "INSERT INTO $table_name $str_insert_list VALUES (" . '?, ' x ( scalar(@insert_fields) -1 ) . '?)';

    @exec_args = _encode_data(\@exec_args);

    return ($sql_insert, \@exec_args);

} ## END sub _build_sql_insert



### Subroutine : _build_sql_delete
#
# usage        :
# description  :
# parameters   :
#              :
# returns      :
#
sub _build_sql_delete :Export(:justfortest) {

    my ($arg_ref)       = @_;
    my $table_name      = $arg_ref->{table_name};
    my $key_data_ref    = $arg_ref->{key_data};
    my $field_data_ref  = $arg_ref->{field_data};

    $logger->logcroak("Invalid table name ('$table_name')") if $table_name !~ $FORMAT_REGEXP{db_object_name};
    $logger->logcroak('No key fields were specified') unless keys %{ $key_data_ref->{key_fields} };

    my $where_clause;
    my @key_fields      = ();
    my $key_conditions;
    my @exec_args       = ();

    KEY_FIELD:
    foreach my $key_field_name ( keys %{ $key_data_ref->{key_fields} } ) {
        my $key_field_value = $key_data_ref->{key_fields}{$key_field_name};
        $logger->logcroak("Invalid key field name ('$key_field_name')") if $key_field_name !~ $FORMAT_REGEXP{db_object_name};
        $logger->logcroak("Invalid vaule for key field '$key_field_name'") unless ( (defined $key_field_value) and ($key_field_value !~ $FORMAT_REGEXP{empty_or_whitespace}) );
        push @key_fields, $key_field_name;
        push @exec_args, $key_field_value;
    }
    $where_clause   = join(' = ? AND ', @key_fields) . ' = ?';


    my @nonkey_fields       = ();
    my $nonkey_conditions;
    my @nonkey_exec_args    = ();

    NONKEY_FIELD:
    foreach my $nonkey_field_name ( keys %{$field_data_ref} ) {
        my $nonkey_field_value = $field_data_ref->{$nonkey_field_name};
        $logger->logcroak("Invalid fieldname ('$nonkey_field_name')") if $nonkey_field_name !~ $FORMAT_REGEXP{db_object_name};
        push @nonkey_fields, $nonkey_field_name;
        push @nonkey_exec_args, $nonkey_field_value;
    }


    if ( scalar @nonkey_fields ) {
        $nonkey_conditions = join(' = ? AND ', @nonkey_fields) . ' = ?';
        $where_clause .= ' AND ' . $nonkey_conditions;
        push(@exec_args, @nonkey_exec_args);
    }

    my $sql_delete  = "DELETE FROM $table_name WHERE $where_clause";

    @exec_args = _encode_data(\@exec_args);

    return ($sql_delete, \@exec_args);

} ## END sub _build_sql_delete



### Subroutine : _encode_data
#
# usage        :
# description  :
# parameters   :
#              :
#              :
#              :
#              :
# returns      :
#
sub _encode_data :Export(:justfortest) {

    my $data            = shift;

    my $typeof_data     = ref($data);
    my $this_function   = (caller(0))[3];
    my @encoded_data;

    if ( $typeof_data eq '' ) {
        push @encoded_data, encode($OUTPUT_ENCODING, decode_it($data));
    }
    elsif ( $typeof_data eq 'ARRAY' ) {
        @encoded_data = map {encode($OUTPUT_ENCODING, decode_it($_))} @{$data};
    }
    else {
        $logger->logcroak("$this_function: Invalid argument format ($typeof_data).");
    }


    return wantarray ? @encoded_data : $encoded_data[0];

} ## END sub _encode_data



### Subroutine : _current_datetime
#
# usage        : my $now = _current_datetime()
# description  :
# parameters   : none
#              :
#              :
# returns      : current date and time string in format: YYYY-MM-DD HH:MM:SS
#
sub _current_datetime {

    my ($second, $minute, $hour, $day, $month, $year) = (localtime)[0..5];
    $month  += 1;
    $year   += 1900;

    for ($second, $minute, $hour, $day, $month) {
        $_ = sprintf "%02u", $_;
    }

    my $current_datetime = "$year-$month-$day $hour:$minute:$second";

    return $current_datetime;

} ## END sub _current_datetime



### Subroutine : db_log_ref_is_valid
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub validate_log_ref :Export(:justfortest) {

    my $db_log_ref  = shift;
    my $operator_id = defined $db_log_ref->{operator_id} ? $db_log_ref->{operator_id} : '';
    my $transfer_id = defined $db_log_ref->{transfer_id} ? $db_log_ref->{transfer_id} : '';

    my $operator_id_is_valid    = $operator_id =~ $FORMAT_REGEXP{id};
    my $transfer_id_is_valid    = $transfer_id =~ $FORMAT_REGEXP{id};
    my $dbh_log_is_valid        = ref($db_log_ref->{dbh_log}) =~ m{\ADBI::db\z}xms;

    if ( $operator_id_is_valid && $transfer_id_is_valid && $dbh_log_is_valid ) {
        $db_log_ref->{dbh_log}{AutoCommit} = 1;
        return $db_log_ref;
    }
    else {
        return 0;
    }

} ## END sub db_log_ref_is_valid



### Subroutine : _validate_data_mapping
#
# usage        :
# description  : check the consistency and integrity of the source/sink mapping hashes
# parameters   :
#              :
#              :
# returns      :
#
sub _validate_data_mapping {

    my ($arg_ref)           = @_;
    my $transfer_category   = $arg_ref->{transfer_category};
    my $source_map_ref      = $arg_ref->{source_map};

    my $source_map_keys_ref     = $source_map_ref->{key_ref};
    my $source_map_fields_ref   = $source_map_ref->{field_ref};

    my $sink_key_field_map      = $DATA_SINK_MAP{$transfer_category}{key_field_map};
    my $sink_data_field_map     = $DATA_SINK_MAP{$transfer_category}{data_field_map};

    ##TODO

    foreach my $key ( @{$source_map_keys_ref} ) {

    }

} ## END sub _validate_data_mapping


### Subroutine : set_pws_visibility
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub set_pws_visibility :Export(:pws_visibility) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $product_ids = $arg_ref->{product_ids};
    my $type        = $arg_ref->{type};
    my $visible     = $arg_ref->{visible};

    croak "Invalid value for argument 'visible' ($visible). Must be '1' or '0'" unless $visible =~ m{\A(?:1|0)\z}xms;

    my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

    for ($type) {
        m{\Aproduct\z}xmsi  && do { set_pws_visibility_product( { dbh => $dbh, product_ids => $product_ids_ref, visible => $visible } ); last; };
        m{\Apricing\z}xmsi  && do { set_pws_visibility_pricing( { dbh => $dbh, product_ids => $product_ids_ref, visible => $visible } ); last; };
        croak "Unknown type ($_)";
    }

    return;

} ## end sub set_pws_visibility



### Subroutine : set_pws_visibility_product
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub set_pws_visibility_product :Export(:pws_visibility) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $product_ids = $arg_ref->{product_ids};
    my $visible     = $arg_ref->{visible};

    croak "Invalid value for argument 'visible' ($visible). Must be '1' or '0'" unless $visible =~ m{\A(?:1|0)\z}xms;
    $visible = $visible ? 'T' : 'F';

    my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

    my $sql_update
        = qq{UPDATE searchable_product SET is_visible = ? WHERE id IN (@{[ join(', ', @{$product_ids_ref}) ]})};

    $logger->info("Setting visibility: searchable_product - $visible - @{[ join(', ', @{$product_ids_ref}) ]})");
    $logger->debug("$sql_update\n/*[$visible]*/\n\n\n");

    my $sth = $dbh->prepare($sql_update);
    $sth->execute($visible);

    return;

} ## END sub set_pws_visibility_product



### Subroutine : set_pws_visibility_pricing
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub set_pws_visibility_pricing :Export(:pws_visibility) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $product_ids = $arg_ref->{product_ids};
    my $visible     = $arg_ref->{visible};

    croak "Invalid value for argument 'visible' ($visible). Must be '1' or '0'" unless $visible =~ m{\A(?:1|0)\z}xms;
    $visible = $visible ? 'T' : 'F';

    my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

    $logger->info("Setting visibility: channel_pricing - $visible - @{[ join(', ', @{$product_ids_ref}) ]})");

    my $sql_update      = q{UPDATE channel_pricing SET is_visible = ?};
    my $where_clause    = " WHERE (sku LIKE '";
    $where_clause       .= join( "-%' OR sku LIKE '", @{$product_ids_ref} );
    $where_clause       .= "-%')";
    $sql_update         .= $where_clause;

    $logger->debug("$sql_update\n/*[$visible]*/\n\n\n");

    my $sth = $dbh->prepare($sql_update);
    $sth->execute($visible);

    return;

} ## END sub set_pws_visibility_pricing




### Subroutine : set_xt_product_status
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub set_xt_product_status :Export() {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $channel_id  = $arg_ref->{channel_id};
    my $product_ids = $arg_ref->{product_ids};
    my $live        = $arg_ref->{live};
    my $staging     = $arg_ref->{staging};
    my $visible     = $arg_ref->{visible};

    my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

    my @update_terms    = ();

    if ( defined $live ) {
        croak "Invalid value for argument 'live'.  Must be 1 or 0" unless $live =~ m{\A(?:1|0)\z}xms;
        $live = $live ? 'True' : 'False';
        push @update_terms, qq{live = $live};
    }

    if ( defined $staging ) {
        croak "Invalid value for argument 'staging'.  Must be 1 or 0" unless $staging =~ m{\A(?:1|0)\z}xms;
        $staging = $staging ? 'True' : 'False';
        push @update_terms, qq{staging = $staging};
    }

    if ( defined $visible ) {
        croak "Invalid value for argument 'visible'.  Must be 1 or 0" unless $visible =~ m{\A(?:1|0)\z}xms;
        $visible = $visible ? 'True' : 'False';
        push @update_terms, qq{visible = $visible};
    }

    my $sql = qq{UPDATE product_channel SET @{[ join(', ', @update_terms) ]} WHERE channel_id = ? AND product_id IN (@{[ join(', ', @{$product_ids_ref}) ]}) };
    my $sth = $dbh->prepare($sql);
    $sth->execute( $channel_id );

    return;

} ## END sub set_xt_product_status



### Subroutine : _set_markdown_exported
#
# usage        :
# description  :
# parameters   :
# returns      :
#
sub _set_markdown_exported :Export() {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $product_ids = $arg_ref->{product_ids};

    my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

    # set old markdowns as exported = false
    my $sql = qq{UPDATE price_adjustment SET exported = false WHERE date_finish < current_date AND product_id IN (@{[ join(', ', @{$product_ids_ref}) ]}) };
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    # set current markdown as exported = true
    $sql = qq{UPDATE price_adjustment SET exported = true WHERE date_finish > current_date AND product_id IN (@{[ join(', ', @{$product_ids_ref}) ]}) };
    $sth = $dbh->prepare($sql);
    $sth->execute();

    return;

} ## END sub _set_markdown_exported


### Subroutine : clear_catalogue_ship_restriction
#
# usage        : clear_catalogue_ship_restriction( $dbh, $prod_id)
# description  : deletes all entries in shipping_restriction table website database for the given PID
# parameters   : website db handle, pid
# returns      : nothing
#
sub clear_catalogue_ship_restriction :Export() {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $product_ids = $arg_ref->{product_ids};

    my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

    # set old markdowns as exported = false
    my $sql = qq{DELETE FROM shipping_restriction WHERE pid IN (@{[ join(', ', @{$product_ids_ref}) ]}) };
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    return;

} ## END sub clear_catalogue_ship_restriction


### Subroutine : set_xt_upload_status
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub set_xt_upload_status :Export() {

    my ($arg_ref)   = @_;
    my $dbh_ref     = $arg_ref->{dbh_ref};
    my $upload_id   = $arg_ref->{upload_id};
    my $status      = $arg_ref->{status};

    $logger->logcroak("Invalid upload_id ($upload_id)") if $upload_id !~ $FORMAT_REGEXP{id};

    my $dbh_source          = $dbh_ref->{dbh_source};
    my $sink_environment    = $dbh_ref->{sink_environment};

    my $sql = qq{UPDATE upload SET upload_status_id = ? WHERE id = ?};
    my $sth = $dbh_source->prepare($sql);
    $sth->execute($upload_id);

    return;

} ## END sub set_xt_upload_status



### Subroutine : set_pws_whats_new
#
# usage        :
# description  :
# parameters   :
#              :
#              :
# returns      :
#
sub set_pws_whats_new :Export() {

    my ($arg_ref)   = @_;
    my $dbh_ref     = $arg_ref->{dbh_ref};
    my $product_ids = $arg_ref->{product_ids};

    my $product_ids_ref = _validate_items( { items => $product_ids, type => 'id' } );

    my $dbh_sink            = $dbh_ref->{dbh_sink};
    my $sink_environment    = $dbh_ref->{sink_environment};

    my $sql_set_old
        = qq{UPDATE searchable_product SET
                created_dts = DATE_SUB(created_dts, INTERVAL 1 YEAR)
             WHERE created_dts > current_timestamp - interval 1 month
        };
    my $sth_set_old = $dbh_ref->{dbh_sink}->prepare($sql_set_old);

    my $sql_set_new
        = qq{UPDATE searchable_product SET
                last_updated_dts = now(),
                created_dts = now()
            WHERE id IN (@{[ join(', ', @{$product_ids_ref}) ]})
        };
    my $sth_set_new = $dbh_ref->{dbh_sink}->prepare($sql_set_new);

    $logger->debug("\n$sql_set_new\n");

    $sth_set_old->execute();
    $sth_set_new->execute();


    return;

} ## END sub set_pws_whats_new

{

    my $regions;

    sub is_valid_region {
        my $region = lc shift;
        my $prefix = lc ( shift || '' );

        unless ( $prefix eq '' ) {
        # If a prefix was passed in, we need to check it matches
        # and strip it of $region.

            if ( $region =~ /^$prefix(.+)$/ ) {

                $region = $1;

            } else {

                return 0;

            }

        }

        unless ( $regions ) {

            # Get schema handle.
            my $schema = schema_handle;

            # Create a cached result of all regions.
            $regions = [ map { lc }
                $schema
                    ->resultset('Public::DistribCentre')
                    ->get_column('alias')
                    ->all
            ];

        }

        return grep {/^$region$/} @$regions;

    }

}

################################################################################
# Schema metadata utilities
################################################################################
#
#
#

### Subroutine : _get_pk_column_names
#
# usage        : $pk_column_names_ref = _get_pk_column_names( { dbh => $dbh, table => 'table_name' } );
# description  : list primary key columns for a specified table.  Works with Postgres and MySQL.
# parameters   : dbh (object - database handle)
#              : table_name (scalar)
#              :
# returns      : array-ref - primary key columns listed in index order
#
sub _get_pk_column_names :Export(:justfortest) {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $table_name  = $arg_ref->{table};

    my $driver_name = $dbh->{Driver}{Name};

    my @pk_column_names;

    if ( $driver_name eq 'Pg' ) {

        @pk_column_names = $dbh->primary_key( undef, undef, $table_name );

    }
    elsif ( $driver_name eq 'mysql' ) {

        my $sth = $dbh->prepare("SHOW INDEX FROM $table_name");
        $sth->execute();
        my $indexes_ref = $sth->fetchall_arrayref( {} );
        @pk_column_names = map { $_->{Column_name} } grep { $_->{Key_name} eq 'PRIMARY' } @{$indexes_ref};

    }


    return scalar @pk_column_names ? \@pk_column_names : undef;

} ## END sub _get_pk_column_names

##################
# Utility methods

### Subroutine : _delete_unnecessary_fields
#
# usage        : $source_map_ref = _delete_unnecessary_fields($source_map_ref, $optimized_upload_fields, $transfer_category);
# description  : If using the optimized upload configuration, removes unecessary fields from the payload
# parameters   : $source_map_ref (field map hash)
#              : $optimized_upload_fields (arrayref containing the fields we want to keep)
#              : $transfer_category (string)
#              :
# returns      : #source_map_ref the stripped down version of the $source_map_ref - actually this is just a ref,
#                so returning it wouldn't be necessary, but keeping it for clarity
#

sub _delete_unnecessary_fields{
    my ($source_map_ref, $optimized_upload_fields, $transfer_category) = @_;
    my @deleted_fields;
    for my $field ( keys %{ $source_map_ref->{field_ref} } ) {
        SMARTMATCH: {
            use experimental 'smartmatch';
            unless($field ~~ @$optimized_upload_fields){
            push @deleted_fields, $field;
            delete $source_map_ref->{field_ref}->{$field};
            }
        }
    }
    $logger->info("OPTIMIZED UPLOAD for Transfer category $transfer_category - Deleted fields: ".(join ", ",@deleted_fields));
    return $source_map_ref;
} ## END sub _delete_unnecessary_fields

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1;

__END__
