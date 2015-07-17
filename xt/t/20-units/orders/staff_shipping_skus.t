#!/usr/bin/env perl

use NAP::policy "tt",     'test';

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::OrderImporter;
use XTracker::Constants::FromDB qw/ :customer_category/;


my $schema = Test::XTracker::Data->get_schema;
$schema->txn_begin();

# wipe out contents of 'customer_category_default' and then
# specifically put 'net-a-porter.com' as a Staff email domain
my $cust_cat_default = $schema->resultset('Public::CustomerCategoryDefault');
$cust_cat_default->delete;
$cust_cat_default->create( {
    category_id  => $CUSTOMER_CATEGORY__STAFF,
    email_domain => 'net-a-porter.com',
} );

# get a Customer Number for existing Staff Customers
my $staff_customer_number = _create_staff_customer_for_test_channels( $schema );

my $test_cases = [
    {
        name => 'new staff get categorised',
        setup => {
            DC1 => {
                customer => {
                    id => '[UNIQUEME]',
                    email => '[UNIQUEME]@net-a-porter.com',
                },
                order => {
                    shipping_sku => '900001-001',
                },
            },
            DC2 => {
                customer => {
                    id => '[UNIQUEME]',
                    email => '[UNIQUEME]@net-a-porter.com',
                },
                order => {
                    shipping_sku => '900025-002',
                },
            },
            DC3 => {
                customer => {
                    id => '[UNIQUEME]',
                    email => '[UNIQUEME]@net-a-porter.com',
                },
                order => {
                    shipping_sku => '9000311-001',
                },
            },
        },
        expected => {
            DC1 => {
                'PublicWebsiteXML' => {
                    category_id => $CUSTOMER_CATEGORY__STAFF,
                    shipping_sku => '920005-001',
                },
                'IntegrationServiceJSON' => {
                    category_id => $CUSTOMER_CATEGORY__STAFF,
                    # should not change - this is for JC - no staff orders
                    shipping_sku => '900001-001',
                },
            },
            DC2 => {
                'PublicWebsiteXML' => {
                    category_id => $CUSTOMER_CATEGORY__STAFF,
                    shipping_sku => '920008-001',
                },
                # this will be for JC for which we don't deal with 'staff
                # deliveries'
                'IntegrationServiceJSON' => {
                    category_id => $CUSTOMER_CATEGORY__STAFF,
                    shipping_sku => '900025-002',
                },
            },
            DC3 => {
                'PublicWebsiteXML' => {
                    category_id => $CUSTOMER_CATEGORY__STAFF,
                    shipping_sku => '9000322-001',
                },
            },
        }
    },
    {
        name => 'existing staff get categorised',
        setup => {
            DC1 => {
                customer => {
                    id => $staff_customer_number,
                    # email domains don't need to be NAP Group
                    # if Customer's Category is already Staff
                    email => '[UNIQUEME]@example.com',
                },
                order => {
                    shipping_sku => '900001-001',
                },
            },
            DC2 => {
                customer => {
                    id => $staff_customer_number,
                    email => '[UNIQUEME]@example.com',
                },
                order => {
                    shipping_sku => '900025-002',
                },
            },
            DC3 => {
                customer => {
                    id => $staff_customer_number,
                    email => '[UNIQUEME]@example.com',
                },
                order => {
                    shipping_sku => '9000311-001',
                },
            },
        },
        expected => {
            DC1 => {
                'PublicWebsiteXML' => {
                    category_id => $CUSTOMER_CATEGORY__STAFF,
                    shipping_sku => '920005-001',
                },
                'IntegrationServiceJSON' => {
                    category_id => $CUSTOMER_CATEGORY__STAFF,
                    # should not change - this is for JC - no staff orders
                    shipping_sku => '900001-001',
                },
            },
            DC2 => {
                'PublicWebsiteXML' => {
                    category_id => $CUSTOMER_CATEGORY__STAFF,
                    shipping_sku => '920008-001',
                },
                # this will be for JC for which we don't deal with 'staff
                # deliveries'
                'IntegrationServiceJSON' => {
                    category_id => $CUSTOMER_CATEGORY__STAFF,
                    shipping_sku => '900025-002',
                },
            },
            DC3 => {
                'PublicWebsiteXML' => {
                    category_id => $CUSTOMER_CATEGORY__STAFF,
                    shipping_sku => '9000322-001',
                },
            },
        }
    },
    {
        name => 'non-staff keep their original sku',
        setup => {
            DC1 => {
                customer => {
                    id => '[UNIQUEME]',
                    email => '[UNIQUEME]@non-nap.com',
                },
                order => {
                    shipping_sku => '900001-001',
                },
            },
            DC2 => {
                customer => {
                    id => '[UNIQUEME]',
                    email => '[UNIQUEME]@non-nap.com',
                },
                order => {
                    shipping_sku => '900025-002',
                },
            },
            DC3 => {
                customer => {
                    id => '[UNIQUEME]',
                    email => '[UNIQUEME]@non-nap.com',
                },
                order => {
                    shipping_sku => '9000311-001',
                },
            },

        },
        expected => {
            DC1 => {
                'PublicWebsiteXML' => {
                    category_id => $CUSTOMER_CATEGORY__NONE,
                    shipping_sku => '900001-001',
                },
                'IntegrationServiceJSON' => {
                    category_id => $CUSTOMER_CATEGORY__NONE,
                    shipping_sku => '900001-001',
                },
            },
            DC2 => {
                'PublicWebsiteXML' => {
                    category_id => $CUSTOMER_CATEGORY__NONE,
                    shipping_sku => '900025-002',
                },
                'IntegrationServiceJSON' => {
                    category_id => $CUSTOMER_CATEGORY__NONE,
                    shipping_sku => '900025-002',
                },
            },
            DC3 => {
                'PublicWebsiteXML' => {
                    category_id => $CUSTOMER_CATEGORY__NONE,
                    shipping_sku => '9000311-001',
                },

            },
        }
    }
];


Test::XTracker::OrderImporter->run_tests(
    $test_cases,
    sub {
        my($order,$expected) = @_;

        note "CUSTEMAIL: ". $order->customer->email;
        note "CUSTOMERID: ". $order->customer->id;
        note "SHIPMENTID: ". $order->shipments->first->id;

        my $cat_id = $expected->{category_id};
        is($order->customer->category_id, $cat_id,
            "customer flagged as category expected ($cat_id)");


        my $shipment = $order->shipments->first;
        is(ref($shipment),'XTracker::Schema::Result::Public::Shipment',
            'we have a shipment');

        is($shipment->shipping_charge_table->sku, $expected->{shipping_sku},
            "shipping sku is what we expected");
    }
);

# remove all test data
$schema->txn_rollback();

# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;

#------------------------------------------------------------------------

# create a Staff Customer for each Channel the Tests will run against
sub _create_staff_customer_for_test_channels {
    my $schema = shift;

    my $dc = Test::XTracker::Data->whatami;
    my $channels = Test::XTracker::OrderImporter->channel_parser_test_cases->{ $dc };

    my $channel_rs = $schema->resultset('Public::Channel');

    my $customer_number;
    foreach my $channel ( @{ $channels } ) {
        # get the channel record
        my $channel_rec = $channel_rs->search(
            {
                'business.config_section' => $channel->{channel_name},
            },
            {
                join => 'business',
            }
        )->first;

        my $customer = Test::XTracker::Data->create_dbic_customer( {
            channel_id  => $channel_rec->id,
            category_id => $CUSTOMER_CATEGORY__STAFF,
        } );

        # use the same Customer Number for every Customer
        $customer_number //= $customer->is_customer_number;
        $customer->discard_changes->update( { is_customer_number => $customer_number } );
    }

    # return the Customer Number that
    # can be fed into the Test Cases
    return $customer_number;
}

