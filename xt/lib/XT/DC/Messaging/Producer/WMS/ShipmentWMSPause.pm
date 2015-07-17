package XT::DC::Messaging::Producer::WMS::ShipmentWMSPause;
use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;
use Carp;
use JSON::XS;
use XTracker::Config::Local qw( config_var );
use Log::Log4perl ':easy';

use XTracker::Constants::FromDB qw( :shipment_status );


with 'XT::DC::Messaging::Role::Producer',
     'XTracker::Role::WithIWSRolloutPhase',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithSchema';

has '+type' => ( default => 'shipment_wms_pause' );
has '+destination' => ( default => config_var('WMS_Queues','wms_fulfilment') );

sub message_spec {
    return XT::DC::Messaging::Spec::WMS::shipment_wms_pause();
}

sub transform {
    my ($self, $header, $shipment) = @_;

    croak "WMS::ShipmentWMSPause needs a valid shipment object"
        unless defined $shipment && $shipment->isa('XTracker::Schema::Result::Public::Shipment');

    my $hold_status = {
        $SHIPMENT_STATUS__FINANCE_HOLD          => 1,
        $SHIPMENT_STATUS__HOLD                  => 1,
        $SHIPMENT_STATUS__RETURN_HOLD           => 1,
        $SHIPMENT_STATUS__EXCHANGE_HOLD         => 1,
        $SHIPMENT_STATUS__DDU_HOLD              => 1,
        $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD   => 1,
    };

    my $payload = {
        shipment_id => 's-' . $shipment->id,
    };

    if ($hold_status->{$shipment->shipment_status_id}) {
        # not using the more obvious 'hold_date' column to find the latest
        # one, because I don't know if the granularity of timestamps has
        # enough precision to distinguish between two messages sent at
        # about the same time (which is unlikely, but not impossible),
        # whereas the shipment_hold_id ought to be both unique
        # and monotonically increasing, so is guaranteed to give the
        # later shipment_hold row the higher ID
        #
        # ok, there should not be more than 1 shipment_hold per
        # shipment active at any given time, but we'll get the latest
        # one anyway

        my $shipment_holds = $shipment->shipment_holds
                                      ->search( { },
                                                { order_by => { -desc => 'id' }}
                                        );

        if ($shipment_holds->count) {
            $payload->{reason} = $shipment_holds
                ->slice(0,0)->single
                    ->shipment_hold_reason->reason;
        }

        # don't whine about there being no hold reason for a shipment that is
        # actually on hold, since it's optional, and what could we do about it at this
        # stage anyway?

        $payload->{pause} = JSON::XS::true;
    }
    else {
        $payload->{pause} = JSON::XS::false;
    }

    $payload->{version} = '1.0';

    return ($header, $payload);
}

1;
