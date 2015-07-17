#!/usr/bin/env perl

use NAP::policy "tt",     'test';


use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;

use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw(
                                    :business
                                    :department
                                    :reservation_status
                                    :shipment_item_status
                                    :flow_status
                            );
use XTracker::Config::Local     qw(
                                    customercare_email
                                    personalshopping_email
                                    fashionadvisor_email
                                );
use XTracker::WebContent::StockManagement;

use Test::XTracker::ParamCheck;
use Test::XT::Data;


BEGIN {
    use_ok('XTracker::Database::Reservation', qw(
                            get_reservation_list
                            get_reservation_overview
                            get_reservation_products
                            :email
                            create_reservation
                            get_reservation_details
                            cancel_reservation
                            update_reservation_variant
                            edit_reservation
                            list_product_reservations
                        ) );

    can_ok("XTracker::Database::Reservation", qw(
                            get_reservation_list
                            get_reservation_overview
                            get_reservation_products
                            get_from_email_address
                            get_email_signoff
                            get_email_signoff_parts
                            build_reservation_notification_email
                            create_reservation
                            get_reservation_details
                            cancel_reservation
                            update_reservation_variant
                            edit_reservation
                            list_product_reservations
                        ) );
}

my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Schema Sanity Check' );

#---- Test Functions ------------------------------------------

_test_func_params($schema,1);
_test_reservation_funcs($schema,1);
_test_email_funcs($schema,1);
_test_cancelling_reservation($schema,1);

#--------------------------------------------------------------

done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# This tests reservation functions
sub _test_reservation_funcs {

    my $schema  = shift;

    my $test;
    my $tmp;
    my @tmp;

    # get the all of the fields for a 'reservation' record
    # so as to populate below expected fields when 'reservation.*'
    # is used in queries
    my @reserv_rec_fields   = $schema->resultset('Public::Reservation')->result_source->columns;

    my %tests   = (
            'get_reservation_overview'  => {
                    # fields expected to be returned for various calls of the function
                    'fields'  => [
                            qw(
                                id
                                legacy_sku
                                product_name
                                description
                                designer
                                upload_date
                                reserved
                                preordered
                                season
                                ordered
                            )
                        ],
                },
            'get_reservation_list'      => {
                    # fields expected to be returned for various calls of the function
                    'fields'  => [
                            qw(
                                id
                                ordering_id
                                variant_id
                                customer_id
                                operator_id
                                date_created
                                date_uploaded
                                date_expired
                                status_id
                                notified
                                date_advance_contact
                                customer_note
                                note
                                channel_id
                                sales_channel
                                date_notified
                                creation_date
                                creation_ddmmyy
                                expiry_date
                                expiry_ddmmyy
                                uploaded_ddmmyy
                                legacy_sku
                                product_id
                                designer_size_id
                                live
                                product_name
                                designer
                                operator_name
                                status
                                is_customer_number
                                first_name
                                last_name
                                sku
                                department_id
                            )
                        ],
                },
            'get_reservation_products'  => {
                    # fields expected to be returned for various calls of the function
                    'fields'  => [
                            qw(
                                id
                                name
                                designer
                                product_type
                                season
                                live
                                channel_id
                            )
                        ],
                },
            'list_product_reservations' => {
                    # fields expected to be returned for various calls of the function
                    'fields'    => [
                            @reserv_rec_fields,
                            qw(
                                date_expired_long
                                operator_name
                                is_customer_number
                                first_name
                                last_name
                                status
                                sales_channel
                                reservation_source
                                reservation_type
                                expire_day
                                expire_month
                                expire_year
                                preorder
                                customer_class_id
                                customer_category
                                department_id
                            )
                        ],
                },
        );

    SKIP: {
        skip "_test_reservation_funcs", 1           if (!shift);

        note "TESTING Reservation Functions";

        $schema->txn_do( sub {

            my $dbh         = $schema->storage->dbh;
            my $reserv_rs   = $schema->resultset('Public::Reservation');

            # get Application Operator record
            my $app_operator= $schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID );

            # create another operator
            my $max_oper_id = $schema->resultset('Public::Operator')->search({})->get_column('id')->max();
            my $other_oper  = $schema->resultset('Public::Operator')->create( {
                                                        id          => $max_oper_id+1,
                                                        name        => 'TEST OP NAME',
                                                        username    => 'testshds.qwee120'.$$,
                                                        password    => 'new',
                                                        department_id   => $DEPARTMENT__FINANCE,
                                                    } );

            # update all reservations that are 'Pending' to be 'Cancelled'
            # to get them out of the way for the tests
            note "Cancelling existing reservations to get them out of the way first";
            $reserv_rs->search( { status_id => { 'IN' => [ $RESERVATION_STATUS__PENDING, $RESERVATION_STATUS__UPLOADED ] } } )
                            ->update( { status_id => $RESERVATION_STATUS__CANCELLED } );

            my ($channel, $tmp)     = Test::XTracker::Data->grab_products( { how_many => 1, ensure_stock_all_variants => 1 } );
            my $pid         = $tmp->[0];
            my $pc          = $pid->{product_channel};
            my $season      = $pid->{product}->season->season;
            my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

            # get a Stock Management object to pass to some functions
            my $stock_manager   = XTracker::WebContent::StockManagement->new_stock_manager( { schema => $schema, channel_id => $channel->id } );

            # get a Reservation Source and an Alternative
            my ( $reserv_source, $alt_source )  = $schema->resultset('Public::ReservationSource')
                                                    ->search( {}, { order_by => 'me.id DESC', limit => 2 } )->all;

            # delete any reservations for the Customer & Product
            Test::XTracker::Data->delete_reservations( { customer => $customer } );
            Test::XTracker::Data->delete_reservations( { product => $pid->{product} } );


            #
            # testing 'create_reservation' and 'get_reservation_details' functions
            #

            note "testing 'create_reservation' & 'get_reservation_details' functions";
            $pc->update( { live => 0 } );       # make product non-live
            my $reserv_id   = create_reservation( $dbh, $stock_manager, {
                                                                channel                 => $channel->name,
                                                                channel_id              => $channel->id,
                                                                variant_id              => $pid->{variant_id},
                                                                customer_id             => $customer->id,
                                                                operator_id             => $APPLICATION_OPERATOR_ID,
                                                                customer_nr             => $customer->is_customer_number,
                                                                reservation_source_id   => $reserv_source->id,
                                                        } );
            ok( $reserv_id && $reserv_id > 0, "Got a Reservation Id back from 'create_reservation' function" );
            my $reservation = $customer->reservations->first;
            isa_ok( $reservation, 'XTracker::Schema::Result::Public::Reservation', "Customer has a Reservation record" );
            cmp_ok( $reserv_id, '==', $reservation->id, "Customer's Reservation Id is the same as the Reservation Created" );
            my %reserv_fields   = $reservation->get_columns();
            my %expected        = (
                            channel_id              => $channel->id,
                            variant_id              => $pid->{variant_id},
                            customer_id             => $customer->id,
                            operator_id             => $APPLICATION_OPERATOR_ID,
                            reservation_source_id   => $reserv_source->id,
                            status_id               => $RESERVATION_STATUS__PENDING,
                        );
            my %got             = map { $_ => $reserv_fields{ $_ } }
                                    grep { exists( $expected{ $_ } ) }
                                        keys %reserv_fields;
            is_deeply( \%got, \%expected, "and Reservation Created with Expected Values" );

            my $reserv_dets = get_reservation_details( $dbh, $reserv_id );
            isa_ok( $reserv_dets, 'HASH', "'get_reservation_details' Returned as Expected" );
            %expected   = (
                    %reserv_fields,
                    legacy_sku          => $pid->{variant}->legacy_sku,
                    product_id          => $pid->{pid},
                    designer_size_id    => $pid->{variant}->designer_size_id,
                    product_name        => $pid->{product}->product_attribute->name,
                    designer            => $pid->{product}->designer->designer,
                    operator_name       => $schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID )->name,
                    status              => $reservation->status->status,
                    is_customer_number  => $customer->is_customer_number,
                    first_name          => $customer->first_name,
                    last_name           => $customer->last_name,
                    email               => $customer->email,
                    sales_channel       => $channel->name,
                );
            is_deeply( $reserv_dets, \%expected, "and HASH contains expected data" );

            note "testing 'create_reservation' for a LIVE product";
            $pc->update( { live => 1 } );       # make product live
            my $new_reserv_id   = create_reservation( $dbh, $stock_manager, {
                                                                channel                 => $channel->name,
                                                                channel_id              => $channel->id,
                                                                variant_id              => $pid->{variant_id},
                                                                customer_id             => $customer->id,
                                                                operator_id             => $APPLICATION_OPERATOR_ID,
                                                                customer_nr             => $customer->is_customer_number,
                                                                reservation_source_id   => $reserv_source->id,
                                                        } );
            cmp_ok( $new_reserv_id, '>', $reserv_id, "New Reservation Created" );
            $reservation    = $reserv_rs->find( $new_reserv_id );
            cmp_ok( $reservation->status_id, '==', $RESERVATION_STATUS__UPLOADED, "Reservation for a LIVE Product means Status is 'Uploaded'" );

            # delete Reservations for the Customer before starting new tests
            Test::XTracker::Data->delete_reservations( { customer => $customer } );


            #
            # testing 'edit_reservation' function
            #

            note "testing 'edit_reservation' function";

            # create some new Reservations
            $reservation    = $reserv_rs->create( {
                                        ordering_id     => 1,
                                        variant_id      => $pid->{variant_id},
                                        customer_id     => $customer->id,
                                        operator_id     => $APPLICATION_OPERATOR_ID,
                                        status_id       => $RESERVATION_STATUS__PENDING,
                                        channel_id      => $channel->id,
                                        reservation_source_id => $reserv_source->id,
                                        date_expired    => '2098-04-03',
                                    } );

            # create another reservation for other operator
            my $other_res   = $reserv_rs->create( {
                                        ordering_id     => 2,
                                        variant_id      => $pid->{variant_id},
                                        customer_id     => $customer->id,
                                        operator_id     => $other_oper->id,
                                        status_id       => $RESERVATION_STATUS__PENDING,
                                        channel_id      => $channel->id,
                                        reservation_source_id => $reserv_source->id,
                                    } );

            note "when making no changes";
            edit_reservation( $schema, $stock_manager, $channel->id, _build_edit_args( $reservation, {
                                                                notes       => '',
                                                                expireDay   => '00',
                                                                expireMonth => '00',
                                                                expireYear  => '00',
                                                                ordering    => $reservation->ordering_id,
                                                                new_reservation_source_id => 0,
                                                            } ) );
            cmp_ok( $reservation->discard_changes->reservation_source_id, '==', $reserv_source->id, "Reservation Source still the Same" );
            ok( !$reservation->note, "Notes still Empty" );
            is( $reservation->date_expired->ymd('-'), '2098-04-03', "Expiry Date still the Same" );
            cmp_ok( $reservation->ordering_id, '==', 1, "Ordering Id still 1" );

            note "now make changes";
            edit_reservation( $schema, $stock_manager, $channel->id, _build_edit_args( $reservation, {
                                                                notes       => 'a note',
                                                                expireDay   => '02',
                                                                expireMonth => '05',
                                                                expireYear  => '2091',
                                                                ordering    => 2,
                                                                new_reservation_source_id => $alt_source->id,
                                                            } ) );
            cmp_ok( $reservation->discard_changes->reservation_source_id, '==', $alt_source->id, "Reservation Source Now: '" . $alt_source->source . "'" );
            ok( $reservation->note && $reservation->note eq 'a note', "Notes is now: 'a note'" );
            is( $reservation->date_expired->ymd('-'), '2091-05-02', "Expiry Date is now: '2091-05-02'" );
            cmp_ok( $reservation->ordering_id, '==', 2, "Ordering Id is now: 2" );

            note "try setting the expiry date to an invalid date";
            throws_ok { edit_reservation( $schema, $stock_manager, $channel->id, _build_edit_args( $reservation, {
                                                                notes       => 'a note about invalid dates',
                                                                expireDay   => '31',
                                                                expireMonth => '04',
                                                                expireYear  => '2013',
                                                                ordering    => $reservation->ordering_id,
                                                                new_reservation_source_id => 0,
                                                            } ) );
            } qr/expiry date '2013-04-31' is not a valid date/, "Setting invalid date dies properly";
            is( $reservation->date_expired->ymd('-'), '2091-05-02', "Expiry Date is still: '2091-05-02'" );

            note "make changes with a NULL reservation source";
            $reservation->update( { reservation_source_id => undef } );
            edit_reservation( $schema, $stock_manager, $channel->id, _build_edit_args( $reservation, {
                                                                new_reservation_source_id => $reserv_source->id,
                                                            } ) );
            cmp_ok( $reservation->discard_changes->reservation_source_id, '==', $reserv_source->id,
                                                        "Reservation Source back to being: '" . $reserv_source->source . "'" );


            # generate a Pre-Order with a Reservation, this Reservation should not
            # be included in the 'reserved' column but should be included in the 'preordered' column
            $pc->update( { live => 0 } );       # make product NON-Live, so Reservations will start of as 'Pending'
            my $preord_res  = Test::XTracker::Data::PreOrder->create_pre_order_reservations( {
                                                                            channel     => $channel,
                                                                            variants    => [ $pid->{variant} ],
                                                                            operator    => $app_operator,
                                                                        } )->[0];   # get the first Reservation of the ArrayRef
            $preord_res->update( { customer_id => $customer->id } );    # make it use the same Customer as everything else


            #
            # testing 'get_reservation_overview' function
            #

            note "testing 'get_reservation_overview' function";
            $test   = $tests{get_reservation_overview};

            note "test 'Pending' call";
            $pc->update( { live => 1 } );
            # call first as 'Waiting' to check product can't be found
            $tmp    = get_reservation_overview( $dbh, { channel_id => $channel->id, type => 'Waiting' } );
            ok( !exists( $tmp->{ $season }{1} ), "DID NOT Find entry for product's season: $season in HASH when called using 'Waiting' type" );
            $tmp    = get_reservation_overview( $dbh, { channel_id => $channel->id, type => 'Pending' } );
            isa_ok( $tmp, 'HASH', "Pending: 'get_reservation_overview' function returns a 'HASH'" );
            ok( exists( $tmp->{ $season }{1} ), "Found entry for product's season: $season in HASH" );
            $tmp    = $tmp->{ $season }{1};     # get the row for the product that's been reserved
            is_deeply( [ sort keys %{ $tmp } ], [ sort @{ $test->{fields} } ], "Got Expected Fields from 'get_reservation_overview'" );
            cmp_ok( $tmp->{id}, '==', $pid->{pid}, "Found correct PID: $$pid{pid} in row" );
            cmp_ok( $tmp->{reserved}, '==', 2, "Reserved Quantity is correct as 1" );
            cmp_ok( $tmp->{preordered}, '==', 0, "PreOrder Quantity is correct as 0" );

            note "test 'Waiting' call";
            $pc->update( { live => 0 } );       # make product non-live
            # call first as 'Pending' to check product can't be found
            $tmp    = get_reservation_overview( $dbh, { channel_id => $channel->id, type => 'Pending' } );
            ok( !exists( $tmp->{ $season }{1} ), "DID NOT Find entry for product's season: $season in HASH when called using 'Pending' type" );
            $tmp    = get_reservation_overview( $dbh, { channel_id => $channel->id, type => 'Waiting' } );
            isa_ok( $tmp, 'HASH', "Waiting: 'get_reservation_overview' function returns a 'HASH'" );
            ok( exists( $tmp->{ $season }{1} ), "Found entry for product's season: $season in HASH" );
            $tmp    = $tmp->{ $season }{1};     # get the row for the product that's been reserved
            is_deeply( [ sort keys %{ $tmp } ], [ sort @{ $test->{fields} } ], "Got Expected Fields from 'get_reservation_overview'" );
            cmp_ok( $tmp->{id}, '==', $pid->{pid}, "Found correct PID: $$pid{pid} in row" );
            cmp_ok( $tmp->{reserved}, '==', 2, "Reserved Quantity is correct as 1" );
            cmp_ok( $tmp->{preordered}, '==', 0, "PreOrder Quantity is correct as 0" );

            note "test 'Upload' call";
            $pc->update( { live => 1, upload_date => \'now()' } );       # make product live set upload date to now
            $pc->discard_changes;
            $tmp    = get_reservation_overview( $dbh, { channel_id => $channel->id, type => 'Upload', upload_date => $pc->upload_date->dmy } );
            isa_ok( $tmp, 'HASH', "Upload: 'get_reservation_overview' function returns a 'HASH'" );
            ok( exists( $tmp->{ $season }{1} ), "Found entry for product's season: $season in HASH" );
            $tmp    = $tmp->{ $season }{1};     # get the row for the product that's been reserved
            is_deeply( [ sort keys %{ $tmp } ], [ sort @{ $test->{fields} } ], "Got Expected Fields from 'get_reservation_overview'" );
            cmp_ok( $tmp->{id}, '==', $pid->{pid}, "Found correct PID: $$pid{pid} in row" );
            cmp_ok( $tmp->{reserved}, '==', 2, "Reserved Quantity is correct as 1" );
            cmp_ok( $tmp->{preordered}, '==', 1, "PreOrder Quantity is correct as 0" );

            note "test calling without wanting Stock Order Quantities";
            $tmp    = get_reservation_overview( $dbh, { channel_id => $channel->id, type => 'Pending', get_so_ord_qty => 0 } );
            isa_ok( $tmp, 'HASH', "Upload: 'get_reservation_overview' function returns a 'HASH'" );
            ok( exists( $tmp->{ $season }{1} ), "Found entry for product's season: $season in HASH" );
            $tmp    = $tmp->{ $season }{1};     # get the row for the product that's been reserved
            ok( !exists( $tmp->{ordered} ), "Did NOT find 'ordered' key in row hash" );



            #
            # testing 'get_reservation_list' function
            #

            note "testing 'get_reservation_list' function";
            $test   = $tests{get_reservation_list};

            note "test 'Pending' call";
            $pc->update( { live => 1 } );       # make product live

            # call first as 'Waiting' & 'Live' to check reservation can't be found
            $tmp    = get_reservation_list( $dbh, { channel_id => $channel->id, type => 'waiting', operator_id => $APPLICATION_OPERATOR_ID } );
            cmp_ok( keys %{ $tmp }, '==', 0, "DID NOT find any rows when called using 'Waiting' type" );
            $tmp    = get_reservation_list( $dbh, { channel_id => $channel->id, type => 'live', operator_id => $APPLICATION_OPERATOR_ID } );
            cmp_ok( keys %{ $tmp }, '==', 0, "DID NOT find any rows when called using 'live' type" );

            $tmp    = get_reservation_list( $dbh, { channel_id => $channel->id, type => 'pending', operator_id => $APPLICATION_OPERATOR_ID } );
            isa_ok( $tmp, 'HASH', "Pending: 'get_reservation_list' function returns a 'HASH'" );
            cmp_ok( keys %{ $tmp->{ $channel->name } }, '==', 1, "Found 1 reservation" );
            ok( exists( $tmp->{ $channel->name }{ $reservation->id } ), "Found entry for reservation in correct Sales Channel's HASH" );
            $tmp    = $tmp->{ $channel->name }{ $reservation->id };
            is_deeply( [ sort keys %{ $tmp } ], [ sort @{ $test->{fields} } ], "Got Expected Fields from 'get_reservation_list'" );

            note "test 'Waiting' call";
            $pc->update( { live => 0 } );       # make product non-live

            # call first as 'Pending' & 'Live' to check reservation can't be found
            $tmp    = get_reservation_list( $dbh, { channel_id => $channel->id, type => 'pending', operator_id => $APPLICATION_OPERATOR_ID } );
            cmp_ok( keys %{ $tmp }, '==', 0, "DID NOT find any rows when called using 'Pending' type" );
            $tmp    = get_reservation_list( $dbh, { channel_id => $channel->id, type => 'live', operator_id => $APPLICATION_OPERATOR_ID } );
            cmp_ok( keys %{ $tmp }, '==', 0, "DID NOT find any rows when called using 'live' type" );

            $tmp    = get_reservation_list( $dbh, { channel_id => $channel->id, type => 'waiting', operator_id => $APPLICATION_OPERATOR_ID } );
            isa_ok( $tmp, 'HASH', "Waiting: 'get_reservation_list' function returns a 'HASH'" );
            cmp_ok( keys %{ $tmp->{ $channel->name } }, '==', 1, "Found 1 reservation" );
            ok( exists( $tmp->{ $channel->name }{ $reservation->id } ), "Found entry for reservation in correct Sales Channel's HASH" );
            $tmp    = $tmp->{ $channel->name }{ $reservation->id };
            is_deeply( [ sort keys %{ $tmp } ], [ sort @{ $test->{fields} } ], "Got Expected Fields from 'get_reservation_list'" );

            note "test 'Live' call";
            # set reservations up properly
            foreach my $rec ( $reservation, $other_res, $preord_res ) {
                $rec->update( { status_id => $RESERVATION_STATUS__UPLOADED } );
            }

            # call first as 'Pending' & 'Waiting' to check reservation can't be found
            $tmp    = get_reservation_list( $dbh, { channel_id => $channel->id, type => 'pending', operator_id => $APPLICATION_OPERATOR_ID } );
            cmp_ok( keys %{ $tmp }, '==', 0, "DID NOT find any rows when called using 'Pending' type" );
            $tmp    = get_reservation_list( $dbh, { channel_id => $channel->id, type => 'waiting', operator_id => $APPLICATION_OPERATOR_ID } );
            cmp_ok( keys %{ $tmp }, '==', 0, "DID NOT find any rows when called using 'waiting' type" );

            $tmp    = get_reservation_list( $dbh, { channel_id => $channel->id, type => 'live', operator_id => $APPLICATION_OPERATOR_ID } );
            isa_ok( $tmp, 'HASH', "Live: 'get_reservation_list' function returns a 'HASH'" );
            cmp_ok( keys %{ $tmp->{ $channel->name } }, '==', 1, "Found 1 reservation" );
            ok( exists( $tmp->{ $channel->name }{ $reservation->id } ), "Found entry for reservation in correct Sales Channel's HASH" );
            $tmp    = $tmp->{ $channel->name }{ $reservation->id };
            is_deeply( [ sort keys %{ $tmp } ], [ sort @{ $test->{fields} } ], "Got Expected Fields from 'get_reservation_list'" );

            note "test function to get ALL reservations not just for a specific operator";
            $tmp    = get_reservation_list( $dbh, { channel_id => $channel->id, type => 'live' } );
            cmp_ok( keys %{ $tmp->{ $channel->name } }, '==', 2, "Found 2 reservations" );
            ok( exists( $tmp->{ $channel->name }{ $reservation->id } ), "Found entry for 1st reservation in HASH" );
            ok( exists( $tmp->{ $channel->name }{ $other_res->id } ), "Found entry for 2nd reservation in HASH" );


            #
            # testing 'get_reservation_products' function
            #

            note "testing 'get_reservation_products' function";
            $test   = $tests{get_reservation_products};

            my $all_pc      = $pid->{product}->product_channel->search;     # get all product channel recs for the product
            my $season_id   = $pid->{product}->season_id;
            my $designer_id = $pid->{product}->designer_id;
            my $prodtype_id = $pid->{product}->product_type_id;

            $all_pc->update( { live => 1 } );       # make product live
            $tmp    = get_reservation_products( $dbh, $designer_id, $season_id, $prodtype_id );
            isa_ok( $tmp, 'HASH', "'get_reservation_products' function returns a 'HASH'" );
            ok( exists( $tmp->{ $pid->{pid} } ), "Found Product Id in HASH" );
            $tmp    = $tmp->{ $pid->{pid } };
            is_deeply( [ sort keys %{ $tmp } ], [ sort @{ $test->{fields} } ], "Got Expected Fields from 'get_reservation_products'" );
            cmp_ok( $tmp->{live}, '==', 1, "Product 'live' flag is TRUE" );

            # do search again but this time with the product not 'live'
            $all_pc->update( { live => 0 } );       # make product non-live
            $tmp    = get_reservation_products( $dbh, $designer_id, $season_id, $prodtype_id );
            cmp_ok( $tmp->{ $pid->{pid} }{live}, '==', 0, "Product 'live' flag is FALSE" );


            #
            # testing 'list_product_reservations' function
            #

            note "testing 'list_product_reservations' function";
            $test   = $tests{list_product_reservations};

            # set-up dates
            $reservation->update( {
                                    date_created    => '2098-05-04',
                                    date_uploaded   => '2089-06-03',
                                    date_expired    => undef,
                                } );

            $tmp    = list_product_reservations( $dbh, $pid->{pid} );
            isa_ok( $tmp, 'HASH', "'list_product_reservations' function returns a 'HASH'" );
            ok( exists( $tmp->{ $channel->name }{ $reservation->id } ), "Found Reservation Id in HASH" );
            $tmp    = $tmp->{ $channel->name }{ $reservation->id };
            is_deeply( [ sort keys %{ $tmp } ], [ sort @{ $test->{fields} } ], "Got Expected Fields from 'list_product_reservations'" );
            is( $tmp->{operator_name}, $reservation->operator->name, "Operator Name as Expected" );
            is( $tmp->{is_customer_number}, $customer->is_customer_number, "Customer Number as Expected" );
            is( $tmp->{first_name}, $customer->first_name, "Customer First Name as Expected" );
            is( $tmp->{last_name}, $customer->last_name, "Customer Last Name as Expected" );
            is( $tmp->{status}, $reservation->status->status, "Reservation Status as Expected" );
            is( $tmp->{sales_channel}, $channel->name, "Sales Channel as Expected" );
            cmp_ok( $tmp->{reservation_source_id}, '==', $reserv_source->id, "Reservation Source Id as Expected" );
            is( $tmp->{reservation_source}, $reserv_source->source, "Reservation Source as Expected" );
            is( $tmp->{date_created}, '04-05', "'date_created' formatted as Expected" );
            is( $tmp->{date_uploaded}, '03-06', "'date_uploaded' formatted as Expected" );
            ok( !$tmp->{date_expired_long}, "'date_expired_long' empty as Expected" );
            is( $tmp->{expire_day}, '00', "With NULL Expiry Date, 'expire_day' is '00'" );
            is( $tmp->{expire_month}, '00', "With NULL Expiry Date, 'expire_month' is '00'" );
            is( $tmp->{expire_year}, '00', "With NULL Expiry Date, 'expire_year' is '00'" );

            $reservation->update( { date_expired => '2099-03-02' } );   # use with an expiry date
            $tmp    = list_product_reservations( $dbh, $pid->{pid} );
            $tmp    = $tmp->{ $channel->name }{ $reservation->id };
            is( $tmp->{date_expired_long}, '02-03-2099', "With Expiry Date as '2099-03-02', 'date_expired_long' formatted as Expected" );
            is( $tmp->{expire_day}, '02', "With Expiry Date as '2099-03-02', 'expire_day' is '02'" );
            is( $tmp->{expire_month}, '03', "With Expiry Date as '2099-03-02', 'expire_month' is '03'" );
            is( $tmp->{expire_year}, '2099', "With Expiry Date as '2099-03-02', 'expire_year' is '2099'" );

            note "test different Statuses that should show up in the list or not";
            my %statuses    = map { $_->id => $_ }
                                    $schema->resultset('Public::ReservationStatus')->search->all;
            my @not_in_list = map { delete $statuses{ $_ } }
                                    (
                                        $RESERVATION_STATUS__CANCELLED,
                                        $RESERVATION_STATUS__EXPIRED,
                                    );
            my @in_list     = values %statuses;

            # NOT IN LIST
            foreach my $status ( @not_in_list ) {
                $reservation->update( { status_id => $status->id } );
                $tmp    = list_product_reservations( $dbh, $pid->{pid} );
                ok( !exists( $tmp->{ $channel->name }{ $reservation->id } ), "Status: " . $status->status . ", NOT In List" );
            }

            # IN LIST
            foreach my $status ( @in_list ) {
                $reservation->update( { status_id => $status->id } );
                $tmp    = list_product_reservations( $dbh, $pid->{pid} );
                ok( exists( $tmp->{ $channel->name }{ $reservation->id } ), "Status: " . $status->status . ", IN List" );
            }

            note "check with NULL Reservation Source still get records back - checking LEFT JOIN";
            $reservation->discard_changes->update( { reservation_source_id => undef } );
            $tmp    = list_product_reservations( $dbh, $pid->{pid} );
            isa_ok( $tmp, 'HASH', "'list_product_reservations' function returns a 'HASH'" );
            ok( exists( $tmp->{ $channel->name }{ $reservation->id } ), "Found Reservation Id in HASH" );
            $tmp    = $tmp->{ $channel->name }{ $reservation->id };
            ok( !defined $tmp->{reservation_source_id}, "Reservation Source Id is 'undef'" );
            is_deeply( [ sort keys %{ $tmp } ], [ sort @{ $test->{fields} } ], "Got Expected Fields from 'list_product_reservations'" );


            # undo any changes
            $schema->txn_rollback();
        } );

    }
}

# this tests a couple of functions used in email notifications
sub _test_email_funcs {
    my $schema  = shift;

    SKIP: {
        skip "_test_email_funcs", 1         if ( !shift );

        note "TESTING Email Related Functions";

        my @channels    = $schema->resultset('Public::Channel')->all;

        my $operator_name   = "First Last";

        $schema->txn_do( sub {
            foreach my $channel ( @channels ) {
                note "testing for: ".$channel->name;

                my $channel_config  = $channel->business->config_section;
                my $business_id     = $channel->business_id;

                my $email_cust_care = customercare_email( $channel_config );
                my $email_pers_shop = personalshopping_email( $channel_config );
                my $email_fash_advi = fashionadvisor_email( $channel_config );

                # set-up French localised versions of the Email Addresses
                my $localised_email_rs  = $schema->resultset('Public::LocalisedEmailAddress');
                $localised_email_rs->search->delete;
                foreach my $address ( $email_cust_care, $email_pers_shop, $email_fash_advi ) {
                    $localised_email_rs->update_or_create( {
                        email_address           => $address,
                        locale                  => 'fr_FR',
                        localised_email_address => "local.${address}",
                    } );
                }

                # these will be common to all tests
                my %sign_off_name_parts = (
                    name    => {
                        full    => $operator_name,
                        first   => 'First',
                        last    => 'Last',
                    },
                );

                my %tests   = (
                        'Customer Care' => {
                            department_id   => $DEPARTMENT__CUSTOMER_CARE,
                            email_address   => $email_cust_care,
                            sign_off        => "First<br/>Customer Care",
                            sign_off_parts  => {
                                %sign_off_name_parts,
                                role    => {
                                    name    => 'Customer Care',
                                    id      => $DEPARTMENT__CUSTOMER_CARE,
                                },
                            },
                        },
                        'Customer Care Manager' => {
                            department_id   => $DEPARTMENT__CUSTOMER_CARE_MANAGER,
                            email_address   => $email_cust_care,
                            sign_off        => "First<br/>Customer Care",
                            sign_off_parts  => {
                                %sign_off_name_parts,
                                role    => {
                                    name    => 'Customer Care',
                                    id      => $DEPARTMENT__CUSTOMER_CARE,
                                },
                            },
                        },
                        'Fashion Advisor' => {
                            department_id   => $DEPARTMENT__FASHION_ADVISOR,
                            email_address   => $email_fash_advi,
                            sign_off        => "First<br/>Fashion Consultant",
                            sign_off_parts  => {
                                %sign_off_name_parts,
                                role    => {
                                    name    => 'Fashion Consultant',
                                    id      => $DEPARTMENT__FASHION_ADVISOR,
                                },
                            },
                        },
                        'Personal Shopping' => {
                            department_id   => $DEPARTMENT__PERSONAL_SHOPPING,
                            email_address   => $email_pers_shop,
                            sign_off        => "First<br/>Personal Shopper",
                            sign_off_parts  => {
                                %sign_off_name_parts,
                                role    => {
                                    name    => 'Personal Shopper',
                                    id      => $DEPARTMENT__PERSONAL_SHOPPING,
                                },
                            },
                        },
                        'Any other Department'  => {
                            department_id   => $DEPARTMENT__SHIPPING,
                            email_address   => $email_cust_care,
                            sign_off        => "First<br/>Customer Care",
                            sign_off_parts  => {
                                %sign_off_name_parts,
                                role    => {
                                    name    => 'Customer Care',
                                    id      => $DEPARTMENT__CUSTOMER_CARE,
                                },
                            },
                        },
                    );

                foreach my $test_label ( sort keys %tests ) {
                    note "testing: ".$test_label;

                    my $test= $tests{ $test_label };

                    my $got = get_from_email_address( { channel_config => $channel_config, department_id => $test->{department_id} } );
                    is( $got, $test->{email_address}, "Without Localisation, From Email Address correct for department: '${got}'" );

                    $got    = get_from_email_address( {
                        channel_config  => $channel_config,
                        department_id   => $test->{department_id},
                        schema          => $schema,
                        locale          => 'fr_FR',
                    } );
                    is( $got, "local." . $test->{email_address}, "With Localisation, From Email Address correct for department: '${got}'" );

                    # All Mr. Porter Sign-Offs are the same regardless
                    # of Department, just the Name of the Operator, so
                    # override the expected sign-off with this instead
                    if ( $channel_config eq "MRP" ) {
                        $test->{sign_off}   = $operator_name;
                    }

                    $got    = get_email_signoff( {
                                                business_id     => $business_id,
                                                department_id   => $test->{department_id},
                                                operator_name   => $operator_name,
                                            } );
                    is( $got, $test->{sign_off}, "Sign-Off correct for department: ".$test->{sign_off} );

                    $got    = get_email_signoff_parts( {
                                                department_id   => $test->{department_id},
                                                operator_name   => $operator_name,
                                            } );
                    is_deeply( $got, $test->{sign_off_parts}, "Sign-Off parts as expected" );
                }
            }


            # undo any changes
            $schema->txn_rollback();
        } );
    };
}

# this tests the functions used in Cancelling Reservations
sub _test_cancelling_reservation {
    my ( $schmea, $oktodo )     = @_;

    my $dbh = $schema->storage->dbh;

    SKIP: {
        skip "_test_cancelling_reservation", 1      if ( !$oktodo );

        note "TESTING functions used in Cancelling a Reservation";

        $schema->txn_do( sub {
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
                                                                how_many => 1,
                                                                how_many_variants => 2,
                                                                channel => Test::XTracker::Data->channel_for_nap,
                                                                ensure_stock_all_variants => 1,
                                                            } );

            my $upload_max_log  = $schema->resultset('Public::ReservationLog')
                                            ->search( { reservation_status_id => $RESERVATION_STATUS__UPLOADED } )
                                                ->get_column('id');

            my $variant = $pids->[0]{variant};
            # get an alternative size for the Product
            my ( $alt_variant ) = grep { $_->size_id != $variant->size_id } $pids->[0]{product}->variants->all;
            note "Variant            : ".$variant->sku;
            note "Alternative Variant: ".$alt_variant->sku;

            # clear any existing Reservations from these Variants
            $variant->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED, ordering_id => 0 } );
            $alt_variant->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED, ordering_id => 0 } );

            # clear any Cancelled Items or Shipment Items to make checking the Stock more reliable for both SKU's
            my @canc_items  = $variant->shipment_items->search( { shipment_item_status_id => { 'IN' => [
                                                                                                        $SHIPMENT_ITEM_STATUS__CANCELLED,
                                                                                                        $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                                                                                                    ],
                                                                                                } } )->all;
            $variant->shipment_items->search( { shipment_item_status_id => { '!=' => $SHIPMENT_ITEM_STATUS__CANCELLED } } )
                                        ->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED } );
            @canc_items = $alt_variant->shipment_items->search( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED } )->all;
            $alt_variant->shipment_items->search( { shipment_item_status_id => { '!=' => $SHIPMENT_ITEM_STATUS__CANCELLED } } )
                                        ->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED } );

            # get XT Stock Level for a Variant
            $variant->quantities->update( { quantity => 0 } );      # clear down existing stock
            my $xt_stock    = $variant->quantities->search( { channel_id => $channel->id, status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS } )->first;
            $xt_stock->update( { quantity => 100 } );

            # overload 'get_web_stock_level' to always return 100
            my $web_stock_level = 100;
            no warnings 'redefine';
            *XTracker::WebContent::StockManagement::OurChannels::get_web_stock_level    = sub { return $web_stock_level; };
            use warnings 'redefine';

            # get a Stock Management object to pass to the functions
            my $stock_manager   = XTracker::WebContent::StockManagement->new_stock_manager( { schema => $schema, channel_id => $channel->id } );

            # create 5 Reservations first
            my @reservs = _create_reservations( 7, $channel, $variant );
            my $max_res_id  = $reservs[-1]->id;

            note "cancel the first Pending Reservation using 'cancel_reservation' and nothing should be Uploaded";
            cancel_reservation( $dbh, $stock_manager, _build_cancel_args( $reservs[0] ) );
            _check_reservation_statuses_ok( $reservs[0], undef, [ @reservs[ 1..$#reservs ] ], { cancel_with_no_log => 1 } );

            note "Upload the Second Reservation and then Cancel it using the 'skip_upload_reservations' flag and Nothing Should get Uploaded";
            $reservs[1]->update( { status_id => $RESERVATION_STATUS__UPLOADED } );
            cancel_reservation( $dbh, $stock_manager, _build_cancel_args( $reservs[1], { skip_upload_reservations => 1 } ) );
            _check_reservation_statuses_ok( $reservs[1], undef, [ @reservs[ 2..$#reservs ] ] );

            note "Upload the Third Reservation and then Cancel it, which should upload the Fourth Reservation";
            $reservs[2]->update( { status_id => $RESERVATION_STATUS__UPLOADED } );
            cancel_reservation( $dbh, $stock_manager, _build_cancel_args( $reservs[2] ) );
            _check_reservation_statuses_ok( $reservs[2], $reservs[3], [ @reservs[ 4..$#reservs ] ] );

            note "Use 'update_reservation_variant' for the Fourth Reservation to change it's";
            note "Variant which should Cancel the Original and Upload the Fifth Reservation";
            update_reservation_variant( $dbh, $stock_manager, $reservs[3]->id, $alt_variant->id );
            _check_reservation_statuses_ok( $reservs[3], $reservs[4], [ @reservs[ 5..$#reservs ] ] );
            my $new_res = $alt_variant->reservations->search( {}, { order_by => 'id DESC' } )->first;
            isa_ok( $new_res, 'XTracker::Schema::Result::Public::Reservation', "Found a New Reservation for the Alternative Variant" );
            cmp_ok( $new_res->id, '>', $max_res_id, "New Reservation's Id is Greater than the Reservations created Earlier" );
            cmp_ok( $new_res->customer_id, '==', $reservs[3]->customer_id, "New Reservation is for the Same Customer as the Cancelled One" );
            # check to make sure the Reservation Source has been copied to the new record
            ok( defined $new_res->reservation_source_id, "New Reservation has a Source Id" );
            cmp_ok( $new_res->reservation_source_id, '==', $reservs[3]->reservation_source_id,
                                                "Reservation Source has been Copied from the Cancelled Reservation to the New one" );
            $max_res_id = $new_res->id;

            note "Use 'edit_reservation' to change the Fifth Reservation but without";
            note "changing it's Variant and nothing should get Cancelled or Uploaded";
            edit_reservation( $schema, $stock_manager, $channel->id, _build_edit_args( $reservs[4] ) );
            _check_reservation_statuses_ok( undef, $reservs[4], [ @reservs[ 5..$#reservs ] ] );

            note "Use 'edit_reservation' to change the Fifth Reservation WITH changing it's Variant";
            note "which should Cancel the Reservation and the Sixth Reservation should be Uploaded";
            edit_reservation( $schema, $stock_manager, $channel->id, _build_edit_args( $reservs[4], { changeSize => $alt_variant->id } ) );
            _check_reservation_statuses_ok( $reservs[4], $reservs[5], [ @reservs[ 6..$#reservs ] ] );
            $new_res    = $alt_variant->reservations->search( {}, { order_by => 'id DESC' } )->first;
            isa_ok( $new_res, 'XTracker::Schema::Result::Public::Reservation', "Found a New Reservation for the Alternative Variant" );
            cmp_ok( $new_res->id, '>', $max_res_id, "New Reservation's Id is Greater than the Reservation created Earlier" );
            cmp_ok( $new_res->customer_id, '==', $reservs[4]->customer_id, "New Reservation is for the Same Customer as the Cancelled One" );

            note "Cancel the Sixth Reservation with -1 XT Stock Level, nothing Should get Uploaded";
            $xt_stock->update( { quantity => 0 } );
            cancel_reservation( $dbh, $stock_manager, _build_cancel_args( $reservs[5] ) );
            _check_reservation_statuses_ok( $reservs[5], undef, [ @reservs[ 6..$#reservs ] ] );

            note "Cancel the Sixth Reservation with enough XT Stock Level but -1 Web Stock Level, nothing Should get Uploaded";
            $reservs[5]->update( { status_id => $RESERVATION_STATUS__UPLOADED, ordering_id => 100 } );
            $web_stock_level    = -1;
            $xt_stock->update( { quantity => 100 } );
            cancel_reservation( $dbh, $stock_manager, _build_cancel_args( $reservs[5] ) );
            _check_reservation_statuses_ok( $reservs[5], undef, [ @reservs[ 6..$#reservs ] ] );

            note "Cancel the Sixth Reservation with ZERO XT Stock Level excluding the Uploaded Reservation and enough Web Stock Level, should still Upload the Seventh";
            $reservs[5]->update( { status_id => $RESERVATION_STATUS__UPLOADED, ordering_id => 100 } );
            $web_stock_level    = 100;
            $xt_stock->update( { quantity => 1 } );
            cancel_reservation( $dbh, $stock_manager, _build_cancel_args( $reservs[5] ) );
            _check_reservation_statuses_ok( $reservs[5], $reservs[6] );

            note "Cancel the Seventh Reservation with no more Pending to do nothing should get Uploaded";
            my $max_log_id  = $upload_max_log->max();
            cancel_reservation( $dbh, $stock_manager, _build_cancel_args( $reservs[6] ) );
            _check_reservation_statuses_ok( $reservs[6] );
            cmp_ok( $upload_max_log->max(), '==', $max_log_id, "No New 'Uploaded' Log Entry has been Created" );


            # rollback changes
            $stock_manager->rollback;
            $schema->txn_rollback;
        } );
    };

    return;
}

# this tests various functions requrired parameters
sub _test_func_params {
    my $schema      = shift;

    my $dbh     = $schema->storage->dbh;

    my $stock_manager   = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                    schema      => $schema,
                                                    channel_id  => Test::XTracker::Data->channel_for_nap()->id,
                                            } );

    SKIP: {
        skip "_test_func_params", 1         if ( !shift );

        my $param_check = Test::XTracker::ParamCheck->new();

        note "TESTING for Function Required Parameters";

        note "testing 'get_from_email_address'";
        $param_check->check_for_params(
                            \&get_from_email_address,
                            'get_from_email_address',
                            [ { channel_config => 'NAP', department_id => $DEPARTMENT__CUSTOMER_CARE } ],
                            [ "'get_from_email_address' function requires a HASH Ref" ],
                            [ [ 'array ref' ] ],
                            [ "'get_from_email_address' function requires a HASH Ref" ],
                        );
        $param_check->check_for_hash_params(
                            \&get_from_email_address,
                            'get_from_email_address',
                            [ { channel_config => 'NAP', department_id => $DEPARTMENT__CUSTOMER_CARE } ],
                            [ { channel_config => "function requires 'channel_config' option to be passed", department_id => "function requires 'department_id' option to be passed" } ],
                        );

        note "testing 'get_email_signoff'";
        $param_check->check_for_params(
                            \&get_email_signoff,
                            'get_email_signoff',
                            [ { business_id => $BUSINESS__NAP, department_id => $DEPARTMENT__CUSTOMER_CARE } ],
                            [ "'get_email_signoff' function requires a HASH Ref" ],
                            [ [ 'array ref' ] ],
                            [ "'get_email_signoff' function requires a HASH Ref" ],
                        );
        $param_check->check_for_hash_params(
                            \&get_email_signoff,
                            'get_email_signoff',
                            [ { business_id => $BUSINESS__NAP, department_id => $DEPARTMENT__CUSTOMER_CARE, operator_name => 'First Last' } ],
                            [ {
                                business_id => "function requires 'business_id' option to be passed",
                                department_id => "function requires 'department_id' option to be passed",
                                operator_name => "function requires 'operator_name' option to be passed",
                            } ],
                        );

        note "testing 'get_email_signoff_parts'";
        $param_check->check_for_params(
                            \&get_email_signoff_parts,
                            'get_email_signoff_parts',
                            [ { department_id => $DEPARTMENT__CUSTOMER_CARE } ],
                            [ "'get_email_signoff_parts' function requires a HASH Ref" ],
                            [ [ 'array ref' ] ],
                            [ "'get_email_signoff_parts' function requires a HASH Ref" ],
                        );
        $param_check->check_for_hash_params(
                            \&get_email_signoff_parts,
                            'get_email_signoff_parts',
                            [ { department_id => $DEPARTMENT__CUSTOMER_CARE, operator_name => 'First Last' } ],
                            [ {
                                department_id => "function requires 'department_id' option to be passed",
                                operator_name => "function requires 'operator_name' option to be passed",
                            } ],
                        );

        note "testing 'cancel_reservation'";
        $param_check->check_for_params(
                            \&cancel_reservation,
                            'cancel_reservation',
                            [ $dbh, $stock_manager, { hash => 'ref' } ],
                            [
                                "No DBH passed to 'cancel_reservation'",
                                "No 'Stock Management' object passed to 'cancel_reservation'",
                                "No ARGS Hash Ref passed to 'cancel_reservation'",
                            ],
                            [ undef, 'Not a Stock Management Object', 'Not a HASH Ref' ],
                            [
                                undef,
                                "No 'Stock Management' object passed to 'cancel_reservation'",
                                "No ARGS Hash Ref passed to 'cancel_reservation'",
                            ],
                        );

        note "testing 'update_reservation_variant'";
        $param_check->check_for_params(
                            \&update_reservation_variant,
                            'update_reservation_variant',
                            [ $dbh, $stock_manager, 101, 201 ],
                            [
                                "No DBH passed to 'update_reservation_variant'",
                                "No 'Stock Management' object passed to 'update_reservation_variant'",
                                "No Reservation Id passed to 'update_reservation_variant'",
                                "No New Variant Id passed to 'update_reservation_variant'",
                            ],
                            [ undef, 'Not a Stock Management Object' ],
                            [
                                undef,
                                "No 'Stock Management' object passed to 'update_reservation_variant'",
                            ],
                        );

        note "testing 'edit_reservation'";
        $param_check->check_for_params(
                            \&edit_reservation,
                            'edit_reservation',
                            [ $schema, $stock_manager, 1, { hash => 'ref' } ],
                            [
                                "No Schema passed to 'edit_reservation'",
                                "No 'Stock Management' object passed to 'edit_reservation'",
                                "No Channel Id passed to 'edit_reservation'",
                                "No Params Hash Ref passed to 'edit_reservation'",
                            ],
                            [ $dbh, 'Not a Stock Management Object', undef, 'Not a HASH Ref' ],
                            [
                                "Need a Schema Class passed to 'edit_reservation'",
                                "No 'Stock Management' object passed to 'edit_reservation'",
                                undef,
                                "No Params Hash Ref passed to 'edit_reservation'",
                            ],
                        );

        # check the 'reservation_upload' method on the StockManager Class
        note "testing 'stock_manager->reservation_upload' method";
        throws_ok { $stock_manager->reservation_upload; } qr/Argument hashref required/i,
                                        "No HashRef passed";
        my $args    = {
                    customer_nr     => 5043,
                    variant_id      => 2344,
                    pre_order_flag  => 0,
                };
        foreach my $param ( qw( customer_nr variant_id pre_order_flag ) ) {
            my $clone_args  = { %{ $args } };
            delete $clone_args->{ $param };
            throws_ok { $stock_manager->reservation_upload( $clone_args ); } qr/$param argument required/i,
                                            "Got No '$param' message when '$param' not in Args";
            $clone_args->{ $param }   = undef;
            throws_ok { $stock_manager->reservation_upload( $clone_args ); } qr/$param argument required/i,
                                            "Got No '$param' message when '$param' is in Args but undefined";
        }

        # check the 'reservation_cancel' method on the StockManager Class
        note "testing 'stock_manager->reservation_cancel' method";
        throws_ok { $stock_manager->reservation_cancel; } qr/Argument hashref required/i,
                                        "No HashRef passed";
        $args = {
            customer_nr     => 5043,
            variant_id      => 2344,
            pre_order_flag  => 0,
        };
        foreach my $param ( qw( customer_nr variant_id pre_order_flag ) ) {
            my $clone_args  = { %{ $args } };
            delete $clone_args->{ $param };
            throws_ok { $stock_manager->reservation_cancel( $clone_args ); } qr/$param argument required/i,
                                            "Got No '$param' message when '$param' not in Args";
            $clone_args->{ $param }   = undef;
            throws_ok { $stock_manager->reservation_cancel( $clone_args ); } qr/$param argument required/i,
                                            "Got No '$param' message when '$param' is in Args but undefined";
        }
    };
}

#--------------------------------------------------------------

# helper to check that a Reservation has been Cancelled
# and that others are still Pending
sub _check_reservation_statuses_ok {
    my ( $cancelled, $uploaded, $pending, $opts )   = @_;

    # check Cancelled
    if ( defined $cancelled ) {
        cmp_ok( $cancelled->discard_changes->status_id, '==', $RESERVATION_STATUS__CANCELLED,
                                    "Reservation: ".$cancelled->id." has been 'Cancelled'" );
        cmp_ok( $cancelled->ordering_id, '==', 0, "Ordering Id is ZERO" );
        my $log = $cancelled->reservation_logs->search( { reservation_status_id => $RESERVATION_STATUS__CANCELLED } )->first;
        if ( !$opts->{cancel_with_no_log} ) {
            ok( defined $log, "Reservation has Logged the Cancellation" );
        }
        else {
            ok( !defined $log, "Reservation has NOT Logged the Cancellation" );
        }
    }

    # check Uploaded
    if ( defined $uploaded ) {
        cmp_ok( $uploaded->discard_changes->status_id, '==', $RESERVATION_STATUS__UPLOADED,
                                    "Reservation: ".$uploaded->id. " has been 'Uploaded'" );
        my $log = $uploaded->reservation_logs->search( { reservation_status_id => $RESERVATION_STATUS__UPLOADED } )->first;
        ok( defined $log, "Reservation has Logged the Upload" );
        cmp_ok( $log->operator_id, '==', $uploaded->operator_id,
                                    "Operator on Log is the same as for the Reservation and NOT the 'Application' user" );
    }

    # check Pending
    if ( defined $pending ) {
        foreach my $res ( @{ $pending } ) {
            cmp_ok( $res->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "Reservation: ".$res->id." is still 'Pending'" );
        }
    }

    return;
}

# helper to create X number of reservations
sub _create_reservations {
    my ( $number, $channel, $variant )  = @_;

    my $schema  = $channel->result_source->schema;

    my @reservations;
    # get an Operator that isn't the 'Application' Operator
    my $operator    = $schema->resultset('Public::Operator')->search( {
        id => { '!=' => $APPLICATION_OPERATOR_ID },
        department_id => {'>', 0},
    } )->first;

    foreach my $counter ( 1..$number ) {
        my $data = Test::XT::Data->new_with_traits(
                        traits => [
                            'Test::XT::Data::ReservationSimple',
                        ],
                    );

        $data->operator( $operator );
        $data->channel( $channel );
        $data->variant( $variant );                             # make sure all reservations are for the same SKU

        my $reservation = $data->reservation;
        $reservation->update( { ordering_id => $counter } );    # prioritise each reservation

        # make sure the Customer has a different Email
        # Address than every other Reservation's Customer
        $reservation->customer->update( { email => $reservation->customer->is_customer_number . '.test@net-a-porter.com' } );
        note "Customer Id/Nr: ".$reservation->customer->id."/".$reservation->customer->is_customer_number;

        push @reservations, $reservation;
    }

    return @reservations;
}

# helper used to build up the Arguments for 'Cancel Reservation'
sub _build_cancel_args {
    my ( $res, $xtra )  = @_;

    my $args    = {
                status_id       => $res->status_id,
                variant_id      => $res->variant_id,
                customer_nr     => $res->customer->is_customer_number,
                reservation_id  => $res->id,
                operator_id     => $res->operator_id,
            };
    # add in Extra Arguments if Passed
    if ( $xtra ) {
        $args   = { %{ $args }, %{ $xtra } };
    }

    return $args;
}

# helper to build up the Argumnets for 'edit_reservation'
sub _build_edit_args {
    my ( $res, $xtra )  = @_;

    my $args    = {
                ordering        => $res->ordering_id,
                current_position=> $res->ordering_id,
                special_order_id=> $res->id,
                variant_id      => $res->variant_id,
                notes           => 'TEST NOTE',
                expireDay       => '00',
                expireMonth     => '00',
                expireYear      => '00',
                changeSize      => $res->variant_id,
                new_reservation_source_id => $res->reservation_source_id,
            };
    # add in Extra Arguments if Passed
    if ( $xtra ) {
        $args   = { %{ $args }, %{ $xtra } };
    }

    return $args;
}
