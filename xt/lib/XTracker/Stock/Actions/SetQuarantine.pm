package XTracker::Stock::Actions::SetQuarantine;

use strict;
use warnings;

use Carp;

use Try::Tiny;

use XTracker::Handler;
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Error qw( xt_warn );
use XTracker::Utilities qw( :string );
use XTracker::PrintFunctions;
use XTracker::Barcode;
use XTracker::Session;
use XTracker::Database::Delivery qw( create_delivery create_quarantine_process set_delivery_status set_delivery_item_status );
use XTracker::Database::Logging qw( :rtv );
use XTracker::Database::StockProcess qw( set_stock_process_status split_stock_process complete_stock_process );
use XTracker::Database::Stock;
use XTracker::Database::Return;
use XTracker::Database::Shipment;
use XTracker::Database::RTV qw( create_rtv_stock_process );
use XTracker::Constants::FromDB qw(
    :delivery_item_status
    :delivery_status
    :delivery_type
    :rtv_action
    :stock_process_status
    :stock_process_type
);
use XTracker::Document::RTVStockSheet;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    # We might want to add a 'quarantine' section one day, but it looks like
    # all RTV currently prints to the same printers, so let's not unnecessarily
    # add more config values
    return $handler->redirect_to($handler->printer_station_uri)
        unless $handler->operator->has_location_for_section('rtv_workstation');

    try {
        $handler->schema->txn_do(
            sub {
                if ($handler->{param_of}{stock_process_id}) {
                    ## goods in or returns in quarantine
                    _process_delivery_quarantine( $handler );
                }
                else {
                    ## from stock quarantine
                    _process_stock_quarantine( $handler );
                }
            }
        );
    }
    catch {
        xt_warn(strip_txn_do($_));
    };

    return $handler->redirect_to("/StockControl/Quarantine");
}

sub _process_delivery_quarantine {
    my $handler = shift;

    my $dbh = $handler->dbh;

    my ($type, $process_id, $delivery_item_id, $quantity_id,
        $quarantine, $stock, $rtv, $rtc, $variant_id) =
        trim( @{$handler->{param_of}{ qw( type stock_process_id delivery_item_id quantity_id
                                          quarantine stock rtv rtc variant_id ) }} );
    $quarantine ||= 0;
    $stock      ||= 0;
    $rtv        ||= 0;

    die "Invalid quarantine quantity '$quarantine'\n" if $quarantine  !~ m{\A\d+\z}xms;
    die "Invalid stock quantity '$stock'\n"           if $stock       !~ m{\A\d+\z}xms;
    die "Invalid rtv quantity '$rtv'\n"               if $rtv         !~ m{\A\d+\z}xms;

    if ($stock > 0) {
        my $status_id = $type eq 'ReturnsIn'
            ? $STOCK_PROCESS_STATUS__PUTAWAY
            : $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED;

        my $group  = 0;
        my $new_sp = split_stock_process( $dbh, $STOCK_PROCESS_TYPE__MAIN, $process_id, $stock, \$group, $delivery_item_id );
        set_stock_process_status( $dbh, $new_sp, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED );
    }

    if ($rtv > 0) {
        set_stock_process_status( $dbh, $process_id, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED );
    }

    my $processed = $stock + $rtv + $rtc;

    ### quarantine process completed
    if ($processed == $quarantine) {

        complete_stock_process( $dbh, $process_id );

        my $qry = "delete from quantity where id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $quantity_id );

    } else {
        my $qry = "update quantity set quantity = (quantity - ?) where id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $processed, $quantity_id );
    }

    return;
}

sub _process_stock_quarantine {
    my $handler = shift;

    my ( $dbh, $operator_id, $uri_path )  = ( $handler->dbh, $handler->operator_id, $handler->path );

    my ($quantity_id, $variant_id, $quarantine, $stock, $rtv, $dead, $reason, $channel_id )
       = trim( @{$handler->{param_of}}{ qw ( quantity_id variant_id quarantine stock rtv dead reason channel_id ) } );

    $quarantine ||= 0;
    $stock      ||= 0;
    $rtv        ||= 0;
    $dead       ||= 0;
    $reason     //= q{};
    $channel_id //= q{};

    die "Invalid channel_id '$channel_id'\n"          if $channel_id  !~ m{\A\d+\z}xms;
    die "Invalid quantity_id '$quantity_id'\n"        if $quantity_id !~ m{\A\d+\z}xms;
    die "Invalid variant_id '$variant_id'\n"          if $variant_id  !~ m{\A\d+\z}xms;
    die "Invalid quarantine quantity '$quarantine'\n" if $quarantine  !~ m{\A\d+\z}xms;
    die "Invalid stock quantity '$stock'\n"           if $stock       !~ m{\A\d+\z}xms;
    die "Invalid rtv quantity '$rtv'\n"               if $rtv         !~ m{\A\d+\z}xms;
    die "Invalid dead quantity '$dead'\n"             if $dead        !~ m{\A\d+\z}xms;
    die "Invalid operator_id '$operator_id\n"         if $operator_id !~ m{\A\d+\z}xms;

    die "Quantity mismatch! Total of quantities entered exceeds quarantine quantity\n"
        if ($stock + $rtv + $dead) > $quarantine;

    # create a quarantine delivery for item
    my ($delivery_id, $delivery_item_id) = _create_quarantine_delivery($dbh, $variant_id, $channel_id);

    ### create stock_process records as necessary
    my $stock_sheet_origin  = 'quarantine';

    # TODO - Uncomment this when SHIP-976 has been merged
    my $printer_location = 'RTV Workstation';
    #my $printer_location = $handler->operator->printer_location
    #    or die "No printer station selected - please select one\n";

    if ( $stock > 0 ) {
        my $group_stock = 0;

        create_rtv_stock_process({
            dbh                     => $dbh,
            stock_process_type_id   => $STOCK_PROCESS_TYPE__QUARANTINE_FIXED,
            delivery_item_id        => $delivery_item_id,
            quantity                => $stock,
            process_group_ref       => \$group_stock,
            stock_process_status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            originating_path        => $uri_path,
            notes                   => undef,
        });

        XTracker::Document::RTVStockSheet->new(
            group_id        => $group_stock,
            document_type   => 'main',
            origin          => $stock_sheet_origin
        )->print_at_location($printer_location);

        my $sp_group_rs = $handler->schema->resultset('Public::StockProcess')->search({
            group_id => $group_stock,
            type_id => $STOCK_PROCESS_TYPE__QUARANTINE_FIXED,
            status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            quantity => $stock
        });

        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::PreAdvice',
            { sp_group_rs => $sp_group_rs },
        );
    }

    if ( $rtv > 0 ) {
        my $group_rtv = 0;
        my $quantity_details_ref = get_quantity_details($dbh, { quantity_id => $quantity_id } );

        create_rtv_stock_process({
            dbh                     => $dbh,
            stock_process_type_id   => $STOCK_PROCESS_TYPE__RTV,
            delivery_item_id        => $delivery_item_id,
            quantity                => $rtv,
            process_group_ref       => \$group_rtv,
            stock_process_status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            originating_path        => $uri_path,
            notes                   => $quantity_details_ref->{details},
        });

        my $document = XTracker::Document::RTVStockSheet->new(
            group_id        => $group_rtv,
            document_type   => 'rtv',
            origin          => $stock_sheet_origin
        );

        $document->print_at_location($printer_location);

        # in phase < 3 this probably won't actually be sent, but most future-proof to
        # prepare the message here anyway and let the Producer sort out whether to send it or not.
        my $sp_group_rs = $handler->schema->resultset('Public::StockProcess')->search({
            group_id => $group_rtv,
            type_id => $STOCK_PROCESS_TYPE__RTV,
            status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            quantity => $rtv
        });

        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::PreAdvice',
            { sp_group_rs => $sp_group_rs },
        );
    }

    if ( $dead > 0 ) {
        my $group_dead = 0;

        create_rtv_stock_process({
            dbh                     => $dbh,
            stock_process_type_id   => $STOCK_PROCESS_TYPE__DEAD,
            delivery_item_id        => $delivery_item_id,
            quantity                => $dead,
            process_group_ref       => \$group_dead,
            stock_process_status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            originating_path        => $uri_path,
        });

        my $document = XTracker::Document::RTVStockSheet->new(
            group_id        => $group_dead,
            document_type   => 'dead',
            origin          => $stock_sheet_origin
        );

        $document->print_at_location($printer_location);

        my $sp_group_rs = $handler->schema->resultset('Public::StockProcess')->search({
            group_id => $group_dead,
            type_id => $STOCK_PROCESS_TYPE__DEAD,
            status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            quantity => $dead
        });

        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::PreAdvice',
            { sp_group_rs => $sp_group_rs },
        );
    }

    my $processed = $stock + $rtv + $dead;

    ### quarantine process completed
    if ($processed == $quarantine) {

        my $qry = "delete from quantity_details where quantity_id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $quantity_id );

        $qry = "delete from quantity where id = ?";
        $sth = $dbh->prepare($qry);
        $sth->execute( $quantity_id );
    } else {
        my $qry = "update quantity set quantity = (quantity - ?) where id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $processed, $quantity_id );
    }

    my %quarantine_options = (
        'stock' => {
            'quantity'   =>  $stock,
            'rtv_action' => $RTV_ACTION__QUARANTINE_FIXED
        },
        'rtv'   => {
            'quantity'   =>  $rtv,
            'rtv_action' => $RTV_ACTION__QUARANTINE_RTV
        },
        'dead'  => {
            'quantity'   =>  $dead,
            'rtv_action' => $RTV_ACTION__QUARANTINE_DEAD
        }
    );

    # $quarantine = total quantity in quarantine
    # we will calculate the balance here itself
    my $balance = $quarantine;
    foreach my $quarantine_data ( grep { $_->{quantity} } values %quarantine_options ) {
        $balance -= $quarantine_data->{quantity};
        log_rtv_stock({
            dbh           => $dbh,
            variant_id    => $variant_id,
            rtv_action_id => $quarantine_data->{rtv_action},
            quantity      => ($quarantine_data->{quantity} * -1),
            balance       => $balance,
            operator_id   => $operator_id,
            notes         => $reason,
            channel_id    => $channel_id,
        });
    }

    return;
}

sub _create_quarantine_delivery {
    my ( $dbh, $variant_id, $channel_id ) = @_;

    # array ref of delivery item hashrefs to create delivery later
    my $di_ref = [];

    # create processed quarantine entry
    my $process_id = create_quarantine_process( $dbh, $variant_id, $channel_id );

    # pass item into delivery item data
    push @{$di_ref}, {
        quarantine_process_id => $process_id,
        packing_slip          => 1,
        type_id               => $DELIVERY_TYPE__PROCESSED_QUARANTINE,
    };

    # create delivery
    my $delivery_id = create_delivery($dbh, { delivery_type_id => $DELIVERY_TYPE__PROCESSED_QUARANTINE, delivery_items => $di_ref } );

    # set delivery status
    set_delivery_status( $dbh, $delivery_id, 'delivery_id', $DELIVERY_STATUS__PROCESSING );

    # get id's of items we've just created
    my $qry = "SELECT id FROM delivery_item WHERE delivery_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($delivery_id);
    my $row = $sth->fetchrow_arrayref();

    my $delivery_item_id = $row->[0];

    # update delivery item status
    set_delivery_item_status( $dbh, $delivery_item_id, 'delivery_item_id', $DELIVERY_ITEM_STATUS__PROCESSING);

    return $delivery_id, $delivery_item_id;
}

1;
