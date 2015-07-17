package XTracker::Stock::Actions::Reservation::UploadApplyFilter;

use strict;
use warnings;

use Try::Tiny;
use DateTime::Format::Natural;

use XTracker::Handler;

use XTracker::Database::Reservation         qw( queue_upload_pdf_generation );

use XTracker::Utilities                     qw( extract_pids_skus_from_text );
use XTracker::Error;

use Data::Dump  qw( pp );

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;

    my $redirect    = "/StockControl/Reservation/Overview?view_type=Upload";

    my $channel;
    my $upload_date;
    my $err;
    try {
        $channel    = $schema->resultset('Public::Channel')->find( $handler->{param_of}{channel_id} );
        die "Couldn't find a Sales Channel for Id: " . ( $handler->{param_of}{channel_id} // 'undef' )
                            if ( !$channel );

        my $date_parser = DateTime::Format::Natural->new( format => 'dd/mm/yyyy' );
        $upload_date    = $date_parser->parse_datetime( $handler->{param_of}{upload_date} );
        die "Couldn't get a Date for: " . ( $handler->{param_of}{upload_date} // 'undef' )
                            if ( !$date_parser->success );
        $err=0;
    }
    catch {
        $err=1;
        xt_warn( "Problem Applying Filter to PDF:<br>" . $_ );
    };
    return $handler->redirect_to( $redirect ) if $err;

    try {
        my $include_designer_ids= $handler->{param_of}{include_designers} || 0;     # have 0 as an Id if none so that later query works
        $include_designer_ids   = ( ref( $include_designer_ids ) ? $include_designer_ids : [ $include_designer_ids ] );

        my $pid_list            = extract_pids_skus_from_text( $handler->{param_of}{exclude_pids} );
        my @pids_to_exclude     = map { $_->{pid} } @{ $pid_list->{clean_pids} };

        # work out which designers to Exclude by
        # getting all those that haven't been Included
        my @excluded_designers  = $schema->resultset('Public::Designer')
                                            ->list_for_upload_date( $channel, $upload_date )
                                                ->search( { 'me.id' => { 'NOT IN' => $include_designer_ids } } )
                                                    ->all;
        $handler->{data}{excluded_designers}    = \@excluded_designers;
        if ( @excluded_designers ) {
            $handler->{data}{pdf_filter}{exclude_designer_ids}  = [ map { $_->id } @excluded_designers ];
        }

        if ( @pids_to_exclude ) {
            # check the Excluded PIDs for those that are
            # not in the Upload so as to inform the User
            my @excluded_pids   = $schema->resultset('Public::ProductChannel')
                                    ->list_on_channel_for_upload_date( $channel, $upload_date )
                                        ->search(
                                                { 'product_id' => { 'IN' => \@pids_to_exclude } },
                                                { 'order_by'  => 'product_id' },
                                            )->all;
            _show_warnings_for_incorrect_pids( \@excluded_pids, \@pids_to_exclude );

            $handler->{data}{pdf_filter}{exclude_pids}  = [ map { $_->product_id } @excluded_pids ]     if ( @excluded_pids );
            $handler->{data}{excluded_products}         = \@excluded_pids;
        }

        # setup the Data for the Job
        $handler->{data}{channels}{ $channel->id }{name}    = $channel->name;
        $handler->{data}{upload_date}{ $channel->name }     = $upload_date->dmy('-');

        # now queue a Job
        my $message = queue_upload_pdf_generation( $handler, $channel->id, $channel->name );
        xt_info( $message );
        xt_success("Upload PDF has been Filtered");
        $err=0;
    }
    catch {
        $err=1;
        xt_warn( "An Error Occured: " . $_ );
    };
    return $handler->redirect_to( $redirect . '&show_channel=' . $channel->id ) if $err;

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Overview';
    $handler->{data}{subsubsection} = 'Upload Filter - Applied';
    $handler->{data}{content}       = 'stocktracker/reservation/overview/upload_filter.tt';
    $handler->{data}{css}           = '/css/reservation_upload_filter.css';
    $handler->{data}{show_filter_for_pdf}   = 0;

    $handler->{data}{sidenav}[0]{'Overview'}[0] = {
                                        title   => "Upload",
                                        url     => $redirect . '&show_channel=' . $channel->id,
                                    };

    $handler->{data}{sales_channel} = $channel->name;
    $handler->{data}{channel_obj}   = $channel;
    $handler->{data}{upload_date}   = $upload_date;

    return $handler->process_template;
}

# show warnings for those Excluded PIDs
# that weren't in the Upload anyway
sub _show_warnings_for_incorrect_pids {
    my ( $pids_in_upload, $excluded_pids )  = @_;

    # now compare the PIDs for the Upload with
    # those that are Excluded to find the differences
    my %got = map { $_->product_id => 1 } @{ $pids_in_upload };
    foreach my $pid ( sort { $a <=> $b } @{ $excluded_pids } ) {
        if ( !exists( $got{ $pid } ) ) {
            xt_warn( "Excluded Product Id: '${pid}' was NOT for the Upload anyway" );
        }
    }

    return;
}

1;
