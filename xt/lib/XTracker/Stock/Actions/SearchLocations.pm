package XTracker::Stock::Actions::SearchLocations;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Utilities;
use XTracker::Database::Attributes;
use XTracker::Database::Location qw( get_location_list generate_location_list );
use XTracker::Utilities qw( get_start_end_location url_encode );
use XTracker::Error;

use Data::Dumper;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $session     = $handler->session;

    eval {
        my $quantity_clause = '';
        my @location_list   = ();

        # If single location search
        if ($handler->{param_of}{single_location} ne "" ) {
            $location_list[0] = uc($handler->{param_of}{single_location});
        }
        # Else if range of locations search
        else {
            # Validate request parameters
            my ($min_location, $max_location) = get_start_end_location($handler->{param_of});

            $session->{start_location}  = $min_location;
            $session->{end_location}    = $max_location;

            @location_list  = generate_location_list($min_location, $max_location);
        }

        if ($handler->{param_of}{'qty'} eq 'empty') {
            $session->{qty} = 'empty';
        } elsif ($handler->{param_of}{'qty'} eq 'full') {
            $session->{qty} = 'full';
        } else {
            $session->{qty} = 'either';
        }

        $session->{frm_sales_channel}   = $handler->{param_of}{'frm_sales_channel'};

        $session->{location_search_results} = get_location_list($handler->{dbh},{
            'qty' => $session->{qty},
            'sales_channel' => $session->{frm_sales_channel},
            'location_list' => \@location_list,
        });
    };

    if ($@) {
        # error - redirect back
        xt_warn($@);
    }

    return $handler->redirect_to("/StockControl/Location/SearchLocationsForm");
}

1;

__END__
