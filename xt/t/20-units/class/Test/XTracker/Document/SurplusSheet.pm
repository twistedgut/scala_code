package Test::XTracker::Document::SurplusSheet;

use NAP::policy qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
}

use Test::Fatal;

use XTracker::Constants::FromDB qw/:stock_process_status :stock_process_type/;
use XTracker::Document::SurplusSheet;

use Test::XTracker::Data;

=head1 NAME

Test::XTracker::Document::SurplusSheet

=cut

sub test_basic : Tests {
    my $self = shift;

    my $expected_type = 'document';

    my $stock_process = $self->create_stock_process;
    my $surplus_sheet = XTracker::Document::SurplusSheet->new(
        group_id => $stock_process->group_id
    );

    is( $surplus_sheet->printer_type, $expected_type,
        'surplus sheet uses correct printer type' );

    lives_ok( sub {
        $surplus_sheet->print_at_location(
            $self->location_with_type($expected_type)->name
        );
    }, "didn't die printing surplus sheet" );
}

sub test_many_little_deaths : Tests {
    my $self = shift;

    like(
        exception { XTracker::Document::SurplusSheet->new },
        qr{\QAttribute (group_id) is required},
        'instantiating document without group_id should die'
    );
    like(
        exception { XTracker::Document::SurplusSheet->new(group_id => 'foo') },
        qr{foo},
        'instantiating document with non-integer group_id should die'
    );
    like(
        exception { XTracker::Document::SurplusSheet->new(
            group_id => ($self->schema->resultset('Public::StockProcess')->get_column('group_id')->max//0)+1
        )},
        qr{No stock processes found},
        'instantiating document with inexistent group_id should die'
    );

    my $stock_process = $self->create_stock_process({type_id => $STOCK_PROCESS_TYPE__MAIN});
    like(
        exception { XTracker::Document::SurplusSheet->new(
            group_id => $stock_process->group_id,
        )},
        qr{contains non-surplus stock processes},
        'instantating document with non-surplus stock processes should die'
    );
}

# These two subs are remarkably similar to the ones in the PutawaySheet unit
# test file - someone should really factor them out
sub create_stock_process {
    my ( $self, $args ) = @_;

    my $product = (Test::XTracker::Data->grab_products(
        { force_create => 1, how_many_variants => 1 }
    ))[1][0]{product};

    my $po = $product->stock_orders->related_resultset('purchase_order')->single;
    my $sp = $self->create_stock_process_for_purchase_order($po, $args);
    ok( $sp, 'created stock process ' . $sp->id );
    return $sp;
}

sub create_stock_process_for_purchase_order {
    my ( $self, $purchase_order, $args ) = @_;

    my ($delivery) = Test::XTracker::Data->create_delivery_for_po(
        $purchase_order, 'bag_and_tag'
    );
    ok( $delivery, 'created delivery ' . $delivery->id );

    # We also need to create the appropriate PGIDs
    my $delivery_item = $delivery->delivery_items->single;
    return Test::XTracker::Data->create_stock_process_for_delivery_item(
        $delivery_item, {
            type_id   => $STOCK_PROCESS_TYPE__SURPLUS,
            status_id => $STOCK_PROCESS_STATUS__APPROVED,
            %{$args//{}}
        }
    );
}
