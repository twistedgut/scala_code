package Test::XT::Data::Delivery;

use NAP::policy "tt",     qw( test role );

use Test::XTracker::Data;

use XTracker::Constants::FromDB qw(
    :channel
    :business
    :stock_order_status
    :authorisation_level
    :delivery_status
);

has delivery => (
    is          => 'rw',
    isa         => 'XTracker::Schema::Result::Public::Delivery',
    lazy        => 1,
    builder     => '_set_delivery',
    );

############################
# Attribute default builders
############################

# Return the delivery
#
sub _set_delivery {
    my ($self) = @_;

    my @deliveries = Test::XTracker::Data->create_delivery_for_po($self->purchase_order->id,'qc');

    return $deliveries[0];
}

1;
