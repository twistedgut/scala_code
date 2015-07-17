package XTracker::Stock::Sample::Request;

use strict;
use warnings;

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :department
    :shipment_status
);
use XTracker::Database::Stock         qw( :DEFAULT get_saleable_item_quantity );
use XTracker::Database::StockTransfer qw( get_pending_stock_transfers get_stock_transfer_shipments );
use XTracker::Handler;
use XTracker::Navigation              qw( build_sidenav );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{content}           = 'stocktracker/sample/request.tt';
    $handler->{data}{section}           = 'Stock Control';
    $handler->{data}{subsection}        = 'Sample';
    $handler->{data}{subsubsection}     = 'Transfer Requests';
    $handler->{data}{sidenav}           = build_sidenav( { navtype => 'stockc_sample' } );
    $handler->{data}{type}              = 'stock';

    #
    # User is Request a Sample from Stock
    #

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    $handler->{data}{can_action_by_department} = grep {
        $handler->operator->department_id == $_
    } ($DEPARTMENT__STOCK_CONTROL, $DEPARTMENT__DISTRIBUTION_MANAGEMENT);
    $handler->{data}{is_manager}
        = $handler->auth_level == $AUTHORISATION_LEVEL__MANAGER;

    $handler->{data}{pending}   = get_pending_stock_transfers( $dbh );

    foreach my $channel ( keys %{$handler->{data}{pending}} ) {
        $handler->{data}{channel_list}{$channel} = scalar(keys %{ $handler->{data}{pending}{$channel} });
        foreach my $pender ( keys %{ $handler->{data}{pending}{$channel} } ) {
            my $free_stock  = get_saleable_item_quantity( $dbh, ${ $handler->{data}{pending}{$channel} }{$pender}{product_id} );
            ${ $handler->{data}{pending}{$channel} }{$pender}{free_stock}   = $free_stock->{ $channel }{ $handler->{data}{pending}{$channel}{$pender}{variant_id} };
        }
    }

    $handler->{data}{stock_shipments} = get_stock_transfer_shipments( $dbh, {
        status_list => [ $SHIPMENT_STATUS__FINANCE_HOLD, $SHIPMENT_STATUS__PROCESSING, $SHIPMENT_STATUS__HOLD ]
    } );

    # Mark items as packed if they are
    my $rs = $schema->resultset('Public::Shipment');
    $_->{is_packed} = $rs->find($_->{id})->is_shipment_completely_packed
        for map { @{$_//[]} } values %{$handler->{data}{stock_shipments}};

    foreach my $channel ( keys %{ $handler->{data}{stock_shipments} } ) {
        $handler->{data}{channel_list}{$channel}    += scalar(@{ $handler->{data}{stock_shipments}{$channel} });
    }

    return $handler->process_template;
}

1;
