package XTracker::Order::Functions::Order::OrderLog;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Config::Local 'config_var';
use XTracker::Constants::FromDB ':allocation_item_status';

use XTracker::Utilities qw( parse_url );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Order Log';
    $handler->{data}{content}       = 'ordertracker/shared/orderlog.tt';

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;
    # get id of order we're working on and order data for display
    $handler->{data}{orders_id}         = $handler->{param_of}{orders_id};
    $handler->{data}{order}             = get_order_info( $dbh, $handler->{data}{orders_id} );
    $handler->{data}{order_log}         = get_order_log( $dbh, $handler->{data}{orders_id} );
    $handler->{data}{order_address_log} = get_order_address_log( $dbh, $handler->{data}{orders_id} );
    $handler->{data}{shipments}         = get_order_shipment_info( $dbh, $handler->{data}{orders_id} );

    $handler->{data}{order_created_in_xt_date} = $handler->{data}{order}{order_created_in_xt_date};
    $handler->{data}{live_order_taken_date}    = $handler->{data}{order}{live_order_taken_date};

    # loop over order address log and get full address
    foreach my $log_data ( values %{ $handler->{data}{order_address_log} } ) {
        @{$log_data}{qw!from_address to_address!} = map {
            get_address_info( $schema, $log_data->{$_} )
        } (qw!changed_from changed_to!);
    }

    my @shipment_ids = keys %{ $handler->{data}{shipments} };

    # show allocation item log if PRL on.
    my $show_alloc_log = (config_var('PRL', 'rollout_phase') > 0);
    my $allocation_item_log;

    if ($show_alloc_log) {
        $allocation_item_log = $schema->resultset('Public::AllocationItemLog')->filter_by_shipment_ids(
            @shipment_ids
        );
    };

    # loop over shipments and get shipment info
    foreach my $ship_id (@shipment_ids) {
        my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_id );
        my $shipment_hash = $handler->{data}{shipments}{$ship_id};

        $shipment_hash->{shipment_box_log} = [
            $shipment->shipment_boxes->search_related( 'shipment_box_logs',
                {}, { order_by => [qw/shipment_box_id timestamp/] }
            )->all
        ];
        $shipment_hash->{shipment_log}         = get_shipment_log( $dbh, $ship_id );
        $shipment_hash->{shipment_item_log}    = get_shipment_item_log($schema, $ship_id);
        $shipment_hash->{shipment_address_log} = get_shipment_address_log( $dbh, $ship_id );
        # TODO - DJ: Get this working with joins instead of prefetch - looks
        # like a bug in DBIC :(
#        $shipment->search_related('shipment_message_logs', undef, {
#            order_by => 'me.date',
#            join => { operator => 'department' },
#            '+columns' => [qw{operator.name department.department}],
#        })->all
        $shipment_hash->{message_log} = [
            $shipment->search_related('shipment_message_logs', undef, {
                order_by => 'me.date',
                prefetch => { operator => 'department' },
            })->all
        ];
        $shipment_hash->{shipment_signature_log} = [
            $shipment->log_shipment_signature_requireds
                     ->search( {}, { order_by => 'id ASC' } )
                     ->all ];

        $shipment_hash->{shipment_hold_log} = [
            $shipment->search_related('shipment_hold_logs',
                {}, { order_by => 'id ASC' }
            )->all,
        ];

        # loop over shipment address log and get address info
        foreach my $log_data ( values %{ $shipment_hash->{shipment_address_log} } ) {
            @{$log_data}{qw!from_address to_address!} = map {
                get_address_info( $schema, $log_data->{$_} )
            } (qw!changed_from changed_to!);
        }

        # filter the allocation_item_log
        if ($show_alloc_log) {

            $shipment_hash->{allocation_item_log} = [ grep { $_->allocation_item->shipment_item->shipment_id == $ship_id } @$allocation_item_log ];
        }

    }

    # back link in left nav
    push @{ $handler->{data}{sidenav}[0]{'None'} }, {
        'title' => 'Back',
        'url' => "$short_url/OrderView?order_id=$handler->{data}{orders_id}",
    };

    # set sales channel to display on page
    $handler->{data}{sales_channel} = $handler->{data}{order}{sales_channel};

    return $handler->process_template;
}

1;
