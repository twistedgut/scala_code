#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::MockModule;
use Test::XTracker::RunCondition    export => [ qw( $distribution_centre ) ];

use XTracker::Constants::FromDB qw(
    :country
);

use base 'Test::Class';

sub startup :Test(startup) {
    my ($self) = @_;

    # Mock the get_restricted_countries_by_designer_id method that's used by
    # can_ship_to_address (within XT::Rules), so it never fails because the
    # service is not there.
    $self->{mock_designer_dervice} = Test::MockModule->new('XT::Service::Designer');
    $self->{mock_designer_dervice}->mock(
        get_restricted_countries_by_designer_id => sub {
            note '** In Mocked get_restricted_countries_by_designer_id **';
            # Return an empty country list.
            return [];
        }
    );

    $self->{schema}   = Test::XTracker::Data->get_schema();
    $self->{product}  = $self->{schema}->resultset('Public::Product');
    $self->{channels} = [$self->{schema}->resultset('Public::Channel')->all];
}

# just test that the 'test_can_ship_to_address' method
# works in both the positive and negative context. See test
# t/20-units/class/Test/XTracker/Database/Shipment.pm for detailed
# tests for the actual Restrictions themselves across all DCs.
sub test_can_ship_to_address :Tests() {
    my ($self) = @_;

    my $addresses = {
        uk      => Test::XTracker::Data->create_order_address_in('UK'),
        usa_ca  => Test::XTracker::Data->create_order_address_in('US2'),
        usa_nj  => Test::XTracker::Data->create_order_address_in('US4'),
        eu      => Test::XTracker::Data->create_order_address_in('EU'),
        europe  => Test::XTracker::Data->create_order_address_in('Europe'),
        mexico  => Test::XTracker::Data->create_order_address_in('sample', { country => 'Mexico'})
    };

    foreach my $channel (@{$self->{channels}}) {

        note 'Running tests for '.$channel->business->name;

        my $products = {
            fish_wildlife => Test::XTracker::Data->create_test_products({
                how_many      => 1,
                channel_id    => $channel->id,
                fish_wildlife => 1,
            }),
            cites_restricted => Test::XTracker::Data->create_test_products({
                how_many          => 1,
                channel_id        => $channel->id,
                cites_restricted  => 1
            }),
            made_in_china => Test::XTracker::Data->create_test_products({
                how_many          => 1,
                channel_id        => $channel->id,
                country_of_origin => $COUNTRY__CHINA
            })
        };

        given ( $distribution_centre ) {
            when ('DC1') {
                # Made in China to an EU country
                ok($products->{made_in_china}->can_ship_to_address($addresses->{eu}, $channel), 'Made in China product can be shipped to the EU from DC1');
            }
            when ('DC2') {
                # Made in China to the USA
                ok($products->{made_in_china}->can_ship_to_address($addresses->{usa_ca}, $channel), 'Made in China product can be shipped to the USA-CA from DC2');
                # Made in China to Mexico
                ok(!$products->{made_in_china}->can_ship_to_address($addresses->{mexico}, $channel), 'Made in China product can not be shipped to Mexico from DC2');
                # CITES Restriction, outside the US can't be Shipped
                ok( !$products->{cites_restricted}->can_ship_to_address( $addresses->{mexico}, $channel ), 'CITES Product can not be shipped outside the US from DC2' );
                # CITES Restriction, inside the US can be Shipped
                ok( $products->{cites_restricted}->can_ship_to_address( $addresses->{usa_nj}, $channel ), 'CITES Product can be shipped inside the US from DC2' );
                # F&W Restriction, outside the US can't be Shipped
                ok( !$products->{fish_wildlife}->can_ship_to_address( $addresses->{mexico}, $channel ), 'F&W Product can not be shipped outside the US from DC2' );
                # F&W Restriction, inside the US can be Shipped
                ok( $products->{fish_wildlife}->can_ship_to_address( $addresses->{usa_nj}, $channel ), 'F&W Product can be shipped inside the US from DC2' );
            }
            when ('DC3') {
                # Made in China to the USA
                ok($products->{made_in_china}->can_ship_to_address($addresses->{usa_ca}, $channel), 'Made in China product can be shipped to the USA-CA from DC3');
                # Made in China to Mexico
                ok(!$products->{made_in_china}->can_ship_to_address($addresses->{mexico}, $channel), 'Made in China product can not be shipped to Mexico from DC3');
            }
            default {
                fail( "Nothing has been specified to test for this DC: ${distribution_centre}" );
            }
        }
    }
}

sub test_sizing_payload :Tests() {
    my ($self) = @_;

    my @products = Test::XTracker::Data->create_test_products({
        how_many            => 1,
        # size_scheme_id 50 should be M Jeans RL (inches),
        # which has very broken ordering of size_ids, to test our
        # use of position
        size_scheme_id      => 50,
        how_many_variants   => 15,
    });

    foreach my $product ( @products ) {
        my $payload = $product->sizing_payload;
        my $ss = $product->product_attribute->size_scheme;
        my $sizewise = sub {
            return
                $a->size->size_scheme_variant_size_size_ids->single({
                    size_scheme_id => $ss->id
                })->position
            <=> $b->size->size_scheme_variant_size_size_ids->single({
                    size_scheme_id => $ss->id
                })->position
        };
        cmp_deeply(
            $payload,
            superhashof({
                size_scheme => $product->product_attribute->size_scheme->name,
                size_scheme_short_name => $product->product_attribute->size_scheme->short_name,
                size_scheme_variant_size => [
                    map {
                        {
                            designer_size => $_->designer_size->size,
                            designer_size_id => $_->designer_size_id,
                            measurements => superbagof(
                                superhashof({
                                    measurement_id => ignore,
                                    measurement_name => ignore,
                                    value => ignore,
                                    visible => ignore,
                                })
                            ),
                            position => $_->size->
                                size_scheme_variant_size_designer_size_ids->single({
                                    size_scheme_id => $ss->id,
                                })->position,
                            size => $_->size->size,
                            size_id => $_->size_id,
                            sku => $_->product_id . '-' . sprintf('%03d', $_->size_id),
                            std_size => ignore,
                            variant_id => $_->id,
                        }
                    }
                    # sizes should be returned in order of "position"
                    sort $sizewise $product->variants->all
                ],
            }),
            'Product sizing payload looks correct for product with size scheme ' . $ss->name,
        ) or note p $payload;
    }
}

Test::Class->runtests;
