package XTracker::Script::Shipment::AutoSelect;

use Moose;

extends 'XTracker::Script';
with 'XTracker::Role::WithPRLs',
    map { "XTracker::Script::Feature::$_" } qw(
    SingleInstance
    Schema
    RunEvery
);
with 'XTracker::Role::WithAMQMessageFactory';

has '+interval' => (
    default => sub { sys_param('fulfilment/selection/batch_interval') || 1 },
);

use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

use XTracker::Config::Parameters 'sys_param';
use XTracker::Config::Local 'config_var';
use XTracker::PickScheduler;   # v1 - remove after v2 is solid in production
use XTracker::Pick::Scheduler; # v2

use Readonly;

Readonly my $DEFAULT_AUTO_SELECT_COUNT => 6;

sub invoke {
    my ($self, %args) = @_;

    my $verbose = !!$args{verbose};

    # check that auto-selection is enabled, exit if not
    my $auto_select_shipments = $args{auto_select_shipments} // sys_param('fulfilment/selection/enable_auto_selection') // 0;
    if (!$auto_select_shipments) {
        $verbose && print "Shipment auto-selection is disabled\n";
        return 0; # not an error
    }

    # If we're have PRLs we use the pick scheduler, otherwise we carry on as
    # usual
    if ( $self->prl_rollout_phase ) {
        if( (config_var("PickScheduler", "version") // 0) == 2 ) {
            my $ps = XTracker::Pick::Scheduler->new(
                msg_factory => $self->msg_factory,
            );
            $ps->schedule_allocations();
        }
        else {
            my $ps = XTracker::PickScheduler->new(
                msg_factory => $self->msg_factory,
            );
            $ps->pick_full_shipments;
            $ps->set_induction_capacity_and_release_dms_only;
        }
        return 0;
    }

    my $dry_run = !!$args{dryrun};
    my $operator_id = $args{operator_id} // $APPLICATION_OPERATOR_ID;

    # if shipments specified, use those, otherwise make batch from eligible
    # NOTE supplied shipment ids are not validated so this still works for
    #      sample shipments, for example, which would not ordinarily have been
    #      available for selection in XTracker. This is to continue the cheat
    #      Flow uses for testing (fake form fields!).
    my @shipment_ids_to_select = @{ $args{shipment_ids} // [] };
    @shipment_ids_to_select = $self->_get_shipment_ids(%args) unless @shipment_ids_to_select;

    $verbose && print 'Number of shipments which '.($dry_run ? 'would' : 'will').' be selected: '.scalar(@shipment_ids_to_select).' ('.join(', ', @shipment_ids_to_select).")\n";

    if (!$dry_run) {
        my $num_selected = 0;
        my $schema = $self->schema;
        for my $shipment_id (@shipment_ids_to_select) {
            eval {
                $schema->txn_do(sub{
                    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id)
                        or return;
                    my $status = $shipment->select($operator_id, $self->msg_factory) || 0;
                    $num_selected += $status;
                });
            };
            if ($@) {
                warn "An error occurred trying to select shipment $shipment_id: $@";
            }
        }
        $verbose && print "Number of shipments selected: $num_selected\n";
    }

    return 0;
}

sub _get_shipment_ids {
    my ($self, %args) = @_;

    # if not specified, get batch size from config, or default to 6
    my $num_shipments_to_select = $args{count} //
        sys_param('fulfilment/selection/batch_size');
    $num_shipments_to_select //= $DEFAULT_AUTO_SELECT_COUNT;

    my @shipments_to_select = $self->schema()->resultset('Public::Shipment')->get_selection_list({
        exclude_non_prioritised_samples         => 1,
        prioritise_samples                      => 1,
        exclude_held_for_nominated_selection    => 1,
    })->search({
        ($args{restricted_ids} ? ( id => $args{restricted_ids} ) : () ),
    }, {
        rows => $num_shipments_to_select,
    });

    my @shipment_ids_to_select = map { $_->id } @shipments_to_select;

    return @shipment_ids_to_select;
}

1;
