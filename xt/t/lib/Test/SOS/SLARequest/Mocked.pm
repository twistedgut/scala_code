package Test::SOS::SLARequest::Mocked;
use NAP::policy 'tt', 'class';
extends 'SOS::SLARequest';

use DateTime;
use Readonly;
use MooseX::Params::Validate;

Readonly my $ARBITRARY_ADDITION_TO_SELECTION_TIME_TO_CREATE_AN_SLA => 4;
Readonly my $ARBITRARY_ADDITION_TO_SELECTION_TIME_TO_CREATE_DEADLINE => 2;
Readonly my $ARBITRARY_INITIAL_PICK_PRIORITY => 20;

override 'get_sla_data' => sub {
    my ($self, %params) = validated_hash(\@_,
        shipment_class_code     => { isa => 'Str' },
        carrier_code            => { isa => 'Str' },
        country_code            => { isa => 'Str' },
        region_code             => { isa => 'Str', optional => 1 },
        channel_code            => { isa => 'Str' },
        selection_date_epoch    => { isa => 'Int' },
        is_express              => { isa => 'Bool', default => 0 },
        is_eip                  => { isa => 'Bool', default => 0 },
        is_slow                 => { isa => 'Bool', default => 0 },
        is_full_sale            => { isa => 'Bool', default => 0 },
        is_mixed_sale           => { isa => 'Bool', default => 0 },
    );
    my $params = \%params;

    my $selection_datetime = DateTime->from_epoch({
        epoch       => $params{selection_date_epoch},
    });

    my $sla_datetime = $selection_datetime->clone->add(
        hours => $ARBITRARY_ADDITION_TO_SELECTION_TIME_TO_CREATE_AN_SLA,
    );

    my $wms_deadline = $selection_datetime->clone->add(
        hours => $ARBITRARY_ADDITION_TO_SELECTION_TIME_TO_CREATE_DEADLINE,
    );

    return {
        sla_epoch                   => $sla_datetime->epoch(),
        wms_deadline_epoch          => $wms_deadline->epoch(),
        wms_initial_pick_priority   => $ARBITRARY_INITIAL_PICK_PRIORITY,
    };
};
