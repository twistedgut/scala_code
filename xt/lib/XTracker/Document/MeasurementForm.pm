package XTracker::Document::MeasurementForm;

use NAP::policy 'class';

use XTracker::Database::Product qw(get_product_data get_variant_list);
use XTracker::Database::StockProcess qw(get_measurements get_suggested_measurements);
use XTracker::Image 'get_images';
use XTracker::XTemplate;

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::MeasurementForm

=head1 SYNOPSIS

    use XTracker::Document::MeasurementForm;

    my $mf = XTracker::Document::MeasurementForm->new(product_id => $product_id);
    $mf->print_at_location($location);

=cut

=head1 ATTRIBUTES

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }

=head2 product_id

=cut

has product_id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

=head2 product

This is derived from product_id.

=cut

has product => (
    is       => 'ro',
    isa      => 'XTracker::Schema::Result::Public::Product',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_product',
);

sub _build_product {
    my $self = shift;
    return $self->schema->resultset('Public::Product')->find($self->product_id)
        || die "Couldn't find product " . $self->product_id;
}

has basename => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => sub { return 'measurementform-' . $_[0]->product_id; },
);

sub BUILD {
    my $self = shift;
    $self->product;
}

sub content {
    my $self = shift;

    my $schema = $self->schema;
    my $dbh = $schema->storage->dbh;

    my $product_id = $self->product_id;
    my $data = {
        product => get_product_data($dbh, { type => "product_id", id => $product_id }),
        images  => get_images({
            product_id => $product_id,
            live       => 0,
            schema     => $schema
        }),
    };

    my $variant = get_variant_list($dbh, { type => "product_id", id => $product_id } );
    my $suggest = get_suggested_measurements( $dbh, $product_id );
    my $measured = get_measurements( $dbh, $product_id );

    foreach my $variant_id (
        grep { $variant->{$_}{variant_type} eq 'Stock' } keys %$variant
    ) {
        foreach my $measure ( @$suggest ) {
            $data->{required}{$measure->{id}}              = $measure->{measurement};
            $data->{variants}{$variant_id}{$measure->{id}} = $measured->{$variant_id}{$measure->{id}}
        }
    }

    $data->{var_data} = $variant;

    my $html = q{};
    XTracker::XTemplate->template->process(
        'print/measurementform.tt', { template_type => 'none', %$data }, \$html
    );
    return $html;
}

with qw{
    XTracker::Document::Role::Filename
    XTracker::Document::Role::PrintAsPDF
    XTracker::Document::Role::TempDir
    XTracker::Role::WithSchema
};
