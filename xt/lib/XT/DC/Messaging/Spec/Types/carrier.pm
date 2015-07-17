package XT::DC::Messaging::Spec::Types::carrier;
use NAP::policy;
use parent 'Data::Rx::CommonType::EasyNew';

use XTracker::Constants qw/
    :sos_carrier
/;

sub subname { 'sos/carrier' };
sub type_uri { sprintf 'http://net-a-porter.com/%s', $_[0]->subname }

my @carriers = ($SOS_CARRIER__DHL, $SOS_CARRIER__UPS, $SOS_CARRIER__NAP);

sub assert_valid {
    my ( $self, $carrier_code ) = @_;
    return 1 if grep { $_ eq $carrier_code } @carriers;
    return 0;
}
