#!/usr/bin/env perl

use NAP::policy     qw( test );
use parent "NAP::Test::Class";

=head1 NAME

staff_order.t - Tests Staff Orders

=head1 DESCRIPTION

Checks that Staff Orders are imported correctly.

=cut


use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use XTracker::Config::Local         qw( config_var internal_staff_shipping_sku );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :customer_category );
use Test::XT::Data;

use Test::XTracker::Mock::Service::Seaview;
use Test::XTracker::Mock::PSP;

use DateTime;


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{channels} = [ $self->schema->resultset('Public::Channel')->fulfilment_only( 0 )->enabled ];
    $self->{category} = {
        map { $_->id => $_->category } $self->rs('Public::CustomerCategory')->all
    };

    # make sure Fake Seaview will use the Defaults for Account requests
    Test::XTracker::Mock::Service::Seaview->clear_get_account_response();
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;

    Test::XTracker::Data::Order->purge_order_directories();

    # re-set Seaview Account requests to using the Default
    Test::XTracker::Mock::Service::Seaview->clear_get_account_response();
}


=head1 TESTS

=head2 test__preprocess_customer_for_staff

Tests the method '_preprocess_customer' method that decides whether the
Customer is of Category Staff before the Order gets imported and if so
that the Nomindated Day values are 'undef' and the Internal Staff
Shipping SKU is used.

Checks that for Existing Customers that the Customer Category on the
Customer record is always used regardless of the Email Address used.

=cut

sub test__preprocess_customer_for_staff : Tests {
    my $self = shift;

    my $channel = $self->{channels}[0];

    my $cust_cat_default = $self->rs('Public::CustomerCategoryDefault');
    $cust_cat_default->delete;
    # create Email Domain for Staff
    $cust_cat_default->create( {
        category_id  => $CUSTOMER_CATEGORY__STAFF,
        email_domain => 'net-a-porter.com',
    } );
    # create another Email Domain but in a different Case
    $cust_cat_default->create( {
        category_id  => $CUSTOMER_CATEGORY__STAFF,
        email_domain => 'Net-A-Porter.com',
    } );
    # create Email Domain with Spaces in it for Staff
    $cust_cat_default->create( {
        category_id  => $CUSTOMER_CATEGORY__STAFF,
        email_domain => ' theoutnet.com ',
    } );
    # create Email Domain for Press
    $cust_cat_default->create( {
        category_id  => $CUSTOMER_CATEGORY__PRESS_CONTACT,
        email_domain => 'press.com',
    } );

    # get Shipping SKUs
    my $internal_staff_sku = internal_staff_shipping_sku( $self->schema, $channel->id );
    my $shipping_charge    = $channel->shipping_charges->search( {
        sku                => { '!=' => $internal_staff_sku },
        is_customer_facing => 1,
        is_enabled         => 1,
        latest_nominated_dispatch_daytime => { 'IS NOT' => undef },
    } )->first;

    ok( $internal_staff_sku, "Internal Staff Shipping SKU sanity check" );
    isa_ok( $shipping_charge, 'XTracker::Schema::Result::Public::ShippingCharge',
                                    "Nominated Day Shipping SKU sanity check" );

    my $customer_rs = $self->rs('Public::Customer');

    my $nom_dispatch_date = DateTime->now->add( days => 1 );
    my $nom_delivery_date = DateTime->now->add( days => 3 );

    my %tests = (
        "Using a Non Customer Category Default Email Domain with Existing Non-Staff Customer" => {
            setup => {
                email             => 'test@example.com',
                existing_customer => 1,
                category_id       => $CUSTOMER_CATEGORY__NONE,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__NONE,
                shipping_sku      => $shipping_charge->sku,
                nominated_day     => 1,
                is_staff_shipping => 0,
            },
        },
        "Using a Staff Customer Category Default Email Domain with Existing Non-Staff Customer" => {
            setup => {
                email             => 'test@net-a-porter.com',
                existing_customer => 1,
                category_id       => $CUSTOMER_CATEGORY__NONE,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__NONE,
                shipping_sku      => $shipping_charge->sku,
                nominated_day     => 1,
                is_staff_shipping => 0,
            },
        },
        "Using a Non Customer Category Default Email Domain with Existing Staff Customer" => {
            setup => {
                email             => 'test@example.com',
                existing_customer => 1,
                category_id       => $CUSTOMER_CATEGORY__STAFF,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__STAFF,
                shipping_sku      => $internal_staff_sku,
                nominated_day     => 0,
                is_staff_shipping => 1,
            },
        },
        "Using a Staff Customer Category Default Email Domain with Existing Staff Customer" => {
            setup => {
                email             => 'test@net-a-porter.com',
                existing_customer => 1,
                category_id       => $CUSTOMER_CATEGORY__STAFF,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__STAFF,
                shipping_sku      => $internal_staff_sku,
                nominated_day     => 0,
                is_staff_shipping => 1,
            },
        },
        "Using a Non Customer Category Default Email Domain with a New Customer" => {
            setup => {
                email             => 'test@example.com',
                existing_customer => 0,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__NONE,
                shipping_sku      => $shipping_charge->sku,
                nominated_day     => 1,
                is_staff_shipping => 0,
            },
        },
        "Using a Staff Customer Category Default Email Domain with a New Customer" => {
            setup => {
                email             => 'test@net-a-porter.com',
                existing_customer => 0,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__STAFF,
                shipping_sku      => $internal_staff_sku,
                nominated_day     => 0,
                is_staff_shipping => 1,
            },
        },
        "Using a Non Staff Customer Category Default Email Domain with a New Customer" => {
            setup => {
                email             => 'test@press.com',
                existing_customer => 0,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__PRESS_CONTACT,
                shipping_sku      => $shipping_charge->sku,
                nominated_day     => 1,
                is_staff_shipping => 0,
            },
        },
        "Check that the case of the Email Domain is Unimportant for New Customers" => {
            setup => {
                email             => 'test@NET-A-PORTER.COM',
                existing_customer => 0,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__STAFF,
                shipping_sku      => $internal_staff_sku,
                nominated_day     => 0,
                is_staff_shipping => 1,
            },
        },
        "Check that an Email Domain having Spaces, is Unimportant when matching against a Default that doesn't have Spaces" => {
            setup => {
                email             => ' test@net-a-Porter.COM ',
                existing_customer => 0,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__STAFF,
                shipping_sku      => $internal_staff_sku,
                nominated_day     => 0,
                is_staff_shipping => 1,
            },
        },
        "Check that an Email Domain without Spaces, is Unimportant when matching against a Default that does have Spaces" => {
            setup => {
                email             => 'test@theoutnet.com',
                existing_customer => 0,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__STAFF,
                shipping_sku      => $internal_staff_sku,
                nominated_day     => 0,
                is_staff_shipping => 1,
            },
        },
        "Check an Existing EIP Customer stays an EIP when using a Non Default Email Domain" => {
            setup => {
                email             => 'test@example.com',
                existing_customer => 1,
                category_id       => $CUSTOMER_CATEGORY__EIP,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__EIP,
                shipping_sku      => $shipping_charge->sku,
                nominated_day     => 1,
                is_staff_shipping => 0,
            },
        },
        "Check an Existing EIP Customer stays an EIP when using a Default Email Domain" => {
            setup => {
                email             => 'test@press.com',
                existing_customer => 1,
                category_id       => $CUSTOMER_CATEGORY__EIP,
            },
            expect => {
                category_id       => $CUSTOMER_CATEGORY__EIP,
                shipping_sku      => $shipping_charge->sku,
                nominated_day     => 1,
                is_staff_shipping => 0,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        Test::XTracker::Data::Order->purge_order_directories();

        note "Testing: ${label}";
        my $test = $tests{ $label };

        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        my $customer_number;
        if ( $setup->{existing_customer} ) {
            my $data = Test::XT::Data->new_with_traits(
                traits => [
                    'Test::XT::Data::Channel',
                    'Test::XT::Data::Customer',
                ],
            );
            $data->channel( $channel );     # explicitly set the Sales Channel otherwise it will default to NaP
            my $customer = $data->customer;
            $customer->update( {
                category_id => $setup->{category_id},
                email       => $setup->{email},
            } );
            $customer_number = $customer->discard_changes->is_customer_number;
            # make sure the Category Fake Seaview will return is the same as in the DB
            Test::XTracker::Mock::Service::Seaview->set_customer_category(
                $self->{category}{ $setup->{category_id} },
            );
        }
        else {
            $customer_number = $customer_rs->get_column('is_customer_number')->max // 0;
            $customer_number++;
        }

        # Set-up options for the the Order XML file that will be created
        my $order_args = {
            customer => {
                id    => $customer_number,
                email => $setup->{email},
            },
            order => {
                channel_prefix => $channel->business->config_section,
                shipping_sku   => $shipping_charge->sku,
                nominated_day => {
                    nominated_delivery_date => $nom_delivery_date,
                    nominated_dispatch_date => $nom_dispatch_date,
                },
            },
        };

        # Create and Parse Order File
        my $data_order;
        subtest "Imported Order" => sub {
            ( $data_order ) = Test::XTracker::Data::Order->create_order_xml_and_parse( $order_args );
        };

        # Pre-Process the Customer, which will work out Customer Category
        $data_order->_preprocess_customer();
        # Pre-Process the Shipment which sets the Shipping Charge
        $data_order->_preprocess_shipment();

        # check everything is as expected
        cmp_ok( $data_order->customer_category_id, '==', $expect->{category_id},
                                "Customer Category Id set as Expected" );
        is( $data_order->shipping_charge->sku, $expect->{shipping_sku},
                                "Shipping SKU is as Expected" );
        cmp_ok( $data_order->_is_staff_shipping_sku, '==', $expect->{is_staff_shipping},
                                "'_is_staff_shipping_sku' flag set as Expected" );
        if ( $expect->{nominated_day} ) {
            isa_ok( $data_order->nominated_delivery_date, 'XT::Data::DateStamp',
                                "Nominated Delivery Date is set" );
            isa_ok( $data_order->nominated_dispatch_date, 'XT::Data::DateStamp',
                                "Nominated Dispatch Date is set" );
        }
        else {
            ok( !defined $data_order->nominated_delivery_date, "Nominated Delivery Date is 'undef'" );
            ok( !defined $data_order->nominated_dispatch_date, "Nominated Dispatch Date is 'undef'" );
        }

        my $order;
        lives_ok {
            $order = $data_order->digest( { skip => 1 } );
        } "Order Digested";

        my $customer = $order->discard_changes->customer;
        cmp_ok( $customer->category_id, '==', $expect->{category_id},
                                "Customer Category as Expected after Order Digested" );
    }
}

Test::Class->runtests;
