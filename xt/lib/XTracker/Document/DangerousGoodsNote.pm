package XTracker::Document::DangerousGoodsNote;

use NAP::policy 'class';

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::DangerousGoodsNote

=head1 DESCRIPTION

This class will create a dangerous good note for a shipment. Note that it
doesn't check if a dangerous good note I<needs> to be printed.

=head1 SYNOPSIS

    my $document = XTracker::Document::DangerousGoodsNote->new(
        shipment_id   => $shipment_id,
        operator_name => 'Bobby Tables',
    );
    $document->print_at_location($location, $copies);

=head1 ATTRIBUTES

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }

=head2 shipment

You should initialise this with shipment_id (see L<SYNOPSIS>).

=cut

=head2 basename

Represents the basename of the filename. No extension needed as this will be
used to generate the filename of this document.

=cut

has basename => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => sub { join q{-}, $_[0]->document_type, $_[0]->shipment->id },
);

=head2 document_type

This is the subdirectory in which the document will be placed.

=cut

has document_type => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    default  => 'dgn',
);

=head2 operator_name

=cut

has operator_name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 pretty_name

=cut

has 'pretty_name' => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    default  => 'Dangerous Goods Note',
);

=head2 template_path

=cut

has '+template_path' => (
    default => 'print/dangerous_goods_note.tt',
);

=head1 METHODS

=head2 gather_data() : \%data

This gets the data to pass to the template.

=cut

sub gather_data {
    my $self = shift;

    # this will hold DGN info of all hazmat lq items
    my @hazmat_lq_attributes;
    # this will store total number of boxes with hazmat lq items
    my %hazmat_lq_boxes;

    my $shipment = $self->shipment;
    my ($net_weight, $gross_weight, $cubic_volume);
    foreach my $item ( $shipment->non_cancelled_items->exclude_vouchers->all ) {
        my $product = $item->variant->product;

        # we need to display dangerous goods note for all hazmat lq items
        next unless $product->get_shipping_restrictions_status->{is_hazmat_lq};

        my $shipping_attribute = $product->shipping_attribute;
        $_ += $shipping_attribute->weight for $net_weight, $gross_weight;

        push @hazmat_lq_attributes, $shipping_attribute->dangerous_goods_note;

        # store box information containing hazmat lq items, just once
        next unless $item->shipment_box_id;
        next if $hazmat_lq_boxes{$item->shipment_box_id}++;

        $gross_weight += $item->shipment_box->box->weight;
        $cubic_volume += $item->shipment_box->box->cubic_volume;
    }

    my $order   = $shipment->order;
    my $channel = $order->channel;
    return {
        order => {
            sales_channel => $channel->name,
            order_nr      => $order->order_nr,
        },
        outward_airway_bill => $shipment->outward_airway_bill,
        shipping_address    => $shipment->shipment_address,
        operator_name       => $self->operator_name,
        branded_date        => $channel->business->branded_date( $self->schema->db_now ),
        channel_branding    => $channel->branding,
        total_hazmat_lq_item_net_weight   => $net_weight,
        total_hazmat_lq_item_gross_weight => sprintf( '%0.3f', $gross_weight//0 ),
        hazmat_lq_boxes_cubic_volume      => sprintf( '%0.3f', $cubic_volume//0 ),
        total_hazmat_lq_boxes             => scalar keys %hazmat_lq_boxes,
        hazmat_lq_attributes              => \@hazmat_lq_attributes,
    };
}

with qw{
    XTracker::Document::Role::Filename
    XTracker::Document::Role::PrintAsPDF
    XTracker::Document::Role::StaticDir
    XTracker::Document::Role::ShipmentInput
    XTracker::Role::WithSchema
};
