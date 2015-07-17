package XTracker::Document::PutawaySheet;

use NAP::policy 'class';

use DateTime;
use File::Spec;

use XTracker::Barcode qw{generate_png generate_file};
use XTracker::Constants::FromDB ':stock_process_status';
use XTracker::Database::Delivery qw/get_delivery_channel get_stock_process_log/;
use XTracker::Database::Product 'get_product_data';
use XTracker::Database::StockProcess 'get_stock_process_items';

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::PutawaySheet - Model putaway sheets and print them.

=head1 DESCRIPTION

Create a document class for a putaway sheet given a C<$group_id>. These documents
are temporary and aren't stored on disk for any longer than it requires for
them to be printed.

=head1 SYNOPSIS

    my $document = XTracker::Document::PutawaySheet->new(group_id => $group_id);
    $document->print_at_location($location, $copies);
    $document->group_id($other_group_id);
    $document->print_at_location($location, $copies);

=head1 ATTRIBUTES

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }

=head2 group_id

=cut

has group_id => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
);

has _type => (
    is       => 'rw',
    isa      => 'Str',
    init_arg => undef,
);

=head2 basename

Represents the basename of the filename. No extension
needed as this will be used to generate the filename of
this document

=cut

has basename => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => sub {
        my $self = shift;

        return sprintf( '%s-%s', lc($self->_type), $self->group_id);
    }
);

has '+template_path' => (
    default => 'print/putaway.tt'
);


sub BUILD {
    my $self = shift;
    my $stock_process = $self->schema->resultset('Public::StockProcess')->search(
        { group_id => $self->group_id },
        { rows => 1 }
    )->single or die sprintf "Couldn't find PGID %i\n", $self->group_id;
    return if $stock_process->is_main
        || $stock_process->is_faulty
        || $stock_process->is_surplus;
    die sprintf
        "Can't print putaway sheets for type '%s' (PGID %i)\n",
        $stock_process->type->type, $self->group_id;
}

=head1 METHODS

=head2 gather_data

=cut

sub gather_data {
    my $self = shift;

    my $schema = $self->schema;
    my $dbh = $schema->storage->dbh;
    my $sku_ref = get_stock_process_items( $dbh, 'process_group', $self->group_id );

    my %data;
    unless($sku_ref->[0]) { # probably a voucher
        my ($stock_process) = $schema->resultset('Public::StockProcess')->search({
            group_id => $self->group_id,
            # type_id *shouldn't* be necessary - all group ids should have the
            # same type, and the pgid we're passing should be able to determine
            # what 'type' the group is anyway
            # type_id => $type_id,
            status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        });

        die sprintf(
            "PGID %i not in correct status to print a putaway sheet\n",
            $self->group_id
        ) unless $stock_process;

        # Otherwise we need to determine the voucher's product id
        my $voucher_variant = $stock_process->delivery_item
            ->related_resultset('link_delivery_item__stock_order_items')
            ->related_resultset('stock_order_item')
            ->related_resultset('voucher_variant')
            ->slice(0,0)
            ->single or die sprintf
                'could not get stock process items for group %s',
                $self->group_id;

        $sku_ref = [{
            product_id    => $voucher_variant->product_id,
            designer_size => $voucher_variant->designer_size_id,
            size_id       => $voucher_variant->size_id,
            delivery_id   => $stock_process->delivery_item->delivery_id,
            type          => $stock_process->type->type,
        }];
        $data{is_voucher} = 1;
    }
    # Infer a couple of group-specific attributes
    my ($product_id, $delivery_id, $type, $stock_process_type_id)
        = @{$sku_ref->[0]}{qw/product_id delivery_id type stock_process_type_id/};
    $self->_type($sku_ref->[0]{type});

    %data = (
        %data,
        process_group_items => $sku_ref,
        delivery_id         => $delivery_id,
        group_id            => $self->group_id,
        product             => get_product_data( $dbh, { type => 'product_id', id => $product_id} ),
        sales_channel       => get_delivery_channel( $dbh, $delivery_id ),
        stock_process_type  => $type,
    );

    $data{print_date} = DateTime->now(time_zone => 'local')->strftime("%d-%m-%Y %R");

    my $barcode_args = {
        font_size => 'small',
        scale => 3,
        show_text => 1,
        height => 65,
    };

    # Create our delivery barcode
    generate_file(
        File::Spec->catfile($self->directory, sprintf('delivery-%i.png', $delivery_id)),
        generate_png($delivery_id, $barcode_args)
    );
    # Create our PGID barcode
    generate_file(
        File::Spec->catfile($self->directory, sprintf('sub_delivery-%s.png', $self->group_id)),
        generate_png(
            ($self->iws_rollout_phase ? q{p-} : q{}) . $self->group_id,
            $barcode_args
        )
    );

    # We need to print booked in date(main) in putaway sheet (from logs)
    $data{main_booked_in_date} = get_stock_process_log($dbh, $delivery_id)
        ->get_main_booked_in_date->first;

    return \%data;
}

with qw{
    XTracker::Document::Role::Filename
    XTracker::Document::Role::PrintAsPDF
    XTracker::Document::Role::TempDir
    XTracker::Role::WithIWSRolloutPhase
    XTracker::Role::WithSchema
};
