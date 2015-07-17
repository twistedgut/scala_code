package NAP::Carrier::Premier;
use Moose;
extends 'NAP::Carrier';

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

use XTracker::Database::Shipment    qw<:carrier_automation>;
use XTracker::Database::Logging     qw<:carrier_automation>;
use XTracker::Config::Local         qw<config_var>;

=head2 validate_address() : Bool

Validate the shipment's address. Return true if address validated. Note that
currently premier addresses are always considered valid unless they contain
non-Latin-1 characters.

=cut

sub validate_address {
    my $self = shift;
    return !$self->shipment->hold_if_invalid_address_characters($self->operator_id);
}

# always return ZERO
sub is_autoable {
    my $self    = shift;

    $self->shipment->discard_changes;

    return 0;
}

sub deduce_autoable {
    my $self    = shift;

    # check to see if this shipment can be automated Premier Shouldn't be
    my $result  = $self->is_autoable();
    my $current = $self->shipment->is_carrier_automated;        # get the current value of the RTCB field

    if ( $result != $current ) {
        # set RTCB field to the result of is_autoable and log
        # if value changed

        set_carrier_automated(
                $self->schema->storage->dbh,
                $self->shipment_id,
                $result
            );
        log_shipment_rtcb(
                $self->schema->storage->dbh,
                $self->shipment_id,
                $result,
                $self->operator_id,
                "AUTO: Changed After 'is_autoable' TEST",
            );
    }

    return $result;
}

=head2 shipping_service descriptions

 Should return an array of carrier service descriptions for the shipment.
 This functionality currently doesn't exist for this carrier, so returns a zero-length array.

=cut

sub shipping_service_descriptions {
    my ($self ) = @_;

    return [];

}



1;
__END__
