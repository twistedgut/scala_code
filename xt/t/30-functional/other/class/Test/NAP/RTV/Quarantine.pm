package Test::NAP::RTV::Quarantine;

=head1 NAME

Test::NAP::RTV::Quarantine - Test RTV via Quarantine

=head1 DESCRIPTION

Test RTV via Quarantine

#TAGS goodsin inventory quarantine rtv return putaway prl iws checkruncondition

=head1 METHODS

=cut

use NAP::policy "tt", qw/test class/;

use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level :flow_status  );
use XTracker::Database qw(:common);
use XTracker::Config::Local qw( config_var );

BEGIN {
    extends "NAP::Test::Class";
    with
        'XTracker::Role::WithSchema',
        'XTracker::Role::WithPRLs',
        'XTracker::Role::WithIWSRolloutPhase',
        'Test::XT::Data::Quantity';
    with 'Test::XTracker::Data::Quarantine';

    has 'framework' => (
        is => 'ro',
        default => sub {
            my $framework = Test::XT::Flow->new_with_traits( traits => [qw/
                Test::XT::Data::Location
                Test::XT::Feature::LocationMigration
                Test::XT::Flow::GoodsIn
                Test::XT::Flow::RTV
                Test::XT::Flow::PrintStation
                Test::XT::Flow::StockControl::Quarantine
            /]);
        },
    );
};

sub test__rtv_via_quarantine :Tests {
    my ($self) = @_;

    my $framework = $self->framework();

    $framework->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Goods In/Putaway',
                'Stock Control/Inventory',
                'Stock Control/Quarantine',
                'RTV/Request RMA',
                'RTV/List RMA',
                'RTV/List RTV',
                'RTV/Pick RTV',
                'RTV/Pack RTV',
                'RTV/Awaiting Dispatch',
                'RTV/Dispatched RTV'
            ]
        }
    });

    note 'Clearing all test locations';
    $framework->force_datalite(1);

    $framework->data__location__initialise_non_iws_test_locations;

    my $quantity = $self->get_pre_quarantine_quantity();

    my $product = $quantity->product();
    my $variant = $quantity->variant();
    my $location = $quantity->location;
    my $channel = $quantity->channel();
    my $stock_count = $quantity->quantity();

    $framework->task__set_printer_station(qw/StockControl Quarantine/);
    $framework
        ->test_db__location_migration__init( $variant->id )
        ->test_db__location_migration__snapshot('Before Quarantine')
        ->flow_mech__stockcontrol__inventory_stockquarantine( $product->id );

    my ($quarantine_note, $quantity_object) = $framework
        ->flow_mech__stockcontrol__inventory_stockquarantine_submit(
            variant_id => $variant->id,
            location   => $location->location(),
            type       => 'L'
        );
    my $process_group_id = $framework
        ->flow_mech__stockcontrol__quarantine_processitem(
            $quantity_object->id
        )->flow_mech__stockcontrol__quarantine_processitem_submit(
            rtv => $stock_count,
        );

    my $search_params = {};

    # In DC2 we need to avoid putting away 'RTV Non-Faulty' as a location due to us having
    # trailing code that forces us to put items away into floor 4
    # Unfortunately as production code checks the actual DC number then we have no choice
    # but to do the same here :(
    $search_params = {location => { -ilike => '0%' }}
        if config_var('DistributionCentre', 'name') eq 'DC2';
    my $putaway_location = $framework->locations_by_allowed_status(
        $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
    )->search($search_params)->slice(0,0)->single;

    # Do the putaway
    $framework
        ->flow_mech__goodsin__putaway_processgroupid( $process_group_id )
        ->flow_mech__goodsin__putaway_book_submit( $putaway_location->location, $stock_count )
        ->flow_mech__goodsin__putaway_book_complete();

    my $stock_status;
    if ($self->iws_rollout_phase) {
        $stock_status = 'In transit from IWS';
    } elsif($self->prl_rollout_phase) {
        $stock_status = 'In transit from PRL';
    } else {
        $stock_status = 'Main Stock';
    }

    $framework
        ->test_db__location_migration__snapshot('After Putaway')
        ->test_db__location_migration__test_delta(
            from => 'Before Quarantine',
            to   => 'After Putaway',
            stock_status => {
                $stock_status => 0-$stock_count,
                'RTV Process' => 0+$stock_count,
            },
        );

    # Now we need to coax the RTV Flow in to accepting this stuff. It has been
    # written to assume certain attributes tacked on to the framework model, so
    # we're going to need to set those.
    $framework->meta->add_attribute( product => { is => 'rw', isa => 'Object' } );
    $framework->product( $product );

    $framework->meta->add_attribute( channel => { is => 'rw', isa => 'Object' } );
    $framework->channel( $channel );

    # Create an RMA request for our stock sample
    my $rtv_quantity_id = $framework
        ->flow_mech__rtv__requestrma
        ->flow_mech__rtv__requestrma__submit
        ->flow_mech__rtv__requestrma__submit__find_rtv_id_via_qnote(
            $quarantine_note
        );
    my $rma_request_id = $framework
        ->flow_mech__rtv__requestrma__create_rma_request( $rtv_quantity_id );

    # Prepare to ship
    my $shipment_id = $framework
        ->flow_mech__rtv__requestrma__submit_email({
            to => 'test@example.com',
            message => 'Here is your RMA mail'
         })
        ->flow_mech__rtv__listrma
        ->flow_mech__rtv__listrma__submit( $rma_request_id )
        ->flow_mech__rtv__listrma__view_request( $rma_request_id )
        ->flow_mech__rtv__listrma__update_rma_number({
            rma_request_id => $rma_request_id,
            rma_number     => 'RMA' . $rma_request_id,
            follow_up_date => '2020-01-01',
        })->flow_mech__rtv__listrma__capture_notes( $rma_request_id )
        ->flow_mech__rtv__create_shipment( $rma_request_id );

    $framework
        ->flow_mech__rtv__listrtv( $shipment_id )
        ->flow_mech__rtv__pickrtv( $shipment_id )
        ->flow_mech__rtv__pickrtv_autopick_and_commit( $shipment_id )
        ->flow_mech__rtv__packrtv( $shipment_id )
        ->flow_mech__rtv__packrtv_autopack_and_commit( $shipment_id )
        ->flow_mech__rtv__view_awaiting_dispatch( $shipment_id )
        ->flow_mech__rtv__view_shipment_details( $shipment_id )
        ->flow_mech__rtv__update_shipment_details({
            airway_bill_id  => 'AWB' . $shipment_id,
            rtv_shipment_id => $shipment_id
        })
        ->flow_mech__rtv__view_dispatched_shipments({
            rma_number      => 'RMA' . $rma_request_id,
            airway_bill_id  => 'AWB' . $shipment_id
        })
        ->flow_mech__rtv__view_dispatched_shipment_details( $shipment_id )
        ->test_db__location_migration__snapshot('After RMA')
        ->test_db__location_migration__test_delta;
}

