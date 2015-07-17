package XTracker::Document::ReturnProforma;

use NAP::policy 'class';

use XTracker::Barcode qw( generate_png generate_file );

use XTracker::Config::Local qw(
    comp_addr
    comp_contact_hours
    comp_fax
    comp_freephone
    comp_tel
    config_var
    customercare_email
    return_addr
    return_export_reason_prefix
    return_postcode
    returns_email
);

use XTracker::Constants::FromDB qw(
    :renumeration_class
    :shipment_item_status
);

use XTracker::Database;
use XTracker::Database::Currency qw( get_currency_glyph_map );
use XTracker::Utilities qw( number_in_list );

use Math::Round;

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::ReturnProforma - Model returns proforma document and prints it

=head1 DESCRIPTION

Given a C<$shipment_id> it takes the shipment associated to it and generates the
 returns proforma document. Also number of copies can be specified

=head1 SYNOPSIS

    my $document = XTracker::Document::ReturnProforma->new(shipment_id => $shipment_id);
    $document->print_at_location($location, $copies);

=head1 ATTRIBUTES

=head2 document_type

Basicly, this will represent the suffix of the filename that will be generated

=cut


has document_type => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => 'retpro',
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

        return sprintf( '%s-%s', $self->document_type, $self->shipment->id);
    }
);

=head2 pretty_name

=cut

has 'pretty_name' => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    default  => 'Return Proforma',
);

=head2 template_path

String representing the path to the template of
the document

=cut

has '+template_path' => (
    default => 'print/returnproforma.tt',
);

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }

=head1 METHODS

=head2 gather_data($self:) : $hashref

Gathers all the data needed, in a hashref, to build the returns proforma.

TODO: needs to be refactored

=cut

sub gather_data {
    my $self = shift;

    my $shipment = $self->shipment;
    my $order    = $shipment->order;
    my $channel  = $order->channel;

    my $config_section = $channel->business->config_section;
    my $data = {
        returns_email           => returns_email( $config_section ),
        customercare_email      => customercare_email( $config_section ),
        tt_comp_addr            => comp_addr( $config_section ),
        tt_comp_tel             => comp_tel( $config_section ),
        tt_comp_freephone       => comp_freephone( $config_section ),
        tt_comp_contact_hours   => comp_contact_hours( $config_section ),
        tt_comp_fax             => comp_fax( $config_section ),
        tt_return_addr          => return_addr( $config_section ),
        tt_return_postcode      => return_postcode( $config_section ),
        tt_dc                   => config_var('DistributionCentre','name'),
        tt_export_reason_prefix => return_export_reason_prefix(),
    };

    my $spl_rs = $self->schema->resultset('Public::ShipmentPrintLog');

    # Get the date from the ShipmentPrintLog if it exists - else set it to now
    # this is possible to return multiple rows
    my $spl = $spl_rs->search({
            shipment_id => $shipment->id,
            document    => 'Return Proforma',
        })
        ->first;

    $data->{date}         = $spl ? $spl->date : $self->schema->db_now;
    $data->{branded_date} = $channel->business->branded_date( $data->{date} );

    # Get the local DC's Currency Code and the Order's Currency
    my $dc_currency_code    = config_var('Currency', 'local_currency_code');
    my $order_currency_code = $order->currency->currency;

    # Get Currency Symbols and the currencies used for this Shipment
    $data->{tt_curr_glyph_map}  = get_currency_glyph_map( $self->schema->storage->dbh );
    $data->{tt_currency}        = {
        order   => $order_currency_code,
        dc      => $dc_currency_code,
    };

    # get the conversion rate between the Shipment or Order's currency and the local DC's
    my $dc_conv_rate = $shipment->get_conversion_rate_to( $dc_currency_code );

    my @shipment_items      = $shipment->non_cancelled_items->all;
    SHIPMENT_ITEM:
    foreach my $item ( @shipment_items ) {
        # For all DCs no items that have item_returnable_state set to CC_ONLY
        # or NO should be shown on the Returns Proforma
        next SHIPMENT_ITEM  unless ( $item->display_on_returns_proforma );

        # Item is not:
        # pending cancellation, cancelled, lost, undelivered
        if (number_in_list($item->shipment_item_status,
                           $SHIPMENT_ITEM_STATUS__NEW,
                           $SHIPMENT_ITEM_STATUS__SELECTED,
                           $SHIPMENT_ITEM_STATUS__PICKED,
                           $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                           $SHIPMENT_ITEM_STATUS__PACKED,
                           $SHIPMENT_ITEM_STATUS__DISPATCHED,
                           $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                           $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                           $SHIPMENT_ITEM_STATUS__RETURNED,
                       )) {
            next SHIPMENT_ITEM
        }

        # all items must have a unit price - if its 0 then change to 1
        # (affects promotional gifts only)
        my $unit_price = $item->unit_price || 1;

        my $variant            = $item->get_true_variant;
        my $product            = $variant->product;
        my $shipping_attribute = $product->shipping_attribute;

        # Variant already exists in shipment
        if ( exists $data->{shipment_item}{$variant->id} ) {
            $data->{shipment_item}{$variant->id}{quantity}++;

            $data->{shipment_item}{$variant->id}{ord_total_price}
                += $data->{shipment_item}{$variant->id}{ord_unit_price};
            $data->{shipment_item}{$variant->id}{dc_total_price}
                += $data->{shipment_item}{$variant->id}{dc_unit_price};
        }
        else {
            my $dc_unit_price = nearest( .01, $unit_price * $dc_conv_rate );
            my $si = {
                # Price data
                quantity        => 1,
                ord_unit_price  => $unit_price,
                ord_total_price => $unit_price,
                ord_tax         => $item->tax,
                dc_unit_price   => $dc_unit_price,
                dc_total_price  => $dc_unit_price,
                dc_tax          => nearest( .01, $item->tax  * $dc_conv_rate ),
                # Product data
                designer        => $product->designer->designer,
                name            => $product->attribute->name,
                hs_code         => $product->hs_code->hs_code,
                # Shipping attribute data
                fabric_content  => $shipping_attribute->fabric_content,
                weight          => $shipping_attribute->weight,
                # Variant data
                sku             => $variant->sku,
            };
            $si->{country_of_origin} = $shipping_attribute->country
                ? $shipping_attribute->country->country
                : $shipping_attribute->legacy_countryoforigin;

            $si->{fabric_content} .= '<br />'.$shipping_attribute->scientific_term
                if $shipping_attribute->scientific_term;

            # Add to template data hash
            $data->{shipment_item}{$variant->id} = $si;
        }
    }

    my $s_ref = {
        id           => $shipment->id,
        total_weight => 0,
        # Update total values for shipment
        total_weight        => $shipment->total_weight,
        ord_total_tax       => $shipment->total_tax,
        ord_total_price     => $shipment->total_price(),
        dc_total_tax        => $shipment->total_tax( $dc_currency_code ),
        dc_total_price      => $shipment->total_price( $dc_currency_code ),
        # Calculate shipping
        ord_shipping        => $shipment->calculate_shipping,
        dc_shipping         => $shipment->calculate_shipping( $dc_currency_code ),
        telephone           => $shipment->telephone,
        mobile_telephone    => $shipment->mobile_telephone,
        date                => $shipment->date,
        branded_date        => $channel->business->branded_date( $shipment->date ),
        outward_airway_bill => $shipment->outward_airway_bill,
        return_airway_bill  => $shipment->return_airway_bill,
        gift                => $shipment->gift,
    };

    # Only populate invoice if shipment is an order
    my $remuneration = $shipment->renumerations->find({
        renumeration_class_id => $RENUMERATION_CLASS__ORDER
    });
    $s_ref->{invoice_nr} = $remuneration->invoice_nr if $remuneration;

    # Populate hashref for template with DBIC object values
    $data = {
        %$data,
        shipment => $s_ref,
        order    => {
            sales_channel => $order->channel->name,
            order_nr      => $order->order_nr,
        },
        shipping_address  => $shipment->shipment_address,
        # Get the Sales Channel Branding
        channel_branding  => $order->channel->branding,
    };

    # Create our arcode
    my $barcode_args = {
        font_size => 'small',
        scale     => 1,
        show_text => 0,
        height    => 40,
    };

    generate_file(
        File::Spec->catfile( $self->directory, sprintf('proOrder%s.png', $shipment->id) ),
        generate_png( $shipment->id, $barcode_args)
    );

    return $data;
}

with qw{
    XTracker::Document::Role::Filename
    XTracker::Document::Role::PrintAsPDF
    XTracker::Document::Role::StaticDir
    XTracker::Document::Role::ShipmentInput
    XTracker::Document::Role::LogPrintDoc
    XTracker::Role::WithSchema
};
