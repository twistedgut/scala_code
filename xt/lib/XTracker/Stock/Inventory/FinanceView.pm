package XTracker::Stock::Inventory::FinanceView;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Database::Logging    qw( get_delivery_log );
use XTracker::Database::Pricing    qw( get_pricing );
use XTracker::Database::Product    qw( get_product_summary );
use XTracker::Handler;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $prod_id = $handler->{param_of}{'product_id'} || 0;
    my %args    = ( type => 'product_id', id => $prod_id );

    $args{'navtype'} = 'product';

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);

    $mon = $mon + 1;
    if ($mon < 10){ $mon = "0".$mon; }
    if ($mday < 10){ $mday = "0".$mday; }

    # TT Data structure
    $handler->{data}{content}       = 'inventory/financeview.tt';
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = 'Finance View';
    $handler->{data}{javascript}    = 'product.tt';
    $handler->{data}{current_date}  = ($year + 1900).$mon.$mday;
    $handler->{data}{sidenav}       = [{
        "None" => [{
            'title' => 'Back',
            'url'   => "/StockControl/Inventory",
        }]
    }];

    # get common product summary data for header
    $handler->{data}{product_id} = $prod_id;
    $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;
    my $voucher = $schema->resultset('Voucher::Product')->find($prod_id);
    if ( $voucher ) {
        my $delivery_log_rs = $voucher->delivery_logs->order_for_log;
        $handler->{data}{log_data} = {
            $voucher->channel->name => [
                map {
                    time => $_->date->strftime('%R'),
                    date => $_->date->strftime('%F'),
                    quantity => $_->quantity,
                    operator => $_->operator->name,
                    delivery_id => $_->delivery_id,
                    sales_channel => $voucher->channel->name,
                    notes => ( $_->notes ? $_->notes : 'none' ),
                    action => $_->delivery_action->action,
                    type => 'Main',
                }, $delivery_log_rs->all
            ]
        };

        # Don't think most of these fields apply to vouchers... so populating
        # with N/A - DJ
        # NOTE: This assumes the three variables never change too... somewhere
        # further down the line this may change
        my $wholesale_currency = $voucher->stock_orders
                                         ->related_resultset('purchase_order')
                                         ->related_resultset('currency')
                                         ->first;
        $handler->{data}{purchase_pricing} = [{
            currency              => $wholesale_currency->currency,
            uk_landed_cost        => ( $voucher->landed_cost ? $voucher->landed_cost : '-' ),
            wholesale_currency_id => $wholesale_currency->id,
        }];
        $handler->{data}{purchase_pricing}[0]{$_} = 'N/A - Gift Voucher'
            for qw{currency_id original_wholesale trade_discount uplift_cost uplift wholesale_price};
        $handler->{data}{product}{$_} = 'N/A - Gift Voucher'
            for qw{payment_term payment_deposit payment_settlement_discount};
    }
    else {
        $handler->{data}{purchase_pricing} = get_pricing( $dbh, $prod_id, 'purchase' );
        $handler->{data}{log_data}         = get_delivery_log( $dbh, $prod_id );
    }

    $handler->process_template( undef );

    return OK;
}

1;

__END__
