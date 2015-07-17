package XTracker::Shipment::LateChecker;
use NAP::policy 'class';

=head1 NAME

XTracker::Shipment::LateChecker

=head1 DESCRIPTION

A class that provides functionality surrounding shipments that will be late due to
 remote shipping-addresses

=cut

with 'XTracker::Role::WithSchema';

use MooseX::Params::Validate;
use XTracker::Email::LateShipment;

has 'latepostcode_rs' => (
    is      => 'ro',
    isa     => 'XTracker::Schema::ResultSet::Public::ShippingChargeLatePostcode',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->schema->resultset('Public::ShippingChargeLatePostcode');
    },
);

=head1 PUBLIC METHODS

=head2 check_address

Given an address and a shipping charge, return true if shipment's with this data will not
 be able to meet the delivery promise

=cut
sub check_address {
    my ($self, $address, $shipping_charge) = validated_list(\@_,
        address         => { isa => 'XTracker::Schema::Result::Public::OrderAddress' },
        shipping_charge => { isa => 'XTracker::Schema::Result::Public::ShippingCharge' },
    );

    return ($self->latepostcode_rs->filter_by_shipping_charge({
        shipping_charge => $shipping_charge,
    })->filter_by_address({
        address => $address
    })->count() ? 1 : 0);
}

=head2 send_late_shipment_notification

Send an internal notification e-mail for a given shipment to let someone know it won't
 meet its delivery promise

=cut
sub send_late_shipment_notification {
    my ($self, $shipment) = validated_list(\@_,
        shipment => { isa => 'XTracker::Schema::Result::Public::Shipment' }
    );

    return XTracker::Email::LateShipment->new({ shipment => $shipment })->send();
}
