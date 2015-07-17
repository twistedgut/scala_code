use utf8;
package XTracker::Schema::Result::Operator::StickyPage::PIPE;

use Moose;

extends 'XTracker::Schema::Result::Operator::StickyPage';

__PACKAGE__->table('operator.sticky_page');

sub signature_object_class {
    my ( $self ) = @_;

    return 'Public::Shipment';
}

sub description {
    my ( $self ) = @_;
    return sprintf('Packing exception for shipment number %d', $self->sticky_id);
}

sub is_valid_exit_url {
    my ( $self, $url, $param_of ) = @_;

    my $shipment_id = $param_of->{shipment_id} // 0;

    # If the request is for /Fulfilment/Packing/PlaceInPEtote...
    if ( $url =~ m{/Fulfilment/Packing/PlaceInPEtote\b} ) {
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
