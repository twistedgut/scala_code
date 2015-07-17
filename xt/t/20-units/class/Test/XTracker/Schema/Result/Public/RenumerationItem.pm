package Test::XTracker::Schema::Result::Public::RenumerationItem;
use NAP::policy 'test';
use parent 'NAP::Test::Class';

=head1 NAME

Test::XTracker::Schema::Result::Public::RenumerationItem

=head1 DESCRIPTION

Tests the L<XTracker::Schema::Result::Public::RenumerationItem> class.

=cut

use Test::XTracker::Data;
use Test::XT::Data;

=head1 TESTS

=head2 startup

Tests L<XTracker::Schema::Result::Public::RenumerationItem> can be loaded OK and
creates a renumeration record.

=cut

sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    use_ok('XTracker::Schema::Result::Public::RenumerationItem');

    $self->{data} = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::Order',
        ],
    );

    my $order_details       = $self->{data}->dispatched_order;
    $self->{schema}         = $self->{data}->schema;
    $self->{shipment}       = $order_details->{shipment_object};
    $self->{renumeration}   = Test::XTracker::Data->create_renumeration( $self->{shipment} );

}

=head2 setup

Starts a transaction, then creates a renumeration item record with known values.

=cut

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{schema}->txn_begin;

    $self->{renumeration_item} = Test::XTracker::Data->create_renumeration_item(
        $self->{renumeration},
        $self->{shipment}->shipment_items->first->id, {
            unit_price  => 1000,
            tax         => 100,
            duty        => 10,
        }
    );

}

=head2 teardown

Rolls back the transaction.

=cut

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->{schema}->txn_rollback;

}

=head2 test_format_as_refund_line_item

Tests the C<format_as_refund_line_item> method returns a HashRef suitable for
a refund to send to the PSP. It should contain the following keys: sku, name,
amount, vat and tax.

=cut

sub test_format_as_refund_line_item : Tests {
    my $self = shift;

    my $renumeration_item   = $self->{renumeration_item};
    my $variant             = $renumeration_item->shipment_item->variant;

    cmp_deeply( $self->{renumeration_item}->format_as_refund_line_item, {
        sku     => $variant->sku,
        name    => $variant->product->name,
        amount  => 111000,
        vat     => 10000,
        tax     => 1000,
    }, 'All the values are correct and multiplied by 100 as expected' );

}

=head2 test_total_price

Tests the C<total_price> method returns the sum of C<unit_price>, C<tax> and
C<duty>.

=cut

sub test_total_price : Tests {
    my $self = shift;

    my $renumeration_item = $self->{renumeration_item};

    cmp_ok( $renumeration_item->unit_price,     '==', 1000, 'Unit Price is 1,000.00' );
    cmp_ok( $renumeration_item->tax,            '==', 100,  'Tax is 100.00' );
    cmp_ok( $renumeration_item->duty,           '==', 10,   'Duty is 10.00' );
    cmp_ok( $renumeration_item->total_price,    '==', 1110, 'Total Price is 1,110.00' );

}
