#!/usr/bin/env perl

=head1 NAME

shipping_docs_branding.t - Shipping Documentation Channel Branding

=head1 DESCRIPTION

This tests the Sales Channel Branding in the Shipping Documents, such as the
email addresses mentioned or the name of the Sales Channel, or anything else
to do with the branding of the documents rather than the actual data in them.

Currently it tests:
    * Shipping Input Form
    * Outward Proforma
    * Return Proforma
    * Invoice

Label files are generated as part of the test but not currently tested, please
add as you see fit.

This was originally done for CANDO-345.

To test the data part of the documents please use shipping_docs.t

#TAGS fulfilment packing printer checkruncondition whm

=cut

use NAP::policy qw/test/;

use Test::MockModule;
use Test::XTracker::Data;
use Test::XTracker::Data::Country;
use Test::XTracker::Hacks::isaFunction;
use Test::XTracker::Mock::DHL::XMLRequest;
use Test::XTracker::PrintDocs;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];

use XTracker::Config::Local         qw(
                                        config_var
                                        dc_address
                                        get_shipping_printers
                                        comp_addr
                                        comp_contact_hours
                                        comp_tel
                                        customercare_email
                                        shipping_email
                                        return_addr
                                        return_postcode
                                    );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :branding
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                    );

use XTracker::Order::Printing::OutwardProforma  qw( generate_outward_proforma );
use XTracker::Order::Actions::UpdateShipmentAirwaybill qw();
use XTracker::Database::Shipment    qw( check_country_paperwork );
use XTracker::Database::Currency    qw( get_currency_id );
use XTracker::Printers;

BEGIN {
    use_ok('XTracker::Order::Printing::ShipmentDocuments', qw( generate_shipment_paperwork print_shipment_documents ) );
    use_ok('XTracker::Order::Printing::ShippingInputForm', qw( generate_input_form ) );

    can_ok("XTracker::Order::Printing::ShipmentDocuments",qw(
                            print_shipment_documents
                            generate_shipment_paperwork
                        ) );
    can_ok("XTracker::Order::Printing::ShippingInputForm",qw(
                            generate_input_form
                        ) );
}

# make DB connections
my $schema  = Test::XTracker::Data->get_schema;
isa_ok($schema, 'XTracker::Schema',"Schema Created");
my $dbh     = $schema->storage->dbh;

#---- TEST FUNCTIONS ------------------------------------------

# This tests the branding of various shipping documents:
#   Invoice
#   Shipping Input Form
#   Outward Proforma
#   Return Proforma

my $resultset= _define_dbic_resultset( $schema );

my $ps_name     = $resultset->{ps_name}();
my $outpro_ctry = $resultset->{outpro_country}();

my %create_order_args   = (
        country    => $outpro_ctry,
        normal_pid => 1,
        phys_vouch => 0,
        virt_vouch => 0,
    );


my @channels    = $schema->resultset('Public::Channel')->search( {}, { order_by => 'id' } )->enabled_channels->all;

foreach my $channel ( @channels ) {

    note "TESTING for Sales Channel: " . $channel->id . " - " . $channel->name;

    unless ( $channel->shipping_accounts->count ) {
        note 'No shipping accounts configured - skipping tests';
        next;
    }

    $create_order_args{channel} = $channel;
    my $branding    = $channel->branding;       # get all of the Branding for the Sales Channel

    my $country = $create_order_args{country};
    my $order      = _create_an_order( \%create_order_args );
    my $shipment   = $order->shipments->first;

    $order->discard_changes;
    $shipment->discard_changes;

    # find out what paperwork to expect
    my ( $num_proforma, $num_returns_proforma )    = check_country_paperwork( $dbh, $shipment->shipment_address->country );

    my $print_directory = Test::XTracker::PrintDocs->new();

    # Print the Shipping input Form
    generate_input_form( $shipment->id, 'Shipping' );

    # Not sure why we have a separate DC2 section... :/
    if ( $distribution_centre eq 'DC2' ) {
        # this will print off the docs for DC2
        my $operator
            = $schema->resultset('Public::Operator')->find($APPLICATION_OPERATOR_ID);
        my ($location) = map { $_->name }
                XTracker::Printers->new
                ->locations_for_section('airwaybill');

        $operator->update_or_create_preferences({
            operator_id          => $operator->id,
            printer_station_name => $location,
        });
        XTracker::Order::Actions::UpdateShipmentAirwaybill::_update_airwaybill(
            $shipment,
            '1111111111',
            '2222222222',
            $operator,
        );
    }
    else {
        # set up the mocked call to DHL to retrieve shipment validate XML response
        my $dhl_label_type = 'dhl_shipment_validate';
        my $mock_data = Test::XTracker::Mock::DHL::XMLRequest->new(
            data => [
                { dhl_label => $dhl_label_type },
            ]
        );
        my $xmlreq = Test::MockModule->new( 'XTracker::DHL::XMLRequest' );
        $xmlreq->mock( send_xml_request => sub { $mock_data->$dhl_label_type } );

        # work out printers to use
        my ( $document_printer_name, $label_printer_name )  = _get_printer_names( $schema );
        print_shipment_documents(
                            $dbh,
                            $shipment->shipment_boxes->first->id,
                            $document_printer_name,
                            $label_printer_name,
                            1,      # this indicates I want to skip printing invoice if Gift Shipment
                        );
    }

    # store the filenames
    my $inputform_fname = "shippingform-".$shipment->id.".html";
    my $invoice_fname   = "invoice-".$shipment->renumerations->first->id.".html";
    my $outpro_fname    = "outpro-".$shipment->id.".html";
    my $retpro_fname    = "retpro-".$shipment->id.".html";
    my $dgn_fname       = "dgn-".$shipment->id.".html";

    my $expected_document_count = 0
                                    + 1 # shippingform
                                    + 1 # invoice
                                    + (( $shipment->has_hazmat_lq_items && !$shipment->is_premier ) ? 1 : 0) #dgn
                                    + ( $num_proforma ? 1 : 0 )
                                    + ( $num_returns_proforma ? 1 : 0 );
    my %file_name_object = $print_directory->wait_for_new_filename_object(
        files => $expected_document_count,
    );

    # check files have been generated
    foreach my $fname ( $inputform_fname, $invoice_fname, $outpro_fname, $retpro_fname ) {
        ok( $file_name_object{ $fname }, "Found '$fname' Document" );
        $print_directory->non_empty_file_exists_ok( $fname, "and it's not empty" );
    }

    # check if the file contents are ok
    _check_input_form( $schema, $branding, $shipment, $file_name_object{ $inputform_fname }, $print_directory );
    _check_outward_proforma( $schema, $branding, $shipment, $file_name_object{ $outpro_fname }, $print_directory );
    _check_return_proforma( $schema, $branding, $shipment, $file_name_object{ $retpro_fname }, $print_directory );
    _check_invoice( $schema, $branding, $shipment, $file_name_object{ $invoice_fname }, $print_directory );
}

done_testing;

#--------------------------------------------------------------

# check the Shipping Input Form
sub _check_input_form {
    my ( $schema, $branding, $shipment, $print_doc, $print_dir )    = @_;

    note "Looking at Shipping Input Form file";

    my $channel     = $shipment->order->channel;
    my $doc_data    = $print_doc->as_data();

    is( $doc_data->{shipment_details}{'Sales Channel'}, $branding->{$BRANDING__PF_NAME},
                        "The Sales Channel Public Facing Name is shown correctly" );

    return;
}

# check the Outward Proforma
sub _check_outward_proforma {
    my ( $schema, $branding, $shipment, $print_doc, $print_dir )    = @_;

    note "Looking at Outward Proforma file";

    my $channel     = $shipment->order->channel;
    my $doc_data    = $print_doc->as_data();

    is( $doc_data->{document_heading}, $branding->{$BRANDING__DOC_HEADING},
                        "The Document Header is shown correctly" );

    _check_general_footer( $doc_data->{footer}, $channel, $branding );

    # check the 'Date' shown is in the correct format
    my $expected    = $channel->business->branded_date( $schema->db_now );
    is( $doc_data->{shipment_details}{Date}, $expected, "'Date' shown in document is in the correct format" );


    # Romania, Iceland, Liechtenstein and Israel show different text
    note "check for Country 'Israel' as this is a special case which shows the Sales Channel again";

    $shipment->shipment_address->update( { country => 'Israel' } );
    generate_outward_proforma( $schema->storage->dbh, $shipment->id, 'Shipping', 1, $schema );

    my %file_name_object = $print_dir->wait_for_new_filename_object( files => 1 );
    $doc_data   = $file_name_object{ $print_doc->filename }->as_data();

    like( $doc_data->{footer}, qr/$branding->{$BRANDING__PF_NAME}\W+Airwaybill/,
                        "Public Facing Name shown correctly when shipping country is 'Israel'" );
    my $dc_city = dc_address($channel)->{city};
    like( $doc_data->{footer}, qr/Place and date of signature:.*${dc_city}.*$branding->{$BRANDING__PF_NAME}/i,
                        "DC City shown correctly in 'Place and date of signature' section" );

    return;
}

# check the Return Proforma
sub _check_return_proforma {
    my ( $schema, $branding, $shipment, $print_doc, $print_dir )    = @_;

    note "Looking at Returns Proforma file";

    my $channel     = $shipment->order->channel;
    my $conf_section= $channel->business->config_section;
    my $doc_data    = $print_doc->as_data();

    is( $doc_data->{document_heading}, $branding->{$BRANDING__DOC_HEADING},
                        "The Document Header is shown correctly" );
    is( $doc_data->{shipment_details}{'Consignee Details'}{'COMPANY NAME'}, $branding->{$BRANDING__PF_NAME},
                        "The Sales Channel Public Facing Name is shown correctly" );
    my $return_addr = return_addr( $conf_section );
    $return_addr    =~ s/<br>/\.\*/g;
    like( $doc_data->{shipment_details}{'Consignee Details'}{ADDRESS}, qr/${return_addr}/i,
                        "The Consignee Address is as Expected" );
    my $post_code_label = config_var('DistributionCentre','post_code_label');
    is( $doc_data->{shipment_details}{'Consignee Details'}{ $post_code_label }, return_postcode( $conf_section ),
                        "The Consignee Post Code is as Expected" );

    # check the 'Original Date Sent' & 'Date of Invoice' shown is in the correct format
    my $expected    = $channel->business->branded_date( $schema->db_now );
    is( $doc_data->{shipment_details}{'Consignor Details'}{'ORIGINAL DATE SENT'}, $expected,
                                            "'Original Date Sent' shown in document is in the correct format" );
    $expected       = $channel->business->branded_date( $shipment->date );
    is( $doc_data->{shipment_details}{'Consignee Details'}{'DATE OF INVOICE'}, $expected,
                                            "'Date of Invoice' shown in document is in the correct format" );

    my $export_reason_prefix    = config_var('DistributionCentre','return_export_reason_prefix');
    like( $doc_data->{export_reason}, qr/REASON FOR EXPORT.*${export_reason_prefix} Returned Goods Rejected by Customer/i,
                                "Reason For Export as Expected" );

    _check_general_footer( $doc_data->{footer}, $channel, $branding );

    return;
}

# check the Invoice
sub _check_invoice {
    my ( $schema, $branding, $shipment, $print_doc, $print_dir )    = @_;

    note "Looking at Invoice file";

    my $channel     = $shipment->order->channel;
    my $doc_data    = $print_doc->as_data();

    my $shipping_email  = shipping_email( $channel->business->config_section );

    is( $doc_data->{document_heading}, $branding->{$BRANDING__DOC_HEADING},
                        "The Document Header is shown correctly" );

    like( $doc_data->{duties_and_taxes}, qr/$branding->{$BRANDING__PF_NAME} pays these/,
                        "'DUTIES & TAXES' section shows correct Public Facing Name for the Sales Channel" );
    like( $doc_data->{duties_and_taxes}, qr/on $shipping_email, as/,
                        "'DUTIES & TAXES' section show correct Shipping Email Address" );

    # check the 'Invoice Date' is as it should be
    my $expected    = $channel->business->branded_date( $shipment->renumerations->first->get_invoice_date );
    is( $doc_data->{invoice_details}{overview}{'Invoice Date'}, $expected,
                                            "'Invoice Date' shown in document is in the correct format" );

    _check_general_footer( $doc_data->{footer}, $channel, $branding );

    return;
}


# checks the general footer on most documents
sub _check_general_footer {
    my ( $footer, $channel, $branding )     = @_;

    my $conf_section    = $channel->business->config_section;

    my $email_address   = customercare_email( $conf_section );
    my $contact_hours   = comp_contact_hours( $conf_section );
    my $comp_addr       = comp_addr( $conf_section );
    my $cc_tel          = comp_tel( $conf_section );

    like( $footer, qr/\Q${comp_addr}\E.*NEED HELP/i, "Footer: Company Address shown correctly" );
    like( $footer, qr/NEED HELP.*\Q${email_address}\E/i, "Footer: Customer Care Email Address shown correctly" );
    like( $footer, qr/NEED HELP.*\Q${cc_tel}\E/i, "Footer: Customer Care Phone Number shown correctly" );
    like( $footer, qr/NEED HELP.*\Q${contact_hours}\E/i, "Footer: Contact Hours shown correctly" );

    return;
}

# creates an order
sub _create_an_order {

    my $args    = shift;

    my $item_tax    = $args->{item_tax} || 50;
    my $item_duty   = $args->{item_duty} || 0;

    note "Creating Order";

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 1,
        channel => $args->{channel},
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
    {
        my $sa = $pids->[0]{product}->shipping_attribute;
        if (!$sa->fabric_content) {
            $sa->update({fabric_content => 'nasty stuff'});
        }
    }
    my @pids_to_use;
    push @pids_to_use, $pids->[0]       if ( $args->{normal_pid} );
    push @pids_to_use, $pids->[1]       if ( $args->{phys_vouch} );
    push @pids_to_use, $pids->[2]       if ( $args->{virt_vouch} );

    my $currency        = $args->{currency} || config_var('Currency', 'local_currency_code');

    my $currency_id     = get_currency_id( Test::XTracker::Data->get_schema->storage->dbh, $currency );
    my $carrier_name    = ( $channel->is_on_dc( 'DC2' ) ? 'UPS' : config_var('DistributionCentre','default_carrier') );
    my $ship_account = Test::XTracker::Data->find_shipping_account({
        carrier    => $carrier_name,
        channel_id => $channel->id,
    });
    my $address = Test::XTracker::Data->create_order_address_in(
        "current_dc_premier",
        { country => $args->{country} },
    );

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $base = {
        customer_id          => $customer->id,
        currency_id          => $currency_id,
        channel_id           => $channel->id,
        shipment_type        => $SHIPMENT_TYPE__INTERNATIONAL,
        shipment_status      => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__PACKED,
        shipping_account_id  => $ship_account->id,
        invoice_address_id   => $address->id,
        gift_shipment        => ( exists( $args->{gift_shipment} ) ? $args->{gift_shipment} : 1 ),
        create_renumerations => 1,
    };
    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => \@pids_to_use,
        base => $base,
        attrs => [
            { price => 100.00, tax => $item_tax, duty => $item_duty },
        ],
    });

    my $shipment    = $order->get_standard_class_shipment;
    my $invoice     = $shipment->renumerations->first;
    $invoice->update_status( $invoice->renumeration_status_id, $APPLICATION_OPERATOR_ID );

    my @ship_items  = $shipment->shipment_items->all;
    foreach my $item ( @ship_items ) {
        $item->update( { tax => $item_tax } );
        $item->create_related( 'renumeration_items', {
                                        renumeration_id => $invoice->id,
                                        unit_price      => $item->unit_price,
                                        tax             => $item->tax,
                                        duty            => $item->duty,
                                    } );
    }

    # add a Box to the Shipment
    $shipment->create_related( 'shipment_boxes', {
                                        box_id  => $channel->boxes->first->id,
                                    } );

    # update some dates so they are not 'today' for future tests
    $order->update( { date => $order->date->subtract( days => 1 ) } );
    $shipment->update( { date => $order->date, return_airway_bill => '2222222222' } );

    return $order;
}

# defines a set of commands to be used by a DBiC connection
sub _define_dbic_resultset {

    my $schema      = shift;

    my $resultset   = {};

    $resultset->{ps_name}       = sub {
            my $rs  = $schema->resultset('SystemConfig::ConfigGroup');
            my $rec = $rs->search( { name => { 'ilike' => 'PackingStation_%' } } )->first;
            return ( $rec ? $rec->name : '' );
        };
    $resultset->{outpro_country}= sub {
        return Test::XTracker::Data::Country->proforma_countries->first->country;
    };

    return $resultset;
}

# returns a Document and a Label Printer name
sub _get_printer_names {
    my $schema  = shift;

    my $printers    = get_shipping_printers( $schema );
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

    return ( $document_printer_name, $label_printer_name );
}
