package Test::NAP::Packing;

use NAP::policy "tt", 'test';

use FindBin::libs;
use parent 'NAP::Test::Class';

use XTracker::Config::Local qw/
    config_var
    get_packing_station_printers
/;
use XTracker::PrintFunctions qw/
    get_printer_by_name
    print_ups_label
/;
use Test::XTracker::Data;

use Test::XTracker::PrintDocs;
use Test::XTracker::Artifacts::Labels;
use XTracker::Database::Order 'get_order_info';
use XTracker::Database::Shipment qw/
    check_country_paperwork
    get_country_info
    get_order_shipment_info
    get_shipment_boxes
    get_shipment_box_labels
    get_shipment_info
    get_shipment_item_info
/;
use XTracker::Database::Address 'get_address_info';
use XTracker::Database::OrderPayment;
use XTracker::Database::Profile 'get_operator_preferences';
use XTracker::Order::Actions::UpdateShipmentAirwaybill;
use XTracker::Order::Fulfilment::PackShipment;

use XTracker::Printers;
use XTracker::Printers::Populator;

use Test::XTracker::Mock::DHL::XMLRequest;
use Test::XTracker::Mock::Handler;

use XTracker::Constants::FromDB qw/
    :shipment_item_status
    :shipment_status
    :shipment_type
/;
use XTracker::Constants ':application';
use XTracker::Order::Printing::ShipmentDocuments qw/
    generate_shipment_paperwork
    print_shipment_documents
/;

sub startup : Tests(startup) {
    my ( $self ) = @_;
    $self->SUPER::startup;
    isa_ok( $self->{schema} = Test::XTracker::Data->get_schema, 'XTracker::Schema' );

    XTracker::Printers::Populator->new->populate_if_updated;
}

sub test_packing_stations : Tests {
    my ( $self ) = @_;

    unless ( config_var('Fulfilment','requires_packing_station') ) {
        diag "skipping test_packing_stations_in_db - not in a DC Environment that requires a packing station";
        return;
    }

    my $channel_rs = Test::XTracker::Data->get_enabled_channels->search(undef,{ order_by => 'me.id' });
    for my $channel ( $channel_rs->all ) {
        my $ps_list_rs = $channel->search_related('config_groups',
            { 'me.name' => 'PackingStationList', 'me.active' => 1 }
        );
        is( $ps_list_rs->count, 1, $channel->name . ' has just one packing station list' );
        my @ps_names = $ps_list_rs->search_related('config_group_settings',
            { setting => 'packing_station', 'config_group_settings.active' => 1, },
            { order_by => 'sequence' }
        )->get_column('value')
        ->all;
        ok( @ps_names, $channel->name . ' has at least one packing station' );
        # Loop using map (i.e. many sql calls) to preserve sequence
        my $config_group_rs = $self->{schema}->resultset('SystemConfig::ConfigGroup');
        # We are taking a leap of faith and assuming that each packing station
        # entry in config_group_setting will have just one matching value in
        # config_group... which may not be strictly speaking true. If it isn't
        # find will warn, but we won't get a failing test
        for my $packing_station ( map { $config_group_rs->find({ name => $_ }) } @ps_names ) {
            ok( $packing_station->active,
                sprintf 'active packing station setting (%s) has matching active group', $packing_station->name
            );
            $self->_check_for_valid_printer_config($packing_station);
        }
    }
}

sub _check_for_valid_printer_config {
    my ($self, $packing_station) = @_;

    # A valid packing station must have either...

    # A doc_printer and a lab_printer (Standard Packlane)
    if(
        $self->_check_for_printer_type($packing_station, 'doc_printer')
        &&
        $self->_check_for_printer_type($packing_station, 'lab_printer')
    ) {
        pass('Valid standard packing station config');
        return 1;
    }

    # Or a doc_printer and a card_printer (Premier-Only Packlane)
    if(
        $self->_check_for_printer_type($packing_station, 'doc_printer')
        &&
        $self->_check_for_printer_type($packing_station, 'card_printer')
    ) {
        pass('Valid premier packing station config');
        return 1;
    }

    fail('Does not fit any known valid configuration');
    return 0;
}

sub _check_for_printer_type {
    my ($self, $packing_station, $printer_type) = @_;

    my @ps_settings = $packing_station->search_related('config_group_settings',
        { setting => $printer_type, active => 1 }
    )->all;

    return 0 unless @ps_settings > 0;

    is( @ps_settings, 1, $packing_station->name . " has just one active $printer_type" );

    return 1;
}

=head2 test_shipment_paperwork

This tests a few functions involved in the packing of an automated shipment
particulary the 'generate_shipment_paperwork' to make sure the paperwork is
being printed properly.

=cut

# Note that this test has been refactored quite a bit, and this should be
# broken up further into separate unit tests to provide better coverage.
sub test_shipment_paperwork : Tests {
    my ( $self ) = @_;

    my $schema  = $self->{schema};
    my $dbh     = $schema->storage->dbh;

    my $operator_id = $APPLICATION_OPERATOR_ID;
    my $operator = $schema->resultset('Public::Operator')->find($operator_id);
    my $operator_preference = $operator->update_or_create_preferences({
        packing_station_name => $self->get_packing_station_name
    });

    foreach my $test_name (
        # generate_shipment_paperwork requires a packing station (and
        # update_airwaybill calls that method too) - currently just DC1 doesn't
        # have one.
        (
            $self->get_packing_station_name
          ? (qw/update_airwaybill generate_shipment_paperwork/)
          : ()
        ),
        # labelling fails on DC2 (it wasn't enabled in the first place) - not
        # sure why :/
        (config_var(qw/DistributionCentre name/) eq 'DC2' ? () : 'labelling')
    ) {
        subtest "test $test_name" => sub {
            my $shipment = $self->create_a_shipment;
            note 'created shipment ', $shipment->id;

            # Create a renumeration entry referencing this shipment so we can
            # test an invoice gets printed for it later
            $self->create_renumeration($shipment);

            # Update items' statuses to packed
            $shipment->shipment_items->update({
                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED
            });

            # Assign a box to the shipment so our labels get printed
            $self->assign_box_to_shipment($shipment, $operator_id);

            $self->test_labels($shipment, $operator_id);

            if ( $test_name eq "generate_shipment_paperwork" ) {
                my ( $out_awb, $ret_awb ) = Test::XTracker::Data->generate_air_waybills;
                $shipment->update({
                    outward_airway_bill => $out_awb,
                    return_airway_bill  => $ret_awb,
                });

                # generate the shipping paperwork and then we'll have look to see if the necessary files have been generated
                generate_shipment_paperwork( $dbh, {
                    shipment_id      => $shipment->id,
                    shipping_country => $shipment->shipment_address->country,
                    packing_station  => $operator_preference->packing_station_name,
                } );

                # check outward & return labels have been printed and logged
                $self->check_labels_printed( $shipment, 1 );
                $self->check_documents_printed( $shipment );
                return;
            }

            if ( $test_name eq "update_airwaybill" ) {
                my ($location) = map { $_->name }
                    XTracker::Printers->new
                        ->locations_for_section(
                        'airwaybill'
                    ) or die "Could not find airwaybill printer";

                $operator->update_or_create_preferences({printer_station_name => $location});

                my ( $out_awb, $ret_awb ) = Test::XTracker::Data->generate_air_waybills;
                XTracker::Order::Actions::UpdateShipmentAirwaybill::_update_airwaybill(
                    $shipment, $out_awb, $ret_awb, $operator
                );
                # check outward & return labels have NOT been printed and logged
                $self->check_labels_printed( $shipment, 0 );
                $self->check_documents_printed( $shipment );
                return;
            }

            if ( $test_name eq "labelling" ) {
                # Set-Up for gift Messages
                $shipment->update({ gift => 1, gift_message => 'This is a Gift Message' });

                # assign return AWB
                my ($ret_awb) = Test::XTracker::Data->generate_air_waybills;
                my $handler = $self->create_mock_handler(
                    $shipment, $operator_id,
                    { param_of => { return_waybill => $ret_awb } },
                );
                XTracker::Order::Fulfilment::PackShipment::_assign_awb( $handler );

                # set up the mocked call to DHL to retrieve shipment validate XML response
                my $dhl_label_type = 'dhl_shipment_validate';
                my $mock_data = Test::XTracker::Mock::DHL::XMLRequest->new(
                    data => [ { dhl_label => $dhl_label_type }, ]
                );
                my $xmlreq = Test::MockModule->new( 'XTracker::DHL::XMLRequest' );
                $xmlreq->mock( send_xml_request => sub { $mock_data->$dhl_label_type } );

                my $expected_docs = { invoice => 1, retpro => 1 };
                $expected_docs->{giftmessagewarning} = 1
                    if $shipment->requires_gift_message_warning;

                my $print_directory = Test::XTracker::PrintDocs->new;
                print_shipment_documents(
                    $dbh, $shipment->shipment_boxes->first->id,
                );

                my %found_docs = map { $_->file_type => 1 } $print_directory->new_files;

                is_deeply(\%found_docs, $expected_docs, 'should find correct shipment documents');

                my $label_directory = Test::XTracker::Artifacts::Labels->new;
                $label_directory->non_empty_file_exists_ok(
                    $shipment->shipment_boxes->first->id.'.lbl',
                    'box label file should not be empty'
                );

                # check outward & return labels have NOT been printed and logged
                $self->check_labels_printed( $shipment, 0 );

                $self->check_documents_printed( $shipment );
                return;
            }
        };
    }
}

=head2 create_renumeration($shipment) :

Create a renumeration row for the given shipment.

=cut

sub create_renumeration {
    my ( $self, $shipment ) = @_;

    my $schema = $shipment->result_source->schema;
    my $dbh    = $schema->storage->dbh;
    my $order  = $shipment->order;

    my $order_info = get_order_info($dbh, $order->id);
    my $shipments  = get_order_shipment_info($dbh, $order->id);
    # This method is slightly misnamed - what it does is create a
    # 'renumeration' entry in the database - not the invoice document.
    # We need this so we can test that generate_shipment_documents
    # prints an invoice - without a renumeration it doesn't print one
    XTracker::Database::OrderPayment::_create_invoice(
        $schema, $shipment->id, $shipments, $order_info
    );
}

=head2 test_labels($shipment, $operator_id) :

Perform a few label tests on the given shipment.

=cut

sub test_labels {
    my ( $self, $shipment, $operator_id ) = @_;

    # Check that there are shipment box labels
    my $schema = $shipment->result_source->schema;
    my $shipment_box_labels = get_shipment_box_labels(
        $schema->storage->dbh, $shipment->id
    );
    cmp_ok( @{$shipment_box_labels}, ">", 0, "Shipment Box Labels Found" );

    # get the first label
    my $shipment_box_label = $shipment_box_labels->[0];
    for my $box ( $shipment->shipment_boxes ) {
        my $box_id = $shipment_box_label->{box_id};
        is(
            $shipment_box_label->{box_id},
            $box_id,
            "Found Label for Box Id: $box_id at correct Position in Array: 0"
        );

        for my $label_type (qw/outward return/) {
            is(
                $shipment_box_label->{"${label_type}_label"},
                uc($label_type) . " IMAGE DATA: ".$box_id,
                "found correct $label_type label data for box id: $box_id"
            );

            # These tests only apply to UPS shipments. However we can
            # test print_ups_label with DHL shipments too... as we're
            # only creating DHL shipments we don't really need to
            # restrict these tests
            my $packing_station_name = $schema->resultset('Public::OperatorPreference')
                ->find({operator_id => $operator_id})
                ->packing_station_name;

            next unless $packing_station_name;

            my $label_printer = get_packing_station_printers(
                $schema, $packing_station_name
            )->{label};
            my $res = print_ups_label({
                prefix     => $label_type,
                unique_id  => $box_id,
                label_data => $shipment_box_label->{"${label_type}_label"},
                printer    => $label_printer,
            });
            is( $res, 1, "printed $label_type label for box: $box_id on printer: $label_printer" );

            my $label_directory = Test::XTracker::Artifacts::Labels->new;
            $label_directory->non_empty_file_exists_ok(
                "$label_type-$box_id.lbl",
                "$label_type label file should be created for box $box_id"
            );
            # remove the files for later tests
            $label_directory->delete_file( "$label_type-$box_id.lbl" );
        }
    }
}

=head2 assign_box_to_shipment($shipment, $operator_id) :

Assign a box to the given shipment.

=cut

sub assign_box_to_shipment {
    my ( $self, $shipment, $operator_id ) = @_;

    # Assign a box to the shipment
    my $outer_box = $self->get_outer_box($shipment->get_channel->id);
    my $inner_box = $outer_box->inner_boxes
        ->search(undef, { order_by => 'id', rows => 1 })
        ->single;

    my $handler = $self->create_mock_handler(
        $shipment, $operator_id,
        {
            param_of => {
                outer_box_id => $outer_box->id,
                inner_box_id => $inner_box->id,
                shipment_box_id => Test::XTracker::Data->get_next_shipment_box_id,
            }
        }
    );
    XTracker::Order::Fulfilment::PackShipment::_assign_box( $handler );
    is( $shipment->shipment_boxes->count(), 1, "Shipment Box Found" );

    # test you can't/can see shipment box labels
    my $labels    = get_shipment_box_labels(
        $shipment->result_source->storage->dbh, $shipment->id
    );
    ok( !@$labels, "No Shipment Box Labels Found" );

    $_->update({
        outward_box_label_image => 'OUTWARD IMAGE DATA: '.$_->id,
        return_box_label_image  => 'RETURN IMAGE DATA: '.$_->id,
    }) for $shipment->shipment_boxes;

    return;
}

=head2 get_outer_box($channel_id) : $outer_box_row

Get the outer box for the given C<$channel_id>.

=cut

sub get_outer_box {
    my ( $self, $channel_id ) = @_;

    return $self->schema->resultset('Public::Box')
        ->search({ box => 'Outer 3', channel_id => $channel_id }, { rows => 1 })
        ->single || die "Couldn't find box for channel $channel_id";
}

=head2 check_documents_printed($shipment) :

Tests that the invoice and proformas were printed.

=cut

sub check_documents_printed {
    my ( $self, $shipment ) = @_;

    my $print_directory = Test::XTracker::PrintDocs->new;

    $print_directory->non_empty_file_exists_ok(
        'invoice-'.$shipment->renumerations->first->id.'.html',
        'should find invoice document'
    );

    # find out which proformas to expect
    my ( $num_proforma, $num_returns_proforma ) = check_country_paperwork(
        $shipment->result_source->schema->storage->dbh,
        $shipment->shipment_address->country
    );
    $print_directory->non_empty_file_exists_ok(
        'outpro-'.$shipment->id.'.html',
        'should find outward proforma'
    ) if $num_proforma;
    $print_directory->non_empty_file_exists_ok(
        'retpro-'.$shipment->id.'.html',
        'should find return proforma'
    ) if $num_returns_proforma;
}

=head2 create_mock_handler($shipment, $operator_id) : $mock_handler

Creates a mock handler pre-populated with shipment data.

=cut

sub create_mock_handler {
    my ( $self, $shipment, $operator_id, $args ) = @_;

    my $channel = $shipment->get_channel;
    my $schema = $shipment->result_source->schema;
    my $dbh = $schema->storage->dbh;

    return Test::XTracker::Mock::Handler->new({
        operator_id => $operator_id,
        data => {
            shipment_id         => $shipment->id,
            sales_channel       => $channel->name,
            sales_channel_id    => $channel->id,
            shipment_info       => get_shipment_info( $dbh, $shipment->id ),
            shipment_boxes      => get_shipment_boxes( $dbh, $shipment->id ),
            shipment_item_info  => get_shipment_item_info( $dbh, $shipment->id ),
            shipment_address    => get_address_info( $schema, $shipment->shipment_address_id ),
            shipping_country    => get_country_info( $dbh, $shipment->shipment_address->country ),
            preferences         => get_operator_preferences( $dbh, $operator_id ),
        },
        %{$args//{}},
    });
}

=head2 get_packing_station_name

Get any packing station.

=cut

# Copypasted from t/30-functional/other/class/Test/NAP/Packing.pm
sub get_packing_station_name {
    my ( $self ) = @_;
    my $row = $self->{schema}->resultset('SystemConfig::ConfigGroup')
        ->search( { name => { 'ilike' => 'PackingStation\\_%' } } )
        ->slice(0,0)
        ->single;

    return ( $row ? $row->name : q{} );
}

# Adapted from t/30-functional/other/class/Test/NAP/Packing.pm
sub create_a_shipment {
    my $self = shift;

    my ( $channel, $pids ) = Test::XTracker::Data->grab_products({ force_create => 1 });

    my $address      = Test::XTracker::Data->create_order_address_in('current_dc_premier');
    my $ship_account = Test::XTracker::Data->find_shipping_account({
        channel_id => $channel->id,
    });

    my $base = {
        channel_id           => $channel->id,
        shipment_status      => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id  => $ship_account->id,
        invoice_address_id   => $address->id,
    };

    my ($order) = Test::XTracker::Data->create_db_order({ pids => $pids, base => $base, });
    my $shipment = $order->get_standard_class_shipment;
    # Ugly hack - basically sometimes the destination code gets unset...
    # weirdness - let's explicitly set it here and this test should stop
    # failing intermittently. Should be only temporary until we make changes to
    # the carrier automation code and we can drop this column altogether
    $shipment->update({destination_code => 'LCY'});

    return $shipment;
}

=head2 check_labels_printed($shipment, $should_exist) :

Goes through shipment boxes and checks labels have been created and logged
or haven't depending on C<$should_exist>.

=cut

sub check_labels_printed {
    my ( $self ) = shift;
    my ( $shipment, $should_exist ) = @_;

    my $print_directory = Test::XTracker::PrintDocs->new;

    for my $box ( $shipment->shipment_boxes->all ) {
        my $box_id = $box->id;
        for (
            [ 'outward label' => "outward-$box_id.lbl" ],
            [ 'return label'  => "return-$box_id.lbl" ],
        ) {
            my ( $label_type, $file_name ) = @$_;
            subtest "test $label_type for box $box_id" => sub {
                my $log = $shipment->shipment_print_logs->search(
                    { file => $file_name },
                    { rows => 1 }
                )->single;

                if ( $should_exist ) {
                    ok( $log, "$label_type found in log" );
                    $print_directory->non_empty_file_exists_ok(
                        $file_name, "$file_name should be created"
                    );

                    # delete files for future tests
                    $print_directory->delete_file($file_name);
                }
                else {
                    ok( !$log, "no $label_type in log" );
                    $print_directory->file_not_present_ok(
                        $file_name, "$file_name should not be created"
                    );
                }
            }
        }
    }
}
