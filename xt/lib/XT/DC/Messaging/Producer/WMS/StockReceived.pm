package XT::DC::Messaging::Producer::WMS::StockReceived;
use NAP::policy "tt", 'class';

use XT::DC::Messaging::Spec::WMS;
use XTracker::Constants::FromDB qw(
                                      :stock_process_status
                                      :stock_process_type
                                      :flow_status
                                    );
use XTracker::Database::Delivery qw ( get_delivery_channel );
use XTracker::Image;
use XTracker::Config::Local qw( config_var );
use Carp;
with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

has '+type' => ( default => 'stock_received' );
has '+destination' => ( default => config_var('WMS_Queues','xt_wms_inventory') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::stock_received();
}

sub transform {
    my ($self, $header, $data) = @_;


    my $payload = { items => [] };
    $payload->{operator} = $data->{operator}->username
        if $data->{operator};

    if (my $sp_group_rs = $data->{sp_group_rs}) {
        $self->_transform_one( $payload, $_ ) for $sp_group_rs->all;
    }
    elsif ( my $sp = $data->{sp}) {
        $self->_transform_one( $payload, $sp );
    }
    elsif ( my $sr = $data->{sr}) {
        $self->_recode_one( $payload, $sr );
    }
    else {
        croak __PACKAGE__ . " needs a stock process group result set, or a single stock process record, or a single recode record";
    }

    $payload->{version} = '1.0';

    return ($header, $payload);
}

sub _transform_one {
    my ($self, $payload, $stock_process) = @_;

    return unless $stock_process->quantity > 0;

    if (!defined $payload->{pgid}) {
        # they will all be the same
        $payload->{pgid} = 'p-'.$stock_process->group_id;
    }

    my $variant = $stock_process->delivery_item->variant;

    my $storage_type = $variant->product->storage_type;
    my $storage_type_name = $storage_type ? lc($storage_type->iws_name) : "flat";
    push @{$payload->{items}}, {
        sku         => $variant->sku,
        quantity    => $stock_process->quantity,
        storage_type=> $storage_type_name,
        client      => $stock_process->get_client()->get_client_code(),
    };
}

sub _recode_one {
    my ($self, $payload, $stock_recode) = @_;

    $payload->{pgid} = 'r-'.$stock_recode->id;
    my $variant = $stock_recode->variant;

    my $storage_type = $variant->product->storage_type;
    my $storage_type_name = $storage_type ? lc($storage_type->iws_name) : "flat";
    push @{$payload->{items}}, {
        sku         => $variant->sku,
        quantity    => $stock_recode->quantity,
        storage_type=> $storage_type_name,
        client      => $stock_recode->get_client()->get_client_code(),
    };
}

1;
