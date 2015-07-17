package XT::DC::Messaging::Spec::Types::delivery_event_type;
use NAP::policy;
use parent 'Data::Rx::CommonType::EasyNew';

use XTracker::Constants qw/
    :sos_delivery_event_type
/;

sub subname { 'sos/delivery_event_type' };
sub type_uri { sprintf 'http://net-a-porter.com/%s', $_[0]->subname }

my @event_types = ($SOS_DELIVERY_EVENT_TYPE__ATTEMPTED, $SOS_DELIVERY_EVENT_TYPE__COMPLETED);

sub assert_valid {
    my ( $self, $delivery_event_type ) = @_;
    return 1 if grep { $_ eq $delivery_event_type } @event_types;
    return 0;
}
