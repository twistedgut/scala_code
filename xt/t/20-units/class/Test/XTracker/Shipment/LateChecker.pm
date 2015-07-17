package Test::XTracker::Shipment::LateChecker;
use NAP::policy qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Address';
};

sub get_schema { return shift->schema }

use XTracker::Shipment::LateChecker;
use Test::XTracker::Data::Shipping;
use Test::XTracker::Data;

sub test__send_late_shipment_notification :Tests {
    my ($self) = @_;

    for my $test (
        {
            name => 'E-mail is generated successfully',
        }
    ) {
        subtest $test->{name} => sub {

            my ($channel, $pids) = Test::XTracker::Data->grab_products({
                how_many => 1,
            });

            my ($order, $hash) = Test::XTracker::Data->create_db_order({
                pids    => $pids,
                channel => $channel,
            });

            my $shipment = $order->shipments->first();
            my $checker = XTracker::Shipment::LateChecker->new();
            ok($checker->send_late_shipment_notification({ shipment => $shipment }),
               'Late shipment notification sent successfully');
        };
    }
}

sub test__check_address :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Address returns as will-be-late when in matching GB remote location',
            setup   => {
                late_postcodes  => [
                    {
                        shipping_sku    => '123456-789',
                        country         => 'GB',
                        postcode        => 'ZX81',
                    }
                ],
                shipping_skus    => [
                    '123456-789',
                ],
                check_address_parameters => {
                    address     => {
                        country => 'GB',
                        postcode=> 'ZX81 7HZ',
                    },
                    shipping_sku=> '123456-789',
                },
            },
            result => {
                will_be_late => 1,
            }
        },
        {
            name    => 'Address does not return as will-be-late when right country but wrong postcode',
            setup   => {
                late_postcodes  => [
                    {
                        shipping_sku    => '123456-789',
                        country         => 'GB',
                        postcode        => 'ZX80',
                    }
                ],
                shipping_skus    => [
                    '123456-789',
                ],
                check_address_parameters => {
                    address     => {
                        country => 'GB',
                        postcode=> 'ZX81 7HZ',
                    },
                    shipping_sku=> '123456-789',
                },
            },
            result => {
                will_be_late => 0,
            }
        },
        {
            name    => 'Address does not return as will-be-late when right country but invalid postcode',
            setup   => {
                late_postcodes  => [
                    {
                        shipping_sku    => '123456-789',
                        country         => 'GB',
                        postcode        => 'ZX81',
                    }
                ],
                shipping_skus    => [
                    '123456-789',
                ],
                check_address_parameters => {
                    address     => {
                        country => 'GB',
                        postcode=> 'WWW',
                    },
                    shipping_sku=> '123456-789',
                },
            },
            result => {
                will_be_late => 0,
            }
        },
        {
            name    => 'Address does not return as will-be-late when right country and postcode, but wrong shipping-sku',
            setup   => {
                late_postcodes  => [
                    {
                        shipping_sku    => '123456-789',
                        country         => 'GB',
                        postcode        => 'ZX80',
                    }
                ],
                shipping_skus    => [
                    '123456-789',
                    '123456-742',
                ],
                check_address_parameters => {
                    address     => {
                        country => 'GB',
                        postcode=> 'ZX81 7HZ',
                    },
                    shipping_sku=> '123456-742',
                },
            },
            result => {
                will_be_late => 0,
            }
        }
    ) {
        subtest $test->{name} => sub {
            my ($late_checker, $address, $shipping_charge) = $self->_create_test_data($test);

            is($late_checker->check_address({
                address         => $address,
                shipping_charge => $shipping_charge,
            }), $test->{result}->{will_be_late},
                sprintf('Check address returns expected value: %s', $test->{result}->{will_be_late}));
        };
    }
}

sub _create_test_data {
    my ($self, $test) = @_;

    my $shipping_charges = {};

    for my $shipping_sku (@{$test->{setup}->{shipping_skus}}) {
        $shipping_charges->{$shipping_sku} = $self->schema->resultset('Public::ShippingCharge')->find({
            sku => $shipping_sku,
        }) // Test::XTracker::Data::Shipping->create_shipping_charge({
            sku => $shipping_sku,
        });
    }

    my @late_postcode_ids;
    for my $late_postcode_def (@{$test->{setup}->{late_postcodes}}) {
        my $charge_id = $shipping_charges->{$late_postcode_def->{shipping_sku}}->id();
        my $country_id = $self->schema->resultset('Public::Country')->find({
            code => $late_postcode_def->{country},
        })->id();

        push(@late_postcode_ids,
            $self->schema->resultset('Public::ShippingChargeLatePostcode')->find_or_create({
                shipping_charge_id  => $charge_id,
                country_id          => $country_id,
                postcode            => $late_postcode_def->{postcode},
            })->id()
        );
    }

    my $address = $self->create_order_address({
        country     => $self->schema->resultset('Public::Country')->find({
                code => $test->{setup}->{check_address_parameters}->{address}->{country},
            })->country(),
        postcode    => $test->{setup}->{check_address_parameters}->{address}->{postcode},
    });

    my $shipping_charge = $shipping_charges->{$test->{setup}->{check_address_parameters}->{shipping_sku}};

    my $latepostcode_rs = $self->schema->resultset('Public::ShippingChargeLatePostcode')->search({
        'me.id' => \@late_postcode_ids,
    });

    my $late_checker = XTracker::Shipment::LateChecker->new({
        latepostcode_rs => $latepostcode_rs,
    });

    return ($late_checker, $address, $shipping_charge);
}
