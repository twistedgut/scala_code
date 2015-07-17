#!/usr/bin/perl

package XTracker::DHL::XMLDocument;

use strict;
use warnings;
use feature 'unicode_strings';

use XML::Writer;
use XML::LibXML;
use XTracker::Config::Local qw(
    dhl_xmlpi
    config_var
    can_autofill_town_for_address_validation
    get_autofilled_town_for_address_validation
    use_alternate_country_code
    dc_address
);
use Data::Dump qw/pp/;
use XTracker::DBEncode qw( encode_it );
use XTracker::Logfile qw(xt_logger);
use XTracker::ShippingGoodsDescription qw( description_of_goods );
use DateTime;
use POSIX qw( ceil );
use NAP::ShippingOption;
use Text::Unidecode;

### get xmlpi, capability api and local currency details from the config
my $xmlpi_info = dhl_xmlpi();
my $local_currency = config_var('Currency', 'local_currency_code');

sub build_request_xml {
    my $args = shift;
    my $request_xml = build_routing_xml($args->{shipment_address});
    return $request_xml;
}

=head2 build_routing_xml

Build the request XML for the DHL routing service if the capability api is not
used by the DC, using the shipment address provided.

Rendered XML, suitable for the DHL Routing service, is returned.

=cut

sub build_routing_xml {

    my ($shipment_address)= @_;

    my $output;

    my $DHL_URL             = $xmlpi_info->{dhl_url};
    my $DHL_XML_URL         = $xmlpi_info->{schema_url};
    my $DHL_SCHEMA_LOCATION = $xmlpi_info->{rou_location_url};
    my $DHL_ROU_HEADER      = $xmlpi_info->{rou_header};
    my $DHL_ROUTING_VERSION = $xmlpi_info->{routing_version};
    xt_logger->info("DHL routing request XML is being generated.");

    my $writer = XML::Writer->new(
        OUTPUT      => \$output,
        DATA_MODE   => 'true',
        DATA_INDENT => 4,
        NAMESPACES  => 1,
        ENCODING    => 'utf-8',
        PREFIX_MAP  => { $DHL_URL  => 'ns1' ,
                         $DHL_XML_URL   => 'xsi',
                         $DHL_ROUTING_VERSION => 'schemaVersion'},
        FORCED_NS_DECLS  => [ $DHL_URL, $DHL_XML_URL, $DHL_ROUTING_VERSION ],
    );

    # Auto Fill Town (if empty) with a default City value
    my $towncity = $shipment_address->{towncity};
    if ( get_autofilled_town_for_address_validation( 'DHL', $shipment_address->{country_code} ) ) {
        $towncity = get_autofilled_town_for_address_validation( 'DHL', $shipment_address->{country_code} );
    }

    # To pass address validation some counties may need to use a different country
    # code (e.g. XY instead of BL)
    my $country_code = $shipment_address->{country_code};
    if ( my $alt_code = use_alternate_country_code( 'DHL', $country_code ) ) {
        $country_code = $alt_code;
    }

    $writer->xmlDecl();
    $writer->startTag([$DHL_URL, $DHL_ROU_HEADER], [$DHL_XML_URL, "schemaLocation"], "$DHL_SCHEMA_LOCATION");

        $writer->startTag( 'Request');
            $writer->startTag( 'ServiceHeader');
                $writer->dataElement( 'MessageTime', $shipment_address->{date} );
                # note: this is a required field, but is never used so we pass a dummy code reference
                $writer->dataElement( 'MessageReference', '1234567890123456789012345678901' );
                $writer->dataElement( 'SiteID', $xmlpi_info->{username} );
                $writer->dataElement( 'Password', $xmlpi_info->{password} );
            $writer->endTag(  );
        $writer->endTag(  );

        $writer->dataElement( 'RegionCode', $xmlpi_info->{region_code} );

        $writer->dataElement( 'RequestType', 'D' );

        $writer->dataElement( 'Address1', substr($shipment_address->{address_line_1}, 0, 35) );

        $writer->dataElement( 'Address2', substr($shipment_address->{address_line_2}, 0, 35) );

        $writer->dataElement( 'PostalCode', substr($shipment_address->{postcode}, 0, 12) );

        $writer->dataElement( 'City', substr($towncity, 0, 35) );

        $writer->dataElement( 'Division', substr($shipment_address->{county}, 0, 35) );

        $writer->dataElement( 'CountryCode', $country_code );

        $writer->dataElement( 'CountryName', $shipment_address->{country} );

        $writer->dataElement( 'OriginCountryCode', config_var('DistributionCentre', 'alpha-2') );

    $writer->endTag(  );

    return encode_it($output);
}

=head2 build_label_request_xml

Build the request XML for the DHL capability service (DCT), providing the capability
api is used by the DC, using the $shipment_address information.

##pass shipment or shipment id and get shipment from that??

Other parameters:
$is_dutiable          - is the shipment dutiable for DHL
$shipment_value       - value of shipment

Rendered XML, suitable for the DHL Capability service, is returned.

=cut

sub build_label_request_xml {

    my $args = shift;
    my $shipment      = $args->{shipment};

    my $output;

    my $DHL_URL       = $xmlpi_info->{dhl_url};
    my $DHL_XML_URL   = $xmlpi_info->{schema_url};
    my $DHL_SCHEMA_LOCATION = $xmlpi_info->{svl_location_url};
    my $DHL_SVL_HEADER = $xmlpi_info->{svl_header};
    my $DHL_SCHEMA_VERSION = $xmlpi_info->{schema_version};
    xt_logger->info("DHL label request XML is being generated.");

    my $writer = XML::Writer->new(
        OUTPUT           => \$output,
        NAMESPACES       => 1,
        DATA_MODE        => 'true',
        DATA_INDENT      => 4,
        UNSAFE           => 0,
        ENCODING         => 'utf-8',
        PREFIX_MAP       => { $DHL_URL            => 'req',
                              $DHL_XML_URL        => 'xsi',
                              $DHL_SCHEMA_VERSION => 'schemaVersion'},,
        FORCED_NS_DECLS  => [ $DHL_URL, $DHL_XML_URL, $DHL_SCHEMA_VERSION ],
    );

    my $date_time             = $shipment->result_source->schema->db_now();
    my $order_currency        = $shipment->get_currency;
    my $shipment_total_weight = $shipment->total_weight;

    my $dc_address            = dc_address($shipment->get_channel);
    my $customer_details      = $shipment->customer_details;
    my $shipment_is_ddu       = $shipment->is_international_ddu;
    my @shipment_boxes        = $shipment->shipment_boxes->search( undef, { order_by => { -asc => 'id'} } )->all;

    my $contents_description  =  description_of_goods({ hs_codes   => $shipment->hs_codes,
                                                         docs_only => $shipment->is_voucher_only,
                                                         hazmat    => $shipment->has_hazmat_items,
                                                         hazmat_lq => $shipment->has_hazmat_lq_items,
                                                         line_len  => 88,
                                                         lines     => 1 });

    # Valid DimensionUnit values for DHL API are I (Inches) and C (Centimetres)
    my $dimension_unit        = config_var('Units','dimensions') eq 'in' ? 'I' : 'C';
    # Valid WeightUnit values for DHL are L (pounds) and K (kilograms)
    my $weight_unit           = config_var('Units','weight') eq 'lbs' ? 'L' : 'K';

    #need to know DHL global code for shipping option
    my $shipping_option_info = {
        shipping_account_name => $shipment->shipping_account->name,
        shipment_type         => $shipment->shipment_type->type,
        sub_region            => $shipment->get_shipment_sub_region,
        is_voucher_only       => $shipment->is_voucher_only ? 1 : 0,
    };
    my $shipping_option = NAP::ShippingOption->new_from_query_hash($shipping_option_info);
    my $is_dutiable_value = $shipment->is_dhl_dutiable ? 'Y' : 'N';
    my $requires_archive_label = $shipment->requires_archive_label ? 'Y' : 'N';

    # Auto Fill Town (if empty) with a default City value
    # if the city has a value, it is transferred to address_line3, if that parameter has no value
    my $towncity = $customer_details->{'Address'}->{'City'};
    my $address_line3 = $customer_details->{'Address'}->{'AddressLine3'};
    if ( get_autofilled_town_for_address_validation( 'DHL', $shipment->get_shippable_country_code ) ) {
        $address_line3 = $towncity if ( $towncity && !$address_line3 );
        $towncity = get_autofilled_town_for_address_validation( 'DHL', $shipment->get_shippable_country_code );
    }

    # To pass address validation some counties may need to use a different country
    # code (e.g. XY instead of BL)
    my $country_code = $customer_details->{'Address'}->{'CountryCode'};
    if ( my $alt_code = use_alternate_country_code( 'DHL', $country_code ) ) {
        $country_code = $alt_code;
    }

    $writer->xmlDecl();

    $writer->startTag([$DHL_URL, $DHL_SVL_HEADER], [$DHL_XML_URL, "schemaLocation"], "$DHL_SCHEMA_LOCATION");

        # A 28 character MessageReference MUST be provided, but is never used
        # so this dummy string is used
        $writer->startTag( 'Request' );
            $writer->startTag( 'ServiceHeader' );
                $writer->dataElement( 'MessageTime', $date_time );
                $writer->dataElement( 'MessageReference', '1234567123456712345671234567' );
                $writer->dataElement( 'SiteID', $xmlpi_info->{username} );
                $writer->dataElement( 'Password', $xmlpi_info->{password} );
            $writer->endTag(  );
        $writer->endTag(  );

        $writer->dataElement( 'RegionCode', $xmlpi_info->{region_code} );
        $writer->dataElement( 'NewShipper', 'N' );
        $writer->dataElement( 'LanguageCode', $xmlpi_info->{language_code} );
        $writer->dataElement( 'PiecesEnabled', 'Y' );

        $writer->startTag( 'Billing' );
            $writer->dataElement( 'ShipperAccountNumber', $shipment->shipping_account->account_number );
            $writer->dataElement( 'ShippingPaymentType', 'S' );

            if ( $shipment->is_dhl_dutiable ) {
                my $duty_type = $shipment_is_ddu ? 'R' : 'S';
                $writer->dataElement( 'BillingAccountNumber', $shipment->shipping_account->account_number );
                $writer->dataElement( 'DutyPaymentType', $duty_type );

                $writer->dataElement( 'DutyAccountNumber',  $shipment->shipping_account->account_number )
                    if (!$shipment_is_ddu);
            }
        $writer->endTag(  );

        $writer->startTag( 'Consignee' );
            $writer->dataElement( 'CompanyName', substr($customer_details->{'Name'}, 0, 35) );
            $writer->dataElement( 'AddressLine',  substr($customer_details->{'Address'}->{'AddressLine1'}, 0, 35) );
            if ( $customer_details->{'Address'}->{'AddressLine2'} ) {
                $writer->dataElement( 'AddressLine', substr($customer_details->{'Address'}->{'AddressLine2'}, 0, 35) );
            }
            if ( $address_line3 ) {
                $writer->dataElement( 'AddressLine', substr($address_line3, 0, 35) );
            }
            $writer->dataElement( 'City', substr($towncity, 0, 35) );
            if ( $customer_details->{'Address'}->{'StateProvinceCode'} ) {
                $writer->dataElement( 'Division', substr($customer_details->{'Address'}->{'StateProvinceCode'}, 0, 35) );
            }
            $writer->dataElement( 'PostalCode', substr($customer_details->{'Address'}->{'PostalCode'}, 0, 12) );
            # why is this taken from the $customer_details, but CountryName is taken from shipment_address?
            $writer->dataElement( 'CountryCode',  $country_code );
            $writer->dataElement( 'CountryName', $shipment->shipment_address->country );
            $writer->startTag( 'Contact' );
                $writer->emptyTag( 'PersonName' );
                $writer->dataElement( 'PhoneNumber',  $shipment->mobile_telephone || $shipment->telephone );
                $writer->dataElement( 'Email', $customer_details->{'EMailAddress'} );
            $writer->endTag(  );
        $writer->endTag(  );

        if ( $shipment->is_dhl_dutiable ) {
            $writer->startTag( 'Dutiable' );
                my $declared_value =  sprintf "%.2f", $shipment->total_customs_value;
                $writer->dataElement( 'DeclaredValue', $declared_value );
                $writer->dataElement( 'DeclaredCurrency', $order_currency->currency );
                $writer->dataElement( 'TermsOfTrade', $shipment_is_ddu ? 'DDU' : 'DDP' );
            $writer->endTag(  );

            my $export_information = $shipment->export_declaration_information;
            my $line_number = 1;
            $writer->startTag( 'ExportDeclaration' );
            foreach my $variant ( keys %{ $export_information } ) {
                $writer->startTag( 'ExportLineItem' );
                    $writer->dataElement( 'LineNumber', $line_number++ );
                    $writer->dataElement( 'Quantity', $export_information->{$variant}->{quantity} );
                    $writer->dataElement( 'QuantityUnit', 'piece' );
                    # make sure the "Contents" does not have non-ascii characters,
                    # this is a quick fix and rest is going to be done  within WHM-4636
                    $writer->dataElement(
                        'Description',
                        substr( unidecode($export_information->{$variant}->{description}),0,75)
                    );
                    $writer->dataElement( 'Value', $export_information->{$variant}->{total_price} );
                $writer->endTag( );
            }
            $writer->endTag( );
        }

        $writer->startTag( 'Reference' );
            $writer->dataElement( 'ReferenceID', $shipment->order->order_nr );
            $writer->dataElement( 'ReferenceType', 'St' );
        $writer->endTag(  );

        $writer->startTag( 'ShipmentDetails' );
            $writer->dataElement( 'NumberOfPieces', scalar @shipment_boxes );
            $writer->startTag( 'Pieces' );
                for my $box ( @shipment_boxes ) {
                    $shipment_total_weight += $box->box->weight;
                    $writer->startTag( 'Piece' );
                        $writer->dataElement( 'PieceID', $box->id );
                        $writer->dataElement( 'PackageType', 'CP' );
                        my $package_weight = sprintf "%.3f", $box->package_weight;
                        $writer->dataElement( 'Weight', $package_weight );
                        $writer->dataElement( 'DimWeight', $box->box->volumetric_weight );
                        $writer->dataElement( 'Width', ceil( $box->outer_box->width + 0.1 ) );
                        $writer->dataElement( 'Height', ceil( $box->outer_box->height + 0.1 ) );
                        $writer->dataElement( 'Depth', ceil( $box->outer_box->length + 0.1 ) );
                    $writer->endTag(  );
                }
            $writer->endTag(  );

            my $formatted_total_weight = sprintf "%.3f", $shipment_total_weight;
            $writer->dataElement( 'Weight', $formatted_total_weight );
            $writer->dataElement( 'WeightUnit', $weight_unit );
            # Note - the global_product_code is intentionally used for the LocalProductCode
            # and the GlobalProductCode. DHL (currently) do not provide any local product codes
            # and the DHL tech rep advised us to use the global code here as it is mandatory
            # to provide the LocalProductCode field....
            $writer->dataElement( 'GlobalProductCode', $shipping_option->global_product_code );
            $writer->dataElement( 'LocalProductCode', $shipping_option->global_product_code );
            $writer->dataElement( 'Date', $date_time->date );
            # make sure the "Contents" does not have non-ascii characters,
            # this is a quick fix and rest is going to be done  within WHM-4636
            $writer->dataElement( 'Contents', unidecode($contents_description) );
            $writer->dataElement( 'DoorTo', 'DD' );
            $writer->dataElement( 'DimensionUnit', $dimension_unit );
            $writer->dataElement( 'PackageType', 'CP' );
            $writer->dataElement( 'IsDutiable', $is_dutiable_value );
            $writer->dataElement( 'CurrencyCode', $order_currency->currency() );
            # this tag can also be used for French door codes (see WHM-3437)
            if (!$shipment->is_signature_required) {
                $writer->dataElement( 'CustData', 'Leave in safe place - Does not require signature' );
            }
        $writer->endTag(  );

        $writer->startTag( 'Shipper' );
            $writer->dataElement( 'ShipperID', $shipment->shipping_account->channel->business->name );
            $writer->dataElement( 'CompanyName', $shipment->shipping_account->channel->business->name );
            $writer->dataElement( 'AddressLine',  $dc_address->{addr1} );
            $writer->dataElement( 'City', $dc_address->{city} );
            $writer->dataElement( 'PostalCode', $dc_address->{postcode} );
            $writer->dataElement( 'CountryCode', $dc_address->{'alpha-2'} );
            $writer->dataElement( 'CountryName', $dc_address->{country} );
            $writer->startTag( 'Contact' );
                $writer->dataElement( 'PersonName', 'Dispatch Department' );
                $writer->dataElement( 'PhoneNumber', '00' );
            $writer->endTag(  );
        $writer->endTag(  );

        if ($shipment->is_saturday_nominated_delivery_date) {
            $writer->startTag( 'SpecialService' );
                $writer->dataElement( 'SpecialServiceType', 'AA' );
            $writer->endTag(  );
        }

        if ($shipment->has_hazmat_lq_items) {
            $writer->startTag( 'SpecialService' );
                $writer->dataElement( 'SpecialServiceType', 'HL' );
            $writer->endTag(  );
        }

        if (!$shipment->is_signature_required) {
            $writer->startTag( 'SpecialService' );
                $writer->dataElement( 'SpecialServiceType', 'SX' );
            $writer->endTag(  );
        }

        $writer->dataElement( 'LabelImageFormat', 'ZPL2' );
        # SHIP-676: we only want to print archive label for
        # dutiable shipments
        $writer->dataElement( 'RequestArchiveDoc', $requires_archive_label );

        $writer->startTag( 'Label' );
            $writer->dataElement( 'LabelTemplate', $xmlpi_info->{label_template} );
            # this element is used to turn DHL logo on / off
            $writer->dataElement( 'Logo', $xmlpi_info->{use_dhl_logo} ? 'Y' : 'N' );
            # this tag will be used to add NAP logo
            #$writer->startTag( 'CustomerLogo' );
            #    $writer->dataElement( 'LogoImage', <Base64 encoded image> );
            #    $writer->dataElement( 'LogoImageFormat', <image format> );
            #$writer->endTag(  );
            $writer->dataElement( 'Resolution', $xmlpi_info->{label_resolution} );
        $writer->endTag(  );

    $writer->endTag(  );

    return encode_it($output);
}

sub parse_xml_response {

    my ($response_xml) = @_;

    my $parsed_data = parse_routing_response($response_xml);

    return $parsed_data;

}

=head2 parse_routing_response

Parse the XML received in response from the DHL routing service

This will die if the the XML response contains no data or if errors are present
within the Condition tag.

Return values:

MessageTime          - time message received by DHL service
MessageReference     - ID of message for tracing (not used)
SiteID               - name of DHL service user (i.e. NetAPorter)
GMTNegativeIndicator - is shipment destination time behind origin
GMTOffset            - offset in hours of shipment destination from origin
RegionCode           - DHL region code of shipment origin
ServiceAreaCode      - DHL area code for shipment destination
Description          - full DHL descripton for shipment destination

=cut

sub parse_routing_response {

    my ($response_xml) = @_;

    my %data;

    my $parser = XML::LibXML->new;
    my $doc;
    eval {
        $doc = $parser->parse_string($response_xml);
    };
    if ($@) {
        die __PACKAGE__ .": Failed parsing supposedly xml response - "
            . pp($response_xml);
    }
    my $root = $doc->getDocumentElement;

    ### service header
    $data{MessageTime} = $root->findvalue('MessageTime');
    $data{SiteID} = $root->findvalue('SiteID');

    ### get errors
    my @conditions = $root->getElementsByTagName('Condition');

    foreach my $condition ( @conditions ){
        my $code = $condition->findvalue('ConditionCode');
        my $error_message = $condition->findvalue('ConditionData');

        # strip extraneous whitespace from error message
        $error_message =~ s/\s+/ /g;
        $error_message =~ s/^\s+|\s+$//g;
        $data{error}{$code} = $error_message;
    }

    ### no errors get repsonse data fields
    if ( exists $data{error} ) {
        die $data{error};
    }
    else {
        $data{GMTNegativeIndicator} = $root->findvalue('GMTNegativeIndicator');
        $data{GMTOffset} = $root->findvalue('GMTOffset');
        $data{RegionCode} = $root->findvalue('RegionCode');
        $data{ServiceAreaCode} = $root->findvalue('ServiceArea/ServiceAreaCode');
        $data{Description} = $root->findvalue('ServiceArea/Description');
    }

    # check that not all the values are empty string - this is bad
    my @empty = grep { $_ eq "" } values %data;
    if (scalar @empty == scalar keys %data) {
        xt_logger->warn("No data in DHL response ".pp($response_xml));
        die { "X" => "Unable to get DHL routing data. No data returned" };
    }

    return \%data;
}

=head2 parse_label_response_xml

Parse the XML received in response from the DHL shipment validate service.

This will die if the the XML response contains no data or if errors are present
within the Condition tag.

Return values:

MessageTime        - time message received by DHL service
SiteID             - name of DHL service user (i.e. NetAPorter)
OriginAreaCode     - DHL area code of DC warehouse
ServiceAreaCode    - DHL area code for shipment destination
AirwayBillNumber   - DHL AWB number(!)
DHLRoutingCode     - code that contains routing number, e.g. GI:GIBGIB+48000001
DHLRoutingDataId   - e.g.2L
ProductContentCode - DHL code for shipping type, e.g. WPX, DOM
ProductShortName   - DHL name for shipping type, e.g. EXPRESS WORLDWIDE
LicensePlate       - DHL tracking number
OutputImage        - Image for box labels and archive label

=cut

sub parse_label_response_xml {

    my ($response_xml) = @_;

    my %data;
    my @conditions;
    xt_logger->info("DHL label response XML is being parsed.");
    my $parser = XML::LibXML->new;
    my $doc = undef;
    eval {
        $doc = $parser->parse_string($response_xml);
    };
    if ($@) {
        die __PACKAGE__ .": Failed parsing supposedly xml response - "
            . pp($response_xml);
    }
    my $root = $doc->getDocumentElement;

    foreach my $note_tag ( $root->getElementsByTagName('Note') ) {
        $data{ActionNote} = $note_tag->findvalue('ActionNote');
    }

    ### service header
    foreach my $service_tag ( $root->getElementsByTagName('ServiceHeader') ) {
        $data{MessageTime} = $service_tag->findvalue('MessageTime');
        $data{SiteID} = $service_tag->findvalue('SiteID');
    }

    ### The xml response may contain errors and warnings in Condition tags
    ### Warnings are currently ignored as long as the label request is successful
    my $request_successful = ($data{ActionNote} && $data{ActionNote} eq 'Success');
    @conditions = $root->getElementsByTagName('Condition') unless $request_successful;
    my $service_unavailable_code = 108;

    foreach my $condition ( @conditions ){
        my $code = $condition->findvalue('ConditionCode');
        my $error_message = $condition->findvalue('ConditionData');

        # strip leading/trailing whitespace from error message
        $error_message =~ s/\s+/ /g;
        $error_message =~ s/^\s+|\s+$//;
        # If DHL service is unavailable, a special message is returned, otherwise
        # the DHL error message is returned
        $error_message = "DHL Service is unavailable, please contact Service Desk to get in touch with DHL to rectify the problem."
            if $code eq $service_unavailable_code;
        $data{error}{$code} = $error_message;
    }

    ### no errors get response data fields
    if(! exists $data{error}) {
        $data{AirwayBillNumber}   = $root->findvalue('AirwayBillNumber');
        $data{DHLRoutingCode}     = $root->findvalue('DHLRoutingCode');
        $data{DHLRoutingDataId}   = $root->findvalue('DHLRoutingDataId');
        $data{ProductContentCode} = $root->findvalue('ProductContentCode');
        $data{ProductShortName}   = $root->findvalue('ProductShortName');
        $data{ShipmentDate}       = $root->findvalue('ShipmentDate');

        my @pieces = $root->findnodes('Pieces/Piece');
        my %box_tracking_number;
        foreach my $piece ( @pieces ) {
            $box_tracking_number{$piece->findvalue('PieceNumber') - 1} = $piece->findvalue('LicensePlate');
        }
        $data{BoxTrackingNumbers} = \%box_tracking_number;

        foreach my $label_image ( $root->getElementsByTagName('LabelImage') ) {
            $data{OutputImage} = $label_image->findvalue('OutputImage');
        }
    }

    # check that not all the values are empty string - this is bad
    my @empty = grep { $_ eq "" } values %data;
    if (scalar @empty == scalar keys %data) {
        xt_logger->warn("No data in DHL response ".pp($response_xml));
        die { "X" => "Unable to get DHL shipment validate label data. No data returned" };
    }

    return \%data;
}

1;
