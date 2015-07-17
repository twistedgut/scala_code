package XTracker::Order::Fulfilment::ScanOutPEItem; ## no critic(ProhibitExcessMainComplexity)
use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use URI;
use URI::QueryParam;
use XTracker::Error;
use XTracker::Database::Shipment qw( get_shipment_item_info );
use XTracker::Database::Container qw( :utils :validation );
use XTracker::Database qw( :common );
use XTracker::Image; # get_images
use XTracker::Utilities qw( strip );
use XTracker::Constants::FromDB qw( :pws_action );
use XTracker::WebContent::StockManagement;

use XTracker::Handler::Situation;
use Digest::MD5                         qw/md5_hex/;

use XTracker::DBEncode                  qw( encode_it );
use XT::Data::Fulfilment::Putaway;


# the situations this handler can be expected to deal with;
# in no particular order, except that, if there is more than
# one, there must be a situation parameter provided on each
# call, otherwise it doesn't know which one to pick
# (although I suppose I could add a 'start_here' key...)

sub situations {

    # For sending Cancelled items to Putaway: after scanning a SKU
    # proceeed to either a Container or the Cancelled-to-Putaway
    # Location
    my $putaway = XT::Data::Fulfilment::Putaway->new_by_type();
    my $putaway_intransit_type = $putaway->intransit_type;
    my $removeCancelPendingToPutaway = {
        Container => 'removeCancelPending.handleContainer',
        Location  => 'removeCancelPending.handleCancelledLocation',
    }->{ $putaway_intransit_type }
        or die("Internal: Invalid intransit_type ($putaway_intransit_type)\n");

    my $situations = {
        'removeFaulty' => {
            fancy_name     => 'Scan SKU of Faulty Item',
            check_we_have  => [ qw( shipment_id shipment_item_id ) ],
            next_situation => 'removeFaulty.handleSKU',
        },
        'removeFaulty.handleSKU' => {
            fancy_name     => 'Scan Container for Faulty Item',
            check_we_have  => [ qw( shipment_id shipment_item_id sku ) ],
            next_situation => 'removeFaulty.handleContainer',
        },
        'removeFaulty.handleContainer' => {
            fancy_name      => 'Remove Faulty Item',
            check_we_have   => [ qw( shipment_id shipment_item_id sku container_id ) ],
            continue_url    => '/Fulfilment/Packing/ScanFaultyItem',
            continue_params => [ qw( shipment_id shipment_item_id     container_id ) ],
        },
        'removeCancelPending' => {
            fancy_name     => 'Scan SKU of Cancelled Item',
            check_we_have  => [ qw( shipment_id shipment_item_id ) ],
            next_situation => 'removeCancelPending.handleSKU',
        },
        'removeCancelPending.handleSKU' => {
            fancy_name     => 'Scan Container for Cancelled Item',
            check_we_have  => [ qw( shipment_id shipment_item_id sku ) ],
            next_situation => $removeCancelPendingToPutaway,
        },
        'removeCancelPending.handleContainer' => {
            fancy_name      => 'Remove Cancelled Item',
            check_we_have   => [ qw( shipment_id shipment_item_id sku empty_container_id ) ],
            continue_url    => '/Fulfilment/Packing/CheckShipmentException',
            continue_params => [ qw( shipment_id ) ],
        },
        'removeCancelPending.handleCancelledLocation' => {
            fancy_name      => 'Move Cancelled Item into Cancelled-to-Putaway Location',
            check_we_have   => [ qw( shipment_id shipment_item_id sku cancelled_location_id ) ],
            continue_url    => '/Fulfilment/Packing/CheckShipmentException',
            continue_params => [ qw( shipment_id ) ],
        },
    };

    return $situations;
}

# if get_object is defined, it gets called with a $schema and the $id
# of the thing that's wanted, and is expected to return an object, or
# explode
my $parameters = {
    shipment_id      => {
        fancy_name => 'shipment',
        model_name => 'Public::Shipment',
    },
    shipment_item_id => {
        fancy_name       => 'shipment item',
        model_name       => 'Public::ShipmentItem',
        redirect_on_fail => '/Fulfilment/Packing/CheckShipmentException',
    },
    sku              => {
        fancy_name       => 'SKU',
        redirect_on_fail => '',
    },
    container_id     => {
        fancy_name => 'container/tote',

        # make sure that incoming Container ID goes further as Barcode object
        get_object => sub {
            my ($schema, $container_id) = @_;
            $container_id = NAP::DC::Barcode::Container->new_from_id(
                $container_id
            );
            return get_container_by_id ( $schema, $container_id );
        },
        redirect_on_fail => '',
    },
    empty_container_id => {
        fancy_name => 'container/tote',
        # make sure that incoming Container ID goes further as Barcode object
        get_object => sub {
            my ($schema, $container_id) = @_;
            $container_id = NAP::DC::Barcode::Container->new_from_id(
                $container_id
            );
            return get_container_by_id ( $schema, $container_id );
        },
        redirect_on_fail => '',
    },
    cancelled_location_id => {
        fancy_name => 'Cancelled-to-Putaway Location',
        get_object => sub {
            my ($schema, $location_name) = @_;

            my $location_rs = $schema->resultset("Public::Location");
            my $cancelled_location_row = $location_rs->get_cancelled_location();

            $cancelled_location_row->verify_is_same( $location_name );

            return $cancelled_location_row;
        },
        redirect_on_fail => '',
    },
};

# interface is that the validator gets passed the thing to be
# validated, plus a hashref of all the previously validated
# parameters, named as in $parameters
#
# no return value is expected, since lack of explosion is considered
# validation enough
my $validators = {
    shipment_item_id => sub {
        my ($item,$checked_objects) = @_;

        die "That shipment item is not in this shipment\n"
            unless $checked_objects->{shipment_id}->id == $item->shipment_id;
    },

    sku => sub {
        my ($sku,$checked_objects) = @_;

        die "SKU $sku does not match the target item's SKU\n"
            unless $checked_objects->{shipment_item_id}->get_sku eq $sku;
    },

    container_id => sub {
        my ($container,$checked_objects) = @_;

        if ($container && $container->is_pigeonhole) {
            my $shipment_item = $checked_objects->{shipment_item_id};
            if ($shipment_item) {
                if ($shipment_item->container_id && ($shipment_item->container_id eq $container->id)) {
                    # that's all ok, leave it in container for now, it'll get removed at the
                    # next stage
                } elsif ($shipment_item->old_container_id && ($shipment_item->old_container_id eq $container->id)) {
                    # It was missing before, so we don't need to take it out of anywhere.
                } else {
                    # If the item wasn't in this pigeon hole before, they shouldn't
                    # be trying to put it there.
                    die "May not put faulty item into a pigeon hole\n";
                }
            } else {
                # If the item wasn't in this pigeon hole before, they shouldn't
                # be trying to put it there.
                die "Missing shipment item\n";
            }
        } else {
            die "May not put faulty item into that container; please scan another\n"
                unless ( $container->accepts_faulty_items );
        }
    },

    # Intransit type: Container
    empty_container_id => sub {
        my ($new_container,$checked_objects, $handler) = @_;

        my $item = $checked_objects->{'shipment_item_id'};
        my $container = $item->container;

        if ($container && $container->is_pigeonhole) {
            # Cancelled pigeon hole items have to go back in the same one.
            die "Please return the item to pigeon hole ".$container->id
                unless ($new_container->id eq $checked_objects->{'shipment_item_id'}->container->id);
        } else {
            die "Please only scan Cancelled Items to totes that are empty or only" .
                " contain other Cancelled Items\n"
                unless $new_container->accepts_putaway_ok_items;
        }

        # "Orphan" cancelled item into the new container
        if ( $container ) {
            $container->remove_item({ shipment_item => $item });
        }

        # Phase 1, we need to change its status and add to INVAR. We then need
        # to do all the inventory crap that's in SetCancelPutAway.pm.
        # XXX all this only works for *orders*
        # transfers & samples should really not show up here… maybe. we hope.
        if ( $handler->iws_rollout_phase >= 1 ) {
            $item->cancel_and_move_stock_to_iws_location_and_notify_pws(
                $handler->operator_id,
            );

            # tell IWS about the move if it's from a tote or nowhere,
            # but don't for pigeon holes
            if (!$container || !$container->id->is_type('pigeon_hole')) {
                $handler->msg_factory->transform_and_send(
                    'XT::DC::Messaging::Producer::WMS::ItemMoved',{
                        shipment_id => $item->shipment_id,
                        from  => {
                            ($container ?
                                ( container_id => $container->id ) :
                                ( 'no' => 'where' )),
                            stock_status => 'main'
                        },
                        to    => { container_id => $new_container->id,
                                   stock_status => 'main' },
                        items => [{
                            sku      => $item->get_sku,
                            quantity => 1,
                            client   => $item->get_client()->get_client_code(),
                        },],
                    }
                );
            }
        }

        if ( $container ) {
            if ( $container->is_pigeonhole ) {
                xt_success('Cancelled Item in ' . $container->id .
                    ' marked as ready for IWS to process');
            } else {
                xt_success(
                    "Cancelled Item removed from " . $container->physical_type . ' ' .
                    $container->id);
            }
        } else {
            xt_success("Item refound and prepared for putaway");
        }
    },

    # Note: Moving Cancelled items from Packing Exception to Putaway
    # via Cancelled Location only works using PRLs atm, since it
    # currently doesn't care about Pigeonholes.
    #
    # If/when we need that implemented in DCA-??? either add it here,
    # or incorporate the main logic in empty_container_id.
    cancelled_location_id => sub {
        my ($cancelled_location_id, $checked_objects, $handler) = @_;
        my $shipment_item_row      = $checked_objects->{shipment_item_id};
        my $container_row          = $shipment_item_row->container;


        # Intransit type: Location
        my $cancelled_location_row;
        $handler->schema->txn_do( sub {

            if ( $container_row ) {
                $container_row->remove_item({
                    shipment_item => $shipment_item_row,
                });
            }

            $cancelled_location_row
                = $shipment_item_row->move_stock_to_cancelled_location(
                    $handler->operator_id,
                );

        });

        if ( $container_row ) {
            xt_success(
                "Cancelled Item removed from tote "
                . $container_row->id
                . " and put into the location "
                . $cancelled_location_row->location
            );
        }
        else {
            xt_success(
                "Cancelled Item put into the location "
                . $cancelled_location_row->location
            );
        }
    },
};


sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    my $redirect_on_fail_default = '/Fulfilment/PackingException';
    my ($situation, $bounce);
    eval {
        $situation = XTracker::Handler::Situation->new({
            situations               => situations(),
            validators               => $validators,
            parameters               => $parameters,
            redirect_on_fail_default => $redirect_on_fail_default,
            handler                  => $handler,
        });
        $bounce = $situation->evaluate;
    };
    if ($@) {
        xt_warn($@);
        return $handler->redirect_to($redirect_on_fail_default);
    }

    return $handler->redirect_to($bounce) if $bounce;

# Page setup
    # Set up the navigation and template
    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing Exception';
    $handler->{data}{subsubsection} = $situation->fancy_name;
    $handler->{data}{taskname}      = $situation->fancy_name;
    $handler->{data}{content}       = 'ordertracker/fulfilment/scan_pe_item.tt';

    my ($shipment,$shipment_item,$sku) = $situation->get_checked_objects( qw(
        shipment_id
        shipment_item_id
        sku
    ) );

    my $shipment_id      = $shipment->id;
    my $shipment_item_id = $shipment_item->id;

    # Add a 'back' link to the left-side nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, {
        'title' => 'Back',
        'url'   => "/Fulfilment/Packing/CheckShipmentException?shipment_id=" . $shipment_id
    });

    # Check if shipment signature match e.g. nothing has changed since we loaded the page.
    my $shipment_state_signature = md5_hex( encode_it($shipment->state_signature) );
    if ($handler->{param_of}{shipment_state_signature} ne "" && $shipment_state_signature ne $handler->{param_of}{shipment_state_signature}) {
        xt_warn(sprintf("Shipment %s has changed since you started working on it. Please scan the tote again.",$shipment->id));
        return $handler->redirect_to( '/Fulfilment/Packing/CheckShipmentException?shipment_id=' . $shipment->id );
    }

    my $shipment_item_info = get_shipment_item_info ( $handler->{dbh}, $shipment_id )
                                                    ->{ $shipment_item_id };

    # in case it could've been missing and we want to know where it's missing from
    if ($shipment_item->qc_failure_reason && $shipment_item->old_container_id) {
        $shipment_item_info->{old_container_id} = $shipment_item->old_container_id;
        $shipment_item_info->{old_container_is_pigeonhole}
            = $shipment_item->old_container_id->is_type('pigeon_hole');
    } elsif ($handler->{param_of}{old_container_id}) {
        $shipment_item_info->{old_container_id} = $handler->{param_of}{old_container_id};
        $shipment_item_info->{old_container_is_pigeonhole}
            = $handler->{param_of}{old_container_id}->is_type('pigeon_hole')
                if $handler->{param_of}{old_container_id};
    }

    # Clear qc info if it's important
    $shipment_item->update({ qc_failure_reason => '' })
        if $handler->{param_of}{clear_fail};

    # Get an image for the product
    $shipment_item_info->{image} = get_images( {
        product_id => $shipment_item->get_product_id,
        live => 1,
        schema => $handler->schema,
    } );

    $shipment_item_info->{product} = $shipment_item->product;
    # Save product data
    $handler->{data}{shipment}           = $shipment;
    $handler->{data}{shipment_item_id}   = $shipment_item_id;
    $handler->{data}{shipment_item_info} = $shipment_item_info;

    $handler->{data}{sku}                = $sku;

    # move on when we can, stay put when we can't
    $handler->{data}{situation} = $situation->next_situation;

    $shipment->discard_changes;
    $handler->{data}{shipment_state_signature} = md5_hex( encode_it($shipment->state_signature) );
    $handler->process_template( undef );

    return OK;
}

1;
