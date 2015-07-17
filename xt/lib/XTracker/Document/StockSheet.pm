package XTracker::Document::StockSheet;

use NAP::policy 'class';

use File::Spec;

use XTracker::Barcode qw{generate_png generate_file};
use XTracker::XTemplate;

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::StockSheet


=head1 SYNOPSIS

    use XTracker::Document::StockSheet;

    my $document = XTracker::Document::StockSheet->new(delivery_id => $delivery_id);
    $document->print_at_location($location, $copies);

=head1 ATTRIBUTES

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }

=head2 delivery_id

=cut

has delivery_id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

=head2 delivery

=cut

has delivery => (
    is       => 'ro',
    isa      => 'XTracker::Schema::Result::Public::Delivery',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_delivery',
);

sub _build_delivery {
    my $self = shift;
    return $self->schema->resultset('Public::Delivery')->find($self->delivery_id)
        || die "Couldn't find delivery " . $self->delivery_id;
}

=head2 basename

Represents the basename of the filename. No extension needed as this will be
used to generate the filename of this document

=cut

has basename => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => sub { 'delivery-' . $_[0]->delivery_id; },
);

sub BUILD {
    my $self = shift;
    $self->delivery;
}

=head1 METHODS

=head2 content

Create html content for the putaway sheet.

=cut

sub content {
    my $self = shift;

    # Create our delivery barcode
    generate_file(
        File::Spec->catfile($self->directory, $self->basename . '.png'),
        generate_png($self->delivery_id, {
            font_size => 'small',
            scale     => 3,
            show_text => 1,
            height    => 65,
        })
    );

    my $data = $self->prepare_print_data;
    die "Couldn't build data hashref for stock sheet" unless %$data;

    my $html = q{};
    XTracker::XTemplate->template->process(
        'print/delivery_sheet.tt', { template_type => 'none', %$data }, \$html
    );
    return $html;
}

=head2 prepare_print_data() : \%print_data

Prepare the data to be passed to the template.

=cut

sub prepare_print_data {
    my $self = shift;

    my $delivery = $self->delivery;
    my $stock_order = $delivery->stock_order;
    my $purchase_order = $stock_order->purchase_order;

    my $print_data = {
        delivery_id   => $delivery->id,
        sales_channel => $purchase_order->channel->name,
        print_date    => $delivery->result_source->schema->db_now,
    };

    my $product = $stock_order->product;
    if ( $purchase_order->is_product_po ) {
        my $product_attribute = $product->product_attribute;
        $print_data->{product} = {
            id                   => $product->id,
            designer             => $product->designer->designer,
            style_number         => $product->style_number,
            description          => $product_attribute->description,
            designer_colour      => $product_attribute->designer_colour,
            designer_colour_code => $product_attribute->designer_colour_code,
            size_scheme          => $product_attribute->size_scheme->short_name,
            storage_type         => $product->storage_type
                                  ? $product->storage_type->name
                                  : "No storage type",
        };
        $print_data->{delivery_items} = [map { +{
            size_id => sprintf('%03d', $_->size_id),
            designer_size => $_->designer_size->size,
        } } $delivery->delivery_items
            ->related_resultset('link_delivery_item__stock_order_items')
            ->related_resultset('stock_order_item')
            ->related_resultset('variant')
            ->all
        ];
    }
    else {
        $print_data->{is_voucher} = 1;
        $print_data->{product} = { id => $product->id, };
        $print_data->{delivery_items} = [{ size_id => $product->size_id }];
    }
    return $print_data;
}

with qw{
    XTracker::Document::Role::Filename
    XTracker::Document::Role::PrintAsPDF
    XTracker::Document::Role::TempDir
    XTracker::Role::WithSchema
};
