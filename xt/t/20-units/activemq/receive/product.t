#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use base 'Test::Class';

use Test::XTracker::RunCondition export => [qw/$prl_rollout_phase/];

use DateTime;

use Test::XTracker::Hacks::TxnGuardRollback;

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use XTracker::Constants::FromDB qw{ :channel :storage_type};
use XTracker::Constants qw( :application );
use XTracker::Database::Pricing qw(get_markdown);
use XTracker::Config::Local         qw{ config_var };

my $DC = Test::XTracker::Data->whatami();

sub startup : Tests(startup => 2) {
    my $test = shift;
    ($test->{amq},$test->{app}) = Test::XTracker::MessageQueue->new_with_app;
    $test->{schema} = XT::DC::Messaging->model('Schema');
    $test->{txn_guard} = $test->{schema}->storage->txn_scope_guard;

    my $channel_id=$test->{channel_id}=
        Test::XTracker::Data->get_local_channel()->id;

    my $pa_rs=$test->{schema}->resultset('Product::Attribute');
    my $pat_rs=$test->{schema}->resultset('Product::AttributeType');

    $pa_rs->find_or_create({
        name => 'Harem_and_Cargo',
        attribute_type_id => $pat_rs->find_or_create({
            name => 'Sub-Type',
            web_attribute => 'NAV_LEVEL3',
            navigational => 1,
        })->id,
        channel_id => $channel_id,
    });
    $pa_rs->find_or_create({
        name => 'Pants',
        attribute_type_id => $pat_rs->find_or_create({
            name => 'Product Type',
            web_attribute => 'NAV_LEVEL2',
            navigational => 1,
        })->id,
        channel_id => $channel_id,
    });
    $pa_rs->find_or_create({
        name => 'Clothing',
        attribute_type_id => $pat_rs->find_or_create({
            name => 'Classification',
            web_attribute => 'NAV_LEVEL1',
            navigational => 1,
        })->id,
        channel_id => $channel_id,
    });
}

sub rollback : Test(shutdown) {
    my $test = shift;
    $test->{txn_guard}->rollback;
}

sub setup : Test(setup) {
    my $test = shift;
    my ($product_id,$variant_id,$designer_name,$other_channel_id) =
        $test->{schema}->storage->dbh_do(
            sub {
                my ($storage, $dbh) = @_;
                my $p = $dbh->selectall_arrayref(<<'SQL');
SELECT max(id)
FROM product
SQL
                my $v = $dbh->selectall_arrayref(<<'SQL');
SELECT max(id)
FROM variant
SQL
                my $d = $dbh->selectall_arrayref(<<'SQL');
SELECT designer
FROM designer
WHERE designer NOT ILIKE 'unk%'
AND designer NOT ILIKE 'none'
LIMIT 1
SQL
                my $c = $dbh->selectall_arrayref(<<'SQL');
SELECT max(id)
FROM channel
SQL
                return $p->[0][0],
                        $v->[0][0],
                        $d->[0][0],
                        $c->[0][0],
                            ;
            });
    ++$product_id;++$variant_id;++$other_channel_id;
    my $channel_id  = Test::XTracker::Data->get_local_channel()->id;
    my $business_id = Test::XTracker::Data->get_business('JIMMYCHOO')->id;

    $test->{product_id}       = $product_id;
    $test->{business_id}      = $business_id;
    $test->{first_variant_id} = $variant_id;
    $test->{channel_id}       = $channel_id;
    $test->{other_channel_id} = $other_channel_id;

    $test->{product_params} = {
        'act'         => 'Main',
        'business_id' => $business_id,
        'channels' => [
            {
                'channel_id' => $channel_id,
                'country_prices' => [
                    {
                        'country' => 'AO',
                        'currency' => 'GBP',
                        'price' => '34.12'
                    }
                ],
                'default_currency' => 'GBP',
                'default_price' => 145,
                'initial_markdown' => {
                    percentage => '30.00',
                    start_date => '2009-01-01T00:00:00',
                },
                'landed_currency' => 'GBP',
                'original_wholesale' => '123.450',
                'payment_deposit' => '0',
                'payment_settlement_discount' => '0',
                'payment_term' => 'Immediate',
                'product_tags' => [],
                'region_prices' => [
                    {
                        'currency' => 'GBP',
                        'price' => '12.34',
                        'region' => 'Americas'
                    }
                ],
                'runway_look' => '0',
                'sample_colour_correct' => '0',
                'sample_correct' => '0',
                'trade_discount' => '0.25',
                'unit_landed_cost' => '124.988495625',
                'uplift' => '1.50',
                'upload_after' => '2009-02-01T00:00:00',
                'wholesale_currency' => 'GBP',
                'external_image_urls' => ["http://example.com/image1.jpg","http://example.com/image2.jpg","http://example.com/image3.jpg"],
            },
            {
                'channel_id' => $other_channel_id,
                'default_currency' => 'USD',
                'default_price' => 235,
                'landed_currency' => 'USD',
                'original_wholesale' => '999',
                'payment_deposit' => '0',
                'payment_settlement_discount' => '0',
                'payment_term' => 'Immediate',
                'product_tags' => [],
                'runway_look' => '0',
                'sample_colour_correct' => '0',
                'sample_correct' => '0',
                'trade_discount' => '1',
                'unit_landed_cost' => '999',
                'uplift' => '5',
                'wholesale_currency' => 'USD',
                'upload_after' => '2009-03-01T00:00:00',
            }
        ],
        'restrictions' => [
            {
                'title' => 'Fish & Wildlife',
            }
        ],
        'name' => 'Test Product',
        'hs_code' => '620892',
        'scientific_term' => 'Science!',
        'classification' => 'Clothing',
        'colour' => 'Beige',
        'colour_filter' => 'Brown',
        'description' => 'foo',
        'designer' => $designer_name,
        'designer_colour' => 'whatever',
        'designer_colour_code' => 'WHTV',
        'division' => 'Women',
        'operator_id' => $APPLICATION_OPERATOR_ID,
        'product_department' => 'Premium Designer',
        'product_id' => $product_id,
        'product_type' => 'Pants',
        'season' => 'CR07',
        'size_scheme' => 'RTW - France',
        'size_scheme_variant_size' => [
            {
                'designer_size'   => '34',
                'size'            => 'xx small',
                'third_party_sku' => 'JC34'.$variant_id,
                'variant_id'      => $variant_id++,
            },
            {
                'designer_size'   => '36',
                'size'            => 'x small',
                'third_party_sku' => 'JC36'.$variant_id,
                'variant_id'      => $variant_id++,
            },
            {
                'designer_size'   => '38',
                'size'            => 'small',
                'third_party_sku' => 'JC38'.$variant_id,
                'variant_id'      => $variant_id++,
            },
            {
                'designer_size'   => '40',
                'size'            => 'medium',
                'third_party_sku' => 'JC40'.$variant_id,
                'variant_id'      => $variant_id++,
            },
            {
                'designer_size'   => '42',
                'size'            => 'large',
                'third_party_sku' => 'JC42'.$variant_id,
                'variant_id'      => $variant_id++,
            },
            {
                'designer_size'   => '44',
                'size'            => 'x large',
                'third_party_sku' => 'JC44'.$variant_id,
                'variant_id'      => $variant_id++,
            },
            {
                'designer_size'   => '46',
                'size'            => 'xx large',
                'third_party_sku' => 'JC46'.$variant_id,
                'variant_id'      => $variant_id++,
            }
        ],
        'style_notes' => undef,
        'style_number' => 'Style1',
        'storage_type_id' => $PRODUCT_STORAGE_TYPE__FLAT,
        'sub_type' => 'Harem and Cargo',
        'world' => 'Fashion',
    };
}

sub test_create_product : Tests {
    my $test = shift;
    my $schema = $test->{schema};

    my $dest = config_var('Producer::Product::Notify', 'destination');

    $test->{amq}->clear_destination($dest);
    $test->clear_test_sku_update;
    my $res = $test->{amq}->request(
        $test->{app},
        "/queue/$DC/product",
        $test->{product_params},
        { type => 'create_product' },
    );
    ok( $res->is_success, 'Create message processed ok' );
    my $product = $schema->resultset('Public::Product')
                            ->find($test->{product_id});
    isa_ok( $product, 'XTracker::Schema::Result::Public::Product' );

    $test->{amq}->assert_messages({
        destination => $dest,
        assert_body => superhashof({
            product_id => $product->id,
            channel_id => $product->product_channel->first->channel_id
        }),
    });

    my @external_images = $product->external_image_urls->all;

    is(scalar(@external_images),3,"We have 3 external images");
    for my $image_index (1..3){
        is ($external_images[($image_index-1)]->url, "http://example.com/image".$image_index.".jpg", "Image $image_index as expected");
    }

    is( $product->storage_type_id, $PRODUCT_STORAGE_TYPE__FLAT, 'storage_type_id' );
    is( $product->colour->colour, 'Beige', 'colour' );
    is( $product->product_attribute->description, 'foo', 'description');
    # "upload_after" is ignored
    # it should be set in the product_attribute table
    # but I'm not adding a column today
    # - Gianni Cecarelli 2010-06-18
    #is( $product->product_attribute->upload_after->iso80601,
    #    '2009-03-01T00:00:00', 'upload after');
    is( $product->product_attribute->size_scheme->name, 'RTW - France', 'size scheme' );
    is( $product->price_purchase->wholesale_currency->currency, 'GBP', 'wholesale currency' );
    is( 0+$product->price_default->price, 145, 'default price' );
    my $md=get_markdown($schema->storage->dbh,
                        $product->id);
    is( (scalar keys %$md), 1, '1 initial markdown' );
    is( 0+((values %$md)[0]->{percentage}), 30, 'initial markdown value' );

    is( $product->product_channel->count, 1, 'only 1 PC' );
    my $pc = $product->product_channel->first;
    ok( $product->variants->first->third_party_sku, 'Variant has one third_party_sku' );

    ok(!$product->product_attribute->pre_order, 'created product is not a pre-order product');
    $test->test_sku_update($product);
}

sub test_update_product : Tests {
    my $test = shift;
    my $schema = $test->{schema};

    $test->clear_test_sku_update;
    my $res = $test->{amq}->request(
        $test->{app},
        "/queue/$DC/product",
        $test->{product_params},
        { type => 'create_product' },
    );
    ok( $res->is_success, 'Create message processed ok' ) || die $res->content;
    my $product = $schema->resultset('Public::Product')
                            ->find($test->{product_id});
    isa_ok( $product, 'XTracker::Schema::Result::Public::Product' );
    note "Testing 1 for product ".$test->{product_id};
    $test->test_sku_update($product);

    $product->product_attribute->update({
        editors_comments => "If I wasn't an editor, I'd rather be... a lumberjack!",
        long_description => 'Long is an adjective used to describe an object or process with a large extent in space or time',
        keywords => 'key words',
        size_fit => 'the size fits',
    });

    $product->shipping_attribute->update({
            weight => 666,
            country_id => 3,
            fabric_content => '110% peruvian squirrel ear lobe',
            packing_note => 'I hate packing these things',
            dangerous_goods_note => 'UN1263, Paint (lacquer), Class 3, PG II, (35◦C)',
    });

    $test->{product_params}{channels}[0]{country_prices}[0]{price}='10.15';
    $test->{product_params}{channels}[0]{initial_markdown}{percentage}='25.00';

    $test->clear_test_sku_update;
    $res = $test->{amq}->request(
        $test->{app},
        "/queue/$DC/product",
        $test->{product_params},
        { type => 'create_product' },
    );
    ok( $res->is_success, 'Update message processed ok' );
    $product->discard_changes();
    note "Testing 2 for product ".$test->{product_id};
    $test->test_sku_update($product);

    my $md=get_markdown($schema->storage->dbh,
                        $product->id);
    is( (scalar keys %$md), 1, '1 initial markdown' );
    is( 0+((values %$md)[0]->{percentage}), 25, 'initial markdown value' );

    is( $product->product_channel->count, 1, 'only 1 PC' );
    my $pc = $product->product_channel->first;

    is( $product->price_country->count, 1, 'only 1 country price');
    my $price=$product->price_country->first;
    is( $price->price, '10.15', 'new price correct');

    is(
        $product->product_attribute->editors_comments,
        "If I wasn't an editor, I'd rather be... a lumberjack!",
        "editors comments not destroyed by update"
    );
    is(
        $product->product_attribute->long_description,
        "Long is an adjective used to describe an object or process with a large extent in space or time",
        "long_description was not overwritten by update"
    );
    is(
        $product->product_attribute->keywords,
        "key words",
        "keywords not overwritten by update",
    );
    is(
        $product->product_attribute->size_fit,
        "the size fits",
        "size_fit not overwritten by update",
    );
    is(
        $product->shipping_attribute->weight,
        '666.000',
        "weight not destroyed by update",
    );
    is(
        $product->shipping_attribute->fabric_content,
        "110% peruvian squirrel ear lobe",
        "fabric content not overwritten by update",
    );
    is(
        $product->shipping_attribute->packing_note,
        "I hate packing these things",
        "packing_note not overwritten by update",
    );
    is(
        $product->shipping_attribute->dangerous_goods_note,
        "UN1263, Paint (lacquer), Class 3, PG II, (35◦C)",
        "dangerous_goods_note not overwritten by update",
    );
    is(
        $product->shipping_attribute->country_id,
        3,
        "country_id not overwritten by update",
    );

    ok(!$product->product_attribute->pre_order, 'updated product is not a pre-order product');
}

sub test_preorder_flag : Tests(9) {
    my $test = shift;
    my $schema = $test->{schema};

    foreach my $chan (@{ $test->{product_params}->{channels} }) {
        push @{$chan->{product_tags}}, 'preorder';
    }

    $test->clear_test_sku_update;
    my $res = $test->{amq}->request(
        $test->{app},
        "/queue/$DC/product",
        $test->{product_params},
        { type => 'create_product' },
    );
    ok( $res->is_success, 'Create message processed ok' ) || die $res->content;
    my $product = $schema->resultset('Public::Product')
        ->find($test->{product_id});
    isa_ok( $product, 'XTracker::Schema::Result::Public::Product');
    ok($product->product_attribute->pre_order, 'created a pre-order product');
    $test->test_sku_update($product);

    foreach my $chan (@{ $test->{product_params}->{channels} }) {
        my $removed = pop @{$chan->{product_tags}};
        is( $removed, 'preorder', 'removed preorder tag' );
    }

    $test->clear_test_sku_update;
    $res = $test->{amq}->request(
        $test->{app},
        "/queue/$DC/product",
        $test->{product_params},
        { type => 'create_product' },
    );
    ok( $res->is_success, 'Update message processed ok' );
    $product->product_attribute->discard_changes;
    ok(!$product->product_attribute->pre_order, 'the update removed pre-order from product');
    $test->test_sku_update($product);

    foreach my $chan (@{ $test->{product_params}->{channels} }) {
        push @{$chan->{product_tags}}, 'preorder';
    }
    $test->clear_test_sku_update;
    $res = $test->{amq}->request(
        $test->{app},
        "/queue/$DC/product",
        $test->{product_params},
        { type => 'create_product' },
    );
    ok( $res->is_success, 'Update message processed ok' );
    $product->product_attribute->discard_changes;
    ok($product->product_attribute->pre_order, 'the update added pre-order to product');
    $test->test_sku_update($product);
}

sub clear_test_sku_update {
    my ($test) = @_;

    if ($prl_rollout_phase) {
        my @prls = XT::Domain::PRLs::get_all_prls;
        foreach my $prl (@prls) {
            $test->{amq}->clear_destination($prl->amq_queue);
        }
    }
}

sub test_sku_update {
    my ($test,$product) = @_;

    # If PRLs are turned on, we should've sent one message for each related SKU
    # to each PRL
    if ($prl_rollout_phase) {
        my @prls = XT::Domain::PRLs::get_all_prls;
        foreach my $prl (@prls) {
            foreach my $variant ($product->variants->all) {
                $test->{amq}->assert_messages({
                    destination => $prl->amq_queue,
                    filter_header => superhashof({
                        type => 'sku_update',
                    }),
                    filter_body => superhashof({
                        '@type' => 'sku_update',
                        'sku' => $variant->sku,
                    }),
                },"message found for PRL " . $prl->name ." SKU ".$variant->sku);
            }
        }
    }
}

Test::Class->runtests;
