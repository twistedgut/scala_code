package XTracker::Email::LateShipment;
use NAP::policy 'class';

=head1 NAME

XTracker::Email::LateShipment

=head1 DESCRIPTION

An e-mail that is sent when it is identified that a shipment will be late because
 its shipping-address/shipping-charge combo means it cannot be delivered on time

=cut

with 'XTracker::Role::AccessConfig';

=head1 REQUIRED ATTRIBUTES

=head2 shipment

The XTracker::Schema::Result::Public::Shipment object representing the shipment that
 will be late

=cut
has 'shipment' => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Shipment',
    required    => 1,
);

# The following methods/attributes fulfil the requirements for the XTracker::Email role

sub path_to_template { return 'email/internal/late_postcodes.tt'; }

sub is_internal { return 1; }

sub subject {
    my ($self) = @_;
    return sprintf('Order %s will be late due to remote shipping-address',
        $self->shipment->get_order_number()
    );
}

sub template_parameters {
    my ($self) = @_;
    return {
        shipment        => $self->shipment(),
        currency_code   => $self->get_config_var('Currency', 'local_currency_code'),
    };
}

with 'XTracker::Role::Email';

has '+send_to_address' => (
    default => sub {
        my ($self) = @_;
        return $self->get_config_var('Email', 'late_postcodes');
    }
);
