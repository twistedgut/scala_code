package XTracker::DHL::Manifest;
use strict;
use warnings;
use utf8;

use DateTime;
use HTML::HTMLDoc ();
use List::AllUtils qw/pairkeys pairvalues/;
use PDF::WebKit;
use Perl6::Export::Attrs;
use Net::SFTP;
use Net::FTP;
use MIME::Lite;
use DateTime;

use XTracker::Database qw/ get_schema_using_dbh /;
use XTracker::Database::Utilities;
use XTracker::Database::Shipment qw( :DEFAULT check_tax_included );
use XTracker::XTemplate;
use XTracker::Config::Local qw( config_var dhl_express_ftp manifest_level manifest_countries );
use XTracker::Constants::FromDB qw(
    :carrier
    :distrib_centre
    :manifest_status
    :shipment_item_status
    :shipment_status
    :shipment_type
);
use XTracker::EmailFunctions;
use XTracker::Database::Currency      qw( get_currency_by_id );
use XTracker::Logfile qw(xt_logger);
use XTracker::Error;
use XTracker::DBEncode qw( decode_db encode_it );
use XTracker::ShippingGoodsDescription qw( description_of_goods );

use XT::Rules::Solve;

use NAP::ShippingOption;

use feature ':5.14';

sub generate_manifest_files :Export() {
    my ($schema, $args )= @_;
    my $dbh = $schema->storage->dbh;

    # get local currency
    my $local_currency_code = config_var('Currency', 'local_currency_code');

    # now start creating the manifest file
    # get shipment data for manifest
    my $shipment_data = get_manifest_shipment_data( $dbh, {
        carrier_id  => $args->{carrier_id},
        cut_off     => $args->{cut_off},
        channel_ids => $args->{channel_ids},
    });

    # to hold the box weights for carriers, currently only used for UPS
    my $carrier_service_box_weights;
    if ( $args->{carrier_id} == $CARRIER__UPS ){
        # get the box weights for UPS carrier
        $carrier_service_box_weights = _get_carrier_box_weights( $dbh, $args->{carrier_id} );
    }

    # pre-process shipment data for manifest format
    foreach my $shipment_id (keys %{$shipment_data}) {
        my $shipment = $shipment_data->{$shipment_id};

        # set currency code for shipment value
        # EN-1986: Get the currency code for the Order's Currency
        $shipment->{currency}    = get_currency_by_id( $dbh, $shipment->{currency_id} );

        # tidy up name and address fields
        #

        $shipment->{customer_name} = $shipment->{first_name} ." ".$shipment->{last_name};

        transform_shipment_fields($shipment);

        # work out product code to use
        my $shipment_row = $schema->resultset('Public::Shipment')->find( $shipment_id );
        my $voucher_shipment_only = $shipment_row->is_voucher_only;
        my $shipping_option = NAP::ShippingOption->new_from_query_hash({
            %$shipment,
            is_voucher_only => $voucher_shipment_only,
        });
        $shipment->{product_code} = $shipping_option->code;

        # Generate description text for PDF and text, which each need different lengths
        my $hs_codes = $shipment_row->hs_codes;
        my $has_hazmat = $shipment_row->has_hazmat_items;
        # This is used in the manifest pdf
        $shipment->{description_of_goods} =
            description_of_goods({ hs_codes => $hs_codes,
                                   docs_only => $voucher_shipment_only,
                                   hazmat => $has_hazmat,
                                   line_len => 300 });
        # This is what we send DHL
        $shipment->{description_of_goods_txt} =
            description_of_goods({ hs_codes => $hs_codes,
                                   docs_only => $voucher_shipment_only,
                                   hazmat => $has_hazmat,
                                   line_len => 30 });

        # to hold the box weights for a particular service for UPS shipments
        my $carrier_box_weights;

        # work out UPS service type and profile
        # strip out commas from all fields
        if ( $args->{carrier_id} == $CARRIER__UPS ) {
            $shipment->{bill_transportation} = 'Shipper';
            $shipment->{ups_account} = $shipment->{account_number};

            # Domestic US shipments
            if ( $shipment->{country_code} eq 'US' ) {
                $shipment->{bill_tax_duty} = 'Shipper';

                $shipment->{ups_service}
                    = $shipment->{shipping_charge_class} eq 'Air'
                    ? 'Next Day Air Saver'
                    : 'Ground';

                my %ups_channel_map = (
                    'NET-A-PORTER.COM' => 'Domestic N.A.P.',
                    'theOutnet.com'    => 'Domestic Outnet',
                    'MRPORTER.COM'     => 'Domestic MRP',
                    'JIMMYCHOO.COM'    => 'Domestic JC',
                );
                $shipment->{ups_profile_name}
                    = $ups_channel_map{$shipment->{sales_channel}} || 'DEFAULT';
            }
            # international shipments
            else {
                # Just warn, don't let this one bad shipment fail
                # the whole Manifest
                xt_warn("Only Domestic shipments are supported for UPS. The shipment ($shipment_id) to ($shipment->{country_code}) in the Manifest is suspect.");
            }

            # get the box weights for a particular service
            # We can only get the weights if we have a value for $shipment->{ups_service}
            if ( exists $shipment->{ups_service} && $shipment->{ups_service} ) {
                $carrier_box_weights = $carrier_service_box_weights->{ $shipment->{ups_service} };
            }
            else {
                $carrier_box_weights = undef;
            }

            $shipment->{$_} =~ s/,//g for (qw<
                first_name
                last_name
                address_line_1
                address_line_2
                towncity
                county
                postcode
                telephone
                description_of_goods
                description_of_goods_txt
            >);
        }

        # number of boxes in shipment
        $shipment->{num_boxes} = 0;

        # total volume of shipment
        $shipment->{total_volume} = 0;

        # total volumetric weight of shipment
        $shipment->{total_volumetric_weight} = 0;
        # zero total carrier weight for UPS shipments
        $shipment->{total_weight_for_carrier} = 0 if ( $args->{carrier_id} == $CARRIER__UPS );

        foreach my $box_id (keys %{$shipment->{boxes}}) {
            my $box = $shipment->{boxes}->{$box_id};
            $shipment->{num_boxes}++;
            $shipment->{total_volume} += (
                    $box->{length}
                * $box->{width}
                * $box->{height}
            );
            $shipment->{total_volumetric_weight} += $box->{volumetric_weight};
            $shipment->{total_weight}            += $box->{weight};

            # work out weight for the shipment for UPS only (at the moment)
            if ( $args->{carrier_id} == $CARRIER__UPS ) {
                my $box_row = $shipment->{boxes}{$box_id};

                # get the carrier's weight for a box
                my $carrier_box_weight = $carrier_box_weights->{ $box_row->{box_id} }{weight} || 0;

                if ( $carrier_box_weight > 0 ) {
                    # work out which is greater the real weight for the box or
                    # the carriers minimum weight for a box
                    $shipment->{total_weight_for_carrier} += ( $carrier_box_weight > $box_row->{contents_and_box_weight} ? $carrier_box_weight : $box_row->{contents_and_box_weight} );
                }
                else {
                    $shipment->{total_weight_for_carrier} += $box_row->{contents_and_box_weight};
                }
            }
        }

    }

    my $manifest_data = {
        manifest_id   => $args->{manifest_id},
        filename      => $args->{filename},
        shipment_data => $shipment_data,
    };
    SMARTMATCH: {
        use experimental 'smartmatch';
        given (
            XT::Rules::Solve->solve(
                'Carrier::manifest_format' => { carrier_id => $args->{carrier_id} },
            )
        ) {
            when ( 'csv' ) { _write_csv_manifest($dbh, $manifest_data); }
            when ( 'dhl' ) { _write_dhl_express_manifest($dbh, $manifest_data ); }
            default { die "Unexpected carrier_id passed ($_): ".$args->{carrier_id}; }
        }
    }

    # Also write manifest to a PDF doc for printing and viewing in browser
    write_manifest_pdf( $args->{filename}, $shipment_data );
}



# See docs-specifications repo for details (currently the file sits in
# (https://gitosis/cgit/docs-specifications/tree/backend/DHL/MIG_FFTIN_Document_ver3_0.pdf)
sub _write_dhl_express_manifest {
    my ( $dbh, $args ) = @_;


    # prepare shipment manifest log entry for use in the loop later
    my $sm_qry = "INSERT INTO link_manifest__shipment VALUES (?, ?)";
    my $sm_sth = $dbh->prepare($sm_qry);

    xt_logger->debug(
        "DCS-1280 :: Perl ORS value delimited by the arrows->".( $\ // q{} )."<-",
    );
    local $\ = '';
    # open manifest text file and set encoding to iso-8859-1 (latin-1)
    # This is deliberately set to Latin-1 and NOT UTf-8.
    # Do not change this to UTF-8 without confirming that DHL accept UTF-8 data
    # and if you do that remove the call to _strip_to_latin1
    open my $mt_fh, ">:encoding(iso-8859-1)", config_var('SystemPaths','manifest_txt_dir')."/".$args->{filename}.".txt"
        || die "Couldn't open ".$args->{filename}.": $!";

    # write header record to manifest file
    print $mt_fh sprintf(
        "%-2.2s%-1.1s%-3.3s%-10.10s%-35.35s%-35.35s\n",
        "FF",         # %-2.2s
        "0",          # %-1.1s
        "HDR",        # %-3.3s
        "FFTIN00300", # %-10.10s
        "NETAPORTER", # %-35.35s
        "DHLEUAPGW",  # %-35.35s
    );


    # write shipments to manifest file
    my $time_zone = config_var("DistributionCentre", "timezone");
    my $today_date = DateTime->now(time_zone => $time_zone)->ymd("");

    my $schema = get_schema_using_dbh( $dbh, "xtracker_schema" );
    my $shipment_data = $args->{shipment_data};

    # Grab all the shipments before we start
    my @shipment_rows = $schema->resultset('Public::Shipment')->search({
        id => [keys %$shipment_data]
    });

    foreach my $shipment_row (@shipment_rows) {
        my $shipment_id = $shipment_row->id();

        # copy the hash to avoid having bad side effects elsewhere
        my $shipment = \%{$shipment_data->{$shipment_id}};

        # DHL custom format compliance tweaks
        # these are mandatory lines cannot be empty strings - apparently
        # ok to have a dot instead
        my @faux_mandatory_fields = qw/
            address_line_1
            address_line_2
            customer_name
            towncity postcode
        /;
        foreach my $field (@faux_mandatory_fields) {
            $shipment->{$field} = ensure_faux_mandatory_value($shipment->{$field});
        }

        my $from_address_data = $shipment_row->get_from_address_data();

        # Note that the order *is* important here!
        my @fields = (
            "FF"                                             => '%-2.2s',
            "0"                                              => '%-1.1s',
            "SHP"                                            => '%-3.3s',
            "2"                                              => '%-1.1s',
            $shipment->{account_number}                      => '%-14.14s',
            $shipment->{outward_airway_bill}                 => '%-10.10s',
            $shipment->{destination_code}                    => '%-3.3s',
            $shipment->{order_nr}                            => '%-35.35s',
            uc($from_address_data->{from_company})           => '%-35.35s',
            ""                                               => '%-35.35s',
            uc($from_address_data->{from_addr1})             => '%-35.35s',
            uc($from_address_data->{from_addr2})             => '%-35.35s',
            uc($from_address_data->{from_addr3})             => '%-35.35s',
            uc($from_address_data->{from_city})              => '%-20.20s', # Shipper City Name
            ""                                               => '%-45.45s', # Shipper District/Province
            (uc($from_address_data->{from_postcode})||'NIL') => '%-12.12s',
            ""                                               => '%-20.20s',
            ""                                               => '%-20.20s',
            uc($from_address_data->{'from_alpha-2'})         => '%-3.3s',
            "A"                                              => '%-1.1s',
            ""                                               => '%-14.14s',
            $shipment->{customer_name}                       => '%-35.35s', # (mandatory)
            ""                                               => '%-35.35s',
            # The consignee address may look like a strange mapping but
            # according to DHL this mapping is fine given our address is just
            # marked as line 1, 2, 3 etc
            ""                                               => '%-35.35s', # (23) - Consignee building name
            $shipment->{address_line_1}                      => '%-35.35s', # (mandatory) - Consignee street name
            $shipment->{address_line_2}                      => '%-35.35s', # (mandatory) - Consignee street number
            $shipment->{towncity}                            => '%-20.20s', # (mandatory) - Consignee City Name (Shipping Address City)
            $shipment->{county}                              => '%-45.45s', # Consignee District/Province
            $shipment->{postcode}                            => '%-12.12s', # (mandatory) (28)
            $shipment->{telephone}                           => '%-20.20s',
            ""                                               => '%-20.20s',
            $shipment->{country_code}                        => '%-3.3s', # Consignee country code
            "A"                                              => '%-1.1s', # Country code qualifier
            $shipment->{product_code}                        => '%-3.3s', # DHL product content code
            $shipment->{num_boxes}                           => '%4.0f',
            $shipment->{total_weight}                        => '%10.2f',
            "KGM"                                            => '%-3.3s',
            "0"                                              => '%-1.1s',
            $shipment->{total_volume}                        => '%10.2f',
            "CMQ"                                            => '%-3.3s',
            "0"                                              => '%-1.1s',
            $shipment->{total_value}                         => '%10.2f',
            $shipment->{currency}                            => '%-3.3s',
            "0"                                              => '%-1.1s',
            $shipment->{description_of_goods_txt}            => '%-30.30s',
            "P"                                              => '%-1.1s',
            ""                                               => '%-20.20s',
            "743796786"                                      => '%-35.35s',
            ""                                               => '%-35.35s',
            $today_date                                      => '%-8.8s', # Pickup date
            ""                                               => '%-10.10s', # Parent shipment ID (Break Bulk)
        );
        say $mt_fh sprintf join( q{}, pairvalues @fields), pairkeys @fields;

        # Service record for saturday delivery, maybe
        if( $shipment_row->is_saturday_nominated_delivery_date ) {
            say $mt_fh "FF0SRV050";
        }

        # loop through shipment boxes and write piece line
        foreach my $box_id (keys %{$shipment->{boxes}}) {
            my $box = $shipment->{boxes}->{$box_id};

            # write common box data at start of each line
            print $mt_fh "FF0PCE";

            # DCS-1210: Renamed field 'licence_plate_number' to 'tracking_number'
            # write box specific data
            my $tracking_number = $box->{tracking_number} // "";
            print $mt_fh sprintf(
                "%-35.35s%4.0f%4.0f%4.0f%-3.3s%-7.7s%-3.3s%-1.1s%-10.10s%-3.3s%-1.1s%-35.35s%-2.2s%-35.35s\n",
                $box_id,                # %-35.35s
                $box->{length},         # %4.0f
                $box->{width},          # %4.0f
                $box->{height},         # %4.0f
                "CMT",                  # %-3.3s
                "",                     # %-7.7s
                "",                     # %-3.3s
                "",                     # %-1.1s
                "",                     # %-10.10s
                "",                     # %-3.3s
                "",                     # %-1.1s
                "JD00$tracking_number", # %-35.35s - Piece ID (License Plate Number)
                "",                     # %-2.2s   - Type of Package
                "",                     # %-35.35s - Piece content description
            );
        }

        # log shipment as being included in manifest
        $sm_sth->execute($args->{manifest_id}, $shipment_id);

    }

    close $mt_fh;

    return;
}

# Ensure "faux mandatory" values aren't empty.
#
# Some values are unreasonably mandatory in the API, but DHL has
# recommended we fake it with "."
sub ensure_faux_mandatory_value {
    my ($value) = @_;
    $value //= "";

    $value =~ /\S/ and return $value;
    return ".";
}

sub _write_csv_manifest {
    my ( $dbh, $args ) = @_;

    my %field = (
        customer_id => {
            header => 'Customer ID',
            data => sub { shift->{customer_number} },
        },
        first_name => {
            header => 'First Name',
            data => sub { shift->{first_name} },
        },
        last_name => {
            header => 'Last Name',
            data => sub { shift->{last_name} },
        },
        address_1 => {
            header => 'Address 1',
            data => sub { shift->{address_line_1} },
        },
        address_2 => {
            header => 'Address 2',
            data => sub { shift->{address_line_2} },
        },
        address_3 => {
            header => 'Address 3',
            data => sub { q{} },
        },
        towncity => {
            header => 'City/Town',
            data => sub { shift->{towncity} },
        },
        state => {
            header => 'State',
            data => sub { shift->{county} },
        },
        postcode => {
            header => 'Postal Code',
            data => sub { shift->{postcode} },
        },
        country => {
            header => 'Country',
            data => sub { shift->{country_code} },
        },
        telephone => {
            header => 'Telephone',
            data => sub { shift->{telephone} },
        },
        address_validation_status => {
            header => 'Address Validation Status',
            data => sub { 'Not Validated' },
        },
        address_validation_date => {
            header => 'Address Validation Date',
            data => sub { q{} },
        },
        profile_name => {
            header => 'Profile Name',
            data => sub { shift->{ups_profile_name} },
        },
        reference_1_qualifier => {
            header => 'Reference 1 qualifier',
            data => sub { shift->{order_nr} },
        },
        reference_2_qualifier => {
            header => 'Reference 2 qualifier',
            data => sub { shift->{ups_account} },
        },
        reference_1_use_all => {
            header => 'Reference 1 use all',
            data => sub { q{Y} },
        },
        reference_2_use_all => {
            header => 'Reference 2 use all',
            data => sub { q{Y} },
        },
        ups_service => {
            header => 'UPS Service',
            data => sub { shift->{ups_service} },
        },
        description => {
            header => 'General Description of Goods',
            data => sub { 'apparel' },
        },
        box_size => {
            header => 'Package Type',
            # only room for one size so mutiple boxes just take one randomly
            data => sub { (values %{shift->{boxes}})[0]{box_size} },
        },
        shipper_number => {
            header => 'Shipper Number',
            data => sub { shift->{shipper_number} },
        },
        is_signature_required => {
            header => 'Delivery Confirmation Signature Required',
            data => sub { shift->{is_signature_required} ? q{Y} : q{N} },
        },
        full_name => {
            header => 'Company or Name',
            data => sub { join q{ }, $_[0]->{first_name}, $_[0]->{last_name} },
        },
        residential_indicator => {
            header => 'Residential Indicator',
            data => sub { q{Y} },
        },
        reference_3_qualifier => {
            header => 'Reference 3 qualifier',
            data => sub { shift->{id} },
        },
        reference_3_use_all => {
            header => 'Reference 3 use all',
            data => sub { q{Y} },
        },
        bill_transportation => {
            header => 'Bill Transportation To',
            data => sub { shift->{bill_transportation} },
        },
        bill_tax_duty => {
            header => 'Bill Duty and Tax To',
            data => sub { shift->{bill_tax_duty} },
        },
        weight => {
            header => 'Weight',
            data => sub { sprintf("%d", ( shift->{total_weight_for_carrier} || 0 )) },
        },
    );
    # Quickly summing up some DC2 DHL Express rules we discussed with Nuno -
    # currently we are displaying exactly the columns with the same rules as
    # UPS. However:
    # address_validation_status - N/A for DHL Express
    # address_validation_date   - N/A for DHL Express
    # ups_service               - should be DHL Express but will be ignored
    #                             anyway, so leaving as is
    # is_signature_required     - DHL Express will never require a signature,
    #                             so meaningless - but leave as is for the moment
    # residential_indicator     - N/A for DHL Express
    my @field_order = (qw<
        customer_id
        first_name
        last_name
        address_1
        address_2
        address_3
        towncity
        state
        postcode
        country
        telephone
        address_validation_status
        address_validation_date
        profile_name
        reference_1_qualifier
        reference_2_qualifier
        reference_1_use_all
        reference_2_use_all
        ups_service
        description
        box_size
        shipper_number
        is_signature_required
        full_name
        residential_indicator
        reference_3_qualifier
        reference_3_use_all
        bill_transportation
        bill_tax_duty
        weight
    >);

    # Make sure all entries in order array exist in field definition
    for (@field_order) {
        die "Could not find definition for field $_" unless exists $field{$_};
    }

    my $sm_qry = "INSERT INTO link_manifest__shipment VALUES (?, ?)";
    my $sm_sth = $dbh->prepare($sm_qry);

    # open manifest text file
    open my $MT_FH, ">encoding(iso-8859-1)", config_var('SystemPaths','manifest_txt_dir')."/".$args->{filename}.".csv"
        || die "Couldn't open ".$args->{filename}.": $!";

    # write header record to manifest file
    print $MT_FH join( q{,}, map { $field{$_}{header} } @field_order ), qq{\r\n};

    # write shipments to manifest file
    foreach my $shipment_id (keys %{$args->{shipment_data}}) {
        my $shipment = $args->{shipment_data}{$shipment_id};
        print $MT_FH
            join( q{,}, map { $field{$_}{data}($shipment) // q{} } @field_order ),
            qq{\r\n};

        # log shipment as being included in manifest
        $sm_sth->execute($args->{manifest_id}, $shipment_id);
    }
    close $MT_FH;
    return;
}



sub write_manifest_pdf :Export() {
    my ( $filename, $pdf_data ) = @_;

    my $pdf_html;
    my $template_data;
    $template_data->{shipment_data} = $pdf_data;
    $template_data->{dc_name} = config_var('DistributionCentre', 'name');

    my $template = XTracker::XTemplate->template();
    $template->process( 'print/manifest_pdf.tt', { template_type => 'none', %$template_data }, \$pdf_html );

    my $header = 'N E T - A - P O R T E R . C O M';
    my $margin_unit = 'in';
    my %margins = (
        left => 0.03,
        right => 0.02,
        top => 0,
        bottom => 0.02,
    );
    my $pdf_file = config_var('SystemPaths', 'manifest_pdf_dir') .
                   "/$filename.pdf";

    if (config_var('Printing', 'use_webkit')) {
        my %print_options = (
            encoding => 'UTF-8',
            header_center => $header,
            footer_right => '[page]/[topage]',
            orientation => 'Landscape',
        );

        foreach my $m (keys %margins) {
            $print_options{"margin_$m"} = $margins{$m};
        }

        my $webkit = PDF::WebKit->new(\$pdf_html, %print_options);
        $webkit->to_file($pdf_file);
    }
    else {
        # write it to a file
        my $doc = HTML::HTMLDoc->new( mode => 'file', tmpdir => '/tmp' );
        $doc->landscape();

        $doc->set_header( '.', $header, '.' );
        $doc->set_footer( '.', '.', '/' );
        $doc->set_right_margin( $margins{right}, $margin_unit );
        $doc->set_left_margin( $margins{left}, $margin_unit );
        $doc->set_bottom_margin( $margins{bottom}, $margin_unit );
        $doc->set_top_margin( $margins{top}, $margin_unit );
        $doc->set_html_content($pdf_html);

        my $pdf = $doc->generate_pdf();

        $pdf->to_file($pdf_file);
    }
}

sub get_working_manifest_list :Export() {
    my ( $dbh ) = @_;

    my $qry = <<EOQ
SELECT m.id,
    m.cut_off AS cut_off,
    msl.date AS date_created,
    o.name AS creator,
    msl2.date AS date_sent,
    m.filename,
    m.status_id,
    ms.status,
    c.name as carrier,
    COUNT(lms.*) AS num_shipments
FROM manifest m
LEFT JOIN link_manifest__shipment lms ON m.id = lms.manifest_id
LEFT JOIN manifest_status_log msl2 ON m.id = msl2.manifest_id AND msl2.status_id = $PUBLIC_MANIFEST_STATUS__SENT
JOIN manifest_status ms ON m.status_id = ms.id
JOIN manifest_status_log msl ON m.id = msl.manifest_id
JOIN operator o ON msl.operator_id = o.id
JOIN carrier c ON m.carrier_id = c.id
WHERE m.status_id in (
    $PUBLIC_MANIFEST_STATUS__EXPORTING,
    $PUBLIC_MANIFEST_STATUS__EXPORTED,
    $PUBLIC_MANIFEST_STATUS__SENDING,
    $PUBLIC_MANIFEST_STATUS__SENT,
    $PUBLIC_MANIFEST_STATUS__IMPORTED,
    $PUBLIC_MANIFEST_STATUS__FAILED
)
AND msl.status_id = $PUBLIC_MANIFEST_STATUS__EXPORTING
GROUP BY m.id, m.cut_off, msl.date, msl2.date, m.filename, m.status_id, ms.status, c.name, o.name
ORDER BY msl.date DESC
EOQ
;
    return $dbh->selectall_arrayref($qry, { Slice => {} });
}

sub get_manifest_list :Export() {

    my ( $dbh, $args ) = @_;

    my %list = ();

    my $qry = "SELECT m.id, (to_char(msl.date, 'YYYYMMDDHH24MI') || m.id) as date_sort, to_char(m.cut_off, 'DD-MM-YYYY HH24:MI') as cut_off, to_char(msl.date, 'DD-MM-YYYY HH24:MI') as date_created, to_char(msl2.date, 'DD-MM-YYYY HH24:MI') as date_sent, m.filename, m.status_id, ms.status, c.name as carrier, count(lms.*) as num_shipments
                FROM manifest m LEFT JOIN link_manifest__shipment lms ON m.id = lms.manifest_id LEFT JOIN manifest_status_log msl2 ON m.id = msl2.manifest_id AND msl2.status_id = 4, manifest_status ms, manifest_status_log msl, carrier c
                WHERE m.status_id = ms.id
                AND m.id = msl.manifest_id
                AND msl.status_id = (select id from manifest_status where status = 'Exporting')
                AND m.carrier_id = c.id ";

    if ($args->{"type"} eq "date") {
        $qry .= "AND msl.date between '".$args->{"start"}."' and '".$args->{"end"}."'";
    }
    elsif ($args->{"type"} eq "shipment") {
        $qry .= "AND m.id IN (select manifest_id from link_manifest__shipment where shipment_id = ".$args->{"shipment_id"}.")";
    }

    $qry .= "GROUP BY m.id, m.cut_off, msl.date, msl2.date, m.filename, m.status_id, ms.status, c.name";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
           $list{ $row->{date_sort}} = $row;
    }

    return \%list;

}

=head2 get_manifest_shipment_data($dbh, {carrier_id!, :cut_off!, :channel_ids) : \%data

Return a structure with shipments that should be on the manifest for the given
arguments. If C<channel_ids> is passed it should be an arrayref of integers.

=cut

sub get_manifest_shipment_data :Export() {
    my ($dbh, $args)= @_;

    # get config settings for manifesting
    my $manifest_level = manifest_level();

    # make sure manifesting isn't switched off
    return {} if $manifest_level eq 'off';

    my $voucher_weight  = config_var( 'Voucher', 'weight' );

    # prepare shipment box sub query for use in the main loop
    # dcs-570: now includes the total weight for the contents of the box
    # and the combined weight of the contents and the box rounded to the
    # nearest whole number
    # DCS-1210: Renamed field 'licence_plate_number' to 'tracking_number'
    my $box_qry =<<BOX_QRY
SELECT  sb.id,
        sb.tracking_number,
        b.box AS box_size,
        b.length,
        b.width,
        b.height,
        b.weight,
        b.id AS box_id,
        b.volumetric_weight,
        SUM( CASE WHEN si.voucher_variant_id IS NOT NULL THEN $voucher_weight ELSE sa.weight END ) AS contents_weight,
        ROUND(SUM( CASE WHEN si.voucher_variant_id IS NOT NULL THEN $voucher_weight ELSE sa.weight END ) + b.weight) AS contents_and_box_weight
FROM    shipment_box sb
        JOIN shipment_item si ON si.shipment_box_id = sb.id
            LEFT JOIN variant v ON v.id = si.variant_id
                LEFT JOIN shipping_attribute sa ON sa.product_id = v.product_id
            LEFT JOIN voucher.variant vv ON vv.id = si.voucher_variant_id
                LEFT JOIN voucher.product vp ON vp.id = vv.voucher_product_id
        , box b
WHERE   sb.shipment_id = ?
AND     sb.box_id = b.id
AND     ( vp.is_physical = TRUE OR vp.is_physical IS NULL )
GROUP BY 1,2,3,4,5,6,7,8,9
BOX_QRY
;
    my $box_sth = $dbh->prepare($box_qry);


    # shipment data query
    my $ship_qry =<<SHIP_QRY
SELECT s.id,
       s.outward_airway_bill,
       s.destination_code,
       sac.account_number,
       sac.shipping_number AS shipper_number,
       sac.name AS shipping_account_name,
       cust.is_customer_number AS customer_number,
       oa.first_name,
       oa.last_name,
       oa.address_line_1,
       oa.address_line_2,
       oa.towncity,
       oa.county,
       oa.country,
       oa.postcode,
       c.code AS country_code,
       st.type AS shipment_type,
       s.telephone,
       s.mobile_telephone,
       sr.sub_region,
       o.order_nr,
       o.currency_id,
       ch.name AS sales_channel,
       schc.class AS shipping_charge_class,
       s.signature_required,
       COALESCE( s.signature_required, TRUE ) AS is_signature_required,
       SUM( CASE
                WHEN si.voucher_variant_id IS NOT NULL
                    THEN $voucher_weight
                ELSE sa.weight
            END ) AS total_weight,
       (s.shipping_charge + SUM( CASE
                                    WHEN si.unit_price = 0
                                        THEN 1
                                    WHEN si.voucher_variant_id IS NOT NULL
                                        THEN 1
                                    ELSE si.unit_price
                                 END )) AS total_value,
       SUM( CASE
                WHEN si.voucher_variant_id IS NOT NULL
                    THEN 0
                ELSE si.tax
            END ) AS total_tax
FROM    shipment s
LEFT JOIN link_manifest__shipment lms
    JOIN manifest man ON lms.manifest_id = man.id AND man.status_id != $PUBLIC_MANIFEST_STATUS__CANCELLED
    ON s.id = lms.shipment_id
JOIN shipment_type st ON s.shipment_type_id = st.id
JOIN shipping_account sac ON s.shipping_account_id = sac.id
JOIN carrier car ON sac.carrier_id = car.id
JOIN order_address oa ON s.shipment_address_id = oa.id
JOIN country c ON oa.country = c.country
JOIN sub_region sr ON c.sub_region_id = sr.id
JOIN link_orders__shipment los ON s.id = los.shipment_id
JOIN orders o ON los.orders_id = o.id
JOIN channel ch ON o.channel_id = ch.id
JOIN customer cust ON o.customer_id = cust.id
JOIN shipment_item si ON s.id = si.shipment_id
LEFT JOIN variant v ON v.id = si.variant_id
    LEFT JOIN shipping_attribute sa ON sa.product_id = v.product_id
LEFT JOIN voucher.variant vv ON vv.id = si.voucher_variant_id
    LEFT JOIN voucher.product vp ON vp.id = vv.voucher_product_id
JOIN shipment_item_status_log sisl ON si.id = sisl.shipment_item_id
JOIN shipping_charge sch ON s.shipping_charge_id = sch.id
JOIN shipping_charge_class schc ON sch.class_id = schc.id
LEFT JOIN (
    SELECT  xsi.shipment_id
    FROM    shipment_item xsi
    WHERE   xsi.voucher_variant_id IS NOT NULL
    AND     ( xsi.voucher_code_id IS NULL OR xsi.shipment_item_status_id IN ( $SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED, $SHIPMENT_ITEM_STATUS__PICKED ) )
) xsi ON s.id = xsi.shipment_id
-- outbound airwaybill needs to be assigned for DHL Express shipments in DC1
WHERE   ( s.outward_airway_bill != 'none' OR sac.carrier_id = $CARRIER__UPS OR (sac.carrier_id = $CARRIER__DHL_EXPRESS AND ch.distrib_centre_id = $DISTRIB_CENTRE__DC2) )
AND     s.shipment_status_id = $SHIPMENT_STATUS__PROCESSING -- not on hold or cancelled
-- valid destination code assigned for DHL in DC1
AND     ( sac.carrier_id = $CARRIER__UPS OR (s.destination_code is not null AND s.destination_code != '') OR (sac.carrier_id = $CARRIER__DHL_EXPRESS AND ch.distrib_centre_id = $DISTRIB_CENTRE__DC2) )
AND     man.id IS NULL -- shipment not already assigned to a manifest
AND     s.real_time_carrier_booking = FALSE  -- DCS-1210: make sure 'rtcb' field is false and therfore shipment is NOT Automated
AND     s.shipment_type_id != $SHIPMENT_TYPE__PREMIER -- DHL deliveries only
AND     sac.carrier_id = ?  -- shipments assigned to correct carrier only
AND     ( vp.is_physical = TRUE OR vp.is_physical IS NULL )
AND     si.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED  -- include packed items only
AND     si.shipment_box_id is not null  -- box has to be assigned to all items
AND     sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED
AND     sisl.date < ?  -- shipment packed before cut off time
AND     xsi.shipment_id IS NULL
%s
GROUP BY    s.id,
            s.outward_airway_bill,
            s.destination_code,
            sac.account_number,
            sac.shipping_number,
            sac.name,
            s.shipping_charge,
            cust.is_customer_number,
            oa.first_name,
            oa.last_name,
            oa.address_line_1,
            oa.address_line_2,
            oa.towncity,
            oa.county,
            oa.country,
            oa.postcode,
            c.code,
            st.type,
            s.telephone,
            s.mobile_telephone,
            sr.sub_region,
            o.order_nr,
            o.currency_id,
            ch.name,
            schc.class,
            s.signature_required,
            is_signature_required
SHIP_QRY
;

    # Filter by channel_ids if we've passed any
    my @channel_ids =  @{ $args->{channel_ids} // [] };

    $ship_qry = sprintf( $ship_qry,
        @channel_ids
      ? sprintf('AND o.channel_id IN (%s)', join q{, }, (q{?}) x @channel_ids)
      : q{}
    );
    my $ship_sth = $dbh->prepare($ship_qry);

    $ship_sth->execute($args->{carrier_id}, $args->{cut_off}, @channel_ids);

    my $manifest_countries = manifest_countries();
    my %data = ();
    while ( my $row = $ship_sth->fetchrow_hashref() ) {
        next unless _filter_manifest_shipments($row);
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
            address_line_1
            address_line_2
            towncity
            county
            postcode
            country
        ));

        # check if manifesting is set to 'full'
        # or
        # if 'partial' make sure shipping country is switched on

        if ($manifest_level eq 'full' || ($manifest_level eq 'partial' && (grep { /\b$$row{country}\b/ } @{$manifest_countries}) )) {

            $data{ $row->{id} } = $row;

            # include tax in shipment value if required
            if ( check_tax_included( $dbh, $row->{country} ) ) {
                $row->{total_value} += $row->{total_tax};
            }

            # gather shipment box data
            $box_sth->execute( $row->{id} );

            while ( my $box_row = $box_sth->fetchrow_hashref() ) {
                $data{ $row->{id} }{boxes}{ $box_row->{id} } = $box_row;
            }
        }
    }

    return \%data;

}

# This has no function in production, but will be mocked in test to ensure
# we're only acting on a subset of data
sub _filter_manifest_shipments {
    my ($row) = @_;
    return 1;
}

sub get_manifest :Export() {

    my ( $dbh, $id ) = @_;

    my $qry = "SELECT m.id, m.carrier_id, m.filename, to_char(m.cut_off, 'DD-MM-YYYY HH24:MM') as cut_off, m.status_id, ms.status, c.name as carrier, count(lms.*) as num_shipments
                FROM manifest m LEFT JOIN link_manifest__shipment lms ON m.id = lms.manifest_id, manifest_status ms, carrier c
                WHERE m.id = ?
                AND m.status_id = ms.id
                AND m.carrier_id = c.id
                GROUP BY m.id, m.carrier_id, m.filename, m.cut_off, m.status_id, ms.status, c.name";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    my $row = $sth->fetchrow_hashref();

    return $row;

}

sub get_manifest_status_log :Export() {

    my ( $dbh, $id ) = @_;

    my %data = ();

    my $qry = "SELECT msl.id, to_char(msl.date, 'DD-MM-YYYY') as date, to_char(msl.date, 'HH24:MI') as time, op.name, ms.status
                FROM manifest_status_log msl, manifest_status ms, operator op
                WHERE msl.manifest_id = ?
                AND msl.status_id = ms.id
                AND msl.operator_id = op.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    while ( my $row = $sth->fetchrow_hashref() ) {
           $data{ $$row{id}} = $row;
    }

    return \%data;

}


sub update_manifest_status :Export() {

    my ($dbh, $id, $status, $operator_id)= @_;

    # update status
    my $qry = "UPDATE manifest SET status_id = (SELECT id FROM manifest_status WHERE status = ?) WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($status, $id);

    # log it
    log_manifest_status($dbh, $id, $status, $operator_id);

}

sub log_manifest_status :Export() {

    my ($dbh, $id, $status, $operator_id)= @_;

    my $qry = "INSERT INTO manifest_status_log VALUES (default, ?,(SELECT id FROM manifest_status WHERE status = ?), ?, current_timestamp)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id, $status, $operator_id);
}


sub update_manifest_filename :Export() {

    my ($dbh, $id, $filename)= @_;

    my $qry = "UPDATE manifest SET filename = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($filename, $id);

    return;

}


sub get_manifest_shipment_list :Export() {

    my ( $dbh, $manifest_id ) = @_;

    my %list = ();

    my $qry
        = "SELECT s.id as shipment_id, ss.status, to_char(s.date, 'DD-MM-YYYY HH24:MI') as shipment_date, oa.country, o.id as order_id, o.order_nr, oa.first_name, oa.last_name, ch.name as sales_channel
                FROM link_manifest__shipment lms, shipment s, shipment_status ss, link_orders__shipment los, order_address oa, orders o, channel ch
                WHERE lms.manifest_id = ?
                AND lms.shipment_id = s.id
                AND s.id = los.shipment_id
                AND s.shipment_address_id = oa.id
                AND s.shipment_status_id = ss.id
                AND los.orders_id = o.id
                AND o.channel_id = ch.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($manifest_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
            country
        ));
        $list{ $row->{shipment_id}} = $row;
    }

    return \%list;

}

sub create_transaction_lock_on_manifest :Export() {

    my ( $dbh, $manifest_id ) = @_;

    my $qry = "SELECT id FROM manifest WHERE id = ? FOR UPDATE NOWAIT";
    my $sth = $dbh->prepare($qry);
    $sth->execute($manifest_id);

    return;
}

# Subroutine   : _get_carrier_box_weights                                      #
# usage        : $hash_ptr = _get_carrier_box_weights(                         #
#                       $dbh,                                                  #
#                       $carrier_id                                            #
#                   );                                                         #
# description  : This returns all the box weights for a particular carrier     #
#                into a hash of hashes with the service name as the primary    #
#                key and the box id as the secondary key.                      #
# parameters   : A Database Handle, A Carrier Id.                              #
# returns      : A pointer to a hash containing the weights.                   #

sub _get_carrier_box_weights {
    my ( $dbh, $carrier_id )    = @_;

    my $sql     = "";
    my %box_weights;

    $sql    =<<SQL
SELECT  *
FROM    carrier_box_weight
WHERE   carrier_id = ?
SQL
;
    my $sth = $dbh->prepare($sql);
    $sth->execute($carrier_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $box_weights{ $row->{service_name} }{ $row->{box_id} }  = $row;
    }

    return \%box_weights;
}

sub _strip_to_latin1 {
    my $string = shift;
    $string =~ s/[^\p{InBasicLatin}\p{InLatin1Supplement}]/?/g;
    return $string;
}

=head2 transform_shipment_fields( \%shipment_info ) :

Truncate and transform all relevant shipment fields for the manifest.

=cut

sub transform_shipment_fields {
    my ( $shipment ) = @_;

    # Replace any characters outside ASCII and Latin-1
    foreach my $field ( qw( customer_name
                            first_name
                            last_name
                            address_line_1
                            address_line_2
                            towncity
                            county
                            postcode)) {
        $shipment->{$field} = _strip_to_latin1(uc $shipment->{$field});
    }

    my $max_length = {
        customer_name  => 35,
        address_line_1 => 35,
        address_line_2 => 35,
        towncity       => 20,
        postcode       => 12,
    };
    # customer name greater than allowed field length of 35 chars - need to tidy it up
    if (length($shipment->{customer_name}) > $max_length->{customer_name}){

        my $initial = substr($shipment->{first_name}, 0, 1);

        $shipment->{customer_name} = $initial ." ".$shipment->{last_name};

        # customer name still to long - just have to chop it off to 35 chars
        if (length($shipment->{customer_name}) > $max_length->{customer_name}){
            $shipment->{customer_name} = substr($shipment->{customer_name}, 0, $max_length->{customer_name});
        }
    }

    # address lines can't be longer than 35 chars

    # first address line is too long
    if (length($shipment->{address_line_1}) > $max_length->{address_line_1}){

        # if nothing in address line 2 use that for the extra data
        if (!$shipment->{address_line_2}) {
            $shipment->{address_line_2} = substr(
                $shipment->{address_line_1},
                $max_length->{address_line_1},
                length($shipment->{address_line_1})
            );
            $shipment->{address_line_1} = substr(
                $shipment->{address_line_1}, 0, $max_length->{address_line_1}
            );
        }
        # second address line in use - we'll just have to lose it
        else {
            $shipment->{address_line_1} = substr(
                $shipment->{address_line_1}, 0, $max_length->{address_line_1}
            );
        }
    }

    # make sure second address line not more than 35 chars
    $shipment->{address_line_2} = substr(
        $shipment->{address_line_2}, 0, $max_length->{address_line_2}
    );

    # city no longer than 20 chars
    $shipment->{towncity} = substr($shipment->{towncity}, 0, $max_length->{towncity});

    # zip code cannot contain any spaces or non-alphanumeric characters - and only max 12 chars long
    $shipment->{postcode} =~ s/[^\w\s]//g;
    $shipment->{postcode} = substr($shipment->{postcode}, 0, $max_length->{postcode});

    # WHM-2612 - the mobile phone number is used in the first instance
    $shipment->{telephone} = $shipment->{mobile_telephone} if $shipment->{mobile_telephone};

    # final check to remove all reserved characters - would cause import to fail
    $shipment->{customer_name}  =~ s/[`\n\r!"%&*;<>]//g;
    $shipment->{address_line_1} =~ s/[`\n\r!"%&*;<>]//g;
    $shipment->{address_line_2} =~ s/[`\n\r!"%&*;<>]//g;
    $shipment->{towncity}       =~ s/[`\n\r!"%&*;<>]//g;
    $shipment->{postcode}       =~ s/[`\n\r!"%&*;<>]//g;
}

1;
