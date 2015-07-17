package XT::DC::Messaging::Producer::WMS::ShipmentPacked;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;
use XTracker::Constants::FromDB qw(
                                      :shipment_item_status
                                    );
use XTracker::Database::Shipment;
use XTracker::Config::Local qw( config_var );
use Carp;
with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

has '+type' => ( default => 'shipment_packed' );
has '+destination' => ( default => config_var('WMS_Queues','wms_fulfilment') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::shipment_packed();
}

sub transform {
    my ($self, $header, $data) = @_;

    my $shipment_id    = $data->{shipment_id};
    croak 'WMS::ShipmentPacked needs a shipment_id'
        unless defined $shipment_id;

    my $payload = {
        shipment_id => "s-$shipment_id",
        containers => [],
        version => '1.0',
    };

    if ($data->{fake_dispatch}) {
        $payload->{spur} = 0;
        # that's all the checking we're going to do for a fake dispatch
        return ($header, $payload);
    }


    my $shipment    = $self->schema->resultset('Public::Shipment')->find($shipment_id);
    croak "WMS::ShipmentPacked needs a valid shipment_id"
        unless defined $shipment;

    my $lane = $shipment->shipment_type->get_lane;
    $payload->{spur} = $lane || 0;

    my $boxes = $shipment->search_related('shipment_boxes',{},
                                          { prefetch => 'box' });

    while (my $box=$boxes->next) {
        next if $box->hide_from_iws;
        if ( $box->tote_id ) {
            push @{$payload->{containers}}, $box->tote_id;
        } else {
            push @{$payload->{containers}}, $box->id;
        }
    }

    return ($header, $payload);
}

1;
