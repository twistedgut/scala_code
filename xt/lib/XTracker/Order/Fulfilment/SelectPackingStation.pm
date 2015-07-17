package XTracker::Order::Fulfilment::SelectPackingStation;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Config::Local         qw( :carrier_automation config_var);

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing';
    $handler->{data}{subsubsection} = 'Set Packing Station';
    $handler->{data}{content}       = 'ordertracker/fulfilment/selectpackingstation.tt';

    $handler->{data}{sidenav}       = [ { 'None' => [
                                            {
                                                title   => 'Back to Packing',
                                                url     => '/Fulfilment/Packing',
                                            }
                                        ] } ];

    $handler->{data}{requires_packing_station} = config_var('Fulfilment', 'requires_packing_station');

    my $channels    = $handler->{schema}->resultset('Public::Channel')->get_channels;

    # go through each channel and get it's list of packing stations
    foreach ( sort { $a <=> $b } keys %{ $channels } ) {
        my $ps  = get_packing_stations( $handler->{schema}, $_ );
        next unless ($ps);

        # go through each packing station and store it in the general list
        # and the channel's list
        foreach my $ps_name ( sort { ($a=~/(\d+)/)[0] <=> ($b=~/(\d+)/)[0] } @{ $ps } ) {
            unless ($handler->{data}{ps_list}{$ps_name}) {
                $handler->{data}{ps_list}{$ps_name} = $ps_name;
                $handler->{data}{ps_list}{$ps_name} =~ s/_/ /g;
                push @{ $handler->{data}->{sorted_ps_list} }, $ps_name;
            }
            push @{ $handler->{data}{ps_channels}{ $channels->{$_}{name} } }, $handler->{data}{ps_list}{$ps_name};
        }
    }

    $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    return $handler->process_template( undef );
}

1;
