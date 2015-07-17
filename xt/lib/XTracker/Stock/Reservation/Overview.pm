package XTracker::Stock::Reservation::Overview;

# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use File::Basename;

use XTracker::Handler;
use XTracker::Image                     qw( get_images );
use XTracker::Navigation                qw( build_sidenav );
use XTracker::Database                  qw( get_schema_using_dbh );
use XTracker::Database::Reservation     qw( get_reservation_overview get_upload_reservations queue_upload_pdf_generation );
use XTracker::Database::Channel         qw( get_channels );
use XTracker::Database::Product         qw( get_recent_uploads );
use XTracker::Constants::FromDB         qw( :business :branding );
use DateTime;
use LWP::Simple;
use HTML::HTMLDoc;
use XTracker::Config::Local             qw( config_var );
use XTracker::Error                     qw(xt_info);
use XT::JQ::DC;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Overview';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'stocktracker/reservation/overview.tt';
    $handler->{data}{css}           = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}            = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    # build side nav
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'reservations', res_filter => 'Personal' } );

    # get view type from url
    $handler->{data}{view_type}     = $handler->{param_of}{view_type};
    $handler->{data}{subsubsection} = $handler->{data}{view_type};

    # get all channels and list of upload dates for each
    $handler->{data}{channels}      = $handler->schema->resultset('Public::Channel')
                                                ->get_channels_for_action( 'Reservation/' . $handler->{data}{view_type} )
                                                    ->get_channels;

    # get the channel we want the upload for
    $handler->{data}{channel_upload} = $handler->{param_of}{channel_upload};

    foreach my $channel_id ( keys %{$handler->{data}{channels}} ) {
        my $channel = $handler->{data}{channels}{$channel_id}{name};
        $handler->{data}{upload_date}{$channel}  = $handler->{param_of}{upload_date};
        $handler->{data}{uploads}{$channel}      = get_recent_uploads( $handler->{dbh}, $channel_id );

        # export PDF upload list
        if ($handler->{data}{view_type} eq 'Upload' && $handler->{data}{upload_date}{$channel}) {
            if (
                    $handler->{request}->method eq 'POST'
                and $handler->{param_of}{upload_date}
                and $handler->{param_of}{channel_upload} eq $channel
            ) {
                $handler->{data}{auto_show_channel} = $handler->{data}{channels}{$channel_id};
                my $message = queue_upload_pdf_generation($handler, $channel_id, $channel );
                xt_info( $message )     if ( $message );
            }
        }

        # get list of reservations
        $handler->{data}{reservations}{$channel}    = get_reservation_overview( $handler->{dbh}, {
                        channel_id      => $channel_id,
                        type            => $handler->{data}{view_type},
                        limit           => '',
                        upload_date     => $handler->{data}{upload_date}{$channel},
                        get_so_ord_qty  => ( $handler->{data}{view_type} ne 'Pending' ? 1 : 0 ),
                } );

        # get product images
        foreach my $s ( keys %{ $handler->{data}{reservations}{$channel} } ) {
            foreach my $id ( keys %{ $handler->{data}{reservations}{$channel}{$s} } ) {
                $handler->{data}{reservations}{$channel}{$s}{$id}{image}
                    = get_images({
                        product_id => $handler->{data}{reservations}{$channel}{$s}{$id}{id},
                        schema => $handler->schema,
                        live => 1,
                        business_id => $handler->{data}{channels}{ $channel_id }{business_id},
                    });
            }
        }
    }

    return $handler->process_template;
}

# should be passed through from the JQ
sub prepare_pdf_template {
    my $jq_class    = shift;
    my $schema      = $jq_class->schema;
    my $dbh         = $schema->storage->dbh;
    my $job_payload = $jq_class->payload;

    my ($channel_name, $channel_id, $pdf_filename, $upload_date, $html, $list_filter);
    my $counter     = 1;
    my $row_counter = 1;
    $channel_name   = $job_payload->{channel_name};
    $channel_id     = $job_payload->{channel_id};
    $pdf_filename   = $job_payload->{output_filename};
    $upload_date    = $job_payload->{upload_date};
    $list_filter    = $job_payload->{filter};

    # get the Business for the Channel and then get the Branded Date for it
    my $channel = $schema->resultset('Public::Channel')->find( $channel_id );
    my $business    = $channel->business;
    my ( $day, $month, $year )  = split( /-/, $upload_date );
    my $branded_date    = $business->branded_date( DateTime->new( day => $day, month => $month, year => $year ) );

    my $list = get_upload_reservations($dbh, $channel_id, $upload_date, { ( $list_filter ? ( filter => $list_filter ) : () ) } );
    return if not defined $list;

    # we're so sorry! we just wanted to start by moving the existing
    # horror into the JQ - LG/CCW
    my $title = $branded_date;
    my $header_txt = $channel->branding->{$BRANDING__PLAIN_NAME};

    # start building html
    $html  = "<html>";
    $html .= '<body>';
    #$html .= "<p align=\"center\"> $title</p>";

    if (my @keys = keys %{$list}) {
        my $images_included = 0;
        $html .= '<table>';
        foreach my $key ( sort {$a <=> $b} @keys ) {
            my $image_url = XTracker::Image::get_images({
                product_id => $list->{$key}{id},
                live => 1,
                schema => $schema,
            })->[0];

            # only include if we can get live image for product
            if ( head($image_url) ) {
                $images_included++;

                if ($counter == 1){
                    $html .= '<tr>';
                }

                my $designer = uc($list->{$key}{designer});

                if ($designer =~ m/^CHLO/){
                    $designer = 'CHLO&Eacute;';
                }

                $html .= '<td width="200" valign="top">';
                $html .= '<span style="font: normal 11px Arial">';
                $html .= '<div><img src="'.$image_url.'"/></div>';
                $html .= '<br /><b>'.$designer.'</b><br />';
                $html .= $list->{$key}{name};
                $html .= ' (<small>PID</small>&nbsp;'.$list->{$key}{id}.')' . '<br/>';
                $html .= $list->{$key}{price}.'<br /><br />';
                $html .= '</span></td>';

                if (++$counter == 4){
                    $html .= '</tr>';
                    $counter = 1;
                    $row_counter++;
                }

                if ($row_counter == 4){
                    $row_counter = 1;
                    $html .= "<!-- PAGE BREAK -->";
                }
            }
        }
        if (not $images_included) {
            $html .= q{<tr><td>ERROR: No images available from website</td></tr>};
        }
        $html .= '</tr>'        if ( $html !~ m{</tr>$} && $html !~ m{<!-- PAGE BREAK -->$} );
        $html .= '</table>';
    }
    else {
        $html .= "<p><b>No upload reservations for $upload_date</b></p>";
    }

    $html .= '</body></html>';

    my $subject_line =
          'XT-'
        . config_var('DistributionCentre','name')
        . ' ('
        . $channel_name
        . '): '
        . basename($job_payload->{output_filename})
    ;

    my $footer_txt = $channel->get_reservation_upload_pdf_footer;

    # now we can queue the task for our PDF to be generated
    # CANDO - 1262
    # Changing the payload to be generic, as we have two
    # options to choose from to generate PDF :  HTMLDoc or webkit.
    my $new_payload     = {
        output_filename => $job_payload->{output_filename},
        current_user    => $job_payload->{current_user},
        html_content    => $html,
        pdf_options => {
            page => {
                size => 'A4',
            },
            body_font => {
                face => 'Arial',
            },
            header => {
                left   => $header_txt,
                centre => $title,
                right  => { symbol => 'PAGE_NUMBER'},
            },
            footer =>{
                centre => $footer_txt,
            },
        },
        email_options => {
            subject         => $subject_line,
        },
    };

    # TODO - add a helper method to ::JQ to make this simpler
    my $job_rq = XT::JQ::DC->new({ funcname => 'Receive::Generate::PDF' });
    $job_rq->set_payload( $new_payload );
    my $result = $job_rq->send_job();
    $jq_class->logger->info(
          "Requesting PDF generation of $new_payload->{output_filename}; "
        . 'new job-id='
        . $result->jobid
        . "\n"
    );

    return;
}

1;
