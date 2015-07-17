package Test::XT::Fixture::PutawayPrep::StockProcess::Group;
use NAP::policy "tt", "class";
with "Test::Role::WithSchema";

=head1 NAME

Test::XT::Fixture::PutawayPrep::StockProcess::Group - Fixture for a PuwawayPrepGroup and its contents

=head1 DESCRIPTION

PPrepGroup with two SKUs, and associated StockProcess and PP Inventory
rows.


=head2 Data

    * Data
     * $product
      * $sku_1
      * $sku_2
     * $pgid
      * $stock_process_1_sku_1
      * $stock_process_2_sku_1
      * $stock_process_3_sku_1
      * $inventory_1_sku_1
      * $inventory_2_sku_1
      * $inventory_3_sku_2
     * pp_container_1
     * pp_container_2

Of note:

 * sku_1 has two stock processes (sp1_s1, sp2_s1), and two pprep inventories
   (inv 1, 2)

 * sku_2 has one stock_process (sp3_s2) and one pprep inventory (inv
   3)

The tests will use this basic test setup with various _expected_
->with_stock_process_quantities and _actual_
->with_inventory_quantities.

=cut

use Moose::Util::TypeConstraints;

use Carp qw/ confess /;
use Test::More;

use XTracker::Database::PutawayPrep;
use XTracker::Constants::FromDB qw(
    :storage_type
    :stock_process_status
    :stock_process_type
    :putaway_prep_group_status
    :putaway_prep_container_status
);

use Test::XTracker::Data;
use Test::XT::Data::PutawayPrep;


=head1 ATTRIBUTES

=cut

has pp_setup => (
    is      => "ro",
    default => sub { Test::XT::Data::PutawayPrep->new() },
);

has putaway_prep_domain => (
    is      => "ro",
    isa     => "XTracker::Database::PutawayPrep",
    lazy    => 1,
    default => sub { XTracker::Database::PutawayPrep->new() },
);

has prl_name => (
    is      => "ro",
    default => "Full",
);

has location_prl_name => (
    is      => "ro",
    lazy    => 1,
    default => sub { shift->prl_name . " PRL" },
);

has location_row => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->schema->resultset("Public::Location")->find_by_prl(
            $self->prl_name,
        );
    }
);

has channel_name => (
    is      => "ro",
    default => "nap",
);

has channel_row => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        Test::XTracker::Data->channel_for_business(
            name => $self->channel_name,
        );
    }
);

has pid_count => (
    is      => "ro",
    default => 1,
);

has product_type => (
    is      => "ro",
    isa     => subtype( Str => where { /\A(product|voucher)\z/ } ),
    default => "product",
);

# How many variants for each pid
has variant_count => (
    is      => "ro",
    default => 2,
);

has pids => (
    is      => "ro",
    isa     => "ArrayRef",
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $class = ref($self);
        return $class->grab_products(
            $self->channel_name,
            $self->pid_count,
            $self->variant_count,
            $self->product_type,
            force_create => 1,
        );
    }
);

has variant_rows => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return [
            sort { $a->id <=> $b->id }
            map { $_->{product}->variants->search({}, { order_by => "id" }) }
            @{$self->pids},
        ];
    },
);

has purchase_order_row => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $purchase_order_row = Test::XTracker::Data->setup_purchase_order(
            [ map { $_->{pid} } @{$self->pids} ],
            { create_stock_order_items_for_all_variants => 1 },
        );

        # Set up another stock_order_item for the first variant (so we
        # have two StockProcess rows for the same variant)
        my $stock_order = $self->schema->resultset("Public::StockOrder")
            ->search({ purchase_order_id => $purchase_order_row->id })->first;

        my $variant_column = {
            product => "variant_id",
            voucher => "voucher_variant_id",
        }->{ $self->product_type };
        my $stock_order_item = Test::XTracker::Data->create_stock_order_item({
            $variant_column => $self->variant_rows->[0]->id,
            stock_order_id  => $stock_order->id,
        });

        return $purchase_order_row;
    },
);

has stock_process_args => (
    is      => "ro",
    default => sub {
        my $self = shift;
        return {
            status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            type_id   => $STOCK_PROCESS_TYPE__MAIN,
            group_id  => $self->group_id,
        };
    },
);

has stock_process_rows => (
    is      => "ro",
    isa     => "ArrayRef",
    lazy    => 1,
    default => sub {
        my $self = shift;

        my @deliveries = Test::XTracker::Data->create_delivery_for_po(
            $self->purchase_order_row->id,
            "putaway",
        );

        my @stock_process_rows =
            # same order as processed and returned by
            # stock_process_recs
            sort {
                   $a->cached_variant->id <=> $b->cached_variant->id
                || $a->id <=> $b->id
            }
            map {
                # Weirdly need to re-search it from the db, discard_changes doesn't work
                $self->schema->resultset("Public::StockProcess")->find($_->id),
            }
            map {
                Test::XTracker::Data->create_stock_process_for_delivery(
                    $_,
                    $self->stock_process_args,
                );
            } @deliveries;

        return [ @stock_process_rows ];
    },
);

has group_id => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->schema->resultset("Public::StockProcess")->generate_new_group_id
    },
);

has pp_group_row => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->schema->resultset("Public::PutawayPrepGroup")->search({
            group_id => $self->group_id,
        })->first;
    },
);

has pp_container_count => (
    is      => "ro",
    default => 3,
);

has pp_container_rows => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return [
            map { $self->pp_setup->create_pp_container }
            1 .. $self->pp_container_count,
        ];
    },
);

=head1 CLASS METHODS

=cut

sub grab_products {
    my ($class, $channel_name, $pid_count, $variant_count, $product_type) = @_;

    my $product_voucher_args = {
        product => {
            how_many          => $pid_count,
            how_many_variants => $variant_count,
        },
        voucher => {
            phys_vouchers => {
                # Only one variant per Voucher Product, so make sure
                # we crate enough Voucher Products
                how_many => $pid_count * $variant_count,
            },
            how_many => 0,
        },
    }->{ $product_type };

    my ( $channel, $pids ) = Test::XTracker::Data->grab_products({
        channel           => $channel_name,
        force_create      => 1,
        %$product_voucher_args
    });

    return $pids;
}



=head1 METHODS

=cut

sub BUILD {
    my $self = shift;
    note "*** BEGIN Fixture setup " . ref($self);
    $self->stock_process_rows;

    note "*** END Fixture setup " . ref($self);
}

# Don't override, add an "after" modifier to discard more things
sub discard_changes {
    my $self = shift;

    for (
        @{$self->pp_container_rows},
        @{$self->stock_process_rows},
        $self->pp_group_row,
    ) {
        $_->discard_changes() ;
    }

    return $self;
}

sub index_from_human {
    my ($self, $human_index) = @_;
    return $human_index - 1;
}

# Allow descriptive key with embedded, numeric, human-readable,
# 1-based index
# if e.g. "inv_2_sku_55", make index 1
sub index_from_human_key {
    my ($self, $what, $key) = @_;
    $key =~ /(\d+)/
        or confess("No $what index found in ($key). Should be an 1-based index.");
    return $self->index_from_human( $1 );
}

# Convenience StockProcess row accessor
sub sp {
    my ($self, $human_index) = @_;
    return $self->stock_process_rows->[
        $self->index_from_human_key("StockProcess", $human_index),
    ];
}

# Convenience Variant row accessor
sub v {
    my ($self, $human_index) = @_;
    return $self->variant_rows->[
        $self->index_from_human_key("Variant", $human_index),
    ];
}

sub pp_inventory_rows {
    my $self = shift;
    return [
        sort {
            $a->variant_with_voucher_id <=> $b->variant_with_voucher_id
         || $a->id <=> $b->id
        }
        map { $_->putaway_prep_inventories->all }
        @{$self->pp_container_rows}
    ];
}

sub with_variants_added_to_pp_containers {
    my $self = shift;
    my ($v1, $v2)      = @{$self->variant_rows};
    my ($c1, $c2, $c3) = @{$self->pp_container_rows};

    $self->with_variant_added_to_pp_container($v1, $c1);
    $self->with_variant_added_to_pp_container($v1, $c2);
    $self->with_variant_added_to_pp_container($v2, $c3);

    return $self;
}

sub with_variant_added_to_pp_container {
    my ($self, $variant_row, $pp_container_row) = @_;
    my $pp_inventory_row
        = $self->schema->resultset("Public::PutawayPrepContainer")->add_sku({
            container_id => $pp_container_row->container_id,
            sku          => $variant_row->sku,
            putaway_prep => $self->putaway_prep_domain,
            group_id     => $self->group_id,
        });

    return $self;
}

# index is the first number in the string (1 based, to be human
# readable)
sub with_inventory_quantities {
    my ($self, $inventory_index_quantity) = @_;

    my $inventory_rows = $self->pp_inventory_rows;

    for my $key (keys %$inventory_index_quantity) {
        my $quantity = $inventory_index_quantity->{$key};
        my $index = $self->index_from_human_key( "Inventory", $key );

        my $inventory_row = $inventory_rows->[$index]
            or confess("Could not find Inventory[$index]");

        $inventory_row->update({ quantity => $quantity });
    }

    return $self;
}

# index is the first number in the string (1 based, to be human
# readable)
sub with_stock_process_quantities {
    my ($self, $stock_process_index_quantity) = @_;

    my $stock_process_rows = $self->stock_process_rows;

    for my $key (keys %$stock_process_index_quantity) {
        my $quantity = $stock_process_index_quantity->{$key};
        my $index = $self->index_from_human_key( "StockProcess", $key );

        my $stock_process_row = $stock_process_rows->[$index]
            or confess("Could not find StockProcess[$index]");

        $stock_process_row->update({ quantity => $quantity });
    }

    return $self;
}

sub with_containers_in_transit {
    my $self = shift;

    for my $pp_container_row (@{$self->pp_container_rows}) {
        $pp_container_row->update({
            putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT,
            destination            => $self->location_prl_name,
        });
    }

    return $self;
}

sub with_pristine_state {
    my $self = shift;

    # Set initial
    $self->pp_group_row->update({
        status_id => $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
    });
    $_->update({
        putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS,
    }) for @{$self->pp_container_rows};

    $_->update( $self->stock_process_args ) for @{$self->stock_process_rows};

    my $stock_process_rows = [ map { $_->id } @{$self->stock_process_rows} ];
    my $discrepancy_rs = $self->schema->resultset('Public::LogPutawayDiscrepancy');
    $discrepancy_rs->search({
        stock_process_id => $stock_process_rows,
    })->delete();

    $self->discard_changes();

    return $self;
}


