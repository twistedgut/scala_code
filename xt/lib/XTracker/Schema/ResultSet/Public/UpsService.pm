package XTracker::Schema::ResultSet::Public::UpsService;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

use MooseX::Params::Validate;

use XTracker::Constants::FromDB qw(
    :shipping_direction
);

=head2 filter_for_shipment

Returns a list of services that can be used to try and book a delivery with UPS
for a specific shipment.

    param - shipment : A shipment row object (that we want to deliver)
    param - is_return : (Default=0) Set to 1 for return delivery services,
            0 for outgoing

    return - $available_services : An array ref of UpsService Row objects that
            can be used to try and book this shipment. They should be attempted
            in the order supplied.

=cut

sub filter_for_shipment {
    my ($self, $shipment, $is_return) = validated_list(\@_,
        shipment    => { isa => 'XTracker::Schema::Result::Public::Shipment' },
        is_return   => { isa => 'Bool', default => 0 },
    );

    my $shipping_charge = $shipment->shipping_charge_table();
    my $shipping_class = $shipment->get_shipping_class();
    my $shipping_charge_class = $shipment->get_shipping_charge_class();

    # This base filter is necesarry for both possible filters below
    my $services_rs = $self->search({
        'ups_service_availabilities.shipping_class_id'  => $shipping_class->id(),
        'ups_service_availabilities.shipping_direction_id'   => ($is_return
            ? $SHIPPING_DIRECTION__RETURN
            : $SHIPPING_DIRECTION__OUTGOING
        ),
    }, {
        join        => 'ups_service_availabilities',
        order_by    => ['ups_service_availabilities.rank', 'ups_service_availabilities.id'],
    });

    # Are there are specific services that should be used for this shipping_charge?
    my $specific_services_rs = $services_rs->search({
        'ups_service_availabilities.shipping_charge_id' => $shipping_charge->id(),
    }, {
        join => 'ups_service_availabilities',
    });

    # If not, look for services that are available by default for this charge_class
    # (Assuming the shipment has a charge-class)
    if($specific_services_rs->count() == 0 && $shipping_charge_class) {
        $services_rs = $services_rs->search({
            'ups_service_availabilities.shipping_charge_id' => undef,
            'me.shipping_charge_class_id'                   => $shipping_charge_class->id(),
        }, {
            join => 'ups_service_availabilities',
        });
    } else {
        $services_rs = $specific_services_rs;
    }

    return (wantarray ? $services_rs->all : $services_rs);
}

1;
