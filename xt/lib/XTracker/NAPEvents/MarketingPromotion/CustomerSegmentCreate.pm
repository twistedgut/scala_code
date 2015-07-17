package XTracker::NAPEvents::MarketingPromotion::CustomerSegmentCreate;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Error;
use XTracker::Navigation            qw( build_sidenav );
use XTracker::Database::Channel     qw( get_channels );
use DateTime::Duration;


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

    $handler->{data}{content}       = 'marketing_promotion/customersegment.tt';

    my $action      = $handler->{param_of}{action} // '';

    if( $action eq 'edit') {
        $handler->{data}{action} = 'Edit';

        my $segment_rs  = $schema->resultset('Public::MarketingCustomerSegment');
        my $segment     = $segment_rs->find( $handler->{param_of}{segment_id} );
        if( $segment ) {

            my $channel_id = $segment->channel_id;
            my $channel_rs = $schema->resultset('Public::Channel')->find($channel_id);
            $handler->{data}{channel_name} = $channel_rs->name;
            $handler->{data}{show_channel} = $channel_id;
            $handler->{data}{sales_channel} = $channel_rs->name;
            $handler->{data}{auto_show_channel} = $channel_id;

            #customer segment data
            $handler->{data}{customer_segment} = $segment;
            # if job is over 1 hour in the queue
            if($segment->job_queue_flag) {
                my $now = DateTime->now();
                my $ref_date = $segment->date_of_last_jq + DateTime::Duration->new( hours => 1 );
                $handler->{data}{override_flag}  = 0;
                if($now > $ref_date) {
                    $handler->{data}{override_flag} = 1;
                }
            }

            #get log details
            $handler->{data}{segment_logs} = $segment->marketing_customer_segment_logs;
        } else {
            xt_warn('Invalid Customer Segment Id');
            return $handler->redirect_to('/NAPEvents/InTheBox/CustomerSegment');
        }

    } else {

        $handler->{data}{action} = 'Create';
    }


    return $handler->process_template();
}

1;
