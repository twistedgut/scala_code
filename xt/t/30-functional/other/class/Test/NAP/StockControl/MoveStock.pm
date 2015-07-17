package Test::NAP::StockControl::MoveStock;

use NAP::policy "tt", 'test';

=head1 NAME

Test::NAP::StockControl::MoveStock

=head1 DESCRIPTION

Verify that moving an item into a location from a more liberal location
doesn't fail.

=head2 PURPOSE

To check that the Move/Add Stock routine, invoked via:

    /StockControl/Inventory/MoveAddStock
        and
    /StockControl/Inventory/SetStockLocation

...actually do the stock move requested

#TAGS checkruncondition iws inventory

=head1 METHODS

=cut

use FindBin::libs;
use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 ) ];

use Test::XT::Flow;
use Test::XT::Data::Location;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :flow_status
);
use XTracker::Config::Local qw( iws_location_name config_var );
use XTracker::Database qw(:common);
use Test::XTracker::Data;
use Test::Differences;

use parent 'NAP::Test::Class';

sub startup : Tests(startup) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::StockControl',
            'Test::XT::Data::Location',
            'Test::XT::Data::Quantity',
        ],
    );
    $self->{framework}->data__location__destroy_test_locations;
}

sub setup : Test(setup=>2) {
    my ( $self ) = @_;

    $self->SUPER::setup;

    $self->{framework}->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Stock Control/Inventory'
        ]}
    });

    @{$self}{qw/channel pids/} = Test::XTracker::Data->grab_products({
        how_many => 1,
        force_create => 1,
    });
    $self->{variant} = $self->{pids}[0];
}

# Destroy the created test locations after each run
sub teardown : Tests(teardown) {
    my ( $self ) = @_;
    #$self->{framework}->data__location__destroy_test_locations;
    $self->SUPER::teardown;
}

=head2 test_move_main_stock

=head3 Part One

We create a test location that can accommodate main stock.

We create a test variant in that location, and make sure it
has enough stock.

We attempt to move some of that stock to the IWS location,
and make sure that fails.

Then we create a second test location that can
receive stock of *any* kind, and move an amount of the
test variant to the new location, leaving some of
the stock in the old location.

This confirms that we can move stock from an existing
location to a more liberal location, which was the original
JIRA ticket problem. It also, co-incidentally, tests that
we can move stock to an empty location.

=head3 Part Two

We then test moving a further amount of stock from
the original location to the test location, to confirm
that we can move stock to a location that already
contains some of that stock.

=head3 Part Three

Finally, we move all the stock from the test location
back to the original location, to confirm we can
move to a more restrictive location that will happen
accommodate the flow.status of stock being moved.

At each stage, we read the status of the stock levels
as reported in the MoveAddStock page, to confirm that
the move has happened, as well as checking that no
errors have been reported on the page.

=cut

sub test_move_main_stock : Tests {
    my ( $self ) = @_;

    my $framework = $self->{framework};
    my $variant = $self->{variant};
    my $channel = $self->{channel};

    # We expect the product variant to have 'Main Stock' status...
    my ( $src_location_name, $dst_location_name )
        = $self->create_locations($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS);

    note "Adding stock for SKU $variant->{sku} to source location $src_location_name";

    my $original_stock_level = 50;
    $framework->data__quantity__insert_quantity({ quantity => $original_stock_level,
                                                location_name => $src_location_name,
                                                variant_id => $variant->{variant_id},
                                                channel_id => $channel->id });

    $framework->flow_mech__stockcontrol__inventory_moveaddstock($variant->{variant_id});
    my ($stock_location)=grep { $_->{SKU}->{value} eq $variant->{sku}
                                && $_->{Location} ne '-' && $_->{Location}->{value} eq $src_location_name }
                            @{$framework->mech->as_data->{stock_by_location}->{$channel->name}->{'Stock by Location'}};

    my $variant_location=(split(/_/,$stock_location->{Location}->{input_name},2))[1];

    my $old_location_name = $stock_location->{Location}->{value};
    my $old_quantity = $stock_location->{Quantity}->{value};

    is($old_location_name,$src_location_name,"Variant found in '$src_location_name");
    ok($old_quantity>=$original_stock_level,"Stock level $old_quantity is at least $original_stock_level");

    note "Location: [$old_location_name]";
    note "Quantity: [$old_quantity]";
    note "Variant_Location: [$variant_location]";

    my $amount_to_move=5;

    # Part One...

    # try to fail, first
    if ( config_var('IWS', 'rollout_phase') > 0) {
        $framework->errors_are_fatal(0);

        my $iws_location_name = iws_location_name();
        my $iws_location_args = {
            $variant_location => {
                quantity => $amount_to_move,
                location => $iws_location_name,
            }
        };

        note "Trying to move stock from old location '$src_location_name' to IWS location '$iws_location_name'";

        $framework->flow_mech__stockcontrol__inventory_moveaddstock_submit($iws_location_args);
        $framework->mech->has_feedback_error_ok(qr{May not move stock to location 'IWS'});

        $framework->errors_are_fatal(1);
    }

    note "Moving stock from old location '$src_location_name' to new location '$dst_location_name'";

    my $dst_location_args = {
        $variant_location => {
            quantity => $amount_to_move,
            location => $dst_location_name,
        }
    };

    $framework->flow_mech__stockcontrol__inventory_moveaddstock_submit($dst_location_args);

    # Now examine the state of the data

    note "Checking that the stock moved to the new location";

    $framework->flow_mech__stockcontrol__inventory_moveaddstock($variant->{variant_id});

    my @post_move_stock_items=grep { $_->{SKU}->{value} eq $variant->{sku} && $_->{Location} ne '-'}
                                @{$framework->mech->as_data->{stock_by_location}->{$channel->name}->{'Stock by Location'}};

    my ($old_stock_item)=grep { $_->{Location}->{value} eq $old_location_name } @post_move_stock_items;
    my ($new_stock_item)=grep { $_->{Location}->{value} eq $dst_location_name } @post_move_stock_items;

    ok($old_stock_item->{Quantity}->{value} == $old_quantity-$amount_to_move,
        "Old location '$old_location_name' contains $amount_to_move fewer");

    ok($new_stock_item->{Quantity}->{value} == $amount_to_move,
        "New location '$dst_location_name' contains $amount_to_move");

    # Part Two...

    note "Moving more stock from old location '$old_location_name' to new location '$dst_location_name'";

    $framework->flow_mech__stockcontrol__inventory_moveaddstock($variant->{variant_id})
            ->flow_mech__stockcontrol__inventory_moveaddstock_submit($dst_location_args);

    note "Checking that more stock moved to the new location";

    $framework->flow_mech__stockcontrol__inventory_moveaddstock($variant->{variant_id});

    @post_move_stock_items=grep { $_->{SKU}->{value} eq $variant->{sku} && $_->{Location} ne '-'}
                                @{$framework->mech->as_data->{stock_by_location}->{$channel->name}->{'Stock by Location'}};

    ($old_stock_item)=grep { $_->{Location}->{value} eq $old_location_name } @post_move_stock_items;
    ($new_stock_item)=grep { $_->{Location}->{value} eq $dst_location_name } @post_move_stock_items;

    ok($old_stock_item->{Quantity}->{value} == $old_quantity-(2*$amount_to_move),
    "Old location '$old_location_name' contains another $amount_to_move fewer");

    ok($new_stock_item->{Quantity}->{value} == 2*$amount_to_move,
    "New location '$dst_location_name' contains ".(2*$amount_to_move) );

    # Part Three...

    $dst_location_name=$new_stock_item->{Location}->{value};

    (undef,$variant_location)=split(/_/,$new_stock_item->{Location}->{input_name},2);

    note "Moving stock back to original location '$old_location_name', to prove complementary move also works";

    my $old_location_args = {
        $variant_location => {
            quantity => 2*$amount_to_move,
            location => $old_location_name,
        }
    };

    $framework->flow_mech__stockcontrol__inventory_moveaddstock_submit($old_location_args);

    note "Checking that the stock moved back to the old location";

    $framework->flow_mech__stockcontrol__inventory_moveaddstock($variant->{variant_id});

    @post_move_stock_items=grep { $_->{SKU}->{value} eq $variant->{sku} && $_->{Location} ne '-'}
                                @{$framework->mech->as_data->{stock_by_location}->{$channel->name}->{'Stock by Location'}};

    ($old_stock_item)=grep { $_->{Location}->{value} eq $old_location_name } @post_move_stock_items;
    ($new_stock_item)=grep { $_->{Location}->{value} eq $dst_location_name } @post_move_stock_items;

    ok($old_stock_item->{Quantity}->{value} == $old_quantity,
    "Old location '$old_location_name' contains original $old_quantity");

    ok(!defined($new_stock_item)
    || ($new_stock_item->{Quantity}->{value} == 0),
    "New location '$dst_location_name' contains nothing");
}

=head2 test_move_all_nonmain_stock

Test plan:

    1. Move main quantity to non-main location (should fail)
    2. Move all non-main quantity at a location to another location supporting
       the same status (should pass) and check it logs

=cut

sub test_move_all_nonmain_stock : Tests {
    my ( $self ) = @_;

    my $framework = $self->{framework};
    my $variant = $self->{variant};
    my $channel = $self->{channel};

    # Change the status of the quantity to any non-main
    my $location_status_id = $FLOW_STATUS__QUARANTINE__STOCK_STATUS;
    # Create some locations that doesn't accept said quantity
    my ( $src_location_name, $dst_location_name )
        = $self->create_locations($location_status_id);

    note "Adding stock for SKU $variant->{sku} to source location $src_location_name";

    my $amount_to_move = 5;
    my $stock_status_id = $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS;
    my $quantity = $framework->data__quantity__insert_quantity({
        quantity => $amount_to_move,
        location_name => $src_location_name,
        variant_id => $variant->{variant_id},
        channel_id => $channel->id,
        status_id => $stock_status_id,
    });

    $framework->flow_mech__stockcontrol__inventory_moveaddstock($variant->{variant_id});

    my ($stock_location)=grep {
        $_->{SKU}->{value} eq $variant->{sku} && $_->{Location} ne '-' && $_->{Location}->{value} eq $src_location_name
    } @{$framework->mech->as_data->{stock_by_location}{$channel->name}{'Stock by Location'}};

    my $variant_location=(split(/_/,$stock_location->{Location}->{input_name},2))[1];

    my $old_location_name = $stock_location->{Location}{value};
    my $old_quantity = $stock_location->{Quantity}{value};

    is($old_location_name,$src_location_name,"Variant found in '$src_location_name");
    ok($old_quantity == $amount_to_move,"Stock level $old_quantity is $amount_to_move");

    note "Moving stock from old location '$src_location_name' to new location '$dst_location_name'";

    my $dst_location_args = {
        $variant_location => {
            quantity => $amount_to_move,
            location => $dst_location_name,
        }
    };

    # Test move fail
    $framework->errors_are_fatal(0);

    $framework->flow_mech__stockcontrol__inventory_moveaddstock_submit($dst_location_args);
    $framework->mech->has_feedback_error_ok(map {
        qr{$_}
    } sprintf q{Location '%s' does not accept %s, please choose another},
        $dst_location_name,
        $framework->schema->resultset('Flow::Status')->find($stock_status_id)->name
    );

    $framework->errors_are_fatal(1);

    # Test move success
    # Change quantity back to one that the location should accept
    $quantity->update({status_id => $location_status_id});

    # Do the move
    $framework->flow_mech__stockcontrol__inventory_moveaddstock_submit($dst_location_args);

    # Reload the moveaddstock page for checks
    $framework->flow_mech__stockcontrol__inventory_moveaddstock($variant->{variant_id});

    my @post_move_stock_items = grep {
        $_->{SKU}{value} eq $variant->{sku} && $_->{Location} ne '-'
    } @{$framework->mech->as_data->{stock_by_location}{$channel->name}{'Stock by Location'}};

    ok( (!grep { $_->{Location} ne '-' && $_->{Location}{value} eq $old_location_name } @post_move_stock_items),
        'no stock in old location' );
    my ($new_stock_item) = grep {
        $_->{Location}{value} eq $dst_location_name
    } @post_move_stock_items;

    ok($new_stock_item->{Quantity}->{value} == $amount_to_move,
        "New location '$dst_location_name' contains $amount_to_move");

    # We have moved all stock so we should be logging it
    my $log_location
        = $framework->schema
                    ->resultset('Public::LogLocation')
                    ->search(undef, { rows => 1, order_by => { -desc => 'id' } })
                    ->single;
    for (
        [ 'variant_id',    $log_location->variant_id,         q{==}, $variant->{variant_id} ],
        [ 'location name', $log_location->location->location, q{eq}, $old_location_name ],
        [ 'operator name', $log_location->operator->name,     q{eq}, $framework->mech->logged_in_as_logname ],
        [ 'channel name',  $log_location->channel->name,      q{eq}, $channel->name ],
    ) {
        my ( $name, $got, $op, $expected ) = @$_;
        cmp_ok($got, $op, $expected, "$name logged correctly");
    }
}

=head2 test_create_main_location_if_non_exists

=cut

sub test_create_main_location_if_non_exists : Tests {
    my ( $self ) = @_;

    my $framework = $self->{framework};
    my $variant = $self->{variant};
    my $channel = $self->{channel};

    # Change the status of the quantity to any non-main
    my $q_status_id = $FLOW_STATUS__QUARANTINE__STOCK_STATUS;
    my ($quarantine_location_name) = @{$framework->data__location__create_new_locations({
            allowed_types => [$q_status_id],
    })};

    note "Adding stock for SKU $variant->{sku} to quarantine location $quarantine_location_name";

    my $amount = 5;
    my $quantity = $framework->data__quantity__insert_quantity({
        quantity => $amount,
        location_name => $quarantine_location_name,
        variant_id => $variant->{variant_id},
        channel_id => $channel->id,
        status_id => $q_status_id,
    });

    note "Delete all main stock quantities";
    $framework->data__quantity__delete_quantity_by_type({
        variant_id => $variant->{variant_id},
        channel_id => $channel->id,
        status_id => 1
    });

    my ($main_location) = @{$framework->data__location__create_new_locations({
        allowed_types => [$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS],
    })};

    note "Now try to add a new main location";
    my $args = {
        $variant->{variant_id} => {
            location => $main_location,
        }
    };

    $framework->flow_mech__stockcontrol__inventory_moveaddstock($variant->{variant_id});
    $framework->flow_mech__stockcontrol__inventory_moveaddstock_assign_submit($args);

}

# Create locations for the given location type
sub create_locations {
    my ( $self, $type_id ) = @_;

    my @locations;
    subtest 'create_locations' => sub {
        my $channel = $self->{channel};
        my $location_opts = {
            quantity => 2,
            allowed_types => ( ( grep { $_ && $_ eq 'ARRAY' } ref $type_id ) ? $type_id : [$type_id] ),
            channel_id => $channel->id,
        };

        @locations
            = @{$self->{framework}->data__location__create_new_locations($location_opts)};
        ok ( $_->[1], "Got $_->[0] location '$_->[1]'" )
            for [source => $locations[0]], [destination => $locations[1]];
    };

    return @locations;
}
