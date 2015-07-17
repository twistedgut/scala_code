package XT::DC::Messaging::Producer::WMS::RouteTote;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';
use Scalar::Util 'refaddr';

use Moose;
use Carp;

with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'route_tote' );
has '+destination' => ( default => config_var('WMS_Queues','wms_fulfilment') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::route_tote();
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
        _filter_fields($data,'container_id','destination'),
    };

    return ($header, $payload);
}

1;
