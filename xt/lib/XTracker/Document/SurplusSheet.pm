package XTracker::Document::SurplusSheet;

use NAP::policy 'class';

use File::Spec;

use XTracker::Barcode qw{generate_file generate_png};
use XTracker::Config::Local 'config_var';
use XTracker::Constants::FromDB ':stock_process_type';
use XTracker::Database::Delivery qw( get_delivery_channel get_stock_process_log );
use XTracker::Database::Product 'get_product_data';
use XTracker::Database::StockProcess 'get_stock_process_items';

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::SurplusSheet

=head1 SYNOPSIS

    use XTracker::Document::SurplusSheet;

    my $document = XTracker::Document::SurplusSheet->new(group_id => $group_id);
    $document->print_at_location($location, $copies);

=head1 ATTRIBUTES

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }

=head2 group_id

Required.

=cut

has group_id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

=head2 template_path

=cut

has '+template_path' => ( default => 'print/accept.tt' );

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
    my @deliveries = $self->schema->resultset('Public::StockProcess')
        ->search({group_id => $self->group_id})
        ->related_resultset('delivery_item')
        ->search_related('delivery',{},{distinct => 1})
        ->all;

    # It shouldn't be possible to have two stock processes with the same group
    # id belonging to two different deliveries - HOWEVER, as there are no
    # constraints at db level let's die horribly instead of picking one at
    # random should we have some 'bad' data.
    die sprintf( "Couldn't uniquely determine delivery for group_id %i", $self->group_id )
        if @deliveries > 1;

    return pop @deliveries;
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
    default  => sub { 'accept-' . $_[0]->group_id; },
);

sub BUILD {
    my $self = shift;

    # Check group_id exists
    my $stock_process_rs = $self->schema->resultset('Public::StockProcess')
        ->search({ group_id => $self->group_id });
    die sprintf "No stock processes found for group_id '%i'", $self->group_id
        unless $stock_process_rs->search({}, { rows => 1 })->single;

    # Don't allow non-surplus group ids past this point
    die sprintf( 'group_id %i contains non-surplus stock processes', $self->group_id )
        if $stock_process_rs->search(
            { type_id => { q{!=} => $STOCK_PROCESS_TYPE__SURPLUS } },
            { rows => 1 }
        )->single;

    # Trigger our delivery validation
    $self->delivery;
}

=head1 METHODS

=head2 gather_data() \%template_data

=cut

sub gather_data {
    my $self = shift;

    my $common_barcode_args = {
        font_size => 'small',
        scale     => 3,
        show_text => 1,
        height    => 65,
    };

    # Generate our delivery barcode
    my $delivery_id = $self->delivery->id;
    generate_file(
        File::Spec->catfile($self->directory, "delivery-$delivery_id.png"),
        generate_png($delivery_id, $common_barcode_args)
    );

    # Generate our PGID barcode
    my $group_id = $self->group_id;
    generate_file(
        File::Spec->catfile($self->directory, "sub_delivery-$group_id.png"),
        generate_png(
            $self->iws_rollout_phase ? "p-$group_id" : $group_id,
            $common_barcode_args
        )
    );

    my $schema = $self->schema;
    my $dbh    = $schema->storage->dbh;

    # we need to print booked in dates(main|surplus) in stock sheet (from logs)
    my $created_logs = get_stock_process_log($dbh, $delivery_id);
    return {
        process_group_items => get_stock_process_items( $dbh, 'process_group', $group_id ),
        delivery_id         => $delivery_id,
        group_id            => $group_id,
        print_date          => $schema->db_now->strftime('%d-%B-%Y %H:%M'),
        product             => get_product_data($dbh, {
            type => 'product_id',
            id   => $self->delivery->stock_order->product_id,
        }),
        # Argh... these... aren't... dates...
        main_booked_in_date    => $created_logs->get_main_booked_in_date->first,
        surplus_booked_in_date => $created_logs->get_surplus_booked_in_date->first,
    };
}

with qw{
    XTracker::Document::Role::Filename
    XTracker::Document::Role::PrintAsPDF
    XTracker::Document::Role::TempDir
    XTracker::Role::WithIWSRolloutPhase
    XTracker::Role::WithSchema
};
