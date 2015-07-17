package Test::XTracker::Document::StockSheet;

use NAP::policy qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
}

use Test::Fatal;

use XTracker::Document::StockSheet;

use Test::XTracker::Data;

=head1 NAME

Test::XTracker::Document::StockSheet

=cut

sub test_basic : Tests {
    my $self = shift;

    my $product = (Test::XTracker::Data->grab_products({
        force_create => 1,
        with_delivery => 1
    }))[1][0]{product};
    my $expected_type = 'document';

    my $delivery = $product->stock_orders
        ->related_resultset('link_delivery__stock_orders')
        ->search_related(delivery => {}, {rows => 1})
        ->single;
    my $stock_sheet
        = XTracker::Document::StockSheet->new(delivery_id => $delivery->id);

    is( $stock_sheet->printer_type, $expected_type,
        'stock sheet uses correct printer type' );

    lives_ok( sub {
        $stock_sheet->print_at_location(
            $self->location_with_type($expected_type)->name
        );
    }, "didn't die printing stock sheet" );
}

sub test_failures : Tests {
    my $self = shift;

    like(
        exception { XTracker::Document::StockSheet->new },
        qr{\QAttribute (delivery_id) is required},
        'instantiating class without delivery_id should die'
    );
    like(
        exception { XTracker::Document::StockSheet->new(delivery_id => 'foo') },
        qr{\Qfoo},
        'instantiating class with non-integer delivery_id should die'
    );
    like(
        exception { XTracker::Document::StockSheet->new(
            delivery_id => ($self->schema->resultset('Public::Delivery')->get_column('id')->max//0)+1
        )},
        qr{\QCouldn't find delivery},
        'instantiating class with inexistent delivery_id should die'
    );
}
