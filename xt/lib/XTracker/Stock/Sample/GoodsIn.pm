package XTracker::Stock::Sample::GoodsIn;

use strict;
use warnings;

use XTracker::Constants::FromDB qw{:shipment_status :department};
use XTracker::Handler;
use XTracker::Navigation;
use XTracker::Database::StockTransfer   qw( get_stock_transfer_shipments );
use XTracker::Image                     qw{ get_image_list };

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    $handler->{data}{content}           = 'stocktracker/sample/goodsin.tt';
    $handler->{data}{section}           = 'Stock Control';
    $handler->{data}{subsection}        = 'Sample';
    $handler->{data}{subsubsection}     = 'Goods In';
    $handler->{data}{sidenav}           = build_sidenav( { navtype => 'stockc_sample' } );

    $handler->{data}{can_receive}   = $handler->department_id == $DEPARTMENT__SAMPLE;
    $handler->{data}{from_stock}    = get_stock_transfer_shipments( $dbh, { status_list => [ $SHIPMENT_STATUS__DISPATCHED ] });

    $handler->{data}{images} = get_image_list( $schema, [map {
        +{ id => $_->{product_id}, live => $_->{live}, }
    } map { @{$_//[]} } values %{$handler->{data}{from_stock}}]);

    return $handler->process_template;
}

1;
