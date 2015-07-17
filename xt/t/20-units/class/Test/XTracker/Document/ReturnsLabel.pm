package Test::XTracker::Document::ReturnsLabel;

use NAP::policy qw{ class test };

use Test::Fatal;

use Test::XT::Data;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
};

use XTracker::Document::ReturnsLabel;
use XTracker::Printers::Populator;

=head1 NAME

Test::XTracker::Document::ReturnsLabel - Tests for XTracker::Document::ReturnsLabel

=head1 TESTS

=cut

sub startup : Tests(startup) {
    my $self = shift;

    $self->{framework} = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Return',
            'Test::XT::Data::Order',
        ]
    );

    XTracker::Printers::Populator->new->populate_if_updated;
}

=head2 test_basic

For a stock process, it tries to print the returns label

=cut

sub test_basic : Tests {
    my $self = shift;

    my $expected_type = 'small_label';

    my $stock_process = $self->stock_process_for_return_qc();

    my $label
        = XTracker::Document::ReturnsLabel->new( stock_process_id => $stock_process->id );

    is( $label->printer_type, $expected_type,
        'small label uses correct printer type' );

    lives_ok( sub {
        $label->print_at_location($self->location_with_type($expected_type)->name);
    }, "didn't die printing label" );
}

=head2 test_failures

Test if we try and print with a nonexistent
stock process id.

=cut

sub test_failures : Tests {
    my $self = shift;

    like(
        exception { XTracker::Document::ReturnsLabel->new() },
        qr{Attribute \(stock_process\) is required at constructor},
        q{Can't build object without the stock_process attribute}
    );

    like(
        exception {
            XTracker::Document::ReturnsLabel->new(
            stock_process_id => 1+($self->schema->resultset('Public::StockProcess')->get_column('id')->max||0)
        )},
        qr{Couldn't find stock process with id},
        q{Can't build document object for nonexistent stock process id}
    );

    like(
        exception {
            XTracker::Document::ReturnsLabel->new(
            stock_process_id => 1111,
            stock_process    => $self->stock_process_for_return_qc
        )},
        qr{Please define your object using only one .* attributes},
        q{Can't build document object for nonexistent stock process id}
    );
}


sub stock_process_for_return_qc {
    my $self = shift;

    # We need to get a stock process for a return
    my $order_data = $self->{framework}->dispatched_order();
    my $return     = $self->{framework}->booked_in_return({
        shipment_id => $order_data->{'shipment_id'}
    });

    ok( $return, 'We have new return: ' . $return->id );

    return $return->return_items
        ->first
        ->uncancelled_delivery_item
        ->stock_process;
}
