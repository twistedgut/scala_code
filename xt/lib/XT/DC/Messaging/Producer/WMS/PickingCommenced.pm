package XT::DC::Messaging::Producer::WMS::PickingCommenced;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';

use Carp;

with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

has '+type' => ( default => 'picking_commenced' );
has '+destination' => ( default => config_var('WMS_Queues','xt_wms_fulfilment') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::picking_commenced();
}

sub transform {
    my ($self, $header, $shipment) = @_;

    croak "WMS::PickingCommenced needs a Public::Shipment object"
        unless defined $shipment && $shipment->isa('XTracker::Schema::Result::Public::Shipment');

    my $payload = {
        shipment_id     => 's-' . $shipment->id,
    };

    $payload->{version} = '1.0';

    return ($header, $payload);
}

1;
