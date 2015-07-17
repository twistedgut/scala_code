package XTracker::Stock::HSCode::HSCodeForm;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Address qw( get_country_list );
use XTracker::Database::Attributes qw( get_country_by_id );
use XTracker::Database::Duty qw( get_hs_code get_hs_codes get_hs_code_duty_rates get_country_duty_rates );

use vars qw($r $operator_id);

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section} = 'Stock Control';
    $handler->{data}{subsection}    = 'Duty Rates';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'stocktracker/hscode/form.tt';

    # full list of countries and hs codes for form selects
    $handler->{data}{countries} = get_country_list( $handler->{dbh} );
    $handler->{data}{hs_codes}  = get_hs_codes( $handler->{dbh} );

    # use country name as hash key so we can sort alphabetically
    foreach my $id ( keys %{ $handler->{data}{countries} } ){
            $handler->{data}{sorted_countries}{ $handler->{data}{countries}{$id}{country} } = $id;
    }


    # edit hs code rates
    if ( $handler->{param_of}{hs_code_id} ){
        $handler->{data}{hs_code_id}    = $handler->{param_of}{hs_code_id};
        $handler->{data}{hs_code}       = get_hs_code( $handler->{dbh}, $handler->{param_of}{hs_code_id} );
        $handler->{data}{duty_rates}    = get_hs_code_duty_rates( $handler->{dbh}, $handler->{param_of}{hs_code_id} );

        push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => '/StockControl/DutyRates' } );
    }
    # edit country rates
    elsif ( $handler->{param_of}{country_id} ){
        $handler->{data}{country_id}    = $handler->{param_of}{country_id};
        $handler->{data}{country}       = get_country_by_id( $handler->{dbh}, $handler->{param_of}{country_id} );
        $handler->{data}{duty_rates}    = get_country_duty_rates( $handler->{dbh}, $handler->{param_of}{country_id} );

        push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => '/StockControl/DutyRates' } );
    }

    $handler->process_template( undef );

    return OK;
}

1;
