package XTracker::NAPEvents::MarketingPromotion::CustomerSegmentSearch;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Error;
use XTracker::Navigation            qw( build_sidenav );
use XTracker::Database::Channel     qw( get_channels );
use XTracker::Utilities             qw( :string );
use XTracker::Database::Utilities   qw( :DEFAULT );
use XTracker::Database::Channel     qw( get_channels );


sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;
    my $dbh    = $handler->dbh;

    $handler->{data}{yui_enabled}       = 1;

     # load css & javascript for calendar
    $handler->{data}{css}   = ['/css/nap_events_in_the_box.css'];
    $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js',
                                '/javascript/nap_events_inthebox.js',
                              ];


    $handler->{data}{channels}      = get_channels($dbh);
    $handler->{data}{section}       = 'In The Box';
    $handler->{data}{subsection}    = 'Customer Segment';
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'marketing_promotion' } );

    $handler->{data}{content}       = 'marketing_promotion/search_customer_segment.tt';

    if( $handler->{param_of}{search}) {
        my $search_customer_number = strip( $handler->{param_of}{customer_number} );
        my $search_customer_segment = $handler->{param_of}{segment_name};

        if( $search_customer_number ) {

            if( !is_valid_database_id($search_customer_number)) {
                xt_warn('Customer not found');
                return $handler->process_template;
            } else {
                $handler->{data}{customer} = $schema->resultset('Public::Customer')->search(
                                                 { is_customer_number => $search_customer_number }
                                             )->first;

                if( $handler->{data}{customer} ) {
                    $handler->{data}{sales_channel}    = $handler->{data}{customer}->channel->name;
                    $handler->{data}{customer_segment} = $handler->{data}{customer}->search_marketing_customer_segment;
                } else {
                    xt_warn('Customer not found');
                    return $handler->process_template;
                }

            }
        } elsif( $search_customer_segment ) {
            my $segment =  $schema->resultset('Public::MarketingCustomerSegment');
            $handler->{data}{customer_segment} = $segment->search_by_name($search_customer_segment);
            $handler->{data}{segment_name} = $search_customer_segment;
            $handler->{data}{channels} = get_channels( $handler->{dbh} );
            $handler->{data}{segment_flag} = 1;
            if( !$handler->{data}{customer_segment} ) {
                xt_warn('Customer Segment with this name not found');
                return $handler->process_template;
            }
        }
    }

    return $handler->process_template();
}

1;
