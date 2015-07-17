#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition
    dc       => [ qw( DC1 DC2 ) ];

use Test::Exception;
use Test::XTracker::Data::Order;
use Test::XTracker::OrderImporter;
use XTracker::Constants::FromDB qw/ :premier_routing/;


my $schema = Test::XTracker::Data->get_schema;
my $test_cases = [
    {
        name => 'premier zone 3 with defined premier_routing_id',
        setup => {
            DC1 => {
                order => {
                    shipping_sku => '900001-001',
                    premier_routing_id => $PREMIER_ROUTING__B,
                },
            },
            DC2 => {
                order => {
                    shipping_sku => '900025-002',
                    premier_routing_id => $PREMIER_ROUTING__B,
                },
            },
        },
        expected => {
            DC1 => {
                'PublicWebsiteXML' => {
                    shipping_sku => '900001-001',
                    premier_routing_id => $PREMIER_ROUTING__B,
                },
                'IntegrationServiceJSON' => {
                    shipping_sku => '900001-001',
                    premier_routing_id => $PREMIER_ROUTING__C,
                },
            },
            DC2 => {
                'PublicWebsiteXML' => {
                    shipping_sku => '900025-002',
                    premier_routing_id => $PREMIER_ROUTING__B,
                },
                'IntegrationServiceJSON' => {
                    shipping_sku => '900025-002',
                    premier_routing_id => $PREMIER_ROUTING__C,
                },
            },
        }
    },
    {
        name => 'premier zone 3 with no premier_routing_id',
        setup => {
            DC1 => {
                order => {
                    shipping_sku => '900001-001',
                },
            },
            DC2 => {
                order => {
                    shipping_sku => '900025-002',
                },
            },
        },
        expected => {
            DC1 => {
                'PublicWebsiteXML' => {
                    shipping_sku => '900001-001',
                    premier_routing_id => $PREMIER_ROUTING__C,
                },
                'IntegrationServiceJSON' => {
                    shipping_sku => '900001-001',
                    premier_routing_id => $PREMIER_ROUTING__C,
                },
            },
            DC2 => {
                'PublicWebsiteXML' => {
                    shipping_sku => '900025-002',
                    premier_routing_id => $PREMIER_ROUTING__C,
                },
                'IntegrationServiceJSON' => {
                    shipping_sku => '900025-002',
                    premier_routing_id => $PREMIER_ROUTING__C,
                },
            },
        }
    },
    {
        name => 'premier daytime with premier_routing_id',
        setup => {
            DC1 => {
                order => {
                    shipping_sku => '9000210-001',
                    premier_routing_id => $PREMIER_ROUTING__B,
                },
            },
            DC2 => {
                order => {
                    shipping_sku => '9000211-001',
                    premier_routing_id => $PREMIER_ROUTING__B,
                },
            },
        },
        expected => {
            DC1 => {
                'PublicWebsiteXML' => {
                    shipping_sku => '9000210-001',
                    premier_routing_id => $PREMIER_ROUTING__B,
                },
                'IntegrationServiceJSON' => {
                    shipping_sku => '9000210-001',
                    premier_routing_id => $PREMIER_ROUTING__D,
                },
            },
            DC2 => {
                'PublicWebsiteXML' => {
                    shipping_sku => '9000211-001',
                    premier_routing_id => $PREMIER_ROUTING__B,
                },
                'IntegrationServiceJSON' => {
                    shipping_sku => '9000211-001',
                    premier_routing_id => $PREMIER_ROUTING__D,
                },
            },
        }
    },
    {
        name => 'premier daytime without premier_routing_id',
        setup => {
            DC1 => {
                order => {
                    shipping_sku => '9000210-001',
                },
            },
            DC2 => {
                order => {
                    shipping_sku => '9000211-001',
                },
            },
        },
        expected => {
            DC1 => {
                'PublicWebsiteXML' => {
                    shipping_sku => '9000210-001',
                    premier_routing_id => $PREMIER_ROUTING__D,
                },
                'IntegrationServiceJSON' => {
                    shipping_sku => '9000210-001',
                    premier_routing_id => $PREMIER_ROUTING__D,
                },
            },
            DC2 => {
                'PublicWebsiteXML' => {
                    shipping_sku => '9000211-001',
                    premier_routing_id => $PREMIER_ROUTING__D,
                },
                'IntegrationServiceJSON' => {
                    shipping_sku => '9000211-001',
                    premier_routing_id => $PREMIER_ROUTING__D,
                },
            },
        }
    }
];

Test::XTracker::OrderImporter->run_tests(
    $test_cases,
    sub {
        my($order,$expected) = @_;

        my $sku = $expected->{shipping_sku};
        my $premier_routing_id = $expected->{premier_routing_id};


        my $shipment = $order->shipments->first;
        is(ref($shipment),'XTracker::Schema::Result::Public::Shipment',
            'we have a shipment');

        is($shipment->premier_routing_id, $premier_routing_id,
            "premier_routing_id as expected");
        is($shipment->shipping_charge_table->sku, $sku,
            "shipping sku as expected - $sku");

    }
);



# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;
