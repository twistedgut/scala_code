package XTracker::Document::Invoice;

use NAP::policy 'class';

use File::Spec;

use XTracker::Database;
use XTracker::Utilities qw( d2 );

use XTracker::XTemplate;

use XTracker::Config::Local qw(
    comp_addr
    comp_fax
    comp_tel
    comp_freephone
    comp_contact_hours
    config_var
    returns_email
    shipping_email
    customercare_email
);

use XTracker::Constants::FromDB qw{
    :shipment_type
};


extends 'XTracker::Document';

=head1 NAME

XTracker::Document::Invoice - Model invoice document and prints it

=head1 DESCRIPTION

Given a C<$shipment_id> it takes the shipment associated to it and generates the
invoice document. Also number of copies can be specified

=head1 SYNOPSIS

    my $document = XTracker::Document::Invoice->new(shipment_id => $shipment_id);
    $document->print_at_location($location, $copies);

=head1 ATTRIBUTES

=head2 document_type

Represents the type of the document. In this case it is a static attribute

=cut

has document_type => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    default  => 'invoice',
);

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }

=head2 renumeration_id

The renumeration id is used in building the filename

=cut

has renumeration => (
    is       => 'rw',
    isa      => 'Maybe[XTracker::Schema::Result::Public::Renumeration]',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_renumeration'
);

sub _build_renumeration {
    my $self = shift;

    return $self->shipment->get_sales_invoice;
}

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

        return sprintf( '%s-%s', $self->document_type, $self->renumeration->id);
    },
);


=head2 pretty_name

=cut

has 'pretty_name' => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    default  => 'Invoice',
);

=head2 template_path

String representing the path to the template of
the document

=cut

has '+template_path' => (
    default => 'print/invoice.tt',
);

=head2 gather_data

Gathers all the data needed, in a hashref, to build the outward proforma
TODO: needs to be refactored

=cut

sub gather_data {
    my $self = shift;

    my $renumeration = $self->renumeration;

    return {}
        unless $renumeration;

    my $shipment = $self->shipment;
    my $order    = $shipment->order;
    my $channel  = $order->channel;
    my $dc       = $order->channel->distrib_centre->name;

    my $config_section = $channel->business->config_section;

    my $data = {
        returns_email           => returns_email( $config_section ),
        customercare_email      => customercare_email( $config_section ),
        shipping_email          => shipping_email( $config_section ),
        tt_comp_addr            => comp_addr( $config_section ),
        tt_comp_tel             => comp_tel( $config_section ),
        tt_comp_freephone       => comp_freephone( $config_section ),
        tt_comp_contact_hours   => comp_contact_hours( $config_section ),
        tt_comp_fax             => comp_fax( $config_section ),
        tt_dc                   =>  config_var('DistributionCentre','name'),
        company_reg_num         => $channel->company_registration_number,

    };

    # Get tax information for shipping country
    my $c_ref            = {};
    my $country          = $shipment->shipment_address->country_ignore_case;
    my $country_tax_rate = $country->country_tax_rate;

    # If country has specific tax info set it to that
    if ( $country_tax_rate ) {
        my $country_tax_code = $country
        ->search_related(
                'country_tax_codes',
                { channel_id => $order->channel->id }
            )
        ->first;

        $c_ref->{tax_name} = $country_tax_rate->tax_name;
        $c_ref->{rate}     = $country_tax_rate->rate;
        $c_ref->{tax_code} = ( $country_tax_code ? $country_tax_code->code : undef );
    }

    # stop the template from warning on undef
    $c_ref->{rate} //= 0;

    # see if there is an order threshold rule
    my $country_tax_rules       = $country->tax_rule_values;
    while (my $country_tax_rule = $country_tax_rules->next) {
        if ($country_tax_rule->tax_rule->rule eq 'Order Threshold') {
            $c_ref->{order_threshold} = $country_tax_rule->value;
        }
    }
    $c_ref->{order_threshold} //= 0;

    # If there's no tax name set it to the default value
    $c_ref->{tax_name} //= config_var( 'Tax', 'default_tax_name' );

    # Pass DBIC address objects to template
    $data->{invoice_address}  = $order->order_address;
    $data->{shipping_address} = $shipment->shipment_address;

    $data->{currency_symbol} = $order->currency->get_glyph_html_entity;

    my $s_ref = {
        gift_message     => $shipment->gift_message,
        gift             => $shipment->gift,
        id               => $shipment->id,
        shipment_type_id => $shipment->shipment_type_id,
    };

    my $invoice_date = $renumeration->get_invoice_date;
    my $invoice = {
        date                 => $invoice_date,
        invoice_nr           => $renumeration->invoice_nr,
        renumeration_type_id => $renumeration->renumeration_type_id,
        ( branded_date => $channel->business->branded_date($invoice_date))x!! (defined $invoice_date)
    };

    # Not a customer order invoice
    unless ( $renumeration->is_order_class ) {
        $s_ref->{shipment_type_id} = $SHIPMENT_TYPE__UNKNOWN; # Originally set to 0
        $s_ref->{gift}             = 'false';
        $s_ref->{gift_message}     = q{};
    }
    $data->{shipment} = $s_ref;

    my @renumeration_items = $renumeration->renumeration_items->all;

    $invoice->{total_price} = 0;
    foreach my $item ( @renumeration_items ) {
        my $variant          = $item->shipment_item->get_true_variant;
        my $total_item_price = d2($item->unit_price + $item->tax + $item->duty);

        if ( exists $data->{invoice_item}{$variant->id} ) {
            $data->{invoice_item}{$variant->id}{quantity}++;
            $data->{invoice_item}{$variant->id}{total_price}
                += $total_item_price;
        }
        else {
            my $ri = {
                quantity    => 1,
                total_price => $total_item_price,
                unit_price  => $item->unit_price,
                tax         => $item->tax,
                duty        => $item->duty,
                name        => (
                                 $item->shipment_item->voucher_variant_id
                                 ? $variant->product->designer
                                   . q{ }
                                   . $variant->product->name
                                 : $variant->product->designer->designer
                                   . q{ }
                                   . $variant->product->attribute->name
                               ),
            };

            # Get tax rate used for display on invoice

            # Calculate backwards for vertex orders
            if ( $order->use_external_tax_rate ) {
                # DCS-3482: fixes divide by zero error, so that
                #           refunds on shipping charge only won't fail
                if ( ( $item->unit_price + $item->duty ) > 0 ) {
                    $ri->{tax_rate} = ( $item->tax
                                        / ( $item->unit_price + $item->duty )
                                      ) * 100;
                }
                else {
                    $ri->{tax_rate} = 0;
                }
            }
            else {
                $ri->{tax_rate}
                    = ( $country_tax_rate and $country_tax_rate->rate )
                    ? $country_tax_rate->rate * 100
                    : 0;
            }
            $data->{invoice_item}{$variant->id} = $ri;
        }
        $invoice->{total_price} += d2($total_item_price);
    }

    $invoice->{shipping}     = d2($renumeration->shipping);
    $invoice->{store_credit} = d2($renumeration->store_credit);
    $invoice->{gift_credit}  = d2($renumeration->gift_credit);
    $invoice->{gift_voucher} = d2($renumeration->gift_voucher);

    $invoice->{grand_total} = d2(
        $invoice->{total_price}
        + $invoice->{shipping}
        + $invoice->{store_credit}
        + $invoice->{gift_credit}
        + $invoice->{gift_voucher}
    );

    # Remove tax from shipping if required
    if ( $c_ref->{rate} && $invoice->{grand_total} > $c_ref->{order_threshold}) {
        $invoice->{shipping_tax} = d2(
                $renumeration->shipping
                -   ( $renumeration->shipping
                / ( 1 + $country_tax_rate->rate )
                )
        );
        $invoice->{shipping} -= $invoice->{shipping_tax};
    }

    $data->{country} = $c_ref;
    $data->{invoice} = $invoice;
    $data->{order} = {
        sales_channel => $order->channel->name,
        order_nr      => $order->order_nr,
    };

    $data->{customer}{is_customer_number} = $order->customer->is_customer_number;

    # Sales Channel branding
    $data->{channel_branding} = $channel->branding;

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
