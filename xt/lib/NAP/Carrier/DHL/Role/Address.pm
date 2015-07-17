package NAP::Carrier::DHL::Role::Address;

use Moose::Role;

use Carp    qw<cluck>;
use XTracker::DHL::RoutingRequest qw<get_dhl_destination_code>;
use XTracker::Database::Shipment qw< :carrier_automation >;
use XTracker::Database::Logging qw< :carrier_automation >;

use XTracker::Constants::FromDB qw< :shipment_hold_reason >;

=head2 role_validate_address() : Bool

Validate the address with DHL. Return true if validation succeeded.

=cut

sub role_validate_address {
    my $self = shift;

    # We do not validate the address for virtual shipments
    return 1 if $self->is_virtual_shipment;

    my $shipment = $self->shipment;
    my $dest_code;
    eval {
        # clear Automation if set
        if ( $shipment->is_carrier_automated ) {
            set_carrier_automated(
                    $self->schema->storage->dbh,
                    $self->shipment_id,
                    0,
                );
            log_shipment_rtcb(
                    $self->schema->storage->dbh,
                    $self->shipment_id,
                    0,
                    $self->operator_id,
                    "AUTO: Changed because of an Address Validation check using DHL",
                );
            # set the shipment's QRT rating
            set_shipment_qrt(
                        $self->schema->storage->dbh,
                        $self->shipment_id,
                        undef,
                    );
        }

        # try and get DHL destination code for new address
        $dest_code = get_dhl_destination_code(
            $self->schema->storage->dbh,
            $self->shipment_id,
        );

        # Store our response - destination_code is an empty string when invalid
        $shipment->update({ destination_code  => $dest_code//q{} });

        # CANDO-2192 : hold if address contains characters outside of ASCII/Latin-1
        $shipment->hold_if_invalid_address_characters($self->operator_id);
    };
    # this is a new concept ... doing something with errors!
    if(my $e=$@) {
        cluck($e);
    }

    return !!$dest_code;
}

1;
