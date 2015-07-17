package Test::XT::DC::Messaging::Producer::PRL::SKUUpdate;

use FindBin::libs;
use NAP::policy "tt", 'test', 'class';

BEGIN {
    extends "NAP::Test::Class";
}
use Test::XTracker::Data;
use XT::DC::Messaging::Producer::PRL::SKUUpdate;
use XTracker::Constants qw/:prl_type/;
use XTracker::Constants::FromDB qw/:business/;

=head1 NAME

Test::XT::DC::Messaging::Producer::PRL::SKUUpdate - Unit tests for XT::DC::Messaging::Producer::PRL::SKUUpdate

=head1 DESCRIPTION

Unit tests for XT::DC::Messaging::Producer::PRL::SKUUpdate

=head1 SYNOPSIS

 # Run all tests
 prove t/20-units/class/Test/XT/DC/Messaging/Producer/PRL/SKUUpdate.pm

 # Run all tests matching the foo_bar regex
 TEST_METHOD=foo_bar  prove t/20-units/class/Test/XT/DC/Messaging/Producer/PRL/SKUUpdate.pm

 # For more details, perldoc NAP::Test::Class

=cut

sub details : Tests() {

    # Tests against the details hash. The right-hand side can either
    # be a string/number or a subref which will get passed:
    # $channel, $item, $product, $variant (as pulled out in the test body)
    my @common_checks = (
        # Remove this hard coded value when there is a logic to calculate it
        [ 'cycle_count_frequency' => 91 ],
        [ 'sku'                   => sub { $_[1]->{'sku'} } ],
        [ 'name'                  => sub { $_[2]->name } ],
        [ 'image_url'             => sub {
                sprintf(
                    'http://cache.net-a-porter.com/images/products/%d/%d_in_m.jpg',
                    $_[2]->id,
                    $_[2]->id
                )
            }
        ],
    );

    TEST:
    for my $type (
        {
            name  => 'Garment',
            setup => { how_many => 1, channel => 'nap' },
            expect => [
                [ 'family_group' => $PRL_TYPE__FAMILY__GARMENT ],
                [ client         => $PRL_TYPE__CLIENT__NAP     ],
                [ channel        => $PRL_TYPE__CHANNEL__NAP    ],
                [ designer       => sub { $_[2]->designer->designer } ],
                [ description    => sub { $_[2]->product_attribute->description } ],
                [ size           => sub { $_[3]->designer_size->size } ],
                [ color          => sub { $_[2]->colour->colour } ],
                [ 'storage_type' => sub {
                    $_[2]->storage_type ? ($_[2]->storage_type->name) || 'Flat' : 'Flat'
                }],
                [ weight_lbs     => sub { $_[2]->shipping_attribute->weight || 0 } ],
                [ length_cm      => sub { $_[3]->get_measurements->{'Length'} || 0 }],
            ],
        },
        {
            name  => 'Voucher',
            setup => {
                how_many => 0,
                channel => 'nap',
                phys_vouchers => { how_many => 1, },
            },
            expect => [
                [ 'family_group' => $PRL_TYPE__FAMILY__VOUCHER ],
                [ client         => $PRL_TYPE__CLIENT__NAP     ],
                [ channel        => $PRL_TYPE__CHANNEL__NAP    ],
                [ designer       => 'Gift Card' ],
                [ description    => 'Gift Card' ],
                [ size           => sub { $_[3]->descriptive_value } ],
                [ color          => sub { $_[2]->colour->colour } ],
                [ 'storage_type' => sub { $_[2]->storage_type->name } ],
                [ weight_lbs     => sub { $_[2]->shipping_attribute->weight || 0 } ],
                [ length_cm      => 0 ],
            ],
        },
        {
            name  => 'Jimmy Choo',
            setup => { how_many => 1, channel => 'jc' },
            expect => [
                [ 'family_group' => $PRL_TYPE__FAMILY__GARMENT ],
                [ client         => $PRL_TYPE__CLIENT__JC      ],
                [ channel        => $PRL_TYPE__CHANNEL__JC     ],
                [ designer       => sub { $_[2]->designer->designer } ],
                [ description    => sub { $_[2]->product_attribute->description } ],
                [ size           => sub { $_[3]->designer_size->size } ],
                [ color          => sub { $_[2]->colour->colour } ],
                [ 'storage_type' => sub {
                    $_[2]->storage_type ? ($_[2]->storage_type->name) || 'Flat' : 'Flat'
                }],
                [ weight_lbs     => sub { $_[2]->shipping_attribute->weight || 0 } ],
                [ length_cm      => sub { $_[3]->get_measurements->{'Length'} || 0 }],
            ],
        },
    ) {
        note "Testing details() for case: " . $type->{'name'};

        # Get a product
        my($channel,$pids) =
            Test::XTracker::Data->grab_products($type->{'setup'});

        next TEST       if ( !$channel->is_enabled );

        my $item    = $pids->[0];
        my $variant = $item->{'variant'};

        # Get its details
        my $details = XT::DC::Messaging::Producer::PRL::SKUUpdate->variant_details(
            $variant
        );

        # Check fiels all match
        for ( @common_checks, @{$type->{'expect'}} ) {
            my ( $key, $value ) = @$_;

            # Jimmy Choo products use external images
            next if ($key eq "image_url" && $channel->business_id eq $BUSINESS__JC);

            $value = $value->( $channel, $item, $item->{'product'}, $variant ) if
                ref( $value ) eq 'CODE';

            is( $details->{$key}, $value, "$key matches: " . $value );
        }
    }

}

sub send_message_to_more_then_one_queue :Tests() {
    my ($test) = @_;

    my $amq = Test::XTracker::MessageQueue->new;

    # Get a product
    my ($channel, $pids) =
        Test::XTracker::Data->grab_products({ how_many => 1, channel => 'nap' });
    my $variant = $pids->[0]->{'variant'};


    # check case when we try to send same message to more then one queue
    $amq->clear_destination();

    lives_ok{
        $amq->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::SKUUpdate' => {
                product_variant => $variant,
                destinations => ['/queue/test.1', '/queue/test.2']
            }
        );
    } 'Send one SKUUpdate message to two destinations';

    $amq->assert_messages({
        destination => '/queue/test.1',
        assert_header => superhashof({
            type => 'sku_update',
        }),
    }, 'First queue got a message');
    $amq->assert_messages({
        destination => '/queue/test.2',
        assert_header => superhashof({
            type => 'sku_update',
        }),
    }, 'Second queue got a message');

    my (@messages) = $amq->messages();

    is_deeply(
        $amq->deserializer->($messages[0]->body),
        $amq->deserializer->($messages[1]->body),
        'Messages from both queues have same content'
    );

    # clean up
    $amq->clear_destination();
}


sub send_message_to_one_queue :Tests() {
    my ($test) = @_;

    my $amq = Test::XTracker::MessageQueue->new;

    # Get a product
    my ($channel, $pids) =
        Test::XTracker::Data->grab_products({ how_many => 1, channel => 'nap' });
    my $variant = $pids->[0]->{'variant'};


    # check case when we try to send same message to more then one queue
    $amq->clear_destination();

    lives_ok{
        $amq->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::SKUUpdate' => {
                product_variant => $variant,
                destinations => '/queue/test.3'
            });
    } 'Send one SKUUpdate message to one destinations';

    $amq->assert_messages({
        destination => '/queue/test.3',
        assert_header => superhashof({
            type => 'sku_update',
        }),
    }, 'Got correct message in default queue' );
    # clean up
    $amq->clear_destination();
}


=head1 SEE ALSO

L<NAP::Test::Class>

L<XT::DC::Messaging::Producer::PRL::SKUUpdate

=cut

1;
