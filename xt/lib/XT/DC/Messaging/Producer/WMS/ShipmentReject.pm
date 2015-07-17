package XT::DC::Messaging::Producer::WMS::ShipmentReject;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;
use Carp;

use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';
use XTracker::Constants::FromDB qw(
    :shipment_class
    :shipment_item_status
    :shipment_status
    :shipment_type
);

with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

has '+type' => ( default => 'shipment_reject' );
has '+destination' => ( default => config_var('WMS_Queues','wms_fulfilment') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::shipment_reject();
}

sub transform {
    my ($self, $header, $data) = @_;

    my $shipment_id    = $data->{shipment_id};
    croak 'WMS::ShipmentReject needs a shipment_id'
        unless defined $shipment_id;

    my $shipment    = $self->schema->resultset('Public::Shipment')->find($shipment_id);
    croak "WMS::ShipmentReject needs a valid shipment_id"
        unless defined $shipment;

    my $items = $shipment->related_resultset('shipment_items',{
        shipment_item_status_id => [
            $SHIPMENT_ITEM_STATUS__PICKED,
            $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
        ],
        container_id => { '!=' => undef },
    });

    my %container_cache;
    my $payload = {
        shipment_id     => 's-' . $shipment->id,
        containers      => [
        ],
    };

    while (my $item = $items->next) {
        my $slot = $container_cache{$item->container->id};

        if (!$slot) {
            $slot = $container_cache{$item->container->id} = {
                container_id => $item->container->id,
                items => [],
            };
            push @{ $payload->{containers} }, $slot;
        }

        my $variant = $item->get_true_variant();
        push @{$slot->{items}}, {
            sku         => $variant->sku(),
            quantity    => 1, # Always 1 for now - may change in the future...
            client      => $variant->get_client()->get_client_code(),
        }
    }

    $payload->{version} = '1.0';

    return ($header, $payload);
}

1;
