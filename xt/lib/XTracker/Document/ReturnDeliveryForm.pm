package XTracker::Document::ReturnDeliveryForm;

use NAP::policy 'class';

use File::Spec;

use XTracker::Database::Return;
use XTracker::Database::Shipment;

use XTracker::Database;
use XTracker::XTemplate;

use XTracker::Barcode qw( generate_png generate_file );

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::DeliveryForm - Model return delivery form and prints it

=head1 DESCRIPTION

Given a C<$delivery_id> it takes the return associated to it and generates the
return delivery form.

=head1 SYNOPSIS

    my $document = XTracker::Document::ReturnDeliveryForm->new(delivery_id => $delivery_id);
    $document->print_at_location($location, $copies);

=head1 ATTRIBUTES

=head2 delivery

DB object representing the coresponding delivery for the
current return

=cut

has delivery => (
    is       => 'ro',
    isa      => 'XTracker::Schema::Result::Public::Delivery',
    required => 1,
);

=head2 return

DB object representing the current return. Although the attribute is required,
it will be build at object construction based on the provided delivery id
or delivery object

=cut

has return => (
    is       => 'rw',
    isa      => 'XTracker::Schema::Result::Public::Return',
);

=head2 document_type

Represents the type of the document. In this case it is a static attribute

=cut

has document_type => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => 'returndel',
);

=head2 basename

Represents the basename of the filename. No extension
needed as this will be used to generate the static folder
in which the document will be created

=cut

has basename => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => sub {
        my $self = shift;

        return sprintf( '%s-%s', $self->document_type, $self->delivery->id);
    }
);

=head2 template_path

String representing the path to the template of
the document

=cut

has '+template_path' => (
    default => 'print/return_delivery_sheet.tt',
);

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }


around BUILDARGS => sub {
    my ( $orig, $class, %args ) = @_;

    die 'Please define your object using only one of' .
        'the delivery/delivery_id arguments'
        if ( $args{delivery} && $args{delivery_id} );

    if ( my $delivery_id = delete $args{delivery_id} ) {
        $args{delivery} = XTracker::Database::xtracker_schema
            ->resultset('Public::Delivery')
            ->find($delivery_id)
        or die "Couldn't find delivery with id $delivery_id";
    }

    $class->$orig(%args)
};

sub BUILD {
    my $self = shift;

    my $delivery = $self->delivery;

    if ( $delivery->link_delivery__return ) {
        $self->return($delivery->link_delivery__return->return);
    } else {
        die "No return associated with delivery id: " . $delivery->id;
    }
}

=head1 METHODS

=head2 gather_data

Generates the needed data to build the delivery form sheet

=cut

sub gather_data {
    my $self = shift;

    my $dbh = $self->dbh;

    # Get return info from db
    my $return              = $self->return;

    my $return_item_info    = get_return_item_info($dbh, $return->id);
    my $ship_item_info      = get_shipment_item_info($dbh, $return->shipment_id);

    # Get booked items
    my %delivery_items = map {
        $_->link_delivery_item__return_item->return_item_id => 1
    } $self->delivery->delivery_items;

    my $barcode_args = {
        font_size   => 'small',
        scale       => 3,
        show_text   => 1,
        height      => 65,
    };

    # Create our delivery barcode
    my $barcode_filename = sprintf('delivery-%i.png', $self->delivery->id);
    generate_file(
        File::Spec->catfile($self->directory, $barcode_filename),
        generate_png($self->delivery->id, $barcode_args)
    );

    my %print_data = (
        delivery_id     => $self->delivery->id,
        print_date      => $self->schema->db_now,
        return          => $return,
        delivery_item   => \%delivery_items,
        return_item     => $return_item_info,
        shipment_item   => $ship_item_info,
        bc_filename     => $barcode_filename,
    );

    return \%print_data;
}

with qw{
    XTracker::Document::Role::Filename
    XTracker::Document::Role::PrintAsPDF
    XTracker::Document::Role::StaticDir
    XTracker::Role::WithSchema
};
