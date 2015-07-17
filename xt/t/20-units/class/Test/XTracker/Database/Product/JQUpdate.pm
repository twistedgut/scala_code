package Test::XTracker::Database::Product::JQUpdate;
use NAP::policy "tt", 'test', 'class';
BEGIN {
    extends 'NAP::Test::Class';

    use_ok('XTracker::Database::Product::JQUpdate');
};

use Test::MockModule;
use Test::MockObject;
use Test::XTracker::Data;
use Test::XTracker::Data::Product;

sub test__non_existant_products_do_not_die :Tests {
    my ($self) = @_;

    # Create a new product, record the id, and then delete it. So we have a product id
    # we know does not exist
    my $non_existent_product_id = Test::XTracker::Data::Product->new->get_non_existant_product_id();

    my $updater = $self->_create_updater();
    lives_ok {
        $updater->update_product([{
            product_id  => $non_existent_product_id
        }]);
    } 'update_product() lives with non-existant product_id';

}

sub test__ship_restrictions_legacy :Tests {
    my ($self) = @_;

    # Ensure that ship_restriction codes are mapped properly (both supported and legacy)
    my $updater = $self->_create_updater();

    my $restrictions = {
        add => ['FISH', 'CHIPS'],
        remove => ['VINEGAR', 'MUSHY_PEAS']
    };
    my $map_result = $updater->_map_payload({}, {
        restriction => $restrictions,
    });
    is_deeply($map_result->{xt_data}->{restriction}, $restrictions,
        'restrictions have been mapped successfully');

    my $mock_product_attribute = Test::MockModule->new('XTracker::Database::Attributes');
    my $set_shipping_restrictions = {};
    $mock_product_attribute->mock('set_shipping_restriction', sub {
        my ($dbh, $args) = @_;
        $set_shipping_restrictions->{$args->{restriction}} = 1;
    });
    my $removed_shipping_restrictions = {};
    $mock_product_attribute->mock('remove_shipping_restriction', sub {
        my ($dbh, $args) = @_;
        $removed_shipping_restrictions->{$args->{restriction}} = 1;
    });

    my $mock_product = Test::MockObject->new();
    $mock_product->mock('id', sub {return 1 });

    my $operator_id = Test::XTracker::Data->get_application_operator_id();

    $updater->_run_updates($mock_product, $map_result->{xt_data}, $operator_id);

    is_deeply($set_shipping_restrictions, {
        FISH    => 1,
        CHIPS   => 1,
    }, 'Correct restrictions added');

    is_deeply($removed_shipping_restrictions, {
        VINEGAR     => 1,
        MUSHY_PEAS  => 1,
    }, 'Correct restrictions removed');
}

sub test__ship_restrictions_codes :Tests {
    my ($self) = @_;

    # Ensure that ship_restriction codes are mapped properly (both supported and legacy)
    my $updater = $self->_create_updater();

    my $restriction_codes = {
        add => ['FISH', 'CHIPS'],
        remove => ['VINEGAR', 'MUSHY_PEAS']
    };
    my $map_result = $updater->_map_payload([], {
        restriction_code => $restriction_codes,
    });
    is_deeply($map_result->{xt_data}->{restriction_code}, $restriction_codes,
        'restriction codes have been mapped successfully');

    my $mock_product = Test::MockObject->new();
    $mock_product->mock('id', sub {return 1 });

    my $set_shipping_restrictions = {};
    $mock_product->mock('add_shipping_restrictions', sub {
        my ($self, $args) = @_;
        $set_shipping_restrictions->{$_} = 1 for @{$args->{restriction_codes}};
    });
    my $removed_shipping_restrictions = {};
    $mock_product->mock('remove_shipping_restrictions', sub {
        my ($self, $args) = @_;
        $removed_shipping_restrictions->{$_} = 1 for @{$args->{restriction_codes}};
    });

    my $operator_id = Test::XTracker::Data->get_application_operator_id();

    $updater->_run_updates($mock_product, $map_result->{xt_data}, $operator_id);

    is_deeply($set_shipping_restrictions, {
        FISH    => 1,
        CHIPS   => 1,
    }, 'Correct restrictions added');

    is_deeply($removed_shipping_restrictions, {
        VINEGAR     => 1,
        MUSHY_PEAS  => 1,
    }, 'Correct restrictions removed');
}

sub _create_updater {
    my ($self) = @_;
    return XTracker::Database::Product::JQUpdate->new({
        dbh     => $self->dbh(),
        schema  => $self->schema(),
    });
}
