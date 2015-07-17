package XTracker::Stock::Location::SearchForm;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Navigation                        qw( get_navtype build_sidenav );
use XTracker::Database::Location;
use XTracker::Database::Channel         qw( get_channels );
use XTracker::Constants                         qw( $PER_PAGE );
use XTracker::Stock::Location::Common qw/ :selectable /;

use Data::Dumper;
use Data::Page;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $auth_level      = $handler->auth_level;
    my $session         = $handler->session;

    if ($handler->{param_of}{'clear_search'}) {
                delete($session->{location_search_results});
                delete($session->{start_location});
                delete($session->{end_location});
                delete($session->{qty});
                delete($session->{frm_sales_channel});
    }

    my $search_results  = $session->{location_search_results}   || 0;
        my $message                     = delete($session->{message})                   || 0;
    my $results_page    = $handler->{param_of}{'results_page'}  || 1;
    my $view            = $handler->{param_of}{'view'}                  || 0;

    my ($results_per_page, $start_floor, $start_zone, $start_location, $start_level, $end_floor, $end_zone, $end_location, $end_level, $qty, $sales_channel, $page_results);

    if ($search_results) {
                $results_per_page = $PER_PAGE;

                eval {
                        ($start_floor, $start_zone, $start_location, $start_level)
                = NAP::DC::Location::Format::parse_location($session->{start_location});
                        ($end_floor, $end_zone, $end_location, $end_level)
                = NAP::DC::Location::Format::parse_location($session->{end_location});
                };

                # use Page module to make page jumping easier
                my $pager       = Data::Page->new();
                $pager->current_page($results_page);
                $pager->entries_per_page($results_per_page);
                $pager->total_entries( scalar(keys(%{$search_results})) );
                $handler->{data}{pager} = $pager;

                $qty                    = $session->{qty};
                $sales_channel  = $session->{frm_sales_channel};

                # get the locations needed for the current page out of the search results
                my @locs_forpage= $pager->splice( [ map { $_ } sort keys %$search_results ] );
                $page_results   = { map { $_ => $search_results->{$_} } @locs_forpage };
    }

    # TT data structure
        $handler->{data}{content}                       = 'stocktracker/location/search.tt';
        $handler->{data}{view}              = $view;
        $handler->{data}{search_results}    = $page_results;
        $handler->{data}{message}                       = $message;
        $handler->{data}{results_page}      = $results_page;
        $handler->{data}{results_per_page}  = $results_per_page;

    $handler->{data}{floors}            = selectable_floors();
    $handler->{data}{zones}             = selectable_zones();
    $handler->{data}{locations}         = selectable_locations();
    $handler->{data}{levels}            = selectable_levels();

        $handler->{data}{start_floor}       = $start_floor;
        $handler->{data}{start_zone}        = $start_zone;
        $handler->{data}{start_location}    = $start_location;
        $handler->{data}{start_level}       = $start_level;
        $handler->{data}{end_floor}         = $end_floor;
        $handler->{data}{end_zone}          = $end_zone;
        $handler->{data}{end_location}      = $end_location;
        $handler->{data}{end_level}         = $end_level;
        $handler->{data}{qty}               = $qty;
        $handler->{data}{frm_sales_channel}     = $sales_channel;
        $handler->{data}{sales_channels}        = get_channels($handler->{dbh});
        $handler->{data}{section}           = 'Stock Control';
        $handler->{data}{subsection}        = 'Location';
        $handler->{data}{subsubsection}     = 'Search';
        $handler->{data}{sidenav}           = build_sidenav({navtype => get_navtype({
            type            => 'location',
            auth_level      => $auth_level
        })});


        $handler->process_template( undef );

    return OK;
}

1;

__END__
