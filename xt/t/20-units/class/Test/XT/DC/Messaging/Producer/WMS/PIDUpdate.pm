package Test::XT::DC::Messaging::Producer::WMS::PIDUpdate;
use NAP::policy "tt", 'class', 'test';

BEGIN {
    extends 'NAP::Test::Class';
};

use XTracker::Config::Local 'config_var';
use XTracker::Constants::FromDB ':storage_type';

use Test::XTracker::MessageQueue;
use Test::XTracker::Data;

=head1 NAME

Test::XT::DC::Messaging::Producer::WMS::PIDUpdate

=head2 test_transform

Tests for the transform method in the PIDUpdate producer

=cut

sub test_transform :Tests {
    my ($self) = @_;

    my $message_queue = Test::XTracker::MessageQueue->new();

    for (
        [
            'test voucher dimensions',
            sub { Test::XTracker::Data->create_voucher; },
            { map { $_ => sub { config_var('Voucher', $_) } } qw/length width height weight/ },
        ],
        [
            'test happy path',
            sub { $self->get_product({
                shipping_attribute => {
                    length => 1, width => 2, height => 3, weight => 4,
                },
            }); },
            # Quote dimensions get them to play nice with the 'is' test below
            {
                length => sub { '1.000' },
                width  => sub { '2.000' },
                height => sub { '3.000' },
                weight => sub { '4.000' },
                client => sub { shift->get_product_channel->channel->client->get_client_code; },
            },
        ],
        [
            'test no dimensions set',
            sub { $self->get_product({ shipping_attribute => {
                length => undef, width => undef, height => undef, weight => undef,
            }}); },
            { length => sub {}, width => sub {}, height => sub {}, weight => sub {}, },
        ],
        [
            'test no storage type',
            sub { $self->get_product({storage_type_id => undef}); },
            {},
            qr{Unable to determine storage type for product},
        ],
    ) {
        my ( $test_name, $product_ref, $expected, $error ) = @$_;

        subtest $test_name => sub {
            # Execute the product caller in here so the product is created
            # within the correct subtest
            my $product = $product_ref->();
            if ( $error ) {
                throws_ok( sub {
                    $message_queue->transform(
                        'XT::DC::Messaging::Producer::WMS::PidUpdate',
                        $product,
                    );
                }, $error );
                return;
            }
            my ($headers, $body) = $message_queue->transform(
                'XT::DC::Messaging::Producer::WMS::PidUpdate', $product
            );
            is($body->{$_}, $expected->{$_}($product), "$_ should match")
                for sort keys %$expected;
        };
    }
}

sub get_product {
    my ( $self, $args ) = @_;
    return (Test::XTracker::Data->grab_products({
        force_create => 1,
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        %{$args||{}},
    }))[1][0]{product};
}
