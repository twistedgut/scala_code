package XT::DC::Messaging::Producer::WMS::StockChange;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';

use Carp;

with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

has '+type' => ( default => 'stock_change' );
has '+destination' => ( default => config_var('WMS_Queues','wms_inventory') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::stock_change();
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

    my ($from_channel, $to_channel);
    my $transfer = $self->schema->resultset('Public::ChannelTransfer')
        ->find({id => $args->{transfer_id}});

    croak sprintf 'Invalid transfer id %d',$args->{transfer_id}
        unless defined $transfer;

    if($args->{rev_flag})
    {
        $from_channel = $transfer->to_channel->name;
        $to_channel = $transfer->from_channel->name;
    }
    else
    {
        $from_channel = $transfer->from_channel->name;
        $to_channel = $transfer->to_channel->name;
    }


    my $payload = {
        version => '1.0',
        what => {
            pid => $transfer->product_id,
        },
        from => {
            stock_status => 'main',
            channel => $from_channel,
        },
        to => {
            stock_status => 'main',
            channel => $to_channel,
        },
    };

    return $payload;
}

1;
