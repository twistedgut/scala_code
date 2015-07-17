package Test::XTracker::Role::SOS::Shippable::TestShippable;
use NAP::policy "tt", 'class';

for (qw/
    get_shippable_requested_datetime
    get_shippable_carrier
    get_shippable_country_code
    get_shippable_region_code
    get_shippable_channel
    get_shippable_channel_code
    shippable_is_transfer
    shippable_is_rtv
    shippable_is_staff
    shippable_is_exchange
    shippable_is_premier_daytime
    shippable_is_premier_evening
    shippable_is_premier_hamptons
    shippable_is_premier_all_day
    shippable_is_express
    shippable_is_eip
    shippable_is_slow
    shippable_is_virtual_only
    shippable_is_nominated_day
    shippable_is_full_sale
    shippable_is_mixed_sale
    overrided_shippable_class_code
    overrided_carrier_code
    overrided_channel_code
/) {
    has $_ => ( is => 'rw' );
}

with 'XTracker::Role::AccessConfig';
with 'XTracker::Role::SOS::Shippable';

around '_get_shippable_shipment_class_code' => sub {
    my ($orig, $self) = @_;
    return $self->overrided_shippable_class_code()
        if defined($self->overrided_shippable_class_code());
    return $self->$orig();
};

around '_get_shippable_carrier_code' => sub {
    my ($orig, $self) = @_;
    return $self->overrided_carrier_code()
        if defined($self->overrided_carrier_code());
    return $self->$orig();
};

around '_get_shippable_channel_code' => sub {
    my ($orig, $self) = @_;
    return $self->overrided_channel_code()
        if defined($self->overrided_channel_code());
    return $self->$orig();
};
