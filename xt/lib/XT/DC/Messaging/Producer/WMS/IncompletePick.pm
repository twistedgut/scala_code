package XT::DC::Messaging::Producer::WMS::IncompletePick;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;
use XTracker::Database::Shipment;
use XTracker::Config::Local qw( config_var );
use Carp;
with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

has '+type' => ( default => 'incomplete_pick' );
has '+destination' => ( default => config_var('WMS_Queues','xt_wms_fulfilment') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::incomplete_pick();
}

sub transform {
    my ($self, $header, $data) = @_;

    my $shipment_id    = $data->{shipment_id};
    croak 'WMS::IncompletePick needs a shipment_id'
        unless defined $shipment_id;

    my $payload = {
        shipment_id => "s-$shipment_id",
        items => $data->{'items'} || [{ # XT does not currently need this info, so we fake it
            sku     => '0-000',
            quantity=> 0,
            #client  => 'Some Client',
        }],
    };

    if (exists $data->{operator_id}){
        my $operator = $self->schema->resultset('Public::Operator')->find($data->{operator_id});
        croak "WMS::IncompletePick cannot find operator id $data->{operator_id}"
            unless $operator;
        $payload->{operator} = $operator->username;
    }


    $payload->{version} = '1.0';

    return ($header, $payload);
}

1;
