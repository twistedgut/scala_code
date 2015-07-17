package Test::XT::Data::Shipment;

use NAP::policy "tt",     qw( test role );

use Test::XTracker::Data;

has shipment => (
    is          => 'rw',
    isa         => 'XTracker::Schema::Result::Public::Shipment',
    lazy        => 1,
    builder     => '_set_shipment',
    );

############################
# Attribute default builders
############################

# Return the shipment
#
sub _set_shipment {
    my ($self) = @_;

    my $shipment = Test::XTracker::Data->create_shipment_for_delivery($self->delivery);

    # Link the order to the shipment



    return $shipment;
}

1;
