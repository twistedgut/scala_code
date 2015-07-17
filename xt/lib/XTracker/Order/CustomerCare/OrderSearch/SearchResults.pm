package XTracker::Order::CustomerCare::OrderSearch::SearchResults;

use strict;
use warnings;
use DateTime;

use XTracker::Error;
use XTracker::Handler;
use XTracker::Utilities             qw( isdates_ok trim );
use XTracker::Database::Currency    qw( get_currency_glyph_map );
use XTracker::Config::Local         qw( sys_config_var );
use Try::Tiny;

use XTracker::Order::CustomerCare::OrderSearch::Search qw( :search );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $dt = DateTime->now( time_zone => "local" );
    $handler->{data}{day}   = $dt->day;
    $handler->{data}{month} = $dt->month;
    $handler->{data}{year}  = $dt->year;

    $handler->{data}{section}       = 'Customer Care';
    $handler->{data}{subsection}    = 'Order Search';
    $handler->{data}{subsubsection} = 'Search Results';
    $handler->{data}{content}       = 'ordertracker/customercare/ordersearch/searchresults.tt';
    $handler->{data}{currency_glyph} = get_currency_glyph_map( $handler->{dbh} );

    $handler->{data}{channels}      = $handler->{schema}->resultset('Public::Channel')->search({is_enabled=>1});

    $handler->{data}{search_type}   = $handler->{param_of}{'search_type'};

    my $do_not_search;

    if ( $handler->{data}{search_type} ) {
        $handler->{data}{search_sales_channel} = $handler->{param_of}{'sales_channel'};

        my $search_params = {
            sales_channel => $handler->{data}{search_sales_channel},
            search_type => $handler->{data}{search_type}
        };

        if ($handler->{data}{search_type} eq 'by_date') {
            $handler->{data}{day}   = $handler->{param_of}{'day'};
            $handler->{data}{month} = $handler->{param_of}{'month'};
            $handler->{data}{year}  = $handler->{param_of}{'year'};

            my $ymd = join( '-', $handler->{data}{year},
                                 $handler->{data}{month},
                                 $handler->{data}{day} );

            if ( isdates_ok( $ymd ) ) {
                $search_params->{date_type}   = $handler->{param_of}{'date_type'};
                $search_params->{date}        = $ymd;
            }
            else {
                $do_not_search = 1;
                xt_warn( "Date '$ymd' not recognized" );
            }
        }
        elsif ($handler->{data}{search_type} eq 'customer_name') {
            $search_params->{search_terms} = { first_name => $handler->{param_of}{'firstname'},
                                               last_name  => $handler->{param_of}{'surname'}
                                             };
        }
        elsif ( $handler->{data}{search_type} eq 'pre_order_number' ) {
            $search_params->{search_terms} = $handler->{param_of}{'search_term'};
            $search_params->{search_terms} =~ s/\AP(\d+)/$1/i;  # remove P prefix if present
        }
        elsif ( $handler->{data}{search_type} eq 'telephone_number' ) {
            if ( $handler->{param_of}{'search_term'} !~ m/\d{3,}/ ) {
                $do_not_search = 1;
                xt_warn( "Telephone number searches require a telephone number - not searching" );
            }
            else {
                $search_params->{search_terms} = $handler->{param_of}{'search_term'};
            }
        }
        # free text search
        else {
            $search_params->{search_terms} = $handler->{param_of}{'search_term'};
        }

        my $results_limit;
        if ( $handler->{data}{search_type} ne 'by_date' ) {
            $results_limit = sys_config_var( $handler->{schema}, 'order_search', 'result_limit' );
        }

        unless ( $do_not_search ) {

            try {
                my $results     = find_orders( $handler->{dbh}, $search_params, $results_limit );
                my $result_key  = ( $handler->{data}{search_type} eq 'by_date' ? 'order_results' : 'results' );
                $handler->{data}{ $result_key } = $results;
            } catch {
                xt_warn( $_ );
            };
        }
    }

    $handler->{data}{fullwidthcontent} = 1;

    return $handler->process_template( undef );
}

1;
