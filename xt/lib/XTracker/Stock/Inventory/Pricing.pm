package XTracker::Stock::Inventory::Pricing;
use strict;
use warnings;

use DateTime;
use XTracker::Handler;
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Navigation qw( get_navtype build_sidenav );
use XTracker::Database::Attributes qw( get_paymentterm_atts get_paymentdeposit_atts get_paymentsettlementdiscount_atts );
use XTracker::Database::Product qw (:DEFAULT get_price_audit_log get_product_summary);
use XTracker::Database::Currency qw( get_local_currency_id );
use XTracker::Database::Operator qw( get_operator_by_id );
use XTracker::Database::Pricing qw( get_pricing get_currency
                                    get_markdown get_buy_conversion_rates
                                  );

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw( :department );
use Data::Dump 'pp';


### Subroutine : handler                        ###
# usage        : n/a                              #
# description  : Edit Pricing page for Retail     #
# parameters   : POST product_id                  #
# tt-template  : inventory/pricing.tt             #
# tt-variables : see $data                        #

sub handler {
    my $handler     = XTracker::Handler->new(shift);
    my $dt          = DateTime->now( time_zone => "local" );

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = 'Pricing';
    $handler->{data}{content}       = 'stocktracker/inventory/pricing.tt';
    $handler->{data}{javascript}    = 'product.tt';
    $handler->{data}{current_date}  = $dt->year.$dt->month.$dt->day;

    # get product from url
    $handler->{data}{product_id}    = $handler->{param_of}{product_id};

    # hash of arguments to pass to functions
    $handler->{data}{sidenav}   = build_sidenav( { type => 'product_id', id => $handler->{data}{product_id}, navtype => get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->{data}{auth_level}, type => 'product', id => $handler->{data}{operator_id} } ) } );

    # get common product summary data for header
    $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{param_of}{product_id} ) );

    $handler->{data}{voucher} = XTracker::Database::Product::is_voucher($handler->dbh, {id=>$handler->{data}{product_id}, type=>'product_id'});

    # all pricing data for display
    $handler->{data}{purchase_pricing}  = get_pricing( $handler->{dbh}, $handler->{data}{product_id}, 'purchase' );

    if ($handler->{data}{voucher}) {
        my $v = $handler->schema->resultset('Voucher::Product')->find($handler->{data}{voucher});
        $handler->{data}{default_pricing} = [{currency => $v->currency->currency, currency_id=>$v->currency_id, price=>$v->value}];
    }
    else {
        $handler->{data}{default_pricing} = get_pricing( $handler->{dbh}, $handler->{data}{product_id}, 'default' );
    }

    $handler->{data}{region_pricing}    = get_pricing( $handler->{dbh}, $handler->{data}{product_id}, 'region' );
    $handler->{data}{country_pricing}   = get_pricing( $handler->{dbh}, $handler->{data}{product_id}, 'country' );
    $handler->{data}{markdown}          = get_markdown( $handler->{dbh}, $handler->{data}{product_id} );

    $handler->{data}{price_log}         = get_price_audit_log( $handler->{dbh}, { 'product_id' => $handler->{data}{product_id} } );
    $handler->{data}{currency}          = get_currency( $handler->{dbh} );
    $handler->{data}{conversion}        = get_buy_conversion_rates( $handler->{dbh} );
    $handler->{data}{local_currency_id} = get_local_currency_id( $handler->{dbh} );
    $handler->{data}{paymentterms}      = [ 'payment_term', get_paymentterm_atts($handler->{dbh}) ];
    $handler->{data}{paymentdeposit}    = [ 'payment_deposit', get_paymentdeposit_atts($handler->{dbh}) ];
    $handler->{data}{paymentsettlement} = [ 'payment_settlement_discount', get_paymentsettlementdiscount_atts($handler->{dbh}) ];
    $handler->{data}{dc_country}        = config_var('DistributionCentre', 'country');

    $handler->process_template( undef );

    return OK;
}

1;
