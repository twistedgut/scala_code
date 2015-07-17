package Test::XTracker::Data::Carrier::UPS;
use NAP::policy "tt", 'class';
with 'XTracker::Role::WithSchema';

use XTracker::Constants::FromDB qw(
    :shipping_charge_class
    :shipping_class
    :shipping_direction
);

sub create_ups_services {
    my ($self, $service_defs) = @_;
    $service_defs //= [];

    my @services;

    my $schema = $self->schema();
    $schema->txn_do(sub {
        # Real codes do not contain letters, so remove any (test) ones already in the db that
        # are prefixed 'T'
        $schema->resultset('Public::UpsService')->search({
            code => \q/like 'T%'/
        })->search_related('ups_service_availabilities')->delete();
        $schema->resultset('Public::UpsService')->search({
            code => \q/like 'T%'/
        })->delete();

        @services = map { $self->_create_ups_service($_) } @$service_defs;
    });

    return @services;
}

sub _create_ups_service {
    my ($self, $args) = @_;
    $args //= {};

    return $self->schema->resultset('Public::UpsService')->create({
        code                        => 'T' . $args->{code},
        description                 => $args->{description},
        shipping_charge_class_id    => $args->{shipping_charge_class_id} // $SHIPPING_CHARGE_CLASS__GROUND,
    });
}

sub create_ups_service_availabilities {
    my ($self, $availability_defs) = @_;
    $availability_defs //= [];

    my @availabilities;

    my $schema = $self->schema();
    $schema->txn_do(sub {
        @availabilities = map { $self->_create_ups_service_availability($_) } @$availability_defs;
    });
    return @availabilities;
}

sub _create_ups_service_availability {
    my ($self, $args) = @_;
    $args //= {};

    return $self->schema->resultset('Public::UpsServiceAvailability')->create({
        ups_service_id      => $args->{ups_service_id},
        shipping_class_id   => $args->{shipping_class_id} // $SHIPPING_CLASS__DOMESTIC,
        shipping_direction_id    => $args->{shipping_direction_id} // $SHIPPING_DIRECTION__OUTGOING,
        shipping_charge_id  => $args->{shipping_charge_id},
        rank                => $args->{rank} // 1,
    });
}
