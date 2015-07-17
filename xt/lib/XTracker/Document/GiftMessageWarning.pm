package XTracker::Document::GiftMessageWarning;

use NAP::policy 'class';

extends 'XTracker::Document';

use File::Spec;

use XT::Data::Types qw/ShipmentRow ShipmentItemRow/;
use XTracker::Barcode qw/generate_png generate_file/;
use XTracker::XTemplate;

=head1 NAME

XTracker::Document::GiftMessageWarning

=head1 DESCRIPTION

This class models a I<Gift Message Warning> document. Note that there are two
ways to instantiate this class, as gift messages exist both for shipments and
shipment items. A gift message on a shipment item indicates can only exist if
the item is a voucher.

=head1 SYNOPSIS

    my $gmw = XTracker::Document::GiftMessageWarning->new(
        shipment_id   => $shipment_id,
    );
    $gmw->print_at_location($location, $copies);

    OR

    my $gmw = XTracker::Document::GiftMessageWarning->new(
        shipment_item_id   => $shipment_item_id,
    );
    $gmw->print_at_location($location, $copies);

=head1 ATTRIBUTES

=head2 shipment

Initiate this arg at object creation with C<shipment_id>. This and
L<shipment_item> are mutually exclusive.

=cut

has shipment => (
    is        => 'ro',
    isa       => ShipmentRow,
    init_arg  => 'shipment_id',
    predicate => 'has_shipment',
    coerce    => 1,
);

=head2 shipment_item

Initiate this arg at object creation with C<shipment_item_id>. This and
L<shipment> are mutually exclusive.

=cut

has shipment_item => (
    is       => 'ro',
    isa      => ShipmentItemRow,
    init_arg => 'shipment_item_id',
    coerce   => 1,
);

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }

=head2 basename

Represents the basename of the filename. No extension needed as this will be
used to generate the filename of this document.

=cut

has basename => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => sub {
        my $self = shift;
        join q{-}, 'giftmessagewarning',
            $self->shipment ? $self->shipment->id : $self->shipment_item->id
    },
);

=head2 barcode_name

=cut

has barcode_name => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_barcode_name',
);

sub _build_barcode_name {
    my $self = shift;
    File::Spec->catfile(
        $self->directory,
        sprintf( 'giftmessagewarning%s.png', $self->order->order_nr )
    );
}

=head2 order

=cut

has order => (
    is       => 'ro',
    isa      => 'XTracker::Schema::Result::Public::Orders',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_order',
);

sub _build_order {
    my $self = shift;
    my $shipment = $self->shipment // $self->shipment_item->shipment;
    return $shipment->order;
}

=head2 template_path

=cut

has '+template_path' => (
    default => 'print/giftmessagewarning.tt',
);


=head2 gift_message

=cut

has gift_message => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_gift_message',
);

sub _build_gift_message {
    my $self = shift;
    my $object = $self->shipment // $self->shipment_item;
    return $object->gift_message;
}

around BUILDARGS => sub {
    my ( $orig, $class, %args ) = @_;

    confess 'One of shipment_id or shipment_item_id must be provided'
        if !(exists $args{shipment_id} xor exists $args{shipment_item_id});

    return $class->$orig(%args);
};

=head1 METHODS

=head2 gather_data

Create data for the gift message warning.

=cut

sub gather_data {
    my $self = shift;

    my $order_nr = $self->order->order_nr;
    generate_file(
        $self->barcode_name,
        generate_png($order_nr, { scale => 3, show_text => 1, })
    );

    return {
        gift_message  => $self->gift_message,
        order_nr      => $order_nr,
    }
}

with qw{
    XTracker::Document::Role::Filename
    XTracker::Document::Role::PrintAsPDF
    XTracker::Document::Role::TempDir
};
