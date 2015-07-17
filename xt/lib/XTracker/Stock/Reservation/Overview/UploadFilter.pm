package XTracker::Stock::Reservation::Overview::UploadFilter;

use strict;
use warnings;

use DateTime::Format::Natural;

use XTracker::Handler;

use XTracker::Constants::FromDB         qw( );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $schema      = $handler->schema;

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Overview';
    $handler->{data}{subsubsection} = 'Upload Filter';
    $handler->{data}{content}       = 'stocktracker/reservation/overview/upload_filter.tt';
    $handler->{data}{css}           = '/css/reservation_upload_filter.css';
    $handler->{data}{js}            = '/javascript/reservations_upload_filter.js';
    $handler->{data}{show_filter_for_pdf}   = 1;

    my $back_url        = "/StockControl/Reservation/Overview?view_type=Upload";

    my $channel_name    = $handler->{param_of}{channel_upload};
    my $channel         = $schema->resultset('Public::Channel')->find_by_name( $channel_name || '' );

    my $date_parser     = DateTime::Format::Natural->new( format => 'dd/mm/yyyy' );
    my $upload_date     = $date_parser->parse_datetime( $handler->{param_of}{upload_date} );

    if ( !$channel || !$date_parser->success ) {
        xt_warn("Need a Sales Channel and a Valid Upload Date");
        return $handler->redirect_to( $back_url );
    }

    # if the Filter is being Re-Applied
    if ( $handler->{param_of}{re_apply_filter} ) {
        my $filtered_pids           = $handler->{param_of}{excluded_pids};
        my $filtered_designer_ids   = $handler->{param_of}{excluded_designer_ids};

        if ( $filtered_pids ) {
            $filtered_pids  = [ $filtered_pids ]                        if ( !ref( $filtered_pids ) );
            $handler->{data}{already_excluded_pids} = join( "\n", @{ $filtered_pids } );
        }
        if ( $filtered_designer_ids ) {
            $filtered_designer_ids  = [ $filtered_designer_ids ]        if ( !ref( $filtered_designer_ids ) );
            $handler->{data}{already_excluded_designer_ids} = {
                                                map { $_ => 1 } @{ $filtered_designer_ids }
                                            };
        }
    }

    $handler->{data}{channel_obj}           = $channel;
    $handler->{data}{sales_channel}         = $channel->name;
    $handler->{data}{sidenav}[0]{'None'}[0] = {
                                            title   => "Back",
                                            url     => $back_url . '&show_channel=' . $channel->id,
                                        };

    $handler->{data}{upload_date}   = $upload_date;
    $handler->{data}{designer_list} = [
                                        $schema->resultset('Public::Designer')
                                                ->list_for_upload_date( $channel, $upload_date )
                                                    ->all
                                    ];


    return $handler->process_template;
}

1;
