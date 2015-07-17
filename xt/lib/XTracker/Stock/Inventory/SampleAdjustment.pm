package XTracker::Stock::Inventory::SampleAdjustment;

use strict;
use warnings;

use URI;

use XTracker::Constants::FromDB qw{
    :flow_status
    :return_status
    :shipment_class
    :shipment_item_status
};
use XTracker::Database::Product qw( get_product_summary );
use XTracker::Error;
use XTracker::Handler;
use XTracker::Navigation qw( get_navtype build_sidenav );
use XTracker::Utilities qw( strip_txn_do );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my ( $type, $type_id ) = map {
        $_ => $handler->{param_of}{$_}
    } grep { $handler->{param_of}{$_} } qw{product_id variant_id};

    # Check for illegal characters in pid/sku
    if ( $type_id && $type_id =~ /[^-\d]/ ) {
        xt_warn(
            'Please enter a valid '.($type eq 'product_id' ? 'PID' : 'variant ID')
        );
        $type = ''; # just render the form again
    }

    my $schema = $handler->schema;

    # TODO: view channel redirection currently gets lost
    # The user has marked a shipment as lost
    if ( my ($lost) = grep { m{^lost} } keys %{$handler->{param_of}||{}} ) {
        my ($submitted_row) = ( $lost =~ m{(\d+$)} );
        lose_sample( $schema, {
            operator_id => $handler->operator_id,
            map {
                my ($arg) = m{^(.+)_$submitted_row$};
                $arg => $handler->{param_of}{$_}
            } grep { m{_$submitted_row$} } keys %{$handler->{param_of}}
        });
        my $uri = URI->new($handler->path);
        $uri->query_form({ $type => $type_id });
        return $handler->redirect_to($uri);
    }

    # The user has marked a shipment as found
    if ( $handler->{param_of}{found} ) {
        my $shipment_item_id = $handler->{param_of}{shipment_item_id};
        eval {
            my $shipment_item = $schema->resultset('Public::ShipmentItem')
                                       ->find($shipment_item_id)
                                       ->found($handler->operator_id);
        };
        if ( my $e = $@ ) {
            xt_warn( "There was an error finding the SKU: $e" );
        }
        else {
            xt_success( 'SKU marked as found' );
        }
        my $uri = URI->new($handler->path);
        $uri->query_form({ $type => $type_id });
        return $handler->redirect_to($uri);
    }

    $handler->add_to_data({
        content       => 'inventory/sample_adjustment.tt',
        section       => 'Stock Control',
        subsection    => 'Inventory',
        subsubsection => 'Sample Adjustment',
    });
    return $handler->process_template unless $type;

    my $search_args = {
        sprintf('me.%sid', $type eq 'variant_id' ? q{} : 'product_') => $type_id
    };
    my $variant_rs = $schema->resultset('Public::Variant')->search($search_args);

    my $product = $variant_rs->related_resultset('product')->slice(0,0)->single;
    unless ( $product ) {
        xt_warn( sprintf(
            "Could not find %s %s",
            $type eq 'product_id' ? ('PID',$type_id) : ('variant',$type_id)
        ) );
        return $handler->redirect_to( $handler->path );
    }

    # The sidenav code *really* needs a rework
    my $args = {
        auth_level => $handler->{data}{auth_level},
        operator_id => $handler->operator_id,
        type => $type,
        id => $type_id,
        navtype => get_navtype({
            type => 'product', # or variant, it doesn't matter
            auth_level => $handler->{data}{auth_level},
            id => $handler->operator_id,
        }),
    };
    $handler->add_to_data({
        sidenav       => build_sidenav( $args ),
        # So we can redirect to the right place
        type         => $type,
        type_id      => $type_id,
        view         => $handler->{param_of}{view} || '',
        view_channel => $handler->{param_of}{view_channel} || '',
        another_bleeding_channel_map_so_we_can_work_with_ids => { map {
            $_->name => $_->id,
        } $schema->resultset('Public::Channel')->all, },
    });

    $handler->add_to_data( get_product_summary( $handler->schema, $product->id ) );

    # A container for items we want to pass to the handler
    my %stock;
    push @{$stock{$_->channel->name}{located}}, $_
        for $variant_rs->dispatched_sample_quantities->all;

    push @{$stock{$_->shipment->stock_transfer->channel->name}{lost}}, $_
        for $variant_rs->lost_sample_shipment_items->all;

    $handler->add_to_data({ stock => \%stock });

    return $handler->process_template;
}

sub lose_sample {
    my ( $schema, $args ) = @_;

    my ( $quantity_id, $operator_id, $notes )
        = @{$args}{qw/quantity_id operator_id notes/};

    $notes =~ s{^\s*}{}; $notes=~ s{\s*$}{};
    unless ( length $notes ) {
        xt_warn("You must enter some text into the 'Notes' field");
        return;
    }

    my $quantity
        = $schema->resultset('Public::Quantity')->find($quantity_id);
    # Lose shipment
    # * Dispatched - also Return Pending?
    # * Variant
    # * sample/press/transfer class
    # * no return?
    # * order by newest/oldest?
    my $si = $schema->resultset('Public::ShipmentItem')->search(
        {
            shipment_item_status_id => [
                $SHIPMENT_ITEM_STATUS__DISPATCHED,
                $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
            ],
            variant_id => $quantity->variant_id,
            'shipment.shipment_class_id' => [
                $SHIPMENT_CLASS__SAMPLE,
                $SHIPMENT_CLASS__PRESS,
                $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
            ],
        },
        { join => 'shipment', order_by => 'shipment.date' },
    )->slice(0,0)->single;
    unless ( $si ) {
        xt_warn(sprintf(
            join( q{ },
                q{Couldn't mark SKU %s as lost as we can't find a matching shipment for it.},
                q{Please contact service desk.} ),
            $quantity->variant->sku
        ));
        return;
    }
    my $location_id = $quantity->location_id;
    my $shipment = $si->shipment;
    my $return = $shipment->returns->first;
    eval {
        $schema->txn_do(sub{
            $quantity->update_and_log_sample({
                delta => -1,
                operator_id => $operator_id,
                notes => $notes,
            });
            $si->set_lost($_, $location_id)
            && $shipment->set_lost($_)
            && $return && $return->set_lost($_)
                for $operator_id;
        });
        xt_success( 'SKU marked as lost' );
    };
    if ( $@ ) {
        xt_warn(sprintf q{Couldn't mark SKU as lost: %s}, strip_txn_do($@));
    }
}

1;
