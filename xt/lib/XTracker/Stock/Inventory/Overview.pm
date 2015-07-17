package XTracker::Stock::Inventory::Overview;
use strict;
use warnings;
use feature ':5.14';
use Carp;
use XTracker::Handler;
use XTracker::Navigation qw( get_navtype build_sidenav );
use XTracker::Database::Location qw( get_location_allowed_statuses );
use XTracker::Database::Profile qw( get_department get_operator );
use XTracker::Database::Stock   qw(
    get_saleable_item_quantity
    get_reserved_item_quantity
    get_allocated_item_quantity
    get_picked_item_quantity
    get_total_item_quantity
    get_located_stock
    get_delivered_item_quantity
    get_ordered_item_quantity
    is_cancelled
);

use XTracker::Database::Product qw( get_variant_list get_product_id get_product_summary );
use XTracker::Database::SampleRequest qw(get_operator_request_types);
use XTracker::Constants::FromDB qw(
    :flow_status
    :reservation_status
    :return_status
    :shipment_class
    :shipment_item_status
    :shipment_status
    :stock_transfer_status
    :stock_transfer_type
);
use XTracker::Config::Local qw( config_var instance );
use List::MoreUtils qw( uniq );
use XTracker::Error qw( xt_warn xt_info );
use Try::Tiny;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = 'Product Overview';
    $handler->{data}{content}       = 'stocktracker/inventory/overview.tt';
    $handler->{data}{javascript}    = 'inventory.tt';

    # get product or variant id from url
    $handler->{data}{product_id}    = $handler->{request}->param('product_id');
    $handler->{data}{variant_id}    = $handler->{request}->param('variant_id');

    # hash of arguments to pass to functions
    my %args = ();

    # build arguments based on info we have
    if( $handler->{data}{product_id} ){
        # we don't want to search for anything other than digits
        if ($handler->{data}{product_id} !~ m{\A\d+\z}) {
            xt_info(
                sprintf(
                    'Invalid characters in Product ID: %s',
                    $handler->{data}{product_id}
                )
            );
            return $handler->redirect_to('/StockControl/Inventory');
        }
        %args = ( type => 'product_id', id => $handler->{data}{product_id}, nav_type => 'product' );
    }
    elsif( $handler->{data}{variant_id} ){
        %args = ( type => 'variant_id', id => $handler->{data}{variant_id}, nav_type => 'variant' );
        $handler->{data}{product_id} = get_product_id( $handler->{dbh}, { type => 'variant_id', id => $handler->{data}{variant_id} } );
    }
    else {
        xt_warn('No product or variant id defined');
        return $handler->process_template;
    }

    my $product = $handler->{schema}->resultset('Public::Product')->find($handler->{data}{product_id});

    $args{voucher_product_id} = XTracker::Database::Product::is_voucher($handler->dbh, \%args);

    # check for restrictions for non voucher products
    unless ($args{voucher_product_id}) {
        try {
            my $ship_restrictions = $product->get_shipping_restrictions_status;
            $handler->{data}{is_hazmat}  = $ship_restrictions->{is_hazmat};
            $handler->{data}{is_aerosol} = $ship_restrictions->{is_aerosol};
        } catch {
            warn 'Product id is a voucher, no shipping restrictions';
        };
    }

    # more function arguments
    $args{navtype}  = get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->{data}{auth_level}, type => $args{nav_type}, id => $handler->{data}{operator_id} } );
    $args{return}   = 'List';
    $args{operator_id}  = $handler->{data}{operator_id};

    $args{iws_rollout_phase} = $handler->iws_rollout_phase;

    # get all info we need to display

    # get common product summary data for header
    $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

    # make it really obvious if we didn't fetch/match anything
    # no products = {}
    if (not keys %{$handler->{data}{product}}) {
        xt_info(
            sprintf(
                "There are no products matching: %s",
                $handler->{data}{product_id} // $handler->{data}{variant_id}
            )
        );
        return $handler->redirect_to('/StockControl/Inventory');
    }

    # current operator info
    $handler->{data}{operator}      = (get_operator( { dbh => $handler->{dbh}, id => $handler->{data}{operator_id} } ))[0];
    $handler->{data}{department}    = get_department( { dbh => $handler->{dbh}, id => $handler->{data}{operator_id} } );

    # TODO WHM-119: most of this stuff going in the stash is no longer needed
    #               by the template - it should just fetched locally by
    #               _prepare_template_data

    # get sample request types for which operator has access
    {
        my $operator_request_types = get_operator_request_types( { dbh => $handler->{dbh}, operator_id => $handler->{data}{operator_id} } );
        $handler->{data}{op_request_types} = [ grep { defined } map { $_->{type} } @$operator_request_types ];
        $handler->{data}{op_request_types_nonpress} = scalar( grep { $_ ne 'Press' } @{ $handler->{data}{op_request_types} } );
    }

    # inventory info
    $handler->{data}{located_stock_main}    = get_located_stock( $handler->{dbh}, \%args, 'stock_main' );
    $handler->{data}{located_stock_transit} = get_located_stock( $handler->{dbh}, \%args, 'stock_transit' );
    $handler->{data}{located_stock_other}   = get_located_stock( $handler->{dbh}, \%args, 'stock_other' );
    $handler->{data}{located_sample}        = get_located_stock( $handler->{dbh}, \%args, 'sample' );

    $handler->{data}{variant_stock_main}      = get_variant_list( $handler->{dbh}, \%args, { by => 'size_list'    } );
    $handler->{data}{variant_stock_transit}   = get_variant_list( $handler->{dbh}, \%args, { by => 'stock_transit'} );
    if ($handler->{data}{variant_stock_transit} &&
        ref $handler->{data}{variant_stock_transit} eq 'ARRAY' &&
        @{$handler->{data}{variant_stock_transit}}) {
        # this isn't perfect, because it'll make it show up for stock on the way
        # to quarantine too, but it's better than always showing the recode link
        $args{can_recode_variant} = 1;
    }
    $handler->{data}{variant_stock_other}     = get_variant_list( $handler->{dbh}, \%args, { by => 'stock_other'  } );
    $handler->{data}{variant_sample}          = get_variant_list( $handler->{dbh}, \%args, { by => 'sample'       } );

    $handler->{data}{allocated}               = get_allocated_item_quantity( $handler->{dbh}, $handler->{data}{product_id} );
    $handler->{data}{picked}                  = get_picked_item_quantity( $handler->{dbh}, $handler->{data}{product_id} );
    $handler->{data}{free}                    = get_saleable_item_quantity( $handler->{dbh}, $handler->{data}{product_id} );
    $handler->{data}{reserved}                = get_reserved_item_quantity( $handler->{dbh}, $handler->{data}{product_id}, $RESERVATION_STATUS__PENDING );

    $handler->{data}{total}                   = get_total_item_quantity( $handler->{dbh}, $handler->{data}{product_id} );
    $handler->{data}{delivered_item_quantity} = get_delivered_item_quantity( $handler->{dbh}, $handler->{data}{product_id} );
    $handler->{data}{ordered_item_quantity}   = get_ordered_item_quantity( $handler->{dbh}, $handler->{data}{product_id} );

    $handler->{data}{location_types}          = get_location_allowed_statuses({ schema => $handler->schema,
                                                                                include_transit => 1 });

    # Prepare all the inventory overview table data for the template
    _prepare_template_data($handler);

    # specific side nav for user settings
    $handler->{data}{sidenav} = build_sidenav( \%args );

    # extended view for certain departments
    my @depts_with_extended_view = (
        'Retail',
        'Buying',
        'Merchandising',
        'Product Merchandising',
        'Marketing',
        'Editorial',
        'Personal Shopping',
        'Photography',
        'Finance',
        'Fashion Advisor',
    );

    # set extended view
    SMARTMATCH: {
        use experimental 'smartmatch';
        $handler->{data}{stock_view} = $handler->{data}{department} ~~ @depts_with_extended_view
            ? 'extended'
            : 'standard';
    }

    return $handler->process_template;
}

sub _prepare_template_data {
    ## no critic(ProhibitDeepNests)
    my $handler = shift;

    # TODO WHM-119: this stuff is a refactored version of all the logic
    #               I ripped out of the template. It's ugly. The DBIC stuff
    #               needs moving to resultset methods and it shouldn't rely on
    #               data in the stash. Also, the get_* stuff fetching that data
    #               should be rewritten to use DBIC. Now it's all in Perl, feel
    #               free to refactor. :)

    # Titles for tables
    my $table_titles = {
        stock_main => 'Stock Overview - Main Stock',
        stock_other => 'Stock Overview - Other Locations',
        stock_transit => 'Stock Overview - In Transit',
        sample => 'Sample Overview',
    };

    # Prepare data for Stock Overview - Main Stock
    for my $channel ( keys %{ $handler->{data}{channel_info} } ) {
        $handler->{data}{overview}{$channel} = { table_types => [], };

        # Determine whether or not there are samples to display
        $handler->{data}{overview}{$channel}{num_samples} = 0;
        for my $variant ( @{ $handler->{data}{variant_sample} } ) {
            for my $location ( values %{ $handler->{data}{located_sample}{$channel}{$variant->{id}} } ) {
                $handler->{data}{overview}{$channel}{num_samples} += scalar( keys %$location ); # count variant->location->status
            }
        }

        for my $table_type (qw( stock_main stock_other stock_transit sample )) {

            # main should always be displayed; the others will depend on data
            my $should_display = ( $table_type eq 'stock_main' );

            $handler->{data}{overview}{$channel}{$table_type} = { rows => [] };

            my $located_stock = $handler->{data}{"located_$table_type"};
            my $variant_stock = $handler->{data}{"variant_$table_type"};

            my $grand_totals = {
                map { ( $_ => 0 ) }
                qw(
                    ordered_item
                    delivered_item
                    stock
                    allocated
                    free
                    location
                    reserved
                ),
            };

            my $last_variant_id = 0;
            my $last_variant_type = '';

            my $product = $handler->{data}{product};

            for my $variant ( sort { $a->{size_id} <=> $b->{size_id} } @$variant_stock ) {
                my $variant_id = $variant->{id};
                my $total_location = 0;

                my $primary_loc = '';
                my $max_q = 0;

                my $different_locations = { map { ( $_ => 1 ) } keys %{ $located_stock->{$channel}{$variant_id} } };
                my $num_different_locations = scalar keys %$different_locations;

                my @primary_loc_statuses;

                my $expand_rows = [];

                for my $location_id ( keys %{ $located_stock->{$channel}{$variant_id} } ) {
                    # main stock overview displays main stock only
                    my @statuses_to_check = ( $table_type eq 'stock_main' )
                        ? ( $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS )
                        : ( keys %{ $located_stock->{$channel}{$variant_id}{$location_id} } );

                    for my $status_id ( @statuses_to_check ) {
                        # get details of located stock for this status
                        my $located = $located_stock->{$channel}{$variant_id}{$location_id}{$status_id};

                        my $quantity = $located->{quantity} || 0;
                        my $location = $located->{location} // '';
                        $total_location += $quantity;

                        my @split_quantity; # keep track of sample transfer out/return, for example

                        # special handling for transfer pending in the 'other locations' table
                        if ( $table_type eq 'stock_other' && $location eq 'Transfer Pending' ) {
                            # get transfer out/return
                            # TODO skip if $variant->{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__CANCELLED ?
                            # find how many samples have an RMA number
                            my $sample_transfers = $handler->{schema}->resultset('Public::Quantity')->search_rs(
                                {
                                    'me.variant_id' => $variant_id,
                                    'me.location_id' => $location_id, # Transfer Pending = 1
                                    'me.status_id' => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS, # Transfer Pending = 2
                                    'stock_transfer.status_id' => $STOCK_TRANSFER_STATUS__APPROVED,
                                    'shipment.shipment_class_id' => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
                                },
                                {
                                    join => {
                                        'product_variant' => {
                                            'shipment_items' => {
                                                'shipment' => [
                                                    'return',
                                                    { 'link_stock_transfer__shipment' => 'stock_transfer' },
                                                ],
                                            },
                                        },
                                    },

                                },
                            );

                            my $num_sample_transfers_in = $sample_transfers->search(
                                {
                                    'return.id' => { '!=' => undef }, # must have a corresponding return
                                    'return.return_status_id' => { '-in' => [ $RETURN_STATUS__AWAITING_RETURN, $RETURN_STATUS__PROCESSING ] }, # incomplete return
                                },
                            )->count;

                            my $num_sample_transfers_out = $sample_transfers->search(
                                {
                                    'return.id' => undef, # must not have a corresponding return
                                    'shipment.shipment_status_id' => $SHIPMENT_STATUS__DISPATCHED,
                                }
                            )->count;

                            my $remaining_quantity = $quantity - ($num_sample_transfers_in + $num_sample_transfers_out);

                            if ( $remaining_quantity ) {
                                push @split_quantity, {
                                    location_display => 'Transfer Pending',
                                    location_type => $handler->{data}{location_types}{$status_id}{type} // '',
                                    quantity => $remaining_quantity,
                                };
                                push @primary_loc_statuses, 'Transfer Pending';
                            }

                            if ( $num_sample_transfers_out ) {
                                push @split_quantity, {
                                    location_display => 'Sample Transfer Out',
                                    location_type => $handler->{data}{location_types}{$status_id}{type} // '',
                                    quantity => $num_sample_transfers_out,
                                };
                                push @primary_loc_statuses, 'Sample Transfer Out';
                            }

                            if ( $num_sample_transfers_in ) {
                                push @split_quantity, {
                                    location_display => 'Sample Transfer Return',
                                    location_type => $handler->{data}{location_types}{$status_id}{type} // '',
                                    quantity => $num_sample_transfers_in,
                                };
                                push @primary_loc_statuses, 'Sample Transfer Return';
                            }
                        } else {
                            # normal behaviour - just use location (status) -> count
                            my $location_type = $handler->{data}{location_types}{$status_id}{type} // '';
                            push @split_quantity, {
                                location => $location,
                                location_display => $location,
                                location_type => $location_type,
                                quantity => $quantity,
                                stock_status => $located->{status_name},
                            };

                            push @primary_loc_statuses, $location_type;
                        }

                        # at this point, @split_quantity contains each of the
                        # location/quantity rows for our expansion "table"

                        # expansion row details
                        for my $expand_row ( @split_quantity ) {
                            my $display_expand_location = $expand_row->{location_display};
                            # primary_loc shall be the display name of the
                            # location/status with the largest quantity
                            if ($expand_row->{quantity} > $max_q) {
                                $primary_loc = $expand_row->{location_display};
                                $max_q = $expand_row->{quantity};
                            }

                            if ($expand_row->{stock_status} && $expand_row->{stock_status} ne $expand_row->{location_display}) {
                                $display_expand_location .= ' (' . $expand_row->{stock_status} . ')';
                            }
                            push @$expand_rows, {
                                quantity => $expand_row->{quantity},
                                location => $location,
                                location_display => $display_expand_location,
                                channel_id => $located->{channel_id},
                            };
                        }
                    }
                }

                # Get list of all statuses for this variant in this table
                @primary_loc_statuses = uniq grep { $_ } @primary_loc_statuses;

                # Suppress display of location type if location and location type are the same
                $primary_loc ||= 'None';
                my $primary_loc_display = $primary_loc;

                if ( $table_type ne 'stock_main' ) {
                    if ( scalar(@primary_loc_statuses) > 1 ) {
                        if ( my $status_list = join(', ', grep { $_ } @primary_loc_statuses) ) {
                            $primary_loc_display = "($status_list)";
                        }
                    } else {
                        if ( $primary_loc_statuses[0] && (($primary_loc_statuses[0] // '') ne $primary_loc) ) {
                            $primary_loc_display = "$primary_loc ($primary_loc_statuses[0])";
                        }
                    }
                }

                next if $last_variant_id == $variant_id and $last_variant_type eq $variant->{variant_type};

                $last_variant_id = $variant_id;
                $last_variant_type = $variant->{variant_type};

                $grand_totals->{location} += $total_location;

                if ( $table_type eq 'stock_main' ) {
                    $grand_totals->{stock} += $handler->{data}{total}{$channel}{$variant_id} || 0;
                    $grand_totals->{allocated} += $handler->{data}{allocated}{$channel}{$variant_id} || 0;
                    $grand_totals->{free} += $handler->{data}{free}{$channel}{$variant_id} || 0;
                    $grand_totals->{ordered_item} += $handler->{data}{ordered_item_quantity}{$channel}{$variant_id} || 0;
                    $grand_totals->{delivered_item} += $handler->{data}{delivered_item_quantity}{$channel}{$variant_id} || 0;
                    $grand_totals->{reserved} += $handler->{data}{reserved}{$channel}{$variant_id} || 0;
                }

                # prepare details row for this variant
                my $variant_row = {
                    variant_id => $variant_id,
                    product_id => $variant->{product_id},
                    sku => join('-', $variant->{product_id}, $variant->{size_id}),
                    third_party_sku => $variant->{third_party_sku},
                    size => $variant->{size},
                    size_id => $variant->{size_id},
                    designer_size => join(' ', grep { defined } $product->{size_scheme}, $variant->{designer_size}),
                    location => {
                        name => $primary_loc,
                        display_name => $primary_loc_display,
                    },
                    total_location => $total_location || 0,
                    total => $handler->{data}{total}{$channel}{$variant_id} || 0,
                    allocated => $handler->{data}{allocated}{$channel}{$variant_id} || 0,
                    picked => $handler->{data}{picked}{$channel}{$variant_id} || 0,
                    free => $handler->{data}{free}{$channel}{$variant_id} || 0,
                    ordered => $handler->{data}{ordered_item_quantity}{$channel}{$variant_id} || 0,
                    delivered => $handler->{data}{delivered_item_quantity}{$channel}{$variant_id} || 0,
                    reserved => $handler->{data}{reserved}{$channel}{$variant_id} || 0,
                    variant_type => $variant->{variant_type},
                };

                # determine whether or not expanded location info should be visible...
                # * is there more than one row to display in the expansion?
                my $should_expand = @$expand_rows > 1;
                # * does operator have permissions for action buttons? (not applicable for main stock overview)
                if ( $table_type ne 'stock_main' ) {
                    $should_expand ||= ( scalar( @{ $handler->{data}{op_request_types} } ) || $handler->{data}{department} eq 'Sample' );
                }

                # any expansions?
                if ( $should_expand && @$expand_rows ) {
                    $variant_row->{location}{expand} = 1;
                    $variant_row->{expand_rows} = $expand_rows;
                }

                push @{ $handler->{data}{overview}{$channel}{$table_type}{rows} }, $variant_row;
            }
            # pass grand totals to handler
            $handler->{data}{overview}{$channel}{$table_type}{grand_totals} = $grand_totals;

            # if we haven't already decided, use number of rows to determine display
            $should_display ||= !!scalar( @{ $handler->{data}{overview}{$channel}{$table_type}{rows} } );

            if ( $should_display ) {
                my $table_info = {
                    type => $table_type,
                    title => $table_titles->{$table_type},
                };
                push @{ $handler->{data}{overview}{$channel}{table_types} }, $table_info;
            }
        }
    }
}

1;
