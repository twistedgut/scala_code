package Test::XTracker::Stock::Reservation::PreOrderSelectProducts;

use NAP::policy qw/ test /;

use parent 'NAP::Test::Class';

=head1 NAME

Test::XTracker::Stock::Reservation::PreOrderSelectProducts

=head1 DESCRIPTION

Test XTracker::Stock::Reservation::PreOrderSelectProducts

=head1 TESTS

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::Handler;

use XTracker::Stock::Reservation::PreOrderSelectProducts;

use Number::Format qw/ format_number /;

use Test::MockModule;

sub startup : Test(startup) {
    my ($self) = @_;

    $self->SUPER::startup;

    $self->{mock_designer_service} = Test::MockModule->new('XT::Service::Designer');
    $self->{mock_designer_service}->mock(
        get_restricted_countries_by_designer_id => sub {
            note '** In Mocked get_restricted_countries_by_designer_id **';
            # Return an empty country list.
            return [];
        }
    );
}

sub shut_down : Test(shutdown => no_plan) {
    my $self = shift;
    $self->SUPER::shutdown();

    # just make sure the Mock doesn't interfere with other tests
    $self->{mock_designer_service}->unmock_all();
    delete $self->{mock_designer_service};
}

=head2 test_price_rounding

Tests that the discounted prices shown are correctly rounded.

The return values from the pricing module are mocked to return
prices which round differently when summed pre/post formatting.

http://jira.nap/browse/CANDO-8117

=cut

sub test_price_rounding : Tests() {
    my $self = shift;

    my $unit_price = 10.00;
    my $tax_price = 247.00499999;
    my $duty_price = 28.0049999;

    my $preOrderSelectProductsMock = Test::MockModule->new(
        'XTracker::Stock::Reservation::PreOrderSelectProducts',
        no_auto => 1
    );
    $preOrderSelectProductsMock->mock(
        get_product_selling_price => sub {
            return ( $unit_price, $tax_price, $duty_price );
        },
    );

    # For the purposes of this test, make all products pre-orderable
    my $productMock = Test::MockModule->new('XTracker::Schema::Result::Public::Product');
    $productMock->mock( can_be_pre_ordered_in_channel => sub { return 1; } );

    my $pre_order = Test::XTracker::Data::PreOrder->create_incomplete_pre_order();
    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id => $pre_order->id,
            skip_pws_customer_check => 1,
        },
        mock_methods => { process_template => sub { return 1; } }
    });

    my $basket = new_ok('XTracker::Stock::Reservation::PreOrderSelectProducts' => [$mock_handler]);
    $basket->process();

    # Format the prices as we're expecting them
    my $rounded_unit = format_number($unit_price, 2, 1);
    my $rounded_tax = format_number($tax_price, 2, 1);
    my $rounded_duty = format_number($duty_price, 2, 1);

    # Get the first product - doesn't matter which one as we've mocked the price calculation
    my ($key) = keys %{$mock_handler->{data}{products}};
    my $prices = $mock_handler->{data}{products}->{$key}->{price};

    is( $prices->{unit_price}, $rounded_unit, 'unit_price correctly rounded');
    is( $prices->{tax}, $rounded_tax, 'tax correctly rounded');
    is( $prices->{duty}, $rounded_duty, 'duty correctly rounded');
    # Total is the amount after all constituent parts are rounded
    is(
        $prices->{total},
        format_number($rounded_unit + $rounded_tax + $rounded_duty, 2, 1),
        'total correctly rounded'
    );
}
