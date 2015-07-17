package Test::XTracker::Schema::Result::Public::Product;
use NAP::policy "tt", qw/test class/;

use Test::XTracker::Data;
use Test::XTracker::Data::Product;
use Test::XTracker::Data::ChannelTransfer;

use XTracker::Constants::FromDB qw( :flow_status );

BEGIN {
    extends 'NAP::Test::Class';

    has 'product_test_data_helper' => (
        is => 'ro',
        lazy => 1,
        default => sub {
            return Test::XTracker::Data::Product->new();
        },
        handles => [ 'create_product' ],
    );
};

use XTracker::Constants::FromDB qw(
    :product_channel_transfer_status
);

sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup;

    # need to use this schema because
    # rollbacks don't work otherwise
    # and I can't figure out why!
    $self->{schema} = Test::XTracker::Data->get_schema;
}

# this is done before every test
sub setup : Test(setup) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;
}

# this is done after every test
sub teardown : Test(teardown) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}

sub test__whm_1886_channel_transfer_for_never_live_product_bug :Tests {
    my ($self) = @_;

    my $schema = $self->schema();

    my $channel_rs = $schema->resultset('Public::Channel')->fulfilment_only(0)->enabled(1);
    my $from_channel = $channel_rs->next();
    my $to_channel = $channel_rs->next();

    SKIP: {
        skip "Tests require a DC with two active, not fulfilment-only channels" unless $from_channel && $to_channel;
        my $from_channel_name = $from_channel->name();
        my $to_channel_name = $to_channel->name();

        # WHM_1886 bug where channel has never gone live
        my ($test_product) = Test::XTracker::Data->create_test_products({
            channel_id      => $from_channel->id(),
            is_live_on_channel => 0,
        });
        note('Created a test product (pid: ' . $test_product->id() . ") that exists on $from_channel_name");

        my $from_product_channel = $test_product->get_product_channel();
        is($from_product_channel->channel()->id(), $from_channel->id(),
           'get_product_channel() returns correct channel when there is no archive and no '
            . 'transfer');

        my $channel_transfer_test = Test::XTracker::Data::ChannelTransfer->new();
        $channel_transfer_test->request_channel_transfer({
            product     => $test_product,
            new_channel => $to_channel,
        });
        note("Simulated a channel request for the product to $to_channel_name");

        is($test_product->get_product_channel()->channel()->id(), $from_channel->id(),
           "get_product_channel() still returns $from_channel_name after channel transfer is "
           .    'initiated');

        $channel_transfer_test->complete_channel_transfer({
            product_channel => $from_product_channel,
        });
        note("Simulated completion of channel transfer to $to_channel_name");

        is($test_product->get_product_channel()->channel()->id(), $to_channel->id(),
           "get_product_channel() now returns $to_channel_name after channel transfer is "
           .    'complete');
    }
}


sub test__is_restricted_to : Tests {
    my ($self) = @_;


    my $product = $self->create_product;
    # Grab one restriction to play around with
    #ad randon ship_restrction

    my $ship_restriction = $self->schema->resultset('Public::ShipRestriction')->create({
        title => 'TEST Restriction',
        code  => 'XRESTX'
    });

    # Add this restriction to product
    ok($product->add_shipping_restrictions( restriction_codes => ['XRESTX'] ),
        'add_shipping_restrictions returns ok');


    # Grab 3 countres from country table
    my $country_uk   = $self->rs('Public::Country')->find( { country => 'United Kingdom' } );
    my @country_objs = $self->rs('Public::Country')->search(
        {
            country => { 'NOT IN' => [ 'Unknown', 'United Kingdom' ] },
        },
        {
            rows => 2
        }
    );

    # add UK Country in ship_restriction_allowed_country table
    $self->schema->resultset('Public::ShipRestrictionAllowedCountry')->create({
        ship_restriction_id => $ship_restriction->id,
        country_id          => $country_uk->id,
    });
    # add a another Country to the Allowed list that won't have any Postcode restrictions
    $self->schema->resultset('Public::ShipRestrictionAllowedCountry')->create({
        ship_restriction_id => $ship_restriction->id,
        country_id          => $country_objs[0]->id
    });

    # Add randon post code for UK Country
    $self->schema->resultset('Public::ShipRestrictionExcludePostcode')->create({
        ship_restriction_id => $ship_restriction->id,
        country_id          => $country_uk->id,
        postcode            => 'AB',
    });

    throws_ok {
        $product->is_excluded_from_location({});
    } qr{No ship_restriction_id passed in to 'XTracker::Schema::Result::Public::Product->is_excluded_from_location},
       'ship_restriction_id not provided';

    my %tests = (
    "Not allowed Country" => {
        setup => {
            ship_restriction_id => $ship_restriction->id,
            country => $country_objs[1]->country,
            postcode => 'td1 1rg',
        },
        expect => {
            return => 1,
        }

    },
    "Allowed Country with NO Postcode Restrictions" => {
        setup => {
            ship_restriction_id => $ship_restriction->id,
            country => $country_objs[0]->country,
        },
        expect => {
            return => 0,
        }

   },
   "Allowed Postcode" =>  {
        setup => {
            ship_restriction_id => $ship_restriction->id,
            country => $country_uk->country,
            postcode => 'UB3 1TH',
        },
        expect => {
            return => 0,
        }
    },
    "Excluded Postcode" =>  {
        setup => {
            ship_restriction_id => $ship_restriction->id,
            country => $country_uk->country,
            postcode => 'AB1 5RF',
        },
        expect => {
            return => 1,
        }

    });

    foreach my $label ( keys %tests ) {
        note " Testing ${label}";

        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        my $got = $product->is_excluded_from_location( $setup );
        cmp_ok( $got, '==', $expect->{return}, "${label} ");


    }
}


sub test__ship_restrictions :Tests {
    my ($self) = @_;

    my $product = $self->create_product();

    my $non_existant_codes = ['SPANGLY'];

    # Try and add a made up ship_restriction
    throws_ok {
        $product->add_shipping_restrictions( restriction_codes => $non_existant_codes );
    } 'NAP::XT::Exception::Shipment::InvalidRestrictionCode',
        'Correct exception thrown for adding non-existant code';

    # Grab two restrictions that we know exist
    my @real_ship_restrictions = $self->schema->resultset('Public::ShipRestriction')->search({},{
        rows => 2,
    });
    my @real_codes = map { $_->code() } @real_ship_restrictions;

    ok($product->add_shipping_restrictions( restriction_codes => \@real_codes ),
        'add_shipping_restrictions returns ok');

    my %set_codes = map { $_->code() => 1 } $product->ship_restrictions();
    my %real_codes = map { $_ => 1 } @real_codes;
    is_deeply(\%set_codes, \%real_codes, 'Correct shipping restrictions have been set');

    ok($product->add_shipping_restrictions( restriction_codes => \@real_codes ),
        'add_shipping_restrictions with already set codes returns ok');

    is($product->ship_restrictions(), 2, 'Still only 2 restrictions set after duplicate add');

    throws_ok {
        $product->remove_shipping_restrictions( restriction_codes => $non_existant_codes );
    } 'NAP::XT::Exception::Shipment::InvalidRestrictionCode',
        'Correct exception thrown for removing non-existant code';

    my $code_to_remove = pop @real_codes;
    ok($product->remove_shipping_restrictions( restriction_codes => [$code_to_remove] ),
        'remove_shipping_restrictions returns ok');

    %set_codes = map { $_->code() => 1 } $product->ship_restrictions();
    %real_codes = map { $_ => 1 } @real_codes;

    is_deeply(\%set_codes, \%real_codes, 'Correct shipping restrictions are set after one is removed');
}

sub test_has_stock : Tests {
    my $self = shift;

    Test::XTracker::Data->ensure_non_iws_locations;

    # get a product which has stock, and one that does not
    my @prods = Test::XTracker::Data->create_test_products({ how_many=>2 });
    Test::XTracker::Data->ensure_stock($prods[0]->id,$_->size_id)
        for $prods[0]->variants;

    ok($prods[0]->has_stock, "product ".$prods[0]->id." has stock");
    ok(! $prods[1]->has_stock, "product ".$prods[1]->id." has no stock");
}

sub test_get_saleable_item_quantity : Tests {
    my $self = shift;

    # Just make sure we have a product
    Test::XTracker::Data->grab_products;

    my $schema = $self->schema;
    # get a product with a few in stock
    my $prod = $schema->resultset('Public::Quantity')->search(
        {
            quantity             => {'>' => 2},
            status_id            => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            'product_variant.id' => {'!=' => undef},   # ignore vouchers
        },
        {
            join     => 'product_variant',
            order_by => {'-desc' => 'product_variant.product_id'}
        },
    )->slice(0,0)->first->variant->product;
    ok($prod, "got a product id " . $prod->id);

    # check the DBIC method and the old (deprecated) Database::Stock method
    use_ok( 'XTracker::Database::Stock', qw(get_saleable_item_quantity) );
    ok(my $saleable  = $prod->get_saleable_item_quantity(), 'get_saleable_item_quantity from DBIC');
    ok(my $saleable2 = get_saleable_item_quantity($schema->storage->dbh ,$prod->id), 'get_saleable_item_quantity from database - deprecated');

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
