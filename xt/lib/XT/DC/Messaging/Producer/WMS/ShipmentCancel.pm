package XT::DC::Messaging::Producer::WMS::ShipmentCancel;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';

use Carp;

with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'shipment_cancel' );
has '+destination' => ( default => config_var('WMS_Queues','wms_fulfilment') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::shipment_cancel();
}

sub transform {
    my ($self, $header, $data) = @_;

    my $shipment_id    = $data->{shipment} ? $data->{shipment}->id : $data->{shipment_id};
    croak 'WMS::ShipmentCancel needs a shipment object or a shipment_id'
        unless defined $shipment_id;

    my $payload = {
        shipment_id => "s-$shipment_id",
    };

    $payload->{version} = '1.0';

    return ($header, $payload);
}

1;
