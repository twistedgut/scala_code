#!/usr/bin/env perl
## no critic(ProhibitExcessMainComplexity,ProhibitDeepNests,ProhibitUselessNoCritic)
use NAP::policy "tt", 'test';

=head1 NAME

shipping_docs.t

=head1 DESCRIPTION

Tests some of the contents of various shipping documents:

    * Invoice
    * Shipping Input Form
    * Outward Proforma
    * Return Proforma
    * DHL Label

#TAGS fulfilment packing ups dhl printer loops checkruncondition xpath whm

=cut

use FindBin::libs;

use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw(
    :shipment_item_returnable_state
    :shipment_item_status
    :shipment_status
    :shipment_type
    :sub_region
);

use Test::MockModule;
use Test::XTracker::Data;
use Test::XTracker::Data::Country;
use Test::XTracker::Hacks::isaFunction;
use Test::XTracker::Mechanize;
use Test::XTracker::Mock::Handler;
use Test::XTracker::Mock::DHL::XMLRequest;

use XT::Data::DateStamp;
use XTracker::Config::Local         qw( config_var get_shipping_printers );

use XTracker::Database::Address;
use XTracker::Database::Currency    qw( get_local_conversion_rate );
use XTracker::Database::Order;
use XTracker::Database::OrderPayment;
use XTracker::Database::Profile     qw( get_operator_preferences );
use XTracker::Database::Shipment    qw(get_shipment_documents);
use XTracker::Order::Fulfilment::PackShipment;
use XTracker::Order::Functions::Order::OrderView;
use XTracker::Printers;

use Test::XTracker::PrintDocs;

use Data::Dump  qw( pp );
use URI::file;


use Test::More::Prefix qw/ test_prefix /;

BEGIN {
    use_ok('XTracker::Database::Shipment', qw( :DEFAULT :carrier_automation check_tax_included ));
    use_ok('XTracker::Order::Printing::ShipmentDocuments', qw( print_shipment_documents ));
    use_ok('XTracker::Order::Printing::ShippingInputForm', qw( generate_input_form ));
    use_ok('Test::XTracker::Data::MarketingPromotion');
    use_ok('XTracker::Order::Actions::UpdateShipmentAirwaybill');
    can_ok( 'Test::XTracker::Data::MarketingPromotion', qw(
        create_marketing_promotion
        create_link
        delete_all_promotions_by_channel
    ) );

}
my $input_row_xpath=q{//table[.//tr/td = 'DESCRIPTION']//tr[td='%s']/td};
my $outpro_row_xpath=q{//table[.//tr/td = 'UNIT TYPE']//tr[td=~'PID: %s\s*$']/td};
my $retpro_row_xpath=q{//table[.//tr/td = 'TICK']//tr[td=~'\(%s\)']/td};

# make DB connections

my $schema  = Test::XTracker::Data->get_schema;
isa_ok($schema, 'XTracker::Schema',"Schema Created");
my $dbh     = $schema->storage->dbh;

# get enabled channels
my $channel_rs = Test::XTracker::Data->get_enabled_channels();
my $channel_id = Test::XTracker::Data->channel_for_nap->id;

# want a fulfilment only channel, if there is one
my $channel = $channel_rs->fulfilment_only(1)->single();
my $fulfilment_channel_id = $channel ? $channel->id : 0;

my $dc_name = config_var('DistributionCentre','name');

#---- TEST FUNCTIONS ------------------------------------------

# This tests some of the contents of various shipping documents:
#   Invoice
#   Shipping Input Form
#   Outward Proforma
#   Return Proforma
#   DHL Label

my $ps = $schema->resultset('SystemConfig::ConfigGroup')->search({ name => { 'ilike' => 'PackingStation_%' } })->first;
my $ps_name = ( $ps ? $ps->name : '' );

my $outpro_ctry = Test::XTracker::Data::Country->proforma_countries->search(
    {
        sub_region_id => { '!=' => $SUB_REGION__EU_MEMBER_STATES },     # outside of the EU
        'country_tax_rate.country_id'   => undef,       # don't want a Taxable Country
    },
    { join    => 'country_tax_rate', }
)->first->country;

# set-up a hash of the different ways that updating airway bills and
# printing shipping documents can be printed
my @test_methods = ( 'airwaybill' );
push @test_methods, 'labelling' unless $dc_name eq "DC2";

my %create_orders   = (
        'Normal + Vouchers' => {
                country    => $outpro_ctry,
                normal_pid => 1,
                phys_vouch => 1,
                virt_vouch => 1,
                gift_message => 'Gift message test',
            },
        'Normal + CC_only' => {
                country    => $outpro_ctry,
                normal_pid => 1,
                cc_only_pid => 1,
                gift_message => 'Gift message test',
            },
        'CC_only + Vouchers' => {
                country    => $outpro_ctry,
                cc_only_pid => 1,
                phys_vouch => 1,
                virt_vouch => 1,
                gift_message => 'Gift message test',
            },
       'CC_only' => {
                country    => $outpro_ctry,
                cc_only_pid => 1,
                gift_message => 'Gift message test',
            },
        'Vouchers Only'     => {
                country    => $outpro_ctry,
                phys_vouch => 1,
                virt_vouch => 1,
            },
        'Non-Gift Order'    => {
                country       => $outpro_ctry,
                gift_shipment => 0,
                normal_pid    => 1,
            },
        'Weighted Marketing Promotion' => {
                country       => $outpro_ctry,
                gift_shipment => 0,
                normal_pid    => 1,
                marketing_promotion     => {
                    weighted => 1,
                },
            },
        'Normal + Is_hazmat' => {
                country    => $outpro_ctry,
                normal_pid => 1,
                is_hazmat_pid => 1,
            },
        'Is_hazmat only' => {
                country    => $outpro_ctry,
                is_hazmat_pid => 1,
            },
        'Is_hazmat + Vouchers' => {
                country    => $outpro_ctry,
                is_hazmat_pid => 1,
                phys_vouch => 1,
                virt_vouch => 1,
            },
    );

my %fulfilment_only_orders = (
        'Fulfilment CC_only' => {
                country    => $outpro_ctry,
                channel_id => $fulfilment_channel_id,
                cc_only_pid => 1,
                gift_message => 'Gift message test',
            },
        'Fulfilment Normal + CC_only' => {
                country    => $outpro_ctry,
                channel_id => $fulfilment_channel_id,
                normal_pid => 1,
                cc_only_pid => 1,
                gift_message => 'Gift message test',
           },
    );

# If there is a fulfilment_only channel (e.g. JC on DC1), we need to test this
# as well for production of returns proforma, etc.
%create_orders = (%create_orders, %fulfilment_only_orders) if $fulfilment_channel_id;

my $work_week_date = XT::Data::DateStamp->from_string("2012-05-23"); # Wed
my $saturday_date  = XT::Data::DateStamp->from_string("2012-05-26"); # Sat

my $shipping_option_cases = [
    {
        prefix      => "Non-Nom",
        description => "Non Nominated Day",
        setup       => { nominated_delivery_date => undef },
        expected    => { saturday_label_file_count => 0 },
    },
    {
        prefix               => "Nom-Work Week",
        description          => "Nominated Day - Work week day",
        only_for_test_method => "labelling",
        setup                => { nominated_delivery_date => $work_week_date },
        expected             => { saturday_label_file_count => 0 },
    },
    {
        prefix               => "Nom-Sat",
        description          => "Nominated Day - Saturday. Should print Saturday Delivery Label",
        only_for_test_method => "labelling",
        setup                => { nominated_delivery_date => $saturday_date },
        expected             => { saturday_label_file_count => 1 },
    },
];
for my $case (@$shipping_option_cases) {
    test_prefix($case->{prefix});
    note "\n\n\n\n\n*** $case->{description}";

    my $mech = Test::XTracker::Mechanize->new;

    foreach my $tmethod ( @test_methods ) {
        note "*** Test method ($tmethod)";
        # If flagged to only run for some test methods, skip if it's not that one
        my $only_for = $case->{only_for_test_method} || $tmethod;
        if($tmethod ne $only_for) {
            note "<--- Skipping because ($case->{description}), only running ($case->{only_for_test_method})\n\n";
            next;
        }

        for my $order_type ( sort keys %create_orders ) {
            test_prefix("$case->{prefix}::$order_type");
            my $country = $create_orders{$order_type}{country};
            my $order   = _create_an_order( $create_orders{$order_type} );
            test_prefix("$case->{prefix}::$order_type"); # Have to re-set it after create_order :/
            my $shipment = $order->shipments->first;
            $shipment->update({
                nominated_delivery_date => $case->{setup}->{nominated_delivery_date},
            });
            $shipment->discard_changes();

            my $printer;

            # get things needed to create an invoice
            my $order_info = get_order_info($dbh, $order->id);
            my $shipments  = get_order_shipment_info($dbh, $order->id);
            XTracker::Database::OrderPayment::_create_invoice( $schema, $shipment->id, $shipments, $order_info );

            $order->discard_changes;
            $shipment->discard_changes;

            note "Testing Packing Shipment. Method: ".$tmethod.", Order Type: $order_type, Order Id: ".$order->id.", Shipment Id: ".$shipment->id;

            # pick all the items
            $shipment->shipment_items->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED });

            my $operator_id = $APPLICATION_OPERATOR_ID;
            my $operator = $schema->resultset('Public::Operator')->find($operator_id);
            $schema->resultset('Public::OperatorPreference')->update_or_create(
                {
                    operator_id          => $operator_id,
                    packing_station_name => $ps_name,
                },
                { key => 'primary' }
            );
            my $handler = Test::XTracker::Mock::Handler->new({
                data => {
                    shipment_id        => $shipment->id,
                    sales_channel      => $order->channel->name,
                    sales_channel_id   => $order->channel_id,
                    shipment_info      => get_shipment_info( $dbh, $shipment->id ),
                    shipment_boxes     => get_shipment_boxes( $dbh, $shipment->id ),
                    shipment_item_info => get_shipment_item_info( $dbh, $shipment->id ),
                    shipment_address   => get_address_info( $schema, $shipment->shipment_address_id ),
                    shipping_country   => get_country_info( $dbh, $shipment->shipment_address->country ),
                    preferences        => get_operator_preferences( $dbh, $operator_id ),
                }
            });


            # pre add box check
            # need to initialise box and inner box for nap and jc
            my $box_name       = $shipment->order->channel->is_fulfilment_only ? 'Unknown' : 'Outer 3';
            my $inner_box_name = $shipment->order->channel->is_fulfilment_only ? 'No Inner box' : 'NAP 3';

            my $box = $schema->resultset('Public::Box')->find({
                box => $box_name,
                channel_id => $order->channel_id,
            });
            $handler->{param_of}{outer_box_id} = $box->id;
            $handler->{param_of}{inner_box_id}
                = $box->find_related('inner_boxes', { inner_box => $inner_box_name })->id;

            $handler->{param_of}{shipment_box_id} = Test::XTracker::Data->get_next_shipment_box_id;

            XTracker::Order::Fulfilment::PackShipment::_assign_box( $handler );
            $shipment->discard_changes;
            # find out what paperwork to expect
            my ( $num_proforma, $num_returns_proforma ) = check_country_paperwork( $dbh, $shipment->shipment_address->country );
            # if the shipment is not returnable then no Returns Proforma should be created
            if ( !$shipment->is_returnable ) {
               $num_returns_proforma = 0;
            }

            # set-up a basic airway bill to be used later on
            my ( $out_awb, $ret_awb ) = Test::XTracker::Data->generate_air_waybills;
            $ret_awb = 'none' if !$shipment->is_returnable;

            my $print_directory = Test::XTracker::PrintDocs->new({
                filter_regex => qr{\.(?:html|lbl)$},
            });

            # store the filenames
            my $inputform_fname    = "shippingform-".$shipment->id.".html";
            my $invoice_fname      = "invoice-".$shipment->renumerations->first->id.".html";
            my $outpro_fname       = "outpro-".$shipment->id.".html";
            my $retpro_fname       = "retpro-".$shipment->id.".html";
            my $label_fname        = $shipment->shipment_boxes->first->id.".lbl";
            my $archive_label_fname = $shipment->id."_archive_file.lbl";
            my $saturday_delivery_label_fname
                = $shipment->shipment_boxes->first->id
                . "_saturday_delivery_service_alert.lbl";

            CASE: {
                if ( $tmethod eq "airwaybill" ) {
                    ($printer) = map { $_->name } XTracker::Printers->new
                        ->locations_for_section($tmethod);

                    $operator->operator_preference
                        ->update({ printer_station_name => $printer });
                    XTracker::Order::Actions::UpdateShipmentAirwaybill::_update_airwaybill(
                        $shipment,
                        $out_awb,
                        $ret_awb,
                        $operator,
                    );

                    last CASE;
                }
                if ( $tmethod eq "labelling" ) {
                    # choose arbitrary printers from those available

                    note "Choosing printers";

                    my $printers = get_shipping_printers( $schema );

                    ok( $printers
                        && exists $printers->{document}
                        && exists $printers->{label}, "Got list of document and label printers");

                    my $printer_info = { document => { total => scalar(@{$printers->{document}}) },
                                            label    => { total => scalar(@{$printers->{label}}) }
                                        };

                    $printer_info->{document}->{selected}=int rand $printer_info->{document}->{total};
                    $printer_info->{label}   ->{selected}=int rand $printer_info->{label}   ->{total};

                    my $document_printer_name = $printers->{document}->[$printer_info->{document}->{selected}]->{name};
                    my $label_printer_name    = $printers->{label}   ->[$printer_info->{label}   ->{selected}]->{name};

                    note "Document printer will be '$document_printer_name' (".($printer_info->{document}->{selected}+1)." of $printer_info->{document}->{total})";
                    note "Label printer will be '$label_printer_name' (".      ($printer_info->{label}   ->{selected}+1)." of $printer_info->{label}->{total})";

                    $printer    = $document_printer_name;

                    # assign return AWB if shipment is returnable
                    if ( $shipment->is_returnable ) {
                        $handler->{param_of}{return_waybill}    = $ret_awb;
                        XTracker::Order::Fulfilment::PackShipment::_assign_awb( $handler );
                        ok ( $ret_awb
                            && ( $ret_awb =~ m/\d{10}/ || $ret_awb =~ m/\w{1}\d{11}/ ),
                            "Returnable shipment has valid return airwaybill.");
                    }
                    else {
                        ok ( $ret_awb eq 'none', "Non-returnable shipment has no valid return airwaybill assigned." );
                    }

                    # set up the mocked call to DHL to retrieve shipment validate XML response
                    my $dhl_label_type = 'dhl_shipment_validate';

                    my $mock_data = Test::XTracker::Mock::DHL::XMLRequest->new(
                        data => [
                            { dhl_label => $dhl_label_type },
                        ]
                    );
                    my $xmlreq = Test::MockModule->new( 'XTracker::DHL::XMLRequest' );
                    $xmlreq->mock( send_xml_request => sub { $mock_data->$dhl_label_type } );

                    print_shipment_documents(
                        $dbh,
                        $shipment->shipment_boxes->first->id,
                        $document_printer_name,
                        $label_printer_name,
                        1, # this indicates I want to skip printing invoice if Gift Shipment
                    );

                    test_label_print_log_entry(
                        "Shipment Label",
                        $shipment,
                        $label_fname,
                        1,
                    );
                    test_label_print_log_entry(
                        "Saturday Delivery Service Alert Label",
                        $shipment,
                        $saturday_delivery_label_fname,
                        $case->{expected}->{saturday_label_file_count},
                    );

                    last CASE;
                }
            };

            # Print the Shipping input Form
            generate_input_form( $shipment->id, 'Shipping' );

            my $expected_document_count = 2 # shippingform, invoice
                + ( $num_proforma ? 1 : 0 )
                + (($shipment->has_hazmat_lq_items && !$shipment->is_premier) ? 1 : 0)
                + ( $num_returns_proforma ? 1 : 0 );

            if ( $tmethod eq 'labelling' ) {
                # We expect to print a box label and for dutiable shipments, an archive label here
                $expected_document_count += ( $shipment->requires_archive_label ) ? 2 : 1;
                my $gm_warning_expected = ($shipment->has_gift_messages() && !$shipment->can_automate_gift_message());

                if ($gm_warning_expected) {
                    $expected_document_count++ if (defined($shipment->gift_message) && $shipment->gift_message ne ''); # top level gift message

                    my @ship_items = $shipment->shipment_items->all; # shipment item level gift messages
                    foreach my $si (@ship_items) {
                        $expected_document_count++ if (defined($si->gift_message) && $si->gift_message ne '');
                    }
                }
                $expected_document_count += $case->{expected}->{saturday_label_file_count};
            }

            my %file_name_object = $print_directory->wait_for_new_filename_object(
                files => $expected_document_count,
            );

            # check files have been generated
            $print_directory->non_empty_file_exists_ok( $inputform_fname, "should find shipping input form document ($inputform_fname)" );
            $print_directory->non_empty_file_exists_ok( $invoice_fname, "should find invoice document ($invoice_fname)" );

            if ( $num_proforma ) {
                $print_directory->non_empty_file_exists_ok( $outpro_fname, "should find outward proforma document ($outpro_fname)" );
            }
            else {
                $print_directory->file_not_present_ok( $outpro_fname, "should not find outward proforma document ($outpro_fname)" );
            }

            if ( $num_returns_proforma ) {
                $print_directory->non_empty_file_exists_ok( $retpro_fname, "should find return proforma document ($retpro_fname)" );
            }
            else {
                $print_directory->file_not_present_ok( $retpro_fname, "should not find return proforma document ($retpro_fname)" );
            }

            # check if the file contents are ok
            _check_input_form( $schema, $mech, $shipment, $file_name_object{ $inputform_fname }, $create_orders{$order_type}{marketing_promotion}{weighted} );
            _check_outward_proforma( $schema, $mech, $shipment, $file_name_object{ $outpro_fname }, $print_directory, $create_orders{$order_type}{marketing_promotion}{weighted} )
                                                                                                                        if ( $num_proforma );
            _check_return_proforma( $schema, $mech, $shipment, $file_name_object{ $retpro_fname }, $print_directory )
                                                                                                                        if ( $num_returns_proforma );
            _check_invoice( $schema, $mech, $shipment, $printer, $file_name_object{ $invoice_fname }, $print_directory );
            if ( $tmethod eq "labelling" ) {
                $print_directory->non_empty_file_exists_ok( $label_fname, "should find DHL label file ($label_fname)" );
                if ( $shipment->requires_archive_label ) {
                    $print_directory->non_empty_file_exists_ok( $archive_label_fname, "should find DHL archive label file ($archive_label_fname)" );
                }
                if($case->{expected}->{saturday_label_file_count}) {
                    $print_directory->non_empty_file_exists_ok( $saturday_delivery_label_fname, "should find DHL Saturday delivery label file ($saturday_delivery_label_fname)" );
                    # Don't check contents, it's not dynamic anyway
                }
                else {
                    $print_directory->file_not_present_ok( $saturday_delivery_label_fname, "should not find DHL Saturday delivery label file ($saturday_delivery_label_fname)" );
                }
            }
        }
    }
}

done_testing();

sub test_label_print_log_entry {
    my ($label_name, $shipment, $log_label_file_name, $label_count) = @_;
    my @print_log_rows = values %{get_shipment_documents($schema->storage->dbh, $shipment->id)};
    my @shipment_label_rows =
        grep { $_->{document} eq $label_name }
        @print_log_rows;
    is(
        scalar @shipment_label_rows,
        $label_count,
        "Got $label_count $label_name row",
    );

    if($label_count) {
        my ($shipment_label_row) = @shipment_label_rows;
        is(
            $shipment_label_row->{file},
            $log_label_file_name,
            "Found a $label_name, and it has the correct file name",
        );
    }
}

#--------------------------------------------------------------

# check the Shipping Input Form
sub _check_input_form {
    my ( $schema, $mech, $shipment, $print_doc, $weighted_promotion )    = @_;

    my $doc_path = $print_doc->full_path;
    my $doc_filename = $print_doc->filename;

    my $tmp;
    my @tmp;

    note "Looking at Shipping Input Form file";
    my $uri = URI::file->new( $doc_path );
    $mech->get_ok( $uri, 'Fetching ' . "$doc_path" . ' from disk' );

    my @ship_items  = $shipment->shipment_items->all;

    my $expect_tax  = check_tax_included( $schema->storage->dbh, $shipment->shipment_address->country );
    note "EXPECT TAX: $expect_tax";

    my $total_cost  = 0;
    my $total_tax   = 0;

    foreach ( @ship_items ) {
        if ( $_->voucher_variant_id ) {
            my $voucher = $_->voucher_variant->product;
            if ( $voucher->is_physical ) {
                # Physical Vouchers should be displayed but cost '1' GBP/USD/EUR etc. as appropriate
                ok( scalar( @tmp = $mech->get_table_row_by_xpath(
                    $input_row_xpath,
                    $voucher->id,
                ) ), "Physical Voucher found in table" );
                $tmp    = $voucher->name;
                like( $tmp[1], qr/$tmp/, "found voucher's Name in row" );
                $tmp    = $voucher->fabric_content;
                like( $tmp[4], qr/$tmp/, "found voucher's Fabric Content in row" );
                like( $tmp[7], qr/1.00/, "found voucher's Unit Price of '1' in row" );

                $total_cost += 1;
            }
            else {
                # Virtual Vouchers shouldn't be displayed
                ok( !scalar( @tmp = $mech->get_table_row_by_xpath (
                    $input_row_xpath,
                    $voucher->id,
                ) ), "Virtual Voucher NOT found in table" );
            }
        }
        else {
            my $product = $_->variant->product;
            note "looking for ".$_->variant->legacy_sku;
            ok( scalar( @tmp = $mech->get_table_row_by_xpath(
                $input_row_xpath,
                $_->variant->legacy_sku,
            ) ), "Normal Product found in table" );
            $tmp    = $product->product_attribute->name;
            like( $tmp[1], qr/$tmp/, "found product's Name in row" );
            $tmp    = $product->shipping_attribute->fabric_content;
            $tmp[4] =~ s/^\s+//;
            like( $tmp[4], qr/$tmp/, "found product's Fabric Content in row" );
            $tmp    = sprintf( "%.2f", $_->unit_price );
            like( $tmp[7], qr/$tmp/, "found product's Unit Price in row" );

            $total_tax  += $_->tax;
            $total_cost += $_->unit_price;
        }
    }

    # Check that if the shipment has to display a shipping input warning
    # the shipping form states 'NON-RETURNABLE ITEMS'
    if ( $shipment->display_shipping_input_warning ) {
        $mech->content_like( qr/NON-RETURNABLE ITEMS/s,
                             "Shipping form is marked 'NON-RETURNABLE ITEMS'" );
    }
    else {
        $mech->content_unlike( qr/NON-RETURNABLE ITEMS/s,
                               "Shipping form is not marked 'NON-RETURNABLE ITEMS'" );
    }

    my $grand_total = sprintf( "%.2f", $total_cost + $shipment->shipping_charge + ( $expect_tax ? $total_tax : 0 ) );
    $grand_total    =~ s/\.00$//;       # grand total doesn't seem todisplay decimals
    $total_tax  = sprintf( "%.2f", $total_tax );
    $total_cost = sprintf( "%.2f", $total_cost );

    # If the order contains a weighted promotion.
    if ( $weighted_promotion ) {

        # Increment total values by ONE.
        $total_cost++;
        $grand_total++;

        # Check a Promotion is present and has the correct values.
        my @promotions;
        ok( scalar( @promotions = $mech->get_table_row_by_xpath(
            q{//table[.//tr/td = 'DESCRIPTION']//tr[./td/font[starts-with(.,'Marketing Promotion for Order ID')]]/td},
        ) ), 'Found a Marketing Promotion in the table' );

        is( $promotions[6], 1, 'Promotion has correct quantity (1)' );
        like( $promotions[7], qr/1\.00/, 'Promotion has correct unit price (1.00)' );
        like( $promotions[8], qr/1\.00/, 'Promotion has correct sub total (1.00)' );

    }

    # check totals
    @tmp    = $mech->get_table_row( 'TOTAL PRICE' );
    like( $tmp[0], qr/$total_cost/, "Total Price as expected" );
    @tmp    = $mech->get_table_row( 'TOTAL TAX' );
    if ( $expect_tax ) {
        like( $tmp[0], qr/$total_tax/, "Total Tax as expected" );
    }
    else {
        ok( !scalar( @tmp ), "NO Total Tax shown as expected for shipment country" );
    }
    @tmp    = $mech->get_table_row( 'GRAND TOTAL' );
    like( $tmp[0], qr/$grand_total/, "Grand Total as expected" );

    return;
}

# check the Outward Proforma
sub _check_outward_proforma {
    my ( $schema, $mech, $shipment, $print_doc, $print_directory, $weighted_promotion )  = @_;

    my $doc_path = $print_doc->full_path;
    my $doc_filename = $print_doc->filename;

    my $doc_data    = $print_doc->as_data();

    # check the last shipment print log
    my $spl_rs  = $shipment->shipment_print_logs
                            ->search( { file => 'outpro-'.$shipment->id }, { order_by => 'id DESC' } );
    is( $spl_rs->first->document, "Outward Proforma", "Shipment Printer Log: document name as expected" );
    my $spl_id  = $spl_rs->first->id;       # store the Log Id for later comparison

    note "Looking at Outward Proforma file";
    my $uri = URI::file->new( $doc_path );
    $mech->get_ok( $uri, 'Fetching ' . "$doc_path" . ' from disk' );

    my $total_cost  = 0;
    my $total_items = 0;
    my $total_vouch = 0;

    foreach my $item ( $shipment->shipment_items->all ) {
        my $product = $item->get_true_variant->product;

        my @got = $mech->get_table_row_by_xpath($outpro_row_xpath, $product->id);

        # Virtual Vouchers shouldn't be displayed
        if ( $item->is_voucher && !$product->is_physical ) {
            ok( !@got, "Virtual Voucher NOT found in table" );
            next;
        }
        ok(@got, sprintf '%s found in table', $item->is_voucher ? 'Voucher' : 'Product');

        my $expected_fabric_content = $product->shipping_attribute->fabric_content;
        like( $got[3], qr/$expected_fabric_content/, "found fabric content in row" );

        my $expected_hs_code = $product->hs_code->hs_code;
        like( $got[6], qr/$expected_hs_code/, "found HS Code in row" );

        # Physical Vouchers should be displayed but cost '1' GBP/USD/EUR etc. as appropriate
        my $expected_unit_price
            = sprintf( '%.2f', $item->is_voucher ? 1 : $item->unit_price );
            like( $got[4], qr/$expected_unit_price/, "found unit price in row" );

        $total_items++;
        $total_cost += $expected_unit_price;

        $total_vouch++ if $item->is_voucher;
    }

    $total_cost++
        if $weighted_promotion;

    my $grand_total = sprintf( "%.2f", $total_cost + $shipment->shipping_charge );

    # check total
    my ($total_value) = $mech->get_table_row( 'TOTAL VALUE' );
    like( $total_value, qr/$grand_total/, "Total Value as expected" );

    # Check Export Reason
    if ( $total_items == $total_vouch ) {
        # if vouchers only
        $mech->content_like( qr/REASON FOR EXPORT :.*DOCUMENTS/s, "Reason for Export is 'DOCUMENTS'" );
        $mech->content_unlike( qr/REASON FOR EXPORT :.*(DDP|DDU)/s, "Reason for Export doesn't contain 'DDP' or 'DDU'" );
    }
    else {
        # if mixed or normal, plus test for hazmat item(s)
        if ( $shipment->has_hazmat_items ) {
            $mech->content_like( qr/REASON FOR EXPORT :.*DANGEROUS GOODS IN LIMITED QUANTITIES/s,
                             "Reason for Export is 'DANGEROUS GOODS IN LIMITED QUANTITIES'" );
        }
        else {
            $mech->content_like( qr/REASON FOR EXPORT :.*NOT RESTRICTED FOR TRANSPORT/s,
                             "Reason for Export is 'NOT RESTRICTED FOR TRANSPORT'" );
        }
    }

    # check the 'Date' shown is in the correct format
    my $expected    = $shipment->order->channel->business->branded_date( $schema->db_now );
    is( $doc_data->{shipment_details}{Date}, $expected, "'Date' shown in document is in the correct format" );


    # check the Outward Proforma can be Re-Viewed on the Order View page
    # the '_view_document' function in 'XTracker::Order::Functions::Order::OrderView'
    # regenerates the document if it has been deleted and returns a uri to it

    $print_directory->delete_file( $doc_filename ); # delete the file so it can be re-generated

    # re-gen the document
    $uri    = XTracker::Order::Functions::Order::OrderView::_view_document( $shipment->order->id, $spl_id, $schema );
    ( $print_doc )  = $print_directory->wait_for_new_files();     # wait for the new file so the Test doesn't complain at the end
    like $uri, qr{/$doc_filename$}, 'outward document should get regenerated';
    cmp_ok( $spl_rs->reset->first->id, '>', $spl_id, "There has been a new Shipment Print Log record created" );
    is( $spl_rs->first->document, "Outward Proforma", "and the new Shipment Printer Log: document name as expected" );

    return;
}

# check the Return Proforma
sub _check_return_proforma {
    my ( $schema, $mech, $shipment, $print_doc, $print_directory )  = @_;

    my $doc_path = $print_doc->full_path;
    my $doc_filename = $print_doc->filename;

    my $doc_data    = $print_doc->as_data();

    my $tmp;
    my @tmp;

    my $dc_name = config_var('DistributionCentre','name');

    # check the last shipment print log
    my $spl_rs  = $shipment->shipment_print_logs
                            ->search( { file => 'retpro-'.$shipment->id }, { order_by => 'id DESC' } );
    my $spl     = $spl_rs->first;       # store for later tests
    is( $spl->document, "Return Proforma", "Shipment Printer Log: document name as expected" );

    note "Looking at Returns Proforma file";
    my $uri = URI::file->new( $doc_path );
    $mech->get_ok( $uri, 'Fetching ' . "$doc_path" . ' from disk' );

    my @ship_items  = $shipment->shipment_items->all;

    my $total_cost  = 0;

    foreach ( @ship_items ) {
        if ( $_->voucher_variant_id ) {
            # Physical & Virtual Vouchers shouldn't be displayed
            ok( !scalar( @tmp = $mech->get_table_row_by_xpath(
                $retpro_row_xpath,
                $_->voucher_variant->sku,
            ) ), "Voucher NOT found in table" );
        }
        elsif ( !$_->display_on_returns_proforma )    {
            ok( !scalar( @tmp = $mech->get_table_row_by_xpath(
                $retpro_row_xpath,
                $_->variant->sku,
            ) ), "Normal Product NOT found in table as non-returnable" );
        }
        else {
            my $product = $_->variant->product;
            ok( scalar( @tmp = $mech->get_table_row_by_xpath(
                $retpro_row_xpath,
                $_->variant->sku,
            ) ), "Normal Product found in table" );
            $tmp    = sprintf( "%0.3f", $product->shipping_attribute->weight );
            like( $tmp[5], qr/$tmp/, "found product's Weight in row" );
            $tmp    = $product->hs_code->hs_code;
            like( $tmp[7], qr/$tmp/, "found product's HS Code in row" );

            # Gift Shipments shouldn't display price
            $tmp    = sprintf( "%.2f", $_->unit_price );
            if ( $shipment->gift ) {
                unlike( $tmp[3], qr/$tmp/, "Unit Price not displayed in row" );
            }
            else {
                like( $tmp[3], qr/$tmp/, "found product's Unit Price in row" );
            }

            $total_cost += $_->unit_price;
        }
    }

    my $grand_total = sprintf( "%.2f", $total_cost );

    # check total
    @tmp    = $mech->get_table_row( 'TOTAL VALUE' );
    if ( $shipment->gift ) {
        unlike( $tmp[0], qr/$grand_total/, "Total Value NOT displayed" );
    }
    else {
        like( $tmp[0], qr/$grand_total/, "Total Value as expected" );
    }

    # check the 'Original Date Sent' & 'Date of Invoice' shown is in the correct format
    my $expected    = $shipment->order->channel->business->branded_date( $schema->db_now );
    is( $doc_data->{shipment_details}{'Consignor Details'}{'ORIGINAL DATE SENT'}, $expected,
                                            "'Original Date Sent' shown in document is in the correct format" );
    $expected       = $shipment->order->channel->business->branded_date( $shipment->date );
    is( $doc_data->{shipment_details}{'Consignee Details'}{'DATE OF INVOICE'}, $expected,
                                            "'Date of Invoice' shown in document is in the correct format" );


    # check the Return Proforma can be Re-Viewed on the Order View page
    # the '_view_document' function in 'XTracker::Order::Functions::Order::OrderView'
    # re-generates the document if it has been deleted and returns a uri to it

    $print_directory->delete_file( $doc_filename ); # delete the file so it can be re-generated

    # update the date on the log to be 2 days ago as when
    # re-generating it should use the Log's date and not 'Now'
    $spl->update( { date => $spl->date->subtract( days => 2 ) } );
    $expected   = $shipment->order->channel->business->branded_date( $spl->date );

    # re-gen the document
    $uri    = XTracker::Order::Functions::Order::OrderView::_view_document( $shipment->order->id, $spl->id, $schema );
    ( $print_doc )  = $print_directory->wait_for_new_files();     # wait for the new file

    like $uri, qr{/$doc_filename$}, 'retpro document should get regenerated';
    cmp_ok( $spl_rs->reset->first->id, '==', $spl->id, "No New Shipment Print Log has been Created" );
    is( $print_doc->as_data()->{shipment_details}{'Consignor Details'}{'ORIGINAL DATE SENT'}, $expected,
                                            "'Original Date Sent' shown in document is in the correct format and is the Log's Date" );

    return;
}

# check the Invoice
sub _check_invoice {
    my ( $schema, $mech, $shipment, $printer, $print_doc, $print_directory )    = @_;

    my $doc_path = $print_doc->full_path;
    my $doc_filename = $print_doc->filename;

    my $doc_data    = $print_doc->as_data();

    my $tmp;
    my @tmp;

    note "Looking at Invoice file";
    my $uri = URI::file->new( $doc_path );
    $mech->get_ok( $uri, 'Fetching ' . "$doc_path" . ' from disk' );

    my @ship_items  = $shipment->shipment_items->all;
    # check the last shipment print log
    my $spl_rs = $shipment
        ->shipment_print_logs
        ->search(
            { file => 'invoice-'.$shipment->get_sales_invoice->id },
            { order_by => 'id DESC' }
        );
    my $spl = $spl_rs->first;

    # gift shipment's invoice is generated but not printed
    is( $spl->document, "Invoice", "Shipment Printer Log: document name as expected" );
    if ( $shipment->gift ) {
        is( $spl->printer_name, "Generated NOT Printed" , "Shipment Printer Log: printer shows 'Generated NOT Printed' message" );
    }
    else {
        is( $spl->printer_name, $printer , "Shipment Printer Log: printer as expected" );
    }

    my $total_cost  = 0;

    foreach ( @ship_items ) {
        if ( $_->voucher_variant_id ) {
            my $voucher = $_->voucher_variant->product;

            # make-up the name of the Voucher to check for
            $tmp    = $voucher->designer.' '.$voucher->name;
            ok( scalar( @tmp = $mech->get_table_row( $tmp ) ), "Voucher found in table" );
            $tmp    = sprintf( "%.2f", $_->unit_price );
            like( $tmp[1], qr/$tmp/, "found voucher's Unit Price in row" );

            $total_cost += $_->unit_price + $_->tax;
        }
        else {
            my $product = $_->variant->product;
            $tmp    = $product->designer->designer.' '.$product->attribute->name;
            ok( scalar( @tmp = $mech->get_table_row( $tmp ) ), "Normal Product found in table" );

            $tmp    = sprintf( "%.2f", $_->unit_price );
            like( $tmp[1], qr/$tmp/, "found product's Unit Price in row" );

            $total_cost += $_->unit_price + $_->tax;
        }
    }

    my $grand_total = sprintf( "%.2f", $total_cost + $shipment->shipping_charge );
    $total_cost = sprintf( "%.2f", $total_cost );

    # check total
    @tmp    = $mech->get_table_row( 'TOTAL PRICE' );
    like( $tmp[1], qr/$total_cost/, "Total Price as expected" );
    @tmp    = $mech->get_table_row( 'GRAND TOTAL' );
    like( $tmp[1], qr/$grand_total/, "Grand Total as expected" );

    # check the 'Invoice Date' is as it should be
    my $expected    = $shipment->order->channel->business->branded_date( $shipment->renumerations->first->get_invoice_date );
    is( $doc_data->{invoice_details}{overview}{'Invoice Date'}, $expected,
                                            "'Invoice Date' shown in document is in the correct format" );


    # check the Invoice can be Re-Viewed on the Order View page
    # the '_view_document' function in 'XTracker::Order::Functions::Order::OrderView'
    # re-generates the document if it has been deleted and returns a uri to it

    $print_directory->delete_file( $doc_filename ); # delete the file so it can be re-generated

    # re-gen the document
    $uri    = XTracker::Order::Functions::Order::OrderView::_view_document( $shipment->order->id, $spl->id, $schema );
    ( $print_doc )  = $print_directory->wait_for_new_files();     # wait for the new file so the Test doesn't complain at then end

    like $uri, qr{/$doc_filename$}, 'invoice document should get regenerated';
    cmp_ok( $spl_rs->reset->first->id, '==', $spl->id, "No New Shipment Print Log has been Created" );

    return;
}

# creates an order
sub _create_an_order {
    my $args    = shift;

    my $item_tax         = $args->{item_tax} || 50;
    my $item_duty        = $args->{item_duty} || 0;
    my $item_channel_id  = $args->{channel_id} || $channel_id;

    note "Creating Order";

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 3,
        channel_id => $item_channel_id,
        phys_vouchers   => {
            how_many                 => 1,
            want_stock               => 1,
            value                    => '150.00',
            assign_code_to_ship_item => 1,
        },
        virt_vouchers   => {
            how_many                 => 1,
            value                    => '250.00',
            assign_code_to_ship_item => 1,
        },
    });
    my @pids_to_use;
    #ensure item has fabric content to prevent test failing
    if ( $args->{normal_pid} ) {
        my $sa = $pids->[0]{product}->shipping_attribute;
        if (!$sa->fabric_content) {
            $sa->update({fabric_content => 'nasty stuff'});
        }
        push @pids_to_use, $pids->[0];
    }
    #make item hazmat with a non-returnable state
    if ( $args->{is_hazmat_pid} ) {
        $pids->[1]->{ item_returnable_state_id } = $SHIPMENT_ITEM_RETURNABLE_STATE__NO;
        my $sa = $pids->[1]{product}->shipping_attribute;
        $sa->update({is_hazmat => 't'});
        if (!$sa->fabric_content) {
            $sa->update({fabric_content => 'nasty stuff'});
        }
        push @pids_to_use, $pids->[1];
    }
    #make item cc_only
    if ( $args->{cc_only_pid} ) {
        $pids->[2]->{ item_returnable_state_id } = $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY;
        my $sa = $pids->[2]{product}->shipping_attribute;
        if (!$sa->fabric_content) {
            $sa->update({fabric_content => 'nasty stuff'});
        }
        push @pids_to_use, $pids->[2];
    }
    push @pids_to_use, $pids->[3]     if ( $args->{phys_vouch} );
    push @pids_to_use, $pids->[4]     if ( $args->{virt_vouch} );

    my $currency        = $args->{currency} || config_var('Currency', 'local_currency_code');

    my $currency_id     = $schema->resultset('Public::Currency')->find({currency => $currency})->id;
    my $carrier_name    = ( $channel->is_on_dc( 'DC2' ) ? 'UPS' : config_var('DistributionCentre','default_carrier') );
    my $ship_account = Test::XTracker::Data->find_shipping_account({
        carrier    => $carrier_name,
        channel_id => $channel->id,
    });
    my $address = Test::XTracker::Data->create_order_address_in(
        "current_dc_premier",
        { country => $args->{country} },
    );
    note "Country Used: " . $args->{country};

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $base = {
        customer_id          => $customer->id,
        currency_id          => $currency_id,
        channel_id           => $channel->id,
        shipment_type        => $SHIPMENT_TYPE__INTERNATIONAL,
        shipment_status      => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id  => $ship_account->id,
        invoice_address_id   => $address->id,
        gift_shipment        => ( exists( $args->{gift_shipment} ) ? $args->{gift_shipment} : 1 ),
        ( $args->{gift_message} ? ( gift_message => $args->{gift_message} ) : () ),
    };
    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => \@pids_to_use,
        base => $base,
        attrs => [
            { price => 100.00, tax => $item_tax, duty => $item_duty },
        ],
    });

    $order->shipments->first->shipment_items->update( { tax => $item_tax } );

    # update some dates so they are not 'today' for future tests
    $order->update( { date => $order->date->subtract( days => 1 ) } );
    $order->get_standard_class_shipment->update( { date => $order->date } );

    if ( exists $args->{marketing_promotion} ) {

        # Create a marketing promotion.
        my $promotions = Test::XTracker::Data::MarketingPromotion
            ->create_marketing_promotion( {
                channel_id  => $channel->id,
                count       => 1,
                $args->{marketing_promotion}{weighted}
                    ? (
                        promotion_type => {
                            # The name needs to be unique.
                            name    => 'Marketing Promotion for Order ID ' . $order->id,
                            # We explicitly specify the weight, so we know what to expect.
                            weight  => 0.5
                        }
                    )
                    : (),
            } );

        # Link the promotion to the order.
        Test::XTracker::Data::MarketingPromotion
            ->create_link( $order, $promotions->[0] );

    }

    return $order;
}
