package XT::DC::Messaging::Producer::WMS::MovedCompleted;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;

use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';

use Carp;

with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'moved_completed' );
has '+destination' => ( default => config_var('WMS_Queues','xt_wms_fulfilment') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::moved_completed();
}

sub transform {
    my ($self, $header, $id) = @_;

    my $payload = {
        version => '1.0',
        moved_id => $id,
    };

    return ($header, $payload);
}

1;
