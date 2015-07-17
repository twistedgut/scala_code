package XTracker::Stock::Actions::SetSampleGoodsOutToStock;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Shipment                qw( create_shipment create_shipment_item );
use XTracker::Database::Stock                   qw( check_stock_location get_stock_location_quantity update_quantity insert_quantity delete_quantity );
use XTracker::Database::StockTransfer   qw( create_stock_transfer set_stock_transfer_status );
use XTracker::Database::Channel                 qw( get_channels );
use XTracker::Utilities                                 qw( get_date_db url_encode );
use XTracker::Config::Local                             qw( config_var samples_email dc_address );
use XTracker::Constants::FromDB qw(
    :flow_status
    :shipment_class
    :shipment_status
    :shipment_type
);
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $ret_url     = "";
    my $ret_params  = "";

    my $schema = $handler->schema;

    if ( my $product_id = $handler->{param_of}{product_id} ) {

        my $type        = 'product_id';
        my $id          = $product_id;
        my $counter     = 0;

        $ret_params     = '?'.$type."=".$id;

        eval {
            $schema->txn_do(sub{
                my $dbh = $schema->storage->dbh;
                my $channels = get_channels($dbh);
                foreach my $key ( keys %{ $handler->{param_of} } ) {
                    if ( $key =~ m/^vendor_sample-(.*)-(.*)/ ) {
                        my $shipment_id = _dodo( $schema, $handler->{param_of}{$key}, $handler->operator_id, $2, $channels->{$2}{config_section} );
                        $counter++;
                    }
                }
            });
        };
        if ( $@ || !$counter ) {
            if ($@) {
                xt_warn($@);
            }
            else {
                xt_warn("No Stock Selected to Move");
            }
        }
        else {
            xt_success("Stock Rotated");
        }
    }

    $ret_url        = "/StockControl/Sample/GoodsOut";

    return $handler->redirect_to( $ret_url.$ret_params );
}

sub _dodo {
    my ( $schema, $variant_id, $operator_id, $channel_id, $channel_conf_section )  = @_;
    my $dbh = $schema->storage->dbh;

    my $channel = $schema->resultset('Public::Channel')->find({ id => $channel_id });
    my $dc_address = dc_address($channel);

    my $stock_transfer_id = create_stock_transfer( $dbh, 1, 1, $variant_id, $channel_id );

    set_stock_transfer_status( $dbh, $stock_transfer_id, 2 );

    my $date = get_date_db( { dbh => $dbh } );

    my %address = (
        first_name     => "Vendor",
        last_name      => "Sample",
        address_line_1 => $dc_address->{addr1},
        address_line_2 => $dc_address->{addr2},
        # WHM-1802 - split the postcode out of addr3 - let's remerge them here
        # into one field again so the label still prints out as it used to
        address_line_3 => ( join q{, },
            $dc_address->{addr3},
            $dc_address->{postcode} || ()
        ),
        towncity       => $dc_address->{city},
        county         => "",
        country        => $dc_address->{country},
        postcode       => "",
    );

    my %new_shipment = (
        date                 => $date,
        type_id              => $SHIPMENT_TYPE__PREMIER,
        class_id             => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
        status_id            => $SHIPMENT_STATUS__DISPATCHED,
        address_id           => '',
        gift                 => "false",
        gift_message         => '',
        email                => samples_email($channel_conf_section),
        telephone            => '',
        mobile_telephone     => '',
        pack_instruction     => 'Vendor Sample Shipment - No extra packaging',
        shipping_charge      => 0,
        comment              => "",
        force_manual_booking => 1,
        address              => \%address,
    );

    my $new_shipment_id = create_shipment( $dbh, $stock_transfer_id, "transfer", \%new_shipment );

    # shipment_item_status is Dispatched, not new, big thanks to Ops for noticing.
    my %new_shipment_item = (
        variant_id    => $variant_id,
        unit_price    => 0,
        tax           => 0,
        duty          => 0,
        status_id     => 5,
        special_order => "false"
    );

    create_shipment_item( $dbh, $new_shipment_id, \%new_shipment_item );

    my $variant_qty     = get_stock_location_quantity( $dbh, {
        variant_id => $variant_id,
        location   => "Sample Room",
        channel_id => $channel_id,
        status_id  => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
    });

    update_quantity( $dbh, {
        variant_id        => $variant_id,
        location          => "Sample Room",
        quantity          => ($variant_qty * -1),
        type              => 'dec',
        channel_id        => $channel_id,
        current_status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
    } );

    if ( get_stock_location_quantity( $dbh, {
        variant_id => $variant_id,
        location   => "Sample Room",
        channel_id => $channel_id,
        status_id  => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
    } ) <= 0 ) {
        delete_quantity( $dbh, {
            variant_id => $variant_id,
            location   => "Sample Room",
            channel_id => $channel_id,
            status_id  => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        } );
    }

    if ( check_stock_location( $dbh, {
        variant_id => $variant_id,
        location => "Transfer Pending",
        channel_id => $channel_id,
        status_id  => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS
    } ) > 0 ) {
        update_quantity( $dbh, {
            variant_id        => $variant_id,
            location          => "Transfer Pending",
            quantity          => $variant_qty,
            type              => 'inc',
            channel_id        => $channel_id,
            current_status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        } );
    }
    else {
        insert_quantity( $dbh, {
            variant_id        => $variant_id,
            location          => "Transfer Pending",
            quantity          => $variant_qty,
            channel_id        => $channel_id,
            initial_status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        } );
    }

    return $new_shipment_id;
}

1;
