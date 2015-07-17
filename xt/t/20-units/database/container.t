#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XT::Data;
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :container_status
    :physical_place
);
use XTracker::Config::Local qw( config_var );
use XTracker::Database::Container qw( :validation :naming );
use NAP::DC::Barcode::Container;
use Test::XT::Data::Container;
use Test::Differences;
use Test::Exception;
use Data::Dump 'pp';
use utf8;

=head1 NAME

t/20-units/database/container.t

=head1 DESCRIPTION

This test script has grown like Topsy, and is now long and a bit haphazard -- I
should tidy it up at some point

Basic functionality tests for Containers

Make sure we can:

=over

=item validate tote, rail and pigeonhole IDs

=item pick an item into an empty (perhaps non-existent) container

=item remove an item from a container

=item pick further items into a non-empty container that contains only picked
items

=item remove any item from a container

=item remove all items from a container

=item fail to pick any item from a shipment into a container that already
contains an item from a different shipment, where either shipment is multi-item

=item pick items into a non-empty container that contains only picked items

=item pick up to, but not beyond, the max number of (single-item) shipments per
container

=item may not pick into non-empty containers that contain other types of items

=item can skip validation on pick-type operations

=back

=cut

my $framework = Test::XT::Data->new_with_traits(
    traits => [
        'Test::XT::Data::Order',
    ],
);
my $schema = $framework->schema;

my @good_place_names=(get_commissioner_name, undef);
my @bad_place_names=('MY BASEMENT','Commisioner','Comissioner');

foreach my $good_place (@good_place_names) {
    ok(is_valid_place($good_place),"Place name '".(defined $good_place?$good_place:'undef')."' is accepted");
}

foreach my $bad_place (@bad_place_names) {
    ok(!is_valid_place($bad_place),"Place name '".(defined $bad_place?$bad_place:'undef')."' is rejected");
}


# get a few orders we can use

# first, prepare max-shipments-in-a-tote + 1 orders...
my @single_item_order=map { $framework->new_order( products => 1 ) }
                          0..config_var('PackingToTote','max_shipments_in_tote');

my @single_item_shipment=map { $_->{shipment_object}     } @single_item_order;
my @single_shipment_item=map { $_->shipment_items->first } @single_item_shipment;

my @multi_item_order=map { $framework->new_order( products => $_*3 ) } 1..2;

my @multi_item_shipment=map { $_->{shipment_object} } @multi_item_order;

my @multi_shipment_items=map { scalar( $_->shipment_items ) } @multi_item_shipment;

my @container_id=Test::XT::Data::Container->get_unique_ids( { how_many => 2 } );

isnt($container_id[0],undef,"Got an ID for container 1");
isnt($container_id[1],undef,"Got an ID for container '$container_id[1]'");
isnt($container_id[0],$container_id[1],"Got different IDs for containers 1 and 2");

my @container=();

$container[0]=$schema->resultset('Public::Container')->find_or_create(
    { id => $container_id[0] }
)->discard_changes;

isa_ok($container[0],'XTracker::Schema::Result::Public::Container');

isnt($container[0]->id,undef,"Container 1 has been allocated ID '".$container[0]->id."'");

is($container[0]->status->id,$PUBLIC_CONTAINER_STATUS__AVAILABLE,
   "Container has been marked as available");

ok($container[0]->add_picked_item( { shipment_item => $single_shipment_item[0] } ),
    "Picked item to container");

ok(!$container[0]->is_empty,"Container is no longer empty");
ok(!$container[0]->is_full,"Container is not yet full");

is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
   "Container status is now 'Picked Items'");

is($container[0]->shipment_items->count, 1, "Container now contains one item");

is($single_shipment_item[0]->container->id,$container_id[0],"Shipment item is now in container '$container_id[0]'");

is(scalar($container[0]->shipment_ids),1,"One shipment ID in the container");
is(scalar($container[0]->shipments),1,"One shipment in the container");

eval {
    $container[0]->set_status({ status_id => $PUBLIC_CONTAINER_STATUS__AVAILABLE } );
};

isnt ($@,undef,"Attempt to reset status of non-empty container to 'Available' failed");


ok($container[0]->add_picked_item( { shipment_item => $single_shipment_item[1] } ),
    "Picked second item to container");

ok(!$container[0]->is_empty,"Container is still not empty");

is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
   "Container status is still 'Picked Items'");

is($container[0]->shipment_items->count, 2, "Container now contains two items");
ok(!$container[0]->is_full,"Container is not yet full");

is($single_shipment_item[1]->container->id,$container_id[0],
   "Shipment item two is now in container '$container_id[0]'");

is($single_shipment_item[0]->container->id,$container_id[0],
   "Shipment item one is still in container '$container_id[0]'");

is(scalar($container[0]->shipment_ids),2,"Two shipment IDs in the container");
is(scalar($container[0]->shipments),2,"Two shipments in the container");

ok($container[0]->remove_item( { shipment_item => $single_shipment_item[0] } ),
   "Item one has been removed from the container");

is($container[0]->shipment_items->count, 1, "Container now contains one item");

$single_shipment_item[0]->discard_changes;
is($single_shipment_item[0]->container,undef,"Item one no longer in any container");

is(scalar($container[0]->shipment_ids),1,"One shipment ID in the container");
is(scalar($container[0]->shipments),1,"One shipments in the container");

note "Setup: set the physical place, to be cleared when the Container is empty";
$container[0]->move_to_physical_place( $PHYSICAL_PLACE__CAGE );

ok($container[0]->remove_item( { shipment_item => $single_shipment_item[1] } ),
   "Item two has been removed from the container");

is($container[0]->shipment_items->count, 0, "Container now contains zero items");
ok($container[0]->is_empty,"Container is now empty");
is($container[0]->physical_place_id, undef, "Physical place is now cleared");


$single_shipment_item[1]->discard_changes;
is($single_shipment_item[1]->container,undef,"Item two no longer in any container");

is(scalar($container[0]->shipment_ids),0,"Zero shipment IDs in the container");
is(scalar($container[0]->shipments),0,"Zero shipments in the container");

is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__AVAILABLE,
   "Container status is now 'Available'");

# we ask for a second unique ID here, because until the above
# actions, that picked stuff into the new container, subsequent
# calls to unique ID would have returned the same ID

$container[1]=$schema->resultset('Public::Container')->find_or_create( { id => $container_id[1] } )->discard_changes;

is($multi_shipment_items[0],3,"Shipment contains three items");

while (my $item = $multi_shipment_items[0]->next) {
    $item->pick_into( $container[0]->id, $APPLICATION_OPERATOR_ID );
}

$container[0]->discard_changes;
ok(!$container[0]->is_empty,"Container is no longer empty");

is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
   "Container status is now 'Picked Items'");

is($container[0]->shipment_items->count, 3, "Container now contains three items");
is(scalar($multi_item_shipment[0]->containers), 1, "Shipment now in one container");

is($multi_item_shipment[0]->containers->first->id,$container_id[0],
   "Shipment items are now in container '$container_id[0]'");

ok($multi_item_shipment[0]->shipment_items->unpick,
   "Removed all shipment items from container ");

is($container[0]->shipment_items->count, 0, "Container now contains zero items");

ok($container[0]->is_empty,"Container is now empty");
ok(!$container[1]->is_full,"Container '$container_id[1]' is not full");

$container[0]->discard_changes;
is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__AVAILABLE,
   "Container status is now 'Available'");


is(scalar($multi_shipment_items[1]),6,"Shipment contains six items");

isa_ok($container[1],'XTracker::Schema::Result::Public::Container');

isnt($container[1]->id,undef,"Container 2 has been allocated ID '".$container[1]->id."'");
isnt($container[0]->id,$container[1]->id,"Containers have been allocated different IDs");

is($container[1]->status->id,$PUBLIC_CONTAINER_STATUS__AVAILABLE,
   "Container '$container_id[1]' has been marked as available");

while (my $item = $multi_shipment_items[1]->next) {
    $item->pick_into( $container[1]->id, $APPLICATION_OPERATOR_ID );
    $item->discard_changes;
    $container[1]->discard_changes;

    is($item->container->id,$container[1]->id,"Item is in container '$container_id[1]'");
}

ok(!$container[1]->is_empty,"Container '$container_id[1]' is no longer empty");

is($container[1]->status_id,$PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
   "Container '$container_id[1]' status is now 'Picked Items'");

is($container[1]->shipment_items->count, 6, "Container now contains six items");
is($multi_item_shipment[1]->containers->count, 1, "Shipment now in one container");
ok(!$container[1]->is_full,"Container '$container_id[1]' is still not full");

is(scalar($container[1]->shipment_ids),1,"One shipment ID in the container");
is(scalar($container[1]->shipments),1,"One shipment in the container");

is($container[1]->shipments->first->id,$multi_item_shipment[1]->id,"Shipment '".$multi_item_shipment[1]->id."' now in the container");

is($multi_item_shipment[1]->containers->first->id,$container_id[1],
   "Shipment items are now in container '$container_id[1]'");

$multi_item_shipment[1]->discard_changes;

$multi_shipment_items[1]->reset;
while (my $item = $multi_shipment_items[1]->next) {
    $item->pick_into( $container[0]->id, $APPLICATION_OPERATOR_ID );
    $item->discard_changes;
    $container[0]->discard_changes;
    $container[1]->discard_changes;

    is  ($item->container->id,$container[0]->id,"Item is in container '$container_id[0]'");
    isnt($item->container->id,$container[1]->id,"Item is no longer in container '$container_id[1]'");
}

is($container[1]->shipment_items->count, 0, "Container '$container_id[1]' now contains zero items");

ok($container[1]->is_empty,"Container '$container_id[1]' is now empty");
ok(!$container[1]->is_full,"Container '$container_id[1]' is not full");

ok($multi_item_shipment[1]->shipment_items->unpick,
   "Removed all shipment 2 items from container '$container_id[0]'");

is($container[0]->shipment_items->count,0, "Container '$container_id[0]' now contains zero items");

ok($container[0]->is_empty,"Container '$container_id[0]' is now empty");

$container[1]->discard_changes;
$container[0]->discard_changes;

is($container[1]->status_id,$PUBLIC_CONTAINER_STATUS__AVAILABLE,
   "Container '$container_id[1]' status is now 'Available'");

is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__AVAILABLE,
   "Container '$container_id[0]' status is now 'Available'");

$single_item_shipment[0]->discard_changes;
$single_item_shipment[1]->discard_changes;
$multi_item_shipment[1]->discard_changes;

$container[0]->add_picked_shipment( { shipment => $single_item_shipment[0],
                                      operator_id => $APPLICATION_OPERATOR_ID });

is($container[0]->shipment_items->count, 1, "Container '$container_id[0]' now contains one item");

$container[0]->add_picked_shipment( { shipment => $single_item_shipment[1],
                                      operator_id => $APPLICATION_OPERATOR_ID });

is($container[0]->shipment_items->count, 2, "Container '$container_id[0]' now contains two items");


eval {
    $container[0]->add_picked_shipment( { shipment => $multi_item_shipment[0],
                                          operator_id => $APPLICATION_OPERATOR_ID });
};

isnt ($@,undef,"Attempt to add second shipment was successfully tossed out");

is($container[0]->shipment_items->count, 2, "Container '$container_id[0]' still contains two items");

eval {
    $container[0]->set_status({ status_id => $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS } );
};

isnt ($@,undef,"Attempt to set non-empty container to packing exception status failed");

$container[0]->shipment_items->unpick;

ok($container[0]->is_empty,"Succesfully emptied container '$container_id[0]'");

foreach my $i (1..config_var('PackingToTote','max_shipments_in_tote')) {
    ok(!$container[0]->is_full,"Container '$container_id[0]' not yet full");
    ok($container[0]->add_picked_shipment( { shipment => $single_item_shipment[$i],
                                             operator_id => $APPLICATION_OPERATOR_ID } ),
        "Added shipment $i to container '$container_id[0]'");
}

ok($container[0]->is_full,"Container '$container_id[0]' is now full");

eval {
    $container[0]->add_picked_shipment( { shipment => $single_item_shipment[0],
                                          operator_id => $APPLICATION_OPERATOR_ID } );
};

isnt($@,undef,"Attempt to overfill container '$container_id[0]' failed");

$container[0]->shipment_items->unpick;

ok($container[0]->is_empty,"Succesfully emptied container '$container_id[0]'");

$container[0]->set_status({ status_id => $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS } );

is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
   "Succesfully altered container '$container_id[0]' to 'packing exception' status");

eval {
    $single_shipment_item[0]->pick_into( $container[0]->id, $APPLICATION_OPERATOR_ID );
};

isnt ($@,undef,"Attempt to pick into 'packing exception' container failed");

$container[0]->discard_changes;

ok($container[0]->is_empty,"Container '$container_id[0]' is still empty");

is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
   "Container '$container_id[0]' still in 'packing exception' status");

$single_shipment_item[0]->packing_exception_into( $container[0]->id, $APPLICATION_OPERATOR_ID );

$container[0]->discard_changes;

ok(!$container[0]->is_empty,"Container '$container_id[0]' is no longer empty");

is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
   "Container '$container_id[0]' still in 'packing exception' status");

eval {
    $container[0]->set_status({ status_id => $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS } );
};

isnt ($@,undef,"Attempt to reset status of non-empty 'packing exception' container failed");

is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
   "Container '$container_id[0]' still in 'packing exception' status");

eval {
    $single_shipment_item[1]->packing_exception_into( $container[0]->id, $APPLICATION_OPERATOR_ID );
};

$container[0]->discard_changes;

is($container[0]->status_id,$PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
   "Container '$container_id[0]' still in 'packing exception' status");

is($container[0]->shipment_items->count, 2, "Container '$container_id[0]' now contains two items");

$multi_shipment_items[0]->reset;

while (my $item = $multi_shipment_items[0]->next) {
    $item->packing_exception_into( $container[0]->id, $APPLICATION_OPERATOR_ID );

    is($item->container->id,$container[0]->id,"Item is in container '$container_id[1]'");
}

$multi_shipment_items[1]->reset;

while (my $item = $multi_shipment_items[1]->next) {
    $item->packing_exception_into( $container[0]->id, $APPLICATION_OPERATOR_ID );

    is($item->container->id,$container[0]->id,"Item is in container '$container_id[1]'");
}

is($container[0]->shipment_items->count, 11, "Container '$container_id[0]' contains nine items");
is($container[0]->shipments->count, 4, "Container '$container_id[0]' contains four shipments");

ok(!$container[0]->is_full,"Container '$container_id[0]' is still not full");

$container[0]->shipment_items->unpick;

ok($container[0]->is_empty,"Container '$container_id[0]' is now empty");
ok(!$container[0]->is_full,"Container '$container_id[0]' is not full");

$container[0]->discard_changes;
is($container[0]->status->id, $PUBLIC_CONTAINER_STATUS__AVAILABLE,
   "Container is marked as 'Available'");

$container[0]->set_status({ status_id => $PUBLIC_CONTAINER_STATUS__AVAILABLE });

is($container[0]->status->id, $PUBLIC_CONTAINER_STATUS__AVAILABLE,
   "Container is still marked as 'Available'");

$container[0]->set_status({ status_id => $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS });

$single_shipment_item[0]->discard_changes;
$container[0]->discard_changes;

is($container[0]->status->id, $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS,
   "Container is marked as 'Superfluous items'");

$container[0]->discard_changes;

eval {
    $single_shipment_item[0]->pick_into( $container[0]->id, $APPLICATION_OPERATOR_ID );
};

isnt ($@,undef,"Attempt to pick into container marked as 'superfluous items' failed");

eval {
    $container[0]->set_status({ status_id => $PUBLIC_CONTAINER_STATUS__AVAILABLE });
};

isnt ($@,undef,"Attempt to mark non-empty container as 'Available' failed");

$container[0]->shipment_items->unpick;

$container[0]->discard_changes;

ok($container[0]->is_empty,"Container '$container_id[0]' is empty");

$container[0]->set_status({ status_id => $PUBLIC_CONTAINER_STATUS__AVAILABLE });

is($container[0]->status->id, $PUBLIC_CONTAINER_STATUS__AVAILABLE,
   "Container is marked as 'Available'");

$single_shipment_item[0]->pick_into( $container[0]->id, $APPLICATION_OPERATOR_ID );

$container[0]->discard_changes;

ok(!$container[0]->is_empty,"Container '$container_id[0]' is no longer empty");

is($container[0]->status->id, $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
   "Container is marked as 'Picked Items'");

eval {
    $container[0]->set_status({ status_id => $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS });
};
isnt ($@,undef,"Attempt to mark non-empty container as 'Packing Exception' failed");

$container[0]->shipment_items->unpick;

$container[0]->discard_changes;

ok($container[0]->is_empty,"Container '$container_id[0]' is now empty");

$single_shipment_item[0]->discard_changes;
$single_shipment_item[0]->packing_exception_into( $container[0]->id, $APPLICATION_OPERATOR_ID );

$container[0]->discard_changes;

is($container[0]->shipment_items->count, 1, "Container '$container_id[0]' contains one item ".$single_shipment_item[0]->id);
is($container[0]->shipments->count, 1, "Container '$container_id[0]' contains one shipment");

is($container[0]->status->id, $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
   "Container '$container_id[0]' is now in 'packing exception' status");

ok(!$container[0]->is_empty,"Container '$container_id[0]' is not empty");
ok(!$container[0]->is_full, "Container '$container_id[0]' is not full");

my @new_containers=$single_item_shipment[0]->container_ids;

is($new_containers[0],$container_id[0],
   "Single item Shipment 1 is in one container, '$container_id[0]'");

eval {
    $single_shipment_item[2]->pick_into($container[0]->id, $APPLICATION_OPERATOR_ID, { dont_validate => '' } );
};

isnt($@, undef, "Attempt to pick into packing-exception tote failed");

$single_shipment_item[2]->pick_into($container[0]->id, $APPLICATION_OPERATOR_ID, { dont_validate => 1 });

is($container[0]->shipment_items->count, 2, "Unvalidated pick into container '$container_id[0]' succeeded");

ok(!$container[0]->is_in_commissioner,"Container '$container_id[0]' is not in the commissioner");

$container[0]->send_to_commissioner;

$container[0]->discard_changes;

ok($container[0]->is_in_commissioner,"Container '$container_id[0]' is in the commissioner");

is($container[0]->status->id, $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
   "Container '$container_id[0]' is now in 'picked items' status");

$container[0]->remove_from_commissioner;

ok(!$container[0]->is_in_commissioner,"Container '$container_id[0]' is no longer in the commissioner");

$container[0]->send_to_commissioner;

ok($container[0]->is_in_commissioner,"Container '$container_id[0]' is back in the commissioner");

$container[0]->shipment_items->unpick;

$container[0]->discard_changes;

ok($container[0]->is_empty,"Container '$container_id[0]' is now empty");

is($container[0]->status->id,$PUBLIC_CONTAINER_STATUS__AVAILABLE,
   "Container has been marked as available");

ok(!$container[0]->is_in_commissioner,"Container '$container_id[0]' has been removed from the commissioner");

eval {
    $container[0]->send_to_commissioner;
};

isnt($@, undef, "Attempt to put empty container into commissioner failed");

$single_shipment_item[3]->orphan_item_into($container[0]->id );

$container[0]->discard_changes;

is($container[0]->shipment_items->count, 1, "Container '$container_id[0]' now contains one orphan item ".$single_shipment_item[3]->id);

is($container[0]->status->id, $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS,
   "Container '$container_id[0]' is now in 'superfluous items' status");

$container[0]->shipment_items->unpick;

$container[0]->discard_changes;

done_testing;
