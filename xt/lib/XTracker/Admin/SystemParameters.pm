package XTracker::Admin::SystemParameters;

use strict;
use warnings;

use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Error;
use XTracker::Handler;
use XTracker::Config::Local 'config_var';

sub handler {
    my $handler = XTracker::Handler->new( shift );

    if ( $handler->auth_level != $AUTHORISATION_LEVEL__MANAGER ) {
        xt_warn(q{You don't have permission to access System Parameters in Admin});
        return $handler->redirect_to( '/Home' );
    }

    # if form submitted, attempt to update parameters
    if ($handler->{param_of}{submit}) {
        $handler->schema->txn_do(sub { _update_parameters($handler) });
        if ($@) {
            xt_warn($@);
        }
    }

    # read parameters from database and display them on form
    my $sys_params_rs = $handler->schema->resultset('SystemConfig::ParameterGroup');
    my $sys_params = $sys_params_rs->get_parameter_hash;
    $handler->{data}{sys_params} = $sys_params;

    # read dispatch lane config from database and display them on form
    my $shipment_type_rs = $handler->schema->resultset('Public::ShipmentType');
    my $dispatch_lanes = $shipment_type_rs->get_dispatch_lane_config;
    $handler->{data}{dispatch_lane_config} = $dispatch_lanes;

    # list all shipment types and dispatch lanes for form
    $handler->{data}{shipment_types} = {
        map { ( $_->id => { id => $_->id, type => $_->type } ) } $shipment_type_rs->all
    };
    $handler->{data}{dispatch_lanes} = [
        $handler->schema->resultset('Public::DispatchLane')->get_column('lane_nr')->all
    ];

    $handler->{data}->{pick_scheduler_version} = config_var('PickScheduler', 'version');

    $handler->{data}{content}    = 'shared/admin/system_parameters.tt';
    $handler->{data}{section}    = 'System Parameters';
    #$handler->{data}{subsection} = 'System Parameters';

    return $handler->process_template;
}

sub _update_parameters {
    my ( $handler ) = @_;

    my $post_ref = $handler->{param_of};

    # get current parameters
    my $param_rs = $handler->schema->resultset('SystemConfig::Parameter')->search(
        undef,
        {
            join => [ 'parameter_group', 'parameter_type' ],
            '+columns' => [
                'parameter_group.name',
                'parameter_group.description',
                'parameter_type.type'
            ],
        }
    );

    # loop through parameters in db, updating as necessary
    for my $param ($param_rs->all) {

        my $pick_scheduler_version = config_var('PickScheduler', 'version');
        next if ($param->parameter_group->name eq 'prl' && $pick_scheduler_version == 2);
        next if ($param->parameter_group->name eq 'prl_pick_scheduler_v2' && $pick_scheduler_version == 1);

        # unchecked booleans won't appear in the form submission, hence looping
        # through the available parameters instead
        my $input_name = join('__',
            'setting',
            $param->parameter_group->name,
            $param->name,
        );
        # the DBIC object will convert and validate the new value and only
        # issue a database update if both steps are successful
        my $new_value = $post_ref->{ $input_name };
        eval {
            $param->update_if_necessary({
                value       => $new_value,
                operator_id => $handler->operator_id,
            });
        };
        if ($@) {
            # we just display warnings for bad config values - it doesn't stop
            # other changes being written if they're valid
            xt_warn($@);
        }
    }

    # get shipment type / lane number matrix values from submitted form
    my $new_lane_numbers = {};
    for my $checkbox_name ( grep { /^dispatch_lane_\d+_\d+$/ } keys %$post_ref ) {
        if ( my ($shipment_type_id, $lane_nr) = ($checkbox_name =~ /^dispatch_lane_(\d+)_(\d+)$/) ) {
            $new_lane_numbers->{ $shipment_type_id }{ $lane_nr } = 1;
        }
    }

    # update dispatch lane config as necessary
    my $st_rs = $handler->schema->resultset('Public::ShipmentType');
    my $dl_rs = $handler->schema->resultset('Public::DispatchLane');
    for my $shipment_type ( $st_rs->all ) {
        my $st_id = $shipment_type->id;
        # check that config would not remove all lanes for a particular type
        if (!scalar(keys %{ $new_lane_numbers->{ $st_id } })) {
            my $st_type = $shipment_type->type;
            xt_warn "At least one dispatch lane must be configured for shipment type '$st_type'";
            next;
        }
        # get current dispatch lanes
        my @current_lane_numbers = $shipment_type->dispatch_lanes->get_column('lane_nr')->all;
        # remove dispatch lanes no longer wanted
        my @lanes_to_remove = $shipment_type
            ->dispatch_lanes
            ->search({ lane_nr => { '-not_in' => [ keys %{ $new_lane_numbers->{ $st_id } } ] } });
        map { $shipment_type->remove_from_dispatch_lanes( $_ ) } @lanes_to_remove;
        # add lanes which weren't already present
        map { delete $new_lane_numbers->{ $st_id }{ $_ } } @current_lane_numbers;
        for my $lane_nr ( keys %{ $new_lane_numbers->{ $st_id } } ) {
            my $lane = $dl_rs->search({ lane_nr => $lane_nr }, { rows => 1 })->slice(0,0)->single;
            $shipment_type->add_to_dispatch_lanes( $lane );
        }
    }
}

1;
