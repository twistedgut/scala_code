package XTracker::Order::Fulfilment::PackLaneActivity;
use strict;
use warnings;
use XTracker::Handler;

# Generate a page showing the pack lanes and containers therein.

sub handler {
    my $r = shift;

    my $handler = XTracker::Handler->new($r);

    my $multi_tote_details = $handler->{param_of}{multi_tote_details};
    $handler->{data}{section}    = 'Fulfilment';
    $handler->{data}{css} = ['/css/pack_lane_activity.css'];

    if($multi_tote_details) {
        push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Pack Lane Activity', 'url' => '/Fulfilment/PackLaneActivity' } );
        $handler->{data}{content}    = 'ordertracker/fulfilment/pack_lane_activity_multi_tote.tt';
        $handler->{data}{subsection} = 'Pack Lane Activity - Multi-tote details';
    } else {
        $handler->{data}{content}    = 'ordertracker/fulfilment/pack_lane_activity.tt';
        $handler->{data}{subsection} = 'Pack Lane Activity - Summary';
        push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Multi-tote details', 'url' => '/Fulfilment/PackLaneActivity?multi_tote_details=true' } );
    }
    $handler->{data}{multi_tote_details} = $multi_tote_details;


    my $schema = $handler->{schema};
    $handler->{data}{packlanes} = [ $schema->resultset('Public::PackLane')->packlanes_and_containers ];

    return $handler->process_template( undef );
}

1;
