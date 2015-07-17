package XTracker::Delivery::Event;
use NAP::policy qw/class/;

=head1 NAME

XTracker::Delivery::Event

=head1 DESCRIPTION

Module for validating and applying delivery-event updates for XTracker

=head1 SYNOPSIS

 my $event = XTracker::Delivery::Event->new({
    order_number        => '123456',
    waybill_number      => '1Z654321',
    sos_event_type      => 'ATTEMPTED',
    event_happened_at   => $timestamp_datetime_obj
 });

 $event->log_in_database({ operator_id => '42' });

=cut

use XTracker::Database qw/xtracker_schema/;
use NAP::XT::Exception::Delivery::Event::NoMatchingShipment;
use NAP::XT::Exception::MissingRequiredParameters;
use NAP::XT::Exception::Delivery::Event::UnknownEventType;

use XTracker::Constants qw/ :sos_delivery_event_type /;
use XTracker::Constants::FromDB qw/ :shipment_status /;
use XT::Data::Types qw/ShipmentStatusId/;
use XTracker::Constants '$APPLICATION_OPERATOR_ID';
use MooseX::Params::Validate;

use DateTime::Format::Pg;

=head1 PUBLIC ATTRIBUTES

=head2 shipment

XTracker::Schema::Result::Public::Shipment object representing the shipment that this
 delivery-event applies to. Typically you would not supply a shipment in the constructor,
 instead, by submitting an 'order_number' and a 'waybill_number', the correct shipment
 will be identified automatically

=cut
has shipment => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Shipment',
    required    => 1,
);


=head2 shipment_status_id

The shipment-status that will be logged against the shipment representing the event that
 occurred. Typically you would not submit a shipment_status_id to the constructor, instead
 bu submitting a 'sos_event_type', the correct shipment_status_id will be identified
 automatically

=cut
has shipment_status_id => (
    is          => 'ro',
    isa         => ShipmentStatusId,
    required    => 1,
);

=head2 event_happened_at

A DateTime object representing when the event happened

=cut
has event_happened_at => (
    is          => 'ro',
    isa         => 'DateTime',
    required    => 1,
);

around BUILDARGS => sub {
    my ($orig, $self, @args) = @_;

    my $SOS_DELIVERY_EVENT_TO_XT_SHIPMENT_STATUS_MAP = {
        $SOS_DELIVERY_EVENT_TYPE__ATTEMPTED => $SHIPMENT_STATUS__DELIVERY_ATTEMPTED,
        $SOS_DELIVERY_EVENT_TYPE__COMPLETED => $SHIPMENT_STATUS__DELIVERED,
    };

    my $args = $self->$orig(@args);

    my $order_number = delete($args->{order_number});
    my $waybill_number = delete($args->{waybill_number});

    if (!defined($args->{shipment})) {

        NAP::XT::Exception::MissingRequiredParameters->throw({
            missing_parameters => [qw/order_number waybill_number/]
        }) unless defined($order_number) && defined($waybill_number);

        # See if we can identify a shipment from the data supplied
        my $shipment = $self->_get_shipment_rs->search({
            outward_airway_bill => $waybill_number,
            order_nr            => $order_number,
        }, {
            join => { 'link_orders__shipment' => 'orders' },
            rows => 1
        })->single();

        NAP::XT::Exception::Delivery::Event::NoMatchingShipment->throw({
            order_number    => $order_number,
            waybill_number  => $waybill_number,
        }) unless $shipment;

        $args->{shipment} = $shipment;
    }

    my $sos_delivery_event_type = delete $args->{sos_event_type};

    if (!defined($args->{shipment_status_id})) {
        # Attempt to map the SOS delivery-event type to an XT shipment status

        NAP::XT::Exception::MissingRequiredParameters->throw({
            missing_parameters => [qw/sos_event_type/]
        }) unless defined($sos_delivery_event_type);

        my $shipment_status_id = $SOS_DELIVERY_EVENT_TO_XT_SHIPMENT_STATUS_MAP->{
            $sos_delivery_event_type
        };

        NAP::XT::Exception::Delivery::Event::UnknownEventType->throw({
            event_type  => $sos_delivery_event_type,
        }) unless defined($shipment_status_id);

        $args->{shipment_status_id} = $shipment_status_id;
    }


    return $args;
};

sub _get_shipment_rs {
    return xtracker_schema->resultset('Public::Shipment');
}

=head1 PUBLIC METHODS

=head2 log_in_database

If a shipment-status log does not already exist for this event, one will be created

 param - operator_id : The operator_id of the person logging this action (defaults to
  the system-user-id)

 return - $logged : True if the event is now logged

=cut
sub log_in_database {
    my ($self, $operator_id) = validated_list(\@_,
        operator_id => { isa => 'Int', default => $APPLICATION_OPERATOR_ID }
    );

    # Either find the existing log of this event, or create it
    my $pg_formatted_event_happened_at = DateTime::Format::Pg->format_timestamp_with_time_zone(
        $self->event_happened_at()
    );

    my $status_log = $self->shipment->search_related('shipment_status_logs', {
        shipment_status_id => $self->shipment_status_id(),
        operator_id        => $operator_id,
        date               => $pg_formatted_event_happened_at,
    }, {
        rows => 1
    })->first();

    $status_log //= $self->shipment->create_related('shipment_status_logs', {
        shipment_status_id => $self->shipment_status_id(),
        operator_id        => $operator_id,
        date               => $pg_formatted_event_happened_at,
    });

    return defined($status_log);
}
