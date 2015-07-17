package XT::DC::Messaging::Producer::WMS::InventoryAdjusted;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';

use Carp;

with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'inventory_adjusted' );
has '+destination' => ( default => config_var('WMS_Queues','wms_inventory') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::inventory_adjusted();
}

sub transform {
    my ($self, $header, $quantity) = @_;

    croak "WMS::InventoryAdjusted needs a Public::Quantity object"
        unless defined $quantity && $quantity->isa('XTracker::Schema::Result::Public::Quantity');

    my $payload = {
        version => '1.0',
        sku => $quantity->variant->sku(),
        stock_status => $quantity->status->iws_name(),
        client => $quantity->get_client()->get_client_code(),
    };

    return ($header, $payload);
}

1;
