package Test::XTracker::Script::Extract::ESP;
use NAP::policy "tt",     'test';

use parent "NAP::Test::Class";

=head1 NAME

Test::XTracker::Script::Extract::ESP

=head1 DESCRIPTION

This tests the Script used to generate the feed for our ESP (Email Service Provider) Responsys.

=cut

use Test::File;

use Test::XT::Data;
use Test::XTracker::Artifacts::OutputFile;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :shipment_class
                                        :shipment_status
                                        :shipment_item_status
                                    );

use XTracker::Script::Extract::ESP;

use DateTime;


# this is done once, when the test starts
sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{dc_instance}    = config_var('XTracker','instance');

    $self->{output_path}    = config_var( 'SystemPaths', 'esp_base_dir' )
                              . '/'. config_var( 'ESP_Responsys', 'waiting_subdir' );

    $self->{extract_dir}    = $self->_setup_directory_reader( $self->{output_path} );
    $self->{extract_dir}->purge_directory_of_files;

    # expected field headers which should be the first row in the files
    $self->{field_headers}  = [ qw(
                            CHANNEL
                            CUSTOMERNUM
                            ORDERNUM
                            ORDERDATE
                            ORDERVALUE
                            ORDERCURRENCY
                            DISPATCHDATE
                            SHIPPINGCITY
                            SHIPPINGSTATE
                            SHIPPINGPOSTALCODE
                            SHIPPINGCOUNTRY
                            DATE
                        ) ];

    # setup dates that are in and outside of the
    # boundary that the script works from which is
    # yesterday's data
    my $now = $self->{schema}->db_now;
    $self->{date_start} = $now->clone->subtract( days => 1 )
                                        ->truncate( to => 'day' );
    $self->{date_end}   = $self->{date_start}->clone->add( days => 1 );

    # create a few dates inside the date range of the main query
    $self->{date_inside_range1} = $self->{date_start}->clone->add( hours => 8, minutes  => 59, seconds => 59  );
    $self->{date_inside_range2} = $self->{date_start}->clone->add( hours => 9, minutes => 59, seconds => 59 );
    $self->{date_inside_range3} = $self->{date_start}->clone->add( hours => 12, minutes => 59, seconds => 59 );

    # create some dates outside of the date range
    $self->{date_before_range}  = $now->clone->subtract( days => 2 );
    $self->{date_after_range}   = $now->clone;

    $self->{today}              = $now;
    $self->{yesterday}          = $self->{date_inside_range2}->clone;

    # setup test data framework
    $self->{data}   = Test::XT::Data->new_with_traits(
                                traits  => [
                                    'Test::XT::Data::Order',
                                ],
                            );

    # Sales Channels
    $self->{channels}       = [ $self->schema->resultset('Public::Channel')->enabled_channels->all ];
    $self->{valid_channels} = {
                                map { $_->id => $_ }
                                    grep { !$_->business->fulfilment_only }
                                        @{ $self->{channels} }
                            };
    # this will be Jimmy choo
    $self->{invalid_channels} = {
                                map { $_->id => $_ }
                                    grep { $_->business->fulfilment_only }
                                        @{ $self->{channels} }
                            };
}

# done everytime before each Test method is run
sub setup: Test(setup) {
    my $self = shift;
    $self->SUPER::setup;

    # Start a transaction, so we can rollback after testing
    $self->schema->txn_begin;
}

# done everytime after each Test method has run
sub teardown: Test(teardown) {
    my $self    = shift;
    $self->SUPER::teardown;

    # rollback changes done in a test
    # so they don't affect the next test
    $self->schema->txn_rollback;

    # clear out the output directory
    $self->{extract_dir}->purge_directory_of_files;

    # clear the instance of $self->{script_obj}
    $self->{script_obj} = undef;
}


=head1 TEST METHODS

=head2 test_defaults

This tests that the expected defaults are used when instantiating the Script Class when NO options are passed to the Constructor.

=cut

sub test_defaults : Tests() {
    my $self    = shift;

    my $obj = $self->script_obj;

    my $yesterday   = $self->{yesterday}->clone;

    my %expected    = (
            verbose             => 0,
            dryrun              => 0,
            start_date          => $yesterday->ymd('-'),
            end_date            => $yesterday->clone->add( days => 1 )->ymd('-'),
            path_to_extract_to  => config_var( 'SystemPaths', 'esp_incoming_dir' ),
            path_to_move_to     => config_var( 'SystemPaths', 'esp_base_dir' )
                                   . '/' . config_var( 'ESP_Responsys', 'waiting_subdir' ),
            using_default_path  => 1,
        );
    my %got = map { $_ => $obj->$_ } keys %expected;

    is_deeply( \%got, \%expected, "Class has expected Defaults" );

    return;
}

=head2 test_overiding_defaults

This tests that defaults can be overridden when different options are passed to the Constructor.

=cut

sub test_overiding_defaults : Tests() {
    my $self    = shift;

    $self->_new_instance( { verbose => 1 } );
    cmp_ok( $self->script_obj->verbose, '==', 1, "'verbose' overidden" );

    $self->_new_instance( { dryrun => 1 } );
    cmp_ok( $self->script_obj->dryrun, '==', 1, "'dryrun' overidden" );

    $self->_new_instance( { path => '/my/made/up/path' } );
    is( $self->script_obj->path_to_extract_to, '/my/made/up/path', "'path' overidden" );
    cmp_ok( $self->script_obj->using_default_path, '==', 0, "'using_default_path' flag set to FALSE" );

    # override 'fromdate' with both a String & a DateTime object
    my $date    = DateTime->new( { year => '2003', month => '05', day => '08' } );
    $self->_new_instance( { fromdate => $date->ymd('-') } );
    is( $self->script_obj->start_date->ymd('-'), $date->ymd('-'), "'fromdate' overridden using a text string" );
    $self->_new_instance( { fromdate => $date } );
    is( $self->script_obj->start_date->ymd('-'), $date->ymd('-'), "'fromdate' overridden using a DateTime object" );

    return;
}

=head2 test_main_query

This tests that the main query is only looking for the correct Shipments to extract.

These Shipments should be:
    * Standard Class Shipments
    * Dispatched Shipments
    * Not Jimmy Choo
    * and shipments dispatched on a certain day (defaults to yesterday)

=cut

sub test_main_query : Tests() {
    my $self    = shift;

    my $obj     = $self->script_obj;

    # lists of Shipment Ids
    my @all_shipment_ids;
    my @shipment_ids_should_find;

    # create a few Shipments for each Sales Channel
    my @channels    = @{ $self->{channels} };
    foreach my $channel ( @channels ) {
        my @shipments_should_find;

        # create shipments that should be found when using the main query
        foreach my $dispatch_date (
                                    $self->{date_inside_range3},
                                    $self->{date_inside_range1},
                                    $self->{date_inside_range2},
                                  ) {
            push @shipments_should_find, $self->_create_dispatched_shipment( $channel, $dispatch_date->clone );
            push @all_shipment_ids, $shipments_should_find[-1]->id;
        }

        # create shipments that should NOT be found when using the main query
        foreach my $dispatch_date (
                                    $self->{date_before_range},
                                    $self->{date_after_range},
                                  ) {
            my $shipment    = $self->_create_dispatched_shipment( $channel, $dispatch_date->clone );
            push @all_shipment_ids, $shipment->id;
        }

        if ( exists( $self->{valid_channels}{ $channel->id } ) ) {
            # store all of the Shipment Ids that should be found by the main query
            push @shipment_ids_should_find, map { $_->id } @shipments_should_find;
        }
    }

    # get the main query used in the extract and then constrain
    # it to the Shipment Ids that have been created in the test,
    # so as to ignore existing shipments
    my $main_qry_rs = $obj->dispatched_shipments_rs();
    isa_ok( $main_qry_rs, 'XTracker::Schema::ResultSet::Public::Shipment', "Main Query is of the correct type" );
    my $test_rs     = $main_qry_rs->search( {
                                        'me.id' => {
                                                    IN  => \@all_shipment_ids,
                                                },
                                    } );

    my @got = $test_rs->all;
    is_deeply(
                [ sort { $a <=> $b } map { $_->id } @got ],
                [ sort { $a <=> $b } @shipment_ids_should_find ],
                "Got all the Expected Shipments"
            );


    # get one shipment to test with
    my $shipment= $self->_create_dispatched_shipment( $self->valid_channel, $self->{date_inside_range1}->clone );
    my $ship_log= $shipment->shipment_status_logs->search( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } )->first;
    # make the main query only search for this Shipment
    $test_rs    = $main_qry_rs->search( { 'me.id' => $shipment->id } );

    note "Test Allowed & Not Allowed Shipment Classes";
    my $classes = Test::XTracker::Data->get_allowed_notallowed_statuses(
                                                                'Public::ShipmentClass',
                                                                {
                                                                    allow   => [ $SHIPMENT_CLASS__STANDARD ],
                                                                }
                                                            );
    note "Classes that should NOT be found by the Query";
    foreach my $class ( @{ $classes->{not_allowed} } ) {
        $shipment->update( { shipment_class_id => $class->id } );
        @got    = $test_rs->reset->all;
        cmp_ok( @got, '==', 0, "With Class: '" . $class->class . "' Shipment NOT Found" );
    }

    note "Classes that SHOULD be found by the Query";
    foreach my $class ( @{ $classes->{allowed} } ) {
        $shipment->update( { shipment_class_id => $class->id } );
        @got    = $test_rs->reset->all;
        cmp_ok( @got, '==', 1, "With Class: '" . $class->class . "' Shipment FOUND" );
    }

    note "Test Allowed & Not Allowed Shipment Statuses for the 'shipment_status_log' table";
    my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses(
                                                                'Public::ShipmentStatus',
                                                                {
                                                                    allow   => [ $SHIPMENT_STATUS__DISPATCHED ],
                                                                }
                                                            );
    note "Statuses that should NOT be found by the Query";
    foreach my $status ( @{ $statuses->{not_allowed} } ) {
        $ship_log->update( { shipment_status_id => $status->id } );
        @got    = $test_rs->reset->all;
        cmp_ok( @got, '==', 0, "With Status: '" . $status->status . "' Shipment NOT Found" );
    }

    note "Statuses that SHOULD be found by the Query";
    foreach my $status ( @{ $statuses->{allowed} } ) {
        $ship_log->update( { shipment_status_id => $status->id } );
        @got    = $test_rs->reset->all;
        cmp_ok( @got, '==', 1, "With Status: '" . $status->status . "' Shipment FOUND" );
    }

    return;
}

=head2 test_extract_output

Tests that the extract outputs the correct data to the file and that it produces a file per Sales Channel.

=cut

sub test_extract_output : Tests() {
    my $self    = shift;

    # create a few Shipments for each Sales Channel
    my %shipments;
    my @shipment_ids;
    my @channels_used;
    my %expected_file_contents;

    # create the test data manually rather than use '_create_test_data'
    # method because we want to use the Order Number as the Primary Key
    foreach my $channel ( values %{ $self->{valid_channels} } ) {
        push @channels_used, $channel;
        foreach my $dispatch_date (
                                    $self->{date_inside_range3},
                                    $self->{date_inside_range1},
                                    $self->{date_inside_range2},
                                  ) {

            my $shipment    = $self->_create_dispatched_shipment( $channel, $dispatch_date->clone );
            push @shipment_ids, $shipment->id;
            $shipments{ $shipment->id } = $shipment;

            $expected_file_contents{ $channel->id }{ $shipment->order->order_nr } = $self->shipment_to_file_content( $shipment, $dispatch_date );
        }
    }

    # refine & then replace the main query
    # to only look at the new Shipments
    my $obj = $self->_refine_script_qry_to_shipment_ids( \@shipment_ids );

    # run the script
    $obj->invoke();

    my $files_for_channels  = $self->find_and_get_files( \@channels_used );

    # check the contents of the files
    foreach my $channel ( @channels_used ) {
        my $file    = $files_for_channels->{ $channel->id };

        my $got_contents        = $file->as_data_by_pkey( { use_field_as_pkey => 'ORDERNUM' } );
        my $expected_contents   = $expected_file_contents{ $channel->id };
        cmp_ok( keys %{ $got_contents }, '==', keys %{ $expected_contents }, "Expected Number of Rows found in file" );
        is_deeply( $got_contents, $expected_contents, "and file Contents is as Expected too" );
    }

    return;
}

=head2 test_extract_for_multiple_orders_per_customer

Tests that when a Customer has had more than one Shipment Dispatched in a day then all of those Shipments are extracted
and appear in the files.

=cut

sub test_extract_for_multiple_orders_per_customer : Tests() {
    my $self    = shift;

    my @channels_used   = values %{ $self->{valid_channels} };
    my $shipment_ids    = $self->_create_test_data( \@channels_used, { use_same_customer => 1 } );

    # refine & then replace the main query
    my $obj = $self->_refine_script_qry_to_shipment_ids( $shipment_ids );

    # run the script
    $obj->invoke();

    my $files_for_channels  = $self->find_and_get_files( \@channels_used );

    # check the contents of the files
    foreach my $channel ( @channels_used ) {
        my $file    = $files_for_channels->{ $channel->id };

        my $got_contents        = $file->as_data_by_pkey( { force_array => 1 } );
        my $expected_contents   = $self->{expected_file_contents}{ $channel->id };
        cmp_ok( keys %{ $got_contents }, '==', keys %{ $expected_contents }, "Expected Number of Rows found in file" );
        is_deeply( $got_contents, $expected_contents, "and file Contents is as Expected too" );
    }

    return;
}

=head2 test_only_one_file_produced_when_orders_for_one_channel

Tests that when there is only one Sales Channel that has any Shipments to Dispatch then only ONE file is produced.

=cut

sub test_only_one_file_produced_when_orders_for_one_channel : Tests() {
    my $self    = shift;

    my ( $channel ) = values %{ $self->{valid_channels} };
    my $shipment_ids= $self->_create_test_data( [ $channel ] );

    # refine & then replace the main query
    my $obj = $self->_refine_script_qry_to_shipment_ids( $shipment_ids );

    # run the script
    $obj->invoke();

    my $files_for_channels  = $self->find_and_get_files( [ $channel ] );
    my $file                = $files_for_channels->{ $channel->id };

    my $got_contents        = $file->as_data_by_pkey( { force_array => 1 } );
    my $expected_contents   = $self->{expected_file_contents}{ $channel->id };
    cmp_ok( keys %{ $got_contents }, '==', keys %{ $expected_contents }, "Expected Number of Rows found in file" );
    is_deeply( $got_contents, $expected_contents, "and file Contents is as Expected too" );

    return;
}

=head2 test_when_in_verbose_mode

Tests that with the 'verbose' switch on that the script still does what it's supposed to.

=cut

sub test_when_in_verbose_mode : Tests() {
    my $self    = shift;

    $self->_new_instance( { verbose => 1 } );

    my @channels_used   = values %{ $self->{valid_channels} };
    my $shipment_ids    = $self->_create_test_data( \@channels_used );

    # refine & then replace the main query
    my $obj = $self->_refine_script_qry_to_shipment_ids( $shipment_ids );

    # run the script
    $obj->invoke();

    my $files_for_channels  = $self->find_and_get_files( \@channels_used );

    # check the contents of the files
    foreach my $channel ( @channels_used ) {
        my $file    = $files_for_channels->{ $channel->id };

        my $got_contents        = $file->as_data_by_pkey( { force_array => 1 } );
        my $expected_contents   = $self->{expected_file_contents}{ $channel->id };
        cmp_ok( keys %{ $got_contents }, '==', keys %{ $expected_contents }, "Expected Number of Rows found in file" );
        is_deeply( $got_contents, $expected_contents, "and file Contents is as Expected too" );
    }

    return;
}

=head2 test_when_in_dryrun_mode_no_files_are_created

Tests that when the 'dryrun' switch is on that NO files are created.

=cut

sub test_when_in_dryrun_mode_no_files_are_created : Tests() {
    my $self    = shift;

    # when called from the wrapper script 'verbose' will be TRUE too
    $self->_new_instance( { dryrun => 1, verbose => 1 } );

    my @channels_used   = values %{ $self->{valid_channels} };
    my $shipment_ids    = $self->_create_test_data( \@channels_used );

    # refine & then replace the main query
    my $obj = $self->_refine_script_qry_to_shipment_ids( $shipment_ids );

    # run the script
    $obj->invoke();

    my $file_date_part  = $self->script_obj->time_now->ymd('')
                          . '_' . $self->script_obj->time_now->hms('');

    # check the contents of the files
    foreach my $channel ( @channels_used ) {
        my $filename    = 'ORDERS_' . uc( $channel->website_name ) . "_${file_date_part}.txt";
        file_not_exists_ok( $self->{output_path} . "/${filename}" );
    }

    return;
}

=head2 test_not_using_the_default_output_path

Tests that when a different output path is specified when Constructing the Script object
that the specified path is actually used to output the files to and NOT the default.

=cut

sub test_not_using_the_default_output_path : Tests() {
    my $self    = shift;

    my $other_path  = config_var( 'SystemPaths', 'xtdc_base_dir' ) . '/tmp';

    # have to get a new Artifact to look in the new directory
    my $default_extract_dir = $self->{extract_dir};
    $self->{extract_dir}    = $self->_setup_directory_reader( $other_path );
    $self->{extract_dir}->purge_directory_of_files;

    $self->_new_instance( { path => $other_path } );

    my @channels_used   = values %{ $self->{valid_channels} };
    my $shipment_ids    = $self->_create_test_data( \@channels_used );

    # refine & then replace the main query
    my $obj = $self->_refine_script_qry_to_shipment_ids( $shipment_ids );

    # run the script
    $obj->invoke();

    my $files_for_channels  = $self->find_and_get_files( \@channels_used );

    # check the contents of the files
    foreach my $channel ( @channels_used ) {
        my $file    = $files_for_channels->{ $channel->id };

        my $got_contents        = $file->as_data_by_pkey( { force_array => 1 } );
        my $expected_contents   = $self->{expected_file_contents}{ $channel->id };
        cmp_ok( keys %{ $got_contents }, '==', keys %{ $expected_contents }, "Expected Number of Rows found in file" );
        is_deeply( $got_contents, $expected_contents, "and file Contents is as Expected too" );
    }


    $self->{extract_dir}->purge_directory_of_files;

    # go back to using the default path to look for files
    $self->{extract_dir}    = $default_extract_dir;

    return;
}

=head2 test_wrapper_script

Tests the wrapper perl script that inbokes the Script class exists and is executable.
Then tests that it can be executed in 'dryrun' mode and NO files are produced.

Wrapper Script:
    script/data_transfer/esp/responsys_orders_feed.pl

=cut

sub test_script_wrapper : Tests() {
    my $self    = shift;

    my $script  = config_var('SystemPaths','xtdc_base_dir')
                  . '/script/data_transfer/esp/responsys_orders_feed.pl';

    note "Testing Wrapper Script: ${script}";

    file_exists_ok( $script, "Wrapper Script exists" );
    file_executable_ok( $script, "and is executable" );

    # make sure no files exists in the directory
    $self->{extract_dir}->purge_directory_of_files;

    note "attempt to run script in 'dryrun' mode";

    # create some test data
    my @channels_used   = values %{ $self->{valid_channels} };
    my $shipment_ids    = $self->_create_test_data( \@channels_used );
    $self->schema->txn_commit;  # need to commit the data otherwise the
                                # Script wouldn't pick up the data anyway
    # teardown will fail if not in a transaction
    $self->schema->txn_begin;

    system( $script, '-d' );    # run script in Dry-Run mode
    my $retval  = $?;
    if ( $retval == -1 ) {
        fail( "Script failed to Execute: ${retval}" )
    }
    else {
        cmp_ok( ( $retval & 127 ), '==', 0, "Script Executed OK: ${retval}" );
    }

    # check NO files were created
    my $files_deleted   = $self->{extract_dir}->purge_directory_of_files;
    cmp_ok( $files_deleted, '==', 0, "and NO files were created" );

    return;
}

sub test_in_pg_format : Tests() {
    my $self = shift;

    my $got_date = DateTime->now( time_zone => config_var('DistributionCentre', 'timezone') );
    my $expected_date = XTracker::Script::Extract::ESP::_in_pg_format($self,$got_date);

    my $cmp = $got_date->ymd." ".$got_date->hms;
    like( $expected_date,qr/$cmp/ , "Expected Date format returned" );
}
#-----------------------------------------------------------------------------------------

# create Data for most of the above tests to use
sub _create_test_data {
    my ( $self, $channels, $args )  = @_;

    $self->{expected_file_contents} = {};

    my @shipment_ids;

    foreach my $channel ( @{ $channels } ) {
        my $customer;
        if ( $args->{use_same_customer} ) {
            $customer   = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );
        }
        foreach my $dispatch_date (
                                    $self->{date_inside_range1},
                                    $self->{date_inside_range2},
                                    $self->{date_inside_range3},
                                  ) {

            my $shipment= $self->_create_dispatched_shipment( $channel, $dispatch_date->clone );
            push @shipment_ids, $shipment->id;

            if ( $args->{use_same_customer} ) {
                $shipment->order->update( { customer_id => $customer->id } );
            }

            push @{ $self->{expected_file_contents}{ $channel->id }{ $shipment->order->customer->is_customer_number } },
                                                            $self->shipment_to_file_content( $shipment, $dispatch_date );
        }
    }

    return \@shipment_ids;
}

# given a Shipment generates what
# should appear in the file for it
sub shipment_to_file_content {
    my ( $self, $shipment, $dispatch_date ) = @_;

    my $order       = $shipment->order;
    my $ship_addr   = $shipment->shipment_address;
    return {
            CHANNEL             => $order->channel_id,
            CUSTOMERNUM         => $order->customer->is_customer_number,
            ORDERNUM            => $order->order_nr,
            ORDERDATE           => $order->date->strftime("%F %T"),
            ORDERVALUE          => sprintf( '%0.3f', _shipment_value( $shipment ) ),
            ORDERCURRENCY       => $order->currency->currency,
            DISPATCHDATE        => $dispatch_date->strftime("%F %T"),
            SHIPPINGCITY        => $ship_addr->towncity,
            SHIPPINGSTATE       => $ship_addr->county,
            SHIPPINGPOSTALCODE  => $ship_addr->postcode,
            SHIPPINGCOUNTRY     => $ship_addr->country_table->code,
            DATE                => $self->script_obj->time_now->strftime("%F %T"),
        };
}

# return the files found in the output
# directory so their contents can be tested
sub find_and_get_files {
    my ( $self, $channels )     = @_;

    my @files   = $self->{extract_dir}->wait_for_new_files( files => scalar( @{ $channels } ) );

    my %channel_files;

    # check 'file_id' on each file to make
    # sure each Sales Channel has been found
    foreach my $channel ( @{ $channels } ) {
        my $channel_name= uc( $channel->website_name );
        my ( $file )    = grep { $_->file_id eq $channel_name } @files;
        $channel_files{ $channel->id }  = $file;
        ok( defined $file, "Found a File for Sales Channel: " . $channel->name );
        is_deeply( scalar $file->headings, $self->{field_headers}, "and found Field Headings on First Row" );
    }

    return \%channel_files;
}

# get a new instance of the Script object, can
# pass options for the constructor if needed
sub _new_instance {
    my ( $self, $options )  = @_;
    $self->{script_obj} = undef;        # need this otherwise the 'SingleInstance' feature
                                        # will block new instantiations of the Class

    $self->{script_obj} = XTracker::Script::Extract::ESP->new( $options || {} );

    # need to use our copy of Schema & DBH
    $self->{script_obj}->{schema}   = $self->schema;
    $self->{script_obj}->{dbh}      = $self->schema->storage->dbh;

    return;
}

# returns the instance of the Script object
# that '_new_instance' has instantiated
sub script_obj {
    my $self    = shift;
    $self->_new_instance            if ( !$self->{script_obj} );
    return $self->{script_obj};
}

# creates a dispatched shipment for a given dispatch date
sub _create_dispatched_shipment {
    my ( $self, $channel, $dispatch_date )  = @_;

    my $order_dets  = $self->{data}->packed_order( channel => $channel );
    my $shipment    = $order_dets->{shipment_object};

    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );
    $shipment->create_related( 'shipment_status_logs', {
                                        shipment_status_id  => $SHIPMENT_STATUS__DISPATCHED,
                                        operator_id         => $APPLICATION_OPERATOR_ID,
                                        date                => $dispatch_date,
                                    } );
    $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );

    note "====> ON CHANNEL: " . $channel->name . ", Created Shipment Id: " . $shipment->id . ", with Dispatch Date: " . $dispatch_date->datetime;

    return $shipment->discard_changes;
}

# returns the schema object for the test
sub schema {
    my $self    = shift;
    return $self->{schema};
}

# return any Valid Sales Channel
sub valid_channel {
    my $self    = shift;

    my ( $channel ) = grep { exists( $self->{valid_channels}{ $_->id } ) }
                                @{ $self->{channels} };
    return $channel;
}

# get the total shipment value for the shipment
# which will be less Cancelled Shipment Items
sub _shipment_value {
    my $shipment    = shift;

    return  $shipment->shipping_charge
            + $shipment->total_price
            + $shipment->total_tax
            + $shipment->total_duty
    ;
}

# refine & then replace the main query
# to only look at specific Shipments
sub _refine_script_qry_to_shipment_ids {
    my ( $self, $ids )  = @_;

    my $obj = $self->script_obj;

    # refine & then replace the main query
    # to only look at the new Shipments
    my $main_qry_rs = $obj->dispatched_shipments_rs();
    my $test_rs     = $main_qry_rs->search( { 'me.id' => $ids } );
    $obj->dispatched_shipments_rs( $test_rs );

    return $obj;
}

# set-up an Artifact to read a directory path
# to look out for files generated by the tests
sub _setup_directory_reader {
    my ( $self, $path )     = @_;

    return Test::XTracker::Artifacts::OutputFile->new( {
                title           => 'ESP Extract',
                read_directory  => $path,
                filter_regex    => qr/^ORDERS_.*\.txt$/,
                file_id_regex   => qr/ORDERS_([A-Z]*_[A-Z]*)_/,
                file_type       => 'PlainText',
                field_delimiter => "\t",
                record_delimiter=> "\n",
                primary_key     => 'CUSTOMERNUM',
        } );
}
