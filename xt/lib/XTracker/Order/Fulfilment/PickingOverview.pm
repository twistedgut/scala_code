package XTracker::Order::Fulfilment::PickingOverview;
use strict;
use warnings;
use XTracker::Handler;
use XTracker::Config::Local 'config_var';

# Generate a page showing the status of active picks.

sub handler {
    my $r = shift;

    my $handler = XTracker::Handler->new($r);

    $handler->{data}{content}    = 'ordertracker/fulfilment/picking_overview.tt';
    $handler->{data}{section}    = 'Fulfilment';
    $handler->{data}{subsection} = 'Picking Overview';

    $handler->{data}{main_shipments} =
        $handler->{schema}->resultset('Public::Allocation')->allocations_picking_summary;

    $handler->{data}{sample_shipments} =
        $handler->{schema}->resultset('Public::Allocation')->allocations_picking_summary({ samples => 1 });

    $handler->{data}{pick_scheduler_properties} = $handler->{schema}->resultset('Public::RuntimeProperty')
        ->pick_scheduler_properties;

    my $params = $handler->{schema}->resultset('SystemConfig::ParameterGroup')
        ->get_parameter_hash;

    if (config_var('PickScheduler', 'version') == 1) {
        $handler->{data}{pick_scheduler_settings} = { prl => $params->{prl} };
    } else {
        $handler->{data}{pick_scheduler_settings} = { prl_pick_scheduler_v2 => $params->{prl_pick_scheduler_v2} };
    }

    $handler->{data}{value_to_string} = sub {
        my $value = shift;
        return '' unless $value;
        return $value->strftime('%F %R %z') if (ref($value) eq 'DateTime');
        return $value;
    };

    return $handler->process_template;
}

1;
