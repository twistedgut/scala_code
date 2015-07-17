package Test::XT::Data::Reservation;

use NAP::policy "tt",     qw( test role );

requires 'schema';

#
# Create a Reservation
#
use XTracker::Config::Local;
use Test::XTracker::Data;

use DateTime;

use Log::Log4perl ':easy';
Log::Log4perl->easy_init({ level => $INFO });

use XTracker::Constants::FromDB qw(
    :delivery_action
);

has reservation => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_reservation',
    );


# Create a Reservation so we can see it in the Unallocated Log
#
sub _set_reservation {
    my ($self) = @_;

    my $now         = DateTime->now;
    my $variant_id  = $self->stock_order->stock_order_items->first->variant_id;
    my $god         = $self->schema->resultset('Public::Operator')->search({username => 'it.god'})->first;

    my $reservation = $self->schema->resultset('Public::Reservation')->create({
        ordering_id             => 1,
        variant_id              => $variant_id,
        customer_id             => $self->customer->id,
        operator_id             => $god->id,
        date_created            => $now,
        date_uploaded           => $now,
        date_expired            => $now,
        status_id               => 2,
        notified                => 0,
        date_advance_contact    => $now,
        customer_note           => 'Customer Note',
        note                    => 'Note',
        channel_id              => $self->channel->id,
        reservation_source_id   => $self->schema->resultset('Public::ReservationSource')->search->first->id,
        reservation_type_id     => $self->schema->resultset('Public::ReservationType')->search->first->id,
    });

    note "Reservation created, ID: ".$reservation->id;
    note "Variant,             ID: $variant_id";
    return $reservation;
}

1;
