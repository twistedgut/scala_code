package XTracker::Stock::GoodsIn::StockIn;
use strict;
use warnings;
use XTracker::Handler;
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Constants qw ( $PER_PAGE );
use Clone 'clone';
use XTracker::XTemplate;
use XTracker::Navigation;
use XTracker::Utilities qw{ trim };

sub handler {
    my $h = XTracker::Handler->new(shift);

    # Redirect to printer selection screen unless operator has one set
    return $h->redirect_to($h->printer_station_uri)
        unless $h->operator->has_location_for_section('stock_in');

    my $schema = $h->schema;

    $h->add_to_data({
        section       => 'Goods In',
        subsection    => 'Stock In',
        subsubsection => '',
        content       => 'purchase_order/search.tt',
        javascript    => ['goodsin.tt'],
        type          => 'StockIn',
        form_action   => '/GoodsIn/StockIn',
        js            => '/javascript/actb_suggest.js',
        # get form data
        designers              => $schema->resultset('Public::Designer')->designer_list,
        seasons                => $schema->resultset('Public::Season')->season_list,
        channels               => $schema->resultset('Public::Channel')->channel_list,
        po_types               => $schema->resultset('Public::PurchaseOrderType')->po_types,
        search_purchase_orders => $schema->resultset('Public::SuperPurchaseOrder')->incomplete,
    });

    push @{ $h->{data}->{sidenav}[0]{'None'} }, {
        title => 'Set Stock In Station',
        url   => '/My/SelectPrinterStation?section=GoodsIn&subsection=StockIn&force_selection=1',
     };
    # clean params
    for (keys %{$h->{param_of}}) {
        delete $h->{param_of}{$_} unless defined $h->{param_of}{$_};
        delete $h->{param_of}{$_} unless length $h->{param_of}{$_};
    }
    delete $h->{param_of}{submit};

    # search form submitted
    if (delete $h->{param_of}{search}) {
        $h->{data}{search}  = 1;

        my $page = delete $h->{param_of}{page} || 1;

        # Store search terms for the page
        $h->{data}{search_terms} = clone($h->{param_of});


        my %query_params = map { $_ => trim($h->{param_of}->{$_}) } keys %{ $h->{param_of} };
        $h->{data}{purchase_orders} = $schema->resultset('Public::SuperPurchaseOrder')->stock_in_search(
            \%query_params,
            {cache => 1, rows => $PER_PAGE, page => $page, join=>'season', order_by => { -desc => [qw/season.season_year season.season_code/] } }
        );
        $h->{data}{pager} = $h->{data}{purchase_orders}->pager;
    }

    $h->process_template;
    return OK;
}
1;
