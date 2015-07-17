package Test::XTracker::Document::RTVStockSheet;

use NAP::policy qw/ class test /;

use Test::XT::Data;
use Test::File;
use Test::Fatal;
use File::Basename;

use XTracker::Constants::FromDB qw{
    :stock_process_status
    :stock_process_type
};

use XTracker::Document::RTVStockSheet;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
};

sub startup : Tests(startup) {
    my $self = shift;

    use XTracker::Printers::Populator;
    XTracker::Printers::Populator->new->populate_if_updated;
}

sub test__document_types :Tests {
    my ($self) = @_;
    my $expected_type = 'document';

    my $stock_process = $self->create_stock_process;

    for my $type (qw/ main dead rtv/) {
        subtest "Generate $type stock sheet" => sub {
            my $stock_sheet = XTracker::Document::RTVStockSheet->new(
                group_id        => $stock_process->group_id,
                document_type   => $type,
                origin          => 'rtv_workstation',
            );

            is($stock_sheet->printer_type, $expected_type,
                "Document uses the correct printer type");

            lives_ok( sub{
                $stock_sheet->print_at_location($self->location_with_type($expected_type)->name);
            }, "Print document works ok");

            my ($basename, $dirs) = fileparse($stock_sheet->filename, qr{\.[^.]*});

            my @expected_files = (
                (map { "${basename}.${_}" } qw/html pdf/),
                sprintf("delivery-%i.png", $stock_sheet->delivery->id),
                sprintf("sub_delivery-%i.png", $stock_sheet->group_id),
            );

            for my $file (map { $dirs . $_ } @expected_files) {
                file_exists_ok($file);
                file_not_empty_ok($file);
            }
        };
    }
}

sub test__exceptions :Tests {
    my ($self) = @_;

    my $stock_process = $self->create_stock_process;

    # Test invalid type
    like(
        exception { XTracker::Document::RTVStockSheet->new(
            group_id        => $stock_process->group_id,
            document_type   => "invalidtype",
            origin          => 'rtv_workstation'
        )},
        qr{Invalid RTV document type},
        "Can't instantiate with an invalid document type"
    );

    my $fake_group_id = ($self->schema->resultset('Public::StockProcess')->get_column('group_id')->max || 0) + 1;

    # Test invalid PGID
    like(
        exception { XTracker::Document::RTVStockSheet->new(
            group_id        => $fake_group_id,
            document_type   => "rtv",
            origin          => 'rtv_workstation'
        )},
        qr\^Couldn't find PGID\,
        "Can't instantiate with an nonexistent process group ID"
    );

    # Test invalid origin
    like(
        exception { XTracker::Document::RTVStockSheet->new(
            group_id        => $stock_process->group_id,
            document_type   => "rtv",
            origin          => 'moon_unit_zappa'
        )},
        qr{Attribute \(origin\) does not pass the type constraint},
        "Can't instantiate with an invalid origin"
    );
}

sub create_stock_process {
    my ($self) = @_;
    my $product = (Test::XTracker::Data->grab_products(
        { force_create => 1, how_many_variants => 1 }
    ))[1][0]{product};

    my $purchase_order = $product->stock_orders->related_resultset('purchase_order')->single;

    my ($delivery) = Test::XTracker::Data->create_delivery_for_po(
        $purchase_order, 'bag_and_tag'
    );

    # We also need to create the appropriate PGIDs
    my $delivery_item = $delivery->delivery_items->single;
    return Test::XTracker::Data->create_stock_process_for_delivery_item(
        $delivery_item, {
            type_id => $STOCK_PROCESS_TYPE__MAIN,
            status_id => (
                ref $purchase_order eq 'XTracker::Schema::Result::Voucher::PurchaseOrder'
              ? $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED
              : $STOCK_PROCESS_STATUS__APPROVED
          ),
        }
    );
}

