package XTracker::Stock::GoodsIn::Putaway;

=head2 NAME

XTracker::Stock::GoodsIn::Putaway

=head2 DESCRIPTION

This page runs in two modes: list and single.

    * List mode shows a list of all the PIDs awaiting putaway (the default)

    * Single mode shows the details for a single PID.
        When a parameter process_group_id is passed, single mode is activated.

=head2 NOTES

    The big try{} block in the handler() sub below populates the single view.

    Subs get_putaway_process_groups() and _do_listing() are used for list view.

=cut

use strict;
use warnings;

use XTracker::Constants qw($PG_MAX_INT);
use XTracker::Constants::FromDB  qw(
    :stock_process_status
    :flow_status
    :putaway_type
);
use XTracker::Database::Channel  qw( get_channel_details );
use XTracker::Database::Delivery qw( get_delivery_channel );
use XTracker::Database::Location qw( get_suggested_stock_location );
use XTracker::Database::Product  qw(
    get_product_id
    get_product_summary
    get_variant_by_sku
);
use XTracker::Database::Return;
use XTracker::Database::RTV qw( :rtv_stock );
use XTracker::Database::Shipment;
use XTracker::Database::StockProcess qw(
    get_delivery_id
    get_putaway
    get_quarantine_process_group
    get_quarantine_process_items
    get_return_process_group
    get_return_stock_process_items
    get_sample_process_group
    get_sample_process_items
    get_stock_process_items
    get_stock_process_types
    :putaway
);
use XTracker::Database::Stock qw( get_variant_locations );
use XTracker::Error;
use XTracker::Handler;
use XTracker::Image;

use Try::Tiny;

use feature ':5.12';

use Data::Dump  qw( pp );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Goods In';
    $handler->{data}{subsection}    = 'Putaway';
    $handler->{data}{subsubsection} = '';

    # form vars
    my $params = $handler->{param_of};
    $handler->{data}{view}                = $params->{view};                 # set view to handheld - defaults to full screen mode
    $handler->{data}{redirect}            = $params->{redirect};             # flag to display completed message and auto redirect to put away list
    $handler->{data}{process_group_id}    = $params->{process_group_id};     # user entered form value
    $handler->{data}{location_suggestion} = $params->{location_suggestion};  #
    $handler->{data}{ravni_warning}       = 1;

    # set page template and left nav links based on view type
    if ($handler->{data}{handheld} == 1) {
        $handler->{data}{content} = 'goods_in/handheld/putaway.tt';
    }
    else {
        $handler->{data}{content} = 'goods_in/putaway.tt';
    }

    # There's no process group - we're just getting a list.
    return _do_listing( $handler ) unless $handler->{data}{process_group_id};

    # Prepare the process group id field
    if ( $handler->{data}{process_group_id} ) {
        $handler->{data}{process_group_id} =~ s{^p-}{}i;
        $handler->{data}{process_group_id} =~ s{^\s*(\S*)\s*$}{$1};
    }

    unless ( grep {
        m{^(\d+)$} && $_ <= $PG_MAX_INT
    } $handler->{data}{process_group_id}) {
        xt_warn( "Process Group ID $params->{process_group_id} is not valid" );
        delete $handler->{data}{process_group_id};
        return _do_listing( $handler );
    }

    my $url = '/GoodsIn/Putaway';

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    $handler->{data}{subsubsection} = 'Process Item';

    # get data needed for page
    $handler->{data}{sp_types} = get_stock_process_types( $dbh );

    my $sp_group_rs = $schema->resultset('Public::StockProcess')
        ->get_group( $handler->{data}{process_group_id} );

    unless ( $sp_group_rs->count ) {
        xt_warn("Could not find process group id $handler->{data}{process_group_id}");
        return $handler->redirect_to($url);
    }

    if ($sp_group_rs->first->is_handled_by_iws($handler->iws_rollout_phase)) {
        xt_warn( "PGID $handler->{data}{process_group_id} is handled by IWS" );
        return $handler->redirect_to($url);
    }

    if ( $sp_group_rs->slice(0,0)->single->is_handled_by_prl ) {
        xt_warn( "PGID $handler->{data}{process_group_id} must be processed from the PutawayPrep page" );
        return $handler->redirect_to($url);
    }

    my $err;
    try {
        # If we have a voucher branch off
        if ( $sp_group_rs->get_voucher ) {
            process_voucher_sp( $handler, $sp_group_rs );
            $err = 0;
            return; # returns from try
        }

        my $putaway_data = get_putaway_type( $dbh, $handler->{data}{process_group_id} );
        $handler->{data} = { %{ $handler->{data} }, %$putaway_data };

        # get delivery info for stock process
        $handler->{data}{delivery_id}           = get_delivery_id( $dbh, $handler->{data}{process_group_id} );
        $handler->{data}{delivery_channel}      = get_delivery_channel( $dbh, $handler->{data}{delivery_id});
        $handler->{data}{delivery_channel_data} = get_channel_details( $dbh, $handler->{data}{delivery_channel});

        # The following data is used in the single view
        SMARTMATCH: {
            use experimental 'smartmatch';
            # Customer Return
            given ( $handler->{data}{putaway_type} ) {
                when ([$PUTAWAY_TYPE__RETURNS, $PUTAWAY_TYPE__STOCK_TRANSFER]) {
                    $handler->{data}{pending_items} = get_return_stock_process_items( $dbh, 'process_group', $handler->{data}{process_group_id}, 'putaway' );
                    $handler->{data}{putaway_items} = get_return_putaway( $dbh, $handler->{data}{process_group_id} );
                    $handler->{data}{total_items}   = get_putaway_total( $dbh, $handler->{data}{process_group_id} );

                    # stock process complete?
                    $handler->{data}{pending_items} = next_putaway_item( $handler->{data}{pending_items}, $handler->{data}{total_items} );

                    # returns are completed in one stage so always set this to 1
                    $handler->{data}{complete} = 1;

                    # We really only expect there to be one variant in each
                    # process group in this scenario, however as this only affects
                    # the suggested location we don't really need to warn the user
                    # here, as the fallback on that sub is to suggest by product
                    my $variant = $sp_group_rs->slice(0,0)->single->variant;
                    $handler->{data}{product_id}  = $variant->product_id;
                    # get channel_id for product for suggested locations
                    my $channel_id = $variant->product->get_current_channel_id();

                    # get suggested location
                    my $suggested_location  = get_suggested_stock_location( $dbh, $variant->id, $channel_id, $sp_group_rs->first->type->id );
                    $handler->{data}{suggested_location_type} = $suggested_location->{type};
                    $handler->{data}{locations}{$channel_id}{$variant->id} = $suggested_location->{location}[0];
                }
                # Goods In
                when ( $PUTAWAY_TYPE__GOODS_IN ) {
                    $handler->{data}{pending_items} = get_stock_process_items( $dbh, 'process_group', $handler->{data}{process_group_id}, 'putaway' );
                    $handler->{data}{putaway_items} = get_putaway( $dbh, $handler->{data}{process_group_id} );
                    $handler->{data}{total_items}   = get_putaway_total( $dbh, $handler->{data}{process_group_id} );

                    # stock process complete?
                    $handler->{data}{pending_items} = next_putaway_item( $handler->{data}{pending_items}, $handler->{data}{total_items} );
                    $handler->{data}{complete} = defined($handler->{data}{pending_items}) ? 0 : 1;

                    # current locations
                    $handler->{data}{locations} = get_variant_locations( $dbh, { type => 'group_id', id => $handler->{data}{process_group_id}, sample => 0, status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS } );

                    # get product id from process group
                    $handler->{data}{product_id}  = get_product_id( $dbh, { type => 'process_group', id => $handler->{data}{process_group_id} } );
                }
                # Processed Quarantine
                when ( $PUTAWAY_TYPE__PROCESSED_QUARANTINE ) {
                    $handler->{data}{pending_items} = get_quarantine_process_items( $dbh, 'process_group', $handler->{data}{process_group_id}, 'putaway' );
                    $handler->{data}{putaway_items} = get_quarantine_putaway( $dbh, $handler->{data}{process_group_id} );
                    $handler->{data}{total_items}   = get_putaway_total( $dbh, $handler->{data}{process_group_id} );

                    # stock process complete?
                    $handler->{data}{pending_items} = next_putaway_item( $handler->{data}{pending_items}, $handler->{data}{total_items} );
                    $handler->{data}{complete} = defined($handler->{data}{pending_items}) ? 0 : 1;

                    # current locations
                    $handler->{data}{locations} = get_variant_locations( $dbh, { type => 'group_id', id => $handler->{data}{process_group_id}, sample => 0, status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS } );

                    # get product id from process group
                    $handler->{data}{product_id}  = get_product_id( $dbh, { type => 'quarantine_process_group', id => $handler->{data}{process_group_id} } );
                }
                # Vendor Samples
                when ( $PUTAWAY_TYPE__SAMPLE ) {
                    $handler->{data}{pending_items} = get_sample_process_items( $dbh, 'process_group', $handler->{data}{process_group_id}, 'putaway' );
                    $handler->{data}{putaway_items} = get_sample_putaway( $dbh, $handler->{data}{process_group_id} );
                    $handler->{data}{total_items}   = get_putaway_total( $dbh, $handler->{data}{process_group_id} );

                    # stock process complete?
                    $handler->{data}{pending_items} = next_putaway_item( $handler->{data}{pending_items}, $handler->{data}{total_items} );

                    # vendor samples are completed in one stage so always set this to 1
                    $handler->{data}{complete} = 1;

                    # current locations
                    $handler->{data}{locations} = get_variant_locations( $dbh, { type => 'group_id', id => $handler->{data}{process_group_id}, sample => 1, status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS } );

                    # get product id from process group
                    $handler->{data}{product_id} = get_product_id( $dbh, { type => 'sample_process_group', id => $handler->{data}{process_group_id} } );
                }
            }
        }

        # get product data
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );
        $handler->{data}{images} = get_images({
            product_id => $handler->{data}{product_id},
            live => $handler->{data}{product}{live},
            schema => $schema,
        });

        # get 'active' sales channel info for product
        $handler->{data}{active_channel_data} = get_channel_details( $dbh, $handler->{data}{active_channel}{channel_name} );

        # set sales channel template var as the 'active channel'
        $handler->{data}{sales_channel} = $handler->{data}{active_channel}{channel_name};

        $err = 0;
    }
    catch {
        SMARTMATCH: {
            use experimental 'smartmatch';
            when (m{not determine putaway type}) {
                xt_warn( "Could not determine putaway type for process group id $handler->{data}{process_group_id}" );
                $err = 1;
            }
            default {
                xt_warn( $_ );
            }
        }
    };
    return $handler->redirect_to($url) if $err;

    create_sidenav( $handler, $url );
    return $handler->process_template;
}

sub create_sidenav {
    my ( $handler, $url ) = @_;
    # set left nav links based on view type
    if ($handler->{data}{handheld}) {
        push @{ $handler->{data}{sidenav}[0]{'None'} },
            { 'title' => 'Back', 'url' => "$url?view=HandHeld" };
    }
    else {
        $url .= "?show_channel=$handler->{data}{active_channel}{channel_id}"
            if defined $handler->{data}{active_channel}{channel_id};
        push @{ $handler->{data}{sidenav}[0]{'None'} },
            { 'title' => 'Back', 'url' => $url };
    }
}

sub process_voucher_sp {
    my ( $handler, $sp_rs ) = @_;

    # Currently a voucher is always a 'Goods In' type
    my $data;
    my $dbh = $handler->schema->storage->dbh;
    my $group_id = $handler->{data}{process_group_id};
    $data->{putaway_type} = $PUTAWAY_TYPE__GOODS_IN;
    eval {
        my $stock_order_rs
            = $sp_rs->related_resultset('delivery_item')
                    ->related_resultset('delivery')
                    ->related_resultset('link_delivery__stock_order')
                    ->related_resultset('stock_order');
        my $channel = $stock_order_rs->related_resultset('purchase_order')
                                     ->related_resultset('channel')
                                     ->first;
        # get delivery info for stock process
        $data->{delivery_id} = $sp_rs->related_resultset('delivery_item')->first->delivery_id;

        $data->{delivery_channel_data} = $channel;

        #$data->{pending_items} = get_stock_process_items( $dbh, 'process_group', $group_id, 'putaway' );
        my $pending_item_rs = $sp_rs->pending_putaway;

        #$data->{putaway_items} = get_putaway( $dbh, $group_id );
        my $putaway_items = $sp_rs->related_resultset('putaways')->incomplete;

        # Stick putaway items in a hashref so as not to break the existing
        # template logic
        $data->{putaway_items} = [];
        PUTAWAY_ITEM:
        foreach ( $putaway_items->all ) {
            push @{$data->{putaway_items}}, {
                quantity              => $_->quantity,
                location              => $_->location->location,
                stock_process_type_id => $_->stock_process->type_id,
            };
        }

        #$data->{total_items}   = get_putaway_total( $dbh, $group_id );
        # stock process complete?
        #$data->{pending_items} = next_putaway_item( $data->{pending_items}, $data->{total_items} );
        #$data->{complete} = defined($data->{pending_items}) ? 0 : 1;
        $data->{complete} = 1;
        PENDING_ITEM:
        foreach my $pending_item ( $pending_item_rs->all ) {
            if ( my $leftover = $pending_item->leftover ) {
                $data->{pending_items} = $pending_item;
                $data->{complete} = 0;
                last PENDING_ITEM;
            }
        }

        my $voucher = $stock_order_rs->related_resultset('voucher_product')->first;
        $data->{voucher} = $voucher;
        my $quantity = $voucher->variant->quantities->slice(0,0)->single;
        $data->{locations}{$channel->id}{$voucher->variant->id} = {
            quantity => $quantity->quantity,
            location => $quantity->location->location,
            # FIXME: Ensure this code works with all DC's, not just specific ones (if uncommented) - Consider using XT::Rules!
            #location_type => $quantity->location->type->type, # This should always be 'DC1', even for DC2
            status_id => $quantity->status_id,
            status_name => $quantity->status->name,
        } if $quantity;

        # get product id from process group
        #$data->{product_id}  = get_product_id( $dbh, { type => 'process_group', id => $group_id } );
        $handler->{data}{product_id} = $voucher->id;

        # get product data
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

        # get 'active' sales channel info for product - for vouchers this only
        # needs channel.id and business.config_section
        #data->{active_channel_data} = get_channel_details( $dbh, $channel->name );
        $data->{active_channel_data} = {
            id => $channel->id,
            config_section => $channel->business->config_section,
        };

        # set sales channel template var as the 'active channel'
        #$handler->{data}{sales_channel} = $handler->{data}{active_channel}{channel_name};
        $data->{sales_channel} = $channel->name;

        # Work out the active channel
        $data->{active_channel}{channel_id} = $voucher->channel_id;
        @{$handler->{data}}{keys %{$data}} = values %{$data};
    };
    if ($@) {
        xt_warn( $@ );
    }
    return;
}

sub get_putaway_process_groups {
    my ( $schema, $phase ) = @_;

    my $data;
    my $stage = 'Putaway';

    # get list of process groups
    my $dbh = $schema->storage->dbh;
    my $stock_process_rs = $schema->resultset('Public::StockProcess');
    my $process_group_data = {
        delivery   => $stock_process_rs->putaway_process_groups( $phase ),
        quarantine => get_quarantine_process_group( $dbh, $stage, $phase ),
        returns    => get_return_process_group( $dbh, $stage ),
        samples    => get_sample_process_group( $dbh, $stage, $phase ),
    };

    my $process_groups;
    # move all process groups into single hash for page
    foreach my $type ( keys %$process_group_data ) {
        foreach my $channel ( keys %{ $process_group_data->{$type} } ) {
            $process_groups->{$channel}{$type} = $process_group_data->{$type}{$channel};
        }
    }
    return $process_groups;
}

sub next_putaway_item {
    my ( $pending_ref, $total_ref ) = @_;

    foreach my $record (@$pending_ref) {
        # Set total to 0 if it's undefined
        my $total_putaway = $total_ref->{ $record->{id} }{total} || 0;
        if ( $record->{quantity} > $total_putaway ) {
            $record->{leftover} = $record->{quantity} - $total_putaway;
            return [$record];
        }
    }
    return;
}

sub _check_putaway {
    my ( $dbh, $type, $var_id ) = @_;

    my %qry = (
            "return" => "select id, group_id
                            from stock_process where status_id = $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED and complete = false and delivery_item_id IN (
                            select delivery_item_id from link_delivery_item__return_item where return_item_id IN (
                            select id from return_item where variant_id = ? and return_item_status_id in (select id from return_item_status where status in ('Failed QC - Accepted', 'Passed QC')) ))
                            limit 1",
            "sample" => "select sp.id, sp.group_id
                            from delivery del, stock_process sp, delivery_item di, stock_process_type spt, link_delivery_item__shipment_item di_si, shipment_item si
                            where si.variant_id = ?
                                and si.id = di_si.shipment_item_id
                                and di_si.delivery_item_id = di.id
                                and di.delivery_id = del.id
                                and sp.delivery_item_id = di.id
                                and sp.type_id = spt.id
                                and sp.complete = false"
    );

    my $sth = $dbh->prepare( $qry{$type} );
    $sth->execute( $var_id );

    my $row = $sth->fetchrow_hashref;

    return $row->{id}, $row->{group_id};
}

sub _do_listing {
    my $handler = shift;

    # data to populate barcode form
    $handler->{data}{scan} = {
        action  => '/GoodsIn/Putaway',
        field   => 'process_group_id',
        name    => 'Process Group',
        heading => 'Putaway',
    };

    $handler->{data}{process_groups} = get_putaway_process_groups( $handler->{schema}, $handler->iws_rollout_phase )
        unless ( $handler->{data}{handheld} || $handler->{data}{datalite} );

    return $handler->process_template;
}

1;
