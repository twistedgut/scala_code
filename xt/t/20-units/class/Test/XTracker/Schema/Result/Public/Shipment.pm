package Test::XTracker::Schema::Result::Public::Shipment;
use NAP::policy     qw( test class );
BEGIN {
    extends "NAP::Test::Class";
    with 'Test::Role::DBSamples';
    with 'XTracker::Role::AccessConfig';
};

use Test::XTracker::RunCondition    export => ['$distribution_centre', '$prl_rollout_phase'];

use DateTime;
use Test::Fatal;
use Test::MockModule;
use Test::MockObject;
use Test::MockObject::Builder;
use Test::MockObject::Extends;
use Test::XTracker::Mock::DHL::XMLRequest;

use XTracker::Schema::Result::Public::Shipment;
use XTracker::Constants::FromDB qw(
    :allocation_status
    :customer_issue_type
    :customer_category
    :prl
    :shipment_class
    :shipment_hold_reason
    :shipment_status
    :shipment_type
    :storage_type
    :shipment_item_status
    :orders_payment_method_class
    :ship_restriction
    :shipment_item_on_sale_flag
);

use XTracker::Config::Local qw( config_var );
use XTracker::Constants qw( :application );
use XTracker::Schema::Result::Public::Shipment;

use XTracker::Database::Shipment        qw( update_shipment_status );

use Test::XTracker::Data;
use Test::XT::Data;
use Test::XTracker::Mock::PSP;
use Test::XTracker::Mock::LWP;
use LWP::UserAgent;
use File::Basename;

use NAP::Carrier;

use Mock::Quick;

use JSON;

use vars qw/ $PRL__FULL $PRL__GOH $PRL__DEMATIC /;

sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup();
    $self->{channel} = Test::XTracker::Data->channel_for_nap();
    $self->{time_zone} = $self->{channel}->timezone;
    $self->{data_helper} = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Order',
            'Test::XT::Data::Return',
        ],
    );

    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state

    # get the Application Operator
    $self->{app_operator} = $self->rs('Public::Operator')->find( $APPLICATION_OPERATOR_ID );
    # get an Operator who isn't 'it.god' or the App. user
    $self->{operator} = $self->rs('Public::Operator')->search( {
        id          => { '!='       => $APPLICATION_OPERATOR_ID },
        username    => { 'NOT ILIKE' => '%it%god%' },
        name        => { 'NOT ILIKE' => '%disabled%' },
    } )->first;

    $self->{payment_method} = {
        creditcard =>
            $self->rs('Orders::PaymentMethod')->search( {
                payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__CARD,
            } )->first,
        thirdparty =>
            $self->rs('Orders::PaymentMethod')->search( {
                payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
            } )->first,
    };

    my $dhl_label_type = 'dhl_routing';
    $self->{xmlreq} = Test::MockModule->new( 'XTracker::DHL::XMLRequest' );
    $self->{xmlreq}->mock( send_xml_request => sub { return Test::XTracker::Mock::DHL::XMLRequest->$dhl_label_type } );

    # get all of the Shipping Restrictions
    $self->{ship_restrictions} = [ $self->rs('Public::ShipRestriction')->all ];
}

sub setup : Test(setup) {
    my $self = shift;
    $self->SUPER::setup();

    # Start from a default state.
    Test::XTracker::Mock::PSP->set_payment_method('default');
    Test::XTracker::Mock::PSP->set_third_party_status('');

    # get new PSP refs for each Test
    $self->{payment_args} = Test::XTracker::Data->get_new_psp_refs();
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    # Tidy up after oursleves.
    Test::XTracker::Mock::PSP->set_payment_method('default');
    Test::XTracker::Mock::PSP->set_third_party_status('');

    # make sure Mocking of LWP is disabled after every test
    Test::XTracker::Mock::PSP->disable_mock_lwp();
}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown;

    Test::XTracker::Mock::PSP->use_all_original_methods();
}

sub customer {
    my ($self, $customer_args) = @_;
    $customer_args //= {};
    $customer_args->{category_id} //= $CUSTOMER_CATEGORY__NONE;

    my $customer_rs = $self->schema->resultset("Public::Customer");
    return $customer_rs->new($customer_args);
}

sub get_sla_priority :Tests {
    my $self = shift;

    my $shipment_row = $self->get_standard_shipment_row();

    is($shipment_row->get_sla_priority, 2, "Default prio is 2");


    $shipment_row->shipment_type_id($SHIPMENT_TYPE__PREMIER);
    is($shipment_row->get_sla_priority, 1, "But Premier prio is 1");

    $shipment_row->shipment_class_id($SHIPMENT_CLASS__TRANSFER_SHIPMENT);
    is($shipment_row->get_sla_priority, 2, "But Transfer Shipment is 2");

    $self->with_mocked_shipment_order({
        order_args => {
            customer => $self->customer({
                category_id => $CUSTOMER_CATEGORY__STAFF,
            }),
        },
        test_sub => sub {
            is($shipment_row->get_sla_priority, 2, "But a Customer Order is 2");
        }
    });
}

sub get_sla_cutoff_dbic_value_without_nominated_day :Tests {
    my $self = shift;
    note "This is a basic sanity check that non-nominated days return a well formed scalar ref. There's a lot of room for expanding the test coverage.";

    my $shipment_row = $self->get_standard_shipment_row();

    $self->with_mocked_shipment_order({
        order_args => {
            channel_id => $self->{channel}->id,
            customer => $self->customer(),
        },
        test_sub => sub {
            ok(
                my $cutoff_value = $shipment_row->get_sla_cutoff_dbic_value,
                "Got cutoff value",
            );
            isa_ok($cutoff_value, "SCALAR", "    as a scalar ref");
            like(
                $$cutoff_value,
                qr/CURRENT_TIMESTAMP \+ interval '\d+ /,
                "    and it looks alright",
            );
        }
    });
}

sub get_sla_cutoff_dbic_value_with_nominated_day :Tests {
    my $self = shift;
    note "Test that nominated days return the correct DateTime";

    $self->test_get_nominated_day_sla_cutoff_time({
        description                      => "dispatch in far future, cutoff time: default",
        nominated_dispatch_time_from_now => { hours => 12 },
        expected_cutoff_time_is_default  => 1,
    });
    $self->test_get_nominated_day_sla_cutoff_time({
        description                      => "dispatch just later than minimum sla, cutoff time: default",
        nominated_dispatch_time_from_now => { minutes => 181 }, # 3h 1m
        expected_cutoff_time_is_default  => 1,
    });

    $self->test_get_nominated_day_sla_cutoff_time({
        description                      => "dispatch just earlier than minimum sla, cutoff time: at least an hour from now",
        nominated_dispatch_time_from_now => { minutes => 179 }, # 2h 59m
        expected_cutoff_time_is_earliest => 1,
    });
    $self->test_get_nominated_day_sla_cutoff_time({
        description                      => "dispatch is now, cutoff time: at least an hour from now (although we just missed the dispatch)",
        nominated_dispatch_time_from_now => { minutes => 0 }, # now
        expected_cutoff_time_is_earliest => 1,
    });
}

sub test_get_nominated_day_sla_cutoff_time {
    my ($self, $args) = @_;
    my $now = DateTime->now(time_zone => $self->{time_zone});

    my $nominated_dispatch_time = $now->clone->add(
        %{$args->{nominated_dispatch_time_from_now}},
    );
    my $shipment_row = $self->get_standard_shipment_row({
        nominated_dispatch_time => $nominated_dispatch_time,
    });

    my $default_duration_minutes = 120;
    my $minimum_duration_minutes = 60;
    my $expected_cutoff_time = $nominated_dispatch_time->clone->subtract(
        minutes => $default_duration_minutes,
    );
    if($args->{expected_cutoff_time_is_earliest}) {
        $expected_cutoff_time = $now->clone->add(minutes => $minimum_duration_minutes);
    }

    $self->with_mocked_shipment_order({
        order_args => {
            channel_id => $self->{channel}->id,
            customer => $self->customer(),
        },
        test_sub => sub {
            ok(
                my $cutoff_value = $shipment_row->get_sla_cutoff_dbic_value,
                "Got cutoff value",
            );
            isa_ok($cutoff_value, "DateTime", "    as a DateTime");

            # This should be an exact match, but a second rollover
            # might throw it off, so let it slide one second if
            # needed.
            ok(
                abs( $cutoff_value->epoch - $expected_cutoff_time->epoch ) < 2,
                "    and it's the correct localtime ($args->{description}) ($cutoff_value) ($expected_cutoff_time)",
            );

            is(
                $cutoff_value->time_zone,
                $nominated_dispatch_time->time_zone,
                "    and it's in the correct TZ",
            );
        },
    });
}



=head2 with_mocked_shipment_order({ :$order_args, :$test_rub }) : $test_sub->()

Run $test_sub with a mocked Shipment->order to avoid having to create
complex db data structures.

Mock it with a new Order object created from $order_args.

=cut

sub with_mocked_shipment_order {
    my ($self, $args) = @_;

    no warnings "redefine";
    local *XTracker::Schema::Result::Public::Shipment::order = sub {
        my $orders_rs = $self->schema->resultset("Public::Orders");
        $orders_rs->new($args->{order_args});
    };
    return $args->{test_sub}->();
}

sub get_standard_shipment_row {
    my ($self, $shipment_args) = @_;
    $shipment_args //= {};

    my $shipment_rs = $self->schema->resultset("Public::Shipment");
    my $shipment_row = $shipment_rs->new({
        shipment_type_id  => $SHIPMENT_TYPE__DOMESTIC,
        shipment_class_id => $SHIPMENT_CLASS__STANDARD,
        %$shipment_args,
    });

    return $shipment_row;
}

sub test_get_allocations_by_prl :Tests {
    my ($self) = @_;

    # Create two products, one that will need to be fetched from the Dematic PRL, one from the Full PRL
    my ($dematic_product) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
        how_many_variants => 1,
    });
    my ($flat_product) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many_variants => 1,
    });

    # Create a test order with 2 dematic products and 1 flat
    my $data_helper = $self->{data_helper};
    my $order = $data_helper->new_order( products => [$dematic_product, $flat_product, $dematic_product] );

    # Make sure get_items_by_prl_name finds them correctly
    my $shipment_items_by_prl = $order->{shipment_object}->get_items_by_prl_name();

    if(config_var('PRL', 'rollout_phase')) {
        is(keys %$shipment_items_by_prl, 2, 'Found items in 2 PRLs');
        is(@{$shipment_items_by_prl->{'Full'}}, 1, 'Correct number of \'Full\' items (1)');
        is(@{$shipment_items_by_prl->{'Dematic'}}, 2, 'Correct number of \'Dematic\' items (2)');

        # Create another one, this time with some of the items unallocated
        $order = $data_helper->new_order( products => [$dematic_product, $flat_product, $dematic_product] );
        $order->{shipment_object}->search_related('shipment_items', {
            variant_id => $flat_product->variants->first->id()
        })->first->allocation_items->update({ status_id => $ALLOCATION_STATUS__REQUESTED });

        $shipment_items_by_prl = $order->{shipment_object}->get_items_by_prl_name();
        is(keys %$shipment_items_by_prl, 1, 'Found items in 1 PRL');
        is(@{$shipment_items_by_prl->{'Dematic'}}, 2, 'Correct number of \'Dematic\' items (2)');

    } else {
        is(keys %$shipment_items_by_prl, 0, 'PRLs are not activated, get_items_by_prl_name() has returned nothing');
    }
}

sub test_contains_on_sale_items_method : Tests() {
    my $self = shift;

    my $order_obj = $self->{data_helper}->new_order(
        products    => 2,
        channel     => $self->{channel},
        );

    my $shipment = $order_obj->{shipment_object};

    ok( ! $shipment->contains_on_sale_items(),
        'Shipment does not contain on sale items' );

    my $item = $shipment->shipment_items->first;
    $item->update( { sale_flag_id => $SHIPMENT_ITEM_ON_SALE_FLAG__YES } );

    ok( $shipment->contains_on_sale_items(),
        'Shipment does contain on sale items' );
}

sub test_find_or_create_allocation_to_add_item_for_prl :Tests {
    my ($self) = @_;

    SKIP: {
        skip 'Only if PRLs are turned on', 1 unless $prl_rollout_phase;

        my ($flat_product) = Test::XTracker::Data->create_test_products({
            storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
            how_many_variants => 1,
        });
        my ($dematic_product) = Test::XTracker::Data->create_test_products({
            storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
            how_many_variants => 1,
        });

        note "Create an order with 1 dematic product and 2 flat";
        my $mixed_order = $self->{data_helper}->new_order(
            products      => [$dematic_product, $flat_product, $flat_product],
            dont_allocate => 1,
        );
        my $mixed_shipment = $mixed_order->{shipment_object};

        note "Call find_or_create_active_allocation with Full";
        my $full_allocation = $mixed_shipment->find_or_create_allocation_to_add_item_for_prl("Full");
        ok ($full_allocation, "Allocation is returned");
        is ($full_allocation->prl_id, $PRL__FULL, "Allocation is in Full PRL");

        note "Call find_or_create_active_allocation with Full again";
        my $full_allocation_again = $mixed_shipment->find_or_create_allocation_to_add_item_for_prl("Full");
        ok ($full_allocation_again, "Allocation is returned");
        is ($full_allocation_again->id, $full_allocation->id, "Allocation is the same Full allocation as before");

        my $dcd_allocation = $mixed_shipment->find_or_create_allocation_to_add_item_for_prl("Dematic");
        ok ($dcd_allocation, "Allocation is returned");
        is ($dcd_allocation->prl_id, $PRL__DEMATIC, "Allocation is in DCD PRL");
    }

    SKIP: {
        skip 'Only in PRL phase 2+', 1 unless $prl_rollout_phase >= 2;

        my ($hanging_product) = Test::XTracker::Data->create_test_products({
            storage_type_id => $PRODUCT_STORAGE_TYPE__HANGING,
            how_many_variants => 1,
        });
        note "Create an order with the maximum number of items that are allowed in one GOH allocation";
        my $goh_prl_row = XT::Domain::PRLs::get_prl_from_name({
            prl_name => 'GOH',
        });
        my $large_goh_order = $self->{data_helper}->new_order(
            products      => [ ($hanging_product) x $goh_prl_row->max_allocation_items],
            dont_allocate => 1,
        );
        my $large_goh_shipment = $large_goh_order->{shipment_object};
        is ($large_goh_shipment->allocations->count, 0, "GOH shipment has no allocations yet");

        note "Call find_or_create_active_allocation with GOH";
        my $goh_allocation = $large_goh_shipment->find_or_create_allocation_to_add_item_for_prl("GOH");
        ok ($goh_allocation, "Allocation is returned");
        is ($goh_allocation->prl_id, $PRL__GOH, "Allocation is in GOH PRL");
        is ($large_goh_shipment->allocations->count, 1, "GOH shipment has one allocation");

        note "Allocate the large GOH shipment";
        $large_goh_shipment->allocate({operator_id => $APPLICATION_OPERATOR_ID});
        is ($large_goh_shipment->allocations->count, 1, "GOH shipment still has one allocation");
        is ($large_goh_shipment->allocations->first->id, $goh_allocation->id, "GOH allocation is the correct one");
        is ($large_goh_shipment->allocations->first->allocation_items->count, $large_goh_shipment->shipment_items->count,
            "GOH allocation contains the same number of items as the shipment");

        note "Call find_or_create_active_allocation again, when the original allocation already contains the max number of items";
        my $goh_allocation_again = $large_goh_shipment->find_or_create_allocation_to_add_item_for_prl("GOH");
        ok ($goh_allocation_again, "Allocation is returned");
        is ($goh_allocation_again->prl_id, $PRL__GOH, "Allocation is in GOH PRL");
        isnt ($goh_allocation_again->id, $goh_allocation->id, "Allocation is a different one");
    }
}

sub test_is_incorrect_website_method :Tests {
    my ($self) = @_;

    my $order_details = $self->{data_helper}->new_order(
        products    => 2,
        channel     => $self->{channel},
    );
    my $customer    = $order_details->{customer_object};
    my $shipment    = $order_details->{shipment_object};

    my $alternative_countries = config_var('IncorrectWebsiteCountry', 'country');

    #check
    is( $shipment->is_incorrect_website(), 0 , "Shipment country is in the same as DC country");

    my ($alt_country) = grep { not / $shipment->shipment_address->country/ } @{ $alternative_countries };
    #update shipment country to united states
    $shipment->update_or_create_related('shipment_address',{
        country => $alt_country,
    });

    is( $shipment->discard_changes->is_incorrect_website(), 1 , "Shipment country is of Different DC than local DC");

}

sub test_update_status_remove_hold_invalid_chars :Tests {
    my $self = shift;

    my $address = Test::XTracker::Data->create_order_address_in('NonASCIICharacters');

    my $order_data = Test::XTracker::Data::Order->create_new_order( {
        channel     => $self->{channel},
        address => $address,
    } );

    my $shipment = $order_data->{shipment_object};

    # Call NAP::Carrier->validate_address which should set on hold due to invalid chars

    my $nc = NAP::Carrier->new( {
        schema      => $shipment->result_source->schema,
        shipment_id => $shipment->id,
        operator_id => $APPLICATION_OPERATOR_ID,
    } );
    $nc->set_address_validator('DHL');
    $nc->validate_address;

    ok($shipment->discard_changes->is_on_hold_for_invalid_address_chars,
        "Shipment is on hold for Invalid Characters" );

    my $count = $shipment->discard_changes->search_related('shipment_holds', {
        shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
    } )->count;

    ok( $count == 1, "There is 1 shipment_hold record for Invalid Characters");

    my $hold_logs = $shipment->search_related('shipment_hold_logs', {
        shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
    } )->count;
    ok( $hold_logs >= 1, 'There is at least one shipment_hold_log entry for Invalid Characters');

    # Call update_status to force the
    $shipment->update_status(
        $SHIPMENT_STATUS__PROCESSING,
        $APPLICATION_OPERATOR_ID
    );

    # shipment should be on hold
    ok( $shipment->discard_changes->is_on_hold_for_invalid_address_chars,
        "Shipment still on hold due to Invalid Characters" );

    $count = $shipment->search_related('shipment_holds', {
        shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
    } )->count;

    cmp_ok( $count, '==', 1, "Still 1 shipment_hold record for Invalid Characters");
}

=head2 test_has_same_address_as_billing_address

Test the shipping/billing address comparison returns the correct result
with various address data.

=cut

sub test_has_same_address_as_billing_address :Tests {
    my $self = shift;

    # Create two addresses to work with.
    my $address_1 = Test::XTracker::Data->create_order_address_in('current_dc');
    my $address_2 = Test::XTracker::Data->create_order_address_in('current_dc');

    my ( undef, $pids ) = Test::XTracker::Data->grab_products( {
        how_many => 1,
    } );

    # We need an order object, because we're testing both invoice and shipping
    # addresses.
    my ( $order ) = Test::XTracker::Data->create_db_order( {
        pids => $pids,
        base => {
            invoice_address_id => $address_1->id,
        }
    } );

    # The standard class shipment to test against.
    my $shipment = $order->get_standard_class_shipment;

    # TEST 1: It should return true when using the same order address IDs.
    ok( $shipment->has_same_address_as_billing_address, 'Returns true for the same IDs' );

    # Change the shipment address to a different ID.
    $shipment->shipment_address_id( $address_2->id );

    # TEST 2: It should return true when using different order address IDs, but
    # with the same data.
    ok( $shipment->has_same_address_as_billing_address, 'Returns true for different IDs, same data' );

    # Change the address associated with the order.
    $address_1->update( {
        address_line_1 => 'CHANGED',
    } );

    # TEST 3: It should now return false for different IDs with different data.
    ok( ! $shipment->has_same_address_as_billing_address, 'Returns false for different IDs, different data' );
}

sub test_slas :Tests {
    my $self = shift;

    my $shipment = Test::XTracker::Data::Order->create_new_order({
        channel => $self->{channel},
    })->{shipment_object};

    # These tests apply to the old method of working out SLAs (not SOS),
    # so pretend SOS is turned of
    $shipment = Test::MockObject::Builder->extend($shipment, {
        mock  => {
            use_sos_for_sla_data => 0,
        },
    });

    my @tests = (
        # Standard class shipments
        [ 'Standard Premier' => {
            type_id             => $SHIPMENT_TYPE__PREMIER,
            class_id            => $SHIPMENT_CLASS__STANDARD,
            sla_cutoff_interval => '1 hours',
            sla_priority        => 1,
        }, ],
        # This shipment also exercises the finance hold tests
        [ 'Standard Domestic' => {
            type_id              => $SHIPMENT_TYPE__DOMESTIC,
            class_id             => $SHIPMENT_CLASS__STANDARD,
            sla_cutoff_interval  => '1 days',
            sla_priority         => 2,
            test_finance_hold    => 1,
        }, ],
        [ 'Standard Sample'=> {
            type_id             => $SHIPMENT_TYPE__PREMIER,
            class_id            => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
            sla_cutoff_interval => '1 days',
            sla_priority        => 2,
        }, ],
        [ 'Standard Staff Premier'=> {
            type_id              => $SHIPMENT_TYPE__PREMIER,
            class_id             => $SHIPMENT_CLASS__STANDARD,
            customer_category_id => $CUSTOMER_CATEGORY__STAFF,
            sla_cutoff_interval  => '7 days',
            sla_priority         => 2,
        }, ],
        [ 'Standard Staff Domestic'=> {
            type_id              => $SHIPMENT_TYPE__DOMESTIC,
            class_id             => $SHIPMENT_CLASS__STANDARD,
            customer_category_id => $CUSTOMER_CATEGORY__STAFF,
            sla_cutoff_interval  => '7 days',
            sla_priority         => 2,
        }, ],
        # Replacement shipments
        [ 'Replacement Premier' => {
            type_id             => $SHIPMENT_TYPE__PREMIER,
            class_id            => $SHIPMENT_CLASS__REPLACEMENT,
            sla_cutoff_interval => '1 hours',
            sla_priority        => 1,
        }, ],
        [ 'Replacement Domestic' => {
            type_id             => $SHIPMENT_TYPE__DOMESTIC,
            class_id            => $SHIPMENT_CLASS__REPLACEMENT,
            sla_cutoff_interval => '1 hours',
            sla_priority        => 2,
        }, ],
        [ 'Replacement Staff Premier' => {
            type_id              => $SHIPMENT_TYPE__PREMIER,
            class_id             => $SHIPMENT_CLASS__REPLACEMENT,
            customer_category_id => $CUSTOMER_CATEGORY__STAFF,
            sla_cutoff_interval  => '1 days',
            sla_priority         => 2,
        }, ],
        [ 'Replacement Staff Domestic' => {
            type_id              => $SHIPMENT_TYPE__DOMESTIC,
            class_id             => $SHIPMENT_CLASS__REPLACEMENT,
            customer_category_id => $CUSTOMER_CATEGORY__STAFF,
            sla_cutoff_interval  => '1 days',
            sla_priority         => 2,
        }, ],
        # Exchange shipments
        [ 'Exchange Premier' => {
            type_id             => $SHIPMENT_TYPE__PREMIER,
            class_id            => $SHIPMENT_CLASS__EXCHANGE,
            sla_cutoff_interval => '1 hours',
            sla_priority        => 1,
        }, ],
        [ 'Exchange Domestic' => {
            type_id             => $SHIPMENT_TYPE__DOMESTIC,
            class_id            => $SHIPMENT_CLASS__EXCHANGE,
            sla_cutoff_interval => '1 days',
            sla_priority        => 2,
        }, ],
        [ 'Exchange Staff Premier' => {
            type_id              => $SHIPMENT_TYPE__PREMIER,
            class_id             => $SHIPMENT_CLASS__EXCHANGE,
            customer_category_id => $CUSTOMER_CATEGORY__STAFF,
            sla_cutoff_interval  => '7 days',
            sla_priority         => 2,
        }, ],
        [ 'Exchange Staff Domestic' => {
            type_id              => $SHIPMENT_TYPE__DOMESTIC,
            class_id             => $SHIPMENT_CLASS__EXCHANGE,
            customer_category_id => $CUSTOMER_CATEGORY__STAFF,
            sla_cutoff_interval  => '7 days',
            sla_priority         => 2,
        }, ],
    );
    for my $test ( @tests ) {
        subtest $test->[0] => sub {
            $self->_execute_sla_tests( $shipment, $test->[1] )
        };
    }
}

sub _execute_sla_tests {
    my ( $self, $shipment, $args ) = @_;

    my $type_id              = $args->{type_id};
    my $class_id             = $args->{class_id};
    my $customer_category_id = $args->{customer_category_id};
    my $sla_cutoff_interval  = $args->{sla_cutoff_interval};
    my $sla_priority         = $args->{sla_priority};
    my $test_finance_hold    = !!$args->{test_finance_hold};

    # update the shipment & customer record with different data
    $shipment->order->customer->update({
        category_id => $customer_category_id || $CUSTOMER_CATEGORY__NONE
    });
    $shipment->update({
        shipment_type_id  => $type_id,
        shipment_class_id => $class_id,
    });

    if ( $test_finance_hold ) {
        # Apply SLAs to current date
        $shipment->apply_SLAs;
        my $current_date = $shipment->date;
        $shipment->update({
            date => \q{date - interval '1 year'},
            shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD,
        });
        # This should have no effect, i.e. the cutoff should still be
        # based on now()
        $shipment->apply_SLAs;
        ok( Test::XTracker::Data->close_to_test_time(
            $shipment->sla_cutoff, $current_date, $sla_cutoff_interval
        ), 'cutoff not updated - ok when shipment is on finance hold' );
        # Restore the date
        $shipment->update({ date => $current_date });
    }

    # * If we have an exchange class shipment we want to test both exchange and
    #   return holds, both while it's held and after it's released
    # * Otherwise we just want to test processing
    if ( !$shipment->is_exchange_class ) {
        $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__PROCESSING });
        $shipment->apply_SLAs;
        is( $shipment->sla_priority, $sla_priority, 'priority ok');
        ok( Test::XTracker::Data->close_to_test_time(
            $shipment->sla_cutoff, $shipment->date, $sla_cutoff_interval
        ), q{cutoff ok'} );
    }
    else {
        my $exchange_sla_cutoff_interval = '1 days';
        for my $shipment_status_id (
            $SHIPMENT_STATUS__EXCHANGE_HOLD, $SHIPMENT_STATUS__RETURN_HOLD
        ) {
            $shipment->update({ shipment_status_id => $shipment_status_id });

            # For exchange shipments we need to consider the SLAs while they're
            # on hold...
            # We do not apply SLA's to shipments on exchange hold / return hold
            # anymore

            # ... and after they've been released
            $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__PROCESSING });

            $shipment->apply_SLAs;
            is( $shipment->sla_priority, $sla_priority,
                sprintf 'priority ok following shipment release');
            ok( Test::XTracker::Data->close_to_test_time(
                $shipment->sla_cutoff, $shipment->date, $sla_cutoff_interval
            ), 'cutoff ok following shipment release' );
        }
    }
}

sub test_nominated_day_slas :Tests {
    my $self = shift;

    my $shipment = Test::XTracker::Data::Order->create_new_order({
        channel => $self->{channel},
    })->{shipment_object};

    # These tests apply to the old method of working out SLAs (not SOS),
    # so pretend SOS is turned of
    $shipment = Test::MockObject::Builder->extend($shipment, {
        mock  => {
            use_sos_for_sla_data => 0,
        },
    });

    my $now = DateTime->now->set_time_zone(config_var('DistributionCentre', 'timezone'));

    my $order = $shipment->order;
    my $channel_timezone = $order->channel->timezone;
    my $future_dispatch_time = $now->clone
            ->set_time_zone($channel_timezone)  # For dispatch, set to TZ of the DC
            ->add(days => 6); # Nominated Day six days from now

    my $customer = $order->customer;

    $shipment->update({ shipment_status_id      => $SHIPMENT_STATUS__PROCESSING });
    $shipment->update({ shipment_type_id        => $SHIPMENT_TYPE__PREMIER});
    $shipment->update({ nominated_dispatch_time => $future_dispatch_time });
    $customer->update({ category_id             => $CUSTOMER_CATEGORY__EIP_PREMIUM});

    note "* Apply the SLAs";
    $shipment->apply_SLAs;

    note "Have set shipment number "        . ($shipment->id || 'MISSING ID')
        . " to sla priority "               . ($shipment->sla_priority || 'MISSING SLA_PRIORITY')
        . " and set the sla cutoff to be "  . ($shipment->sla_cutoff || 'SLA CUTOFF');

    note "* Test the results.";
    my $dispatch_buffer_hours = 2; # In config
    my $future_cutoff_time = $future_dispatch_time->clone->subtract(hours => $dispatch_buffer_hours);
    is( $shipment->sla_priority, 1                  , 'SLA sorting priority is set to highest (same as non Nominated Day)' );
    is( $shipment->sla_cutoff  , $future_cutoff_time, "SLA cutoff time amended, is near the nominated_dispatch_time" );
}

sub test__get_from_address_data :Tests {
    my ($self) = @_;

    CHANNEL:
    for (
            [Test::XTracker::Data->channel_for_nap(), 'DHL Express'],
            [Test::XTracker::Data->channel_for_mrp(), 'DHL Express'],
        ) {
        my ($channel, $carrier_name) = @$_;
        next CHANNEL        if ( !$channel->is_enabled );

        my $from_company    = $self->solve( 'ShippingAccount::FromCompanyName', {
            business_id => $channel->business_id,
        } );

        my $shipment = $self->_create_shipment_with_shipping_account($channel, $carrier_name);
        my $from_address_data = $shipment->get_from_address_data();

        is($from_address_data->{from_company}, $from_company, "Correct 'From Company' name returned");
    }


}

sub test_virtual_voucher_only_not_held_due_to_invalid_chars : Tests {
    my $self = shift;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 1, channel => 'nap',
        virt_vouchers => {
            how_many => 2,
        }
    } );

     my ($order) = Test::XTracker::Data->apply_db_order({
         pids   => $pids->[1],
         attrs  => [ {} ],
         base   => {
             tenders                => undef,
             shipment_status        => $SHIPMENT_STATUS__PROCESSING,
             shipment_item_status  => $SHIPMENT_ITEM_STATUS__NEW,
         },
     });

     my $shipment = $order->get_standard_class_shipment;
     ok( $shipment->is_virtual_voucher_only, "Shipment is virtual voucher only shipment" );

     # Now update the shipment address so that it has an invalidate_address
     my $invalid_address = Test::XTracker::Data->create_order_address_in('NonASCIICharacters');
     $shipment->update( { shipment_address_id => $invalid_address->id } );

     my $carrier = NAP::Carrier->new( {
         schema => $self->schema,
         shipment_id => $shipment->id,
         operator_id => $APPLICATION_OPERATOR_ID,
     } );

     ok( $carrier, "I have a NAP::Carrier object" );

     $carrier->validate_address;
     ok( ! $shipment->is_held, "The shipment is not on hold" );

}

sub test_physical_voucher_only_held_due_to_invalid_chars : Tests {
    my $self = shift;

    SKIP: {
        skip "Not Appropriate for DC2", 1       if ( $distribution_centre eq 'DC2' );

        my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
            how_many => 1, channel => 'nap',
            phys_vouchers => {
                how_many => 1,
            }
        } );

        my $invalid_address = Test::XTracker::Data->create_order_address_in('NonASCIICharacters');
        my ($order) = Test::XTracker::Data->apply_db_order({
            pids   => $pids->[1],
            attrs  => [ {} ],
            base   => {
                invoice_address_id     => $invalid_address->id,
                tenders                => undef,
                shipment_status        => $SHIPMENT_STATUS__PROCESSING,
                shipment_item_status   => $SHIPMENT_ITEM_STATUS__NEW,
            },
        });

        my $shipment = $order->get_standard_class_shipment;
        ok( $shipment->has_vouchers, "Shipment has vouchers" );
        ok( ! $shipment->is_virtual_voucher_only, "Shipment is not virtual voucher only shipment" );

        my $carrier = NAP::Carrier->new( {
            schema => $self->schema,
            shipment_id => $shipment->id,
            operator_id => $APPLICATION_OPERATOR_ID,
        } );

        ok( $carrier, "I have a NAP::Carrier object" );

        $carrier->validate_address;
        ok( $shipment->discard_changes->is_held, "The shipment is on hold" );
        ok( $shipment->shipment_holds->search( {
            shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
            } )->first,
            "... and the hold reason is invalid characters" );
    }
}

sub test_mixed_voucher_is_held_due_to_invalid_chars : Tests {
    my $self = shift;

    SKIP: {
        skip "Not Appropriate for DC2", 1       if ( $distribution_centre eq 'DC2' );

        my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
            how_many => 1, channel => 'nap',
            phys_vouchers => {
                how_many => 1,
            },
            virt_vouchers => {
                how_many => 2,
            }
        } );

        my $invalid_address = Test::XTracker::Data->create_order_address_in('NonASCIICharacters');

        my ($order) = Test::XTracker::Data->apply_db_order({
            pids   => $pids,
            attrs  => [ {} ],
            base   => {
                invoice_address_id     => $invalid_address->id,
                tenders                => undef,
                shipment_status        => $SHIPMENT_STATUS__PROCESSING,
                shipment_item_status   => $SHIPMENT_ITEM_STATUS__NEW,
            },
        });

        my $shipment = $order->get_standard_class_shipment;
        ok( $shipment->has_vouchers, "Shipment has vouchers" );

        ok( ! $shipment->is_virtual_voucher_only, "Shipment is not virtual voucher only shipment" );

        my $carrier = NAP::Carrier->new( {
            schema => $self->schema,
            shipment_id => $shipment->id,
            operator_id => $APPLICATION_OPERATOR_ID,
        } );

        ok( $carrier, "I have a NAP::Carrier object" );

        $carrier->validate_address;
        ok( $shipment->discard_changes->is_held, "The shipment is on hold" );
        ok( $shipment->shipment_holds->search( {
            shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
            } )->first,
            "... and the hold reason is invalid characters" );
    }
}

=head2 test_is_on_hold_for_third_party_psp_reason

Tests the method 'is_on_hold_for_third_party_psp_reason' which checks to see
if a Shipment is on Hold for a Third Party PSP Payment Reason.

=cut

sub test_is_on_hold_for_third_party_psp_reason : Tests {
    my $self = shift;

    my $order_details = $self->{data_helper}->new_order;
    my $shipment = $order_details->{shipment_object};

    note "Test when Shipment is NOT on Hold";
    my $got = $shipment->is_on_hold_for_third_party_psp_reason;
    ok( defined $got, "'is_on_hold_for_third_party_psp_reason' returned a defined Value" );
    cmp_ok( $got, '==', 0, "and the value is FALSE" );

    my $reasons = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::ShipmentHoldReason', {
        allow   => [
            $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
            $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
        ],
    } );

    $shipment->put_on_hold( {
        status_id   => $SHIPMENT_STATUS__HOLD,
        norelease   => 1,
        operator_id => $APPLICATION_OPERATOR_ID,
    } );
    my $hold_rec = $shipment->shipment_holds->first;

    note "Test for NON Third Party PSP Reasons";
    foreach my $reason ( @{ $reasons->{not_allowed} } ) {
        $hold_rec->discard_changes->update( {
            shipment_hold_reason_id => $reason->id,
        } );
        $got = $shipment->is_on_hold_for_third_party_psp_reason;
        ok( defined $got, "method returned a defined Value" );
        cmp_ok( $got, '==', 0, "and the value is FALSE for Reason: '" . $reason->reason . "'" );
    }

    note "Test FOR Third Party PSP Reasons";
    foreach my $reason ( @{ $reasons->{allowed} } ) {
        $hold_rec->discard_changes->update( {
            shipment_hold_reason_id => $reason->id,
        } );
        $got = $shipment->is_on_hold_for_third_party_psp_reason;
        ok( defined $got, "method returned a defined Value" );
        cmp_ok( $got, '==', 1, "and the value is TRUE for Reason: '" . $reason->reason . "'" );
    }
}

=head2 test_update_status_based_on_third_party_psp_payment_status

This tests the method 'update_status_based_on_third_party_psp_payment_status' which if the
Order was paid for using a Third Party PSP (PayPal) will check with our PSP to see if the
Third Party has Accepted the Payment yet, if it hasn't it will then put the Shipment on Hold
with an appropriate reason but only if it is in 'Processing' or on 'Hold' for a Third Party
PSP reason.

=cut

sub test_update_status_based_on_third_party_psp_payment_status : Tests {
    my $self    = shift;

    my @tests = (
        ["Shipment on Finance Hold & Third Party Accepted Payment, nothing should happen" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__FINANCE_HOLD,
                third_party_status  => 'ACCEPTED',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__FINANCE_HOLD,
            },
        }],
        ["Shipment on Finance Hold & Third Party Pending Payment, nothing should happen" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__FINANCE_HOLD,
                third_party_status  => 'PENDING',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__FINANCE_HOLD,
            },
        }],
        ["Shipment on Finance Hold & Third Party Rejected Payment, nothing should happen" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__FINANCE_HOLD,
                third_party_status  => 'REJECTED',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__FINANCE_HOLD,
            },
        }],
        ["Shipment on Shipment Hold with Non-Payment Reason & Third Party Accepted Payment, nothing should happen" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__OTHER,
                third_party_status  => 'ACCEPTED',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__OTHER,
            },
        }],
        ["Shipment on Shipment Hold with Non-Payment Reason & Third Party Pending Payment, nothing should happen" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__OTHER,
                third_party_status  => 'PENDING',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__OTHER,
            },
        }],
        ["Shipment on Shipment Hold with Non-Payment Reason & Third Party Rejected Payment, nothing should happen" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__OTHER,
                third_party_status  => 'REJECTED',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__OTHER,
            },
        }],
        ["Shipment Processing & Third Party Accepted Payment, nothing should happen Shipment should still be Processing" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
                third_party_status  => 'ACCEPTED',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
            },
        }],
        ["Shipment Processing & Third Party Pending Payment, Shipment should go on Hold" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
                third_party_status  => 'PENDING',
                operator            => $self->{operator},
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
                hold_comment        => qr/Waiting on Third Party/i,
            },
        }],
        ["Shipment Processing & Third Party Rejected Payment, Shipment should go on Hold" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
                third_party_status  => 'REJECTED',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
                hold_comment        => qr/Third Party.*Rejected/i,
            },
        }],
        ["Shipment on Hold already with External Payment Pending Reason & Third Party Status is Pending, nothing should happen" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
                third_party_status  => 'PENDING',
                operator            => $self->{operator},
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
                operator            => $self->{app_operator},
            },
        }],
        ["Shipment on Hold already with External Payment Pending Reason & Third Party Status is Accepted, Shipment should go to Processing" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
                third_party_status  => 'ACCEPTED',
                operator            => $self->{operator},
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
            },
        }],
        ["Shipment on Hold already with External Payment Pending Reason & Third Party Status is Rejected, Shipment still on Hold but with new Reason" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
                third_party_status  => 'REJECTED',
                operator            => $self->{operator},
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
                hold_comment        => qr/Third Party.*Rejected/i,
            },
        }],
        ["Shipment On Hold for Third Party Reason but NOT Paid using a Third Party, Shipment should come off Hold" => {
            # this is the scenario where a new Pre-Auth has been gotten from our PSP
            # (which will be for a Credit Card) most likely because the Third Party PSP
            # Rejected the Original Payment and so now the Shipment can be Released
            setup => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                payment_method      => 'creditcard',
                hold_reason         => $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
                # this should be ignored
                third_party_status  => 'REJECTED',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
            },
        }],
        ["Shipment on Hold with Non-Payment Reason & NOT Paid using a Third Party, nothing should happen" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__OTHER,
                payment_method      => 'creditcard',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                hold_reason         => $SHIPMENT_HOLD_REASON__OTHER,
            },
        }],
        ["Shipment Processing & NOT Paid using a Third Party, nothing should happen" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
                payment_method      => 'creditcard',
                # this should be ignored
                third_party_status  => 'REJECTED',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
            },
        }],
        ["Shipment On Hold with Third Party Reason & NOT Paid using either Card or Third Party (no orders.payment record), Shipment should come off Hold" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__HOLD,
                no_payment          => 1,
                hold_reason         => $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
                # this should be ignored
                third_party_status  => 'REJECTED',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
            },
        }],
        ["Shipment Processing & NOT Paid using either Card or Third Party, nothing should happen" => {
            setup => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
                no_payment          => 1,
                # this should be ignored
                third_party_status  => 'REJECTED',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
            },
        }],
        ["NON Standard Class Shipment Processing & Third Party Pending Payment, nothing should happen" => {
            setup => {
                shipment_class      => $SHIPMENT_CLASS__REPLACEMENT,
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
                third_party_status  => 'PENDING',
            },
            expect => {
                shipment_status     => $SHIPMENT_STATUS__PROCESSING,
            },
        }],
    );

    my $address = Test::XTracker::Data->create_order_address_in('current_dc');
    my $order_details = $self->{data_helper}->new_order(
        channel => $self->{channel},
        address => $address,
    );
    my $order    = $order_details->{order_object};
    my $shipment = $order_details->{shipment_object};
    ok( $shipment, 'created shipment ' . $shipment->id );

    foreach my $test_data ( @tests ) {
        my ( $label, $test ) = @$test_data;
        subtest $label => sub {
            my $setup   = $test->{setup};
            my $expect  = $test->{expect};

            # set which Operator should have set the Hold Reason
            $expect->{operator} = $expect->{operator} ||
                                    $setup->{operator} ||
                                        $self->{app_operator};
            # set-up the Operator Id to pass to the method
            my $operator_id_to_pass = ( $setup->{operator} ? $setup->{operator}->id : undef );

            $order->discard_changes->payments->delete;
            $shipment->discard_changes->shipment_holds->delete;

            # set-up requirements for Payment & PSP
            $self->_setup_payment_and_psp( {
                order               => $order,
                payment_method      => $setup->{payment_method} || 'thirdparty',
                third_party_status  => $setup->{third_party_status},
                no_payment          => $setup->{no_payment},
            } );

            # set-up requirements for the Shipment
            $self->_setup_shipment_record( $shipment, {
                shipment_class_id   => $setup->{shipment_class} || $SHIPMENT_CLASS__STANDARD,
                shipment_status_id  => $setup->{shipment_status},
                hold_reason         => $setup->{hold_reason},
            } );

            # call the method on the Shipment
            $shipment->update_status_based_on_third_party_psp_payment_status( $operator_id_to_pass );
            $shipment->discard_changes;

            cmp_ok( $shipment->shipment_status_id, '==', $expect->{shipment_status},
                                    "Shipment Status is as Expected" );
            if ( $expect->{hold_reason} ) {
                cmp_ok( $shipment->shipment_holds->count, '==', 1, "Only ONE Shipment Hold found" );
                my $shipment_hold = $shipment->shipment_holds->first;
                isa_ok( $shipment_hold, 'XTracker::Schema::Result::Public::ShipmentHold',
                                    "Shipment is on Hold" );
                cmp_ok( $shipment_hold->shipment_hold_reason_id, '==', $expect->{hold_reason},
                                    "and the Hold Reason is as Expected" );
                cmp_ok( $shipment_hold->operator_id, '==', $expect->{operator}->id,
                                    "and the Operator for the Hold is as Expected: '" . $expect->{operator}->name . "'" );
                # check if a particular 'comment' is expected for the Hold Reason
                if ( my $comment = $expect->{hold_comment} ) {
                    like( $shipment_hold->comment, $comment,
                                    "and 'comment' for Hold Reason is as Expected" );
                }
            }
            else {
                my $hold_rs = $shipment->shipment_holds;
                ok( !$shipment->shipment_holds->count,
                    "The Shipment has NO Hold Reasons"
                ) or diag '- but it does... and they are ' . join q{, },
                    $hold_rs->search({},{order_by => 'hold_date'})
                        ->get_column('shipment_hold_reason_id')
                        ->all;
            }
        };
    }
}

=head2 test_update_status_checks_for_third_party_payment

Tests that the 'update_status' method and the old 'XTracker::Database::Shipment::update_shipment_status' function
check the status of a Third Party Payment and then places the Shipment On Hold for a Third Party Reason if deemed
appropriate.

=cut

sub test_update_status_checks_for_third_party_payment : Tests {
    my $self    = shift;

    my %tests   = (
        "Third Party Payment is 'Pending' but Shipment Status Updated to 'Finance Hold'" => {
            setup => {
                set_shipment_status     => $SHIPMENT_STATUS__FINANCE_HOLD,
                # this should be ignored
                third_party_status  => 'PENDING',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__FINANCE_HOLD,
                sla_updated     => 0,
            },
        },
        "Third Party Payment is 'Pending' but Shipment Address has Non-Latin Characters" => {
            setup => {
                start_shipment_status => $SHIPMENT_STATUS__HOLD,
                start_hold_reason     => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
                set_shipment_status   => $SHIPMENT_STATUS__PROCESSING,
                address               => Test::XTracker::Data->create_order_address_in('NonASCIICharacters'),
                # don't run this test on DC2
                for_dcs               => [ qw( DC1 DC3 ) ],
                # this should be ignored
                third_party_status    => 'PENDING',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
                sla_updated     => 0,
            },
        },
        "Order using Credit Card, Shipment set to Processing and Should be set to Processing" => {
            setup => {
                set_shipment_status => $SHIPMENT_STATUS__PROCESSING,
                payment_method      => 'creditcard',
                # this should be ignored
                third_party_status  => 'PENDING',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__PROCESSING,
                sla_updated     => 1,
            },
        },
        "Third Party Payment is 'Pending' and Shipment set to Processing" => {
            setup => {
                set_shipment_status => $SHIPMENT_STATUS__PROCESSING,
                third_party_status  => 'PENDING',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
                sla_updated     => 0,
            },
        },
        "Third Party Payment is 'Accepted' and Shipment set to Processing" => {
            setup => {
                set_shipment_status => $SHIPMENT_STATUS__PROCESSING,
                third_party_status  => 'ACCEPTED',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__PROCESSING,
                sla_updated     => 1,
            },
        },
    );

    my $good_address  = Test::XTracker::Data->create_order_address_in('current_dc');
    my $order_details = $self->{data_helper}->new_order(
        channel => $self->{channel},
        address => $good_address,
    );
    my $order    = $order_details->{order_object};
    my $shipment = $order_details->{shipment_object};
    # We're not testing address validation here, so always validate successfully
    my $mocked = Test::MockObject::Extends->new($shipment);
    $mocked->mock(has_validated_address => sub {1});

    # loop round the two different ways of Updating the Shipment
    # Status and run each test scenario using both methods
    METHOD:
    foreach my $update_method_to_use ( qw( update_status update_shipment_status ) ) {
        TEST:
        foreach my $label ( keys %tests ) {
            note "Using Method '${update_method_to_use}', Testing: ${label}";
            my $test    = $tests{ $label };
            my $setup   = $test->{setup};
            my $expect  = $test->{expect};

            # some of the tests don't run on all DCs
            if ( my $dc_list = $setup->{for_dcs} ) {
                if ( !grep { $_ eq $distribution_centre } @{ $dc_list } ) {
                    note "This Test doesn't run on DC '${distribution_centre}'";
                    next TEST;
                }
            }

            $order->discard_changes->payments->delete;
            $shipment->discard_changes->shipment_holds->delete;
            $shipment->shipment_hold_logs->delete;
            $shipment->shipment_status_logs->delete;

            # setup the Shipment
            $self->_setup_shipment_record( $shipment, {
                # using DDU Hold as the default will cause the SLAs to get re-applied
                shipment_status_id  => $setup->{start_shipment_status} // $SHIPMENT_STATUS__DDU_HOLD,
                shipment_address_id => ( $setup->{address} ? $setup->{address}->id : $good_address->id ),
                # NULL the SLA fields
                sla_priority        => undef,
                sla_cutoff          => undef,
            } );

            # create the Hold Reason Manually
            if ( $setup->{start_hold_reason} ) {
                $shipment->shipment_holds->create( {
                    shipment_hold_reason_id => $setup->{start_hold_reason},
                    operator_id             => $APPLICATION_OPERATOR_ID,
                    comment                 => '',
                    hold_date               => \'now()',
                } );
            }

            # set-up requirements for Payment & PSP
            $self->_setup_payment_and_psp( {
                order               => $order,
                payment_method      => $setup->{payment_method} || 'thirdparty',
                third_party_status  => $setup->{third_party_status},
            } );

            # update the Shipment Status
            # using one of the two methods
            if ( $update_method_to_use eq 'update_status' ) {
                $shipment->update_status(
                    $setup->{set_shipment_status},
                    $APPLICATION_OPERATOR_ID,
                );
            }
            elsif ( $update_method_to_use eq 'update_shipment_status' ) {
                update_shipment_status(
                    $self->dbh,
                    $shipment->id,
                    $setup->{set_shipment_status},
                    $APPLICATION_OPERATOR_ID,
                );
            }
            else {
                fail( "Don't know what to do with the Update Method: '${update_method_to_use}'" );
                next METHOD;
            }

            # check Shipment Status
            cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $expect->{shipment_status},
                            "Shipment Status is as Expected" );

            # check SLA has or hasn't been updated
            if ( $expect->{sla_updated} ) {
                ok( defined $shipment->sla_priority, "Shipment's SLA has been Updated" );
            }
            else {
                ok( !defined $shipment->sla_priority, "Shipment's SLA has NOT been Updated" );
            }

            # check for Hold Reasons
            if ( $expect->{hold_reason} ) {
                cmp_ok( $shipment->shipment_holds->count, '==', 1,
                            "Shipment has One Hold Reason" );
                my $got_reason = $shipment->shipment_holds->first;
                cmp_ok( $got_reason->shipment_hold_reason_id, '==', $expect->{hold_reason},
                            "and the Hold Reason is as Expected" ) or diag "====> " . $shipment->shipment_holds->first->shipment_hold_reason->reason;
            }
            else {
                cmp_ok( $shipment->shipment_holds->count, '==', 0,
                            "Shipment has NO Hold Reasons" ) or diag "====> " . $shipment->shipment_holds->first->shipment_hold_reason->reason;
            }
        }
    }
}

=head2 test_validate_address_change_with_psp

Tests the 'validate_address_change_with_psp' method that tells
the PSP that an Shipment Address Change has occured and whether
and returns whether that Address is Valid or Not.

=cut

sub test_validate_address_change_with_psp : Tests {
    my $self = shift;

    my %tests = (
        "Shipment is NOT a Standard Class Shipment" => {
            setup => {
                shipment => {
                    shipment_class_id => $SHIPMENT_CLASS__EXCHANGE,
                },
            },
            expect => 1,
        },
        "Payment has already been Taken" => {
            setup => {
                payment => {
                    fulfilled => 1,
                },
            },
            expect => 1,
        },
        "Payment Method does not require PSP Notification" => {
            setup => {
                payment_method => {
                    notify_psp_of_address_change => 0,
                },
            },
            expect => 1,
        },
        "Order not paid using a Payment (using Store Credit)" => {
            setup => {
                no_payment => 1,
            },
            expect => 1,
        },
        "Shipment Address is Valid" => {
            setup => {
                psp_response => 'address_valid',
            },
            expect => 1,
        },
        "Shipment Address NOT Valid" => {
            setup => {
                psp_response => 'address_invalid',
            },
            expect => 0,
        },
        "A Failure in the Call to the PSP" => {
            setup => {
                psp_response => 'failure',
            },
            expect => 0,
        },
        "A General Error Response with the call to the PSP" => {
            setup => {
                psp_response => 'general_error',
            },
            expect => 0,
        },
    );

    # get any Payment Method
    my $payment_method = $self->rs('Orders::PaymentMethod')->first;
    # store original setting to be restored later
    my $orig_notify_psp_flag = $payment_method->notify_psp_of_address_change;

    my $good_address  = Test::XTracker::Data->create_order_address_in('current_dc');
    my $order_details = $self->{data_helper}->new_order(
        channel => $self->{channel},
        address => $good_address,
    );
    my $order    = $order_details->{order_object};
    my $shipment = $order_details->{shipment_object};

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        $order->discard_changes->payments->delete;
        $shipment->discard_changes;

        # setup the Payment Method
        $payment_method->discard_changes->update( {
            notify_psp_of_address_change => 1,
            %{ $setup->{payment_method} // {} },
        } );

        # setup the Payment for the Order
        Test::XTracker::Data->create_payment_for_order( $order, {
            %{ $self->{payment_args} },
            %{ $setup->{payment} // {} },
            payment_method => $payment_method,
        } ) unless ( $setup->{no_payment} );

        # setup the Shipment
        $self->_setup_shipment_record( $shipment, {
            shipment_class_id => $SHIPMENT_CLASS__STANDARD,
            %{ $setup->{shipment} // {} },
        } );

        Test::XTracker::Mock::PSP->set_reauthorise_address_response(
            $setup->{psp_response} // 'failure'
        );

        my $got = $shipment->validate_address_change_with_psp();
        cmp_ok( $got, '==', $expect, "Return Value as Expected: '${expect}'" );
    }

    # restore notify PSP original setting
    $payment_method->update( { notify_psp_of_address_change => $orig_notify_psp_flag } );
}

=head2 test_should_notify_psp_when_basket_changes

Tests the method 'should_notify_psp_when_basket_changes' returns the correct
value. This method calls the 'Public::Orders->payment_method_requires_basket_updates'
method which is tested in the 'Test::XTracker::Schema::Result::Public::Orders'
test class.

=cut

sub test_should_notify_psp_when_basket_changes : Tests {
    my $self = shift;

    $self->schema->txn_begin();

    my $order_details = $self->{data_helper}->new_order();
    my $order         = $order_details->{order_object}->discard_changes;
    my $shipment      = $order_details->{shipment_object};

    # make sure a Payment has been created for the Order
    my $payment = $order->payments->first;
    $payment->delete        if ( $payment );
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    $payment = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );
    $shipment->discard_changes;     # make sure Shipment is up to date


    note "Test when Payment Method DOESN'T Require PSP to be Notifed";
    Test::XTracker::Data->change_payment_to_not_require_psp_notification_of_basket_changes( $payment );
    my $got = $shipment->should_notify_psp_when_basket_changes;
    cmp_ok( $got, '==', 0, "'should_notify_psp_when_basket_changes' returned FALSE" );


    note "Test when Payment Method DOES Require PSP to be Notifed";
    Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );
    $got = $shipment->should_notify_psp_when_basket_changes;
    cmp_ok( $got, '==', 1, "'should_notify_psp_when_basket_changes' returned TRUE" );


    note "Test when Shipment is NOT Linked to an Order";
    $shipment->link_orders__shipment->delete;
    $got = $shipment->discard_changes->should_notify_psp_when_basket_changes;
    cmp_ok( $got, '==', 0, "'should_notify_psp_when_basket_changes' returned FALSE" );


    $self->schema->txn_rollback();
}

=head2 test_method_allow_editing_of_shipping_address_post_settlement

Tests the method 'allow_editing_of_shipping_address_post_settlement'
return correct result depending on Payment Method used.

=cut

sub test_method_allow_editing_of_shipping_address_post_settlement : Tests {
    my $self = shift;

    $self->schema->txn_begin();

    my $order_details = $self->{data_helper}->new_order();
    my $order         = $order_details->{order_object}->discard_changes;
    my $shipment      = $order_details->{shipment_object};

    # make sure a Payment has been created for the Order
    my $payment = $order->payments->first;
    $payment->delete        if ( $payment );
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    $payment = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );
    $shipment->discard_changes;     # make sure Shipment is up to date


    note "Test when Payment Method Allow Changes to Shipping Address post Settlement";
    Test::XTracker::Data->change_payment_to_allow_change_of_shipping_address_post_settlement( $payment );
    my $got = $shipment->allow_editing_of_shipping_address_post_settlement;
    cmp_ok( $got, '==', 1, "'allow_editing_of_shipping_address_post_settlement' returned TRUE" );


    note "Test when Payment Method does NOT Allow Changes to Shipping Address post Settlement";
    Test::XTracker::Data->change_payment_to_not_allow_change_of_shipping_address_post_settlement( $payment );
    $got = $shipment->allow_editing_of_shipping_address_post_settlement;
    cmp_ok( $got, '==', 0, "'allow_editing_of_shipping_address_post_settlement' returned FALSE" );


    note "Test when Shipment is NOT Linked to an Order";
    $shipment->link_orders__shipment->delete;
    $got = $shipment->discard_changes->allow_editing_of_shipping_address_post_settlement;
    cmp_ok( $got, '==', 1, "'allow_editing_of_shipping_address_post_settlement' returned TRUE" );


    $self->schema->txn_rollback();
}

=head2 test_notifying_psp_when_basket_changes_for_shipment

This tests the 'Public::Shipment' method 'notify_psp_of_item_changes' when called
for Standard, Exchange, Re-Shipment or Replacement class Shipments.

It will check that the correct method on an instance of 'XT::Domain::Payment::Basket'
has been called when the Payment is at different states.

=cut

sub test_notifying_psp_when_basket_changes_for_shipment : Tests {
    my $self = shift;

    $self->schema->txn_begin();

    # create a new Order and use its Shipment to dump newly Created
    # Shipment Items in because of the Triggers that happen on a
    # Shipment Item it can be difficult to Delete them
    my $dumping_shipment_id = $self->{data_helper}->new_order()->{shipment_object}->id;

    my $order_details  = $self->_create_new_order_suitable_for_item_change( { channel => $self->{channel} } );
    my $order          = $order_details->{order_object}->discard_changes;
    my $shipment       = $order_details->{shipment_object};
    my $shipment_items = $order_details->{shipment_items};
    my $new_ship_items_rs = $order_details->{new_ship_items_rs};

    # make sure a Payment has been created for the Order
    my $payment = $self->_create_payment_for_order( $order );

    # set the Payment Method for the Payment
    # to require the PSP to be updated
    Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );

    # mock XT::Domain::Basket using a common method
    # to capture what Basket methods are called
    my %basket_monitor;
    my $mock_basket = $self->_mock_payment_basket( [ qw( send_basket_to_psp update_psp_with_item_changes ) ], \%basket_monitor );


    # $item_details holds a Hash of Items keyed as 'item_1', 'item_2'
    # etc. and so the Items will be referenced as such in the following
    # Test specifications
    my $item_details = $order_details->{shipment_item_details};

    my %tests = (
        "Standard Class Shipment - Prior to Payment being Fulfilled" => {
            setup => {
                shipment_class_id      => $SHIPMENT_CLASS__STANDARD,
                payment_fulfilled_flag => 0,
                items_to_change        => {
                    # list each Item and the Variant in '$item_details'
                    # which you want the Item's Variant to be changed to
                    item_1 => 'alt_variant',
                },
            },
            expect => {
                method_called => 'send_basket_to_psp',
            },
        },
        "Standard Class Shipment - After Payment has been Fulfilled" => {
            setup => {
                shipment_class_id      => $SHIPMENT_CLASS__STANDARD,
                payment_fulfilled_flag => 1,
                items_to_change        => {
                    item_1 => 'alt_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                check_changes_passed => 1,
            },
        },
        "Standard Class Shipment - After Payment has been Fulfilled, with Multiple Changes" => {
            setup => {
                shipment_class_id      => $SHIPMENT_CLASS__STANDARD,
                payment_fulfilled_flag => 1,
                items_to_change        => {
                    item_1 => 'alt_variant',
                    item_2 => 'alt_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                check_changes_passed => 1,
            },
        },
        "Standard Class Shipment - After Payment has been Fulfilled, where SKU is Changed for the same SKU" => {
            setup => {
                shipment_class_id      => $SHIPMENT_CLASS__STANDARD,
                payment_fulfilled_flag => 1,
                items_to_change        => {
                    item_1 => 'orig_variant',
                    item_2 => 'orig_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                check_changes_passed => 1,
            },
        },
        "Exchange Class Shipment - Before 'Packing Has Started' and After Payment has been Fulfilled" => {
            setup => {
                shipment_class_id      => $SHIPMENT_CLASS__EXCHANGE,
                has_packing_started    => 0,
                payment_fulfilled_flag => 1,
                items_to_change        => {
                    item_1 => 'alt_variant',
                    item_2 => 'alt_variant',
                },
            },
            expect => {
                no_method_called => 1,
            },
        },
        "Exchange Class Shipment - Before 'Packing Has Started' and Before Payment has been Fulfilled (shouldn't happen in real world)" => {
            setup => {
                shipment_class_id      => $SHIPMENT_CLASS__EXCHANGE,
                has_packing_started    => 0,
                payment_fulfilled_flag => 0,
                items_to_change        => {
                    item_1 => 'alt_variant',
                    item_2 => 'orig_variant',
                },
            },
            expect => {
                no_method_called => 1,
            },
        },
        "Exchange Class Shipment - After 'Packing Has Started' and After Payment has been Fulfilled" => {
            setup => {
                shipment_class_id      => $SHIPMENT_CLASS__EXCHANGE,
                has_packing_started    => 1,
                payment_fulfilled_flag => 1,
                items_to_change        => {
                    item_1 => 'alt_variant',
                    item_2 => 'alt_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                check_changes_passed => 1,
            },
        },
        "Exchange Class Shipment - After 'Packing Has Started' and Before Payment has been Fulfilled (shouldn't happen in real world)" => {
            setup => {
                shipment_class_id      => $SHIPMENT_CLASS__EXCHANGE,
                has_packing_started    => 1,
                payment_fulfilled_flag => 0,
                items_to_change        => {
                    item_1 => 'alt_variant',
                    item_2 => 'orig_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                check_changes_passed => 1,
            },
        },
        "Re-Shipment Class Shipment" => {
            setup => {
                shipment_class_id      => $SHIPMENT_CLASS__RE_DASH_SHIPMENT,
                payment_fulfilled_flag => 1,
                items_to_change        => {
                    item_1 => 'alt_variant',
                    item_2 => 'orig_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                check_changes_passed => 1,
            },
        },
        "Replacement Class Shipment" => {
            setup => {
                shipment_class_id      => $SHIPMENT_CLASS__REPLACEMENT,
                payment_fulfilled_flag => 1,
                items_to_change        => {
                    item_2 => 'alt_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                check_changes_passed => 1,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # clear the Basket Monitor
        %basket_monitor = ();

        # move the new Shipment Items to another Shipment (because it's a pain to Delete them!)
        $new_ship_items_rs->reset->update( { shipment_id => $dumping_shipment_id } );

        # assign the Original Variants to the Shipment Items
        foreach my $details ( values %{ $item_details } ) {
            $details->{item}->discard_changes->update( {
                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                variant_id              => $details->{orig_variant}->id,
            } );
        }

        # now set-up the Shipment & Items according to the Spec.
        $shipment->discard_changes->update( {
            shipment_class_id   => $setup->{shipment_class_id},
            has_packing_started => $setup->{has_packing_started} // 0,
        } );

        # set the Payment 'fulfilled' flag
        $payment->discard_changes->update( { fulfilled => $setup->{payment_fulfilled_flag} } );

        # change the Items by Creating New ones and Cancelling the old
        my $item_changes = $self->_change_shipment_item( $shipment, $item_details, $setup->{items_to_change} );

        # this makes sure everything has definitely been created
        $shipment->discard_changes;

        # notify the PSP of the Changes
        $shipment->notify_psp_of_item_changes( $item_changes );

        if ( $expect->{no_method_called} ) {
            ok( !exists $basket_monitor{method_called}, "No 'XT::Domain::Payment::Basket' method was called" )
                                or diag "ERROR - 'XT::Domain::Payment::Basket' method was called: " . p( %basket_monitor );
        }
        else {
            # test what Basket method was Called
            is( $basket_monitor{method_called}, $expect->{method_called},
                                "expected 'XT::Domain::Payment::Basket' method called" );
        }

        # check the Changes passed through to the Method
        if ( $expect->{check_changes_passed} ) {
            cmp_deeply( $basket_monitor{params_passed}->[0], $item_changes,
                            "and expected Params were passed to the method" )
                                or diag "ERROR - with Params passed:\n" .
                                        "Got: " . p( $basket_monitor{params_passed}->[0] ) . "\n" .
                                        "Expected: " . p( $item_changes );
        }
    }


    $self->schema->txn_rollback();
}

=head2 test_notify_psp_of_exchanged_items

This tests the 'Public::Shipment' method 'notify_psp_of_exchanged_items' which is called
for Exchange Shipments by the 'XTracker::Database::OrderPayment::process_payment' function
when Packing is started on an Exchange Shipment.

It will check that the correct method on an instance of 'XT::Domain::Payment::Basket'
has been called with the correct changes.

=cut

sub test_notify_psp_of_exchanged_items : Tests {
    my $self = shift;

    $self->schema->txn_begin();

    my $order_details  = $self->_create_new_order_suitable_for_item_change( { channel => $self->{channel} } );
    my $order          = $order_details->{order_object};
    my $shipment       = $order_details->{shipment_object};
    my $shipment_items = $order_details->{shipment_items};

    # make sure a Payment has been created for the Order
    my $payment = $self->_create_payment_for_order( $order );

    # set the Payment Method for the Payment
    # to require the PSP to be updated
    Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );

    # $item_details holds a Hash of Items keyed as 'item_1', 'item_2'
    # etc. and so the Items will be referenced as such in the following
    # Test specifications
    my $item_details = $order_details->{shipment_item_details};

    # mock XT::Domain::Basket using a common method
    # to capture what Basket methods are called
    my %basket_monitor;
    my $mock_basket = $self->_mock_payment_basket( [ 'update_psp_with_item_changes' ], \%basket_monitor );

    my %tests = (
        "Exchange Shipment with One Item" => {
            setup => {
                items_to_exchange => {
                    item_1 => 'alt_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                # list all of the Items that should get passed to the method
                changes_passed => [ qw(
                    item_1
                ) ],
            },
        },
        "Exchange Shipment with One Item that's the same as the Original" => {
            setup => {
                items_to_exchange => {
                    item_1 => 'orig_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                changes_passed => [ qw(
                    item_1
                ) ],
            },
        },
        "Exchange Shipment with Two Items" => {
            setup => {
                items_to_exchange => {
                    item_1 => 'alt_variant',
                    item_2 => 'alt_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                changes_passed => [ qw(
                    item_1
                    item_2
                ) ],
            },
        },
        "Exchange Shipment with Two Items that are the same as their Originals" => {
            setup => {
                items_to_exchange => {
                    item_1 => 'orig_variant',
                    item_2 => 'orig_variant',
                },
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                changes_passed => [ qw(
                    item_1
                    item_2
                ) ],
            },
        },
        "Exchange Shipment with Two Items and then One is Cancelled" => {
            setup => {
                items_to_exchange => {
                    item_1 => 'alt_variant',
                    item_2 => 'alt_variant',
                },
                items_to_cancel_after_exchange => [ qw(
                    item_1
                ) ],
            },
            expect => {
                method_called => 'update_psp_with_item_changes',
                changes_passed => [ qw(
                    item_2
                ) ],
            },
        },
        "Exchange Shipment with Two Items and Both are Cancelled - nothing should happen" => {
            setup => {
                items_to_exchange => {
                    item_1 => 'alt_variant',
                    item_2 => 'alt_variant',
                },
                items_to_cancel_after_exchange => [ qw(
                    item_1
                    item_2
                ) ],
            },
            expect => {
                no_psp_update => 1,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # clear the Basket Monitor
        %basket_monitor = ();

        # reset Shipment & Return Items
        foreach my $details ( values %{ $item_details } ) {
            $details->{item}->discard_changes->update( {
                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED,
            } );
        }

        # change the Exchange Items by Creating New ones and Cancelling the old
        my ( $return, $item_changes ) = $self->_create_exchange_for_shipment( $shipment, $item_details, $setup );
        my $exchange_shipment = $return->exchange_shipment;

        # notify the PSP of the Changes
        $exchange_shipment->notify_psp_of_exchanged_items();

        # test whether a Basket method was Called or Not
        if ( $setup->{no_psp_update} ) {
            ok( !exists( $basket_monitor{method_called} ), "No call to 'XT::Domain::Payment::Basket' was made" )
                            or diag "ERROR - a call was made: " . p( %basket_monitor );
        }
        else {
            is( $basket_monitor{method_called}, $expect->{method_called},
                            "expected 'XT::Domain::Payment::Basket' method called" );
        }

        # check the Changes passed through to the Method
        if ( my $changes_passed = $expect->{changes_passed} ) {
            my @expected_changes = map { $item_changes->{ $_ } } @{ $changes_passed };

            cmp_deeply( $basket_monitor{params_passed}->[0], bag( @expected_changes ),
                                    "and expected Params were passed to the method" )
                            or diag "ERROR - with Params passed:\n" .
                                    "Got: " . p( $basket_monitor{params_passed}->[0] ) . "\n" .
                                    "Expected: " . p( @expected_changes );
        }

        # Remove the Return
        $return->discard_changes->return_items->search_related('return_item_status_logs')->delete;
        $return->return_items->search_related('link_delivery_item__return_items')->delete;
        $return->return_items->delete;
        $return->link_delivery__returns->delete;
        $return->return_status_logs->delete;
        $return->delete;

        # remove the Link between the Exchange Shipment and the Order
        $exchange_shipment->link_orders__shipment->delete;
    }


    $self->schema->txn_rollback();
}

=head2 test_notify_psp_of_basket_changes_or_cancel_payment

Tests the method 'notify_psp_of_basket_changes_or_cancel_payment' which
will send a Basket update to the PSP (prior to Settlement) or if the
Value of the Order has been reduced so that any Store Credit now covers
the cost of the Order then it will call the PSP to Cancel the Payment
by Cancelling the Pre-Auth.

=cut

sub test_notify_psp_of_basket_changes_or_cancel_payment : Tests {
    my $self = shift;

    $self->schema->txn_begin();

    my $order_details = $self->{data_helper}->new_order();
    my $order         = $order_details->{order_object};
    my $shipment      = $order_details->{shipment_object};

    # PSP end-points
    my $psp_cancel_end_point  = '/cancel';
    my $psp_payment_amendment = '/payment-amendment';

    # use '%mock_basket_hash' to control what the Mock '*::Payment::Basket' object will do
    my %mock_basket_hash;
    my $mock_basket = $self->_mock_payment_basket( [ 'get_balance' ], \%mock_basket_hash );

    my $json = JSON->new();

    # stop mocking the 'cancel_preauth' method, so that it will use LWP
    Test::XTracker::Mock::PSP->use_original_method('cancel_preauth');

    # get the Mock LWP as well so we can trap to requests being made to the PSP
    Test::XTracker::Mock::PSP->enable_mock_lwp();
    my $mock_lwp = Test::XTracker::Mock::PSP->get_mock_lwp;

    # use this ResultSet to check for the Removed Payment Order Note being created
    my $context_for_test = 'Test Context';
    my $order_note_rs = $order->order_notes->search(
        {
            note => { ILIKE => '%Removed%Payment%' . $context_for_test . '%' },
        }
    );

    my %tests = (
        "Balance is ZERO" => {
            setup => {
                return_balance => 0,
            },
            expect => {
                end_point => $psp_cancel_end_point,
                no_payment => 1,
                retval => {
                    payment_deleted                => 1,
                    preauth_successfully_cancelled => 1,
                },
            },
        },
        "Balance is Less than ZERO" => {
            setup => {
                return_balance => -123,
            },
            expect => {
                end_point => $psp_cancel_end_point,
                no_payment => 1,
                retval => {
                    payment_deleted                => 1,
                    preauth_successfully_cancelled => 1,
                },
            },
        },
        "Balance is Greater than ZERO" => {
            setup => {
                return_balance => 123,
            },
            expect => {
                end_point => $psp_payment_amendment,
                check_payment_still_exists=> 1,
                retval => {
                    psp_sent_basket_update => 1,
                },
            },
        },
        "Balance is Less than ZERO but Payment Method doesn't require PSP Update" => {
            setup => {
                no_psp_basket_update => 1,
                return_balance       => -123,
            },
            expect => {
                end_point => undef,
                retval => undef,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # reset the Order Details
        $order->discard_changes->order_notes->delete;
        my $payment = $self->_create_payment_for_order( $order );

        if ( !$setup->{no_psp_basket_update} ) {
            Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );
        }
        else {
            Test::XTracker::Data->change_payment_to_not_require_psp_notification_of_basket_changes( $payment );
        }

        # set what 'get_balance' should return
        $mock_basket_hash{get_balance_return_value} = $setup->{return_balance};

        # setup an OK response from the PSP
        $mock_lwp->clear_all->add_response_OK( $json->encode( { returnCodeResult => 1, reference => 'TEST' } ) );

        my $got = $shipment->notify_psp_of_basket_changes_or_cancel_payment( {
            context     => $context_for_test,
            operator_id => $self->{app_operator}->id,
        } );
        cmp_deeply( $got, $expect->{retval},
                    "'notify_psp_of_basket_changes_or_cancel_payment' returned the expected Response" )
                            or diag "ERROR - Unexpected Response Returned -\n" .
                                    "Got: " . p( $got ) . "\n" .
                                    "Expected: " . p( $expect->{retval} );

        my $last_lwp_request = $mock_lwp->get_last_request();
        if ( my $expected_end_point = $expect->{end_point} ) {
            like( $last_lwp_request->as_string, qr/${expected_end_point}/,
                        "Request to PSP on expected End Point: '${expected_end_point}' was made" );
        }
        else {
            ok( !defined $last_lwp_request, "No request was made to the PSP" )
                        or diag "ERROR - a Request was made to the PSP: " . p( $last_lwp_request );
        }

        if ( $expect->{no_payment} ) {
            cmp_ok( $order->discard_changes->payments->count, '==', 0, "'orders.payment' record has been Removed" );
            cmp_ok( $order->replaced_payments->count, '==', 1, "'orders.replaced_payment' has been Created" );
            cmp_ok( $order_note_rs->reset->count, '==', 1, "and an Order Note was created which mentions the Payment being Removed" );
        }

        if ( $expect->{check_payment_still_exists} ) {
            cmp_ok( $order->discard_changes->payments->count, '==', 1, "'orders.payment' record is Still there" );
        }
    }

    $self->schema->txn_rollback();

    Test::XTracker::Mock::PSP->mock_payment_service_client();
}

=head2 test_should_cancel_payment_after_forced_address_update

Tests the method 'should_cancel_payment_after_forced_address_update' returns the correct
value. This method calls the 'Public::Orders->payment_method_requires_payment_cancelled_if_forced_shipping_address_updated_used'
method which is tested in the 'Test::XTracker::Schema::Result::Public::Orders'
test class.

=cut

sub test_should_cancel_payment_after_forced_address_update : Tests() {
    my $self = shift;

    $self->schema->txn_begin();

    my $order_details = $self->{data_helper}->new_order();
    my $order         = $order_details->{order_object}->discard_changes;
    my $shipment      = $order_details->{shipment_object};

    # make sure a Payment has been created for the Order
    my $payment = $order->payments->first;
    $payment->delete        if ( $payment );
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    $payment = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );
    $shipment->discard_changes;     # make sure Shipment is up to date


    note "Test when Payment Method doesn't want the Payment to be Cancelled when doing a Forced Address Update";
    Test::XTracker::Data->change_payment_to_not_cancel_payment_after_force_address_update( $payment );
    my $got = $shipment->should_cancel_payment_after_forced_address_update;
    cmp_ok( $got, '==', 0, "'should_cancel_payment_after_forced_address_update' returned FALSE" );


    note "Test when Payment Method does want to Cancel the Payment when doing a Forced Address Updated";
    Test::XTracker::Data->change_payment_to_cancel_payment_after_force_address_update( $payment );
    $got = $shipment->should_cancel_payment_after_forced_address_update;
    cmp_ok( $got, '==', 1, "'should_cancel_payment_after_forced_address_update' returned TRUE" );


    note "Test when Shipment is NOT Linked to an Order";
    $shipment->link_orders__shipment->delete;
    $got = $shipment->discard_changes->should_cancel_payment_after_forced_address_update;
    cmp_ok( $got, '==', 0, "'should_cancel_payment_after_forced_address_update' returned FALSE" );


    $self->schema->txn_rollback();
}

=head2 test_release_from_hold

Tests that the 'release_from_hold' method Releases the Shipment from Hold but also
allows for when the Shipment is kept on Hold for Invalid Characters in Shipping Address
or Third Party Payment Status reasons and doesn't remove the Hold Reason.

=cut

sub test_release_from_hold : Tests {
    my $self    = shift;

    my @tests = (
        ["Release Shipment from a Hold" => {
            setup => {
                payment_method  => 'creditcard',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__PROCESSING,
            },
        }],
        ['Releasing with invalid address goes on hold' => {
            setup => {
                payment_method      => 'creditcard',
                address             => Test::XTracker::Data->create_order_address_in('US_broken'),
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS,
            },
        }],
        ["Release Shipment from a Hold with Third Party Payment 'ACCEPTED'" => {
            setup => {
                payment_method      => 'thirdparty',
                third_party_status  => 'ACCEPTED',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__PROCESSING,
            },
        }],
        ["When Shipment is on Hold because Shipping Address has Invalid Characters, Shouldn't be Released" => {
            setup => {
                payment_method  => 'creditcard',
                hold_reason     => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
                address         => Test::XTracker::Data->create_order_address_in('NonASCIICharacters'),
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
            },
        }],
        ["When Third Party Status is 'PENDING', Shouldn't be Released" => {
            setup => {
                payment_method      => 'thirdparty',
                third_party_status  => 'PENDING',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
            },
        }],
        ["When Third Party Status is 'REJECTED', Shouldn't be Released" => {
            setup => {
                payment_method      => 'thirdparty',
                third_party_status  => 'REJECTED',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
            },
        }],
        ["When Shipment Starts on Hold for Third Party Reason, it's Still on Hold afterwards" => {
            setup => {
                payment_method      => 'thirdparty',
                hold_reason         => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
                third_party_status  => 'PENDING',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
            },
        }],
    );

    my $good_address  = Test::XTracker::Data->create_order_address_in('current_dc');
    my $order_details = $self->{data_helper}->new_order(
        channel => $self->{channel},
        address => $good_address,
    );
    my $order    = $order_details->{order_object};
    my $shipment = $order_details->{shipment_object};
    ok( $shipment, 'created shipment ' . $shipment->id );

    my $mock_shipment = Test::MockObject::Extends->new($shipment);
    $mock_shipment->mock(should_hold_if_invalid_address => sub{1});
    foreach my $test ( @tests ) {
        my ($label, $data) = @$test;
        subtest "Testing: ${label}" => sub {
            my ($setup, $expect) = @{$data}{qw/setup expect/};

            $order->discard_changes->payments->delete;
            $shipment->discard_changes->shipment_holds->delete;
            $shipment->discard_changes->shipment_hold_logs->delete;
            $shipment->shipment_status_logs->delete;

            # set-up the Shipment
            $self->_setup_shipment_record( $shipment, {
                shipment_status_id  => $SHIPMENT_STATUS__HOLD,
                shipment_address_id => ( $setup->{address} ? $setup->{address}->id : $good_address->id ),
                hold_reason         => $setup->{hold_reason} // $SHIPMENT_HOLD_REASON__OTHER,
            } );

            # set-up requirements for Payment & PSP
            $self->_setup_payment_and_psp( {
                order               => $order,
                payment_method      => $setup->{payment_method},
                third_party_status  => $setup->{third_party_status},
            } );

            # Release the Shipment Hold
            $shipment->release_from_hold(
                operator_id => $APPLICATION_OPERATOR_ID,
            );
            $shipment->discard_changes;

            cmp_ok( $shipment->shipment_status_id, '==', $expect->{shipment_status},
                                "Shipment Status is as Expected" );

            if ( $expect->{hold_reason} ) {
                cmp_ok( $shipment->shipment_holds->count, '==', 1,
                                "the Shipment has ONE 'shipment_hold' record" );
                my $hold = $shipment->shipment_holds->first;
                cmp_ok( $hold->shipment_hold_reason_id, '==', $expect->{hold_reason},
                                "and the Hold Reason is as Expected" )
                                        or diag "====> " . $shipment->shipment_holds->first->shipment_hold_reason->reason;
            }
            else {
                cmp_ok( $shipment->shipment_holds->count, '==', 0,
                                "Shipment has NO Hold Reasons" )
                                        or diag "====> " . $shipment->shipment_holds->first->shipment_hold_reason->reason;
            }
        }
    };
}

=head2 test_get_item_shipping_attributes

Tests the 'get_item_shipping_attributes' to make sure that its return value
has the expected structure.

=cut

sub test_get_item_shipping_attributes : Tests() {
    my $self = shift;

    my $order_data = Test::XTracker::Data::Order->create_new_order( {
        channel  => $self->{channel},
        products => 3,
    } );
    my $shipment = $order_data->{shipment_object};
    my @products = map { $_->{product} } @{ $order_data->{product_objects} };
    my @ship_restrictions = @{ $self->{ship_restrictions} };

    # remove all Shipping Restrictions from all of the Products
    foreach my $product ( @products ) {
        $product->link_product__ship_restrictions->delete;
    }

    # this is what will be expected to be returned for the
    # shipping restrictions, make it so that there is one
    # Product with no Restrictions, another with just one
    # and another with more than one and then use this
    # to actually apply the restrictions to the products
    my %expected_restrictions = (
        $products[0]->id => {
            $ship_restrictions[0]->id => 1,
        },
        $products[1]->id => {
            $ship_restrictions[1]->id => 1,
            $ship_restrictions[2]->id => 1,
            $ship_restrictions[3]->id => 1,
        },
        $products[2]->id => {},
    );
    # now use the 'codes' for the above to pass to 'add_shipping_restrictions'
    $products[0]->add_shipping_restrictions( {
        restriction_codes => [
            $ship_restrictions[0]->code,
        ],
    } );
    $products[1]->add_shipping_restrictions( {
        restriction_codes => [
            $ship_restrictions[1]->code,
            $ship_restrictions[2]->code,
            $ship_restrictions[3]->code,
        ],
    } );

    # this is what will be expected to be returned for every Product
    # the values can be ignored just testing that the keys exist
    my %common_expected = (
        map { $_ => ignore() } qw(
            box_id
            cites_restricted
            country_id
            fabric_content
            fish_wildlife
            fish_wildlife_source
            height
            is_hazmat
            legacy_countryoforigin
            length
            packing_note
            product_id
            scientific_term
            weight
            width
        )
    );

    # what should be returned by 'get_item_shipping_attributes'
    my %expected = (
        $products[0]->id => superhashof( {
                %common_expected,
                ship_restriction_ids => $expected_restrictions{ $products[0]->id },
            } ),
        $products[1]->id => superhashof( {
                %common_expected,
                ship_restriction_ids => $expected_restrictions{ $products[1]->id },
            } ),
        $products[2]->id => superhashof( {
                %common_expected,
                ship_restriction_ids => $expected_restrictions{ $products[2]->id },
            } ),
    );

    my $got = $shipment->discard_changes->get_item_shipping_attributes();
    cmp_deeply( $got, \%expected, "'get_item_shipping_attributes' returned the expected structure" )
                        or diag "====> ERROR: Structure Not as Expected: Got: " . p( $got ) . "\n" .
                                "Expected: " . p( %expected );
}


sub _create_shipment_with_shipping_account {
    my ($self, $channel, $carrier_name) = @_;

    my $ship_account = Test::XTracker::Data->get_shipping_account($channel->id(), $carrier_name);

    my $shipment = Test::XTracker::Data->create_shipment({
        shipping_account_id => $ship_account->id(),
    });
    note("Created a shipment on '"
        . $channel->name()
        . "' channel for shipping account: "
        . $ship_account->name()
    );
    return $shipment;
}

sub _new_shipment {
    my ($self, $sample, $selected) = @_;

    my $shipment;
    if ($sample) {
        my $channel = Test::XTracker::Data->any_channel;
        my $variant = (Test::XTracker::Data->grab_products({
            channel_id => $channel->id,
            force_create => 1,
        }))[1][0]->{variant};
        $shipment = $self->db__samples__create_shipment({
            channel_id    => $channel->id,
            variant_id    => $variant->id,
        });

    } else {
        $shipment = $self->{data_helper}->new_order->{shipment_object};
    }

    if ($selected) {
        $_->set_selected($APPLICATION_OPERATOR_ID) for $shipment->shipment_items();
    }

    return $shipment;
}

sub test_cancel :Tests {
    my $self = shift;

    my $operator_id = $APPLICATION_OPERATOR_ID;

    for my $test (
        {
            label                       => 'test cancelling active shipment',
            is_active                   => 1,
            is_sample                   => 0,
            do_pws_update               => 1,
            items_are_selected          => 1,
            only_allow_selected_items   => 0,
        },
        {
            label                       => 'test cancelling inactive shipment',
            is_active                   => 0,
            is_sample                   => 0,
            do_pws_update               => 0,
            items_are_selected          => 1,
            only_allow_selected_items   => 0,
        },
        {
            label                       => 'test cancelling active sample shipment',
            is_active                   => 1,
            is_sample                   => 1,
            do_pws_update               => 0,
            items_are_selected          => 1,
            only_allow_selected_items   => 1,
        },
        {
            label                       => 'test cancelling active sample shipment (stock discrepancy)',
            is_active                   => 1,
            is_sample                   => 1,
            do_pws_update               => 0,
            items_are_selected          => 1,
            only_allow_selected_items   => 1,
            customer_issue_type_id      => $CUSTOMER_ISSUE_TYPE__8__STOCK_DISCREPANCY,
        },
        {
            label                       => 'test cancelling active sample shipment (unselected)',
            is_active                   => 1,
            is_sample                   => 1,
            do_pws_update               => 0,
            items_are_selected          => 0,
            only_allow_selected_items   => 1,
        },
        {
            label                       => 'test cancelling inactive sample shipment',
            is_active                   => 0,
            is_sample                   => 1,
            do_pws_update               => 0,
            items_are_selected          => 1,
            only_allow_selected_items   => 0,
        },
    ) {
        subtest $test->{label} => sub {
            my $module = Test::MockModule->new('XTracker::Schema::Result::Public::Shipment');
            $module->mock('is_active', sub { return $test->{is_active}; });
            my $email_sent = 0;
            $module->mock(send_email => sub { $email_sent = 1; });

            my $shipment = $self->_new_shipment($test->{is_sample}, $test->{items_are_selected});

            my $pre_pws_log_count = $self->schema->resultset('Public::LogPwsStock')
                ->search->count();

            my $customer_issue_type_id
                = $test->{customer_issue_type_id}//$CUSTOMER_ISSUE_TYPE__7__FABRIC;
            if ($test->{only_allow_selected_items}
                && !$test->{items_are_selected}) {
                throws_ok {

                    $shipment->cancel(
                        operator_id                 => $operator_id,
                        customer_issue_type_id      => $customer_issue_type_id,
                        do_pws_update               => $test->{do_pws_update},
                        only_allow_selected_items   => $test->{only_allow_selected_items},
                    );

                } qr/Can only refuse item if it has a status of/,
                'Cancel dies because items are not in selected status';
                return;
            }

            $shipment->cancel(
                operator_id                 => $operator_id,
                customer_issue_type_id      => $customer_issue_type_id,
                do_pws_update               => $test->{do_pws_update},
                only_allow_selected_items   => $test->{only_allow_selected_items},
            );

            # Inactive shipments are not put on hold
            unless ( $test->{is_active} ) {
                ok(!$shipment->is_cancelled, q{shipment shouldn't be cancelled});
                return;
            }

            ok( $shipment->is_cancelled, 'shipment should be cancelled' )
                or diag q{... but it's } . $shipment->shipment_status->status;

            ok(
                my $log = $shipment->search_related('shipment_status_logs',
                    { shipment_status_id => $SHIPMENT_STATUS__CANCELLED },
                    { order_by           => { -desc => 'date' } }
                )->slice(0,0)->single,
                'should find related cancellation log row'
            );
            is( $log->operator_id, $operator_id, "operator_id should match" );

            my $post_pws_log_count = $self->schema->resultset('Public::LogPwsStock')
                ->search->count();
            is($post_pws_log_count, ($test->{do_pws_update}
                ? $pre_pws_log_count+1
                : $pre_pws_log_count
            ), ($test->{do_pws_update}
                ? 'PWS log has been updated'
                : 'PWS log has not been updated'
            ));

            ok($shipment->stock_transfer->is_cancelled(),
                'stock transfer has been cancelled too') if ($test->{is_sample});
            if ( $shipment->is_sample_shipment
             && ($test->{customer_issue_type_id}//0) == $CUSTOMER_ISSUE_TYPE__8__STOCK_DISCREPANCY
            ) {
                ok( $email_sent, 'sent a stock discrepancy sample email' );
            }
            else {
                ok( !$email_sent, 'no stock discrepancy sample email sent' );
            }
        };
    }
}

sub _shipment_date { return DateTime->new( year => 2013, month => 12, day => 4) }
sub _exchange_release_date { return DateTime->new( year => 2013, month => 12, day => 5) }
sub _order_date { return DateTime->new( year => 2013, month => 12, day => 6) }
sub _earliest_selection_date { return DateTime->new( year => 2013, month => 12, day => 7) }
sub _release_from_hold_date { return DateTime->new( year => 2013, month => 12, day => 8) }

sub test__get_shippable_requested_datetime :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Standard shipment',
            setup   => {
                shipment => {
                    mock => {
                        is_exchange             => 0,
                        is_replacement_class    => 0,
                        is_sample_shipment      => 0,
                        is_reshipment           => 0,
                        get_released_from_exchange_or_return_hold_datetime
                            => $self->_exchange_release_date(),
                        date                    => $self->_shipment_date(),
                        order                   => {
                            mock => {
                                date => $self->_order_date(),
                            },
                        },
                    },
                    validation_class => 'XTracker::Schema::Result::Public::Shipment',
                }
            },
            expected => {
                date => $self->_order_date(),
            },
        },

        {
            name    => 'Exchange shipment',
            setup   => {
                shipment => {
                    mock => {
                        is_exchange             => 1,
                        is_replacement_class    => 0,
                        is_sample_shipment      => 0,
                        is_reshipment           => 0,
                        get_released_from_exchange_or_return_hold_datetime
                            => $self->_exchange_release_date(),
                        date                    => $self->_shipment_date(),
                        order                   => {
                            mock => {
                                date => $self->_order_date(),
                            },
                        },
                    },
                    validation_class => 'XTracker::Schema::Result::Public::Shipment',
                }
            },
            expected => {
                date => $self->_exchange_release_date(),
            },
        },

        {
            name    => 'Replacement shipment',
            setup   => {
                shipment => {
                    mock => {
                        is_exchange             => 0,
                        is_replacement_class    => 1,
                        is_sample_shipment      => 0,
                        is_reshipment           => 0,
                        get_released_from_exchange_or_return_hold_datetime
                            => $self->_exchange_release_date(),
                        date                    => $self->_shipment_date(),
                        order                   => {
                            mock => {
                                date => $self->_order_date(),
                            },
                        },
                    },
                    validation_class => 'XTracker::Schema::Result::Public::Shipment',
                }
            },
            expected => {
                date => $self->_order_date(),
            },
        },

        {
            name    => 'Sample shipment',
            setup   => {
                shipment => {
                    mock => {
                        is_exchange             => 0,
                        is_replacement_class    => 0,
                        is_sample_shipment      => 1,
                        is_reshipment           => 0,
                        get_released_from_exchange_or_return_hold_datetime
                            => $self->_exchange_release_date(),
                        date                    => $self->_shipment_date(),
                        order                   => {
                            mock => {
                                date => $self->_order_date(),
                            },
                        },
                    },
                    validation_class => 'XTracker::Schema::Result::Public::Shipment',
                }
            },
            expected => {
                date => $self->_shipment_date(),
            },
        },

        {
            name    => 'Re-shipment',
            setup   => {
                shipment => {
                    mock => {
                        is_exchange             => 0,
                        is_replacement_class    => 0,
                        is_sample_shipment      => 0,
                        is_reshipment           => 1,
                        get_released_from_exchange_or_return_hold_datetime
                            => $self->_exchange_release_date(),
                        date                    => $self->_shipment_date(),
                        order                   => {
                            mock => {
                                date => $self->_order_date(),
                            },
                        },
                    },
                    validation_class => 'XTracker::Schema::Result::Public::Shipment',
                }
            },
            expected => {
                date => $self->_shipment_date(),
            },
        },

        {
            name    => 'Standard shipment with no order, should throw exception',
            setup   => {
                shipment => {
                    mock => {
                        is_exchange             => 0,
                        is_replacement_class    => 0,
                        is_sample_shipment      => 0,
                        is_reshipment           => 0,
                        get_released_from_exchange_or_return_hold_datetime
                            => $self->_exchange_release_date(),
                        date                    => $self->_shipment_date(),
                        order                   => undef,
                    },
                    validation_class => 'XTracker::Schema::Result::Public::Shipment',
                }
            },
            expected => {
                error_isa => 'NAP::XT::Exception::Shipment::OrderRequired',
            },
        },

        {
            name    => 'Standard shipment with earliest_selection_time',
            setup   => {
                shipment => {
                    mock => {
                        is_exchange             => 0,
                        is_replacement_class    => 0,
                        is_sample_shipment      => 0,
                        is_reshipment           => 0,
                        get_released_from_exchange_or_return_hold_datetime
                            => $self->_exchange_release_date(),
                        date                    => $self->_shipment_date(),
                        order                   => {
                            mock => {
                                date => $self->_order_date(),
                            },
                        },
                        nominated_earliest_selection_time   => $self->_earliest_selection_date()
                    },
                    validation_class => 'XTracker::Schema::Result::Public::Shipment',
                }
            },
            expected => {
                date => $self->_earliest_selection_date(),
            },
        },

        {
            name    => 'Standard shipment with earliest_selection_time and hold release',
            setup   => {
                shipment => {
                    mock => {
                        is_exchange             => 0,
                        is_replacement_class    => 0,
                        is_sample_shipment      => 0,
                        is_reshipment           => 0,
                        get_released_from_exchange_or_return_hold_datetime
                            => $self->_exchange_release_date(),
                        get_last_release_from_hold_datetime
                            => $self->_release_from_hold_date(),
                        date                    => $self->_shipment_date(),
                        order                   => {
                            mock => {
                                date => $self->_order_date(),
                            },
                        },
                        nominated_earliest_selection_time   => $self->_earliest_selection_date()
                    },
                },
                validation_class => 'XTracker::Schema::Result::Public::Shipment',
            },
            expected => {
                date => $self->_release_from_hold_date(),
            },
        },

    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest %s', $test->{name}));

            my $extended_shipment = Test::MockObject::Builder->extend(
                Test::XTracker::Data->create_shipment(),
                $test->{setup}->{shipment}
            );

            if (defined($test->{expected}->{error_isa})) {
                throws_ok {
                    $extended_shipment->get_shippable_requested_datetime();
                } $test->{expected}->{error_isa}, 'Expected error thrown';
                return;
            }


            my $requested_datetime;
            lives_ok {
                $requested_datetime
                    = $extended_shipment->get_shippable_requested_datetime();
            } 'get_shippable_requested_datetime() lives';

            is($requested_datetime, $test->{expected}->{date},
                'Date returned as expected');
        };
    }
}

sub _first_status_change_datetime { return DateTime->new(
    year    => 2013,
    month   => 12,
    day     => 4,
)};

sub _second_status_change_datetime { return DateTime->new(
    year    => 2013,
    month   => 12,
    day     => 5,
)};

sub _third_status_change_datetime { return DateTime->new(
    year    => 2013,
    month   => 12,
    day     => 6,
)};

sub _operator_id { return Test::XTracker::Data->get_application_operator_id() }

sub test__get_released_from_exchange_or_return_hold_datetime :Tests {
    my ($self) = @_;

    # Should note that all exchange shipments are created in the status of 'Exchange Hold'
    # and therefore this status will never appear in the logs.
    for my $test (
        {
            name    => 'Correct class and with valid logs. Should pick first change to' .
                ' processing',
            setup   => {
                shipment    => {
                    shipment_class_id => $SHIPMENT_CLASS__EXCHANGE
                },
                logs        => [
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_first_status_change_datetime(),
                    },
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__HOLD,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_second_status_change_datetime(),
                    },
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_third_status_change_datetime(),
                    },
                ],
            },
            expected => {
                date => $self->_first_status_change_datetime(),
            },
        },

        {
            name    => 'Wrong class should always return undef',
            setup   => {
                shipment    => {
                    shipment_class_id => $SHIPMENT_CLASS__STANDARD
                },
                logs        => [
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_first_status_change_datetime(),
                    },
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__HOLD,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_second_status_change_datetime(),
                    },
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_third_status_change_datetime(),
                    },
                ],
            },
            expected => {
                date => undef,
            },
        },

        {
            name    => 'Correct class never released should return undef',
            setup   => {
                shipment    => {
                    shipment_class_id => $SHIPMENT_CLASS__EXCHANGE
                },
                logs        => [
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__HOLD,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_second_status_change_datetime(),
                    },
                ],
            },
            expected => {
                date => undef,
            },
        }
    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest %s', $test->{name}));

            my $shipment = Test::XTracker::Data->create_shipment(
                $test->{setup}->{shipment}
            );
            for my $log_def (@{$test->{setup}->{logs}}) {
                $shipment->create_related('shipment_status_logs', $log_def);
            }

            my $released_date;
            lives_ok {
                $released_date =
                    $shipment->get_released_from_exchange_or_return_hold_datetime();
            } 'get_released_from_exchange_hold_datetime() lives';

            is($released_date, $test->{expected}->{date}, 'Returned date is as expected');
        };
    }
}

sub test__nominated_day_times :Tests {
    my ($self) = @_;

    # get a premier non-transfer shipment
    my (undef,$pids)=Test::XTracker::Data->grab_products({how_many=>1});
    my ($order)=Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => {
            premier_routing_id => 2,
            shipment_type => $SHIPMENT_TYPE__PREMIER,
        }
    });
    my $shipment = $order->get_standard_class_shipment;
    my @print_docs = $shipment->list_picking_print_docs;
    if ($self->get_config_var('IWS', 'rollout_phase')) {
        is(@print_docs, 1, 'Just one print doc to print at picking');
        is($print_docs[0], 'Address Card', "and it's an address card");
    }

    # get anything else
    ($order)=Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => {
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        },
    });
    $shipment = $order->get_standard_class_shipment;
    @print_docs = $shipment->list_picking_print_docs;
    is(@print_docs, 0, 'No print doc to print at picking');

    is(
        $shipment->nominated_delivery_date,
        undef,
        "Correct NULL Shipment.nominated_delivery_date",
    );
    is(
        $shipment->nominated_dispatch_time,
        undef,
        "Correct NULL Shipment.nominated_dispatch_time",
    );
    is(
        $shipment->nominated_earliest_selection_time,
        undef,
        "Correct NULL Shipment.nominated_earliest_selection_time",
    );

    note("Test nominated day times");
    (undef,$pids)=Test::XTracker::Data->grab_products({how_many=>1});
    my $now = DateTime->now();
    $now->set_time_zone(config_var('DistributionCentre', 'timezone')); # Where DC1 and Jenkins live
    my $today = $now->clone->truncate(to => "day");
    my $yesterday = $now->clone->subtract(days => 1);
    $shipment = $self->create_nominated_day_order(
        {
            nominated_delivery_date  => $today,
            nominated_dispatch_time  => $now,
            nominated_earliest_selection_time => $yesterday,
        },
        $pids,
    );
    is(
        $shipment->nominated_delivery_date  . "",
        "$today",
        "Correct Shipment.nominated_delivery_date",
    );
    is(
        $shipment->nominated_dispatch_time  . "",
        "$now",
        "Correct Shipment.nominated_dispatch_time",
    );
    is(
        $shipment->nominated_earliest_selection_time . "",
        "$yesterday",
        "Correct Shipment.nominated_earliest_selection_time",
    );

    note("Test update_nominated_day");

    my $existing_sla_cutoff = $shipment->sla_cutoff;

    my $new_delivery_date = $today->clone->add(years => 2);
    my $new_dispatch_date = $today->clone->add(years => 2);

    my $compare_columns = [
        "nominated_delivery_date",
        "nominated_dispatch_time",
        "nominated_earliest_selection_time",
    ];
    # Can't check that the sla_priority is different - it might (should)
    # stay the same unless the shipment_type(?) changes

    my $old_key_value = { map { $_ => $shipment->$_ } @$compare_columns };

    $shipment->update_nominated_day($new_delivery_date, $new_dispatch_date);

    for my $key (@$compare_columns) {
        my $old_value = $old_key_value->{$key} // "";
        isnt(
            $shipment->$key . "",
            $old_value,
            "$key changed",
        );
    }
}

sub test__get_previous_non_hold_shipment_status_log_entry : Tests {
    my $self = shift;

    my %test_data = (
        'Shipment with shipment_status_log with 3 different dates in log' => {
            setup   => {
                shipment    => {
                    shipment_class_id => $SHIPMENT_CLASS__STANDARD,
                },
                logs        => [
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__LOST,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_first_status_change_datetime(),
                    },
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__HOLD,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_second_status_change_datetime(),
                    },
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_third_status_change_datetime(),
                    },
                ],
            },
            expected => {
                date => $self->_first_status_change_datetime(),
                shipment_status_id  => $SHIPMENT_STATUS__LOST,
            },
        },
        "Shipment with shipment_status_log with same dates but different status" => {
            setup   => {
                shipment    => {
                    shipment_class_id => $SHIPMENT_CLASS__EXCHANGE,
                },
                logs        => [
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__HOLD,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_first_status_change_datetime(),
                    },
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__FINANCE_HOLD,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_first_status_change_datetime(),
                    },
                ],
           },
           expected => undef,
        },
       "Shipment with Delivered and Attempted Delivered shipment_stats_log_entry" => {
            setup   => {
                shipment    => {
                    shipment_class_id => $SHIPMENT_CLASS__EXCHANGE,
                },
                logs        => [
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__DELIVERED,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_first_status_change_datetime(),
                    },
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__DELIVERY_ATTEMPTED,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_second_status_change_datetime(),
                    },
                    {
                        shipment_status_id  => $SHIPMENT_STATUS__RETURN_HOLD,
                        operator_id         => $self->_operator_id(),
                        date                => $self->_third_status_change_datetime(),
                    },
                ],
           },
           expected => {
                date                => $self->_third_status_change_datetime(),
                shipment_status_id  => $SHIPMENT_STATUS__RETURN_HOLD,

           }
        },
        "Shipment with no shipment_status_log entry" => {
            setup   => {
                shipment    => {
                    shipment_class_id => $SHIPMENT_CLASS__STANDARD,
                },
                logs        => [ ],
           },
           expected => undef,
        },
    );



    foreach my $label ( sort keys %test_data ) {
        my $test = $test_data{ $label };

        note('Testing :', $label);
        my $shipment = Test::XTracker::Data->create_shipment(
            $test->{setup}->{shipment}
        );

        note "Created Shipment with id : ".$shipment->id."\n";
        for my $log_def (@{$test->{setup}->{logs}}) {
            $shipment->create_related('shipment_status_logs', $log_def);
        }

        my $status_log_entry;
        lives_ok {
            $status_log_entry =
                $shipment->get_previous_non_hold_shipment_status_log_entry();
        } 'get_previous_non_hold_shipment_status_log_entry() lives';

        my $got;

        if( $status_log_entry ) {
            $got = {
                date                => $status_log_entry->date,
                shipment_status_id  => $status_log_entry->shipment_status_id,
           };
        }

        if( $got ) {
            is ($got->{date}, $test->{expected}->{date}, 'Shipment Log date is as expected');
            is ($got->{shipment_status_id}, $test->{expected}->{shipment_status_id}, 'Shipment Status id is as expected');
        } else {
            is( $got, $test->{expected} ,"NO shipment_status_log entry as expected");
        }
    }

}

=head2 test_items_of_product_types

This tests three methods that check for Items in a Shipment whose
Product Type is or is not within a list of Product Types.

=cut

sub test_items_of_product_types : Tests() {
    my $self = shift;

    my ( $channel, $pids ) = Test::XTracker::Data->grab_products( {
        channel      => 'nap',
        how_many     => 3,
        force_create => 1,
    } );
    my @products = map { $_->{product} } @{ $pids };

    # get some Product Types
    my @product_types = $self->rs('Public::ProductType')->search(
        { product_type => { '!=' => 'Unknown' } },
        { rows => 4 }
    )->all;

    my %tests = (
        "Shipment with NO Items of the Specified Types" => {
            setup => {
                products               => [ @products ],
                set_product_types      => [ $product_types[0] ],
                test_for_product_types => [ @product_types[1,2,3] ],
            },
            expect => {
                count_for_types         => 0,
                has_items_of_types      => 0,
                has_only_items_of_types => 0,
            },
        },
        "Shipment with a Cancelled Item of a Specified Type but the Non-Cancelled Items aren't" => {
            setup => {
                products               => [ @products ],
                set_product_types      => [ @product_types[0,1,2] ],
                test_for_product_types => [ @product_types[0,3] ],
                cancel_items           => 1,
            },
            expect => {
                count_for_types         => 0,
                has_items_of_types      => 0,
                has_only_items_of_types => 0,
            },
        },
        "Shipment with a Cancelled Item and also Non-Cancelled Items of the Specified Types" => {
            setup => {
                products               => [ @products ],
                set_product_types      => [ @product_types[0,1,2] ],
                test_for_product_types => [ @product_types[0,1] ],
                cancel_items           => 1,
            },
            expect => {
                count_for_types         => 1,
                has_items_of_types      => 1,
                has_only_items_of_types => 0,
            },
        },
        "Shipment with Cancelled Items and a Non-Cancelled Item of the Specified Type" => {
            setup => {
                products               => [ @products ],
                set_product_types      => [ $product_types[0] ],
                test_for_product_types => [ $product_types[0] ],
                cancel_items           => 2,
            },
            expect => {
                count_for_types         => 1,
                has_items_of_types      => 1,
                has_only_items_of_types => 1,
            },
        },
        "Shipment with Items each a Different Type and all for the Specified Types" => {
            setup => {
                products               => [ @products ],
                set_product_types      => [ @product_types[0,1,2] ],
                test_for_product_types => [ @product_types[0,1,2] ],
            },
            expect => {
                count_for_types         => 3,
                has_items_of_types      => 1,
                has_only_items_of_types => 1,
            },
        },
        "Shipment with Items All the Same Type and Specify Many Types including the One for the Items" => {
            setup => {
                products               => [ @products ],
                set_product_types      => [ $product_types[0] ],
                test_for_product_types => [ @product_types[0,1,2] ],
            },
            expect => {
                count_for_types         => 3,
                has_items_of_types      => 1,
                has_only_items_of_types => 1,
            },
        },
        "Shipment with only Some of the Items of the Specified Types" => {
            setup => {
                products               => [ @products ],
                set_product_types      => [ @product_types[0,1,3] ],
                test_for_product_types => [ @product_types[0,1,2] ],
            },
            expect => {
                count_for_types         => 2,
                has_items_of_types      => 1,
                has_only_items_of_types => 0,
            },
        },
        "Shipment with only One Item and it's for the Specified Type" => {
            setup => {
                products               => [ $products[0] ],
                set_product_types      => [ $product_types[1] ],
                test_for_product_types => [ $product_types[1] ],
            },
            expect => {
                count_for_types         => 1,
                has_items_of_types      => 1,
                has_only_items_of_types => 1,
            },
        },
        "Shipment with only One Item and it's NOT for the Specified Type" => {
            setup => {
                products               => [ $products[0] ],
                set_product_types      => [ $product_types[1] ],
                test_for_product_types => [ $product_types[0] ],
            },
            expect => {
                count_for_types         => 0,
                has_items_of_types      => 0,
                has_only_items_of_types => 0,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        my $setup = $test->{setup};
        my $order_details = Test::XTracker::Data::Order->create_new_order( {
            channel  => $channel,
            products => $setup->{products},
        } );
        my $shipment = $order_details->{shipment_object};

        # now set up the Product Types of each item and
        # also Cancel Shipment Items if required to
        my $cancel_count  = $setup->{cancel_items} // 0;
        my $prod_type_idx = 0;
        my @ship_items    = $shipment->shipment_items->all;
        foreach my $item ( @ship_items ) {
            my $product = $item->variant->product;

            # set the Product Type, then move the idx to next Type in the list
            $product->update( { product_type_id => $setup->{set_product_types}[ $prod_type_idx ]->id } );
            $prod_type_idx++;
            # if reached the end of the list, then go back to the beginning
            $prod_type_idx  = 0     if ( $prod_type_idx >= scalar( @{ $setup->{set_product_types} } ) );

            # cancel the Item if the number to be cancelled is still > 0
            if ( $cancel_count > 0 ) {
                $item->update_status( $SHIPMENT_ITEM_STATUS__CANCELLED, $APPLICATION_OPERATOR_ID );
                $cancel_count--;
            }
        }

        $shipment->discard_changes;
        my $expect = $test->{expect};

        # get the Product Types to pass in to all the Methods
        my @product_type_names = map { $_->product_type } @{ $setup->{test_for_product_types} };

        my $got = $shipment->count_items_of_product_types( \@product_type_names );
        cmp_ok( $got, '==', $expect->{count_for_types}, "'count_items_of_product_types' returned as expected" );

        $got = $shipment->has_items_of_product_types( \@product_type_names );
        cmp_ok( $got, '==', $expect->{has_items_of_types}, "'has_items_of_product_types' returned as expected" );

        $got = $shipment->has_only_items_of_product_types( \@product_type_names );
        cmp_ok( $got, '==', $expect->{has_only_items_of_types}, "'has_only_items_of_product_types' returned as expected" );
    }
}

sub create_nominated_day_order {
    my ($self, $nominated_day_args, $pids) = @_;

    my $schema = $self->schema();

    my $channel = Test::XTracker::Data->channel_for_nap();
    my $shipping_charge_rs = $schema->resultset("Public::ShippingCharge");
    my $nominated_day_shipping_charge = $shipping_charge_rs->search({
        channel_id                        => $channel->id,
        latest_nominated_dispatch_daytime => { '!=' => undef },
    })->first;

    my ($order) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => {
            shipment_type      => $SHIPMENT_TYPE__PREMIER,
            nominated_day      => $nominated_day_args,
            shipping_charge_id => $nominated_day_shipping_charge->id,
        },
    });
    my $shipment = $order->get_standard_class_shipment;

    return $shipment;
}

=head2 set_status_hold

Should set a shipment on hold and create a shipment_hold record and a
shipment_hold_log record to match.

=cut

sub set_status_hold : Tests() {
    my $self = shift;

    my $order_data = Test::XTracker::Data::Order->create_new_order( {
        channel     => $self->{channel},
    } );

    my $shipment = $order_data->{shipment_object};

    $shipment->update( {
        shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
    } );
    ok( $shipment->shipment_status->status eq 'Processing', 'Shipment status is processing' );

    my $called;

    my $shipmentTakeover = qtakeover 'XTracker::Schema::Result::Public::Shipment' => ( );
    my $orig_function = \&XTracker::Schema::Result::Public::Shipment::send_status_update;

    $shipmentTakeover->override( send_status_update => sub { ++$called; $orig_function->(@_); });

    #mock the channel to make sure the _get_active_config_group_setting returns the values we want
    my $control = qtakeover 'XTracker::Schema::Result::Public::Channel' => (  );

    # Override a method
    $control->override( _get_active_config_group_setting => sub { return 'on'; });

    $shipment->set_status_hold(
        $APPLICATION_OPERATOR_ID,
        $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
        'INVALID CHARACTERS TEST',
        undef,
    );

    $control->restore('_get_active_config_group_setting');
    $shipmentTakeover->restore('send_status_update');


    ok($called, 'Shipment sent message to Mercury');

    ok($shipment->discard_changes->is_on_hold_for_invalid_address_chars,
        "Shipment is on hold for Invalid Characters" );

    my $count = $shipment->discard_changes->search_related('shipment_holds', {
        shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
    } )->count;

    ok( $count == 1, "There is 1 shipment_hold record for Invalid Characters");

    my $hold_logs = $shipment->search_related('shipment_hold_logs', {
        shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
    } )->count;

    ok( $hold_logs == 1, 'There is at least one shipment_hold_log entry for Invalid Characters');
}

sub _test_shipment_update_hold_feature_switch_off : Tests() {
    my $self = shift;

    my $order_data = Test::XTracker::Data::Order->create_new_order( {
        channel     => $self->{channel},
    } );

    my $shipment = $order_data->{shipment_object};

    my $called = 0;
    my $orig_function = \&XTracker::Schema::Result::Public::Shipment::send_status_update;

    my $shipmentTakeover = qtakeover 'XTracker::Schema::Result::Public::Shipment' => ( );
    $shipmentTakeover->override( send_status_update => sub { ++$called; $orig_function->(@_); });

    #mock the channel to make sure the _get_active_config_group_setting returns the values we want
    my $control = qtakeover 'XTracker::Schema::Result::Public::Channel' => ( );

    # Override a method
    $control->override( _get_active_config_group_setting => sub { return 'off'; });

    $shipment->set_status_hold(
        $APPLICATION_OPERATOR_ID,
        $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
        'INVALID CHARACTERS TEST',
        undef,
    );

    $control->restore('_get_active_config_group_setting');
    $shipmentTakeover->restore('send_status_update');

    ok($called == 0, 'Shipment shouldn\'t send a message to Mercury');
}

# helper to create payment records
# and setup the Mock PSP
sub _setup_payment_and_psp {
    my ( $self, $args ) = @_;

    my $order                   = $args->{order};
    my $payment_method          = $args->{payment_method};
    my $psp_third_party_status  = $args->{third_party_status};
    my $no_payment              = $args->{no_payment} // 0;

    $self->{payment_args}{payment_method} = $self->{payment_method}{ $payment_method };
    Test::XTracker::Data->create_payment_for_order( $order, $self->{payment_args} )
                            unless ( $no_payment );
    Test::XTracker::Mock::PSP->set_third_party_status(
        $psp_third_party_status,
    );
    Test::XTracker::Mock::PSP->set_payment_method(
        $self->{payment_method}{ $payment_method }->string_from_psp,
    );

    return;
}

# helper to set the Shipment up setting certain
# fields and also putting on Hold if requested
sub _setup_shipment_record {
    my ( $self, $shipment, $args ) = @_;

    # take out the non Shipment fields
    my $hold_reason = delete $args->{hold_reason};
    my $operator_id = delete $args->{operator_id};

    $shipment->discard_changes->update( $args );

    $shipment->shipment_status_logs->create( {
        shipment_status_id  => $shipment->shipment_status_id,
        operator_id         => $APPLICATION_OPERATOR_ID,
    } );

    if ( $hold_reason ) {
        $shipment->put_on_hold( {
            reason      => $hold_reason,
            status_id   => $SHIPMENT_STATUS__HOLD,
            operator_id => $operator_id || $APPLICATION_OPERATOR_ID,
            norelease   => 1,
        } );
        cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__HOLD,
                                "sanity check, shipment is on hold" );
    }

    return;
}

sub test__use_emergency_sla_settings :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Emergency SLA settings used when call to SOS dies',
            setup   => {
                get_emergency_sla_data => {
                    sla_cutoff_datetime         => { year => 2014, month => 4, day => 10, hour => 8 },
                    wms_initial_pick_priority   => 19,
                    wms_deadline_datetime       => { year => 2014, month => 4, day => 10, hour => 7 },
                    wms_bump_pick_priority      => undef,
                    wms_bump_deadline_datetime  => undef
                },
            },
            expected=> {
                # These settings match the emergency ones defined above
                sla_cutoff_datetime         => { year => 2014, month => 4, day => 10, hour => 8 },
                wms_initial_pick_priority   => 19,
                wms_deadline_datetime       => { year => 2014, month => 4, day => 10, hour => 7 },
                wms_bump_pick_priority      => undef,
                wms_bump_deadline_datetime  => undef
            },
        }
    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest: %s', $test->{name}));

            my $shipment = $self->_create_shipment_for_emergency_sla($test);

            $shipment->apply_SLAs();

            is($shipment->sla_cutoff(), DateTime->new(
                %{ $test->{expected}->{sla_cutoff_datetime} },
                time_zone => $self->get_config_var('DistributionCentre', 'timezone'),
            ), 'Returned SLA is as expected');

            is($shipment->wms_initial_pick_priority(),
               $test->{expected}->{wms_initial_pick_priority},
               'Returned wms_initial_pick_priority is as expected');

            is($shipment->wms_deadline(), DateTime->new(
                %{ $test->{expected}->{wms_deadline_datetime} },
                time_zone => $self->get_config_var('DistributionCentre', 'timezone'),
            ), 'Returned wms_deadline_datetime is as expected');

            is($shipment->wms_bump_pick_priority(),
               $test->{expected}->{wms_bump_pick_priority},
               'Returned wms_bump_pick_priority is as expected');

            is($shipment->wms_bump_deadline(),
               $test->{expected}->{wms_bump_deadline_datetime},
               'Returned wms_bump_deadline_datetime is as expected');
        };
    }
}

sub _create_shipment_for_emergency_sla {
    my ($self, $test) = @_;

    return Test::MockObject::Builder->extend(
        Test::XTracker::Data->create_shipment(), {
        mock            => {
            get_sla_data => sub { die 'Gamma Goblins!' },
        },
        set_list        => {
            get_emergency_sla_data => [
                DateTime->new(
                    %{ $test->{setup}->{get_emergency_sla_data}->{sla_cutoff_datetime} },
                    time_zone => $self->get_config_var('DistributionCentre', 'timezone'),
                ),
                $test->{setup}->{get_emergency_sla_data}->{wms_initial_pick_priority},
                DateTime->new(
                    %{ $test->{setup}->{get_emergency_sla_data}->{wms_deadline_datetime} },
                    time_zone => $self->get_config_var('DistributionCentre', 'timezone'),
                ),
                $test->{setup}->{get_emergency_sla_data}->{wms_bump_pick_priority},
                $test->{setup}->{get_emergency_sla_data}->{wms_bump_deadline_datetime},
            ],
        },
    });
}

sub test__get_priority_data :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Get data for a un-bumped shipment (no bump data)',
            setup   => {
                shipment=> {
                    initial_pick_priority   => 20,
                    bump_deadline           => undef,
                    bump_pick_priority      => undef,
                },
                now     => { year => 2014, month => 4, day => 25 },
            },
            result  => {
                current_priority=> 20,
                is_bumped       => 0,
            },
        },
        {
            name    => 'Get data for a un-bumped shipment (with bump data)',
            setup   => {
                shipment=> {
                    initial_pick_priority   => 20,
                    bump_deadline           => { year => 2014, month => 4, day => 26 },
                    bump_pick_priority      => 10,
                },
                now     => { year => 2014, month => 4, day => 25 },
            },
            result  => {
                current_priority=> 20,
                is_bumped       => 0,
            },
        },
        {
            name    => 'Get data for a bumped shipment',
            setup   => {
                shipment=> {
                    initial_pick_priority   => 20,
                    bump_deadline           => { year => 2014, month => 4, day => 24 },
                    bump_pick_priority      => 10,
                },
                now     => { year => 2014, month => 4, day => 25 },
            },
            result  => {
                current_priority=> 10,
                is_bumped       => 1,
            },
        },
    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest: %s', $test->{name}));

            my $shipment = $self->_create_priority_data_shipment($test);
            my ($current_priority, $is_bumped) = $shipment->get_priority_data();

            is($current_priority, $test->{result}->{current_priority},
                'Current priority value is as expected');
            is($is_bumped, $test->{result}->{is_bumped},
                'Current is-bumped value is as expected');
            };
    }
}

sub test__get_last_release_from_hold_datetime :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Shipment has never been on hold',
            setup   => {
                reasons             => [
                    { name => 'Dev too tired', allow_new_sla_on_release => 0 },
                    { name => 'Customers fault', allow_new_sla_on_release => 1 }
                ],
                shipment => {
                    shipment_hold_log   => [],
                    current_status      => $SHIPMENT_STATUS__PROCESSING
                },
                params              => {},
            },
            expected=> {
                released_from_hold_datetime => undef,
            },
        },
        {
            name    => 'Shipment has been on hold, but is not now (any reason reported)',
            setup   => {
                reasons     => [
                    { name => 'Dev too tired', allow_new_sla_on_release => 0 },
                    { name => 'Customers fault', allow_new_sla_on_release => 1 }
                ],
                shipment    => {
                    shipment_status_log => [
                        { status => $SHIPMENT_STATUS__HOLD, date => { year => 2014, month => 4, day => 11 }, reason => 'Customers fault' },
                        { status => $SHIPMENT_STATUS__PROCESSING, date => { year => 2014, month => 4, day => 12 } },
                        { status => $SHIPMENT_STATUS__HOLD, date => { year => 2014, month => 4, day => 13 }, reason => 'Dev too tired' },
                        # This next status log is the last time this shipment was released from hold
                        { status => $SHIPMENT_STATUS__PROCESSING, date => { year => 2014, month => 4, day => 14 } },
                        { status => $SHIPMENT_STATUS__DISPATCHED, date => { year => 2014, month => 4, day => 15 } },
                    ],
                    current_status      => $SHIPMENT_STATUS__PROCESSING
                },
                params      => {},
            },
            expected=> {
                # This is correct date because it matches that in the status_log for the
                # status AFTER the shipment was last on hold (as noted above)
                released_from_hold_datetime => { year => 2014, month => 4, day => 14 },
            },
        },
        {
            name    => 'Shipment has been on hold, and is again now (any reason reported)',
            setup   => {
                reasons     => [
                    { name => 'Dev too tired', allow_new_sla_on_release => 0 },
                    { name => 'Customers fault', allow_new_sla_on_release => 1 }
                ],
                shipment    => {
                    shipment_status_log => [
                        { status => $SHIPMENT_STATUS__HOLD, date => { year => 2014, month => 4, day => 11 }, reason => 'Customers fault' },
                        # This next status log is the last time this shipment was released from hold
                        { status => $SHIPMENT_STATUS__PROCESSING, date => { year => 2014, month => 4, day => 12 } },
                        { status => $SHIPMENT_STATUS__HOLD, date => { year => 2014, month => 4, day => 13 }, reason => 'Dev too tired' },
                    ],
                    current_status      => $SHIPMENT_STATUS__HOLD
                },
                params      => {},
            },
            expected=> {
                # This is correct date because it matches that in the status_log for the
                # status AFTER the shipment was last on hold (as noted above)
                released_from_hold_datetime => { year => 2014, month => 4, day => 12 },
            },
        },
        {
            name    => 'Shipment has been on hold, but is not now (only sla releasable reasons reported)',
            setup   => {
                reasons     => [
                    { name => 'Dev too tired', allow_new_sla_on_release => 0 },
                    { name => 'Customers fault', allow_new_sla_on_release => 1 }
                ],
                shipment    => {
                    shipment_status_log => [
                        { status => $SHIPMENT_STATUS__HOLD, date => { year => 2014, month => 4, day => 11 }, reason => 'Customers fault' },
                        # This next status log is the last time this shipment was released from a hold that had
                        # a reasona that allows the recalculation of SLAs
                        { status => $SHIPMENT_STATUS__PROCESSING, date => { year => 2014, month => 4, day => 12 } },
                        { status => $SHIPMENT_STATUS__HOLD, date => { year => 2014, month => 4, day => 13 }, reason => 'Dev too tired' },
                        { status => $SHIPMENT_STATUS__PROCESSING, date => { year => 2014, month => 4, day => 14 } },
                        { status => $SHIPMENT_STATUS__DISPATCHED, date => { year => 2014, month => 4, day => 15 } },
                    ],
                    current_status      => $SHIPMENT_STATUS__PROCESSING
                },
                params      => {
                    only_include_sla_changeable_reasons => 1,
                },
            },
            expected=> {
                # This is correct date because it matches that in the status_log for the
                # status AFTER the shipment was last on hold (as noted above)
                released_from_hold_datetime => { year => 2014, month => 4, day => 12 },
            },
        },
        {
            name    => 'Shipment has been on hold, but is not now (only hold released after minimum time used)',
            setup   => {
                reasons     => [
                    { name => 'Dev too tired', allow_new_sla_on_release => 0 },
                    { name => 'Customers fault', allow_new_sla_on_release => 1 }
                ],
                shipment    => {
                    shipment_status_log => [
                        { status => $SHIPMENT_STATUS__HOLD, date => { year => 2014, month => 4, day => 11 }, reason => 'Customers fault' },
                        # This next status log is the last time this shipment was released from a hold that had
                        # a reason that allows the recalculation of SLAs and was released BEFORE the latest_valid_datetime
                        { status => $SHIPMENT_STATUS__PROCESSING, date => { year => 2014, month => 4, day => 12 } },
                        { status => $SHIPMENT_STATUS__HOLD, date => { year => 2014, month => 4, day => 13 }, reason => 'Dev too tired' },
                        # This release time will be ignored as it is not for a reason we take in to account
                        { status => $SHIPMENT_STATUS__PROCESSING, date => { year => 2014, month => 4, day => 14 } },
                        { status => $SHIPMENT_STATUS__HOLD, date => { year => 2014, month => 4, day => 15, hour => 5, }, reason => 'Customers fault' },
                        # This release time will be ignored because the hold status did not last long enough
                        { status => $SHIPMENT_STATUS__PROCESSING, date => { year => 2014, month => 4, day => 15, hour => 5, minute => 6 } },
                        { status => $SHIPMENT_STATUS__DISPATCHED, date => { year => 2014, month => 4, day => 16 } },
                    ],
                    current_status      => $SHIPMENT_STATUS__PROCESSING,
                },
                _get_minimum_hold_minutes_to_allow_new_sla => 15,
                params      => {
                    only_include_sla_changeable_reasons => 1,
                    only_include_holds_held_long_enough => 1
                },
            },
            expected=> {
                # This is correct date because it matches that in the status_log for the
                # status AFTER the shipment was last released hold BEFORE the latest_valid_datetime
                released_from_hold_datetime => { year => 2014, month => 4, day => 12 },
            },
        },
    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest %s', $test->{name}));

            my ($shipment, $expected_released_datetime, $mock_last_release_rs)
                = $self->_create_release_hold_shipment($test);

            my $released_from_hold_datetime = $shipment->get_last_release_from_hold_datetime(
                $test->{setup}->{params}
            );

            is($released_from_hold_datetime, $expected_released_datetime,
                'Returned released from hold datetime is as expected');
        };
    }
}

sub _create_priority_data_shipment {
    my ($self, $test) = @_;

    my $wms_bump_deadline = ($test->{setup}->{shipment}->{bump_deadline}
        ? DateTime->new( %{$test->{setup}->{shipment}->{bump_deadline}} )
        : undef
    );

    return Test::MockObject::Builder->extend(Test::XTracker::Data->create_shipment(), {
        mock => {
            wms_initial_pick_priority   => $test->{setup}->{shipment}->{initial_pick_priority},
            wms_bump_pick_priority      => $test->{setup}->{shipment}->{bump_pick_priority},
            wms_bump_deadline           => $wms_bump_deadline,
            _get_now                    => DateTime->new(%{$test->{setup}->{now}}),
        },
        validation_class    => 'XTracker::Schema::Result::Public::Shipment',
    });
}

sub _create_release_hold_shipment {
    my ($self, $test) = @_;

    for my $reason_def (@{ $test->{setup}->{reasons} }) {
        my $hold_reason = $self->schema->resultset('Public::ShipmentHoldReason')->find_or_create({
            reason  => $reason_def->{name},
        });
        $hold_reason->update({ allow_new_sla_on_release => $reason_def->{allow_new_sla_on_release} });
    }

    my $shipment = Test::XTracker::Data->create_shipment();
    $shipment->update({
        shipment_status_id => $test->{setup}->{shipment}->{current_status}
    });

    my $mock_last_release_rs;

    if ($test->{setup}->{_get_minimum_hold_minutes_to_allow_new_sla}) {
        $mock_last_release_rs = Test::MockModule->new('XTracker::Schema::ResultSet::Public::LastReleasedShipmentHold');
        $mock_last_release_rs->mock('_get_minimum_hold_minutes_to_allow_new_sla', sub {
            $test->{setup}->{_get_minimum_hold_minutes_to_allow_new_sla}
        });
    }

    for my $shipment_status_log (@{$test->{setup}->{shipment}->{shipment_status_log}}) {
        my $date = DateTime->new(
            %{ $shipment_status_log->{date} },
        );

        my $status_log = $shipment->create_related('shipment_status_logs', {
            shipment_status_id  => $shipment_status_log->{status},
            operator_id         => $APPLICATION_OPERATOR_ID,
            date                => $date,
        });

        if ($shipment_status_log->{reason}) {

            my $hold_reason = $self->schema->resultset('Public::ShipmentHoldReason')->find({
                reason  => $shipment_status_log->{reason},
            });

            $status_log->create_related('shipment_hold_logs', {
                shipment_id             => $shipment->id(),
                shipment_hold_reason_id => $hold_reason->id(),
                comment                 => '',
                operator_id             => $APPLICATION_OPERATOR_ID,
                date                    => $date,
            });
        }
    }

    my $expected_released_datetime;
    $expected_released_datetime = DateTime->new(
        %{ $test->{expected}->{released_from_hold_datetime} },
    ) if $test->{expected}->{released_from_hold_datetime};


    return ($shipment, $expected_released_datetime, $mock_last_release_rs);
}

=head1 test_has_validated_address

=cut

sub test_has_validated_address : Tests {
    my $self = shift;

    my $shipment = Test::XTracker::Data->create_shipment();

    subtest 'validate dhl shipment address' => sub {
        my $mocked_shipment = Test::MockObject::Extends->new($shipment)
            ->mock(carrier_is_ups => sub{0})
            ->mock(carrier_is_dhl => sub {1});
        for (
            [ undef, 0 ],
            [ q{},   0 ],
            [ 'foo', 1 ]
        ) {
            my ( $destination_code, $should_be_valid ) = @$_;
            $mocked_shipment->update({destination_code => $destination_code});
            if ( $should_be_valid ) {
                ok( $mocked_shipment->has_validated_address,
                    "shipment with destination code '$destination_code' is valid"
                );
            }
            else {
                ok( !$mocked_shipment->has_validated_address,
                    sprintf q{shipment with destination code '%s' is not valid},
                        $destination_code//'<undef>'
                );
            }
        }
    };

    subtest 'validate ups shipment address' => sub {
        my $mocked_shipment = Test::MockObject::Extends->new($shipment)
            ->mock(carrier_is_ups => sub{1})
            ->mock(carrier_is_dhl => sub{0});
        my $qrt = 0.51; # I believe UPS returns numbers with 2 decimal places
        $mocked_shipment->mock(ups_quality_rating_threshold => sub{$qrt});
        for (
            [ -0.1, 0 ],
            [ 0,    1 ],
            [ 0.1,  1 ],
        ) {
            my ( $qrt_delta, $should_be_valid ) = @$_;
            $mocked_shipment->update({av_quality_rating => $qrt + $qrt_delta});
            if ( $should_be_valid ) {
                ok( $mocked_shipment->has_validated_address,
                    "shipment with av_quality_rating '$qrt_delta' from qrt should be valid"
                );
            }
            else {
                ok( !$mocked_shipment->has_validated_address,
                    "shipment with av_quality_rating '$qrt_delta' from qrt should not be valid"
                );
            }
        }
    };

    subtest 'validate non-ups non-dhl shipment address' => sub {
        my $mocked_shipment = Test::MockObject::Extends->new($shipment)
            ->mock(carrier_is_ups => sub{0})
            ->mock(carrier_is_dhl => sub{0});
        $mocked_shipment->mock(ups_quality_rating_threshold => sub{1});
        $mocked_shipment->update({
            destination_code  => undef,
            av_quality_rating => 0,
        });
        ok( $mocked_shipment->has_validated_address,
            'shipment should pass address validation in spite of dodgy address' );
    };
}

=head2 test_select

=cut

sub test_select : Tests {
    my $self = shift;

    my $operator_id = $APPLICATION_OPERATOR_ID;

    my $shipment = Test::XTracker::Data->create_shipment;
    ok( $shipment, 'created shipment ' . $shipment->id );
    like(
        exception {
            my $mocked = $self->mock_warehouse({has_prls => 1});
            $shipment->select($operator_id);
        },
        qr{Pick Scheduler},
        'attempting to select a shipment in a prl with PRLs should die'
    );

    # For the rest of these tests we don't want to have PRLs
    my $mocked_warehouse = $self->mock_warehouse({has_prls => 0});
    subtest 'no new shipment items' => sub {
        my $mocked_shipment = $self->mock_unselected_items(0);
        ok( !$shipment->select($operator_id),
            'select should return a false value when there are no items to select' );
    };

    subtest 'shipment is on hold' => sub {
        my $mocked_shipment = $self->mock_unselected_items(1);
        $mocked_shipment->mock(is_on_hold => 1);
        like(
            exception { !$shipment->select($operator_id); },
            qr{is on hold},
            'select should die with on hold error'
        );
    };

    for (
        [ 'virtual voucher only shipment', 1, 0, ],
        [ 'shipment with non-virtual-voucher items', 0, 1],
    ) {
        my ( $test_name, $is_virtual_voucher_only, $expect_message ) = @$_;
        subtest $test_name => sub {
            my $mocked_shipment = $self->mock_unselected_items(1);
            $mocked_shipment->mock(is_virtual_voucher_only => $is_virtual_voucher_only);

            # Testing that transform_and_send gets called when appropriate is
            # good enough for this test
            my $mocked_msg_factory = Test::MockObject->new;
            $mocked_msg_factory->mock(transform_and_send => sub {});
            ok(
                $shipment->select($operator_id, $mocked_msg_factory),
                'select should return a true value'
            );
            if ( $expect_message ) {
                ok(
                    $mocked_msg_factory->called('transform_and_send'),
                    'should send a message to the wms'
                );
            }
            else {
                ok(
                    !$mocked_msg_factory->called('transform_and_send'),
                    'should not send a message to the wms'
                );
            }
        };
    }
}

=head2 mock_warehouse({:has_prls=false}) : mocked_xt_warehouse

Return a mocked L<XT::Warehouse> object. C<has_prls> will be mocked with the
given value as long as this object remains in scope.

=cut

sub mock_warehouse {
    my ( $self, $args ) = @_;

    my $mocked = Test::MockModule->new('XT::Warehouse');
    $mocked->mock(
        instance => sub { bless { has_prls => $args->{has_prls} }, 'XT::Warehouse'; },
    );
    return $mocked;
}

=head2 mock_unselected_items(item_count) : mocked_shipment

Return a mocked L<XTracker::Schema::Result::Public::Shipment> object. As long
as this object remains in scope, calling C<all> on C<unselected_items> will
return a list of length C<item_count> of objects given by
L<mock_shipment_item_row> representing shipment items.

=cut

sub mock_unselected_items {
    my ( $self, $item_count ) = @_;

    my $mocked = Test::MockModule->new('XTracker::Schema::Result::Public::Shipment');
    $mocked->mock(
        unselected_items => sub {
            my $mocked_rs = Test::MockObject->new;
            $mocked_rs->set_list(all => ($self->mock_shipment_item_row) x $item_count);
        },
    );
    return $mocked;
}

=head2 mock_shipment_item_row() : mocked shipment item

Return a very basic L<Test::MockObject> mocking a shipment item row. The only
mocked method mocked is L<set_selected>, which always returns C<1>.

=cut

sub mock_shipment_item_row {
    my $self = shift;

    my $mocked = Test::MockObject->new;
    $mocked->mock(set_selected => sub { 1 },);

    return $mocked;
}

=head2 test_update_status

=cut

sub test_update_status : Tests {
    my $self = shift;

    my $shipment = Test::XTracker::Data->create_shipment;
    my $operator_id = $APPLICATION_OPERATOR_ID;
    ok( $shipment, 'created shipment ' . $shipment->id );
    for (
        [
            'not on hold to processing',
            {
                mock => {
                    is_on_hold                     => 0,
                    should_hold_if_invalid_address => 1,
                },
                shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
                called_methods      => [],
            },
            { shipment_status_ids => [$SHIPMENT_STATUS__PROCESSING], },
        ],
        [
            'on hold with valid address can be released',
            {
                mock => {
                    # Not ideal as we are digging into implementation here -
                    # but we want the first is_on_hold done to return true and
                    # any subsequent ones to false
                    is_on_hold                     => sub { shift @{state $is_on_hold = [1]}; },
                    validate_address               => 1,
                    has_validated_address          => 1,
                    should_hold_if_invalid_address => 1,
                },
                shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
            },
            { shipment_status_ids => [$SHIPMENT_STATUS__PROCESSING], },
        ],
        [
            'on hold failing invalid character validation goes back on hold',
            {
                mock => {
                    is_on_hold                     => 1,
                    validate_address               => \&mock_invalid_character_address_validation,
                    should_hold_if_invalid_address => 1,
                },
                shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
            },
            # In cases where we put the shipment back on hold where required,
            # ideally we wouldn't log that it's gone to 'Processing' before
            # going on hold again, but this is more work and not important
            # enough to be done as part of the ticket I'm working on
            { shipment_status_ids => [
                $SHIPMENT_STATUS__PROCESSING, $SHIPMENT_STATUS__HOLD,
            ]},
        ],
        [
            'on hold failing invalid address validation goes back on hold',
            {
                mock => {
                    is_on_hold                     => 1,
                    validate_address               => 0,
                    has_validated_address          => 0,
                    should_hold_if_invalid_address => 1,
                },
                shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
            },
            { shipment_status_ids => [
                $SHIPMENT_STATUS__PROCESSING, $SHIPMENT_STATUS__HOLD,
            ]},
        ],
        [
            'failing invalid address validation with config set to not hold should be released',
            {
                mock => {
                    is_on_hold                     => 0,
                    validate_address               => 0,
                    has_validated_address          => 0,
                    should_hold_if_invalid_address => 0,
                },
                shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
                called_methods => [], # Not interested in testing these here
            },
            { shipment_status_ids => [ $SHIPMENT_STATUS__PROCESSING ] },
        ],
    ) {
        my ( $test_name, $setup, $expected ) = @$_;

        subtest $test_name => sub {
            my $mocked = Test::MockObject::Extends->new($shipment);
            # Allow passing subrefs and scalars
            $mocked->mock(
                $_ => map {
                    my $val = $_; ref ($val//q{}) eq 'CODE' ? $val : sub { $val; }
                } $setup->{mock}{$_}
            ) for keys %{$setup->{mock}};

            # Our create_shipment call above doesn't actually create any items
            # - which triggers is_virtual_voucher_only to be true. As in this
            # test we don't test virtual vouchers, let's mock it to always be
            # false
            $mocked->mock(is_virtual_voucher_only => sub {0});

            # Mock methods that we want to check get called when they should be
            my @called_on_release = (qw/
                allocate
                apply_SLAs
                auto_pick_virtual_vouchers
                dispatch_virtual_voucher_only_shipment
                send_release_update
            /);
            my @called_on_hold = 'send_hold_update';
            my %is_called = map { $_ => 0 } @called_on_release, @called_on_hold;
            $mocked->mock($_ => map {
                my $subname = $_; sub { $is_called{$subname} = 1; }
            } $_ ) for keys %is_called;

            # Keep track of our max log id before we run update_status
            my $shipment_status_log_rs = $shipment->shipment_status_logs;
            my $max_log_id = $shipment_status_log_rs->get_column('id')->max||0;

            $shipment->update_status($setup->{shipment_status_id}, $operator_id);

            # The last status in our expected log entries is the one we expect
            # our shipment to have
            my $expected_status_id = $expected->{shipment_status_ids}[-1];
            # Test the shipment's status is updated as expected
            is( $shipment->shipment_status_id, $expected_status_id,
                'shipment_status_id should match' );

            for my $method ( sort keys %is_called ) {
                # Create a hash letting us know whether we expect a method to have
                # been called
                state $default_expected_calls = {
                    $SHIPMENT_STATUS__PROCESSING => {map { $_ => 1 } @called_on_release},
                    $SHIPMENT_STATUS__HOLD       => {map { $_ => 1 } @called_on_hold},
                };
                # If we've passed a list of methods we expect to be called, use
                # that to determine if we expect a call to it - otherwise use
                # defaults
                my $should_expect_call
                    = exists $setup->{called_methods}
                    ? (grep { $method eq $_ } @{$setup->{called_methods}})
                    : $default_expected_calls->{$expected_status_id}{$method};
                if ( $should_expect_call ) {
                    ok( $is_called{$method}, "$method should be called");
                }
                else {
                    ok( !$is_called{$method}, "$method should not be called");
                }
            }

            # Test our shipment status logs are created in the right order
            my @got_logs = $shipment_status_log_rs
                ->search({id => {q{>} => $max_log_id}}, {order_by => [qw/date id/]})
                ->get_column('shipment_status_id')
                ->all;

            is( @got_logs, @{$expected->{shipment_status_ids}},
                'correct number of log entries' );
            is( $got_logs[$_], $expected->{shipment_status_ids}[$_],
                "expected shipment status log (status id $expected->{shipment_status_ids}[$_]) found"
            ) for 0..$#{$expected->{shipment_status_ids}};
        };
    }
}

=head2 test_get_payment_info_for_tt

Test the C<get_payment_info_for_tt> method, which should return a HashRef of
data for use in Template Toolkit.

Additional data should be returned if the Shipment was paid for using a Third
Party method.

=cut

sub test_get_payment_info_for_tt : Tests {
    my $self = shift;

    my %tests = (
        'Paid With Credit Card' => {
            setup => {
                payment_method          => 'TEST Credit Card',
                payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__CARD,
                display_name            => 'TEST Credit Card Display',
            },
            expected => {
                was_paid_using_credit_card  => 1,
                was_paid_using_third_party  => 0,
                payment_obj                 => isa('XTracker::Schema::Result::Orders::Payment'),
            },
        },
        'Paid With Third Party'=> {
            setup => {
                payment_method          => 'TEST Third Party',
                payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
                display_name            => 'TEST Third Party Display',
            },
            expected => {
                was_paid_using_credit_card  => 0,
                was_paid_using_third_party  => 1,
                payment_obj                 => isa('XTracker::Schema::Result::Orders::Payment'),
                third_party_paid_with       => 'TESTTHIRDPARTY',
                third_party_display_name    => 'TEST Third Party Display',
                third_party_payment_obj     => isa('XTracker::Schema::Result::Orders::PaymentMethod'),
            },
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest $name => sub {
            $self->schema->txn_dont( sub {

                my $order_details   = $self->{data_helper}->new_order;
                my $order           = $order_details->{order_object};
                my $shipment        = $order_details->{shipment_object};

                $order->create_related( payments => {
                    psp_ref             => $self->{payment_args}->{psp_ref},
                    preauth_ref         => $self->{payment_args}->{preauth_ref},
                    settle_ref          => $self->{payment_args}->{settle_ref},
                    fulfilled           => 0,
                    valid               => 1,
                    payment_method      => {
                        payment_method                  => $test->{setup}->{payment_method},
                        payment_method_class_id         => $test->{setup}->{payment_method_class_id},
                        string_from_psp                 => 'STRING' . $order->id,
                        notify_psp_of_address_change    => 0,
                        display_name                    => $test->{setup}->{display_name},
                    },
                });

                cmp_deeply( $shipment->get_payment_info_for_tt,
                    $test->{expected}, 'Result as expected' );

            } );
        }

    }
}


# Validate address puts the shipment on hold if it has non-Latin-1 characters -
# let's mock that
sub mock_invalid_character_address_validation {
    my ( $self, $args ) = @_;
    $self->set_status_hold(
        $args->{operator_id},
        $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
        'test invalid character hold'
    ),
}

=head2 test_hold_if_invalid_address_characters

=cut

sub test_hold_if_invalid_address_characters : Tests {
    my $self = shift;

    my $shipment = Test::XTracker::Data->create_shipment;

    for (
        [ q{shipment with non-latin-1 chars goes on hold}          => 1, 1 ],
        [ q{shipment without non-latin-1 chars doesn't go on hold} => 0, 0 ],
    ) {
        my ( $test_name, $has_non_latin_1_chars, $expected_on_hold ) = @$_;
        subtest $test_name => sub {

            # Make sure our shipment isn't already on hold
            $shipment->update({shipment_status_id => $SHIPMENT_STATUS__PROCESSING});

            # Mock our address so we can set its method's return value
            my $mocked_address = Test::MockObject->new;
            $mocked_address->mock(
                has_non_latin_1_characters => sub { $has_non_latin_1_chars }
            );

            my $mocked_shipment = Test::MockObject::Extends->new($shipment);
            $mocked_shipment->mock(shipment_address => sub { $mocked_address });

            my $got = $mocked_shipment->hold_if_invalid_address_characters($APPLICATION_OPERATOR_ID);

            if ( $expected_on_hold ) {
                ok( $got, 'method should return true' );
                ok( $shipment->is_on_hold, 'shipment should be on hold' );
            }
            else {
                ok( !$got, 'method should return false' );
                ok( !$shipment->is_on_hold, 'shipment should not be on hold' );
            }
        };
    }
}

=head2 test_validate_address

=cut

sub test_validate_address : Tests {
    my $self = shift;

    my $shipment = Test::XTracker::Data->create_shipment;

    for (
        [ q{carrier validates address successfully} => 1, 1 ],
        [ q{carrier validates address unsuccessfully} => 0, 0 ],
    ) {
        my ( $test_name, $validate_address_override, $should_be_valid ) = @$_;

        subtest $test_name => sub {
            # Create our mocked carrier - we don't care about what carrier
            # returns (as long as it's defined), we're interested in the return
            # value for validate_address
            my $mocked_carrier = Test::MockObject->new;
            $mocked_carrier->mock(@$_) for (
                [ carrier => sub {1} ],
                [ validate_address => sub { $validate_address_override } ],
            );

            # Assign our mocked carrier to our shipment
            my $mocked_shipment = Test::MockObject::Extends->new($shipment);
            $mocked_shipment->mock(nap_carrier => sub { $mocked_carrier });

            if ( $should_be_valid ) {
                ok( $mocked_shipment->validate_address, 'validate_address should return true' );
                ok( $mocked_shipment->has_valid_address, 'has_valid_address should be true' );
            }
            else {
                ok( !$mocked_shipment->validate_address, 'validate address should return false' );
                ok( !$mocked_shipment->has_valid_address, 'has_valid_address should be false' );
            }
        };
    }
}

=head2 test_fetch_third_party_klarna_invoice

Test the C<fetch_third_party_klarna_invoice> method as well as the get_third_party_invoice_url
and get_third_party_invoice_file_path helper methods.

This should only fetch the invoice for shipments of orders paid using the third party Klarna service.

If the call to Klarna fails, no shipment_print_log entry will be created, other than that no error
is thrown.

=cut

sub test_fetch_third_party_klarna_invoice : Tests {
    my $self = shift;
    my $test_invoice_url = 'http://www.example.com/invoice.pdf';
    my $test_file_path_regex = '/var/data/xt_static/print_docs/invoice_klarna';
    my %mock_lwp_responses = (
        pass => { response_code => 200,
                  mock_response => 'response_OK' },
        fail => { response_code => 404,
                  mock_response => 'response_NOT_FOUND' },
    );

    my %tests = (
        'Paid With Credit Card' => {
            setup => {
                payment_method          => 'Credit Card',
                third_party_status      => undef,
                invoice_link            => undef,
            },
            expected => {
                url_returned            => undef,
            },
        },
        'Paid With Third Party (PayPal)' => {
            setup => {
                payment_method          => 'PayPal',
                third_party_status      => 'Accepted',
                invoice_link            => undef,
            },
            expected => {
                url_returned            => undef,
            },
        },
        'Paid With Third Party (Klarna) with successful klarna invoice request' => {
            setup => {
                payment_method          => 'Klarna',
                third_party_status      => 'Accepted',
                invoice_link            => $test_invoice_url,
                mock_lwp_response       => $mock_lwp_responses{pass}{mock_response},
            },
            expected => {
                url_returned            => $test_invoice_url,
                lwp_return_code         => undef,
                file_path_regex         => $test_file_path_regex,
                print_log_entry         => 1,
            },
        },
        'Paid With Third Party (Klarna) with unsuccessful klarna invoice request' => {
            setup => {
                payment_method          => 'Klarna',
                third_party_status      => 'Accepted',
                invoice_link            => $test_invoice_url,
                mock_lwp_response       => $mock_lwp_responses{fail}{mock_response},
            },
            expected => {
                url_returned            => $test_invoice_url,
                lwp_return_code         => $mock_lwp_responses{fail}{response_code},
                file_path_regex         => $test_file_path_regex,
                print_log_entry         => 0,
            },
        },
    );

    my $mock_lwp = Test::XTracker::Mock::LWP->new();
    $mock_lwp->enabled(1);

    while ( my ( $name, $test ) = each %tests ) {
        my $setup = $test->{setup};
        my $expected = $test->{expected};
        subtest $name => sub {
            $self->schema->txn_dont( sub {

                # create new order
                my $order_details   = $self->{data_helper}->new_order;
                my $order           = $order_details->{order_object}->discard_changes;
                my $shipment        = $order_details->{shipment_object};

                # get psp refs and payment method details as defined in setup
                my $payment_args        = Test::XTracker::Data->get_new_psp_refs();
                my $payment_method_name = $setup->{payment_method};
                my $payment_method      = $self->schema->resultset('Orders::PaymentMethod')
                                            ->find( {
                                                payment_method => $payment_method_name,
                                            } );
                $payment_args->{payment_method} = $payment_method;

                # create payment for the order
                my $payment = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );

                # set mocked psp parameters from setup information
                Test::XTracker::Mock::PSP->set_payment_method($payment_method_name);
                Test::XTracker::Mock::PSP->set_third_party_status($setup->{third_party_status});
                Test::XTracker::Mock::PSP->set_card_settlements( [
                       { 'invoiceLink'     => $setup->{invoice_link},
                         'settleReference' => $payment->settle_ref },
                ] );

                # get the third party invoice url for the order
                # this should return undefined for orders paid by credit card and paypal
                # orders paid using klarna should return a url
                my $url = $order->get_third_party_invoice_url;
                is($url, $expected->{url_returned}, 'The url returned by the order get_third_party_invoice_url method is as expected.');

                # test the fetching of the invoice if a url is returned
                if ( $url ) {
                    # set up mocked lwp response for successful and unsuccesful calls to klarna
                    my $mock_lwp_response = $setup->{mock_lwp_response};
                    $mock_lwp->add_response( $mock_lwp->$mock_lwp_response );

                    # test that the file path for storing the invoice is returned as expected
                    my $filepath = $shipment->get_third_party_invoice_file_path( $url, $payment_method_name );
                    ok ( $filepath =~ /$expected->{file_path_regex}/, 'The file path of the invoice matches the expected path regex' );

                    # fetch the invoice and test that the return code is as expected
                    my $invoice_response = $shipment->fetch_third_party_klarna_invoice;

                    # test that a shipment_print_log entry is created if the call is successful, or not if it fails
                    my $shipment_print_log  = $shipment->shipment_print_logs->search( { document => "$payment_method_name Invoice", file => basename($filepath) },{} )->first;
                    if ( $expected->{print_log_entry} ) {
                        ok ( $invoice_response eq $filepath, "The file name ($invoice_response) is returned as expected" );
                        ok ( $shipment->id eq $shipment_print_log->shipment_id, 'Shipment print log entry is in database as expected' ) ;
                    }
                    else {
                        ok ( $invoice_response == $expected->{lwp_return_code}, "The LWP return code ($invoice_response) is as expected" );
                        ok ( !$shipment_print_log, 'No shipment print log entry has been found in the database as expected' );
                    }
                }
            } );
        }
    }
    $mock_lwp->enabled(0);
}

=head2 test_shippable_sale_status_methods

Tests the shippable_is_full_sale and shippable_is_mixed_sale methods

=cut

sub test_shippable_sale_attributes :Tests {
    my ($self) = @_;

    my $shipment = $self->{data_helper}->new_order(
        products => 2,
        channel => $self->{channel},
    )->{shipment_object};

    # No sale items
    ok(!$shipment->shippable_is_mixed_sale, "Shipment with no sale items is not mixed sale");
    ok(!$shipment->shippable_is_full_sale, "Shipment with no sale items is not full sale");

    $shipment->shipment_items->first->update( # one sale item
        { sale_flag_id => $SHIPMENT_ITEM_ON_SALE_FLAG__YES }
    );

    ok($shipment->shippable_is_mixed_sale,
        "Shipment with one sale item and one non-sale item is mixed sale");
    ok(!$shipment->shippable_is_full_sale,
       "Shipment with one sale item and one non-sale item is not full sale");

    for my $item ($shipment->shipment_items) { # all sale items
        $item->update( { sale_flag_id => $SHIPMENT_ITEM_ON_SALE_FLAG__YES } );
    }

    ok(!$shipment->shippable_is_mixed_sale,
        "Shipment with all sale items is not mixed sale");
    ok($shipment->shippable_is_full_sale,
        "Shipment with all sale items is full sale");
}

#------------------------------------------------------------------------------

# helper to make sure and Order has a Payment
sub _create_payment_for_order {
    my ( $self, $order ) = @_;

    $order->discard_changes->payments->search_related('log_payment_preauth_cancellations')->delete;
    $order->payments->delete;
    $order->replaced_payments->search_related('log_replaced_payment_preauth_cancellations')->delete;
    $order->replaced_payments->delete;
    return Test::XTracker::Data->create_payment_for_order( $order, $self->{payment_args} );
}

# helper to create an Order which can be used in a Size Change
# or in an Exchange as it is created using Products that have
# at least two Variants, will create an Order with two Items
sub _create_new_order_suitable_for_item_change {
    my ( $self, $args ) = @_;

    my ( undef, $pids ) = Test::XTracker::Data->grab_products( {
        channel => $args->{channel},
        how_many => 2,
        how_many_variants => 2,
        ensure_stock_all_variants => 1,
        force_create => 1,
    } );

    # specify the method to use to create the Order, default is 'new_order'
    my $create_order_method = $args->{order_method} || 'new_order';

    my $order_details = $self->{data_helper}->$create_order_method(
        channel  => $self->{channel},
        products => $pids,
    );
    my $shipment = $order_details->{shipment_object};

    # get a list of all the Shipment Items
    my @shipment_items = $shipment->shipment_items->all;
    $order_details->{shipment_items} = \@shipment_items;

    # build up a Hash of Items keyed by 'item_1', 'item_2' etc.
    # so that they can be easily referenced in test specifications.
    # foreach item store the Shipment Item, that Items original
    # Variant and an Alternative Variant for the Variant's Product
    my %item_details;
    my $item_count = 1;
    foreach my $item ( @shipment_items ) {
        my ( $alt_variant ) = grep { $_->id != $item->variant_id }
                                $item->variant->product->variants->all;

        $item_details{ "item_${item_count}" } = {
            item         => $item,
            orig_variant => $item->variant,
            alt_variant  => $alt_variant,
        };
        $item_count++;
    }
    $order_details->{shipment_item_details} = \%item_details;

    # use this to remove newly created Shipment
    # Items at the beginning of each test
    my $new_ship_items_rs = $shipment->shipment_items->search( {
        id => { 'NOT IN' => [ map { $_->id } @shipment_items ] },
    } );
    $order_details->{new_ship_items_rs} = $new_ship_items_rs;

    return $order_details;
}

# helper that will create an Exchange for a Shipment
# and return Details of the Exchanged Items so that
# they can be used in Item Change Tests
sub _create_exchange_for_shipment {
    my ( $self, $shipment, $item_details, $what_to_do ) = @_;

    $shipment->discard_changes;

    my $items_to_change = $what_to_do->{items_to_exchange};
    # work out which Items (if any) are to
    # be Cancelled on the Exchange Shipment
    my %items_to_cancel = map {
        $item_details->{ $_ }->{item}->id => 1,
    } @{ $what_to_do->{items_to_cancel_after_exchange} // [] };

    # create a mapping between the item labels (such as 'item_1') and
    # the actual Shipment Item Ids so that they can be used later on
    my %item_id_to_item_label_map;

    my %items;
    while ( my ( $item, $variant_to_change_to ) = each %{ $items_to_change } ) {
        my $item_detail = $item_details->{ $item };
        my $item_id     = $item_detail->{item}->id;
        $items{ $item_id } = {
            type             => 'Exchange',
            exchange_variant => $item_detail->{ $variant_to_change_to }->id,
        };
        $item_id_to_item_label_map{ $item_id } = $item;
    }

    my $return = $self->{data_helper}->qc_passed_return( {
        shipment_id => $shipment->id,
        items       => \%items,
    } );

    # Loop round each Return Item and either Cancel its
    # Exchange Shipment Item or build up a Hash Ref.
    # of Changes in the form of:
    #   {
    #        item_1 => { orig_item_id => x, new_item_id => y }
    #   }
    # so that it can be used in a comparison test later on
    my %item_changes;
    ITEM:
    foreach my $ret_item ( $return->return_items->all ) {
        next ITEM       if ( !$ret_item->is_exchange );

        if ( exists $items_to_cancel{ $ret_item->shipment_item_id } ) {
            $ret_item->exchange_shipment_item->update( {
                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED,
            } );
            next ITEM;
        }

        # store the change for later
        my $item_label = $item_id_to_item_label_map{ $ret_item->shipment_item_id };
        $item_changes{ $item_label } = {
            orig_item_id => $ret_item->shipment_item_id,
            new_item_id  => $ret_item->exchange_shipment_item_id,
        };
    }

    return ( $return->discard_changes, \%item_changes );
}

# helper to mock 'XT::Domain::Payment::Basket', pass in a
# Hash Ref. which will be populated when methods get called
# on an Instance so that you can track what happens
sub _mock_payment_basket {
    my ( $self, $methods_to_mock, $monitor_hash ) = @_;

    my %available_methods_to_mock = (
        send_basket_to_psp           => sub {
                my ( $self, @params ) = @_;
                $monitor_hash->{method_called} = 'send_basket_to_psp';
                $monitor_hash->{params_passed} = \@params;
                return;
            },
        update_psp_with_item_changes => sub {
                my ( $self, @params ) = @_;
                $monitor_hash->{method_called} = 'update_psp_with_item_changes';
                $monitor_hash->{params_passed} = \@params;
                return;
            },
        get_balance => sub {
                my $self = shift;
                return $monitor_hash->{get_balance_return_value};
            },
    );

    # loop round the methods wanted and only get them mocked
    my %methods_to_mock;
    foreach my $method ( @{ $methods_to_mock } ) {
        $methods_to_mock{ $method } = $available_methods_to_mock{ $method };
    }

    my $mock_basket = qtakeover( 'XT::Domain::Payment::Basket' => %methods_to_mock );

    return $mock_basket;
}

# helper to do an Item Change by creating New Shipment
# Items for a Shipment and Cancelling the Original ones
sub _change_shipment_item {
    my ( $self, $shipment, $item_details, $items_to_change ) = @_;

    my @item_changes;
    while ( my ( $item, $variant_to_change_to ) = each %{ $items_to_change } ) {
        my $orig_item = $item_details->{ $item }{item};
        # create the new Shipment Item using all the same field values
        my %item_fields = $orig_item->get_columns();
        # but don't use the Id, Shipment Id or Variant Id
        delete $item_fields{ $_ }   foreach ( qw( id shipment_id variant_id ) );

        # create the new Shipment Item
        my $new_item = $shipment->create_related( 'shipment_items', {
            %item_fields,
            variant_id => $item_details->{ $item }{ $variant_to_change_to }->id,
        } );

        # now update the Status of the original Item to be Cancelled
        $orig_item->update( {
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED,
        } );

        # if the Original is an Exchange Item then update
        # the Return Item's Exchange Shipment Id
        if ( $orig_item->return_item_exchange_shipment_item_ids->count ) {
            $self->rs('Public::ReturnItem')->update_exchange_item_id( $orig_item->id, $new_item->id, 'exchange' );
        }

        push @item_changes, { orig_item_id => $orig_item->id, new_item_id => $new_item->id };
    }

    return \@item_changes;
}

