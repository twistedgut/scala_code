package XTracker::Order::Printing::ShippingInputForm;

use NAP::policy 'tt','exporter';
use Perl6::Export::Attrs;

use XTracker::XTemplate;
use XTracker::Barcode;
use XTracker::PrintFunctions;

use XTracker::Database::Currency;
use XTracker::Database::Invoice;
use XTracker::Database::Customer;
use XTracker::Database::Order;
use XTracker::Database::Shipment qw( :DEFAULT check_tax_included );
use XTracker::Database::Address;
use XTracker::Database::Finance;

use XTracker::Config::Local qw( config_var get_shipping_printers );

use XTracker::Constants::FromDB qw(
    :shipment_item_status
);

use XTracker::Error;
use List::Util qw(
    sum
);

# Use this so we can use the schema singleton without rewriting this module in OO.
use XTracker::Role::WithSchema;

sub generate_input_form :Export(:DEFAULT) {
    my ( $shipment_id, $printer ) = @_;

    my $schema = XTracker::Role::WithSchema->build_schema;
    my $dbh = $schema->storage->dbh;

    my $shipment = $schema->resultset('Public::Shipment')->find( $shipment_id );

    # skip Premier orders
    return 1 if $shipment->is_premier;

    # skip if we've already generated this form - don't want duplicates!
    return 1 if $shipment->search_related('shipment_print_logs', { document => 'Shipping Input Form' })->count;

    # get shipment data
    my $data;
    $data->{shipment} = get_shipment_info( $dbh, $shipment_id );

    # success or failure flag
    my $result = 0;

    ### gather all the info we need
    $data->{item}               = get_shipment_item_info( $dbh, $shipment_id );
    $data->{boxes}              = get_shipment_boxes( $dbh, $shipment_id );
    $data->{order}              = get_order_info( $dbh, $data->{shipment}{orders_id} );
    $data->{shipping_address}   = get_address_info( $dbh, $data->{shipment}{shipment_address_id} );
    $data->{country}            = get_country_tax_info(
        $dbh, $data->{shipping_address}{country}, $data->{order}{channel_id}
    );
    $data->{promotions}         = get_order_promotions( $dbh, $data->{shipment}{orders_id} );
    $data->{tax_included}       = check_tax_included( $dbh, $data->{shipping_address}{country} );
    $data->{gift_message_nr}    = scalar(@{ $shipment->get_gift_messages() });
    $data->{display_shipping_input_warning}  = $shipment->display_shipping_input_warning;

    $data->{shipping_service_descriptions}  = $shipment->get_shipping_service_descriptions();
    ### Manifest messages
    ############################

    ### default to nothing
    $data->{manifest_message} = "";

    ### need to convert all prices back to local currency
    my $conversion_rate = get_local_conversion_rate($dbh, $data->{order}{currency_id});

    $data->{customer} = get_customer_info( $dbh, $data->{order}{customer_id} );

    if ($data->{customer}{category} eq "None"){
        $data->{customer}{category} = "-";
    }

    ### set up some vars to total up stuff
    $data->{shipment}{total_price} = 0;
    $data->{shipment}{total_tax} = 0;
    $data->{shipment}{total_weight} = 0;

    ### loop through shipment items and do some stuff
    foreach my $id ( keys %{ $data->{item} } ) {
        # If Virtual Voucher then ignore
        next if ( $data->{item}{$id}{voucher} && !$data->{item}{$id}{is_physical} );

        SMARTMATCH: {
            use experimental 'smartmatch';
            ### ignore lost, cancel pending, cancelled or unelivered items
            next unless ( $data->{item}{$id}{shipment_item_status_id} ~~ [
                $SHIPMENT_ITEM_STATUS__NEW,
                $SHIPMENT_ITEM_STATUS__SELECTED,
                $SHIPMENT_ITEM_STATUS__PICKED,
                $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                $SHIPMENT_ITEM_STATUS__PACKED,
                $SHIPMENT_ITEM_STATUS__DISPATCHED,
                $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                $SHIPMENT_ITEM_STATUS__RETURNED,
            ] );

            ### all items must have a unit price - if its 0 then change to 1 (affects promotional gifts only)
            if ($data->{item}{$id}{unit_price} == 0) {
                $data->{item}{$id}{unit_price} = 1;
            }
            # Physical Vouchers must be set to 1 and have zero tax
            if ( $data->{item}{$id}{voucher} ) {
                $data->{item}{$id}{unit_price}  = '1.00';
                $data->{item}{$id}{tax}         = 0;
                # set legacy sku to be PID
                $data->{item}{$id}{legacy_sku}  = $data->{item}{$id}{product_id};
            }

            my $variant_id = $data->{item}{$id}{variant_id};
            ### already seen this variant - just increment qty, total price and weight
            if ( $data->{shipment_item}{$variant_id} ){
                $data->{shipment_item}{$variant_id}{quantity} = $data->{shipment_item}{$variant_id}{quantity} + 1;
                $data->{shipment_item}{$variant_id}{total_price} += _d2($data->{item}{$id}{unit_price} * $conversion_rate);
                $data->{shipment}{total_weight} += $data->{shipment_item}{$variant_id}{weight};
            }
            ### first time we've seen the variant - sort it out a bit
            else {
                ### get the shipping attributes for it - country of origin, hs code, that kind of thing
                $data->{shipment_item}{$variant_id} = get_product_shipping_attributes($dbh, $data->{item}{$id}{product_id});

                ### display shipping restriction for the product
                my $product = $schema->resultset('Public::Product')->find($data->{item}{$id}{product_id});
                try {
                    my $ship_restrictions = $product->get_shipping_restrictions_status;
                    $data->{shipment_item}{$data->{item}{$id}{variant_id}}{is_aerosol}
                        = $ship_restrictions->{is_aerosol};
                    $data->{shipment_item}{$data->{item}{$id}{variant_id}}{is_hazmat_lq}
                        = $ship_restrictions->{is_hazmat_lq};
                    $data->{shipment_item}{$data->{item}{$id}{variant_id}}{is_fish_wildlife}
                        = $ship_restrictions->{is_fish_wildlife};
                } catch {
                    warn 'Product id is a voucher, no shipping restrictions';
                };

                ### legacy code for anything which doesn't have a country of origin
                if (!$data->{shipment_item}{$variant_id}{country_of_origin}){
                    $data->{shipment_item}{$variant_id}{country_of_origin} = $data->{shipment_item}{$variant_id}{legacy_countryoforigin};
                }

                ### add scientific term to the fabric content if populated
                if ($data->{shipment_item}{$variant_id}{scientific_term}){
                    $data->{shipment_item}{$variant_id}{fabric_content} .= "<br>".$data->{shipment_item}{$variant_id}{scientific_term};
                }

                ### set the quantity of this variant to 1
                $data->{shipment_item}{$variant_id}{quantity} = 1;

                ### pricing stuff - conversions to local currency and tidy up to two decimal places
                $data->{shipment_item}{$variant_id}{total_price} = _d2($data->{item}{$id}{unit_price} * $conversion_rate);
                $data->{shipment_item}{$variant_id}{unit_price} = _d2($data->{item}{$id}{unit_price} * $conversion_rate);
                $data->{shipment_item}{$variant_id}{tax} = _d2($data->{item}{$id}{tax} * $conversion_rate);
                $data->{shipment_item}{$variant_id}{duty} = _d2($data->{item}{$id}{duty} * $conversion_rate);

                ### variant name, designer and SKU
                $data->{shipment_item}{$variant_id}{name} = $data->{item}{$id}{name};
                $data->{shipment_item}{$variant_id}{designer} = $data->{item}{$id}{designer};
                $data->{shipment_item}{$variant_id}{sku} = $data->{item}{$id}{legacy_sku};

                ### add weight of item to the total shipment weight
                $data->{shipment}{total_weight} += $data->{shipment_item}{$variant_id}{weight};
            }

            ### add tax and unit price to the shipment totals
            $data->{shipment}{total_tax} += $data->{item}{$id}{tax};
            $data->{shipment}{total_price} += $data->{item}{$id}{unit_price};
        } # end SMARTMATCH
    }

    ### Promotions
    ###     - add one unit of the appropriate currency and the weight for each promotion.
    $data->{promotions} = $shipment->get_promotion_types_for_invoice;
    $data->{shipment}{total_price}  += scalar @{ $data->{promotions} };
    $data->{shipment}{grand_total}  += scalar @{ $data->{promotions} };
    # Add an initial zero to sum to ensure undef is not returned. See List::Util docs.
    $data->{shipment}{total_weight} += sum ( 0, map { $_->weight } @{ $data->{promotions} } );

    ### convert totals to local currency and tidy up
    $data->{shipment}{total_tax}   = _d2($data->{shipment}{total_tax}       * $conversion_rate);
    $data->{shipment}{total_price} = _d2($data->{shipment}{total_price}     * $conversion_rate);
    $data->{shipment}{shipping}    = _d2($data->{shipment}{shipping_charge} * $conversion_rate);

    ### if we're shipping to a taxable country split out the tax from the total shipping charge
    if ( $data->{country}{rate} && ($data->{country}{rate} > 0) ){
        $data->{shipment}{shipping_tax} = _d2($data->{shipment}{shipping} - ($data->{shipment}{shipping} / ( 1 + $data->{country}{rate})));
        $data->{shipment}{shipping}     = _d2($data->{shipment}{shipping} - $data->{shipment}{shipping_tax});
    }

    $data->{shipment}{grand_total} = _d2($data->{shipment}{total_price} + $data->{shipment}{shipping});

    # tax needs to be included in total value of shipment
    if ($data->{tax_included}) {
        $data->{shipment}{grand_total} += $data->{shipment}{total_tax};
        $data->{shipment}{grand_total} += ($data->{shipment}{shipping_tax}||0);
    }

    ### create barcode if necessary
    my $barcode = create_barcode("pickorder".$shipment_id, $shipment_id, "small", 3, 1, 65)
        or die 'Could not create barcode for Shipping Input Form';

    # get the Sales Channel Branding for the TT Doc to use
    my $channel = $schema->resultset('Public::Channel')->find( $data->{order}{channel_id} );
    $data->{channel_branding}   = $channel->branding;

    # generate html document
    my $print_file = "shippingform-$shipment_id";
    my $html = create_document($print_file, 'print/shippingform.tt', $data );

    # Only print the form now if the DC is configured to, else just log it so
    # the user can get it later if they want
    if (config_var('Print_Document', 'requires_shipping_input_form_printouts')) {
        # print form for manual data entry

        # get printer info
        $data->{printer_info} = get_printer_by_name( $printer );

        # if we found it - print out the form
        if ( %{$data->{printer_info}||{}} ) {
            $result = print_document($print_file, $data->{printer_info}{lp_name}, 1, '');

            log_shipment_document($dbh, $shipment_id, 'Shipping Input Form', $print_file, $data->{printer_info}{name});
        }
    } else {
        $result = 1;
        my $shipping_printers = get_shipping_printers( $schema );

        log_shipment_document(
            $dbh,
            $shipment_id,
            'Shipping Input Form',
            $print_file,
            $shipping_printers->{document}->[0]->{name}  # no choice, apparently
        );
    }
    return $result;
}

sub _d2 {
    my $val = shift;
    my $n = sprintf( "%.2f", $val );
    return $n;
}

1;
