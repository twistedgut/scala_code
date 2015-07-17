package Test::XTracker::Database::Product;

use NAP::policy "tt", 'test';
use FindBin::libs;
use DateTime;

use Test::XTracker::Data;
use Test::XTracker::ParamCheck;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw(
    :flow_status
    :shipment_class
    :variant_type
);

use DateTime;
use Data::Dump  qw( pp );

use Test::Exception;

use base 'Test::Class';

sub startup : Test(startup => 7) {
    my ( $self ) = @_;
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Database::Shipment', qw(
                            get_product_shipping_attributes
                        ) );
    use_ok('XTracker::Database::Product', qw(
                            product_present
                            get_fcp_sku
                            search_product
                            get_product_data
                            get_variant_product_data
                            get_products_info_for_upload
                            set_product_nav_attribute
                        ) );

    can_ok("XTracker::Database::Shipment", qw(
                            get_product_shipping_attributes
                        ) );
    can_ok("XTracker::Database::Product", qw(
                            product_present
                            get_fcp_sku
                            get_product_data
                            get_variant_product_data
                            get_products_info_for_upload
                            set_product_nav_attribute
                        ) );

    $self->{schema} = Test::XTracker::Data->get_schema();
    $self->{dbh}    = $self->{schema}->storage->dbh;
    my ( $product ) = Test::XTracker::Data->create_test_products();
    ok( $product, "I have a test product to use" );
    ok( ref $product eq 'XTracker::Schema::Result::Public::Product', "and it is a DBIC Product");
    $self->{test_product} = $product;
    $self->{unicode_data} = {
        name            => {
            value           => '試驗',
            relationship    => 'product_attribute'
        },
        description     => {
            value           => "تجربة",
            relationship    => 'product_attribute',
        },
        designer        => {
            value           => 'Bénéficiaire',
            relationship    => 'designer'
        },
        designer_colour => {
            value           => '我能吞',
            relationship    => 'product_attribute'
        },
    };
}

# TODO: This sub still doesn't test the 'location' part of the code...
# shouldn't be too bad to write tests for but will need to expand the 'join'
# param to traverse more than one relationship from the product table
sub product_search : Tests {
    ## no critic(ProhibitDeepNests)
    my ( $self ) = @_;
    my $dbh = $self->{dbh};

    # Test croaks
    my $kill_params = { live => 'live' };
    throws_ok(
        sub { search_product( $dbh, $kill_params ) },
        qr{No location defined},
        'croaks when no location defined'
    );
    $kill_params = { %$kill_params, location => 'make_me_up' };
    throws_ok(
        sub { search_product( $dbh, $kill_params ) },
        qr{Unrecognised location},
        'croaks when using unrecognised location'
    );

    my $locations = [qw<
        inventory
        alllocated

        all

        dc1stock

        dc1
        dc2

        transfer

        sample
        sample_room
        sample_room_press
        sample_editorial
        sample_faulty
        sample_gift
        sample_press
        sample_styling
        sample_upload_1
        sample_upload_2

        dead
        rtv_workstation
        rtv_process
    >];

    for my $location ( @$locations ) {

        my $channel = Test::XTracker::Data->get_enabled_channels->next;
        my $product = Test::XTracker::Data->find_or_create_products->[0]{product};

        # Adding some params per test so the returned resultset is smaller -
        # otherwise these test will take a *long* time to run

        # We are using sample values (e.g. classification/designer) by
        # deriving them from the product we created
        my @tests = (
            { product_id => $product->id, },
            { style_ref => $product->style_number, },
            { channel_id => $channel->id,
              live => 'live',
              visible => 'visible',
              stockvendor => 'stock',
              colour_filter => $self->get_any_colour_filter->id, },
            { channel_id => $channel->id,
              live => 'notlive',
              visible => 'notvisible',
              discount => 'discount', },
            { channel_id => $channel->id,
              live => 'notlive',
              stockvendor => 'vendor',
              colour => $product->colour_id, },
            { visible => 'visible',
              classification => $product->classification_id,
              product_type => $product->product_type_id,
              sub_type => $product->sub_type_id,
              season => $product->season_id,
              sub_type => $product->sub_type_id, },
            { live => 'live',
              designer => $product->designer_id, },
            { act => $product->product_attribute->act_id,
              department => $product->product_attribute->product_department_id, },
            { fabric => 'nickel',
              keywords => 'silver',
              discount => 'notdiscount', },
        );
        TEST: for my $test ( @tests ) {
            # Execute the search
            my %params = ( %$test, location => $location );
            my $results = search_product($dbh, \%params );

            my $search_criteria = join q{, }, map {
                "$_->$params{$_}"
            } keys %params;

            # We can't test anything if the search returns no results
            unless ( @$results ) {
                SKIP: {
                    skip "Skipping test - no products found for '$search_criteria'";
                };
                next TEST;
            }
            my $ids = [ map { $_->{id} } @$results ];

            # Test location
            my $loc_templates = $self->location_template->{$location} // [];
            $loc_templates = [ $loc_templates ]
                unless ref $loc_templates eq 'ARRAY';
            for my $loc_template ( @$loc_templates ) {
                next unless my %template = %{$loc_template};

                my $expected = $template{expected};
                my $hash = $self->generate_hash(
                    $ids, $template{join}, $template{column}, $expected );

                for ( keys %$hash ) {
                    $expected = [ $expected ] unless ref $expected eq 'ARRAY';
                    unless ( map {
                        my $val = $_; grep { $val eq $_ } @$expected
                    } @{$hash->{$_}} ) {
                        fail "$_ fails match on location $location for '$search_criteria'";
                        next TEST;
                    }
                }
                pass "$location ok for '$search_criteria'";
            }

            # Test params
            for my $field ( keys %$test ) {
                my $template = $self->template->{$field};
                my $expected = $template->{expected}{$test->{$field}}
                            // $test->{$field};
                # What we are testing for is not accessible in the return
                # value of search_product - we need to execute some DBIC to
                # check we are returning proper results
                if ( $template->{dbic} ) {
                    my $hash = $self->generate_hash(
                        $ids, $template->{dbic}{join}, $template->{dbic}{column}, $expected );

                    # We fail if any of the results returned don't match
                    for ( keys %$hash ) {
                        $expected = [ $expected ] unless ref $expected eq 'ARRAY';
                        unless ( map {
                            my $val = $_; grep { $val eq $_ } @$expected
                        } @{$hash->{$_}} ) {
                            fail "$_ fails match on $field=$params{$field} for '$search_criteria'";
                            next TEST;
                        }
                    }
                    pass "$field=$params{$field} for '$search_criteria'";
                }
                # The value we are comparing is available in the structure
                # that search_product returns
                elsif ( my $got = $template->{hash_key} ) {
                    my $lookup_sub = $template->{lookup_sub};
                    $expected = $self->$lookup_sub( $expected ) if $lookup_sub;
                    for my $item ( @$results ) {
                        if ( $template->{operator} and $template->{operator} eq 'like' ) {
                            if ( $item->{$got} !~ m{$expected} ) {
                                fail "$item->{id} fails match on $field=$params{$field} for '$search_criteria'";
                                next TEST;
                            }
                        }
                        elsif ( $item->{$got} ne $expected ) {
                            fail "$item->{id} fails match on $field=$params{$field} for '$search_criteria'";
                            next TEST;
                        }
                    }
                    pass "$field=$params{$field} for '$search_criteria'";
                }
                # ... we don't know what to do with this
                else {
                    fail "no test for $field";
                }
            }
        }
    }
    return;
}

sub test_get_product_data : Tests {
    my $self = shift;

    my $product = $self->{test_product};

    # Update product with unicode data
    my $unicode = $self->{unicode_data};

    $product->update_or_create_related('designer', {
        designer => $unicode->{designer}->{value},
    } );

    $product->update_or_create_related('product_attribute', {
        description         => $unicode->{description}->{value},
        name                => $unicode->{name}->{value},
        designer_colour     => $unicode->{designer_colour}->{value}
    } );

    my $result = get_product_data( $self->{dbh}, {
        id      => $product->variants->first->id,
        type    => 'variant_id'
    } );

    ok( $result, "I have a result from get_product_data()" );
    is( $result->{id}, $product->id, "Result id matched product id" );

    foreach my $field ( keys %$unicode ) {
        my $relationship = $unicode->{$field}->{relationship};
        ok( utf8::is_utf8($result->{$field}), "$field has UTF-8 flag" );
        is( $result->{$field}, $unicode->{$field}->{value}, "$field has correct value");
        is( $result->{$field}, $product->$relationship->$field, "$field has correct value");
    }
}

sub test_get_variant_product_data : Tests {
    my $self = shift;
    my $variant_id = $self->{test_product}->variants->first->id;

    my $product = $self->{test_product};
    my $unicode = $self->{unicode_data};

    $product->update_or_create_related('designer', {
        designer => $unicode->{designer}->{value},
    } );

    $product->update_or_create_related('product_attribute', {
        name                => $unicode->{name}->{value}
    } );

    my $product_data = get_variant_product_data($self->{dbh}, $variant_id);

    ok( $product_data, "got a result from get_variant_product_data" );
    is( $product_data->{product_id}, $product->id, "and result is correct product" );

    foreach my $field ( qw|designer name| ) {
        my $relationship = $unicode->{$field}->{relationship};
        ok( utf8::is_utf8($product_data->{$field}), "$field has UTF-8 flag" );
        is( $product_data->{$field}, $unicode->{$field}->{value}, "$field has correct value");
        is( $product_data->{$field}, $product->$relationship->$field, "$field has correct value");
    }
}

sub test_get_products_info_for_upload : Tests {
    my $self = shift;

    my $product = $self->{test_product};

    $product->update_or_create_related('product_attribute', {
        name    => $self->{unicode_data}->{name}->{value}
    } );

    my $data = get_products_info_for_upload( $self->{dbh}, [ $product->id ] );

    ok( $data, "get_products_info_for_upload returned data" );

    my ( $returned_id ) = keys %$data;
    is( $data->{$returned_id}->{product_id}, $product->id, "and it is for the right product" );

    ok( utf8::is_utf8($data->{$returned_id}->{name}), "name has UTF-8 flag" );
    is( $data->{$returned_id}->{name}, $self->{unicode_data}->{name}->{value}, "name has right value" );
    is( $data->{$returned_id}->{name}, $product->product_attribute->name, "name is the same in DBI and DBIC" );
}



# Create a hashref with the structure { $pid => [ @vals ] }, allowing us to
# check for incorrect values in the caller
sub generate_hash {
    my ( $self, $ids, $joins, $col, $value ) = @_;

    # Return right away if we have no $ids
    return {} unless @$ids;

    my $join_stmt = $self->generate_join( @$joins );
    my $qualified_col = ($joins->[-1]||'me').".$col";
    my $dbic_value = ref $value eq 'ARRAY' ? { -in => $value } : $value;

    my @products = $self->{schema}->resultset('Public::Product')->search(
        { 'me.id' => { -in => $ids },
          $qualified_col => $dbic_value },
        { join => $join_stmt,
          '+columns' => $qualified_col,
          result_class => 'DBIx::Class::ResultClass::HashRefInflator' }
    )->all;

    my %hash;
    push @{ $hash{ $_->{id} } },
        map {
            $_->{$col}
        } @{ @$joins
           ? ( ref $_->{$joins} eq 'ARRAY' ? $_->{$joins->[-1]} : [ $_->{$joins->[-1]} ] )
           : [ $_ ]
          }
    for @products;
    return \%hash;
}

sub generate_join {
    my ( $self, @accessors ) = @_;
    my $accessor = shift @accessors;
    return $accessor unless @accessors;
    return { $accessor => $self->generate_join( @accessors ) };
}

sub get_colour {
    $_[0]->{schema}->resultset('Public::Colour')->find($_[1])->colour;
}

sub get_department {
    $_[0]->{schema}->resultset('Public::ProductDepartment')->find($_[1])->department;
}

sub get_designer {
    $_[0]->{schema}->resultset('Public::Designer')->find($_[1])->designer;
}

sub get_product_type {
    $_[0]->{schema}->resultset('Public::ProductType')->find($_[1])->product_type;
}

sub get_season {
    $_[0]->{schema}->resultset('Public::Season')->find($_[1])->season;
}

sub get_season_act {
    $_[0]->{schema}->resultset('Public::SeasonAct')->find($_[1])->act;
}

sub get_any_colour_filter {
    $_[0]->{schema}->resultset('Public::ColourFilter')->slice(0,0)->single;
}

sub get_no_payment_settlement_discount_ids {
    $_[0]->{schema}
         ->resultset('Public::PaymentSettlementDiscount')
         ->search({ discount_percentage => { q{!=} => 0 } })
         ->get_column('id')
         ->all;
}

=pod

Return a hash of data for product_search

The data returned by search_product can be tested in two ways - one where we
the resulting hash contains the field we inputted, and one where it doesn't.
Testing the former is relatively straightforward, while the latter requires us
to perform DB calls to check that the pids in the result match the given
criteria.

When we have the value in the hash we need to specify the following data for
each field.

=over

=item hash_key

Needs a better name, but the value for this is what the field is called in the
returned hash.

=item lookup_sub (optional)

This needs to be specified when we have passed an ID to the search params but
the returning hash contains a name.

=item expected (optional)

Maps the input value to the expected returned value (e.g. 'live' means 1).

=back

These fields are not available in the resulting hash, so we need to make DB
calls to find their value.

=over

=item dbic->{column}

The name of the column we're testing.

=item dbic->{join} (optional)

Returns the accessors we need to traverse to get to the relation containing
the column we're checking against. We always start from the product table -
not required if the column is available there.

=back

=cut

sub template {
    return {
        # Params testable from results hash
        act => { hash_key => 'act', lookup_sub => 'get_season_act', },
        colour => { hash_key => 'colour', lookup_sub => 'get_colour', },
        department => {
            hash_key => 'department',
            lookup_sub => 'get_department',
        },
        designer => { hash_key => 'designer', lookup_sub => 'get_designer', },
        live => {
            hash_key => 'live',
            expected => { live => 1, notlive => 0, },
        },
        product_id => { hash_key => 'id' },
        product_type => {
            hash_key => 'product_type',
            lookup_sub => 'get_product_type',
        },
        season => { hash_key => 'season', lookup_sub => 'get_season', },
        style_ref => { hash_key => 'style_number', operator => 'like', },

        # Params that need DBIC to test
        channel_id => {
            dbic => { join => [ 'product_channel' ], column => 'channel_id', },
        },
        classification => { dbic => { column => 'classification_id', }, },
        colour_filter => { dbic => { column => 'colour_filter_id', }, },
        discount => {
            dbic => { column => 'payment_settlement_discount_id', },
            expected => {
                discount => [ $_[0]->get_no_payment_settlement_discount_ids ],
                notdiscount => 0,
            }
        },
        fabric => {
            dbic => {
                join => [ 'shipping_attribute' ],
                column => 'fabric_content',
            },
        },
        keywords => {
            dbic => {
                join => [ 'product_attribute' ],
                column => 'keywords',
            },
        },
        stockvendor => {
            dbic => { join => [ 'variants' ], column => 'type_id', },
            expected => {
                stock => $VARIANT_TYPE__STOCK,
                vendor => $VARIANT_TYPE__SAMPLE,
            },
        },
        sub_type => { dbic => { column => 'sub_type_id', }, },
        visible => {
            dbic => { join => [ 'product_channel' ], column => 'visible', },
            expected => { visible => 1, notvisible => 0, },
        },
    };
}

sub location_template {
    my %status_id_map = (
        dc1stock => [
            $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
            $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
            $FLOW_STATUS__REMOVED_QUARANTINE__STOCK_STATUS,
            $FLOW_STATUS__SAMPLE__STOCK_STATUS,
            $FLOW_STATUS__QUARANTINE__STOCK_STATUS,
        ],
        dc1 => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        dc2 => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        dead => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
        rtv_workstation => $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS,
        rtv_process => $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        sample => [
            $FLOW_STATUS__SAMPLE__STOCK_STATUS,
            $FLOW_STATUS__CREATIVE__STOCK_STATUS,
        ],
    );
    my %location_map = (
        sample_room => 'Sample Room',
        sample_room_press => 'Press Samples',
        sample_editorial => 'Editorial',
        sample_faulty => 'Faulty',
        sample_gift => 'Gift',
        sample_press => 'Press',
        sample_styling => 'Styling',
        sample_upload_1 => 'Upload 1',
        sample_upload_2 => 'Upload 2',
    );
    my %status = (
        map { $_ => {
            join => [ qw<variants quantities> ],
            column => 'status_id',
            expected => $status_id_map{$_},
        } } keys %status_id_map,
    );
    my %location = (
        map { $_ => {
            join => [ qw<variants quantities location> ],
            column => 'location',
            expected => $location_map{$_},
        } } keys %location_map,
    );
    # TODO: Work out a sensible test for the next three keys
    # inventory => {},
    # alllocated => {},
    # all => {},
    return { %status, %location,
        transfer => [
            {
                join => [ qw<variants quantities> ],
                column => 'status_id',
                expected => [
                    $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                    $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
                    $FLOW_STATUS__REMOVED_QUARANTINE__STOCK_STATUS
                ],
            },
            {
                join => [ qw<variants shipment_items shipment> ],
                column => 'shipment_class_id',
                expected => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
            },
        ],
    };
}

sub test_product_funcs : Tests {
    my ( $self ) = @_;

    my $schema = $self->{schema};
    my $dbh = $schema->storage->dbh;

    # get products
    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
        channel       => 'nap',
        phys_vouchers => { value => '100.00' },
        virt_vouchers => { value => '150.00' },
    } );
    # get the relevant products out of the ARRAY
    isa_ok( my $prod_chan = $pids->[0]{product_channel}, 'XTracker::Schema::Result::Public::ProductChannel' );
    isa_ok( my $product = $pids->[0]{product}, 'XTracker::Schema::Result::Public::Product' );
    isa_ok( my $variant = $pids->[0]{variant}, 'XTracker::Schema::Result::Public::Variant' );
    isa_ok( my $pvouch = $pids->[1]{product}, 'XTracker::Schema::Result::Voucher::Product' );
    isa_ok( my $vvouch = $pids->[2]{product}, 'XTracker::Schema::Result::Voucher::Product' );

    my $min_variant = $product->variants->search( {}, { order_by => 'me.id ASC' } )->first;

    subtest "Testing 'get_shipping_attributes'" => sub {
        # list of keys that should be returned
        my @expected_keys   = qw(
            classification
            country_of_origin
            dangerous_goods_note
            fabric_content
            fish_wildlife
            fish_wildlife_source
            hs_code
            packing_note
            product_type
            scientific_term
            sub_type
            weight
        );

        subtest 'Normal product' => sub {
            my $sa = get_product_shipping_attributes( $dbh, $product->id );
            isa_ok( $sa, 'HASH', "Normal Product: returned a HASH REF" );
            ok( exists $sa->{ $_ },
                "Normal Product: 'get_product_shipping_attributes' has key: $_"
            ) for @expected_keys;
            # check all the data is as expected
            is( $sa->{scientific_term}, $product->shipping_attribute->scientific_term, "Normal Product: 'scientific_term' as expected" );
            is( $sa->{packing_note}, $product->shipping_attribute->packing_note, "Normal Product: 'packing_note' as expected" );
            is( $sa->{dangerous_goods_note}, $product->shipping_attribute->dangerous_goods_note, "Normal Product: 'dangerous_goods_note' as expected" );
            is( $sa->{weight}, $product->shipping_attribute->weight, "Normal Product: 'weight' as expected" );
            is( $sa->{fabric_content}, $product->shipping_attribute->fabric_content, "Normal Product: 'fabric_content' as expected" );
            is( $sa->{fish_wildlife}, $product->shipping_attribute->fish_wildlife, "Normal Product: 'fish_wildlife' as expected" );
            is( $sa->{fish_wildlife_source}, $product->shipping_attribute->fish_wildlife_source, "Normal Product: 'fish_wildlife_source' as expected" );
            is( $sa->{country_of_origin}, $product->shipping_attribute->country->country, "Normal Product: 'country' as expected" );
            is( $sa->{hs_code}, $product->hs_code->hs_code, "Normal Product: 'hs_code' as expected" );
            is( $sa->{product_type}, $product->product_type->product_type, "Normal Product: 'product_type' as expected" );
            is( $sa->{sub_type}, $product->sub_type->sub_type, "Normal Product: 'sub_type' as expected" );
            is( $sa->{classification}, $product->classification->classification, "Normal Product: 'classification' as expected" );
        };

        subtest 'Physical voucher' => sub {
            my $sa    = get_product_shipping_attributes( $dbh, $pvouch->id );
            isa_ok( $sa, 'HASH', "Physical Voucher: returned a HASH REF" );
            ok( exists $sa->{ $_ },
                "Physical Voucher: 'get_product_shipping_attributes' has key: $_"
            ) for @expected_keys;
            # check known data for Physical Vouchers to return, don't expect it to return a full set at the moment as of writing the test
            cmp_ok( $sa->{fish_wildlife}, '==', 0, "Physical Voucher: 'fish_wildlife' as expected" );
            cmp_ok( $sa->{weight}, '==', config_var( 'Voucher', 'weight') , "Physical Voucher: 'weight' as expected" );
            is( $sa->{fabric_content}, config_var( 'Voucher', 'fabric_content') , "Physical Voucher: 'fabric_content' as expected" );
            is( $sa->{country_of_origin}, config_var( 'Voucher', 'country_of_origin') , "Physical Voucher: 'country_of_origin' as expected" );
            is( $sa->{hs_code}, config_var( 'Voucher', 'hs_code') , "Physical Voucher: 'hs_code' as expected" );
            is( $sa->{product_type}, 'Document' , "Physical Voucher: 'product_type' as expected" );
        };

        subtest 'Virtual voucher' => sub {
            my $sa    = get_product_shipping_attributes( $dbh, $vvouch->id );
            isa_ok( $sa, 'HASH', "Virtual Voucher: returned a HASH REF" );
            ok( exists $sa->{ $_ },
                "Virtual Voucher: 'get_product_shipping_attributes' has key: $_"
            ) for @expected_keys;
            # check known data for Virtual Vouchers to return, don't expect it to return a full set at the moment as of writing the test
            cmp_ok( $sa->{fish_wildlife}, '==', 0, "Virtual Voucher: 'fish_wildlife' as expected" );
            cmp_ok( $sa->{weight}, '==', 0 , "Virtual Voucher: 'weight' as expected" );
            is( $sa->{fabric_content}, '' , "Virtual Voucher: 'fabric_content' as expected" );
            is( $sa->{country_of_origin}, config_var( 'Voucher', 'country_of_origin') , "Virtual Voucher: 'country_of_origin' as expected" );
            is( $sa->{hs_code}, 'None' , "Virtual Voucher: 'hs_code' as expected" );
            is( $sa->{product_type}, 'Document' , "Virtual Voucher: 'product_type' as expected" );
        };
    };

    # product_present
    subtest "Testing 'product_present'" => sub {
        subtest "Using Normal Product" => sub {

            note "Set Normal Product: live: false, staging: false";
            $prod_chan->update( { live => 0, staging => 0 } );
            ok( defined product_present( $dbh, { channel_id => $channel->id, type => 'product_id', id => $product->id } ),
                                                        "Normal Product: 'product_present' using 'product_id' returns non-null" );
            ok( defined product_present( $dbh, { channel_id => $channel->id, type => 'variant_id', id => $product->variants->first->id } ),
                                                        "Normal Product: 'product_present' using 'variant_id' returns non-null" );

            note "Set Normal Product: live: true, staging: false";
            $prod_chan->update( { live => 1, staging => 0 } );
            cmp_ok( product_present( $dbh, { channel_id => $channel->id,
                                                type => 'product_id', id => $product->id } ), '==', 1,
                                                        "Normal Product: 'product_present' using 'product_id' implicitly asking for 'live' returns TRUE" );
            cmp_ok( product_present( $dbh, { channel_id => $channel->id,
                                                type => 'variant_id', id => $product->variants->first->id } ), '==', 1,
                                                        "Normal Product: 'product_present' using 'variant_id' implicitly asking for 'live' returns TRUE" );
            cmp_ok( product_present( $dbh, { environment => 'live', channel_id => $channel->id,
                                                type => 'product_id', id => $product->id } ), '==', 1,
                                                        "Normal Product: 'product_present' using 'product_id' asking for 'live' returns TRUE" );
            cmp_ok( product_present( $dbh, { environment => 'live', channel_id => $channel->id,
                                                type => 'variant_id', id => $product->variants->first->id } ), '==', 1,
                                                        "Normal Product: 'product_present' using 'variant_id' asking for 'live' returns TRUE" );
            cmp_ok( product_present( $dbh, { environment => 'staging', channel_id => $channel->id,
                                                type => 'product_id', id => $product->id } ), '==', 0,
                                                        "Normal Product: 'product_present' using 'product_id' asking for 'staging' returns FALSE" );
            cmp_ok( product_present( $dbh, { environment => 'staging', channel_id => $channel->id,
                                                type => 'variant_id', id => $product->variants->first->id } ), '==', 0,
                                                        "Normal Product: 'product_present' using 'variant_id' asking for 'staging' returns FALSE" );

            note "Set Normal Product: live: true, staging: true";
            $prod_chan->update( { live => 1, staging => 1 } );
            cmp_ok( product_present( $dbh, { environment => 'staging', channel_id => $channel->id,
                                                type => 'product_id', id => $product->id } ), '==', 1,
                                                        "Normal Product: 'product_present' using 'product_id' asking for 'staging' returns TRUE" );
            cmp_ok( product_present( $dbh, { environment => 'staging', channel_id => $channel->id,
                                                type => 'variant_id', id => $product->variants->first->id } ), '==', 1,
                                                        "Normal Product: 'product_present' using 'variant_id' asking for 'staging' returns TRUE" );

            note "Ask for Normal Product for a non-existent Sales Channel";
            is( product_present( $dbh, { environment => 'live', channel_id => ( $channel->id + 1 ),
                                            type => 'product_id', id => $product->id } ), undef,
                                                        "Normal Product: 'product_present' using 'product_id' asking for 'live' returns UNDEF" );
            is( product_present( $dbh, { environment => 'live', channel_id => ( $channel->id + 1 ),
                                            type => 'variant_id', id => $product->variants->first->id } ), undef,
                                                        "Normal Product: 'product_present' using 'variant_id' asking for 'live' returns UNDEF" );
        };

        subtest "Using Physical Voucher" => sub {

            note "Set Physical Voucher to be non-live";
            $pvouch->update( { upload_date => undef } );
            ok( defined product_present( $dbh, { channel_id => $channel->id, type => 'product_id', id => $pvouch->id } ),
                                                        "Physical Voucher: 'product_present' using 'product_id' returns non-null" );
            ok( defined product_present( $dbh, { channel_id => $channel->id, type => 'variant_id', id => $pvouch->variant->id } ),
                                                        "Physical Voucher: 'product_present' using 'variant_id' returns non-null" );

            note "Set Physical Voucher to be live in the future";
            $pvouch->update( { upload_date => DateTime->now->add( days => 2 ) } );
            cmp_ok( product_present( $dbh, { channel_id => $channel->id,
                                                type => 'product_id', id => $pvouch->id } ), '==', 0,
                                                    "Physical Voucher: 'product_present' using 'product_id' implicitly asking for 'live' returns FALSE" );
            cmp_ok( product_present( $dbh, { channel_id => $channel->id,
                                                type => 'variant_id', id => $pvouch->variant->id } ), '==', 0,
                                                    "Physical Voucher: 'product_present' using 'variant_id' implicitly asking for 'live' returns FALSE" );

            note "Set Physical Voucher to be live in the future";
            $pvouch->update( { upload_date => DateTime->now } );
            cmp_ok( product_present( $dbh, { channel_id => $channel->id,
                                                type => 'product_id', id => $pvouch->id } ), '==', 1,
                                                    "Physical Voucher: 'product_present' using 'product_id' implicitly asking for 'live' returns TRUE" );
            cmp_ok( product_present( $dbh, { channel_id => $channel->id,
                                                type => 'variant_id', id => $pvouch->variant->id } ), '==', 1,
                                                    "Physical Voucher: 'product_present' using 'variant_id' implicitly asking for 'live' returns TRUE" );
            cmp_ok( product_present( $dbh, { environment => 'live', channel_id => $channel->id,
                                                type => 'product_id', id => $pvouch->id } ), '==', 1,
                                                    "Physical Voucher: 'product_present' using 'product_id' asking for 'live' returns TRUE" );
            cmp_ok( product_present( $dbh, { environment => 'live', channel_id => $channel->id,
                                                type => 'variant_id', id => $pvouch->variant->id } ), '==', 1,
                                                    "Physical Voucher: 'product_present' using 'variant_id' asking for 'live' returns TRUE" );
            cmp_ok( product_present( $dbh, { environment => 'staging', channel_id => $channel->id,
                                                type => 'product_id', id => $pvouch->id } ), '==', 0,
                                                    "Physical Voucher: 'product_present' using 'product_id' asking for 'staging' returns FALSE" );
            cmp_ok( product_present( $dbh, { environment => 'staging', channel_id => $channel->id,
                                                type => 'variant_id', id => $pvouch->variant->id } ), '==', 0,
                                                    "Physical Voucher: 'product_present' using 'variant_id' asking for 'staging' returns FALSE" );

            note "Ask for Physical Voucher for a non-existent Sales Channel";
            is( product_present( $dbh, { environment => 'live', channel_id => ( $channel->id + 1 ),
                                            type => 'product_id', id => $pvouch->id } ), undef,
                                                        "Physical Voucher: 'product_present' using 'product_id' asking for 'live' returns UNDEF" );
            is( product_present( $dbh, { environment => 'live', channel_id => ( $channel->id + 1 ),
                                            type => 'variant_id', id => $product->variants->first->id } ), undef,
                                                        "Physical Voucher: 'product_present' using 'variant_id' asking for 'live' returns UNDEF" );
        };
    };

    # get_fcp_sku
    subtest "Testing 'get_fcp_sku'" => sub {
        # using Normal Product
        is( get_fcp_sku( $dbh, { type => 'variant_id', id => $variant->id } ), $variant->sku,
                            "Normal Product: 'get_fcp_sku' using 'variant_id' returns: " . $variant->sku );
        is( get_fcp_sku( $dbh, { type => 'product_id', id => $product->id } ), $min_variant->sku,
                            "Normal Product: 'get_fcp_sku' using 'product_id' returns: " . $min_variant->sku );

        # using Physical Voucher
        is( get_fcp_sku( $dbh, { type => 'variant_id', id => $pvouch->variant->id } ), $pvouch->sku,
                            "Physical Voucher: 'get_fcp_sku' using 'variant_id' returns: " . $pvouch->sku );
        is( get_fcp_sku( $dbh, { type => 'product_id', id => $pvouch->id } ), $pvouch->sku,
                            "Physical Voucher: 'get_fcp_sku' using 'product_id' returns: " . $pvouch->sku );

        # with an invalid request
        dies_ok( sub {
                get_fcp_sku( $dbh, { type => 'product_id', id => -234 } )
            }, "Invalid Request: 'get_fcp_sku' dies" );
        like( $@, qr/Could not find build fcp sku/, "'get_fcp_sku' die message as expected" );
    };
}

Test::Class->runtests;
