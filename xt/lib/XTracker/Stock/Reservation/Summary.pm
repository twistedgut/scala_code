package XTracker::Stock::Reservation::Summary;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Image                     qw( get_images );
use XTracker::Navigation                qw( build_sidenav );
use XTracker::Database::Reservation     qw( get_reservation_overview );
use XTracker::Database::Channel         qw( get_channels );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Summary';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'stocktracker/reservation/summary.tt';
    $handler->{data}{css}           = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}            = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    # build side nav
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'reservations', res_filter => 'Personal' } );

    # get all channels and list of upload dates for each
    $handler->{data}{channels}      = get_channels( $handler->{dbh} );

    foreach my $channel_id ( keys %{$handler->{data}{channels}} ) {
        my $channel = $handler->{data}{channels}{$channel_id}{name};

        # get list of pending reservations
        $handler->{data}{pending}{$channel} = get_reservation_overview( $handler->{dbh}, {
                                                                                    channel_id  => $channel_id,
                                                                                    type        => 'Pending',
                                                                                    limit       => 'limit 10',
                                                                                } );

        # get product images
        foreach my $s ( keys %{ $handler->{data}{pending}{$channel} } ) {
            foreach my $id ( keys %{ $handler->{data}{pending}{$channel}{$s} } ) {
                $handler->{data}{pending}{$channel}{$s}{$id}{image} = get_images({
                    product_id => $handler->{data}{pending}{$channel}{$s}{$id}{id},
                    live => 1,
                    schema => $handler->schema,
                    business_id => $handler->{data}{channels}{ $channel_id }{business_id},
                });
            }
        }

        # get list of waiting reservations
        $handler->{data}{waiting}{$channel} = get_reservation_overview( $handler->{dbh}, {
                                                                                    channel_id  => $channel_id,
                                                                                    type        => 'Waiting',
                                                                                    limit       => 'limit 20',
                                                                                } );

        # get product images
        foreach my $s ( keys %{ $handler->{data}{waiting}{$channel} } ) {
            foreach my $id ( keys %{ $handler->{data}{waiting}{$channel}{$s} } ) {
                $handler->{data}{waiting}{$channel}{$s}{$id}{image} = get_images({
                    product_id => $handler->{data}{waiting}{$channel}{$s}{$id}{id},
                    schema => $handler->schema,
                    live => 0,      # the Waiting list only gets products that aren't live
                    business_id => $handler->{data}{channels}{ $channel_id }{business_id},
                });
            }
        }
    }

    return $handler->process_template;
}

1;
