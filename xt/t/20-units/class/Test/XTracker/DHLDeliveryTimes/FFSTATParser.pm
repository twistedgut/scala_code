package Test::XTracker::DHLDeliveryTimes::FFSTATParser;

use FindBin::libs;

use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

use Test::XTracker::Data;
use Test::MockModule;
use XTracker::DHLDeliveryTimes::FFSTATParser;
use XTracker::Config::Local 'config_var';
use Data::UUID;
use DateTime;
use Test::XTracker::Data::FFSTATParserSampleFile 'get_sample_data';
use XTracker::Constants::FromDB qw(
    :shipment_status
    :shipment_item_status
    :shipment_class
    :shipment_type
);

sub startup : Tests(startup) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{dhl_rs} = $self->{schema}->resultset('Public::DHLDeliveryFile');

}

sub setup : Tests(setup) {
    my $self = shift;
    $self->SUPER::setup;
    $self->{dhl_rs}->search()->delete();
}

sub get_remaining_count :Tests() {
    my $self = shift;

    my $dhl_rs = $self->{dhl_rs};

    # insert 5 records, 3 processed and 2 unprocessed
    # make sure the answer is 2.

    my $test_data = [
        { filename => 'a', remote_modification_epoch => 1, processed => 0 },
        { filename => 'b', remote_modification_epoch => 1, processed => 1 },
        { filename => 'c', remote_modification_epoch => 1, processed => 0 },
        { filename => 'd', remote_modification_epoch => 1, processed => 1 },
        { filename => 'e', remote_modification_epoch => 1, processed => 1 },
    ];

    my @test_rows;

    foreach my $test_row (@$test_data) {
        my $row = $dhl_rs->create($test_row);
        push(@test_rows, $row);
    }

    my $test_result = $dhl_rs->get_remaining_count();
    is($test_result, 2, 'Ensure unprocessed count is accurate (2 in this case)');

    # process a new record.. check it's still accurate.
    $test_rows[0]->mark_as_processed_ok();

    $test_result = $dhl_rs->get_remaining_count();
    is($test_result, 1, 'Ensure unprocessed count is accurate after update (1 in this case)');

    # mark one as a permanent failure... check that's reflected too
    $test_rows[2]->mark_as_processed_ok();

    $test_result = $dhl_rs->get_remaining_count();
    is($test_result, 0, 'Ensure unprocessed count is accurate after max failure on last record');

}

sub file_exists_locally_test :Tests() {
    my $self = shift;

    my $dhl_rs = $self->{dhl_rs};

    my $test_row = $dhl_rs->create({
        filename => Data::UUID->new->create_hex,
        remote_modification_epoch => 1,
        processed => 0
    });

    note("performing file_exists_locally_tests on file ". $test_row->get_absolute_local_filename());

    # check path first file doesn't exist.
    ok(!$test_row->file_exists_locally(), 'file_exists_locally() returns false when file not present');

    open(my $fh, '>', $test_row->get_absolute_local_filename())
        || die(0, "Failed to write temp file\n");
    print $fh "some data";
    close($fh);

    ok($test_row->file_exists_locally(), 'file_exists_locally() returns true when file is on disk');

    # delete it!
    $test_row->delete_file();

    ok(!$test_row->file_exists_locally(), 'delete_file works');
}

sub process_files_loops_ok_test :Tests() {
    my $self = shift;
    my $dhl_rs = $self->{dhl_rs};

    my $test_data = [
        { filename => 'file1', remote_modification_epoch => 1, processed => 0 },
        { filename => 'file2', remote_modification_epoch => 2, processed => 0 },
        { filename => 'file3', remote_modification_epoch => 3, processed => 0 },
    ];
    $dhl_rs->create($_) foreach @$test_data;

    my $mock_sftp = Test::MockModule->new('XTracker::DHLDeliveryTimes::SFTPMonitor');
    $mock_sftp->mock('download_file', sub { });

    my $i = 0;
    my $process_attempts = 0;

    my $ffstat_mock = Test::MockModule->new('XTracker::DHLDeliveryTimes::FFSTATParser');
    $ffstat_mock->mock('process_file', sub {
        my ($self, $file) = @_;

        note("entered process_file sub for " . $file->filename);
        # ensure file passed in is the one we expected.
        is($test_data->[$i]->{filename}, $file->filename, 'File to process is the one expected: ' . $file->filename);
        $i++;
        $process_attempts++;
    });

    my $ffstat_parser = XTracker::DHLDeliveryTimes::FFSTATParser->new();
    $ffstat_parser->process_files();

    is($process_attempts, 3, 'Expect 3 files to be processed');

}

sub process_file_requests_download_test :Tests() {
    my $self = shift;
    my $dhl_rs = $self->{dhl_rs};

    my $test_data = [
        { filename => 'test_a.txt', remote_modification_epoch => 1, processed => 0 },
        { filename => 'test_b.txt', remote_modification_epoch => 2, processed => 0 },
        { filename => 'test_c.txt', remote_modification_epoch => 3, processed => 0 },
        { filename => 'test_d.txt', remote_modification_epoch => 4, processed => 0 },
    ];
    $dhl_rs->create($_) foreach @$test_data;

    my $download_attempts = 0;
    my $i = 0;

    my $mock_sftp = Test::MockModule->new('XTracker::DHLDeliveryTimes::SFTPMonitor');
    $mock_sftp->mock('download_file', sub {
        my ($self, $file) = @_;

        note("entered download_file sub for " . $file->filename);
        is($test_data->[$i]->{filename}, $file->filename, 'File to download is one expected: '. $file->filename);
        $i++;
        $download_attempts++;
    });

    my $mock_ffstat = Test::MockModule->new('XTracker::DHLDeliveryTimes::FFSTATParser');
    $mock_ffstat->mock('process_file', sub {});

    # prepare parser with mock downloader...
    my $ffstat_parser = XTracker::DHLDeliveryTimes::FFSTATParser->new();
    $ffstat_parser->process_files();

    is($download_attempts, 4, 'Expect 4 files to be requested for download');

}

sub expand_timestamp_str :Tests() {
    my $self = shift;

    my $ffstat_parser = XTracker::DHLDeliveryTimes::FFSTATParser->new();

    my $date_parsed = $ffstat_parser->_expand_timestamp_str('201301010900', '+1:00');
    is($date_parsed->ymd, '2013-01-01', 'ymd parsed correct');
    isnt($date_parsed->time_zone(), 'floating', 'datetime is not in the floating timezone');
    is($date_parsed->hms, '09:00:00', 'hms parsed correctly');
    $date_parsed->set_time_zone('UTC');
    is($date_parsed->hms, '08:00:00', '9 am (+1:00) timezone translates to UTC correctly (aka 8am)');

    my $tz_parsed = $ffstat_parser->_expand_timestamp_str('201301010800', '+3:00');
    my $expected = $self->_utc_dt(2013, 1, 1, 5, 0, 0);
    is($tz_parsed->compare($expected), 0, 'datetime object has accurate timezone (8am +3:00)');

    my $tz_parsed_2 = $ffstat_parser->_expand_timestamp_str('201301010800', '-5:30');
    my $expected_2 = $self->_utc_dt(2013, 1, 1, 13, 30, 0);
    is($tz_parsed_2->compare($expected_2), 0, 'datetime object has accurate timezone (8am -5:30)');
}

sub process_sample_data_file :Tests() {
    my $self = shift;
    my $dhl_rs = $self->{dhl_rs};

    # we keep a preparsed version of the sample data here
    my $sample_data = get_sample_data();

    # override the default location and allow the in-place processing
    # of real data files...
    my $mock_file = Test::MockModule->new('XTracker::Schema::Result::Public::DHLDeliveryFile');
    $mock_file->mock('get_absolute_local_filename', sub {
        return 't/data/dhl_delivery_file/'. shift->filename;
    });
    $mock_file->mock('delete_file', sub {});

    my $test_row = $dhl_rs->create({
        filename => 'sample_ffstat_file',
        remote_modification_epoch => '0001',
        processed => 0
    });

    my $row_num = 0;

    my $mock_parser = Test::MockModule->new('XTracker::DHLDeliveryTimes::FFSTATParser');

    $mock_parser->mock('update_shipment_status_log', sub {
        my ($self, $order_nr, $dhl_status, $air_waybill, $event_time) = @_;

        # check it matches the preparsed version
        my $correct_results = $sample_data->[$row_num];

        is($order_nr, $correct_results->{order_nr}, "Order number parsed correctly (row: $row_num, order_nr: $order_nr)");
        is($air_waybill, $correct_results->{air_waybill}, "Air Waybill parsed correctly (row: $row_num, order_nr: $order_nr)");

        # test data is in UTC, convert h/m/s to standardised
        $event_time->set_time_zone('UTC');

        my $parsed_timestamp = sprintf("%04d%02d%02d%02d%02d",
            $event_time->year,
            $event_time->month,
            $event_time->day,
            $event_time->hour,
            $event_time->minute
        );

        is($parsed_timestamp, $correct_results->{timestamp}, "Timestamp parsed correctly (row: $row_num)");
        is($dhl_status, $correct_results->{dhl_status}, 'DHL Status parsed correctly');

        $row_num++;

    });

    my $ffstat_parser = XTracker::DHLDeliveryTimes::FFSTATParser->new();
    $ffstat_parser->process_files();

    is($row_num, 66, "All 66 records in CSV parsed (got $row_num)");

}

sub shipment_status_log_test :Tests() {
    my $self = shift;
    my $dhl_rs = $self->{dhl_rs};

    my $order = $self->_create_order;

    my $order_nr = $order->order_nr;
    my $shipment = $order->shipments->single;
    $shipment->discard_changes;

    my $dt = DateTime->new(
        year   => 2013,
        month  => 4,
        day    => 15,
        hour   => 5,
        minute => 2
    );

    my $air_waybill = Data::UUID->new->create_hex;
    $shipment->update({
        outward_airway_bill => $air_waybill
    });

    my $ffstat_parser = XTracker::DHLDeliveryTimes::FFSTATParser->new();

    $ffstat_parser->update_shipment_status_log(
        $order_nr,
        'OK',
        $air_waybill,
        $dt
    );

    note("looking up order_nr: $order_nr, shipment id: ". $shipment->id);

    # lets check our record is present
    my $result = $shipment->search_related('shipment_status_logs', {
        shipment_status_id => $SHIPMENT_STATUS__DELIVERED,
    })->single();

    ok($result, 'Completion Record written to shipment status log');
    ok($result->date() eq $dt, 'Timestamp for Completion Event log entry record matches CSV directly')
        if defined($result);

}

sub shipment_status_for_delivery_attempted_logged :Tests() {
    my $self = shift;
    my $dhl_rs = $self->{dhl_rs};

    my $order = $self->_create_order;

    my $order_nr = $order->order_nr;
    my $shipment = $order->shipments->single;
    $shipment->discard_changes;

    my $dt = DateTime->new(
        year   => 2013,
        month  => 4,
        day    => 15,
        hour   => 5,
        minute => 2
    );

    my $air_waybill = Data::UUID->new->create_hex;
    $shipment->update({
        outward_airway_bill => $air_waybill
    });

    my $ffstat_parser = XTracker::DHLDeliveryTimes::FFSTATParser->new();

    $ffstat_parser->update_shipment_status_log(
        $order_nr,
        'NH', # NH (Not Home) results in "delivery attempted" status
        $air_waybill,
        $dt
    );

    note("looking up order_nr: $order_nr, shipment id: ". $shipment->id);

    # lets check our record is present
    my $result = $shipment->search_related('shipment_status_logs', {
        shipment_status_id => $SHIPMENT_STATUS__DELIVERY_ATTEMPTED
    })->single();

    ok($result, 'Completion Record (Delivered Attempted) written to shipment status log');
}

sub _create_order {
    my $self = shift;

    my $channel_id = $self->{schema}->resultset('Public::Channel')->search({
        name => 'NET-A-PORTER.COM'
    }, {
        rows => 1,
        order_by => 'id'
    })->single->id;

    my $default_carrier = config_var('DistributionCentre','default_carrier');
    my $ship_account = Test::XTracker::Data->find_shipping_account({
        channel_id => $channel_id,
        carrier => $default_carrier."%"
    });
    my $pids = Test::XTracker::Data->find_or_create_products({
        channel_id => $channel_id,
        how_many => 2
    });
    my $customer = Test::XTracker::Data->find_customer({
        channel_id => $channel_id
    });

    my $order_args  = {
        customer_id => $customer->id,
        channel_id  => $channel_id,
        items => {
            $pids->[0]{sku} => { price => 100.00 },
        },
        shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__DISPATCHED,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__DISPATCHED,
        shipping_account_id => $ship_account->id,
        invoice_address_id => Test::XTracker::Data->create_order_address_in('current_dc_premier')->id,
        shipping_charge_id => 4,
        dhl_destination => 'LHR',
        av_quality_rating => '1.0',
    };

    my ($order) = Test::XTracker::Data->create_db_order($order_args);
    return $order;
}

sub _utc_dt {
    my ($self, $yr, $mon, $day, $hr, $min) = @_;

    return DateTime->new(
        year      => $yr,
        month     => $mon,
        day       => $day,
        hour      => $hr,
        minute    => $min,
        second    => 0,
        time_zone => 'UTC'
    );
}
