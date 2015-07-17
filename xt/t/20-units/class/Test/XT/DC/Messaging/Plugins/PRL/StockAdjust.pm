package Test::XT::DC::Messaging::Plugins::PRL::StockAdjust;

use NAP::policy "tt", "test", "class";
use FindBin::libs;

BEGIN {
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};

use boolean; # true, false
use MooseX::Params::Validate 'validated_list';
use List::Util 'shuffle';

use Test::XTracker::RunCondition prl_phase => 'prl';
use Test::XTracker::Data;
use Test::XTracker::StockQuantity;
use Test::XTracker::Data::Operator;
use XTracker::Config::Local 'config_var';
use Test::More::Prefix qw/test_prefix/;
use XTracker::Constants qw/:prl_type $APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw/
  :flow_status
  :stock_action
  :storage_type
  :shipment_status
  :shipment_hold_reason
  :putaway_prep_container_status
/;
use Test::XTracker::Artifacts::RAVNI;

sub startup : Test(startup => 1) {
    my $self = shift;

    $self->SUPER::startup;

    $self->{'schema'} = Test::XTracker::Data->get_schema;
    $self->{'stock_quantity'} = Test::XTracker::StockQuantity->new({
        schema => $self->{'schema'}
    });

}

=head2 setup_test_cases

NOTE: All the 'reason' fields come from the PRL's stock_adjust_reason database table.

IMPORTANT WARNING: Some of the test cases are designed to depend upon data set up by the previous test.
They may fail if run in a different order. If you have a better design than this, please implement it.

=cut

sub setup_test_cases {
    my $self = shift;

    my $schema = $self->{'schema'};

    my $prods = Test::XTracker::Data->find_or_create_products({
        how_many => 10,
        dont_ensure_stock => true,
        force_create      => true,
        storage_type_id   => $PRODUCT_STORAGE_TYPE__FLAT,
    });

    my $sample_stock_status = $schema->resultset('Flow::Status')->find(
        $FLOW_STATUS__SAMPLE__STOCK_STATUS
    )->name;

    my $test_operator = Test::XTracker::Data::Operator->create_new_operator();

    $self->{'test_cases'} = [
        {
            product        => $prods->[0],
            start_quantity => 10,
            adjustment     => 1,
            resulting      => 11,
            description    => 'Increment Stock Test'
        },

        {
            product        => $prods->[1],
            start_quantity => 10,
            adjustment     => -1,
            resulting      => 9,
            description    => 'Decrement Stock Test'
        },

        # Check that with update_wms set to false, nothing happens
        {
            product        => $prods->[2],
            start_quantity => 10,
            adjustment     => +1,
            resulting      => 10,
            extra_params   => { update_wms => $PRL_TYPE__BOOLEAN__FALSE },
            no_log         => true,
            description    => 'Do nothing Test (update_wms=false)'
        },

        # These next two work in harmony. Prod 3 has no main stock quantity
        # so this first call should take it to -1. Part two adjusts the
        # `sample` quantity, so main stock should remain at -1.
        {
            product          => $prods->[3],
            starting_quanity => 0,
            adjustment       => -1,
            resulting        => -1,
            description      => "Mixed status - part 1: main stock"
        },
        {
            product      => $prods->[3],
            adjustment   => -1,
            resulting    => -1,
            description  => "Mixed status - part 2: sample stock",
            extra_params => { stock_status => $sample_stock_status }
        },

        # Stop doing random adjustment checking and start testing real scenarios.

        # Simulate a "reconcile no message" reason message. update vms = false and stock_correction = false
        # Ensure this doesn't go into the logs (and ensure resulting quantity same as starting_quantity)
        {
            product          => $prods->[4],
            start_quantity   => 3,
            adjustment       => 6,
            resulting        => 3,
            reason           => 'RECONCILE NO MESSAGE',
            no_log           => true,
            extra_params     => {
                update_wms       => $PRL_TYPE__BOOLEAN__FALSE,
                stock_correction => $PRL_TYPE__BOOLEAN__FALSE
            }
        },

        # These two work in harmony as well
        {
            start_quantity => 3,
            product        => $prods->[5],
            adjustment     => -2,
            resulting      => 1,
            reason         => 'MISSING #1'
        },
        {
            product    => $prods->[5],
            adjustment => +1,
            resulting  => 2,
            reason     => 'FOUND #1'
        },

        {
            start_quantity => 5,
            product        => $prods->[6],
            adjustment     => 1,
            resulting      => 6,
            reason         => 'MISSING #2',
        },
        {
            product    => $prods->[6],
            adjustment => -1,
            resulting  => 5,
            reason     => 'FOUND #2',
        },

        {
            start_quantity => 4,
            product        => $prods->[7],
            adjustment     => -1,
            resulting      => 3,
            reason         => 'MISLABELLED'
        },

        {
            start_quantity => 40,
            product        => $prods->[8],
            adjustment     => -40,
            resulting      => 0,
            reason         => 'ADJ ERROR'
        },

        # A recodes example. ensure the stock ends up in transit
        {
            start_quantity  => 1163,
            product         => $prods->[9],
            adjustment      => -800,
            resulting       => 363,
            reason          => 'STOCK OUT TO XT',
            extra_params    => { stock_correction => $PRL_TYPE__BOOLEAN__FALSE },
            test_transit    => 1
        },

        {
            description    => 'Message includes notes and non-application operator',
            start_quantity => 40,
            product        => $prods->[8],
            adjustment     => -40,
            resulting      => 0,
            reason         => 'MISSING',
            extra_params   => { notes => 'we lost it', user => $test_operator->username },
            operator       => $test_operator,
        },

        {
            description    => 'Message includes empty string for notes',
            start_quantity => 23,
            product        => $prods->[8],
            adjustment     => -23,
            resulting      => 0,
            reason         => 'MISSING',
            extra_params   => { notes => ''},
        },

        {
            description    => 'Message includes 0 for notes',
            start_quantity => 23,
            product        => $prods->[8],
            adjustment     => -23,
            resulting      => 0,
            reason         => 'MISSING',
            extra_params   => { notes => '0'},
        },

        # These two migration stock adjustment tests work together and
        # need to be in this order. This simulates the normal migration
        # sequence where zero or more stock_adjust messages are sent
        # with the 'migrate_container' flag, followed by one with the
        # 'migrate_container' flag.
        {
            description    => 'Migration stock adjustment',
            start_quantity => 5,
            product        => $prods->[7],
            adjustment     => -5,
            resulting      => 0,
            reason         => 'MIGRATION',
            migration      => true,
        },
        {
            description       => 'Last migration stock adjustment',
            start_quantity    => 5,
            product           => $prods->[8],
            adjustment        => -5,
            resulting         => 0,
            reason            => 'MIGRATION',
            migration         => true,
            migrate_container => true,
            extra_params => {
                migration_container_fullness => '.5',
            },
        },
    ];
}

#Entry point for the tests
sub ported_tests : Tests {
    my $self = shift;

    $self->setup_test_cases();
    $self->setup_template();
    $self->setup_transit_locations();

    my @prls = XT::Domain::PRLs::get_all_prls;

    # Test for every PRL
    # TODO: Does it really make sense to test every case for
    # every PRL? Is any of this likely to break for one PRL while
    # working for another? Not really a problem while we only have
    # two PRLs, but worth revisiting when we've got more and it
    # starts taking ages to run.
    foreach my $prl (@prls) {
        test_prefix("Testing PRL: " . $prl->name);
        $self->test_prl($prl);
    }

    test_prefix('');
}

sub test_prl {
    my ($self, $prl) = @_;

    my $schema = $self->{'schema'};

    my $prl_location = $prl->location;

    $schema->resultset('Public::Quantity')->search({
        location_id => $prl_location->id
    })->delete;

    # quick test to ensure the prl will reject a bad sku
    throws_ok {
        $self->send_stock_adjust({
            sku         => '999900999-000',
            adjustment  => -1,
            channel     => 'CHO',
            client      => 'CHO',
            resulting   => 1,
            reason      => 'WHATEVER',
            notes       => 'bad sku',
            prl         => $prl->name,
        })
    } qr/does not have a/, 'Non-existant SKU throws';

    # execute all of our test cases
    my $test_cases = $self->{'test_cases'};

    foreach my $test_case (@$test_cases) {

        $test_case->{'prl'} = $prl->name;
        $test_case->{'prl_name'} = $prl->name;
        $test_case->{'prl_location'} = $prl_location;

        # make a subtest name
        my $description = $test_case->{'description'} || $test_case->{'reason'} || 'testing';
        my $subtest_desc = $description;
        $subtest_desc .= " - variant_id: " . $test_case->{'product'}->{'variant_id'};

        if (defined $ENV{NAP_TEST_CASE} and $ENV{NAP_TEST_CASE} ne $description) {
            note("Skipping test \"$subtest_desc\"");
            next;
        }

        if ($test_case->{migration} && ($prl->name ne 'Full')) {
            note("Skipping MIGRATION test \"$subtest_desc\" for ".$prl->name." PRL");
            next;
        }

        subtest $subtest_desc => sub {
            note("Running test \"$subtest_desc\"");
            $self->run_test_case($test_case);
        };
    }

}

sub run_test_case {
    my ($self, $test_case) = @_;

    my $schema = $self->{'schema'};
    my $q_rs = $schema->resultset('Public::Quantity');
    my $stock_quantity = $self->{'stock_quantity'};

    my $channel    = $test_case->{'product'}->{'product'}->get_product_channel->channel;
    my $variant_id = $test_case->{'product'}->{'variant_id'};
    my $client     = $channel->business->client->prl_name;
    my $start_qty  = $test_case->{'start_quantity'};

    my $description = $test_case->{'description'} || $test_case->{'reason'} || 'testing';

    # starting quantity provided so set the stock level to it.
    if (defined($test_case->{'start_quantity'})) {

        $self->set_start_quantity(
            $variant_id,
            $channel,
            $test_case->{'prl_location'},
            $start_qty,
            $description
        );

    } else {

        $self->note_start_quantity(
            $variant_id,
            $test_case->{'prl_location'}
       );

    }

    # prepare transit location if required, by emptying it
    if (defined $test_case->{'test_transit'}) {
        $self->empty_transit_location($variant_id);
    }

    my $last_log_id = $schema->resultset('Public::LogStock')->count();

    # Construct the message
    my $message = {
        prl        => $test_case->{'prl_name'},
        channel    => $channel,
        client     => $client,
        sku        => $test_case->{'product'}->{'sku'},
        adjustment => $test_case->{'adjustment'},
        reason     => $test_case->{'reason'} || 'testing',
        resulting  => $test_case->{'resulting'}
    };

    $message->{'extra_params'} = $test_case->{'extra_params'}
        if exists($test_case->{'extra_params'});

    # Two attributes that store details that are required across
    # the two migration tests.
    # $self->{test_container_id};
    # $self->{prev_product};

    if ($test_case->{'migration'}) {
        if (!$self->{test_container_id}) {
            ($self->{test_container_id}) = Test::XT::Data::Container
                ->create_new_containers({ how_many => 1 });
        }
        $message->{'extra_params'}->{'migration_container_id'}
            = "$self->{test_container_id}";

        $message->{'extra_params'}->{'migrate_container'} =
            $test_case->{'migrate_container'}
            ? $PRL_TYPE__BOOLEAN__TRUE
            : $PRL_TYPE__BOOLEAN__FALSE;
    }

    if ($test_case->{'migrate_container'}) {
        $message->{'extra_params'}->{'migrate_container'} =
            $PRL_TYPE__BOOLEAN__TRUE;
    }

    my $xt_to_prls;
    if ($test_case->{'migrate_container'}) {
        $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    }

    # Send the message, ensure it doesn't blow up
    lives_ok(
        sub { $self->send_stock_adjust($message) },
        "Test: StockAdjust successfully processed for [$description]",
    );

    # Check the quantity is now what we expect it to be
    is(
        $stock_quantity->get_quantity(
            $variant_id,
            $test_case->{'prl_location'}
        ),
        $test_case->{'resulting'},
        "Quantity properly updated for [$description]"
    );

    # Check this has made its way to the log (if appropriate)
    if (!$test_case->{'no_log'}) {
        $self->test_adjustment_logged(
            $test_case,
            $variant_id,
            $channel->id,
            $description
        );
    } else {
        # test to explicitly ensure it isn't logged!
        my $new_log_id = $schema->resultset('Public::LogStock')->count();
        is($new_log_id, $last_log_id, 'Message not logged');
    }

    if (defined $test_case->{'test_transit'}) {
        $self->ensure_test_products_in_transit(
            $variant_id,
            $test_case->{'adjustment'}
        );
    }

    # Special handling for migration stock_adjust messages
    if (my $container_id =
            $message->{extra_params}->{migration_container_id}) {
        note 'Migration stock_adjust';
        my $pp_container_rs = $schema->resultset(
            'Public::PutawayPrepContainer'
        );
        my ($pp_container) = $pp_container_rs->search({
            container_id => $container_id,
        });
        ok($pp_container, 'Got a PP Container');

        # Count quantity of sku
        my $count =
            $pp_container->get_count_of_sku($test_case->{product}->{sku});
        is($count, -$test_case->{adjustment},
           'Correct quantity of sku in PP container');

        if ($test_case->{migrate_container}) {
            note "Expecting an advice message";
            $xt_to_prls->expect_messages({ messages => [{
                '@type'      => 'advice',
                details      => {
                    container_id       => $container_id,
                    container_fullness => $test_case->{extra_params}{migration_container_fullness},
                    compartments       => [ {
                        inventory_details => [ {
                            quantity   => $self->{prev_product}->{count},
                            sku        => $self->{prev_product}->{sku},
                        }, {
                            quantity   => $count,
                            sku        => $test_case->{product}->{sku},
                        } ],
                    } ],
                }
            }] });

            is($pp_container->putaway_prep_status_id,
               $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT,
               'PP Container is now marked as in transit');

            # If this is a migrate_container message then unset $container_id
            # so we get a new container next time
            $self->{test_container_id} = undef;
        }
        else { # if migrate_container
            is(
                $pp_container->putaway_prep_status_id,
                $PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS,
                'PP Container is in progress',
            );

            $self->{prev_product}->{sku}   = $test_case->{product}->{sku};
            $self->{prev_product}->{count} = $count;
        }
    }
}

=head2 test_on_hold_shipments

Each test case should stand on its own, i.e. not be dependent on any
other case. To enforce this in order to flush out dependency bugs early,
test cases will be executed in a random order below.
To only run a single test case, set the environment variable NAP_TEST_CASE
to the description of the case, e.g.

    NAP_TEST_CASE="failed_allocation" prove StockAdjust.pm

Migration logic:

    1. Setup: Create a shipment with storage type 'Dematic_Flat' ready for migration
    2. Setup: Try to allocate the shipment to Dematic, it should fail and be put on hold,
              because the stock has yet to be migrated from the Full PRL
    3. Setup: 'Migrate' the stock and send a StockAdjust taking the total to zero
    4. Test: The shipment should be taken off hold and re-allocated to Dematic

=cut

# Another entry point for the tests
sub test_on_hold_shipments :Tests {
    my ($self) = @_;

    $self->setup_template;

    # Do not re-use products in different tests
    my $product_data_list = Test::XTracker::Data->find_or_create_products({
        how_many => 2,
        dont_ensure_stock => true,
        force_create      => true,
        storage_type_id   => $PRODUCT_STORAGE_TYPE__FLAT,
    });

    # NOTE: test cases will be executed in a random order.
    my @test_cases = (
    {
        description    => 'failed_allocation',
        start_quantity => 1001, # Creating a shipment results in this quantity
        product        => $product_data_list->[0],
        adjustment     => -1001,
        resulting      => 0,
        reason         => 'MISSING',

        put_on_hold    => sub {
            my ($shipment) = @_;
            note("Putting shipment ".$shipment->id." on normal hold with reason: Failed Allocation");
            $shipment->set_status_hold(
                $APPLICATION_OPERATOR_ID,
                $SHIPMENT_HOLD_REASON__FAILED_ALLOCATION,
                "Putting on hold for a test"
            );
            ok($shipment->is_on_hold, "Setup: Shipment is on hold");
            is($shipment->shipment_status_id, $SHIPMENT_STATUS__HOLD,
                "Setup: Shipment status is on hold for correct reason");
            ok($shipment->is_on_hold_for_reason($SHIPMENT_HOLD_REASON__FAILED_ALLOCATION),
                "Setup: Shipment is registered in the shipment hold table for correct reason");
        },
        take_off_hold => true,
    },
    {
        description    => 'finance_hold',
        start_quantity => 1001, # Creating a shipment results in this quantity
        product        => $product_data_list->[0],
        adjustment     => -1001,
        resulting      => 0,
        reason         => 'MISSING',

        put_on_hold    => sub {
            my ($shipment) = @_;
            note("Putting shipment ".$shipment->id." on Finance Hold");
            $shipment->set_status_finance_hold(
                $APPLICATION_OPERATOR_ID,
            );
            ok($shipment->is_on_hold, "Setup: Shipment is on hold");
            is($shipment->shipment_status_id, $SHIPMENT_STATUS__FINANCE_HOLD,
                "Setup: Shipment status is on hold for correct reason");
        },
        take_off_hold => false,
    },
    ); # @test_cases

    foreach my $test_case (shuffle @test_cases) {
        $self->run_hold_test_case($test_case);
    }
}

sub run_hold_test_case {
    my ($self, $test_case) = @_;

    # Make a subtest name
    my $description = $test_case->{'description'} || $test_case->{'reason'} || 'testing';
    my $subtest_desc = $description;
    $subtest_desc .= " - variant_id: " . $test_case->{'product'}->{'variant_id'};

    # Allow user to run test cases on their own
    if (defined $ENV{NAP_TEST_CASE} and $ENV{NAP_TEST_CASE} ne $description) {
        note("Skipping test \"$subtest_desc\"");
        return;
    }

    my $schema = $self->{'schema'};
    my $stock_quantity = $self->{'stock_quantity'};

    my $channel    = $test_case->{'product'}->{'product'}->get_product_channel->channel;
    my $variant_id = $test_case->{'product'}->{'variant_id'};
    my $client     = $channel->business->client->prl_name;
    my $start_qty  = $test_case->{'start_quantity'};

    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

    note("Set up a shipment, so we can test if it gets reallocated and taken off hold");
    $test_case->{shipment} = $self->create_shipment($test_case->{product});

    note("Change storage_type to Dematic_Flat, in preparation for migration");
    $test_case->{product}->{product}->storage_type_id($PRODUCT_STORAGE_TYPE__DEMATIC_FLAT);
    is($test_case->{product}->{product}->storage_type_id, $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
        "Product ".$test_case->{product}->{product}->id."'s storage type has been changed to Dematic_Flat");

    # TODO: Hard-coded PRL name
    my $prl_location = XT::Domain::PRLs::get_location_from_prl_name({
        prl_name => 'Full',
    });

    $self->set_start_quantity(
        $variant_id,
        $channel,
        $prl_location,
        $start_qty,
        $description
    );

    # Run code to put shipment on hold
    $test_case->{put_on_hold}->($test_case->{shipment});

    note("*** Imagine operator performs migration at the Full PRL ***");

    # Construct the StockAdjust message
    # TODO: Hard-coded PRL name
    my $message = {
        prl        => 'Full',
        channel    => $channel,
        client     => $client,
        sku        => $test_case->{'product'}->{'sku'},
        adjustment => $test_case->{'adjustment'},
        reason     => $test_case->{'reason'} || 'testing',
        resulting  => $test_case->{'resulting'}
    };

    # Send the message, ensure it doesn't blow up
    lives_ok(
        sub { $self->send_stock_adjust($message) },
        "Test: StockAdjust successfully processed for [$description]",
    );

    $test_case->{shipment}->discard_changes; # reload from database

    if ($test_case->{take_off_hold}) {
        ok(! $test_case->{shipment}->is_on_hold, "Setup: Shipment has been taken off hold");

        note "Expecting an allocate message, allocating stock to Dematic PRL";
        $xt_to_prls->expect_messages({ messages => [{
            '@type' => 'allocate',
        }] });
    } else {
        ok($test_case->{shipment}->is_on_hold, "Setup: Shipment remains on hold");
        $xt_to_prls->expect_no_messages;
    }
}


sub set_start_quantity {
    my ($self, $variant_id, $channel, $prl_location, $start_qty, $description) = @_;

    my $schema = $self->{'schema'};
    my $q_rs = $schema->resultset('Public::Quantity');
    my $stock_quantity = $self->{'stock_quantity'};

    $q_rs->search({
        variant_id => $variant_id,
        channel_id => $channel->id
    })->delete;

    $q_rs->create({
        location_id => $prl_location->id,
        variant_id  => $variant_id,
        quantity    => $start_qty,
        channel_id  => $channel->id,
        status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    });

    # sanity check.. that setting the starting quantity was successful
    is(
        $stock_quantity->get_quantity(
            $variant_id,
            $prl_location,
        ),
        $start_qty,
        "Quantity properly initialised for [$description] (quantity = $start_qty)"
    );
}

sub note_start_quantity {
    my ($self, $variant_id, $prl_location) = @_;

    my $schema = $self->{'schema'};
    my $stock_quantity = $self->{'stock_quantity'};

    my $quant = $stock_quantity->get_quantity(
        $variant_id,
        $prl_location,
    );

    note("starting_quantity not set. value in database: $quant\n");

}

sub create_shipment {
    my ($self, $product) = @_;

    my $order_factory = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ]
    );
    my $shipment = $order_factory->new_order(
        products      => [$product],
        dont_allocate => true,
    )->{order_object}->get_standard_class_shipment;

    return $shipment;
}

sub test_adjustment_logged {
    my ($self, $test_case, $variant_id, $channel_id, $description) = @_;

    my $schema = $self->{'schema'};
    my $stock_quantity = $self->{'stock_quantity'};
    my $variant = $schema->resultset('Public::Variant')->find($variant_id);

    my $log_row = $stock_quantity->check_stock_log(
            $variant_id,
            $test_case->{'adjustment'}
    );
    ok($log_row, "Quantity changed has been logged for [$description]");
    is($log_row->balance, $variant->current_stock_on_channel($channel_id),
        "Balance logged is correct");
    if ($test_case->{'operator'}) {
        is ($log_row->operator_id, $test_case->{'operator'}->id,
            "Log contains correct operator id");
    }
    my $expected_log_notes = $test_case->{'reason'} || 'testing';
    if ($test_case->{'extra_params'} && length $test_case->{'extra_params'}->{'notes'}) {
        $expected_log_notes .= " - ".$test_case->{'extra_params'}->{'notes'};
    }
    is($log_row->notes, $expected_log_notes,
        "Log contains correct notes");
}

sub empty_transit_location {
    my ($self, $variant_id) = @_;

    my $schema = $self->{'schema'};
    my $q_rs = $schema->resultset('Public::Quantity');

    $q_rs->search({
        location_id => $self->{'transit_location'}->id,
        variant_id  => $variant_id
    })->delete;

}

sub ensure_test_products_in_transit {
    my ($self, $variant_id, $adjustment) = @_; # provide original adjustment.

    my $schema = $self->{'schema'};
    my $stock_quantity = $self->{'stock_quantity'};

    is(
        $stock_quantity->get_quantity(
            $variant_id,
            $self->{'transit_location'},
            $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS
        ),
        -$adjustment,
        'Quantity was sucessfully checked into the transit location'
    );

}

sub send_stock_adjust {
    my ($self, $args) = @_;

    my $prl = XT::Domain::PRLs::get_prl_from_name({
        prl_name => $args->{prl},
    });

    my $new_args = {
        'total_quantity' => $args->{'resulting'},
        'client'         => $args->{'client'},
        'sku'            => $args->{'sku'},
        'delta_quantity' => $args->{'adjustment'},
        'reason'         => $args->{'reason'},
        'prl'            => $prl->amq_identifier,
    };

    # merge extra params in if there are any into our message
    if ($args->{'extra_params'}) {
        my $ep = $args->{'extra_params'};
        $new_args = { %$new_args, %$ep };
    }

    # merge our message with the template
    my $template = $self->{'template'};
    my $message = $template->( $new_args );

    note("Sending a StockAdjust message:". Data::Printer::p($message));

    $self->send_message( $message );
};

sub setup_template {
    my $self = shift;

    my $schema = $self->{'schema'};

    my $stock_status = $schema->resultset('Flow::Status')->find(
        $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
    )->name;

    # undefs filled in, in send_stock_adjust function where template is copied
    $self->{'template'} = $self->message_template(
        StockAdjust => {
            total_quantity   => undef,
            client           => undef,
            prl              => undef,
            stock_status     => $stock_status,
            stock_correction => $PRL_TYPE__BOOLEAN__TRUE,
            reason           => 'testing',
            date_time_stamp  => '2012-04-02T13:24:00+0000',
            update_wms       => $PRL_TYPE__BOOLEAN__TRUE
        }
    );
}

sub setup_transit_locations {
    my $self = shift;

    my $schema = $self->{'schema'};

    my $transit_location = $schema->resultset('Public::Location')->search({
        'location' => 'Transit',
    })->single();

    ok($transit_location, "Transit location exists");
    $self->{'transit_location'} = $transit_location;

    my $allowed = $schema->resultset('Public::LocationAllowedStatus')->search({
        'location_id' => $transit_location->id,
        'status_id' => $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS,
    })->count();

    is ($allowed, 1, "Transit location allows 'In Transit From PRL' status");
    $self->{'transit_location_allows_status'} = $allowed;

}

1;
