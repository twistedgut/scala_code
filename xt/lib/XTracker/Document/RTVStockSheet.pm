package XTracker::Document::RTVStockSheet;

use NAP::policy 'class';

use DateTime;
use XTracker::Barcode qw/ generate_png generate_file /;
use XTracker::XTemplate;

use XTracker::Database::Product qw/ get_product_id get_product_data /;
use XTracker::Database::StockProcess qw/
    get_stock_process_items
    get_return_stock_process_items
    get_quarantine_process_items
/;
use XTracker::Database::Delivery 'get_stock_process_log';
use XT::Data::Types qw/ RTVDocumentType /;

use Moose::Util::TypeConstraints;

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::RTVStockSheet - document class for stock sheet printing

=head1 DESCRIPTION

Create a document class for a stock sheet given a group ID. Documents are
stored temporarily

=head1 ATTRIBUTES

=cut

sub build_printer_type { 'document' }

=head2 group_id

=cut

has group_id => (
    is          => 'rw',
    isa         => 'Int',
    required    => 1,
);

=head2 document_type

One of main, dead, or rtv. Determines the template used
to generate the stock sheet

=cut

has document_type => (
    is       => 'ro',
    isa      => 'XT::Data::Types::RTVDocumentType',
    required => 1,
);

=head2 origin

The location from which the stock sheet was generated

=cut

has origin => (
    is       => 'ro',
    isa      => enum([keys %{_origin_text()}]),
    required => 1,
);

=head2 basename

Required to fulfil XTracker::Document::Role::Filename

=cut

has basename => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => sub {
        my ($self) = @_;
        return sprintf('%s-%s', $self->document_type, $self->group_id);
    },
);

=head2 stock_process

A stock process result associated with this document's process group ID

=cut

has stock_process => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::StockProcess',
    init_arg    => undef,
    builder     => '_build_stock_process',
);

sub _build_stock_process {
    my ($self) = @_;
    my $stock_process = $self->schema->resultset('Public::StockProcess')->find(
        { group_id => $self->group_id },
        { rows => 1 },
    ) or die sprintf "Couldn't find PGID %i\n", $self->group_id;

    return $stock_process;
}

=head2 delivery

Delivery record associated with this document's process group ID

=cut

has delivery => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Delivery',
    lazy        => 1,
    init_arg    => undef,
    default     => sub {
        my ($self) = @_;
        return $self->stock_process->delivery_item->delivery;
    },
);

has '+template_path' => (
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return sprintf("print/%s.tt", $self->document_type);
    }
);

=head2 gather_data

Required as part of the XTracker::Document::Role::Filename role

=cut

sub gather_data {
    my ($self) = @_;

    my $dbh = $self->dbh;

    my $delivery_id = $self->delivery->id;

    my $sp_items_ref = $self->_get_items_ref;

    my $product_data_ref  = get_product_data( $dbh, { type => 'product_id', id => $self->stock_process->variant->product_id } );

    my $sp_log = get_stock_process_log($dbh, $self->delivery->id);
    my $main_booked_in_date = $sp_log->get_main_booked_in_date->first;
    my $surplus_booked_in_date = $sp_log->get_surplus_booked_in_date->first;

    my $barcode_args = {
        font_size   => 'small',
        scale       => 3,
        show_text   => 1,
        height      => 65,
    };

    generate_file(
        File::Spec->catfile(
            $self->directory,
            sprintf("delivery-%i.png", $self->delivery->id)
        ),
        generate_png($self->delivery->id, $barcode_args),
    );

    generate_file(
        File::Spec->catfile(
            $self->directory,
            sprintf("sub_delivery-%i.png", $self->group_id)
        ),
        generate_png(($self->iws_rollout_phase ? q{p-} : q{}) . $self->stock_process->group_id, $barcode_args),
    );

    my $print_date = DateTime->now(time_zone => 'local')->strftime("%d-%m-%Y %R");

    my %document_data = (
        delivery_id         => $self->delivery->id,
        print_date          => $print_date,
        group_id            => $self->group_id,
        origin              => $self->_origin_text->{ $self->origin },
        process_group_items => $sp_items_ref,
        product             => $product_data_ref,
        main_booked_in_date => $main_booked_in_date,
        surplus_booked_in_date => $surplus_booked_in_date,
    );

    return \%document_data;
}


sub _get_items_ref {
    my ($self) = @_;

    my $dbh = $self->dbh;
    my $delivery_id = $self->delivery->id;
    my $group_id = $self->group_id;

    my $product_id = get_product_id(
        $dbh,
        { type => 'return_process_group', id => $group_id }
    );

    if($product_id) {
        return get_return_stock_process_items($dbh, 'process_group', $group_id);
    }

    $product_id = get_product_id(
        $dbh,
        { type => 'quarantine_process_group', id => $group_id }
    );

    if($product_id) {
        return get_quarantine_process_items($dbh, 'process_group', $group_id);
    }

    $product_id = get_product_id(
        $dbh,
        { type => 'delivery_id', id => $delivery_id }
    );

    return get_stock_process_items($dbh, 'process_group', $group_id);
}

sub _origin_text {
    return {
        returns         => 'Returns Faulty',
        surplus         => 'Goods In Surplus',
        quarantine      => 'Quarantine',
        rma_request     => 'RMA Request',
        dispatched_rtv  => 'Dispatched RTV',
        rtv_workstation => 'RTV Workstation'
    };
}

with qw/
    XTracker::Document::Role::Filename
    XTracker::Document::Role::PrintAsPDF
    XTracker::Document::Role::TempDir
    XTracker::Role::WithIWSRolloutPhase
    XTracker::Role::WithSchema
/;
