use utf8;
package XTracker::Schema::Result::Public::Container;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.container");
__PACKAGE__->add_columns(
  "id",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "status_id",
  {
    data_type      => "integer",
    default_value  => 1,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "place",
  { data_type => "text", is_nullable => 1 },
  "pack_lane_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "routed_at",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "arrived_at",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "has_arrived",
  { data_type => "boolean", is_nullable => 1 },
  "physical_place_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "integration_containers",
  "XTracker::Schema::Result::Public::IntegrationContainer",
  { "foreign.container_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orphan_items",
  "XTracker::Schema::Result::Public::OrphanItem",
  { "foreign.container_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "pack_lane",
  "XTracker::Schema::Result::Public::PackLane",
  { pack_lane_id => "pack_lane_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "physical_place",
  "XTracker::Schema::Result::Public::PhysicalPlace",
  { id => "physical_place_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "putaway_prep_containers",
  "XTracker::Schema::Result::Public::PutawayPrepContainer",
  { "foreign.container_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_items",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.container_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::ContainerStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZucI4NzBIVIGwIn+CM2y+Q



use Moose;
with 'XTracker::Schema::Role::WithStateSignature',
     'XTracker::Role::WithPRLs',
     'XTracker::Role::WithAMQMessageFactory';

use List::MoreUtils qw(any);
use MooseX::Params::Validate qw/validated_list/;

use NAP::DC::Barcode::Container;
use NAP::DC::Barcode::Container::Tote;
use NAP::XT::Exception::Internal;

use XT::Domain::PRLs;
use XTracker::Database::Container qw ( :naming :validation);
use XTracker::Constants::FromDB qw(
    :allocation_status
    :container_status
    :shipment_item_status
    :shipment_status
    :pack_lane_attribute
    :storage_type
    :physical_place
);

use XTracker::Utilities qw(number_in_list);
use XTracker::Config::Local qw( config_var config_section_slurp );
use XTracker::Logfile qw( xt_logger );

use XTracker::Pick::Scheduler;

# Make sure container's "id" is transformed into instance of
# NAP::DC::Barcode::Container on the way from database
# and stringified on the way back to DB
#
__PACKAGE__->inflate_column('id', {
    inflate => sub { NAP::DC::Barcode::Container->new_from_id(shift) },
    deflate => sub { shift->as_id },
});



=head1 Error message policy

I<die> statements here that contain messages expected to be visible to end-users
as part of normal operation have had a newline appended to them, to suppress
the file/line number stuff that I<die> normally appends.

Those that are only likely to appear because of a system problem or bug in
the code have been left without a newline, so that as much context as possible
is presented in the error message, to aid trouble-shooting.

=cut


=head1 Valid container transitions

This table shows the valid item types that you may add to a container in each allowed state.


   State                   | Item types addable
 ==========================+==============================================+
   Available               | picked, packing exception, superfluous
   Picked Items            | picked
   Packing Exception Items | packing exception
   Superflous Items        | cancelled items or orphan items,

Adding an item sets the container status to that type of item iff it is currently 'available'.

Changing the status of a non-empty container isn't allowed.

=cut


=head2 _check_op_args

Helper method for validating that various add and remove operations
have been given a sensible shipment/shipment_item/orphan_item argument to work on.
Dies unless the arg passed contains exactly one of I<shipment> or I<shipment_item>
or I<orphan_item>, which must point to an object be of the corresponding type.

=cut

sub _check_op_args {
    my ($args) = @_;

    if (exists $args->{shipment}) {
        die "May only define one of 'shipment' or 'shipment_item'"
            if exists $args->{shipment_item};

        die "May only define one of 'shipment' or 'orphan_item'"
            if exists $args->{orphan_item};

        die "'shipment' element not of type 'Public::Shipment'"
            unless $args->{shipment}->isa('XTracker::Schema::Result::Public::Shipment');
    }
    elsif (exists $args->{shipment_item}) {
        die "May only define one of 'shipment_item' or 'orphan_item'"
            if exists $args->{orphan_item};

        die "'shipment_item' element not of type 'Public::ShipmentItem'"
            unless $args->{shipment_item}->isa('XTracker::Schema::Result::Public::ShipmentItem');
    }
    elsif (exists $args->{orphan_item}) {
        die "'orphan_item' element not of type 'Public::OrphanItem'"
            unless $args->{orphan_item}->isa('XTracker::Schema::Result::Public::OrphanItem');
    }
    else {
        die "Must define one of 'shipment', 'shipment_item' or 'orphan_item'";
    }

    return 1;
}

=head2 is_in_commissioner

Returns true iff the container is in the Commissioner.

=cut

sub is_in_commissioner {
    my $self = shift;

    return $self->place
        && $self->place eq get_commissioner_name;
}

=head2 is_superfluous

    returns true if tote status implies that it contains superfluous items only

=cut

sub is_superfluous {
    return shift->status_id == $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS;
}

=head2 is_packing_exception

    returns true if tote status implies that it contains packing exception items

=cut

sub is_packing_exception {
    return shift->status_id == $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS;
}

=head2 validate_pick_into

Validates whether the passed-in argument hash, defined as for C<add_picked_shipment>
or as for C<add_picked_item>, may be performed on this container.

Dies with an error message, otherwise returns true.

Only relevant for when we're picking from within XT. This means it correctly
fails if you try to pick into a pigeon hole.

=cut

sub validate_pick_into {
    my ($self,$args) = @_;

    _check_op_args($args);

    unless (number_in_list($self->status_id,
                           $PUBLIC_CONTAINER_STATUS__AVAILABLE,
                           $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS)) {
        die "This container is being used for ".$self->status->name.", you may not pick items into it\n";
    }

    # make sure current container's ID is one for some kind of Tote,
    # otherwise throw an exception
    $self->id( NAP::DC::Barcode::Container::Tote->new_from_id($self->id) );

    # okay, we're dealing with a tote

    if (exists $args->{shipment}) {
        my $shipment=$args->{shipment};

        # if the shipment is multi-item...
        if ($shipment->is_multi_item) {
            my $shipment_id=$shipment->id;

            # then we'd better not have any other shipments in our container
            # apart from the one whose item we're adding

            if (grep { $_->id != $shipment_id } $self->shipments) {
                die "This shipment contains multiple items and the tote already contains items from another shipment. Only single item shipments can be combined within the same tote\n";
            }

            if ($self->is_full) {
                unless (grep { $_->id == $shipment_id } $self->shipments) {
                    die "Cannot have more than ".$self->_available_shipment_slots." different shipments in one tote\n";
                }
            }
        }

        unless ($self->is_empty) {
            die "May not mix channels in one container\n"
                if $self->get_channel->id != $shipment->shipment_items->first->channel->id;
        }
    }
    elsif (exists $args->{shipment_item}) {
        my $shipment_item=$args->{shipment_item};

        my $item_shipment=$shipment_item->shipment;
        my $shipment_id=$item_shipment->id;

        # if the item's shipment is multi-item...
        if ($item_shipment->is_multi_item) {
            # then we'd better not have any other shipments in our container
            # apart from the one whose item we're adding

            if (grep { $_->id != $shipment_id } $self->shipments) {
                die sprintf("This is a shipment with multiple items and this tote already contains at least one other shipment (%s). Only single item shipments can be combined within the same tote\n", join(', ', map {$_->id} $self->shipments));
            }

            # we'd also better not be adding a new shipment when
            # there is already a multi-item shipment in the container

            foreach my $existing_shipment ($self->shipments) {
                if ($existing_shipment->is_multi_item && $shipment_id != $existing_shipment->id) {
                    die sprintf("This tote already contains a shipment with multiple items (%s). Only single item shipments can be combined within the same tote\n", $existing_shipment->id);
                }
            }
        }

        if ($self->is_full) {
            unless (grep { $_->id == $shipment_id } $self->shipments) {
                die "Cannot have more than ".$self->_available_shipment_slots." different shipments in one tote\n";
            }
        }

        unless ($self->is_empty) {
            die "May not mix channels in one container\n"
                if $self->get_channel->id != $item_shipment->get_channel->id;
        }
    }
    else {
        die "Must define one of 'shipment' or 'shipment_item'";
    }


    return 1;
}

=head2 validate_packing_exception_into

As I<validate_pick_into>, but for putting a packing exception item
into a container instead.  This has simpler rules at present.

=cut


sub validate_packing_exception_into {
    my ($self,$args) = @_;

    _check_op_args($args);

    unless (number_in_list($self->status_id,
                           $PUBLIC_CONTAINER_STATUS__AVAILABLE,
                           $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS)) {
        die "This container is being used for ".$self->status->name.", you may not put PE items into it\n";
    }

    if ($self->id->is_type('any_tote')) {
        my $shipment;

        if (exists $args->{shipment}) {
            $shipment=$args->{shipment};
        }
        elsif (exists $args->{shipment_item}) {
            $shipment=$args->{shipment_item}->shipment;
        }
        else {
            die "Must define one of 'shipment' or 'shipment_item'";
        }

        die "Unable to detemine shipment for packing exception item\n"
            unless $shipment;

        unless ($self->is_empty) {
            die "May not mix channels in one container\n"
                if $self->get_channel->id != $shipment->get_channel->id;
        }

    } elsif ($self->id->is_type('pigeon_hole')) {
        my $shipment;

        if (exists $args->{shipment}) {
            $shipment=$args->{shipment};
        }
        elsif (exists $args->{shipment_item}) {
            $shipment=$args->{shipment_item}->shipment;
        }
        else {
            die "Must define one of 'shipment' or 'shipment_item'";
        }

        die "Unable to determine shipment for packing exception item\n"
            unless $shipment;

        unless ($self->is_empty) {
            die "May not put item into a non-empty pigeon hole\n";
        }
    }
    else {
        # HAI AGANE! When you add further container type handlers, update
        # this message to include other container prefixes.  KTHXBAIBAI!
        die "Container ID must begin with 'M' or 'PH'\n";
    }

    return 1;
}

=head2 validate_orphan_item_into

As I<validate_packing_exception_into>, but for putting an orphan item
into a container instead.  Expects an I<orphan_item> arg or a canceled a I<shipment_item>.

=cut


sub validate_orphan_item_into {
    my ($self,$args) = @_;

    _check_op_args($args);

    unless (number_in_list($self->status_id,
                           $PUBLIC_CONTAINER_STATUS__AVAILABLE,
                           $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS)) {
        die "This container is being used for ".$self->status->name.", you may not put unexpected items into it\n";
    }

    # make sure current container's ID is one for Tote, otherwise - throw an exception
    $self->id( NAP::DC::Barcode::Container::Tote->new_from_id($self->id) );

    my $item;

    if (exists $args->{orphan_item}) {
        $item=$args->{orphan_item};

        die "'orphan_item' element not of type 'Public::OrphanItem'"
            unless $item->isa('XTracker::Schema::Result::Public::OrphanItem');
    }
    elsif (exists $args->{shipment_item}) {
        $item=$args->{shipment_item};

        die "'shipment_item' element not of type 'Public::ShipmentItem'"
            unless $item->isa('XTracker::Schema::Result::Public::ShipmentItem');

    }
    else {
        die "Must define one of 'orphan_item' or 'shipment_item'";
    }

    unless ($self->is_empty) {
        die "May not mix channels in one container\n"
            if $self->get_channel->id != $item->get_channel->id;
    }

    return 1;
}

=head2 _validate_remove

We're pretty lenient about deciding if you can remove something from a container.
Basically, if the container isn't empty, and the item/shipment is in a container
in the first place, remove away!

=cut


sub _validate_remove {
    my ($self,$args) = @_;

    _check_op_args($args);

    die "May not remove anything from an empty container\n"
        if $self->is_empty;

    my $item;

    if (exists $args->{shipment_item}) {
        $item=$args->{shipment_item};
    }
    elsif (exists $args->{orphan_item}) {
        $item=$args->{orphan_item};
    }

    if ($item) {
        my $item_container=$item->container;

        die "May not remove item that is not in a container\n"
            unless $item_container && $item_container->id;
    }
    else {
        # must be a shipment, because _check_op_args says so
        die "May not remove shipment that has no items in any container\n"
            unless $args->{shipment}->shipment_items->container_ids;
    }

    return 1;
}


=head2 set_status

Implement rules for setting the status of a container explicitly.

=cut

sub set_status {
    my ($self,$args) = @_;

    my $new_status_id=$args->{status_id};

    # this ensures that later checks know the status *will* be changing
    return $self if $new_status_id == $self->status->id;

    die "Unknown container status '$new_status_id'"
        unless number_in_list($new_status_id,
                              $PUBLIC_CONTAINER_STATUS__AVAILABLE,
                              $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
                              $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
                              $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS);

    unless (
        $self->is_empty
        ||
        ( # pigeon holes can go straight from picked->PE
            $self->is_pigeonhole
            &&
            $self->status->id == $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS
            &&
            $new_status_id == $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS
        )
    ) {
        die "May not change non-empty container ".$self->id
          ." in status ".$self->status->id." to 'Available' status\n"
            if $new_status_id == $PUBLIC_CONTAINER_STATUS__AVAILABLE;

        die "May not change non-empty container ".$self->id
          ." in status ".$self->status->id." to 'Packing Exception Items' status\n"
            if $new_status_id == $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS;

        die "May not change non-empty container ".$self->id
          ." in status ".$self->status->id." to 'Superfluous Items' status\n"
            if $new_status_id == $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS;

        # at this point, the new status has to be in 'Picked Items' status,
        # where we implement a further complication...

        die "May not change non-empty non-packing exception container ".$self->id
          ." in status ".$self->status->id." to 'Picked Items' status\n"
            if $self->status->id != $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS;
    }

    $self->update( { status_id => $new_status_id } );
}


=head2 add_picked_item

Add a picked item to a container.

In each case, pass in a hashref containing one of I<shipment> or I<shipment_item>,
where those are refs to a list of shipments or shipment items.  If there is only
one shipment specified, it may be any kind of shipment, otherwise all shipments
must be single-order shipments.

    $my_container->add_picked_item( { shipment_item => $item });

The result may only place more than one shipment in a container if all are
single-item shipments.

If the item is in another container already, remove it from that container too.

If the hashref contains the key I<dont_validate> and it is true, then we skip
validation.

FIXME: Rationalise logic which is duplicated in add_picked_item(),
add_packing_exception_item(), and add_orphan_item().

=cut

sub add_picked_item {
    my ($self,$args) = @_;

    unless ($args->{dont_validate}) {
        $self->validate_pick_into($args);
    }

    my $shipment_item=$args->{shipment_item};

    if (defined $shipment_item->container
        && $shipment_item->container->id ne $self->id ) {
        # this item is already in another container, remove it
        # from that container too (in case that adjusts the
        # status of that container)

        # Ok this is a pretty ugly hack (the into arg), but the logic is too
        # complicated for me to refactor it, and we need this done in one step
        # so the shipment item container logging framework recognises this as a
        # *move*.
        $shipment_item->container->remove_item(
            { shipment_item => $shipment_item, into => $self->id }
        );
    }
    else {
        $shipment_item->update( { container_id => $self->id } );
    }

    $self->update(  { status_id => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS } )
        if $self->status_id == $PUBLIC_CONTAINER_STATUS__AVAILABLE;

    return $self;
}

=head2 add_packing_exception_item

Add a packing-exception item to a container.

Expects a hashref containing a I<shipment_item>, which is a ref to a shipment item.

    $my_container->add_packing_exception_item( { shipment_item => $item });

If the item is in another container already, remove it from that container too.

If the hashref contains the key I<dont_validate> and it is true, then we skip validation.

=cut

sub add_packing_exception_item {
    my ($self,$args) = @_;

    unless ($args->{dont_validate}) {
        $self->validate_packing_exception_into($args);
    }

    my $shipment_item=$args->{shipment_item};

    if (defined $shipment_item->container
        && $shipment_item->container->id ne $self->id ) {
        # this item is already in another container, remove it
        # from that container too (in case that adjusts the
        # status of that container)

        $shipment_item->container->remove_item(
            { shipment_item => $shipment_item, into => $self->id }
        );
    }
    else {
        $shipment_item->update({ container_id => $self->id });
    }

    $self->update(  { status_id => $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS } )
        unless $self->status_id == $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS;

    return $self;
}

=head2 add_orphan_item

An orphan item can be canceled shipment_item or a strayed sku (variant)

=cut

sub add_orphan_item {
    my ($self,$args) = @_;

    unless ($args->{dont_validate}) {
        $self->validate_orphan_item_into($args);
    }

    $self->update( {  status_id => $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS } )
        unless $self->status_id == $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS;

    if (defined $args->{shipment_item}) {
    my $shipment_item=$args->{shipment_item};

    if (defined $shipment_item->container
        && $shipment_item->container->id ne $self->id ) {
        # this item is already in another container, remove it
        # from that container too (in case that adjusts the
        # status of that container)

        $shipment_item->container->remove_item( { shipment_item => $shipment_item } );
    }

    $shipment_item->update( { container_id => $self->id } );
    } else {
    # For strayed skus we don't need to remove them from a container because they weren't
    # even supposed to be there
    $args->{orphan_item}->container_id( $self->id );
    }

    return $self;
}


=head2 add_picked_shipment

Pick all the items in a shipment to a container.

Expects a hashref containing a I<shipment>, which is a ref to a shipment.

    $my_container->add_picked_shipment( { shipment => $shipment });

If any item is in another container already, remove it from that container too.

=cut


sub add_picked_shipment {
    my ($self,$args) = @_;

    $args->{shipment}->shipment_items->pick_into( $self->id, $args->{operator_id} );
}

=head2 remove_shipment

Drop all the items from a single shipment from the container.

=cut

sub remove_shipment {
    my ($self,$args) = @_;

    $self->_validate_remove($args);

    $args->{shipment}->shipment_items->unpick;
}

=head2 remove_item

Drop only a single item from the container.

=cut

sub remove_item {
    my ($self,$args) = @_;

    $self->_validate_remove($args);

    if ( $args->{'shipment_item'} ) {
        $args->{'shipment_item'}->update( { container_id => $args->{into} } );
    } elsif ( $args->{'orphan_item'} ) {
        $args->{'orphan_item'}->delete();
    } else {
        die "No item to remove";
    }

    if ($self->is_empty) {
        $self->send_container_empty_to_prls;
        $self->update({
            status_id         => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
            # When the tote is empty, it's not considered to "be"
            # anywhere any more
            physical_place_id => undef,
        });
        $self->remove_from_commissioner if $self->is_in_commissioner;
    }

    return $self;
}

=head2 move_to_physical_place($physical_place_id) : $row

Update physical_place_id to $physical_place_id.

=cut

sub move_to_physical_place {
    my ($self, $physical_place_id) = @_;
    return $self->update({ physical_place_id => $physical_place_id });
}

=head2 _available_shipment_slots

Helper method that returns the number of available shipments slots in this container.

Returns a comically high value when a container may be used as a bag of holding,
otherwise returns the configured maximum number of shipments in a tote.

Note: there is no 'available item slots' value, because that is not currently limited.

=cut

sub _available_shipment_slots {
    my $self=shift;

    if (number_in_list($self->status->id,
                       $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
                       $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS)) {
        return 10_000;             # basically, unlimited
    }
    else {
        return config_var('PackingToTote','max_shipments_in_tote');
    }
}

=head2 is_empty, is_full

Helper methods for determining if a container is empty, or has no remaining space.

=cut


sub is_empty {
    my $self=shift;
    return !(   $self->count_related('shipment_items')
             || $self->count_related('orphan_items'));
}

sub is_full {
    my $self=shift;

    return $self->_available_shipment_slots() <= $self->shipments->count;
}

=head2 shipment_ids

Return a list of all shipment IDs in the current container.

=cut

sub shipment_ids {
    return shift->shipment_items->search(
        undef,
        {
            select => [ { distinct => 'shipment_id' } ],
            as     => [ 'shipment_id' ]
        }
    )->get_column('shipment_id')->all;
}

=head2 shipments

Return a result set of all shipments in the container.

=cut

sub shipments {
    my ($self) = @_;

    my @shipment_ids=$self->shipment_ids;

    return $self->result_source
        ->schema
        ->resultset('Public::Shipment')
        ->search( { 'me.id' => { -in => [ @shipment_ids ] } } );
}

=head2 is_multi_shipment

Returns true iff the container contains items from more than one shipment.

=cut

sub is_multi_shipment {
    return shift->shipment_items->search(
        undef,
        {
            select => [ { count => { distinct => 'shipment_id' } } ],
            as     => [ 'shipment_count' ]
        }
    )->single->shipment_count > 1;
}

=head2 get_channel

Return the channel associated with the first shipment in the container.
(Which is presumed to be the channel of all items in the container.)

=cut

sub get_channel {
    my ($self) = @_;

    return unless !$self->is_empty;

    # outrageously presume that each item will actually have a channel
    if ($self->shipments->first) {
    return $self->shipments->first->get_channel;
    } elsif ($self->orphan_items->first) {
    return $self->orphan_items->first->get_channel;
    } else {
    die "Can't determine channel for non-empty container.";
    }
}

=head2 physical_type

Returns a string describing the physical type of a container, based on its ID.

=cut

sub physical_type { shift->id->name }

=head2 accepts_faulty_items

Rule for deciding if a container can have a faulty item put into it.

At present, this can only be applied to empty container, since we don't
*actually* put faulty items into a container -- we just tell IWS we do,
but the container will remain empty in XTracker.

=cut

sub accepts_faulty_items {
    my $self = shift;

    return $self->is_empty;
}

=head2 accepts_putaway_ok_items

Rule for deciding if a container can have non-faulty putaway items in it.

The container must be empty as far as the XTRACKEREERERER is concerned

=cut

sub accepts_putaway_ok_items {
    my $self = shift;
    return $self->is_empty;
}

sub set_place {
    my ($self,$place) = @_;

    return $self->update({ place => undef })
        unless $place;

    die "Place $place is not valid\n"
        unless is_valid_place($place);

    return $self->update({ place => $place });
}

sub send_to_commissioner {
    my $self = shift;

    die "Cannot put empty container in commissioner\n"
        if $self->is_empty;

    $self->set_status({status_id => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS});

    return $self->set_place(get_commissioner_name);
}

sub remove_from_commissioner {
    my $self = shift;

    return $self->set_place( undef );
}


=head2 are_all_items_cancel_pending

Returns true if all items in the container are in status 'Cancel Pending'

=cut

sub are_all_items_cancel_pending {
    my $self = shift;

    my $shipment_items_count = $self->shipment_items->count or return;

    # this probably needs to be better, ie there are two items
    # dispatched and one cancelled?
    my $shipment_items_in_cancel_pending_count
        = $self->shipment_items->search({
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
        })->count;

    return $shipment_items_count == $shipment_items_in_cancel_pending_count;
}

sub are_all_shipments_cancelled {
    my $self = shift;

    my $shipments_rs = $self->shipments or return;

    return ! $shipments_rs->search({
        shipment_status_id => {'!=' => $SHIPMENT_STATUS__CANCELLED},
    })->count;
}

=head2 are_all_shipments_on_hold

Returns true if all shipments in this container are in status 'On Hold'.
(Returns false for empty containers, which irritates the logician in me)

=cut

sub are_all_shipments_on_hold {
    my $self = shift;

    my $shipments = $self->shipments;
    my $shipment_count = $shipments->count;
    return unless $shipment_count;

    return $shipment_count == $shipments->filter_on_hold->count;
}

=head2 packing_ready_in_commissioner

Returns true if container is ready to be sent to packing from Commissioner.

=cut

sub packing_ready_in_commissioner {
    my $self = shift;

    my @related_shipments = $self->shipments->all;

    return
        @related_shipments
        ==
        grep { $_->shipment_status_id eq $SHIPMENT_STATUS__PROCESSING } @related_shipments;
}

=head2 contains_orphan

Returns a count of orphan_items in the container, aka extraneous items

=cut

sub contains_orphan_items {
    my $self = shift;
    return $self->orphan_items->count;
}

=head2 is_pigeonhole

Returns true iff container is a pigeon hole

=cut

sub is_pigeonhole {
    my $self = shift;
    return $self->id->is_type('pigeon_hole');
}

=head2 is_rail

Returns true iff container is a rail

=cut

sub is_rail {
    my $self = shift;
    return $self->id->is_type('rail');
}

=head2 is_tote

Returns true if container is a tote

=cut

sub is_tote {
    my $self = shift;

    return $self->id->is_type('any_tote');
}

=head2 is_part_of_multi_container_shipment

Returns true iff this container is one of the containers associated with a multi-container shipment

=cut

sub is_part_of_multi_container_shipment {
    my $self = shift;

    my $shipments = $self->shipments;
    my $shipment_count = $shipments->count;

    return $shipment_count == 1 && $shipments->first->containers->count > 1;
}

=head2 other_containers_in_shipment

Return a list of the other containers in the same shipment as this
one, not including this one, in helpfully alphanumeric order; only
makes sense for multi-container shipments, in which case only one
shipment ought to be associated with this container.

Don't validate that only one shipment is associated with this
container, but in that case, the result should always be an empty
resultset anyway, so it's harmless.

=cut

sub other_containers_in_shipment {
    my $self = shift;

    return $self
        ->shipments->first
        ->containers->search(
            { id       => [ { '!=' => $self->id } ] },
            { order_by => { -asc => 'id'          } },
        );
}

=head2 get_preassigned_packlane_ids

Look at all the containers that are associated with this
one (by being a part of the same shipments) and returns a unique
list of all the pack_lane_ids associated with them.

=cut

sub get_preassigned_packlane_ids {
    my $self = shift;

    my $schema = $self->result_source->schema;

    my @preassigned_packlane_ids = $schema->resultset('Public::Container')->search({
        pack_lane_id => { '!=' => undef },
        shipment_id => { '-in' => $self->shipment_items->get_column('shipment_id')->as_query }
    }, {
        join => 'shipment_items'
    })->get_column('pack_lane_id')->func('DISTINCT');

    return @preassigned_packlane_ids;

}

=head2 is_in_cage: Bool

Determine if current container is located in Cage.

=cut

sub is_in_cage {
    my $self = shift;

    return ($self->physical_place_id // "") eq $PHYSICAL_PLACE__CAGE;
}

=head2 has_pack_lane: Bool

Indicated if container is aware where it is going to go for packing.

=cut

sub has_pack_lane {
    my $self = shift;

    return !! $self->pack_lane_id;
}

=head2 packing_summary : $packing_summary_string

Return packing_summary for the Container with details about where it is.

=cut

sub packing_summary {
    my $self = shift;

    # Container has special "Packing summary" if it is in the Cage
    $self->is_in_cage  and return $self->_packing_summary_for_container_in_cage;

    # Containers with known pack lane have special "Packing summary"
    $self->has_pack_lane and return $self->_packing_summary_for_containers_with_pack_lane;

    my @where;
    if (my $place = $self->place) {
        # Container has assigned to Logical place/location, e.g. Commissioner
        push @where, $place;
    } else {
        my $warehouse_has_induction_point = config_var("PRL", "rollout_phase");
        if($warehouse_has_induction_point) {
            # By default un-inducted containers assumed to be at induction point
            push @where, "at induction";
        }
    }

    return $self->_stitch_packing_summary({ where => \@where });
}

sub _stitch_packing_summary {
    my ($self, $state, $where) = validated_list(\@_,
        state => { isa => 'ArrayRef', default => [] },
        where => { isa => 'ArrayRef', default => [] },
    );

    my $places_summary = join(
        ", ",
        grep { $_ } ( @$state, @$where ),
    );
    $places_summary &&= " ($places_summary)";

    # i.e. "$CONTAINER_ID (list of states, list of places)"
    return $self->id . $places_summary;
}

sub _places_for_packing_summary {
    my $self = shift;

    my @places;

    # Report container's logical and physical places
    push @places, $self->physical_place->name if $self->physical_place_id;
    push @places, $self->place                if $self->place;

    return \@places;
}

sub _packing_summary_for_container_in_cage {
    my $self = shift;

    # We do not show "state" if it cage, but still need "logical places"
    return $self->_stitch_packing_summary({
        where => $self->_places_for_packing_summary,
    });
}

sub _packing_summary_for_containers_with_pack_lane {
    my $self = shift;

    # For containers with Pack lane show its "state": "arrived" or "en route"
    my @state;

    # Container was already inducted: we know where it is going to go

    if ($self->has_arrived) {

        # Container already arrived to the packing lane, in that case we report
        # only its state, "place" does not matter
        push @state, "arrived";

        # In case of "oversized" items that could not be conveyed,
        # container has "arrived" state, but actually should be walked
        # to Packing manually

        return $self->_stitch_packing_summary({ state => \@state });
    }

    # The container is on its way to pack lane
    push @state, "en route";

    return $self->_stitch_packing_summary({
        where => $self->_places_for_packing_summary,
        state => \@state,
    });
}

=head2 choose_packlane

This is used by routing to determine which pack lane a container should go to.
It inspects the capacity of packlanes and chooses an appropriate one. It also
records its decision in the Container table so that subsequent multi container
shipments can be redirected correctly.

=cut

sub choose_packlane {
    my $self = shift;

    my $schema = $self->result_source->schema;
    my $logger = xt_logger(__PACKAGE__);

    # first decision: is a packlane assigned to a sibling container already?
    my @preassigned_packlane_ids = $self->get_preassigned_packlane_ids;

    # One result? Excellent. We already have a pack lane assigned. Since we always send
    # multitotes to the same lane even if the lane was switched off or is over capacity
    # we are simply done at this point.
    if (@preassigned_packlane_ids == 1) {

        my $chosen_pack_lane_id = $preassigned_packlane_ids[0];
        my $pack_lane = $schema->resultset('Public::PackLane')->find($chosen_pack_lane_id);

        return $self->_assign_pack_lane($pack_lane, 'sibling container');

    }

    # More than one pack lane? Then we have a problem.
    # We've been routed to two different locations.
    if (@preassigned_packlane_ids > 1) {
        $logger->error(sprintf('Cant route container correctly because it is associated with multiple pack lanes (container_id=%s, pack_lane_ids=%s)',
            $self->id,
            join(', ', @preassigned_packlane_ids)
        ));

        my $pack_lane = $schema->resultset('Public::PackLane')->get_pack_lane_for_errors();
        return $self->_assign_pack_lane($pack_lane, 'shipments in container associated with multiple routes');
    }

    # Must have no results. This means we need a pack lane assigned because it is either
    # a single tote or the first tote in a multitote. Gather together the variables we use
    # to select an appropriate pack lane

    my @attrs;

    my $shipments_rs = $self->shipments;

    my $is_prem = ($shipments_rs->premier->count > 0);
    my $is_sample = ($shipments_rs->sample->count > 0);

    my $is_multitote = $schema->resultset('Public::ShipmentItem')->is_treated_as_multitote(
        $self->id,
        $self->shipment_items
    );

    push (@attrs, $PACK_LANE_ATTRIBUTE__PREMIER) if $is_prem;
    push (@attrs, $PACK_LANE_ATTRIBUTE__SAMPLE) if $is_sample;
    push (@attrs, $PACK_LANE_ATTRIBUTE__STANDARD) if (!$is_prem && !$is_sample);

    push (@attrs, $PACK_LANE_ATTRIBUTE__SINGLE) if (!$is_multitote);
    push (@attrs, $PACK_LANE_ATTRIBUTE__MULTITOTE) if ($is_multitote);

    # we let this resultset for an optimised SQL query do the filtering
    my $packlane = $schema->resultset('Public::PackLane')->select_pack_lane(
        \@attrs
    );

    return $self->_assign_pack_lane($packlane, 'new pack lane associated created');
}

=head2 _assign_pack_lane

This function is pretty much a one-liner with a log statement. Given
a pack_lane object we assign it to ourselves and update our routed_at
date.

=cut

sub _assign_pack_lane {
    my ($self, $pack_lane, $reason) = @_;

    my $logger = xt_logger(__PACKAGE__);

    if (!defined($pack_lane)) {
        my $error = "Unable to assign packlane to Container ("
            . $self->id
            . ") ($reason)";
        $logger->error($error);
        die("$error\n");
    }

    $self->update({
        pack_lane_id => $pack_lane->pack_lane_id,
        has_arrived  => 0,
        routed_at    => \'now()',
        arrived_at   => undef
    });

    $logger->info(sprintf('Container Routed (container_id=%s,shipment_ids=%s,packlane=%d [%s],reason=%s',
        $self->id,
        # is this list of shipment ids in this log message worth a SQL call?
        join(', ', $self->shipment_items->get_column('shipment_id')->all() ),
        $pack_lane->pack_lane_id,
        $pack_lane->human_name,
        $reason
    ));

    return $pack_lane;
}

=head2 ensure_has_pack_lane() : die

Die with NAP::XT::Exception::Internal unless the Container has a
pack_lane_id set.

=cut

sub ensure_has_pack_lane {
    my $self = shift;
    $self->pack_lane_id // NAP::XT::Exception::Internal->throw({
        message => "Container (" . $self->id . ") marked as 'arrived' without having a Pack Lane destination set",
    });
}

=head2 mark_has_arrived_at_pack_lane() : 1 | die

Mark the Container as having arrived at its pack_lane_id.

Return 0 if has_arrived is already set - if that's the case then we don't
need to do anything and we don't want to overwrite the arrived_at timestamp.

Return 1 if we have updated has_arrived and set the timestamp.

Die if the Container doesn't have a pack_lane_id destination (because
that wouldn't make any sense).

=cut

sub mark_has_arrived_at_pack_lane {
    my $self = shift;

    $self->ensure_has_pack_lane();

    return 0 if $self->has_arrived;

    $self->update({
        has_arrived => 1,
        arrived_at  => \'now()',
    });

    return 1;
}

=head2 mark_has_arrived_at_integration($integration_container) : 1 | 0

Mark the Container as having arrived at integration.

Return 0 if arrived_at is already set on the integration_container - if
that's the case then we don't need to do anything and we don't want to
overwrite the arrived_at timestamp.

Return 1 if we have set the timestamp.

=cut

sub mark_has_arrived_at_integration {
    my ($self, $integration_container) = @_;

    return $integration_container->mark_has_arrived_at_integration;
}

=head2 maybe_mark_has_arrived() : 1 | 0

Mark the Container as having arrived at its pack_lane_id (and return
1) if there is one and it hadn't arrived yet, otherwise not (and return 0).

This happens IRL when:

* The Container arrives at a PackLane and the Dematic conveyor scanner
  sends a RouteResponse

* At packing, when QC is completed (normal shipments), or the Shipment
  is scanned at Packing (sample shipments)

=cut

sub maybe_mark_has_arrived {
    my $self = shift;
    if ($self->pack_lane_id) {
        return $self->mark_has_arrived_at_pack_lane();
    } elsif (my $integration_container = $self->routed_integration_container) {
        return $self->mark_has_arrived_at_integration($integration_container);
    }
    return 0;
}

=head2 routed_integration_container() : $integration_container_row | undef

If this container is on its way to integration, return the associated
integration_container row.

Note: There shouldn't ever be more than one in this state, but if there are,
we just return the first one and log a warning.

=cut
sub routed_integration_container {
    my $self = shift;

    my @routed_integration_containers = $self->integration_containers->search({
        is_complete => 0,
        routed_at   => { '!=', undef },
        arrived_at  => undef,
    },{
        order_by    => 'id',
    })->all;

    if ((scalar @routed_integration_containers) > 1) {
        my $logger = xt_logger(__PACKAGE__);
        $logger->warn(
            sprintf("More than one integration container en route for container id [%s%]", $self->id)
        );
    }

    return $routed_integration_containers[0];
}

=head2 has_cage_items

Does the container have any items with the 'Cage' storage type?

=cut

sub has_cage_items {
    my $self = shift;
    return 1 if
        any { $_->product->storage_type_id == $PRODUCT_STORAGE_TYPE__CAGE }
        $self->shipment_items->all;

    return 0;
}

=head2 send_container_empty_to_prls

Send the container_empty message to the destination supplied, or
to all configured PRLs if no destination is specified.

=cut

sub send_container_empty_to_prls {
    my ($self, $args) = @_;

    return if !$self->prl_rollout_phase;

    my $amq = $args->{amq} || $self->msg_factory;

    my $msg_data = {
        container => $self,
        destinations => $args->{destinations} || $self->destinations,
    };

    $amq->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::ContainerEmpty' => $msg_data,
    );
}

=head2 remove_from_packlane

Indicate that current container does not belong to any PackLanes.

=cut

sub remove_from_packlane {
    my $self = shift;

    $self->update({
        pack_lane_id => undef,
        has_arrived  => 0,
        arrived_at   => undef,
        routed_at    => undef,
    });
}

=head2 other_container_rows_ready_for_induction() : $rs | @container_rows

Return a list of the other Containers in the same Allocations as this
one that are ready for induction, not including this Container.

Don't validate that only one shipment is associated with this
container, but in that case, the result should always be an empty
resultset anyway, so it's harmless.

=cut

sub _container_rs {
    my $self = shift;
    return $self->result_source->schema->resultset("Public::Container");
}

sub other_container_rows_ready_for_induction {
    my ($self, $allocation_status_id) = @_;

    my $related_container_id_rs = $self
        ->shipment_items
        ->related_resultset("allocation_items")
        ->related_resultset("allocation")
            ->ready_for_induction( $self->is_in_commissioner )
        ->related_resultset("allocation_items")
        ->related_resultset("shipment_item")
            ->get_column("container_id");

    return $self->_container_rs->search(
        {
            -and => [
                "me.id" => { -in => $related_container_id_rs->as_query },
                "me.id" => { '!=' => $self->id },
            ],
        },
        { order_by => { -asc => "me.id" } },
    );
}

=head2 shipment_item_count() : $shipment_item_count

Return hashref (keys: ShipmentItem ids; values: count of
ShipmentItems).

=cut

sub shipment_item_count {
    my $self = shift;

    my $shipment_item_count;
    for my $shipment_item ($self->shipment_items) {
        $shipment_item_count->{ $shipment_item->shipment_id } ++;
    }

    return $shipment_item_count;
}

=head2 related_allocation_rs() : $allocation_rows | $allocation_rs

Return a resultset with all Allocations (via AllocationItems, via
ShipmentItems) that are in this Container, or an empty resultset if
none was found.

=cut

sub related_allocation_rs {
    my $self = shift;
    my $schema = $self->result_source->schema;
    my $allocation_rs = $schema->resultset("Public::Allocation");
    return $allocation_rs->search(
        { "container.id" => $self->id },
        { join => { shipment => { shipment_items => "container" } } },
    )->group_by_result_source();
}

=head2 related_shipment_rs() : $shipment_rows | $shipment_rs

Return a resultset with all Shipments (via ShipmentItems) that are in
this Container, or an empty resultset if none was found.

=cut

sub related_shipment_rs {
    my $self = shift;
    $self->shipment_items
        ->search_related("shipment")
        ->search(undef, { distinct => 1 });
}

=head2 pick_staged_allocations() :

Update the Allocations of the Shipment Items in the Container to
PICKED status.

=cut

sub pick_staged_allocations {
    my ($self, $operator_id) = @_;

    xt_logger('PickScheduling')->debug("Picking staged allocations for container ".$self->id);
    my $staged_allocation_ids = [
        map { $_->id }
        $self->related_allocation_rs->staged
    ];

    # Can't do update directly from the related_allocation_rs because
    # of the group_by to make the rows distinct
    my $allocation_rs = $self->result_source->schema->resultset(
        "Public::Allocation",
    );
    $allocation_rs->search({
        id => { -in => $staged_allocation_ids },
    })->update_to_picked($operator_id);
}

=head2 trigger_picks_for_related_allocations($message_factory, $operator_id) : @unpicked_allocation_rows

Send pick messages (using the $message_factory) for Allocated
Allocations of the Shipment in the Container, for related PRLs which
should have their allocations triggered by this one
(@unpicked_allocation_rows).

Log any changes using the $operator_id.

There are already picked items in this Container (and possibly
others). The pick messages we send now are for the remaining,
unpicked, items in the Shipment that are to be picked related PRLs,
e.g. DCD,

=cut

sub trigger_picks_for_related_allocations {
    my ($self, $message_factory, $operator_id) = @_;

    my @unpicked_allocation_rows = $self
        ->related_allocation_rs->allocated->filter_prls_without_staging_area();
    for my $allocation_row (@unpicked_allocation_rows) {
        xt_logger('PickScheduling')->debug("About to pick allocation ".$allocation_row->id);
        $allocation_row->pick($message_factory, $operator_id);
    }

    return @unpicked_allocation_rows;
}

=head2 allocation_row() : $allocation_row | undef

Return the first Allocation (via AllocationItems, via ShipmentItems)
that is in this Container, or undef if none was found.

=cut

sub allocation_row {
    my $self = shift;

    my $allocation_item_row = $self
        ->shipment_items
        ->search_related("allocation_items")->first
            or return undef;

    return $allocation_item_row->allocation;
}

=head2 related_allocations() : $allocation_row_rs | @allocation_rows

Return related resultset for Allocations (via AllocationItems, via
ShipmentItems) that is in this Container.

=cut

sub related_allocations {
    my $self = shift;
    return $self
        ->shipment_items
        ->search_related("allocation_items")
        ->search_related("allocation")
        ->search(undef, { distinct => 1 });
}

=head2 is_ready_for_induction() : Bool

Whether this Container is associated with at least 1 staged
Allocation.

We shouldn't ever end up with a mix of items belonging to staged
Allocations and other items, but if somehow we have, it's best to
accept that this is in the staging area so that it can be sent via
Packing to Packing Exception and dealt with there.

Don't worry about whether items have been cancelled, because if
they're in the container in the staging area then they need to go to
packing just the same as uncancelled items.

=cut

sub is_ready_for_induction {
    my $self = shift;

    $self
        ->shipment_items
        ->search_related('allocation_items')
        ->search_related('allocation')
        ->staged
        ->count and return 1;

    if( $self->is_in_commissioner) {
        $self->packing_ready_in_commissioner and return 1;
    }

    return 0;

}

1;
