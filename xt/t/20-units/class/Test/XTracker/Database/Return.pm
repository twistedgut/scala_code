package Test::XTracker::Database::Return;
use NAP::policy "tt", 'class', 'test';

use Test::XTracker::LoadTestConfig;

use XTracker::Database::Return qw/ calculate_returns_charge /;
use Test::MockObject;
use Test::MockModule;

BEGIN {
    extends 'NAP::Test::Class';

    has 'test_shipping_charge' => ( is => 'ro', default => 42 );
    has 'test_returns_charge' => ( is => 'ro', default => 24 );
    has 'test_returns_charge_returned' => ( is => 'ro', default => -24 );
};

sub test__calculate_returns_charge :Tests {
    my ($self) = @_;

    my $tests = [
        {
            name        => 'Shipping Charge allows free returns (but no refund)',
            setup       => {
                shipment => {
                    shipping_charge_table   => {
                        is_return_shipment_free => 1,
                    },
                    renumerations           => {
                        previous_shipping_refund => 0,
                    },
                    shipping_charge         => $self->test_shipping_charge(),
                    business                => {
                        does_refund_shipping    => 0,
                    },
                },
                return_charge => {
                    charge => $self->test_returns_charge(),
                },
                call_params => {

                },
            },
            expected    => {
                shipping_refund => 0,
                shipping_charge => 0,
            },
        },

        {
            name        => 'No return charge or refund if all return items are exchanges',
            setup       => {
                shipment => {
                    shipping_charge_table => {
                        is_return_shipment_free => 0,
                    },
                    renumerations           => {
                        previous_shipping_refund => 0,
                    },
                    shipping_charge         => $self->test_shipping_charge(),
                    business                => {
                        does_refund_shipping    => 0,
                    },
                },
                return_charge => {
                    charge => $self->test_returns_charge(),
                },
                call_params => {
                    num_exchange_items  => 2,
                    num_return_items    => 2,
                },
            },
            expected    => {
                shipping_refund => 0,
                shipping_charge => 0,
            },
        },

        {
            name        => 'Refund if there is a faulty item (and not previously refunded)',
            setup       => {
                shipment => {
                    shipping_charge_table => {
                        is_return_shipment_free => 0,
                    },
                    renumerations           => {
                        previous_shipping_refund => 0,
                    },
                    shipping_charge         => $self->test_shipping_charge(),
                    business                => {
                        does_refund_shipping    => 0,
                    },
                },
                return_charge => {
                    charge => $self->test_returns_charge(),
                },
                call_params => {
                    got_faulty_items => 1
                },
            },
            expected    => {
                shipping_refund => $self->test_shipping_charge(),
                shipping_charge => 0,
            },
        },

        {
            name        => 'No refund if there is a faulty item but have refunded already',
            setup       => {
                shipment => {
                    shipping_charge_table => {
                        is_return_shipment_free => 0,
                    },
                    renumerations           => {
                        previous_shipping_refund => 1,
                    },
                    shipping_charge         => $self->test_shipping_charge(),
                    business                => {
                        does_refund_shipping    => 0,
                    },
                },
                return_charge => {
                    charge => $self->test_returns_charge(),
                },
                call_params => {
                    got_faulty_items => 1
                },
            },
            expected    => {
                shipping_refund => 0,
                shipping_charge => 0,
            },
        },

        {
            name        => 'Refund original shipping if no faulty items but business ' .
                            'allows it, and charge for return shipping',
            setup       => {
                shipment => {
                    shipping_charge_table => {
                        is_return_shipment_free => 0,
                    },
                    renumerations           => {
                        previous_shipping_refund => 0,
                    },
                    shipping_charge         => $self->test_shipping_charge(),
                    business                => {
                        does_refund_shipping    => 1,
                    },
                },
                return_charge => {
                    charge => $self->test_returns_charge(),
                },
                call_params => {
                    got_faulty_items => 0,
                },
            },
            expected    => {
                shipping_refund => $self->test_shipping_charge(),
                shipping_charge => $self->test_returns_charge_returned(),
            },
        },

        {
            name        => 'Do not refund original shipping if no faulty items and ' .
                            'business does not allow it, and charge for return shipping',
            setup       => {
                shipment => {
                    shipping_charge_table => {
                        is_return_shipment_free => 0,
                    },
                    renumerations           => {
                        previous_shipping_refund => 0,
                    },
                    shipping_charge         => $self->test_shipping_charge(),
                    business                => {
                        does_refund_shipping    => 0,
                    },
                },
                return_charge => {
                    charge => $self->test_returns_charge(),
                },
                call_params => {
                    got_faulty_items => 0,
                },
            },
            expected    => {
                shipping_refund => 0,
                shipping_charge => $self->test_returns_charge_returned(),
            },
        },
    ];

    for my $test (@$tests) {
        subtest $test->{name} => sub {
            my $mock_shipment = $self->_create_mock_shipment($test);

            my ($shipping_refund, $shipping_charge);
            lives_ok {
                ($shipping_refund, $shipping_charge) = calculate_returns_charge({
                    shipment_row    => $mock_shipment,
                    %{ $test->{setup}->{call_params} },
                });
            } 'calculate_returns_charge() lives';

            eq_or_diff({
                shipping_refund => $shipping_refund,
                shipping_charge => $shipping_charge,
            }, $test->{expected}, 'Return values are as expected');

        };
    }

}

sub _create_mock_shipment {
    my ($self, $test) = @_;

    my $mock_shipping_charge = Test::MockObject->new();
    $mock_shipping_charge->mock('is_return_shipment_free', sub {
        $test->{setup}->{shipment}->{shipping_charge_table}->{is_return_shipment_free};
    });

    my $mock_renumerations = Test::MockObject->new();
    $mock_renumerations->mock('previous_shipping_refund', sub {
        $test->{setup}->{shipment}->{renumerations}->{previous_shipping_refund};
    });

    my $mock_business = Test::MockObject->new();
    $mock_business->mock('does_refund_shipping', sub {
        $test->{setup}->{shipment}->{business}->{does_refund_shipping};
    });

    my $mock_return_charge = Test::MockObject->new();
    $mock_return_charge->mock('charge', sub {
        $test->{setup}->{return_charge}->{charge};
    });

    my $mock_shipment = Test::MockObject->new();
    $mock_shipment->mock('shipping_charge_table', sub {
        $mock_shipping_charge
    });
    $mock_shipment->mock('renumerations', sub {
        $mock_renumerations
    });
    $mock_shipment->mock('get_business', sub {
        $mock_business
    });
    $mock_shipment->mock('shipping_charge', sub {
        $test->{setup}->{shipment}->{shipping_charge}
    });
    $mock_shipment->mock('get_return_charge', sub {
        $mock_return_charge
    });

    return $mock_shipment;
}
