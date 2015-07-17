package Test::XT::DC::Controller::Admin::PackingBoxAdmin;

=head1 NAME

Test::XT::DC::Controller::Admin::PackingBoxAdmin -
Test the creation and editing of Shipment boxes and inner boxes

=head1 DESCRIPTION

Test the PackingBoxAdmin controller to create and update outer and inner
boxes for all active channels.

A new box or inner box is created on the database for each active channel.
The presence of the new box on the db is verified.

If the box is an outer box, the weight parameter is updated.
If it is an inner box, the sort_order is updated.
The updated parameter is then verified on the db.

#TAGS fulfilment packing whm

=cut

use NAP::policy "tt",     'test';
use parent 'NAP::Test::Class';

use Test::More::Prefix 'test_prefix';
use Test::XT::Flow;
use Test::XTracker::Data;
use XTracker::Config::Local qw( config_var );

use XTracker::Constants::FromDB qw( :authorisation_level );

sub startup : Test(startup => 1) {
    my ( $self ) = @_;

    test_prefix 'Startup';

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [qw(
            Test::XT::Flow::Admin
        )],
    );

    $self->{framework}->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Admin/Packing Box Admin'
            ],
        },
        dept => 'Distribution Management',
    });

}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;
    test_prefix("");
}

=head2 test_create_and_edit_outer_shipment_boxes

Test the creation and update of outer boxes (Public::Box)

=cut

sub test_create_and_edit_outer_shipment_boxes : Tests {
    my ( $self ) = @_;

    my $framework = $self->{framework};

    # parameters used in box creation and editing
    my $new_box_name = 'Outer Test Box 999';
    my $new_box_weight = 11.99;
    my $new_box_type = 'outer';

    my @channels = Test::XTracker::Data->get_enabled_channels()->all;
    foreach my $channel ( @channels ) {

        local $Test::More::Prefix::prefix = 'Create Outer Shipment Box (' . $channel->web_name . ')';

        # open admin page with outer box type parameter
        # then create new outer box for the channel
        $framework
            ->flow_mech__admin_create_shipment_box('boxes')
              ->flow_mech__admin_create_shipment_box_submit($channel->id, $new_box_type, $new_box_name);

        my $box_obj =
            $framework->schema->resultset('Public::Box')->find(
                {channel_id => $channel->id, box => $new_box_name}
            );

        is( $box_obj->box, $new_box_name, "The new box has been successfully created on the database." );

        local $Test::More::Prefix::prefix = 'Edit Outer Shipment Box (' . $channel->web_name . ')';

        # open admin page with outer box id
        # then enter the new weight and submit
        $framework
            ->flow_mech__admin_edit_shipment_box_outer($box_obj->id)
              ->flow_mech__admin_edit_shipment_box_submit( $new_box_type, $new_box_weight );

        $box_obj->discard_changes;

        is( $box_obj->weight, $new_box_weight, "The new box weight has been successfully updated on the database." );

    }
}

=head2 test_create_and_edit_inner_shipment_boxes

Test the creation and update of inner boxes (Public::Box)

=cut

sub test_create_and_edit_inner_shipment_boxes : Tests {
    my ( $self ) = @_;

    my $framework = $self->{framework};

    # parameters used in box creation and editing
    my $new_box_name = 'Inner Test Box 999';
    my $new_grouping_id = 99;
    my $new_box_type = 'inner';

    my @channels = Test::XTracker::Data->get_enabled_channels()->all;
    foreach my $channel ( @channels ) {

        local $Test::More::Prefix::prefix = 'Create Inner Shipment Box (' . $channel->web_name . ')';

        # open admin page with inner box type parameter
        # then create new inner box for the channel
        $framework
            ->flow_mech__admin_create_shipment_box('inner_boxes')
              ->flow_mech__admin_create_shipment_box_submit($channel->id, $new_box_type, $new_box_name);

        my $inner_box_obj =
            $framework->schema->resultset('Public::InnerBox')->find(
                {channel_id => $channel->id, inner_box => $new_box_name}
            );

        is( $inner_box_obj->inner_box, $new_box_name, "The new inner box has been successfully created on the database." );

        local $Test::More::Prefix::prefix = 'Edit Inner Shipment Box (' . $channel->web_name . ')';

        # open admin page with inner box id
        # then enter the new sort order and submit
        $framework
            ->flow_mech__admin_edit_shipment_box_inner($inner_box_obj->id)
              ->flow_mech__admin_edit_shipment_box_submit( $new_box_type, $new_grouping_id );

        $inner_box_obj->discard_changes;

        is( $inner_box_obj->grouping_id, $new_grouping_id, "The new inner box grouping id has been successfully updated on the database." );

    }
}
