use utf8;
package XTracker::Schema::Result::Public::PutawayPrepInventory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.putaway_prep_inventory");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "putaway_prep_item_id_seq",
  },
  "putaway_prep_container_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pgid",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
  "voucher_variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "putaway_prep_group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "putaway_prep_container",
  "XTracker::Schema::Result::Public::PutawayPrepContainer",
  { id => "putaway_prep_container_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "putaway_prep_group",
  "XTracker::Schema::Result::Public::PutawayPrepGroup",
  { id => "putaway_prep_group_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "voucher_variant",
  "XTracker::Schema::Result::Voucher::Variant",
  { id => "voucher_variant_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xH9phuClWF8yN1+S9O0inQ

# NOTE: pgid above is really a group_id, it can refer to either a pgid or rgid,
# i.e. a stock_process->group_id or a stock_recode->id

# These are supporting outer-join relationships to allow prefetches and joins
# over relationships that may not actually exist
__PACKAGE__->belongs_to(
    outer_variant =>  "XTracker::Schema::Result::Public::Variant",
    { id => "variant_id" },
    { join_type => "LEFT OUTER" },
);
__PACKAGE__->belongs_to(
    outer_voucher_variant =>  "XTracker::Schema::Result::Voucher::Variant",
    { id => "voucher_variant_id" },
    { join_type => "LEFT OUTER" },
);

use XT::Domain::PRLs;
use MooseX::Params::Validate qw(validated_list);
use XTracker::Logfile qw(xt_logger);
use XTracker::Constants::FromDB qw/
    :flow_status
/;

my $log = xt_logger(__PACKAGE__);

sub variant_with_voucher {
    my ($self) = @_;

    # try normal variant
    my $result = $self->variant;
    return $result if $result;

    # try voucher_variant
    $result = $self->voucher_variant;
    return $result if $result;

    return; # no matches
}

sub variant_with_voucher_id {
    my ($self) = @_;
    return $self->variant_id // $self->voucher_variant_id // undef;
}

=head2 inventory_group_data_for_putaway_admin

Returns a hashref of information about the group linked to this
ppi row, for use on the putaway admin page. It uses a lot of
information from this inventory row as well as the group, which
is why it's living in here rather than the PutawayPrepGroup class,
but it could probably go there instead if someone wanted to move it.

=cut

sub inventory_group_data_for_putaway_admin {
    my ($self, $all_flow_statuses, $stock_processes) = @_;

    my $pp_group = $self->putaway_prep_group;
    my $pp_container = $self->putaway_prep_container;

    my $data = {
        putaway_prep_group_id => $pp_group->id,
        status_id => $pp_group->status_id,
    };

    # If it's a voucher:
    if ( $self->is_voucher ) {
        $data->{'pid'} =
            $self->outer_voucher_variant->voucher_product_id;
        $data->{'designer'} = '-';
        $data->{'upload_date'} = $self->outer_voucher_variant->product->upload_date;
        $data->{'channel_id'} =
            $self->outer_voucher_variant->product->channel_id;
        $data->{'sku'} = _make_sku($data->{'pid'});
        $data->{'storage_type'} = $self->outer_voucher_variant->product->storage_type->name;
        $data->{'voucher'} = 1;
    # Otherwise it's a real product:
    } else {
        $data->{'pid'} = $self->outer_variant->product_id;
        $data->{'designer'} =
            $self->outer_variant->product->designer->designer;

        my ( $product_channel ) = grep { $_->live }
            $self->outer_variant->product->product_channel->all;
        if ($product_channel) {
            $data->{'upload_date'} = $product_channel->upload_date;
            $data->{'channel_id'} = $product_channel->channel_id;
        }
        $data->{'sku'} = _make_sku($data->{'pid'}, $self->outer_variant->size_id);
        $data->{'storage_type'} = $self->outer_variant->product->storage_type->name;
    }

    # Valid PRL(s) for this group are determined by storage type and stock status.
    # We only expect one PRL per group for now, but in the future who knows...
    my $group_prls = XT::Domain::PRLs::get_prls_for_storage_type_and_stock_status({
        storage_type => $data->{storage_type},
        stock_status => $pp_group->get_stock_status_row_from_cache(
            $all_flow_statuses,
            $stock_processes
        )->name,
    });

    if ($group_prls) {
        my @prl_names = keys %$group_prls;
        my @locations = map {
            XT::Domain::PRLs::get_location_from_prl_name({
                prl_name => $_,
            })
        } @prl_names;

        $data->{'prl'} = join(',', map { $_->location } @locations);
    }

    return $data;
}

# TODO: move this to somewhere more sensible, at the moment it's duplicating
# what's in XTracker::Schema::Result::Public::Variant
sub _make_sku {
    my ($product_id, $size_id) = @_;
    $size_id //= 999; # Voucher default
    return sprintf("%d-%03d", $product_id, $size_id );
}

sub start_putaway {
    my ($self, $location) = validated_list(
        \@_,
        location => { isa => 'XTracker::Schema::Result::Public::Location' },
    );
    my $schema = $self->result_source->schema;

    my $pp_group = $self->putaway_prep_group->assert_is_active();

    # The rest of this first loop which creates Putaway rows is relevant
    # only for pp_groups that link to stock_processes
    return unless $pp_group->is_stock_process;

    $log->debug('pp group links to stock process PGID '.$pp_group->group_id);

    my $stock_process = $self->stock_process;

    # Write an appropriate Putaway, or update an existing one.
    # find_or_new is like find_or_create, but delays creation, so we
    # don't need to provide all the fields yet, which is good, because
    # we don't yet know the quantity...
    my $putaway = $schema->resultset('Public::Putaway')->find_or_new(
        stock_process_id => $stock_process->id,
        location_id      => $location->id,
    );

    # This is how many items of stock we're expecting to have putaway in
    # this container
    my $quantity = $self->quantity;

    # If the row is in the db, we know it was already there, and want to
    # update its quantity value with this inventory...
    if ($putaway->in_storage) {
        $putaway->update({ quantity => $putaway->quantity + $quantity });
    # Otherwise, set the quantity and insert
    } else {
        $putaway->quantity( $quantity );
        $putaway->insert;
    }

    return;
}

sub return_item_id {
    my ($self) = @_;
    my $stock_process_row = $self->stock_process or return undef;
    return $stock_process_row->return_item_id();
}

sub stock_process {
    my ($self) = @_;

    return unless $self->putaway_prep_group->is_stock_process;

    my $schema = $self->result_source->schema;

    # We're looking for a stock_process here that has the same
    # variant_id as the pp_inventory row. pp_inventory has a direct
    # reference to the variant_id already, but stock_process doesn't.
    # The plan: look up all stock processes with the group_id, and then
    # query each for its variant_id, and when we have a matching
    # variant_id, use that.
    my @stock_processes_for_pgid =
        $schema->resultset('Public::StockProcess')->search({
            "me.group_id" => $self->pgid });

    my $stock_process;

    my $variant_id = $self->variant_with_voucher->id;
    SP: for my $sp (@stock_processes_for_pgid) {
        # Work out what the variant id is via a very complicated process
        my $sp_variant = $sp->variant ||
            die sprintf("Unable to find a variant for StockProcess [%s]", $sp->id);

        # If this is the one that matches the pp_inventory's variant_id
        if ( $sp_variant->id == $variant_id ) {
            $stock_process = $sp; # Save it
            last SP; # Don't bother with the rest of this loop
        }

    }

    # Noisily catch the case where we couldn't find a stock_process
    unless ( $stock_process ) {
        die sprintf(
            "Couldn't find a Stock Process for group_id [%s] " .
            "with a linked variant [%s] for pp_inventory [%s]. ",
            $self->pgid, $variant_id, $self->id );
    }

    return $stock_process;
}

sub is_voucher {
    my ($self) = @_;
    return $self->outer_voucher_variant;
}

=head2 move_stock_from_location_to_prl(:$location_row, :$operator_row) : 1

Perform transition of stock related to current inventory record from specified
location to PRL.

=cut

sub move_stock_from_location_to_prl {
    my ($self, $location, $operator) = validated_list(
        \@_,
        location => { isa => 'XTracker::Schema::Result::Public::Location' },
        operator => { isa => 'XTracker::Schema::Result::Public::Operator' },
    );

    my $quantity_rs = $self->result_source->schema->resultset('Public::Quantity');

    my $variant = $self->variant_with_voucher;

    $quantity_rs->move_stock({
        variant  => $variant,
        channel  => $variant->current_channel,
        quantity => $self->quantity,
        from     => {
            location => $location,
            status   => $FLOW_STATUS__IN_TRANSIT_TO_PRL__STOCK_STATUS,
        },
        to              => undef,
        log_location_as => $operator,
    });

    return 1;
}

=head2 get_return_items: @return_item_rows

If this inventory contains any returned items, returns a list of them.
Otherwise returns an empty list.

=cut

sub get_return_items {
    my $self = shift;

    my $variant_id = $self->variant_id // $self->voucher_variant_id;
    return unless defined $variant_id;
    return $self->putaway_prep_group->get_return_items($variant_id);
}

1;
