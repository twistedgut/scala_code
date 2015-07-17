package Test::XTracker::Database::Attributes;
use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::WithSchema';
};

use Test::Warn                     qw( warnings_exist );
use Test::XTracker::Data;
use XTracker::Database::Attributes qw(
    set_product
    set_shipping_restriction
    remove_shipping_restriction
);

sub test__warn_not_die_when_product_not_found_in_set_product : Tests {
    my $self = shift;

    # use a product_id that is 1 more than the latest product_id
    my $product_id    = 1 + $self->schema->resultset('Public::Product')->get_column('id')->max // 0;
    my $warning_regex = qr/Failed to find product for id \($product_id\)/;

    lives_ok {
        warnings_exist(
            sub { set_product( $self->dbh, $product_id, 'product_type' ) },
            $warning_regex,
            'warns about the product not being found',
        );
    } 'does not die when product is not found';
}

sub test__shipping_restrictions :Tests {
    my ($self) = @_;

    # Create a new product with no restrictions
    my (undef, $product_data) = Test::XTracker::Data->grab_products({
        how_many            => 1,
        force_create        => 1,
        how_many_variants   => 1,
    });
    my $product = $product_data->[0]->{product};
    my $shipping_attribute = $product->shipping_attribute();

    my $schema = $self->schema();
    my $shipping_restriction = $schema->resultset('Public::ShipRestriction')->search({
        code => 'HAZMAT',
    })->first();
    if (!$shipping_restriction) {
        # No hazmat restriction in db, most likely because the blank db still hasn't
        # been updated to include them. For now we'll create a fake one
        # (Once the blank db has been sorted this should throw an error instead)
        $shipping_restriction = $schema->resultset('Public::ShipRestriction')->create({
            title           => 'Hazmat',
            code            => 'HAZMAT',
        });
        note('No real shipping restrictions in DB, so creating a fake one');
    }

    # The old Database::Attribute methods actually use the shipping_restriction titles
    # to identify db row that we want (which is evil, as 'title' is not a unique field,
    # unlike 'code' which is the obvious sensible alternative :/ )
    # Gah! Will add something to the tech-debt backlog
    set_shipping_restriction($self->dbh(), {
        product_id  => $product->id(),
        restriction => $shipping_restriction->title(),
    });

    is_deeply($product->get_shipping_restrictions_codes(), [$shipping_restriction->code()], 'Restriction added successfully');
    $shipping_attribute->discard_changes();
    is($shipping_attribute->is_hazmat(), 1, 'Legacy shipping_attribute has also been updated');

    remove_shipping_restriction($self->dbh(), {
        product_id  => $product->id(),
        restriction => $shipping_restriction->title(),
    });

    is_deeply($product->get_shipping_restrictions_codes(), [], 'Restriction removed successfully');
    $shipping_attribute->discard_changes();
    is($shipping_attribute->is_hazmat(), 0, 'Legacy shipping_attribute has also been updated');
}
