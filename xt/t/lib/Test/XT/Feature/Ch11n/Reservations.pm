package Test::XT::Feature::Ch11n::Reservations;

use Moose::Role;

#
# Channelisation support tests
#
use XTracker::Config::Local;



sub test_mech__reservation__summary_ch11n {
    my($self, $channel) = @_;


    $self->mech_tab_ch11n( $channel )
        ->mech_title_ch11n([
            'Top 10 Sold Out Products',
            'Top 20 Waiting List Products'
        ], $channel);
#    $self->mech_select_box_ch11n;

}



1;
