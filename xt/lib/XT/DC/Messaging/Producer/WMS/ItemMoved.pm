package XT::DC::Messaging::Producer::WMS::ItemMoved;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';
use Scalar::Util 'refaddr';

use Carp;

with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'item_moved' );
has '+destination' => ( default => config_var('WMS_Queues','wms_fulfilment') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::item_moved();
}

sub _filter_fields {
    my ($srcref,@names) = @_;

    my @ret;

    for my $name (@names) {
        if (defined $srcref->{$name}) {
            push @ret,$name,$srcref->{$name};
        }
    }
    return @ret;
}

sub transform {
    my ($self, $header, $data) = @_;

    my $payload = {
        version => '1.0',
        _filter_fields($data,'moved_id','shipment_id'),
    };

    $payload->{moved_id} = 'm-'.refaddr($data).time(); # just a random id
    $payload->{shipment_id} = 's-'.$payload->{shipment_id}
        if exists $payload->{shipment_id} && $payload->{shipment_id} !~ m{^s-};

    if (ref $data->{from}) {
        $payload->{from} = {
            _filter_fields($data->{from},'container_id','place'),
        };
        # just in case we received a C<from => { container_id => undef }>
        if (!%{$payload->{from}}) {
            $payload->{from} = { no => 'where' };
        }
    }
    else {
        $payload->{from} = { no => 'where' };
    }

    $payload->{to} = {
        _filter_fields($data->{to},'container_id','place','stock_status'),
    };

    for my $i (@{$data->{items}}) {
        push @{$payload->{items}}, {
            _filter_fields($i,'sku','quantity','pgid','new_pgid','client'),
        }
    }

    return ($header, $payload);
}

1;
