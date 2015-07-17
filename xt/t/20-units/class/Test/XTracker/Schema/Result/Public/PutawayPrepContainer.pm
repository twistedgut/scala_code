package Test::XTracker::Schema::Result::Public::PutawayPrepContainer;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { extends "NAP::Test::Class" };
use Test::XTracker::RunCondition prl_phase => 'prl';

use Carp qw/ confess /;
use List::Util qw/ sum /;
use boolean; # true/false
use MooseX::Params::Validate 'validated_list';

use Test::More::Prefix qw/ test_prefix /;

use Test::XT::Data::PutawayPrep;
use Test::XT::Fixture::PutawayPrep::StockProcess::Group;
use XTracker::Role::WithAMQMessageFactory;

use XTracker::Constants qw(
    $APPLICATION_OPERATOR_ID
    :prl_location_name
);
use XTracker::Constants::FromDB qw(
    :allocation_status
    :delivery_action
    :prl
    :putaway_prep_container_status
    :putaway_prep_group_status
    :shipment_hold_reason
    :shipment_status
    :storage_type
);
use vars qw/$PRL__DEMATIC $PRL__FULL/;

BEGIN {
    has setup               => ( is => 'ro', default => sub { Test::XT::Data::PutawayPrep->new } );
    has pp_helper_full      => ( is => 'ro', default => sub { XTracker::Database::PutawayPrep->new } );
    has pp_helper_migration => ( is => 'ro', default => sub { XTracker::Database::PutawayPrep::MigrationGroup->new } );
    # ...setup + helper = too many utility modules ^ should use data fixtures and meaningful classes nstead
    has message_factory     => ( is => 'ro', default => sub { XTracker::Role::WithAMQMessageFactory->build_msg_factory } );
}

sub test_manifest :Tests {
    my ($self) = @_;

    my @manifest = (
        {
            name         => 'single_dematic',
            description  => 'Single item shipment, Dematic',
            product_data_sub => sub {
                my (undef, $product) = $self->setup->create_product_and_stock_process(1, { group_type => $self->pp_helper_migration->name });
                return [$product];
            },
        },
        {
            name         => 'multi_dematic',
            description  => 'Multi-item shipment, two items from Dematic',
            product_data_sub => sub {
                my (undef, $product1) = $self->setup->create_product_and_stock_process(1, { group_type => $self->pp_helper_migration->name });
                my (undef, $product2) = $self->setup->create_product_and_stock_process(1, { group_type => $self->pp_helper_migration->name });
                return [$product1, $product2];
            },
        },
        {
            name         => 'multi_mixed',
            description  => 'Multi-item shipment, one item from Full and one from Dematic',
            product_data_sub => sub {
                my (undef, $product1) = $self->setup->create_product_and_stock_process(1, { group_type => $self->pp_helper_migration->name });
                my (undef, $product2) = $self->setup->create_product_and_stock_process(1, { group_type => $self->pp_helper_full->name });
                return [$product1, $product2];
            },
        },
        {
            name         => 'multi_full',
            description  => 'Multi-item shipment, two items from Full',
            product_data_sub => sub {
                my (undef, $product1) = $self->setup->create_product_and_stock_process(1, { group_type => $self->pp_helper_full->name });
                my (undef, $product2) = $self->setup->create_product_and_stock_process(1, { group_type => $self->pp_helper_full->name });
                return [$product1, $product2];
            },
        },
    );

    # Run all tests
    $self->try_to_reallocate($_) foreach @manifest;
}

sub create_product_and_shipment {
    my ($self, $product_data_sub) = validated_list(
        \@_,
        product_data_sub => { isa => 'CodeRef' },
    );

    # Setup
    note("Set up product and 'stock process' or equivalent");
    my $product_data_list = $product_data_sub->(); # run code to produce product data
    # $product_data->[n] = {
    #    pid               77,
    #    size_id           232,
    #    sku               "77-232",
    #    variant_id        149
    #    product           XTracker::Schema::Result::Public::Product
    #    product_channel   XTracker::Schema::Result::Public::ProductChannel
    #    variant           XTracker::Schema::Result::Public::Variant
    # }

    # Set up an order for that product
    my $order_factory = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ]
    );
    my $shipment_data = $order_factory->new_order(
        products      => $product_data_list,
        dont_allocate => true,
    );
    # $shipment_data = {
    #    shipment_id               6,
    #    shipment_object           XTracker::Schema::Result::Public::Shipment
    #    shipping_account_object   XTracker::Schema::Result::Public::ShippingAccount
    #    address_object            XTracker::Schema::Result::Public::OrderAddress
    #    channel_object            XTracker::Schema::Result::Public::Channel
    #    customer_object           XTracker::Schema::Result::Public::Customer
    #    order_object              XTracker::Schema::Result::Public::Orders
    #    product_objects           [
    #        [0] {
    #            num_ship_items    1,
    #            %$product_data    # see above
    #        }
    #    ],
    # }
    return ($product_data_list, $shipment_data);
}

sub try_to_reallocate {
    my ($self, $name, $description, $product_data_sub) = validated_list(
        \@_,
        name              => { isa => 'Str' },
        description       => { isa => 'Str' },
        product_data_sub => { isa => 'CodeRef' },
    );

    # Allow user to choose which test case to run
    if (defined $ENV{NAP_TEST_METHOD} && $ENV{NAP_TEST_METHOD} ne $name) {
        note("Skipping '$name' test: $description");
        return;
    }

    note("Running '$name' test: $description");

    foreach my $test_method (
        sub { $self->test_finance_hold(@_) },
        sub { $self->test_failed_allocation_hold(@_) },
    ) {
        my ($product_data_list, $shipment_data) = $self->create_product_and_shipment({ product_data_sub => $product_data_sub });

        foreach my $product_data (@$product_data_list) {
            note(sprintf("Checking product %s (variant %s)", $product_data->{pid}, $product_data->{variant_id}));

            if (exists $product_data->{putaway_prep_migration_group_id}) {
                note("Product should have been migrated, check it");
                note("Putaway Prep the items it into Dematic PRL");
                my ($pp_container, $pp_group) = $self->set_up_container_and_group({
                    how_many     => 1,
                    product_data => $product_data,
                    pp_helper    => $self->pp_helper_migration,
                });
                # When AdviceResponse is sent from Dematic PRL to XTracker after some stock
                #   has been migrated (from Full PRL to Dematic PRL), any on-hold shipments
                #   for that stock must be taken off hold and re-allocated.
                # Check the shipment either was or wasn't taken off hold,
                #   depending on what type of hold it had in the first place.
                $test_method->({
                    shipment     => $shipment_data->{shipment_object},
                    pp_container => $pp_container,
                });
            } else {
                note("Product won't have been migrated, we don't care about it");
                next;
            }
            # I would really have prefered to use an object instead of the $product_data hash here.
        }

    }
}

sub test_failed_allocation_hold {
    my ($self, $shipment, $pp_container) = validated_list(
        \@_,
        shipment     => { isa => 'XTracker::Schema::Result::Public::Shipment' },
        pp_container => { isa => 'XTracker::Schema::Result::Public::PutawayPrepContainer' },
    );

    note("Checking Failed Allocation Hold");
    $shipment->set_status_hold(
        $APPLICATION_OPERATOR_ID,
        $SHIPMENT_HOLD_REASON__FAILED_ALLOCATION,
        "Putting on hold for a test"
    );
    ok($shipment->is_on_hold, "Shipment is on hold");
    is($shipment->shipment_status_id, $SHIPMENT_STATUS__HOLD, "Shipment is on hold for the right reason");

    lives_ok(
        sub { $pp_container->advice_response_success( $self->message_factory ) },
        'advice_response_success lives ok'
    );

    note("Expect shipment to be taken off hold, because stock has now been migrated and is available in Dematic");

    $shipment->discard_changes; # reload from database
    ok(! $shipment->is_on_hold, "Test: Shipment has been taken off hold");
    my @expected_dematic_allocations = grep {
        $_->allocation_items->first->shipment_item->product->storage_type_id == $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT
    } $shipment->allocations;
    isnt(scalar(@expected_dematic_allocations), 0, "Shipment has allocations");
    foreach my $alloc (@expected_dematic_allocations) {
        is($alloc->prl_id, $PRL__DEMATIC, 'Allocation has been allocated to correct place: Dematic PRL');
        is($alloc->status_id, $ALLOCATION_STATUS__REQUESTED, 'Allocation is in correct status: Requested');
    }
}

sub test_finance_hold {
    my ($self, $shipment, $pp_container) = validated_list(
        \@_,
        shipment     => { isa => 'XTracker::Schema::Result::Public::Shipment' },
        pp_container => { isa => 'XTracker::Schema::Result::Public::PutawayPrepContainer' },
    );

    note("Checking Finance Hold");
    $shipment->set_status_finance_hold(
        $APPLICATION_OPERATOR_ID,
    );
    ok($shipment->is_on_hold, "Shipment is on hold");
    is($shipment->shipment_status_id, $SHIPMENT_STATUS__FINANCE_HOLD, "Shipment is on hold for the right reason");

    lives_ok(
        sub { $pp_container->advice_response_success( $self->message_factory ) },
        'advice_response_success lives ok'
    );

    note("Expect shipment to stay on hold, because shipment is on finance hold and is unaffected by migration");

    $shipment->discard_changes; # reload from database
    ok($shipment->is_on_hold, "Test: Shipment has NOT been taken off hold yet");
    my @expected_dematic_allocations = grep {
        $_->allocation_items->first->shipment_item->product->storage_type_id == $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT
    } $shipment->allocations;
    is(scalar(@expected_dematic_allocations), 0, "Shipment does NOT have allocations yet");
}

sub set_up_container_and_group {
    my ($self, $args) = @_;
    $args->{how_many} //= 1;
    die "expected product_data hash" unless defined $args->{product_data} and ref $args->{product_data} eq 'HASH';
    my $pp_helper = $args->{pp_helper} || die "expected pp_helper";

    note("Set up PP container and PP group");

    my $group_id = $args->{product_data}->{ $pp_helper->container_group_field_name };

    note("Start a container");
    my $pp_container = $self->setup->create_pp_container();
    my $container_id = $pp_container->container_id;
    my $pp_group = $self->setup->create_pp_group({
        group_id   => $group_id,
        group_type => $pp_helper->name,
    });

    note("Add item to the container");
    my $pp_container_rs = $self->schema->resultset('Public::PutawayPrepContainer');
    $pp_container_rs->add_sku({
        container_id => $pp_container->container_id,
        group_id     => $group_id,
        sku          => $args->{product_data}->{sku},
        putaway_prep => $pp_helper,
    }); # for 1 .. $args->{how_many};

    note("Finish the container");
    $pp_container_rs->finish({ container_id => $pp_container->container_id });

    $_->discard_changes foreach $pp_container, $pp_group; # reload from DB

    return ($pp_container, $pp_group);
}
