package NAP::Carrier::Unknown;
use Moose;
extends 'NAP::Carrier';

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

use XTracker::Config::Local         qw<config_var>;

sub is_autoable { 0; }

sub deduce_autoable { 0; }

=head2 validate_address() : Bool

Validate the shipment's address. Return true if address validated. Note that
currently C<Unknown> addresses are always considered valid unless they have
non-Latin-1 characters.

=head3 NOTE

WTF is C<Unknown>? I'm assuming it actually means C<Premier>, but we also have
a L<NAP::Carrier::Premier>, so seriously, wtf.

=cut

sub validate_address {
    my $self = shift;
    return !$self->shipment->hold_if_invalid_address_characters($self->operator_id);
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
