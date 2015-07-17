package XTracker::Admin::ExchangeRates;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Handler;
use XTracker::Session;
use XTracker::Navigation qw( get_navtype build_nav build_sidenav );
use XTracker::Schema;
use XTracker::Error;

sub handler {

    my $r       = shift;

    # get a handler and set up all the common stuff
    my $handler = XTracker::Handler->new($r);

    my $exchange_rate_rs
        = $handler->{schema}->resultset('Public::LocalExchangeRate');
    my $country_rs
        = $handler->{schema}->resultset('Public::Country');

    my $country_id  = $handler->{param_of}{'select_country'};
    my $new_rate    = $handler->{param_of}{'new_rate'};

    if ( $new_rate ) {
        if ( $new_rate =~ /^(\d*\.?\d*)$/ ) {
            if ( $exchange_rate_rs->set_new_rate( $country_id, $new_rate ) ) {
                xt_info("Rate changed to $1");
            }
        }
        else {
            xt_warn("Please enter a valid rate, this value $new_rate is not correct!");

        }
    }

    # fetch the user's session
#    my $session = XTracker::Session->session();

    $handler->{data}{yui_enabled}       = 1;
    $handler->{data}{content}           = 'shared/admin/exchange_rates.tt';
    $handler->{data}{section}           = 'Admin';
    $handler->{data}{subsection}        = 'Exchange Rates';
    $handler->{data}{selected_country}  = $country_id;

    $handler->{data}{countries}         = $country_rs->get_exchange_countries();
    $handler->{data}{country_rates}     = $exchange_rate_rs->get_rates();

    $handler->process_template( undef );
    return OK;
}

1;

__END__

