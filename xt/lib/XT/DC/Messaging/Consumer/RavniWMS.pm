package XT::DC::Messaging::Consumer::RavniWMS;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
with 'XT::DC::Messaging::ConsumerBase::LogReceipt';

use XTracker::Config::Local qw/config_var/;
use XTracker::Constants::FromDB qw(
  :shipment_class
  :shipment_type
);

use XTracker::Order::Printing::PickingList;

sub routes {
    return {
        destination => {
            pre_advice => {
                spec => XT::DC::Messaging::Spec::WMS->pre_advice(),
                code => \&pre_advice,
            },
            shipment_request => {
                spec => XT::DC::Messaging::Spec::WMS->shipment_request(),
                code => \&shipment_request,
            },
            shipment_received => {
                spec => XT::DC::Messaging::Spec::WMS->shipment_received(),
                code => \&shipment_received,
            },
            shipment_reject => {
                spec => XT::DC::Messaging::Spec::WMS->shipment_reject(),
                code => \&shipment_reject,
            },
            shipment_packed => {
                spec => XT::DC::Messaging::Spec::WMS->shipment_packed(),
                code => \&shipment_packed,
            },
            shipment_cancel => {
                spec => XT::DC::Messaging::Spec::WMS->shipment_cancel(),
                code => \&shipment_cancel,
            },
            pid_update => {
                spec => XT::DC::Messaging::Spec::WMS->pid_update(),
                code => \&pid_update,
            },
            shipment_wms_pause => {
                spec => XT::DC::Messaging::Spec::WMS->shipment_wms_pause(),
                code => \&shipment_wms_pause,
            },
            item_moved => {
                spec => XT::DC::Messaging::Spec::WMS->item_moved(),
                code => \&item_moved,
            },
            route_tote => {
                spec => XT::DC::Messaging::Spec::WMS->route_tote(),
                code => \&route_tote,
            },
            inventory_adjusted => {
                spec => XT::DC::Messaging::Spec::WMS->inventory_adjusted(),
                code => \&inventory_adjusted,
            },
            printing_done => {
                spec => XT::DC::Messaging::Spec::WMS->printing_done(),
                code => \&printing_done,
            },
        },
    };
}

sub pre_advice {
    my ($self, $message, $headers) = @_;
    $self->log->debug("Consuming 'Pre advice' message for PGID: ". $message->{pgid});
}

sub shipment_request {
    my ($self, $message, $headers) = @_;
    $self->log->debug("Consuming 'shipment request' message for shipment id : ". $message->{shipment_id});

    my $schema = $self->model('Schema');

    my $shipment_id = $message->{shipment_id};
    $shipment_id =~ s/^s(hipment)?-//i;
    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id)
        or die "Shipment with id $shipment_id not found";

    $self->log->debug("found shipment");

    # print out picking list
    die "Print error on shipment: $shipment_id"
        unless generate_picking_list( $schema, $shipment_id ) == 1;

    $self->log->debug("picking sheet printed for shipment $shipment_id");
}

sub shipment_received {
    my ($self, $message, $headers) = @_;
    $self->log->debug("Consuming 'shipment received' message for shipment id: ". $message->{shipment_id});
}

sub shipment_reject {
    my ($self, $message, $headers) = @_;
    $self->log->debug("Consuming 'shipment reject' message for shipment id: ". $message->{shipment_id});
}

sub shipment_packed {
    my ($self, $message, $headers) = @_;
    $self->log->debug("Consuming 'shipment packed' message for shipment id: ". $message->{shipment_id});
}

sub shipment_cancel {
    my ($self, $message, $headers) = @_;

    $self->log->debug("Consuming 'shipment cancel' message for shipment id: ". $message->{shipment_id});
}

sub pid_update {
    my ($self, $message, $headers) = @_;

    $self->log->debug("Consuming 'PID update' message for product: ". $message->{pid});
}

sub shipment_wms_pause {
    my ($self, $message, $headers) = @_;

    die "Shipment ID missing" unless exists $message->{shipment_id};

    $self->log->debug("Consuming 'shipment_wms_pause' message for shipment id: ". $message->{shipment_id});

    my $shipment_id = $message->{shipment_id};
    $shipment_id =~ s/^s(shipment)?-//i;

    my $shipment = $self->model('Schema')
                        ->resultset('Public::Shipment')
                        ->find($shipment_id);

    die "Shipment with id $shipment_id not found" unless $shipment;

    die "Shipment pause value missing" unless exists $message->{pause};

    $self->log->debug("Shipment is now ".($message->{pause} ? 'paused' : 'un-paused'));
}

sub item_moved {
    my ($self, $message, $headers) = @_;
    $self->log->debug("Consuming 'item moved' message with id: ". $message->{moved_id});

    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::WMS::MovedCompleted',
        $message->{moved_id},
    );
}

sub route_tote {
    my ($self, $message, $headers) = @_;
    $self->log->debug("Consuming 'route_tote' message for container_id: ". $message->{container_id});
}

sub inventory_adjusted {
    my ($self, $message, $headers) = @_;
    $self->log->debug("Consuming 'inventory_adjusted' message for sku: ". $message->{sku});
}

sub printing_done {
    my ($self, $message, $headers) = @_;
    $self->log->debug("Consuming 'printing_done' message with shipment id: ". $message->{shipment_id});
}
