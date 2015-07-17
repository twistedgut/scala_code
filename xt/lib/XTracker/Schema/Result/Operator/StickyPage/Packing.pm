use utf8;
package XTracker::Schema::Result::Operator::StickyPage::Packing;

use Moose;

extends 'XTracker::Schema::Result::Operator::StickyPage';

__PACKAGE__->table('operator.sticky_page');

sub signature_object_class {
    my ( $self ) = @_;

    return 'Public::Shipment';
}

sub description {
    my ($self) = @_;
    return sprintf("Packing shipment number %d", $self->sticky_id);
}

sub is_valid_exit_url {
    my ( $self, $url, $param_of ) = @_;

    # Once in /Fulfilment/Packing/PackShipment, we need to keep the user there
    # until they have clicked "Complete Packing". However, the StickyPage
    # object is not the same one throughout: each time they complete a step, a
    # new StickyPage object is generated, so these are in fact valid exits even
    # though the process is not finished. At the end of the request handling,
    # a handler will create the new StickyPage object and freeze the new HTML.
    my $shipment_id = $param_of->{shipment_id} // 0;

    # If the request is for /Fulfilment/Packing/PackShipment...
    if ( $url =~ m{/Fulfilment/Packing/PackShipment\b} ) {
        # ...and if the shipment_id matches the sticky page signature object...
        if ( $shipment_id == $self->sticky_id ) {
            # ...then it's a valid exit: allow this sticky page to be replaced
            return 1;
        }
    }

    # Otherwise, it's not a valid exit.
    return 0;
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
