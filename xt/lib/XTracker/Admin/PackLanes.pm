package XTracker::Admin::PackLanes;
use NAP::policy "tt";

=head1 NAME

XTracker::Admin::PackLanes

=head1 DESCRIPTION

Handler for displaying information and adjusting the settings of pack lanes

=cut

use XTracker::Handler;
use XTracker::Error qw( xt_warn xt_info );
use XTracker::Constants::FromDB qw( :authorisation_level );
use List::MoreUtils 'any';
use XTracker::Logfile 'xt_logger';
use Data::Dumper;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    try {
        _update_pack_lanes($handler);
    } catch {
        if ($_ ~~ match_instance_of('NAP::XT::Exception::InvalidPackLaneConfig')) {
            xt_warn('Invalid configuration');
            xt_warn('There must always be at least one active standard single-tote pack lane')
                if $_->has_no_single_tote_standard();
            xt_warn('There must always be at least one active standard multi-tote pack lane')
                if $_->has_no_multi_tote_standard();
            xt_warn('There must always be at least one active premier single-tote pack lane')
                if $_->has_no_single_tote_premier();
            xt_warn('There must always be at least one active premier multi-tote pack lane')
                if $_->has_no_multi_tote_premier();
            xt_warn('There must always be at least one active sample single-tote pack lane')
                if $_->has_no_single_tote_sample();
            xt_warn('There must always be at least one active sample multi-tote pack lane')
                if $_->has_no_multi_tote_sample();
            xt_warn('There is an active lane(s) with no attributes selected. Please ensure that each active lane has an attribute selected.')
                if $_->has_active_unassigned();
        }
        else {
            xt_warn("Unexpected error. Please report this issue to the Service Desk: $_");
        }
    };

    _show_list_of_packlanes($handler);
    return $handler->process_template();
}

sub _update_pack_lanes {
    my ($handler) = @_;

    # Only managers get to fiddle with the parameters
    if (!$handler->is_manager()) {
        xt_warn("You need to be a manager to update pack lane configuration");
        return;
    }

    my $updates = {};
    for my $param (keys %{$handler->{param_of}}) {

        # checking for the 'exists' input stops us setting a packlanes'
        # configuration to the default/off position if it was added after
        # the page was served up.

        if($param =~ /exists_(\d+)/) {
            my $pack_lane_id = $1;

            $updates->{$pack_lane_id} = {
                active      => _is_checked($pack_lane_id, 'active', $handler),
                is_sample   => _is_checked($pack_lane_id, 'is_sample', $handler),
                is_premier  => _is_checked($pack_lane_id, 'is_premier', $handler),
                is_standard => _is_checked($pack_lane_id, 'is_standard', $handler),
            };
        }
    }

    # Only bother if we found anything
    if(keys %$updates) {
        $handler->{schema}->resultset('Public::PackLane')->update_packlanes($updates);
        xt_info('Pack lane data has been updated');
        xt_logger->info(
            sprintf 'Pack lane data has been updated: %s',
            Data::Dumper->Dump([$updates])
        );
    }
}

# see if a checkbox was checked
sub _is_checked {
    my ($pack_lane_id, $field_name, $handler) = @_;
    my $result = exists($handler->{'param_of'}->{$field_name . "_" . $pack_lane_id});
    return $result ? 1 : 0;
}

sub _show_list_of_packlanes {
    my ($handler) = @_;

    $handler->{data}{content} = 'shared/admin/pack_lanes.tt';

    # Get packlanes and make them available to page.
    my @packlanes = $handler->{schema}->resultset('Public::PackLane')->search({
        is_editable => 1
    }, {
        order_by => 'human_name'
    });

    $handler->{data}->{packlanes} = \@packlanes;

    # Make a 'has_attr' function available to the page
    # So it can easily query the state of attributes
    my @packlane_attrs = $handler->{schema}->resultset('Public::PackLaneHasAttribute')->all;

    $handler->{data}->{has_attr} = sub {
        my ($pack_lane_id, $attr_id) = @_;
        return any {
               $_->pack_lane_id == $pack_lane_id
            && $_->pack_lane_attribute_id == $attr_id
        } @packlane_attrs;
    };
}

1;
