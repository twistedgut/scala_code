package Test::XT::Data::ReservationSimple;

use NAP::policy "tt", qw( test role );

requires 'schema';

#
# Create a Reservation Simply by just finding products and creating a new customer for a Sales channel
#

use XTracker::Constants::FromDB     qw( :reservation_status );
use Test::XTracker::Data;

use DateTime;

use Log::Log4perl ':easy';
Log::Log4perl->easy_init({ level => $INFO });


has reservation => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_reservation',
);

has product => (
    is      => 'ro',
    lazy    => 1,
    builder => '_set_product',
);

has customer => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_customer',
);

has channel => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_channel',
);

has operator => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_operator',
);

has variant => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_variant',
);

has reservation_source => (
    is      => 'rw',
    lazy    => 1,
    builder => '_set_reservation_source',
);

has always_create_new_products => (
    is      => 'rw',
    lazy    => 1,
    default => 0,
);

# Create a Pending Reservation
sub _set_reservation {
    my $self    = shift;

    my $now         = DateTime->now;
    my $channel_id  = $self->channel->id;
    my $variant_id  = $self->variant->id;

    my $reservation = $self->schema->resultset('Public::Reservation')->create({
        ordering_id             => 1,
        variant_id              => $variant_id,
        customer_id             => $self->customer->id,
        operator_id             => $self->operator->id,
        date_created            => $now,
        status_id               => $RESERVATION_STATUS__PENDING,
        notified                => 0,
        date_advance_contact    => $now,
        customer_note           => 'Customer Note',
        note                    => 'Note',
        channel_id              => $channel_id,
        reservation_source_id   => $self->reservation_source->id,
    });

    note "Reservation created, ID: ".$reservation->id;
    note "Variant,             ID: $variant_id";

    return $reservation;
}

# retrieve the product from the variant for the Reservation
sub _set_product {
    my $self    = shift;

    return $self->variant->product;
}

# gets the Sales Channel from $self->mech->channel if available
sub _set_channel {
    my $self    = shift;

    return $self->can('mech')
        ? $self->mech->channel
        : Test::XTracker::Data->get_local_channel;

}

# gets the Customer used for the Reservation
sub _set_customer {
    my $self    = shift;

    return Test::XTracker::Data->create_dbic_customer( { channel_id => $self->channel->id } );
}

# gets the operator for the Reservation
sub _set_operator {
    my $self    = shift;

    return $self->schema->resultset('Public::Operator')
                    ->search( { username => 'it.god' } )
                        ->first;
}

sub _set_variant {
    my $self    = shift;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
                                                            how_many => 1,
                                                            channel => $self->channel,
                                                            force_create => $self->always_create_new_products,
                                                        } );
    return $pids->[0]{variant};
}

sub _set_reservation_source {
    my $self    = shift;

    return $self->schema->resultset('Public::ReservationSource')
                    ->search()->first;
}

1;
