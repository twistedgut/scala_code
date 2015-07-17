package Test::XTracker::Database::Stock;
use NAP::policy "tt", 'test', 'class';
BEGIN {
    extends 'NAP::Test::Class';
    with 'XTracker::Role::WithSchema';
    with 'Test::XT::Data::Quantity';
};

use Test::XTracker::Data;
use XTracker::Database::Stock;
use XTracker::Constants::FromDB qw(
    :stock_action
    :pws_action
    :flow_status
);
use Test::Exception;

sub test__putaway_via_variant_and_quantity :Tests {
    my ($self) = @_;

    my ($channel, $product_data) = Test::XTracker::Data->grab_products();
    my $location = Test::XTracker::Data->get_main_stock_location();
    my $quantity = $self->data__quantity__insert_quantity({
        channel     => $channel,
        location    => $location,
        variant     => $product_data->[0]->{variant},
        quantity    => 3,
    });

    XTracker::Database::Stock::putaway_via_variant_and_quantity({
        schema          => $self->schema(),
        channel         => $channel,
        variant         => $product_data->[0]->{variant},
        location        => $location,
        notes           => 'Test putaway',
        quantity        => 1,
        stock_action    => $STOCK_ACTION__PUT_AWAY,
        pws_stock_action=> $PWS_ACTION__PUTAWAY,
    });

    $quantity->discard_changes();
    is($quantity->quantity(), 4, 'Quantity in location has increased by 1 after putaway');

    lives_ok { XTracker::Database::Stock::putaway_via_variant_and_quantity({
        schema          => $self->schema(),
        channel         => $channel,
        variant         => $product_data->[0]->{variant},
        location        => $location,
        notes           => 'Test putaway',
        quantity        => 0,
        stock_action    => $STOCK_ACTION__PUT_AWAY,
        pws_stock_action=> $PWS_ACTION__PUTAWAY,
    }); } 'Call to putaway_via_variant_and_quantity() with quantity 0 lives';
}

sub test__get_saleable_item_quantity :Tests {
    my ($self) = @_;
    my $schema = $self->schema;

    Test::XTracker::Data->ensure_non_iws_locations;

    # get a product which has stock, and one that does not
    my @prods = Test::XTracker::Data->create_test_products({
        how_many=>2,
    });
    Test::XTracker::Data->ensure_stock($prods[0]->id,$_->size_id)
        for $prods[0]->variants;

    # Test has_stock method
    ok($prods[0]->has_stock, "product ".$prods[0]->id." has stock");
    ok(! $prods[1]->has_stock, "product ".$prods[1]->id." has no stock");

    # get a product with a few in stock
    my $prod = $schema->resultset('Public::Quantity')->search({quantity             => {'>' => 2},
                                                               status_id            => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                                                               'product_variant.id' => {'!=' => undef},   # ignore vouchers
                                                              },
                                                              { join     => 'product_variant',
                                                                order_by => {'-desc' => 'product_variant.product_id'}
                                                              },
                                                              )->slice(0,0)->first->variant->product;
    ok($prod, "got a product id " . $prod->id);

    # check the DBIC method and the old (deprecated) Database::Stock method
    use XTracker::Database::Stock qw(get_saleable_item_quantity);
    my ($saleable, $saleable2);
    ok($saleable  = $prod->get_saleable_item_quantity(), 'get_saleable_item_quantity from DBIC');
    ok($saleable2 = get_saleable_item_quantity($schema->storage->dbh ,$prod->id), 'get_saleable_item_quantity from database - deprecated');

    # check the shape of what was returned.
    my $stock_total = 0;
    foreach my $chan (keys %$saleable){
        ok($schema->resultset('Public::Channel')->find({name => $chan}), "key '$chan' is a channel");
        foreach my $variant (keys %{$saleable->{$chan}}){
            ok($schema->resultset('Public::Variant')->find($variant), "key '$variant' is a variant id");
            like($saleable->{$chan}->{$variant}, qr/^-?\d+$/, "quantity is a number");
            $stock_total += $saleable->{$chan}->{$variant};
        }
    }
    cmp_ok($stock_total, '>', 0, 'Found at least some stock somewhere');
    is_deeply($saleable, $saleable2, "data returned from both methods is the same");

    # check exceptions from deprecated method
    throws_ok { get_saleable_item_quantity($schema->storage->dbh); } qr{No product_id defined} , 'bad params dies as expected';
    is_deeply( get_saleable_item_quantity($schema->storage->dbh, 999999999), {}, 'Non existent product returns empty hash ref as before');
}
