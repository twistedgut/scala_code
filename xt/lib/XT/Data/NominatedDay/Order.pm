package XT::Data::NominatedDay::Order;
use NAP::policy "tt", 'class';

use XT::Data::Types qw/ TimeStamp DateStamp /;

=head1 NAME

XT::Data::NominatedDay::Order - Calculate Nominated Day
attributes, e.g. dispatch_time for an Order

=head1 ATTRIBUTES

=head2 schema

=cut

has schema => (
    is       => 'ro',
    isa      => 'DBIx::Class::Schema|XTracker::Schema|XT::DC::Messaging::Model::Schema',
    required => 1,
);

=head2 order_number

Only used for error message output, if present.

=cut

has order_number => (is => 'rw');

=head2 timezone

The timezone of the local DC, e.g. America/New_York.

=cut

has timezone => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

=head2 shipping_charge

=cut

has shipping_charge => (
    is       => 'rw',
    isa      => 'Maybe[XTracker::Schema::Result::Public::ShippingCharge]',
);

=head2 shipping_account

=cut

has shipping_account => (
    is       => 'rw',
    isa      => 'XTracker::Schema::Result::Public::ShippingAccount',
    required => 1,
);

=head2 delivery_date : DateTime | Undef

If there is a Nominated Day (the customer has chosen a specific day to
receive the shipment), this is that Nominated Day date.

=cut

has delivery_date => (
    is          => 'rw',
    isa         => 'XT::Data::Types::DateStamp | Undef',
    coerce      => 1,
);

=head2 dispatch_date : DateTime | Undef

If there is a Nominated Day, this is the date when the goods need to
be dispatched, i.e. leave the DC.

=cut

has dispatch_date => (
    is          => 'rw',
    isa         => 'XT::Data::Types::DateStamp | Undef',
    coerce      => 1,
);

=head2 dispatch_time : DateTime | Undef

If there is a Nominated Day, this is the datetime when the goods need
to be dispatched, i.e. leave the DC. This is based on the
dispatch_date.

=cut

has dispatch_time => (
    is      => 'rw',
    isa     => 'XT::Data::Types::TimeStamp | Undef',
    coerce  => 1,
    lazy    => 1,
    default => sub { shift->_build_dispatch_time() },
);

sub _build_dispatch_time {
    my $self = shift;
    my $dispatch_date = $self->dispatch_date or return undef;
    my $shipping_charge = $self->shipping_charge or die("Invalid Order data:
Nominated Day but no Shipping Charge specified.
If in an Order Importer test: has ->digest been called?
");

    my $latest_dispatch_daytime = $shipping_charge->latest_nominated_dispatch_daytime
        or $self->_throw_bad_data_error();

    # clone + set_time_zone doesn't work, it'll shift the hms along,
    # we need it to stay at 00:00:00 before adding the daytime.
    my $dispatch_time = DateTime->new(
        time_zone => $self->timezone,
        year      => $dispatch_date->year,
        month     => $dispatch_date->month,
        day       => $dispatch_date->day,
    );
    $dispatch_time->add_duration( $latest_dispatch_daytime );

    return $dispatch_time;
}

sub _throw_bad_data_error {
    my $self = shift;

    my $order_message = "";
    if (my $order_number = $self->order_number) {
        $order_message = "Bad data for ORDER_NUMBER($order_number). ";
    }
    die(
        sprintf(
            "${order_message}A Nominated Day is specified with DELIVERY_DATE (%s), DISPATCH_DATE (%s), but the Shipping SKU (%s) isn't a Nominated Day sku)\n",
            $self->date_maybe( $self->delivery_date ),
            $self->date_maybe( $self->dispatch_date ),
            $self->shipping_charge->sku,
        ),
    );
}

sub date_maybe {
    my ($self, $datetime) = @_;
    $datetime or return "";
    return $datetime->ymd;
}

=head2 earliest_selection_time : XT::Data::Types::TimeStamp | Undef

If there is a Nominated Day, this is the datetime when the goods are
ready for Selection. If they are Selected before this time, they might
be dispatched too early by mistake and reach the Customer a day early.

This is the (all in localtime, really in the ->timezone)
carrier.last_pickup_daytime on the date before the dispatch_time.

=cut

sub earliest_selection_time {
    my $self = shift;

    $self->dispatch_time or return undef;
    my $last_pickup_daytime = $self->shipping_account->carrier->last_pickup_daytime;

    my $earliest_selection_time =
        $self->day_before_dispatch_time()->add(
            $last_pickup_daytime,
        );

    return $earliest_selection_time;
}

sub day_before_dispatch_time {
    my $self = shift;
    return $self->dispatch_time
        ->clone
        ->set_time_zone( $self->timezone )
        ->truncate(to => "day")
        ->subtract(days => 1);
}

