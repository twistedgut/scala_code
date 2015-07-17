package XTracker::Document::OutwardProforma;

use NAP::policy 'class';

use List::Util qw( sum );

use XTracker::Config::Local qw(
    config_var
    returns_email
    customercare_email
    comp_addr
    comp_tel
    comp_fax
    comp_freephone
    comp_contact_hours
    dc_address
);

use XTracker::Constants::FromDB qw(
    :shipment_item_status
    :shipment_class
);

use XTracker::Database::Channel qw(get_channel_details);
use XTracker::Database::Currency;
use XTracker::Database::Invoice;
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Finance;

use XTracker::ShippingGoodsDescription qw( description_of_goods );
use XTracker::Utilities qw( number_in_list d2 );

use DateTime;

extends 'XTracker::Document';

=head1 NAME

XTracker::Document::OutwardProforma - Model outward proforma document and prints it

=head1 DESCRIPTION

Given a C<$shipment_id> it takes the shipment associated to it and generates the
outward proforma document. Also number of copies can be specified

=head1 SYNOPSIS

    my $document = XTracker::Document::OutwardProforma->new(shipment_id => $shipment_id);
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
    default  => 'outpro',
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

has pretty_name => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    default  => 'Outward Proforma',
);

=head2 template_path

String representing the path to the template of
the document


=cut

has '+template_path' => (
    lazy    => 1,
    default => 'print/outwardproforma.tt',
);

=head2 printer_type : 'document'

=cut

sub build_printer_type { 'document' }

=head1 METHODS

=head2 gather_data

Gathers all the data needed, in a hashref, to build the outward proforma
TODO: needs to be refactored

=cut

sub gather_data {
    my $self = shift;

    my $dbh = $self->dbh;

    # CANDO-101: require DBIC version of records to use the Branded Date
    my $shipment = $self->shipment;
    my $channel  = $shipment->order->channel;

    my $data;

    # get all the shipment data required
    $data->{shipment}           = get_shipment_info( $dbh, $shipment->id );
    $data->{item}               = get_shipment_item_info( $dbh, $shipment->id );
    $data->{boxes}              = get_shipment_boxes( $dbh, $shipment->id );
    $data->{order}              = get_order_info( $dbh, $data->{shipment}{orders_id} );
    $data->{channel}            = get_channel_details( $dbh, $data->{order}{sales_channel} );
    $data->{shipping_address}   = get_address_info( $dbh, $data->{shipment}{shipment_address_id} );
    $data->{country}            = get_country_tax_info( $dbh, $data->{shipping_address}{country}, $data->{order}{channel_id} );

    # get stuff from config
    $data->{returns_email}      = returns_email( $data->{channel}{config_section} );
    $data->{customercare_email} = customercare_email( $data->{channel}{config_section} );
    $data->{tt_comp_addr}       = comp_addr( $data->{channel}{config_section} );
    $data->{tt_comp_tel}        = comp_tel( $data->{channel}{config_section} );
    $data->{tt_comp_fax}        = comp_fax( $data->{channel}{config_section} );
    $data->{tt_comp_freephone}  = comp_freephone( $data->{channel}{config_section} );
    $data->{tt_comp_contact_hours} = comp_contact_hours( $data->{channel}{config_section} );
    $data->{tt_dc}              =  config_var('DistributionCentre','name');
    $data->{company_reg_num}    = $data->{channel}{company_registration_number};

    # set exchange rate to 1 - we'll use this later to convert all the values to correct currency for shipping country
    my $exch_rate = 1;

    $data->{date}           = $self->schema->db_now;
    $data->{branded_date}   = $channel->business->branded_date( $data->{date} );

    ### need to convert order to local currency for most countries
    #my $conversion_rate = get_local_conversion_rate($dbh, $data->{order}{currency_id});
    # EN-1986: Don't want Values Converted keep it at the Order Currency
    #          setting this to 1 so that I don't have to go round and change
    #          all the code using it and risk a bug developing
    my $conversion_rate = 1;

    ### check if country requires commercial proformas
    $data->{country} = $self->schema->resultset('Public::Country')
        ->find({
            country => $data->{shipping_address}{country}
        });

    ### re-write country name for the US
    if ($data->{shipping_address}{country} eq "United States") {
        $data->{shipping_address}{country} = "United States of America";
    }

    ### set up some totals
    $data->{shipment}{total_price}              = 0;
    $data->{shipment}{total_tax}                = 0;
    $data->{shipment}{total_weight}             = 0;
    $data->{shipment}{total_volumetric_weight}  = 0;

    my $total_items     = 0;
    my $total_vouchers  = 0;

    ### loop through shipment items and do stuff
    foreach my $rec ( values %{ $data->{item} } ) {
        # If Virtual Voucher then ignore
        if ( $rec->{voucher} && !$rec->{is_physical} ) {
            next;
        }
        # maintain a count of items and vouchers
        $total_items++;
        if ( $rec->{voucher} ) {
            $total_vouchers++;
        }

        ### ignore cancelled items
        if (number_in_list($rec->{shipment_item_status_id},
                           $SHIPMENT_ITEM_STATUS__NEW,
                           $SHIPMENT_ITEM_STATUS__SELECTED,
                           $SHIPMENT_ITEM_STATUS__PICKED,
                           $SHIPMENT_ITEM_STATUS__PACKED,
                           $SHIPMENT_ITEM_STATUS__DISPATCHED,
                           $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                           $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                           $SHIPMENT_ITEM_STATUS__RETURNED,
                           $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION) ) {

            ### all items must have a unit price - if its 0 then change to 1 (affects promotional gifts only)
            if ($rec->{unit_price} == 0) {
                $rec->{unit_price} = 1;
            }

            # Physical Vouchers must be set to 1 and have zero tax
            if ( $rec->{voucher} ) {
                $rec->{unit_price}  = '1.00';
                $rec->{tax}         = 0;
            }

            ### already seen this variant - just increment stuff
            if ( $data->{shipment_item}{$rec->{variant_id}} ){
                $data->{shipment_item}{$rec->{variant_id}}{quantity}++;
                $data->{shipment_item}{$rec->{variant_id}}{total_price} += $rec->{unit_price} * $conversion_rate;
                $data->{shipment}{total_weight}                         += $data->{shipment_item}{$rec->{variant_id}}{weight};
            }
            ### first time we've seen this variant
            else {

                ### get shipping info for it
                $data->{shipment_item}{$rec->{variant_id}} = get_product_shipping_attributes($dbh, $rec->{product_id});

                ### legacy stuff
                $data->{shipment_item}{$rec->{variant_id}}{country_of_origin} //= $data->{shipment_item}{$rec->{variant_id}}{legacy_countryoforigin};

                ### do some stuff to the fabric content
                if ($data->{shipment_item}{$rec->{variant_id}}{scientific_term}){

                    if ( $data->{shipment_item}{$rec->{variant_id}}{fish_wildlife} ) {
                        $data->{shipment_item}{$rec->{variant_id}}{fabric_content} .= "<big><b>";
                    }

                    $data->{shipment_item}{$rec->{variant_id}}{fabric_content} .= "<br>".$data->{shipment_item}{$rec->{variant_id}}{scientific_term};
                }

                $data->{shipment_item}{$rec->{variant_id}}{quantity} = 1;

                ### pricing - convert to local currency and to two decimal places
                $data->{shipment_item}{$rec->{variant_id}}{total_price} = $rec->{unit_price} * $conversion_rate;
                $data->{shipment_item}{$rec->{variant_id}}{unit_price}  = d2($rec->{unit_price} * $conversion_rate);
                $data->{shipment_item}{$rec->{variant_id}}{tax}         = d2($rec->{tax} * $conversion_rate);
                $data->{shipment_item}{$rec->{variant_id}}{duty}        = d2($rec->{duty} * $conversion_rate);

                $data->{shipment_item}{$rec->{variant_id}}{name}        = $rec->{name};
                $data->{shipment_item}{$rec->{variant_id}}{description} = $rec->{description};
                $data->{shipment_item}{$rec->{variant_id}}{product_id}  = $rec->{product_id};

                $data->{shipment}{total_weight} += $data->{shipment_item}{$rec->{variant_id}}{weight};
            }

            $data->{shipment}{total_tax}    += $rec->{tax};
            $data->{shipment}{total_price}  += $rec->{unit_price};
        }
    }

    ### loop through the boxes used for the shipment and add to total weight
    foreach my $boxid ( keys %{ $data->{boxes} } ) {
        $data->{shipment}{total_weight} += $data->{boxes}{$boxid}{weight};
        $data->{shipment}{total_volumetric_weight} += $data->{boxes}{$boxid}{volumetric_weight};
    }

    ### if taxable country then split tax out of total shipping charge
    if ( $data->{country}{rate} && ($data->{country}{rate} > 0) ) {
        $data->{shipment}{shipping_tax} = d2($data->{shipment}{shipping_charge} - ($data->{shipment}{shipping_charge} / ( 1 + $data->{country}{rate})));
    }
    $data->{shipment}{shipping_tax} //= 0;

    ### tidying stuff up
    $data->{shipment}{total_price}      = d2(($data->{shipment}{total_price} + $data->{shipment}{shipping_charge}) * $conversion_rate);
    $data->{shipment}{total_tax}        = d2($data->{shipment}{total_tax} * $conversion_rate);
    $data->{shipment}{shipping_charge}  = d2($data->{shipment}{shipping_charge} * $conversion_rate);
    $data->{shipment}{grand_total}      = $data->{shipment}{total_price};

    # check to see if it is a Voucher Order only
    $data->{shipment}{vouchers_only} = ( $total_items == $total_vouchers ) ? 1 : 0;

    # no tax info in database - default to configured tax settings
    # update: tax code moved to db with inroduction of JC channel
    if ( !$data->{country}{tax_name} ) {
        $data->{country}{tax_name} = config_var('Tax', 'default_tax_name'); # "VAT"
        $data->{country}{tax_code} = $data->{channel}{default_tax_code};
    }

    # Set up reason for export
    if ($data->{shipment}->{shipment_class_id} == $SHIPMENT_CLASS__EXCHANGE) {
        $data->{export_reason} = 'EXCHANGE';
    }
    else {
        my $hscodes = $shipment->hs_codes;
        $data->{export_reason} = uc(
            description_of_goods({
                hs_codes  => $hscodes,
                docs_only => $data->{shipment}{vouchers_only},
                hazmat    => $shipment->has_hazmat_items,
                line_len  => 1000 }
            ));
    }

    ### Promotions
    ###     - add one unit of the appropriate currency and the weight for each promotion.
    $data->{promotions} = $shipment->get_promotion_types_for_invoice;
    $data->{shipment}{total_price}  += scalar @{ $data->{promotions} };
    $data->{shipment}{grand_total}  += scalar @{ $data->{promotions} };
    # Add an initial zero to sum to ensure undef is not returned. See List::Util docs.
    $data->{shipment}{total_weight} += sum ( 0, map { $_->weight } @{ $data->{promotions} } );

    ### currency conversions for countries where prices must be in dollars
    $data->{shipment}{total_tax}       = d2($data->{shipment}{total_tax}   * $exch_rate);
    $data->{shipment}{total_price}     = d2($data->{shipment}{total_price} * $exch_rate);
    $data->{shipment}{shipping_charge} = d2($data->{shipment}{shipping_charge} * $exch_rate);
    $data->{shipment}{shipping_tax}    = d2($data->{shipment}{shipping_tax} * $exch_rate);
    $data->{shipment}{grand_total}     = d2($data->{shipment}{grand_total}  * $exch_rate);

    foreach my $id ( keys %{ $data->{shipment_item} } ) {
        $data->{shipment_item}{$id}{unit_price}     = d2($data->{shipment_item}{$id}{unit_price}  * $exch_rate);
        $data->{shipment_item}{$id}{total_price}    = d2($data->{shipment_item}{$id}{total_price} * $exch_rate);
    }

    $data->{dc_city} = dc_address($channel)->{city};

    $data->{channel_branding}   = $channel->branding;

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
