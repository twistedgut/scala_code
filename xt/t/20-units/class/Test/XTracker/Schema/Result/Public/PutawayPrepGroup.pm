package Test::XTracker::Schema::Result::Public::PutawayPrepGroup;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { extends "NAP::Test::Class" };
use Test::XTracker::RunCondition prl_phase => 'prl';

=head1 DESCRIPTION

Test PutawayPrepGroup->stock_process_recs and, using the same
scenarios, PutawayPrepContainer->advice_response_success.

=cut

use Carp qw/ confess /;
use List::Util qw/ sum /;

use Test::More::Prefix qw/ test_prefix /;

use Test::XT::Data::PutawayPrep;
use Test::XT::Fixture::PutawayPrep::StockProcess::Group;
use XTracker::Role::WithAMQMessageFactory;

use XTracker::Constants::FromDB qw(
    :putaway_prep_container_status
    :putaway_prep_group_status
    :delivery_action
);

sub startup :Test(startup) {
    my ($test) = @_;
    $test->SUPER::startup();
    $test->{setup} = Test::XT::Data::PutawayPrep->new;
}

BEGIN {

has product_type_fixture => (
    is      => "ro",
    default => sub { +{} },
);

# Keep track of previous quantity level for the key (variant +
# location)
has key_quantity => (
    is      => "ro",
    default => sub { +{ } },
);

}

sub fixture {
    my ($self, $product_type) = @_;
    my $fixture = $self->product_type_fixture->{ $product_type }
        //= Test::XT::Fixture::PutawayPrep::StockProcess::Group
            ->new({ product_type => $product_type })
            ->with_variants_added_to_pp_containers()
            ->with_containers_in_transit();

    return $fixture->with_pristine_state();
}

sub variants :Tests {
    my ($test) = @_;

    foreach my $config (
        {
            test_type           => 'stock process',
            group_id_field_name => 'pgid',
        },
        {
            test_type           => 'voucher',
            group_id_field_name => 'pgid',
            voucher             => 1,
        },
        {
            test_type           => 'stock recode',
            group_id_field_name => 'recode_id',
            recode              => 1,
        },
        {
            test_type           => 'return',
            group_id_field_name => 'pgid',
            return              => 1,
        },
    ) {
        note("set up ".$config->{test_type});

        my $group_type = $config->{recode}
            ? XTracker::Database::PutawayPrep::RecodeBased->name
            : $config->{migration}
            ? XTracker::Database::PutawayPrep::MigrationGroup->name
            : XTracker::Database::PutawayPrep->name;

        # setup
        my ($stock_process, $product_data)
            = $test->{setup}->create_product_and_stock_process( 1, {
                group_type => $group_type,
                voucher    => $config->{voucher},
                return     => $config->{return},
            });
        my $group_id = $product_data->{ $config->{group_id_field_name} };
        my $sku = $product_data->{sku};
        my $pp_group = $test->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $group_type,
        });

        # test
        if (!$config->{recode}) {
            if ($config->{return}) {
                ok(
                    $stock_process->is_returns,
                    "$config->{test_type} stock process is returns",
                );
                isa_ok(
                    $stock_process->return_item,
                    'XTracker::Schema::Result::Public::ReturnItem',
                );
                my @return_items = $pp_group->get_return_items;
                is(@return_items, 1, 'pp group has one return item');
                isa_ok($return_items[0],
                       'XTracker::Schema::Result::Public::ReturnItem');
            } else {
                ok(!$stock_process->is_returns,
                   "$config->{test_type} stock process is not returns");
                my @return_items = $pp_group->get_return_items;
                is(@return_items, 0, 'pp group has no return items');
            }
        }

        my $variants = $pp_group->variants;
        if ($config->{voucher}) {
            isa_ok( $variants->[0], 'XTracker::Schema::Result::Voucher::Variant' );
        }
        else {
            # includes recodes
            isa_ok( $variants->[0], 'XTracker::Schema::Result::Public::Variant' );
        }
    }
}

sub variant_total_inventory_quantity : Tests() {
    my $self = shift;

    my $fixture = $self->fixture("product");
    $fixture->with_inventory_quantities({
        inv_1_v1 => 10,
        inv_2_v1 => 11,
        inv_3_v2 => 12,
    });

    my ($variant_1, $variant_2) = @{$fixture->variant_rows};
    my $pp_group_row = $fixture->pp_group_row;
    eq_or_diff(
        [ $pp_group_row->variant_total_inventory_quantity ],
        [
            {
                $variant_1->id => 21, # 10 + 11
                $variant_2->id => 12,
            },
        ],
        "variant_total_inventory_quantity sums quantities per variant",
    );
}

sub test_scenario {
    my ($self, $case) = @_;

    for my $product_type ("product", "voucher") {
        $self->test__stock_process_recs( $case, $product_type );
    }

    $self->test_advice_response_success( $case );
}

sub test__stock_process_recs {
    my ($self, $case, $product_type) = @_;
    note "\n\n\n*** test__stock_process_recs in $product_type mode";
    test_prefix( "$case->{prefix} - " . $product_type );

    my $fixture = $self->fixture( $product_type );

    $fixture->with_inventory_quantities(
        $case->{inventory_quantities},
    );
    $fixture->with_stock_process_quantities(
        $case->{stock_process_quantities},
    );

    my ($variant_1, $variant_2) = @{$fixture->variant_rows};
    my $pp_group_row = $fixture->pp_group_row;
    my $expected_stock_process_recs = $case->{stock_process_recs};
    my $stock_process_recs = $pp_group_row->stock_process_recs({
        location_row => $fixture->location_row,
    });
    eq_or_diff(
        [
            map {
                +{
                    id           => $_->{id},
                    variant_id   => $_->{variant_id},
                    quantity     => $_->{quantity},
                    ext_quantity => $_->{ext_quantity},
                };
            }
            @$stock_process_recs,
        ],
        [
            {
                id           => $fixture->sp(1)->id,
                variant_id   => $fixture->v(1)->id,
                quantity     => $expected_stock_process_recs->[0]->{quantity},
                ext_quantity => $expected_stock_process_recs->[0]->{ext_quantity},
            },
            {
                id           => $fixture->sp(2)->id,
                variant_id   => $fixture->v(1)->id,
                quantity     => $expected_stock_process_recs->[1]->{quantity},
                ext_quantity => $expected_stock_process_recs->[1]->{ext_quantity},
            },
            {
                id           => $fixture->sp(3)->id,
                variant_id   => $fixture->v(2)->id,
                quantity     => $expected_stock_process_recs->[2]->{quantity},
                ext_quantity => $expected_stock_process_recs->[2]->{ext_quantity},
            },
        ],
        $case->{description},
    );

    my $total_stock_process_rec_quantity = sum(
        map { $_->{ext_quantity} } @$stock_process_recs,
    );
    my $total_inventory_quantity
        = $pp_group_row->putaway_prep_inventories->get_column("quantity")->sum();
    is(
        $total_inventory_quantity,
        $total_stock_process_rec_quantity,
        "Total Inventory quantity ($total_inventory_quantity) and
         total stock_process_recs quantity ($total_stock_process_rec_quantity)
         are the same which means all the quantities were allocated
         correctly",
    );

}

sub test_advice_response_success {
    my ($self, $case) = @_;
    note "\n\n\n*** test_advice_response_success";
    test_prefix( "$case->{prefix}" );

    my $fixture = $self->fixture( "product" );
    $fixture->with_inventory_quantities(
        $case->{inventory_quantities},
    );
    $fixture->with_stock_process_quantities(
        $case->{stock_process_quantities},
    );
    my $pp_group_row = $fixture->pp_group_row;
    my $location_row = $fixture->location_row;

    # Note the existing quantities
    for my $variant_row (@{$fixture->variant_rows}) {
        $self->test_extra_quantity( $variant_row, $location_row );
    }

    note "There are three PP Containers";
    my ($c1, $c2, $c3) = @{$fixture->pp_container_rows};

    note "Complete the two first, the Group should not be completed yet";
    my $message_factory = XTracker::Role::WithAMQMessageFactory->build_msg_factory;
    for my $pp_container_row ($c1, $c2) {
        $pp_container_row->advice_response_success($message_factory);

        $pp_container_row->discard_changes();
        is(
            $pp_container_row->putaway_prep_status_id,
            $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
            "Container is COMPLETE",
        );

        $pp_group_row->discard_changes();
        is(
            $pp_group_row->status_id,
            $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
            "Group is still IN_PROGRESS",
        );
    }

    note "Test discrepancies";
    for my $stock_process_row (@{$fixture->stock_process_rows}) {
        $self->test_discrepancies(
            "Group not yet completed",
            $stock_process_row,
            0,
        );
    }


    note "Complete final Container";
    my $pp_container_row = $c3;
    $pp_container_row->advice_response_success($message_factory);

    $pp_container_row->discard_changes();
    is(
        $pp_container_row->putaway_prep_status_id,
        $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
        "Container is COMPLETE",
    );

    $pp_group_row->discard_changes();
    is(
        $pp_group_row->status_id,
        $case->{group_status_id},
        "Group is completed (COMPLETED | PROBLEM)",
    );

    note "Test quantities";
    my $putaway_quantity = $case->{putaway_quantity};
    for my $variant_index (keys %$putaway_quantity) {
        my $variant_row = $fixture->v($variant_index);
        my $expected_quantity = $putaway_quantity->{ $variant_index };
        $self->test_extra_quantity(
            $variant_row,
            $location_row,
            $expected_quantity,
        );
    }

    note "Test discrepancies";
    my $discrepancy_count = $case->{discrepancy_count};
    for my $stock_process_index (sort keys %$discrepancy_count) {
        my $expected_count = $discrepancy_count->{ $stock_process_index };

        my $stock_process_row = $fixture->sp($stock_process_index);
        $self->test_discrepancies(
            "Group maybe completed",
            $stock_process_row,
            $expected_count,
        );
    }


    test_prefix("");
}

sub scenario__matches : Tests() {
    my $self = shift;

    $self->test_scenario({
        prefix      => "happy",
        description => "Happy Path, no discrepancies",
        # v1 total quantity = 21 = (inv) 10 + 11 = (sp) 6 + 15
        # v1 total quantity = 12
        stock_process_quantities => {
            sp_1_v1 => 6,
            sp_2_v1 => 15,
            sp_3_v2 => 12,
        },
        inventory_quantities => {
            inv_1_v1 => 10,
            inv_2_v1 => 11,
            inv_3_v2 => 12,
        },
        stock_process_recs => [
            {
                quantity     => 6,
                ext_quantity => 6,
            },
            {
                quantity     => 15,
                ext_quantity => 15,
            },
            {
                quantity     => 12,
                ext_quantity => 12,
            },
        ],
        group_status_id   => $PUTAWAY_PREP_GROUP_STATUS__COMPLETED,
        discrepancy_count => {
            sp_1_v1 => 0,
            sp_2_v1 => 0,
            sp_3_v2 => 0,
        },
        putaway_quantity => {
            v1 => 21,
            v2 => 12,
        },
    });

}

sub scenario__surplus : Tests() {
    my $self = shift;

    # Surplus for both variants
    #   extra quantity for the last   sp for variant 1 (== inv 2)
    #   extra quantity for the single sp for variant 2 (== inv 3)
    $self->test_scenario({
        prefix      => "surplus",
        description => "Surplus both variants",
        # v1 total quantity = 28 = (inv) 17 + 11 <--vs--> (sp) 6 + 15 = 21
        #    surplus on the last stock_process_rec: 28 - 21 = 7
        # v2 total quantity = (inv) 16 <--vs--> (sp) 12
        #    surplus on the single stock_process_rec: 16 - 12 = 4
        stock_process_quantities => {
            sp_1_v1 => 6,
            sp_2_v1 => 15,
            sp_3_v2 => 12,
        },
        inventory_quantities => {
            inv_1_v1 => 17,
            inv_2_v1 => 11,
            inv_3_v2 => 16,
        },
        stock_process_recs => [
            {
                # these stays the same, it's fulfilled by the extra ones
                quantity     => 6,
                ext_quantity => 6,
            },
            {
                quantity     => 15,
                ext_quantity => 22, # 15 + 7
            },
            {
                quantity     => 12,
                ext_quantity => 16, # 12 + 4
            },
        ],
        group_status_id   => $PUTAWAY_PREP_GROUP_STATUS__PROBLEM,
        discrepancy_count => {
            sp_1_v1 => 0,
            sp_2_v1 => 1,
            sp_3_v2 => 1,
        },
        putaway_quantity => {
            v1 => 28,
            v2 => 16,
        },
    });
}

sub scenario__deficit : Tests() {
    my $self = shift;

    # Deficit for both variants
    #   reduced quantity for the last   sp for variant 1 (== inv 2)
    #   reduced quantity for the single sp for variant 2 (== inv 3)
    $self->test_scenario({
        prefix      => "deficit",
        description => "Decifict both variants",
        # v1 total quantity = 18 = (inv) 7 + 11 <--vs--> (sp) 6 + 15 = 21
        #    deficit on the last stock_process_rec: 18 - 21 = -3
        # v2 total quantity = (inv) 6 <--vs--> (sp) 12
        #    deficit on the single stock_process_rec: 6 - 12 = -6
        stock_process_quantities => {
            sp_1_v1 => 6,
            sp_2_v1 => 15,
            sp_3_v2 => 12,
        },
        inventory_quantities => {
            inv_1_v1 => 7,
            inv_2_v1 => 11,
            inv_3_v2 => 6,
        },
        stock_process_recs => [
            {
                # these stays the same, it's fulfilled by the extra ones
                quantity     => 6,
                ext_quantity => 6,
            },
            {
                quantity     => 15,
                ext_quantity => 12, # 21 - 6 - 3
            },
            {
                quantity     => 12,
                ext_quantity => 6, # 12 - 6
            },
        ],
        # Since all variants aren't scanned yet, the group won't be
        # completed... and nothing is putaway yet
        group_status_id   => $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
        discrepancy_count => {
            sp_1_v1 => 0,
            sp_2_v1 => 0,
            sp_3_v2 => 0,
        },
        putaway_quantity => {
            v1 => 0,
            v2 => 0,
        },
    });
}

sub scenario__huge_deficit : Tests() {
    my $self = shift;

    # Huge deficit for both variants (1 actual scanned)
    #   reduced quantity for all        sp for variant 1 (== inv 1, 2)
    #   reduced quantity for the single sp for variant 2 (== inv 3)
    $self->test_scenario({
        prefix      => "huge deficit",
        description => "Huge deficit both variants",
        # v1 total quantity = 0 = (inv) 0 <--vs--> (sp) 6 + 15 = 21
        # v1 total quantity = (inv) 0 <--vs--> (sp) 12
        stock_process_quantities => {
            sp_1_v1 => 6,
            sp_2_v1 => 15,
            sp_3_v2 => 12,
        },
        inventory_quantities => {
            inv_1_v1 => 1,
            inv_2_v1 => 1,
            inv_3_v2 => 1,
        },
        stock_process_recs => [
            {
                quantity     => 6,
                ext_quantity => 2,
            },
            {
                quantity     => 15,
                ext_quantity => 0,
            },
            {
                quantity     => 12,
                ext_quantity => 1,
            },
        ],
        # Since all variants aren't scanned yet, the group won't be
        # completed... and nothing is putaway yet
        group_status_id   => $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
        discrepancy_count => {
            sp_1_v1 => 0,
            sp_2_v1 => 0,
            sp_3_v2 => 0,
        },
        putaway_quantity => {
            v1 => 0,
            v2 => 0,
        },
    });
}

sub check_that_quantity_per_sku_are_used_for_putaway : Tests() {
    my $self = shift;

    $self->test_scenario({
        prefix      => "qty_per_sku",
        description => "When deciding whether to complete putaway - use SKU based quantities",
        stock_process_quantities => {
            sp_1_v1 => 6,
            sp_2_v1 => 15,
            sp_3_v2 => 12,
        },
        # pretend that we scanned one extra SKU_1, but less by one of SKU_2
        inventory_quantities => {
            inv_1_v1 => 6,
            inv_2_v1 => 14, # -1
            inv_3_v2 => 13, # +1
        },
        stock_process_recs => [
            {
                quantity     => 6,
                ext_quantity => 6,
            },
            {
                quantity     => 15, # -1
                ext_quantity => 14,
            },
            {
                quantity     => 12, # +1
                ext_quantity => 13,
            },
        ],
        # even though total expected quantity matches total scanned quantity:
        # 6 + 15 + 12 = 6 + 14 + 13 = 33
        # putaway was not completed because SKU_1 was scanned less then expected:
        # expected 6 + 15 = 21, but scanned 6 + 14 = 20
        group_status_id   => $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
        # hence no discrepancy recorded
        discrepancy_count => {
            sp_1_v1 => 0,
            sp_2_v1 => 0,
            sp_3_v2 => 0,
        },
        putaway_quantity => {
            v1 => 0,
            v2 => 0,
        },
    });
}

sub test_discrepancies {
    my ($self, $description, $stock_process_row, $expected_discrepancy_count) = @_;

    note "Discrepancies: $description";

    my $discrepancy_rs = $self->schema->resultset('Public::LogPutawayDiscrepancy');
    my $discrepancy_count = $discrepancy_rs->search({
        stock_process_id => $stock_process_row->id,
    })->count;

    is(
        $discrepancy_count,
        $expected_discrepancy_count,
        "$expected_discrepancy_count expected discrepancies for the StockProcess (" . $stock_process_row->id . ")",
    );
}

sub test_extra_quantity {
    my ($self, $variant_row, $location_row, $expected_extra_quantity) = @_;

    my $key = join("\t", $location_row->id, $variant_row->id);
    my $previous_quantity = $self->key_quantity->{ $key } // 0;

    my $quantity_rs = $self->schema->resultset('Public::Quantity');
    my $quantity = $quantity_rs->search({
        location_id => $location_row->id,
        variant_id  => $variant_row->id,
    })->get_column("quantity")->sum() || 0;

    my $actual_extra_quantity = $quantity - $previous_quantity;
    $self->key_quantity->{ $key } = $quantity;

    defined($expected_extra_quantity) or return;

    is(
        $actual_extra_quantity,
        $expected_extra_quantity,
        "$expected_extra_quantity expected extra quantity for Variant (" . $variant_row->id . "), Location (" . $location_row->id . ")",
    );
}

# For more details why this test exists refer to DCA-2576 jira ticket.
#
sub check_that_multiple_items_in_pp_container_does_not_cause_multiple_putaways :Tests {
    my $self = shift;

    note 'Get fixture with all stock in one container';
    my $fixture = Test::XT::Fixture::PutawayPrep::StockProcess::Group
        ->new({
            product_type => 'product',
            pp_container_count => 1,
        });

    note 'Make sure that all stock is scanned into one container';
    $fixture->with_variant_added_to_pp_container($_, $fixture->pp_container_rows->[0])
        for @{$fixture->variant_rows};

    note 'Make sure that we have three stock_process records where one of them has quantity zero';
    note '(it is possible to get zero quantity stock_process records due to weirdnesses in Goods In process)';
    $fixture->with_stock_process_quantities(
        {
            sp_1_v1 => 0,
            sp_2_v1 => 21,
            sp_3_v2 => 12,
        }
    );

    note 'Updated scanned containers to have expected quantities scanned';
    $fixture->with_inventory_quantities(
        {
            inv_1_v1 => 21,
            inv_2_v2 => 12,
        },
    );

    note 'Pretend that advice was sent';
    $fixture->with_containers_in_transit;


    note 'Pretend that advice response was sent back';
    my $message_factory = XTracker::Role::WithAMQMessageFactory->build_msg_factory;
    $fixture->pp_container_rows->[0]->advice_response_success($message_factory);

    is(
        scalar(
            grep { $_->delivery_action_id eq $DELIVERY_ACTION__PUTAWAY }
            $fixture->pp_group_row->delivery->log_deliveries
        ),
        1,
        'There should be one delivery log entry for Putaway'
    );
}
