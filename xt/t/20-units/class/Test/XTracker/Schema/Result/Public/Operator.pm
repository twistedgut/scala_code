package Test::XTracker::Schema::Result::Public::Operator;

use FindBin::libs;

use NAP::policy qw/class tt test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
}

=head1 NAME

Test::XTracker::Schema::Result::Public::Operator

=head1 DESCRIPTION

=cut

use XTracker::Constants ':application';
use XTracker::Printers;

use Test::XTracker::Data::Designer;
use Test::XTracker::Data::SearchOrderByDesigner;

use XTracker::Constants::FromDB     qw(
    :customer_category
    :shipment_class
    :shipment_status
    :shipment_type
);

use Test::XT::Data;

use Scalar::Util        qw( blessed );


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    # set-up a ResultSet to get a list of Operators
    $self->{operator_rs} = $self->rs('Public::Operator')->search(
        {
            id                => { '!=' => $APPLICATION_OPERATOR_ID },
            'LOWER(username)' => { '!=' => 'it.god' },
        }
    );

    $self->{channel} = Test::XTracker::Data->channel_for_nap();

    Test::XTracker::Data::SearchOrderByDesigner->purge_search_result_dir();

    # get a Designer for the Search Orders by Designer tests
    $self->{designer} = $self->rs('Public::Designer')
                                ->search( { id => { '!=' => 0 } } )
                                    ->first;
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    # reset the ResultSet so it can be used again
    $self->{operator_rs}->reset;

    $self->schema->txn_begin();
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->schema->txn_rollback();

    Test::XTracker::Data::SearchOrderByDesigner->purge_search_result_dir();
}

=head1 METHODS

=head2 test_has_location_for_section

Test::XTracker::Schema::Result::Public::Allocation - Unit tests for
XTracker::Schema::Result::Public::Operator

=cut

sub test_has_location_for_section : Tests {
    my $self = shift;

    # Define printers with two different sections
    my %section = ( expected => 'item_count', other => 'stock_in' );
    my $printers = [map {
        +{ %{$self->default_printer}, section => $_ }
    } values %section];

    $self->new_printers_from_arrayref($printers)->populate_db;

    my $xp = XTracker::Printers->new;
    my $operator = $self->schema
        ->resultset('Public::Operator')->find($APPLICATION_OPERATOR_ID);
    $operator->update_or_create_related('operator_preference', {
        printer_station_name => $xp->locations_for_section($section{expected})
                                   ->slice(0,0)
                                   ->single
                                   ->name
    });

    ok( $operator->has_location_for_section($section{expected}),
        'printer location is in section' );
    ok( !$operator->has_location_for_section($section{other}),
        'printer location is not in section' );

    $operator->operator_preference->update({printer_station_name => undef});
    ok( !$operator->has_location_for_section($section{expected}),
        'unset printer station name returns false' );

    $operator->operator_preference->delete;
    ok( !$operator->discard_changes->has_location_for_section($section{expected}),
        'missing operator preference returns false' );
}

=head2 test_order_search_by_designer_filename

Test the methods used by the Orders Search By Designer functionality. Currently
these are:

    Result Methods:
        create_orders_search_by_designer_file_name

    Result Set Methods:
        parse_orders_search_by_designer_file_name
        get_list_of_search_orders_by_designer_result_files

=cut

sub test_order_search_by_designer_filename : Tests() {
    my $self = shift;

    # get an Operator and a Designer
    my $operator = $self->{operator_rs}->first;
    my ( $designer, $other_designer ) =
                        $self->rs('Public::Designer')
                            ->search( { id => { '!=' => 0 } }, { rows => 2 } )
                                ->all;

    # get the current DB date
    my $now     = $self->schema->db_now();
    my $now_str = $now->ymd('') . $now->hms('');

    # set the constant part of the filename
    my $expected_prefix = $operator->id . '_' . $designer->id;

    # get a Channel Id to use for some Tests
    my $channel    = Test::XTracker::Data->channel_for_nap();
    my $channel_id = $channel->id;

    my $expected = "${expected_prefix}_0_${now_str}_PENDING.txt";
    $self->_check_file_name( $operator, $expected, {
        designer => $designer,
        state    => 'pending',
    } );

    $expected = "${expected_prefix}_${channel_id}_${now_str}_SEARCHING.txt";
    $self->_check_file_name( $operator, $expected, {
        designer => $designer,
        channel  => $channel,
        state    => 'searching',
    } );

    $expected = "${expected_prefix}_${channel_id}_${now_str}_COMPLETED_563.txt";
    $self->_check_file_name( $operator, $expected, {
        designer => $designer,
        channel  => $channel,
        state    => 'completed',
        number_of_records => 563,
    } );


    note "Create many files and test 'get_list_of_search_orders_by_designer_result_files' method";

    # create 5 new Designers and then create the files
    my @designers   = Test::XTracker::Data::Designer->grab_designers( {
        how_many       => 5,
        want_dbic_recs => 1,
        force_create   => 1,
    } );
    my $file_names  = Test::XTracker::Data::SearchOrderByDesigner->create_search_result_files( 5, [
        map { { designer => $_ } } @designers
    ] );

    my $operator_rs = $self->rs('Public::Operator');
    my @expected = map {
        # parse the file-names that were created
        $operator_rs->parse_orders_search_by_designer_file_name( $_ )
    } @{ $file_names };

    my $got = $operator_rs->get_list_of_search_orders_by_designer_result_files();
    cmp_deeply( $got, bag( @expected ), "'get_list_of_search_orders_by_designer_result_files' returned as Expected" );
}

=head2 test_create_completed_orders_search_by_designer_results_file

Tests the method 'create_completed_orders_search_by_designer_results_file' which actually
searches for the Orders and creates a 'Completed' Results file.

=cut

sub test_create_completed_orders_search_by_designer_results_file : Tests() {
    my $self = shift;

    # create some new Designers
    my @designers = Test::XTracker::Data::Designer->grab_designers( {
        how_many       => 3,
        want_dbic_recs => 1,
        force_create   => 1,
    } );

    my $channel     = Test::XTracker::Data->channel_for_nap();
    my $alt_channel = Test::XTracker::Data->channel_for_out();
    my $operator    = $self->{operator_rs}->first;

    my $search_designer = $designers[0];

    # create some Orders to search for
    my @want_orders = Test::XTracker::Data::Designer->create_orders_with_products_for_the_same_designer( 5, {
        designer => $search_designer,
        channel  => $channel,
    } );

    # create some Orders to search for on a different Channel
    my @alt_channel_orders = Test::XTracker::Data::Designer->create_orders_with_products_for_the_same_designer( 5, {
        designer => $search_designer,
        channel  => $alt_channel,
    } );

    # create some Orders for a different Designer so none of them should be found
    my @dont_want_orders = Test::XTracker::Data::Designer->create_orders_with_products_for_the_same_designer( 3, {
        designer => $designers[1],
        channel  => $channel,
    } );


    note "TESTING - Search for Orders by Designer for the Sales Channel: " . $channel->name;

    my $got = $self->_run_search_and_get_results( $operator, $search_designer, 5, $channel );

    my @expected = map { { shipment_id => $_->get_standard_class_shipment->id } } @want_orders;
    cmp_deeply( $got, superbagof( @expected ), "Got Expected Shipment Ids in File" )
                        or diag "ERROR - Didn't get Expected Shipment Ids in File: " . p( $got ) . "\n" . p( @expected );

    # now check for the Shipments that shouldn't be in the list, '@expected' should be empty
    my %got   = map { $_->{shipment_id} => 1 } @{ $got };
    @expected = map { $_->get_standard_class_shipment->id }
                    grep { exists( $got{ $_->get_standard_class_shipment->id } ) }
                        ( @dont_want_orders, @alt_channel_orders );
    ok( !@expected, "Didn't find any Shipments from the Orders with Items for the other Designer or the Alternative Sales Channel" )
                or diag "ERROR - Found Shipments from the Orders with Items for another Designer or Alternative Channel: " . p( @expected );


    note "TESTING - Search for Orders by Designer from ANY Sales Channel";

    $got = $self->_run_search_and_get_results( $operator, $search_designer, 10 );

    @expected = map { { shipment_id => $_->get_standard_class_shipment->id } }
                        ( @want_orders, @alt_channel_orders );
    cmp_deeply( $got, superbagof( @expected ), "Got Expected Shipment Ids in File" )
                        or diag "ERROR - Didn't get Expected Shipment Ids in File: " . p( $got ) . "\n" . p( @expected );

    # now check for the Shipments that shouldn't be in the list, '@expected' should be empty
    %got      = map { $_->{shipment_id} => 1 } @{ $got };
    @expected = map { $_->get_standard_class_shipment->id }
                    grep { exists( $got{ $_->get_standard_class_shipment->id } ) }
                        @dont_want_orders;
    ok( !@expected, "Didn't find any Shipments from the Orders with Items for the other Designer" )
                or diag "ERROR - Found Shipments from the Orders with Items for another Designer: " . p( @expected );


    note "TESTING - Search for Orders by a Designer which has NO Orders";
    $got = $self->_run_search_and_get_results( $operator, $designers[2], 0 );
    cmp_ok( scalar( @{ $got } ), '==', 0, "Found ZERO records in the Completed file" )
                    or diag "ERROR - found records in Completed file: " . p( $got );
}

=head2 test_order_search_by_designer_only_gets_orders_in_date_range

Tests the method 'create_completed_orders_search_by_designer_results_file' only
searches for Orders that are within the correct date range which is from 'now'
and then as far back as the System Config setting 'order_search.by_designer_search_window'
is set to.

=cut

sub test_order_search_by_designer_only_gets_orders_in_date_range : Tests() {
    my $self = shift;

    # set the search window to be in the last 5 days
    Test::XTracker::Data->remove_config_group('order_search');
    Test::XTracker::Data->create_config_group( 'order_search', {
        settings => [
            { setting => 'by_designer_search_window', value => '5 DAYS' },
        ],
    } );

    # update any existing Shipments Dates to be older than 5 days
    $self->rs('Public::Shipment')->update( { date => \"NOW() - INTERVAL '10 DAYS'" } );

    # create a new Designer
    my ( $designer ) = Test::XTracker::Data::Designer->grab_designers( {
        how_many       => 1,
        want_dbic_recs => 1,
        force_create   => 1,
    } );

    my $channel  = Test::XTracker::Data->channel_for_nap();
    my $operator = $self->{operator_rs}->first;

    # create some Orders to search for
    my @orders = Test::XTracker::Data::Designer->create_orders_with_products_for_the_same_designer( 3, {
        designer => $designer,
        channel  => $channel,
    } );
    my @shipments = sort { $b->id <=> $a->id }
                        map { $_->get_standard_class_shipment }
                            @orders;


    note "TESTING - All Orders within Search Window, should find all Orders";

    my $rows = $self->_run_search_and_get_results( $operator, $designer, 3 );
    cmp_deeply( $rows, [ map { { shipment_id => $_->id } } @shipments ], "Got Expected Shipment Ids" )
                        or diag "ERROR - Didn't get Expected Shipment Ids: " . p( $rows );


    note "TESTING - Only One Order is within the Search Window, should only find One Order";
    Test::XTracker::Data::SearchOrderByDesigner->purge_search_result_dir();

    # the Shipment Date is actually used as the Date
    # to check, set it to a date older than 5 days
    foreach my $shipment ( @shipments[1,2] ) {
        $shipment->update( { date => \"NOW() - INTERVAL '10 DAYS'" } );
        $shipment->discard_changes;
    }

    $rows = $self->_run_search_and_get_results( $operator, $designer, 1 );
    cmp_deeply( $rows, [ { shipment_id => $shipments[0]->id } ], "Got Expected Shipment Id" )
                        or diag "ERROR - Didn't get Expected Shipment Id: " . p( $rows );
}

=head2 test_reading_order_search_by_designer_reading_results_file

Tests the methods used to read the Order Search by Designer Results file
and produce the results so that they can be displayed on a page.

=cut

sub test_reading_order_search_by_designer_reading_results_file : Tests() {
    my $self = shift;

    my $operator = $self->{operator_rs}->first;

    my $designer = $self->rs('Public::Designer')
                            ->search( { id => { '!=' => 0 } } )
                                ->first;
    my $channel  = Test::XTracker::Data->channel_for_nap();

    # a function to generate the expected field values that should
    # appear in the results, these will be the generic ones that
    # can then be passed in overrides to set them sepecifically
    # for each Order that will be created below
    my $fnc_create_expected_results = sub {
        my $order = shift;
        $order->discard_changes;

        my $customer = $order->customer;
        # as part of the test there may not be a Standard Shipment
        my $shipment = $order->link_orders__shipments
                                ->first->shipment;

        return {
            order_nr            => $order->order_nr,
            order_id            => $order->id,
            customer_nr         => $customer->is_customer_number,
            customer_id         => $customer->id,
            customer_category   => $customer->category->category,
            customer_eip_flag   => $customer->is_an_eip,
            channel_id          => $order->channel_id,
            order_date          => "" . $order->date,
            order_total_value   => ( $order->total_value + $order->store_credit ),
            currency_id         => $order->currency_id,
            shipment_id         => $shipment->id,
            shipment_status     => $shipment->shipment_status->status,
            shipment_type       => $shipment->shipment_type->type,
            is_premier_shipment => $shipment->is_premier || 0,
        };
    };

    # set-up the Orders that will get created each with a different setting so
    # that it can be tested that the Search Result file gets read in correctly
    my %order_setup = (
        "EIP Customer" => {
            customer => {
                category_id => $CUSTOMER_CATEGORY__EIP,
            },
        },
        "Premier Shipment" => {
            shipment => {
                shipment_type_id => $SHIPMENT_TYPE__PREMIER,
            },
        },
        "Re-Shipment" => {
            shipment => {
                shipment_class_id => $SHIPMENT_CLASS__RE_DASH_SHIPMENT,
            },
        },
        "EIP Customer & Premier Order" => {
            customer => {
                category_id => $CUSTOMER_CATEGORY__EIP,
            },
            shipment => {
                shipment_type_id => $SHIPMENT_TYPE__PREMIER,
            },
        },
        "A Category of Customer that isn't EIP or None" => {
            customer => {
                category_id => $CUSTOMER_CATEGORY__PRESS_CONTACT,
            },
        },
        "Regular Order" => { },     # the defaults of creating an Order will do
    );

    # get the Products to be used in the Orders
    my ( undef, $products ) = Test::XTracker::Data::Designer->grab_products_for_designer(
        $designer,
        {
            how_many => 3,
            channel  => $channel,
        },
    );

    # store what should be returned when the
    # results file gets read in for the Orders,
    # key it off the Order Number
    my %expected;

    foreach my $label ( keys %order_setup ) {
        note "Creating Order: ${label}";
        my $setup = $order_setup{ $label };

        my $order = $self->_create_and_amend_order( $channel, $products, $setup );
        $expected{ $order->order_nr } = $fnc_create_expected_results->( $order );

        # store the Order in the setup to be used for a later test
        $setup->{order_obj} = $order;
    }

    my $file_name = Test::XTracker::Data::SearchOrderByDesigner->create_and_populate_search_result_file( {
        operator => $operator,
        designer => $designer,
        orders   => [ map { $_->{order_obj} } values %order_setup ],
    } );

    my $operator_rs = $self->rs('Public::Operator');
    my $results     = $operator_rs->read_search_orders_by_designer_result_file( $file_name );
    my @expect      = values( %expected );
    cmp_deeply( $results, bag( @expect ), "Results read in from the file are as Expected" );
}

=head2 test_processing_order_search_by_designer_file_contents

Test the Result Set method 'process_search_orders_by_designer_result_file_contents'
method that gets the contents of a Search Results file and then gets the
Order & Customer details for each of the Shipments in the results file.

=cut

sub test_processing_order_search_by_designer_file_contents : Tests() {
    my $self = shift;

    my $operator = $self->{operator_rs}->first;

    my $operator_rs = $self->rs('Public::Operator');

    my $designer = $self->{designer};
    my $channel  = $self->{channel};

    # the 'process_search_orders_by_designer_result_file_contents' method
    # will return all fields in the 'orders' table plus these additional ones
    my @expected_additional_fields = qw(
        first_order_flag
        first_name
        last_name
        customer_category_id
        customer_category
        customer_class_id
        customer_class
        channel_name
        channel_config_section
        shipment_id
        shipment_class_id
        shipment_class
        shipment_type_id
        shipment_type
        shipment_status_id
        shipment_status
    );

    # get the Products to be used in the Orders
    my ( undef, $products ) = Test::XTracker::Data::Designer->grab_products_for_designer(
        $designer,
        {
            how_many => 3,
            channel  => $channel,
        },
    );

    # create a few orders and then create
    my @orders;
    push @orders, $self->_create_and_amend_order( $channel, $products )     foreach ( 1..3 );

    # create the file then read in its contents
    my $contents = $self->_create_and_read_order_search_file( $operator, $designer, \@orders );


    note "Test return value from 'process_search_orders_by_designer_result_file_contents' method";
    # having read in the contents of the file turn them into
    # Search Results that can be used and check what comes back
    my $results  = $operator_rs->process_search_orders_by_designer_result_file_contents( $contents );
    isa_ok( $results, 'ARRAY', "'process_search_orders_by_designer_result_file_contents' returned as Expected" );
    cmp_ok( scalar( @{ $results } ), '==', scalar( @orders ), "and has the correct number of rows" );
    my %rec = $results->[0]->get_inflated_columns();
    cmp_deeply( [ keys %rec ], superbagof( @expected_additional_fields ),
                            "and a row has the Expected Additional fields" );
}

=head2 test_pagination_of_order_search_by_designer_file_contents

Check that pagination can be done using the arguments that can be passed
to the 'process_search_orders_by_designer_result_file_contents' method

=cut

sub test_pagination_of_order_search_by_designer_file_contents : Tests() {
    my $self = shift;

    my $operator = $self->{operator_rs}->first;

    my $operator_rs = $self->rs('Public::Operator');

    my $designer = $self->{designer};
    my $channel  = $self->{channel};

    # create 50 Orders, then create a search results file and
    # read the file back in to get the contents, then use the
    # 'process_search_orders_by_designer_result_file_contents'
    # method to turn the file contents into a result set

    # get the Products to be used in the Orders
    my ( undef, $products ) = Test::XTracker::Data::Designer->grab_products_for_designer(
        $designer,
        {
            how_many => 3,
            channel  => $channel,
        },
    );

    # create 50 Orders
    my @orders;
    push @orders, $self->_create_and_amend_order( $channel, $products )     foreach ( 1..50 );

    # create the file then read in its contents
    my @contents = $self->_create_and_read_order_search_file( $operator, $designer, \@orders );

    my %tests = (
        "Get first page of 10 Records" => {
            setup => {
                page           => 1,
                number_of_rows => 10,
            },
            expect => {
                rows => [ @contents[ 0..9 ] ],
            },
        },
        "Get third page of 10 Records" => {
            setup => {
                page           => 3,
                number_of_rows => 10,
            },
            expect => {
                rows => [ @contents[ 20..29 ] ],
            },
        },
        "Get last page of 10 Records" => {
            setup => {
                page           => 5,
                number_of_rows => 10,
            },
            expect => {
                rows => [ @contents[ 40..49 ] ],
            },
        },
        "Get first page of 30 Records" => {
            setup => {
                page           => 1,
                number_of_rows => 30,
            },
            expect => {
                rows => [ @contents[ 0..29 ] ],
            },
        },
        "Get last page of 30 Records (can only get 20 records back)" => {
            setup => {
                page           => 2,
                number_of_rows => 30,
            },
            expect => {
                rows => [ @contents[ 30..49 ] ],
            },
        },
        "Get 7th page of 10 Records (no such page should get nothing back)" => {
            setup => {
                page           => 7,
                number_of_rows => 10,
            },
            expect => {
                rows => [],
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        note "call 'process_search_orders_by_designer_result_file_contents' method and expect to find a list of DBIC records";
        my $got = $operator_rs->process_search_orders_by_designer_result_file_contents( \@contents, $setup );
        $self->_check_search_results_rows( $got, $expect->{rows} );

        # now get the results ready for JSON
        note "call 'process_search_orders_by_designer_result_file_contents_for_json' method and expect to find a list of HASH Refs.";
        $got = $operator_rs->process_search_orders_by_designer_result_file_contents_for_json( \@contents, $setup );
        $self->_check_search_results_rows( $got, $expect->{rows}, { has_raw_data => 1 } );
    }
}

#----------------------------------------------------------------------------

# helper to check the file name that gets created from
# the test 'test_order_search_by_designer_filename' method
# and make sure it's the correct one that is returned by
# the method 'parse_orders_search_by_designer_file_name'
sub _check_file_name {
    my ( $self, $operator, $expected, $args ) = @_;

    my $state    = $args->{state};
    my $designer = $args->{designer};
    my $channel  = $args->{channel};
    my $records  = $args->{number_of_records};

    # get a general Operator ResultSet which is not the same as '$self->{operator_rs}'
    my $operator_rs = $self->rs('Public::Operator');

    my $got = $operator->create_orders_search_by_designer_file_name( {
        designer => $designer,
        channel  => $channel,
        state    => $state,
        ( defined $records ? ( number_of_records => $records ) : () ),
    } );

    is( $got, $expected, "File-name as Expected for '${state}' state from 'create_orders_search_by_designer_file_name'" );
    $got = $operator_rs->parse_orders_search_by_designer_file_name( $expected );
    cmp_deeply( $got, {
        state    => $state,
        operator => $operator->discard_changes,
        designer => $designer->discard_changes,
        datetime => isa( 'DateTime' ),
        number_of_records => $records,
        file_name=> $expected,
        # if no Channel then don't expect a Channel
        ( $channel ? ( channel => $channel->discard_changes ) : () ),
    }, "File-name was then parsed correctly using 'parse_orders_search_by_designer_file_name'" );

    return $got;
}

# helper to create an Order and then make changes to
# various parts such as Customer Category, Shipment Type
# etc. for the different tests that are to be done on it
sub _create_and_amend_order {
    my ( $self, $channel, $products, $amendments ) = @_;

    my $data = Test::XT::Data->new_with_traits( {
        traits => [
            'Test::XT::Data::Order',
        ],
    } );

    my $customer = Test::XTracker::Data->create_dbic_customer( {
        channel_id => $channel->id,
    } );

    my $order_details = $data->new_order(
        channel  => $channel,
        customer => $customer,
        products => $products,
    );
    my $order = $order_details->{order_object};

    # get the Shipment so that it can be altered
    my $shipment = $order_details->{shipment_object}->discard_changes;
    $customer->discard_changes;

    $customer->update( $amendments->{customer} )     if ( $amendments->{customer} );
    $shipment->update( $amendments->{shipment} )     if ( $amendments->{shipment} );

    return $order->discard_changes;
}

# create a Order Search results file for some Orders and then
# get back the contents of the file to be processed later
sub _create_and_read_order_search_file {
    my ( $self, $operator, $designer, $orders ) = @_;

    my $operator_rs = $self->rs('Public::Operator');

    my $file_name = Test::XTracker::Data::SearchOrderByDesigner->create_and_populate_search_result_file( {
        operator => $operator,
        designer => $designer,
        orders   => $orders,
    } );
    my $contents = $operator_rs->read_search_orders_by_designer_result_file( $file_name );

    return ( wantarray ? @{ $contents } : $contents );
}


# helper to check the rows that are returned
# from processing the contents of a Search
# Orders by Designer results file
sub _check_search_results_rows {
    my ( $self, $got, $expected, $args ) = @_;

    # if this is true then $got should not contain any
    # blessed data and should just be an Array of HASH Refs.
    my $has_raw_data = $args->{has_raw_data} // 0;

    my $expected_num_of_rows = scalar( @{ $expected } );

    isa_ok( $got, 'ARRAY', "Results returned as Expected" );
    cmp_ok( scalar( @{ $got } ), '==', $expected_num_of_rows,
                        "and has the expected number of Rows: ${expected_num_of_rows}" );

    # if expecting to get more than one row then check the first one out
    if ( $expected_num_of_rows > 0 ) {
        my $row = $got->[0];
        isa_ok(
            $row,
            (
                $has_raw_data
                ? 'HASH'
                : 'XTracker::Schema::Result::Public::Orders'
            ),
            "Row structure is as Expected"
        ) or diag "ERROR Row isa '" . ref( $row ) . "'";
    }

    # get the three main Ids for each Row for both
    # $got & $expected and then make sure they match
    my @got_rows = map {
        {
            order_id    => $has_raw_data ? $_->{id}          : $_->id,
            customer_id => $has_raw_data ? $_->{customer_id} : $_->get_column('customer_id'),
            shipment_id => $has_raw_data ? $_->{shipment_id} : $_->get_column('shipment_id'),
        }
    } @{ $got };
    my @expected_rows = map {
        {
            order_id    => $_->{order_id},
            customer_id => $_->{customer_id},
            shipment_id => $_->{shipment_id},
        }
    } @{ $expected };

    # sequence of the rows is important so don't use a 'bag' test
    cmp_deeply( \@got_rows, \@expected_rows,
                    "Rows are for the correct Records and in the expected Sequence" )
                            or diag "ERROR getting correct Records in Sequence:\n" .
                                    "GOT - " . p( @got_rows ) . "\n" .
                                    "EXPECTED - " . p( @expected_rows );

    # if the Results are supposed to be Raw Data then
    # check there are no blessed values in any of them
    if ( $has_raw_data ) {
        my @blessed = grep { blessed( $_ ) } @{ $got };
        cmp_ok( scalar( @blessed ), '==', 0, "NO Blessed Rows found" );
        # now check all fields in the Rows
        @blessed = ();
        foreach my $row ( @{ $got } ) {
            @blessed = grep { blessed( $row->{ $_ } ) } keys %{ $row };
        }
        cmp_ok( scalar( @blessed ), '==', 0, "NO Blessed Fields found" );
    }

    return;
}

# this is to help test the method that actually does the
# searching, it will check that the 'searching' file
# does not exist and that the Completed file does and
# also read the file and return the rows in it
sub _run_search_and_get_results {
    my ( $self, $operator, $designer, $number_of_records, $channel ) = @_;

    # call the method that does the search and
    # returns the 'Completed' Search Results File Name
    my $result_details = $operator->create_completed_orders_search_by_designer_results_file( $designer, $channel );

    my $expected_file_name = $result_details->{file_name};

    # check 'Searching' file is not present
    my $got       = Test::XTracker::Data::SearchOrderByDesigner->check_if_search_result_file_exists_for_search_criteria( {
        designer => $designer,
        operator => $operator,
        channel  => $channel,
        state    => 'searching',
    } );
    ok( !$got, "Didn't find 'Searching' results file" );

    $got = Test::XTracker::Data::SearchOrderByDesigner->check_if_search_result_file_exists_for_search_criteria( {
        designer => $designer,
        operator => $operator,
        channel  => $channel,
        state    => 'completed',
        number_of_records => $number_of_records,
    } );
    is( $got, $expected_file_name, "Found Expected 'Completed' results file" );

    cmp_ok( $result_details->{number_of_records}, '==', $number_of_records,
                        "Search found Expected Number of Records: ${number_of_records}" );

    # get the rows in the file
    my $rows = Test::XTracker::Data::SearchOrderByDesigner->read_search_results_file( $expected_file_name );

    return $rows;
}

