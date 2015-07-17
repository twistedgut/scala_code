package Test::XTracker::Document::PutawaySheet;

use NAP::policy qw{class test};

use File::Basename;
use Test::Fatal;
use Test::File;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
};

use Test::XTracker::Data;

use XTracker::Constants::FromDB qw{
    :stock_process_status
    :stock_process_type
};
use XTracker::Document::PutawaySheet;

=head1 NAME

Test::XTracker::Document::PutawaySheet - Tests for XTracker::Document::PutawaySheet

=head1 TESTS

=cut

sub startup : Tests(startup) {
    my $self = shift;

    # We need this line as printers we add to our config get inserted when the
    # blank db script runs. In other words anything new you add won't be
    # present in the blank db until your code is live. This forces it to pick
    # up any printers that have been added. It can be removed once this class
    # is live.
    use XTracker::Printers::Populator;
    XTracker::Printers::Populator->new->populate_if_updated;
}

=head2 test_types

Test passing different types of stock processes for regular products to the
putaway sheet class.

=cut

sub test_types : Tests {
    my $self = shift;

    my $stock_process = $self->create_stock_process;

    my @valid_type_ids = (
        $STOCK_PROCESS_TYPE__MAIN,
        $STOCK_PROCESS_TYPE__FAULTY,
        $STOCK_PROCESS_TYPE__SURPLUS,
    );
    for my $type (
        $self->schema->resultset('Public::StockProcessType')->search({},{order_by => 'id'})
    ) {
        subtest sprintf( 'test type %s', $type->type ) => sub {
            $stock_process->update({type_id => $type->id});
            unless ( grep { $_ == $type->id } @valid_type_ids ) {
                like(
                    exception {
                        XTracker::Document::PutawaySheet->new(group_id => $stock_process->group_id)
                    }, qr{Can't print putaway sheets for type},
                    sprintf q{Can't build putaway sheets for type '%s'}, $type->type
                );
                return;
            }
            $self->putaway_sheet_tests($stock_process);
        }
    };
}

=head2 test_voucher

Test creating putaway sheets for vouchers.

=cut

sub test_voucher : Tests {
    my $self = shift;

    my $stock_process = $self->create_voucher_stock_process;
    $self->putaway_sheet_tests($stock_process);
}

=head2 test_failures

Currently only tests we die when we try and print a nonexistent PGID.

=cut

sub test_failures : Tests {
    my $self = shift;

    like(
        exception {
            XTracker::Document::PutawaySheet->new(
            group_id => 1+($self->schema->resultset('Public::StockProcess')->get_column('group_id')->max||0)
        )},
        qr{Couldn't find PGID},
        q{can't build document object for nonexistent PGID}
    );
}

sub putaway_sheet_tests {
    my ( $self, $stock_process ) = @_;

    # Print our document, test artifacts. We want cleanup => 1 - defaults
    # to 0 in a dev (test) environment. While in most tests we'll want to
    # keep the files to test them, here we want to make sure they get
    # deleted (the behaviour on production)
    my $ps = XTracker::Document::PutawaySheet->new(
        group_id => $stock_process->group_id,
        cleanup => 1,
    );
    $ps->print_at_location($self->get_printer_location);

    my ($basename, $dirs) = fileparse($ps->filename, qr{\.[^.]*});
    my @expected_files = (
        (map { "${basename}.${_}" } qw/html pdf/), # docs
        sprintf('delivery-%i.png', $stock_process->delivery_item->delivery_id),
        sprintf('sub_delivery-%i.png', $stock_process->id)
    );
    for my $file (map { $dirs . $_ } @expected_files) {
        file_exists_ok($file);
        file_not_empty_ok($file);
    }

    # Destroy our document object, test artifacts get cleaned up
    undef $ps;
    # NOTE: Annoyingly this test will fail when run on an NFS share as NFS
    # will create temp files that don't get deleted until the process has
    # completed. Should pass on Jenkins though
    ok(!-d $dirs, 'temp directory and its contents cleaned up on object destruction');
}

sub get_printer_location {
    my $self = shift;
    return $self->location_with_type('document')->name;
}

sub create_stock_process {
    my ( $self ) = @_;

    my $product = (Test::XTracker::Data->grab_products(
        { force_create => 1, how_many_variants => 1 }
    ))[1][0]{product};

    # The printing occurs at QC *after* the status changes have been made, so
    # we want delivery{,items} to be created as if they were ready for bag and
    # tag
    my $po = $product->stock_orders->related_resultset('purchase_order')->single;
    return $self->create_stock_process_for_purchase_order($po);
}

sub create_voucher_stock_process {
    my $self = shift;

    my $voucher = Test::XTracker::Data->create_voucher;
    my $vpo = Test::XTracker::Data->setup_purchase_order($voucher->id);
    return $self->create_stock_process_for_purchase_order($vpo);
}

sub create_stock_process_for_purchase_order {
    my ( $self, $purchase_order ) = @_;

    my ($delivery) = Test::XTracker::Data->create_delivery_for_po(
        $purchase_order, 'bag_and_tag'
    );
    ok( $delivery, 'created delivery ' . $delivery->id );

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
