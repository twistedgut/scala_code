package XT::DC::Messaging::Producer::WMS::ShipmentReady;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';
use Scalar::Util qw(blessed);

use Carp;

with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

# Produce the IWS-generated shipment_ready message, for testing.
# eg:
#     $self->wms_amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::ShipmentReady', [$args{shipment_id}, \@containers] );
# But ack t/ for WMS::ShipmentReady for more inspiration

has '+type' => ( default => 'shipment_ready' );
has '+destination' => ( default => config_var('WMS_Queues','xt_wms_fulfilment') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::shipment_ready();
}

sub transform {
    my ($self, $header, $shipment ) = @_;

    if ( $shipment && blessed($shipment) && $shipment->isa('XTracker::Schema::Result::Public::Shipment') ) {
        return $self->_transform_from_shipment_object( $header, $shipment );
    } elsif ( $shipment && ref( $shipment ) eq 'ARRAY' ) {
        return $self->_transform_from_hashref( $header, $shipment->[0], $shipment->[1] );
    } else {
        croak 'WMS::ShipmentReady requires either a shipment object or an int and an arrayref';
    }

}

sub _transform_from_hashref {
    my ($self, $header, $shipment, $containers) = @_;

      my $payload = {
        shipment_id => 's-' . $shipment,
        containers  => $containers,
    };

    $payload->{version} = '1.0';

    return ( $header, $payload );
}

sub _transform_from_shipment_object {
    my ($self, $header, $shipment) = @_;

    croak "Trying to send shipment_ready message on a shipment for which picking is not yet complete"
        unless $shipment->is_pick_complete;

    my $payload = {
        shipment_id => 's-' . $shipment->id,
        containers  => [],
    };

    $payload->{version} = '1.0';

    my $c_rs=$self->schema->resultset('Public::Container');

    my $items = $shipment->get_picked_items_by_container;
    foreach my $container_id (keys %$items){
        my $container_data = {
            container_id => $container_id,
            items => [],
        };
        my $container = $c_rs->find({id => $container_id});
        if ($container && $container->place) {
            $container_data->{place} = lc $container->place;
        }
        foreach my $item ( @{$items->{$container_id}} ){
            my $item_data = {
                sku      => $item->get_true_variant->sku,
                quantity => 1, # always one. If there's multiple units in an order they will be different shipment_items
                pgid     => 'foo-0', # IWS always knows this; we might only care for customer returns
                client   => $item->get_client()->get_client_code(),
            };
            push @{$container_data->{items}}, $item_data;
        }
        push @{$payload->{containers}}, $container_data;
    }

    return ($header, $payload);
}

1;
