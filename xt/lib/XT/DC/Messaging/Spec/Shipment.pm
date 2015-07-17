package XT::DC::Messaging::Spec::Shipment;
use NAP::policy;

NAP::Messaging::Validator->add_type_plugins(
    'XT::DC::Messaging::Spec::Types::delivery_event_type',
    'XT::DC::Messaging::Spec::Types::carrier',
);

sub delivery_event {
    return {
        type     => '//rec',
        required => {
            carrier_code        => '/nap/sos/carrier',
            order_number        => '//str',
            waybill_number      => '//str',
            event_type          => '/nap/sos/delivery_event_type',
            event_happened_at   => '/nap/datetime',
        },
    };
}
