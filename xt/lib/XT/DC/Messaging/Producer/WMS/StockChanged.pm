package XT::DC::Messaging::Producer::WMS::StockChanged;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';

use Carp;

with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

has '+type' => ( default => 'stock_changed' );
has '+destination' => ( default => config_var('WMS_Queues','xt_wms_inventory') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::stock_changed();
}

sub transform {
    my ($self, $header, $args) = @_;

    my $payload;

    if (defined $args->{transfer_id}) {
        $payload = $self->_build_channel_transfer($args);
    }
    else {
        croak 'WMS::StockChange needs a transfer_id';
    }

    return ($header,$payload);
}

sub _build_channel_transfer {
    my ($self,$args) = @_;

    my $transfer = $self->schema->resultset('Public::ChannelTransfer')
        ->find({id => $args->{transfer_id}});

    croak sprintf 'Invalid transfer id %d',$args->{transfer_id}
        unless defined $transfer;

    my $payload = {
        version => '1.0',
        what => {
            pid => $transfer->product_id,
        },
        from => {
            stock_status => 'main',
            channel => $transfer->from_channel->name,
        },
        to => {
            stock_status => 'main',
            channel => $transfer->to_channel->name,
        },
    };

    return $payload;
}

1;
