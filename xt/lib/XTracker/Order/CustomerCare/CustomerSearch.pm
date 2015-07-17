package XTracker::Order::CustomerCare::CustomerSearch;

use strict;
use warnings;

use XTracker::Database qw ( get_database_handle );
use XTracker::Database::Channel qw( get_channels );
use XTracker::Error;
use XTracker::Handler;

use XTracker::Order::CustomerCare::CustomerSearch::Search qw( :search );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Customer Care';
    $handler->{data}{subsection}    = 'Customer Search';
    $handler->{data}{subsubsection} = 'Website';
    $handler->{data}{content}       = 'ordertracker/customercare/customersearch.tt';

    $handler->{data}{channels}      = get_channels( $handler->{dbh}, { fulfilment_only => 0 } );

    if ( $handler->{param_of}{search} ) {
        my $search_params = {};
        foreach my $field (qw/customer_number email first_name last_name/) {
            next unless $handler->{param_of}{$field};
            push @{$search_params->{search_type}}, $field;
            push @{$search_params->{search_terms}}, $handler->{param_of}{$field};
        }
        xt_error(q{No search Type Specified}) unless $search_params->{search_type};

        $search_params->{sales_channel} = $handler->{param_of}{channel};

        # need to get the Channel Id used so as to feed into a
        # form used to create Customers which aren't in xTracker
        my ( $channel_id, $channel_config ) = split /-/, $search_params->{sales_channel};
        $handler->{data}{channel_id_for_search} = $channel_id;

        $handler->{data}{search} = 1; # hint to template that form was submitted

        local $@;

        eval {
            $handler->{data}{results}
                = find_customers( $handler->{dbh}, $search_params );
        };

        if (my $error = $@) {
            xt_error( $error );
        }
    }

    return $handler->process_template( undef );
}

1;
