package Test::XTracker::Schema::ResultSet::Public::ShipmentItem;
use NAP::policy "tt", qw/test class/;

=head1 NAME

Test::XTracker::Schema::ResultSet::Public::ShipmentItem

=cut

BEGIN {
    extends 'NAP::Test::Class';
    with $_ for qw{Test::Role::WithSchema Test::Role::DBSamples};
};

use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw<
    :container_status
>;
use Test::XT::Data;
use Test::XT::Data::Container;
use Test::XT::Fixture::Fulfilment::Shipment;

sub startup : Test(startup => 2) {
    my ( $self ) = @_;

    isa_ok($self->{schema} = Test::XTracker::Data->get_schema, 'XTracker::Schema');

    isa_ok($self->{rs} = $self->{schema}->resultset('Public::ShipmentItem'),
        'XTracker::Schema::ResultSet::Public::ShipmentItem' );
}

=head2 update_shipment_item_container_log

=cut

sub update_shipment_item_container_log : Tests {
    my ($self) = @_;

    # create some containers
    my @container_ids = Test::XT::Data::Container->get_unique_ids( { how_many => 3 });
    # I thought get_unique_ids creates the containers automatically, but apparently it doesn't
    $self->{schema}->resultset('Public::Container')->create({
        id => $_,
        status_id => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
    }) foreach @container_ids;

    # create a shipment with items in it
    my $fixture = Test::XT::Fixture::Fulfilment::Shipment
        ->new({ pid_count => 3 })
        ->with_picked_shipment;
    my $old_container_id = $fixture->picked_container_id;
    my $shipment_items_rs = $fixture->shipment_row->shipment_items;
    my @shipment_items = $shipment_items_rs->all;
    my @shipment_item_ids = map { $_->id } @shipment_items;

    my $logs = $self->{schema}->resultset('Public::ShipmentItemContainerLog');

    # check log
    note("Before the update...");
    is(
        $logs->search({
            shipment_item_id => $_->id,
            old_container_id => undef,
            new_container_id => $old_container_id,
        }),
        1,
        '"Setting the initial container" was logged for shipment item '.$_->id
    ) foreach @shipment_items;
    is(
        $logs->search({ old_container_id => $old_container_id })->count,
        0,
        "No container changes were logged for container $old_container_id yet"
    );

    # Check we haven't broken regular updates
    note("Update an unrelated column");
    $shipment_items_rs->update({ unit_price => 42 });
    is(
        $logs->search({
            shipment_item_id => { -in => \@shipment_item_ids },
        })->count,
        3, # Expect only the three "Setting the initial container" entries already logged above
        "No further changes logged for any Shipment Item yet"
    );

    # Check we haven't broken inflation, as we mess with set_inflated_columns()
    note("Update an inflated column");
    # This gets overwritten with NOW() by a trigger though :/
    $shipment_items_rs->update({ last_updated => '2001-01-01 00:00:00' });
    is(
        $logs->search({
            shipment_item_id => { -in => \@shipment_item_ids },
        })->count,
        3, # Expect only the three "Setting the initial container" entries already logged above
        "Still no further changes logged for any Shipment Item yet"
    );

    # update the container
    $shipment_items_rs->update({ container_id => $container_ids[0] });
    # check log again
    note("After the update...");
    my $logged = $logs->search({
        shipment_item_id => { -in => \@shipment_item_ids },
        old_container_id => $old_container_id,
        new_container_id => $container_ids[0],
    });
    is($logged->count, 3, "Container changes were logged");
    is($logged->first->operator_id, $APPLICATION_OPERATOR_ID, "Operator column was filled in with default");

    # Check a different operator can be passed
    my $operator = $self->{schema}->resultset('Public::Operator')->search({},{
        order_by => { -desc => 'last_login' },
    })->first;
    $shipment_items_rs->update({
        container_id => $container_ids[1],
        operator_id => $operator->id,
    });
    note("After another update...");
    is(
        $logs->search({
            shipment_item_id => { -in => \@shipment_item_ids },
            old_container_id => $container_ids[0],
            new_container_id => $container_ids[1],
            operator_id => $operator->id,
        })->count,
        3,
        "Container change was logged with correct operator"
    );

    # Remove the container
    $shipment_items_rs->update({
        container_id => undef,
    });
    note("After removing...");
    is(
        $logs->search({
            shipment_item_id => { -in => \@shipment_item_ids },
            old_container_id => $container_ids[1],
            new_container_id => undef,
        })->count,
        3,
        "Removing container was logged"
    );
}
