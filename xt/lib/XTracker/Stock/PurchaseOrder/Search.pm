package XTracker::Stock::PurchaseOrder::Search;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::XTemplate;
use XTracker::Navigation;
use XTracker::Constants                 qw( $PER_PAGE );
use XTracker::Constants::FromDB         qw( :purchase_order_status );
use Clone 'clone';
use XTracker::Session;
use XTracker::Utilities qw{ trim };

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);
    my $schema      = $handler->{schema};

    my $session         = XTracker::Session->session();
    my $operator_id     = defined $session->{operator_id} ? $session->{operator_id} : '';

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Purchase Order';
    $handler->{data}{subsubsection} = 'Search';
    $handler->{data}{content}       = 'purchase_order/search.tt';
    $handler->{data}{type}          = 'stockcontrol';
    $handler->{data}{javascript}    = ['goodsin.tt'];
    $handler->{data}{form_action}   = '/StockControl/PurchaseOrder';
    $handler->{data}{js}            = '/javascript/actb_suggest.js';

    # After permanently disabling the Import PO feature we now use always the purchase_order_no_edit navtype list
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'purchase_order_no_edit' } );

    my $h = $handler;
    # get form data

    $h->{data}{designers}   = $schema->resultset('Public::Designer')->drop_down_options;
    $h->{data}{seasons}     = $schema->resultset('Public::Season')->drop_down_options;
    $h->{data}{channels}    = $schema->resultset('Public::Channel')->drop_down_options;
    $h->{data}{po_types}    = $schema->resultset('Public::PurchaseOrderType')->drop_down_options;

    $h->{data}{search_purchase_orders} = $schema->resultset('Public::SuperPurchaseOrder');

    # clean params, remove undefined or zero length parameters
    for (keys %{$h->{param_of}}) {
        delete $h->{param_of}{$_} unless defined $h->{param_of}{$_};
        delete $h->{param_of}{$_} unless length $h->{param_of}{$_};
    }
    delete $h->{param_of}{submit};

    # search form submitted
    if (delete $h->{param_of}{search}){
        $h->{data}{search}  = 1;
        my $page = delete $h->{param_of}{page} || 1;

        # Store search terms for the page
        $h->{data}{search_terms} = clone($h->{param_of});

        my %query_params = map { $_ => trim($h->{param_of}->{$_}) } keys %{ $h->{param_of} };
        $h->{data}{purchase_orders} = $schema->resultset('Public::SuperPurchaseOrder')->stock_in_search(
            \%query_params,
            {cache => 1, rows=>$PER_PAGE, page=> $page, join=>'season', order_by => { -desc => [qw/season.season_year season.season_code/] } }
        );

        $h->{data}{pager} = $h->{data}{purchase_orders}->pager;
    }

    $handler->process_template( undef );

    return OK;

}

1;
