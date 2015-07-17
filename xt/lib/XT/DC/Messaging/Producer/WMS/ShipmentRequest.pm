package XT::DC::Messaging::Producer::WMS::ShipmentRequest;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use Log::Log4perl ':easy';
use Data::Dump qw(pp);

use Carp;
use JSON::XS;

with    'XT::DC::Messaging::Role::Producer',
        'XTracker::Role::AccessConfig',
        'XTracker::Role::WithSchema',
        'XTracker::Role::WithXTLogger';

has '+type' => ( default => 'shipment_request' );
has '+destination' => (
    default => sub {
        my ($self) = @_;
        return $self->get_config_var('WMS_Queues','wms_fulfilment');
    }
);

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::shipment_request();
}

sub transform {
    my ($self, $header, $shipment) = @_;

    croak "WMS::ShipmentRequest needs a Public::Shipment object"
        unless defined $shipment && $shipment->isa('XTracker::Schema::Result::Public::Shipment');
    my $items = $shipment->active_items;

    if (!$items || $items->count == 0) {
        carp "No shipment items found in shipment " . $shipment->id;
        return;
    }

    my $payload = {
        shipment_id     => 's-' . $shipment->id,
        shipment_type   => $shipment->get_iws_shipment_type(),
        stock_status    => $shipment->stock_status_for_iws(),
        channel         => $shipment->get_channel->name,
        premier         => ($shipment->get_iws_is_premier()
            ? JSON::XS::true
            : JSON::XS::false
        ),
        has_print_docs  => ($shipment->list_picking_print_docs()
            ? JSON::XS::true
            : JSON::XS::false
        ),
        items           => [],
    };

    my $initial_priority = $shipment->wms_initial_pick_priority();
    if (defined($initial_priority)) {
        # Assuming we have an initial priority (all future shipments should, but during
        # the migration to SOS we have to deal with shipments created before and after
        # we start using this value), send the wms_priority related fields to IWS
        $payload->{initial_priority} = $initial_priority;
        $payload->{bump_deadline} = $shipment->wms_bump_deadline() if defined($shipment->wms_bump_deadline());
        $payload->{bump_priority} = $shipment->wms_bump_pick_priority() if defined($shipment->wms_bump_pick_priority());
    }

    $payload->{deadline} = $shipment->sla_cutoff();

    if (!$payload->{deadline}) {

        # Shipments should always have an SLA if this message is being sent, so to not
        # have one is an error. But since we're paranoid about the warehouse grinding to
        # a halt, we stick a default SLA in place and log the event
        $payload->{deadline} = $self->_get_default_sla();
        $self->xtlogger->error(
            sprintf('Sending a ShipmentRequest for Shipment %s but it has no SLA (using %s)',
                $shipment->id(), $payload->{deadline}));
    }


    if (!$shipment->use_sos_for_sla_data()) {
        # Without SOS we pass a 'priority-class' to ensure Premiers get through quickly
        $payload->{priority_class} = $shipment->iws_priority_class();
    }

    my @items = $items->all();
    for my $item (@items) {
        next if $item->is_virtual_voucher;
        my $variant = $item->get_true_variant();
        push @{$payload->{items}}, {
            sku         => $variant->sku(),
            quantity    => 1, # Always 1 for now - may change in the future...
#            pgid        => , # optional field don't care for main stock orders - do we care for RTV?, definitely for customer returns
            client      => $variant->get_client()->get_client_code(),
        }
    }

    $payload->{version} = '1.0';

    return ($header, $payload);
}

sub _get_default_sla {
    my ($self) = @_;
    return $self->schema->db_now->add(
        hours => $self->get_config_var('PickingSLA', 'default_cutoff')
    );
}

1;
