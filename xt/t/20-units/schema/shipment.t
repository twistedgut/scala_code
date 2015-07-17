#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Test 'Public::Shipment' Methods

This tests various methods on the 'Shipment' object:

* is_signature_required
* update_signature_required
* can_edit_signature_flag
* premier_mobile_number_for_SMS
* pre_order_create_cancellation_card_refund

Also tests that the 'XTracker::Database::Shipment' - 'get_shipment_info' & 'get_order_shipment_info' functions return the 'signature_required' & 'is_signature_required' fields and also test the 'create_shipment' function to make sure it creates shipments properly.

=cut

use DBIx::Class::RowRestore;
use Guard;


use Test::Exception;
use Test::MockModule;

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use XTracker::Config::Local             qw( config_var );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw(
                                            :shipment_class
                                            :shipment_status
                                            :shipment_item_status
                                            :shipment_type
                                            :stock_transfer_status
                                            :stock_transfer_type
                                            :renumeration_type
                                            :renumeration_class
                                            :renumeration_status
                                        );
use Data::Dump          qw( pp );


use_ok( 'XTracker::Database::Shipment', qw(
                                            get_shipment_info
                                            get_order_shipment_info
                                            create_shipment
                                    ) );
can_ok( 'XTracker::Database::Shipment', qw(
                                            get_shipment_info
                                            get_order_shipment_info
                                            create_shipment
                                    ) );


# get a schema to query
my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

$schema->txn_do( sub {
        my ($channel,$pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
        });
        my ($order) = Test::XTracker::Data->create_db_order({
            pids => $pids,
        });
        my $shipment = $order->shipments->first;

        #--------------------- Run Tests -----------------------------
        _check_required_params( $order );
        _test_create_shipment( $schema, $order, $pids, 1 );
        _test_signature_required( $schema, $order, $shipment, $pids, 1 );
        _test_get_shipment_info( $schema, $order, $pids );
        _test_mobile_number_for_premier( $schema, $order, $pids, 1 );
        _test_mobile_number_for_premier( $schema, $order, $pids, 1 );
        _test_pre_order_create_cancellation_card_refund( $schema, 1 );
        _test_can_have_in_the_box_promotions( $schema, $shipment );
        #-------------------------------------------------------------

        # rollback changes
        $schema->txn_rollback();
    } );

done_testing();

# test the 'signature_required' stuff
sub _test_signature_required {
    my ( $schema, $order, $shipment, $pids, $oktodo )  = @_;

    my $dbh     = $schema->storage->dbh;

    SKIP: {
        skip "_test_signature_required", 1      if ( !$oktodo );

        note "TESTING '_test_signature_required'";

        my $s_info;
        my $os_info;

        note "test 'is_signature_required' method and 'get_shipment_info' & 'get_order_shipment_info' functions";

        # check that the fields exist in 'get_shipment_info' & 'get_order_shipment_info' functions
        $s_info     = get_shipment_info( $dbh, $shipment->id );
        $os_info    = get_order_shipment_info( $dbh, $order->id )->{ $shipment->id };       # get the Shipment we want
        ok( exists( $s_info->{signature_required} ), "'get_shipment_info' has 'signature_required' field" );
        ok( exists( $s_info->{is_signature_required} ), "'get_shipment_info' has 'is_signature_required' field" );
        ok( exists( $os_info->{signature_required} ), "'get_order_shipment_info' has 'signature_required' field" );
        ok( exists( $os_info->{is_signature_required} ), "'get_order_shipment_info' has 'is_signature_required' field" );

        # test when field is TRUE
        $shipment->update( { signature_required => 1 } );
        $s_info     = get_shipment_info( $dbh, $shipment->id );
        $os_info    = get_order_shipment_info( $dbh, $order->id )->{ $shipment->id };
        ok( $shipment->is_signature_required, "'is_signature_required' returned TRUE when value is TRUE" );
        cmp_ok( $s_info->{is_signature_required}, '==', 1, "'get_shipment_info' - 'is_signature_required' returned TRUE when value is TRUE" );
        cmp_ok( $os_info->{is_signature_required}, '==', 1, "'get_order_shipment_info' - 'is_signature_required' returned TRUE when value is TRUE" );

        # test when field is FALSE
        $shipment->update( { signature_required => 0 } );
        $s_info     = get_shipment_info( $dbh, $shipment->id );
        $os_info    = get_order_shipment_info( $dbh, $order->id )->{ $shipment->id };
        ok( !$shipment->is_signature_required, "'is_signature_required' returned FALSE when value is FALSE" );
        cmp_ok( $s_info->{is_signature_required}, '==', 0, "'get_shipment_info' - 'is_signature_required' returned FALSE when value is FALSE" );
        cmp_ok( $os_info->{is_signature_required}, '==', 0, "'get_order_shipment_info' - 'is_signature_required' returned FALSE when value is FALSE" );

        # test when field is NULL
        $shipment->update( { signature_required => undef } );
        $s_info     = get_shipment_info( $dbh, $shipment->id );
        $os_info    = get_order_shipment_info( $dbh, $order->id )->{ $shipment->id };
        ok( $shipment->is_signature_required, "'is_signature_required' returned TRUE when value is NULL" );
        cmp_ok( $s_info->{is_signature_required}, '==', 1, "'get_shipment_info' - 'is_signature_required' returned TRUE when value is NULL" );
        cmp_ok( $os_info->{is_signature_required}, '==', 1, "'get_order_shipment_info' - 'is_signature_required' returned TRUE when value is NULL" );


        note "test 'update_signature_required' method";

        # get expected logs
        my $log_rs  = $shipment->log_shipment_signature_requireds->search( {}, { order_by => 'me.id DESC' } );

        # NOTE: from above the 'signature_required' field is UNDEF to start with
        cmp_ok( $shipment->update_signature_required( 1, $APPLICATION_OPERATOR_ID ), '==', 1, "method returns 1 to indicate it updated something" );
        ok( $shipment->is_signature_required, "update to TRUE and value is now TRUE" );
        cmp_ok( $log_rs->reset->count(), '==', 1, "One 'log_shipment_signature_required' record now created" );
        cmp_ok( $log_rs->first->new_state, '==', 1, "'log_shipment_signature_required' record's 'new_state' field is TRUE" );

        $shipment->update_signature_required( 0, $APPLICATION_OPERATOR_ID );
        ok( !$shipment->is_signature_required, "update to FALSE and value is now FALSE" );
        cmp_ok( $log_rs->reset->count(), '==', 2, "Two 'log_shipment_signature_required' records now created" );
        cmp_ok( $log_rs->first->new_state, '==', 0, "'log_shipment_signature_required' record's 'new_state' field is FALSE" );
        my $tmp = $log_rs->first->id;

        # now test updating with the same value and nothing should have been logged
        cmp_ok( $shipment->update_signature_required( 0, $APPLICATION_OPERATOR_ID ), '==', 0, "method returns 0 to indicate it updated nothing" );
        ok( !$shipment->is_signature_required, "update to FALSE again and value is STILL FALSE" );
        cmp_ok( $log_rs->reset->count(), '==', 2, "Still only Two 'log_shipment_signature_required' records created" );
        cmp_ok( $log_rs->first->id, '==', $tmp, "last 'log_shipment_signature_required' record created is the same as from previous test" );


        note "test 'can_edit_signature_flag' method";

        my $shipment_item   = $shipment->shipment_items->first;

        my %ship_statuses   = map { $_->id => $_ } ( $schema->resultset('Public::ShipmentStatus')->all );
        my %item_statuses   = map { $_->id => $_ } ( $schema->resultset('Public::ShipmentItemStatus')->all );

        my %tests   = (
                'Shipment Status'   => {
                        # set other data up correctly so the other tests will behave properly
                        init_data  => sub { $shipment_item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW } ); },
                        # what to update to test
                        update_field => sub { $shipment->update( { shipment_status_id => shift } ); },
                        can     => [
                                    map { delete $ship_statuses{ $_ } } ( $SHIPMENT_STATUS__FINANCE_HOLD,
                                                                          $SHIPMENT_STATUS__PROCESSING,
                                                                          $SHIPMENT_STATUS__HOLD,
                                                                          $SHIPMENT_STATUS__RETURN_HOLD,
                                                                          $SHIPMENT_STATUS__EXCHANGE_HOLD,
                                                                          $SHIPMENT_STATUS__DDU_HOLD, ),
                                ],
                        cant    => [ values %ship_statuses ],   # everything else
                    },
                'Shipment Item Status'  => {
                        # set other data up correctly so the other tests will behave properly
                        init_data  => sub { $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } ); },
                        # what to update to test
                        update_field => sub { $shipment_item->update( { shipment_item_status_id => shift } ); },
                        cant    => [
                                    map { delete $item_statuses{ $_ } } ( $SHIPMENT_ITEM_STATUS__PACKED, $SHIPMENT_ITEM_STATUS__DISPATCHED ),
                                ],
                        can     => [ values %item_statuses ],   # everything else
                    },
            );

        foreach my $test_label ( keys %tests ) {
            note "testing different '$test_label'";

            my $test    = $tests{ $test_label };
            my $update  = delete $test->{update_field};
            my $init    = delete $test->{init_data};
            my $can     = delete $test->{can};
            my $cant    = delete $test->{cant};

            $init->();

            # test what should work
            foreach my $status ( @{ $can } ) {
                $update->( $status->id );
                cmp_ok( $shipment->can_edit_signature_flag, '==', 1, "can - With Status: '".$status->status."' returns TRUE" );
            }

            # test what should not work
            foreach my $status ( @{ $cant } ) {
                $update->( $status->id );
                cmp_ok( $shipment->can_edit_signature_flag, '==', 0, "cant - With Status: '".$status->status."' returns FALSE" );
            }
        }
    };
}


# this tests the 'XTracker::Database::create_shipment' function,
# it needs an Order so that it can link to it when creating a shipment
sub _test_create_shipment {
    my ( $schema, $order, $pids, $oktodo )  = @_;

    my $dbh     = $schema->storage->dbh;

    SKIP: {
        skip "_test_create_shipment", 1     if ( !$oktodo );

        note "TESTING '_test_create_shipment'";

        my $ship_rs     = $schema->resultset('Public::Shipment');

        # get an existing shipment to nick stuff from
        my $shipment    = $order->discard_changes->get_standard_class_shipment;
        my $ship_addr   = $shipment->shipment_address;
        # update any existing addresses that match the
        # address hash except the one in $ship_addr
        $schema->resultset('Public::OrderAddress')
                ->search( { address_hash => $ship_addr->address_hash, id => { '!=' => $ship_addr->id } } )
                    ->update( { address_hash => 'DONTMATCH' } );

        # create a 'Stock Transfer' record pass in to the
        # function when creating a Sample Shipment
        my $stock_xfer  = $schema->resultset('Public::StockTransfer')->create( {
                                                                    date        => \'now()',
                                                                    type_id     => $STOCK_TRANSFER_TYPE__SAMPLE,
                                                                    status_id   => $STOCK_TRANSFER_STATUS__REQUESTED,
                                                                    variant_id  => $pids->[0]{variant_id},
                                                                    channel_id  => $order->channel_id,
                                                            } );

        # set-up args to create a shipment
        my %args    = (
                type_id             => $SHIPMENT_TYPE__PREMIER,
                class_id            => $SHIPMENT_CLASS__EXCHANGE,
                status_id           => $SHIPMENT_STATUS__HOLD,
                shipping_charge_id  => $schema->resultset('Public::ShippingCharge')->search->first->id,
                shipping_account_id => $schema->resultset('Public::ShippingAccount')->search->first->id,
                premier_routing_id  => $schema->resultset('Public::PremierRouting')->search->first->id,
                date                => $shipment->date,
                address => {
                        $ship_addr->get_columns
                    },
                gift                => 1,
                gift_message        => 'gift message',
                email               => 'email@address.com',
                telephone           => 'telephone',
                mobile_telephone    => 'mobile_telephone',
                pack_instruction    => 'pack instructions',
                shipping_charge     => '34.250',
                comment             => 'comment',
                gift_credit         => '12.500',
                store_credit        => '10.460',
                destination_code    => 'LHR',
                av_quality_rating   => '45.78',
                signature_required  => 1,
            );
        # get rid of extra info in the 'address'
        delete $args{address}{address_hash};
        delete $args{address}{id};

        # get what is expected and using the column names on the 'shipment' table
        my %expected_result = (
                    date                    => $args{date},
                    shipment_type_id        => $args{type_id},
                    shipment_class_id       => $args{class_id},
                    shipment_status_id      => $args{status_id},
                    shipment_address_id     => $ship_addr->id,
                    gift                    => $args{gift},
                    gift_message            => $args{gift_message},
                    outward_airway_bill     => 'none',
                    return_airway_bill      => 'none',
                    email                   => $args{email},
                    telephone               => $args{telephone},
                    mobile_telephone        => $args{mobile_telephone},
                    packing_instruction     => $args{pack_instruction},
                    shipping_charge         => $args{shipping_charge},
                    comment                 => $args{comment},
                    delivered               => 0,
                    gift_credit             => $args{gift_credit},
                    store_credit            => $args{store_credit},
                    legacy_shipment_nr      => '',
                    destination_code        => $args{destination_code},
                    shipping_charge_id      => $args{shipping_charge_id},
                    shipping_account_id     => $args{shipping_account_id},
                    premier_routing_id      => $args{premier_routing_id},
                    av_quality_rating       => $args{av_quality_rating},
                    signature_required      => $args{signature_required},
                );

        my $mock_shipment = Test::MockModule->new('XTracker::Schema::Result::Public::Shipment');
        $mock_shipment->mock('get_released_from_exchange_or_return_hold_datetime', sub {
            return DateTime->now();
        });

        # create the shipment
        note "create a shipment linked to an 'orders' record";
        my $ship_id = create_shipment( $dbh, $order->id, 'order', \%args );
        my $ship_rec= $ship_rs->find( $ship_id );
        ok( defined $ship_id, "Created a Shipment and Got a Shipment Id back" );
        isa_ok( $ship_rec, 'XTracker::Schema::Result::Public::Shipment', "Got a Shipment Record back using the Id" );
        my %result  = map { $_ => $ship_rec->$_ } keys %expected_result;
        is_deeply( \%result, \%expected_result, "Record has the Expected Data" );
        isa_ok( $ship_rec->order, 'XTracker::Schema::Result::Public::Orders', "Record is Linked to an Order record" );
        cmp_ok( $ship_rec->order->id, '==', $order->id, "and Order record Linked to is the one that was passed in" );
        ok( !defined $ship_rec->stock_transfer, "No Stock Transfer assigned to the Shipment" );
        # the following 2 fields not being NULL should indicate the 'apply_SLAs' method has been called
        ok( defined $ship_rec->sla_priority, "'sla_priority' field is not NULL" );
        ok( defined $ship_rec->sla_cutoff, "'sla_cutoff' field is not NULL" );

        # create a shipment
        note "create another shipment, using defaults";

        # change the address so it creates a new one
        delete $args{address_id};   # this is populate within the function
        $args{address}{first_name}  .= "test".$ship_addr->id;
        $args{address}{last_name}   .= "test".$ship_addr->id;
        delete $expected_result{shipment_address_id};   # don't know what to expect

        # test some defaults are used when values aren't passed in
        $expected_result{signature_required}    = 1; delete $args{signature_required};
        $expected_result{gift_credit}           = '0.000' ; delete $args{gift_credit};
        $expected_result{store_credit}          = '0.000' ; delete $args{store_credit};
        $expected_result{shipping_charge_id}    = 0; delete $args{shipping_charge_id};
        $expected_result{shipping_account_id}   = 0; delete $args{shipping_account_id};
        $expected_result{premier_routing_id}    = 0; delete $args{premier_routing_id};

        # create a shipment and get back the record for testing
        $ship_rec   = $ship_rs->find( create_shipment( $dbh, $order->id, 'order', \%args ) );
        %result     = map { $_ => $ship_rec->$_ } keys %expected_result;
        is_deeply( \%result, \%expected_result, "Record has the Expected Data" );
        cmp_ok( $ship_rec->shipment_address_id, '>', $ship_addr->id, "Shipment Address is a new Order Address record" );

        # create anothe shipment, with a couple of more differences
        note "create another shipment, with a couple of tweaks";

        delete $args{address};
        # use the shipment address id that was created previously
        $args{address_id}                       = $ship_rec->shipment_address_id;
        $expected_result{shipment_address_id}   = $ship_rec->shipment_address_id;
        $args{premier_routing_id}               = '';       # empty string for the premier routing id should default to zero
        $args{signature_required}               = 0;        # set signature required to be false
        $expected_result{signature_required}    = 0;

        # create a shipment and get back the record for testing
        $ship_rec   = $ship_rs->find( create_shipment( $dbh, $order->id, 'order', \%args ) );
        %result     = map { $_ => $ship_rec->$_ } keys %expected_result;
        is_deeply( \%result, \%expected_result, "Record has the Expected Data" );

        # create a shipment record for a Stock Transfer
        note "create a shipment linked to a 'stock_transfer' record";

        # pass in a NULL signature required which should be written as NULL to the record
        $args{signature_required}           = undef;
        $expected_result{signature_required}= undef;

        $ship_id    = create_shipment( $dbh, $stock_xfer->id, 'transfer', \%args );
        $ship_rec   = $ship_rs->find( $ship_id );
        ok( defined $ship_id, "Created a Shipment and Got a Shipment Id back" );
        isa_ok( $ship_rec, 'XTracker::Schema::Result::Public::Shipment', "Got a Shipment Record back using the Id" );
        %result     = map { $_ => $ship_rec->$_ } keys %expected_result;
        is_deeply( \%result, \%expected_result, "Record has the Expected Data" );
        isa_ok( $ship_rec->stock_transfer, 'XTracker::Schema::Result::Public::StockTransfer', "Record is Linked to a Stock Transfer record" );
        cmp_ok( $ship_rec->stock_transfer->id, '==', $stock_xfer->id, "and Stock Transfer record Linked to is the one that was passed in" );
        ok( !defined $ship_rec->order, "No Order assigned to the Shipment" );

        _exchange_shipment_on_exchange_hold(\%args, $ship_rs, $dbh, $order);
        _exchange_shipment_on_return_hold(\%args, $ship_rs, $dbh, $order);
    };

    return;
}


# check that no SLA in created for exchange shipment on exchange hold
sub _exchange_shipment_on_exchange_hold {
    my ($args, $ship_rs, $dbh, $order) = @_;

    # create exchange shipment which is on exchange hold to check that no SLA is created
    $args->{status_id} = $SHIPMENT_STATUS__EXCHANGE_HOLD;
    my $ship_rec   = $ship_rs->find( create_shipment( $dbh, $order->id, 'order', $args ) );
    ok( !$ship_rec->sla_priority, "'sla_priority' field is NULL for exchange shipment on exchange hold" );
    ok( !$ship_rec->sla_cutoff, "'sla_cutoff' field is NULL for exchange shipment on exchange hold" );
}


# check that no SLA in created for exchange shipment on return hold
sub _exchange_shipment_on_return_hold {
    my ($args, $ship_rs, $dbh, $order) = @_;

    # create exchange shipment which is on return hold to check that no SLA is created
    $args->{status_id} = $SHIPMENT_STATUS__RETURN_HOLD;
    my $ship_rec   = $ship_rs->find( create_shipment( $dbh, $order->id, 'order', $args ) );
    ok( !$ship_rec->sla_priority, "'sla_priority' field is NULL for exchange shipment on return hold" );
    ok( !$ship_rec->sla_cutoff, "'sla_cutoff' field is NULL for exchange shipment on return hold" );
}


# this tests the method 'premier_mobile_number_for_SMS' on the Shipment Class
# and that it returns the correct number with the correct country code prefix
sub _test_mobile_number_for_premier {
    my ( $schema, $order, $pids, $oktodo )  = @_;

    my $country_rs  = $schema->resultset('Public::Country');

    SKIP: {
        skip "_test_mobile_number_for_premier", 1     if ( !$oktodo );

        note "TESTING '_test_mobile_number_for_premier'";

        my $shipment    = $order->get_standard_class_shipment;

        my $dc_country_name = config_var( 'DistributionCentre', 'country' );
        my $dc_country      = $country_rs->search( { country => $dc_country_name } )->first;
        my $alt_country     = $country_rs->search( { country => { 'NOT IN' => [ 'Unknown', 'United Kingdom', $dc_country_name ] } } )->first;

        # fix their phone country codes
        $dc_country->update( { phone_prefix => '44' } );        # whatever the DC make it have UK's country prefix
        $alt_country->update( { phone_prefix => '345' } );

        # create two new addresses and assign them to the Order & Shipment
        my $inv_addr    = Test::XTracker::Data->order_address( { address => 'create', country => $alt_country->country } );
        my $shp_addr    = Test::XTracker::Data->order_address( { address => 'create', country => $dc_country->country } );
        $order->update( { invoice_address_id => $inv_addr->id } );
        $shipment->update( { shipment_address_id => $shp_addr->id } );

        # default the Phone Numbers
        $order->update( { telephone => '', mobile_telephone => '' } );
        $shipment->update( { telephone => '', mobile_telephone => '' } );

        note "using Invoice Country : ".$inv_addr->country;
        note "using Shipment Country: ".$shp_addr->country;

        # check 'get_phone_number' method that is a Role on
        # both the Shipment & Orders Schema Classes
        note "TEST: 'get_phone_number' method";
        my %tests   = (
                "Empty Tel, With Mobile"    => {
                    data    => {
                            telephone           => '',
                            mobile_telephone    => '0123456789',
                        },
                    args    => undef,
                    expected=> '0123456789',
                },
                "With Tel, Empty Mobile"    => {
                    data    => {
                            telephone           => '0123456789',
                            mobile_telephone    => '',
                        },
                    args    => undef,
                    expected=> '0123456789',
                },
                "Both Empty"    => {
                    data    => {
                            telephone           => '',
                            mobile_telephone    => '',
                        },
                    args    => undef,
                    expected=> '',
                },
                "Preserve Leading '+'"    => {
                    data    => {
                            telephone           => '+0123456789',
                            mobile_telephone    => '',
                        },
                    args    => undef,
                    expected=> '+0123456789',
                },
                "Non Numeric in Tel, Mobile is Fine"    => {
                    data    => {
                            telephone           => 'same as mobile',
                            mobile_telephone    => '0123456789',
                        },
                    args    => undef,
                    expected=> '0123456789',
                },
                "Choose Mobile First"    => {
                    data    => {
                            telephone           => '9876543210',
                            mobile_telephone    => '0123456789',
                        },
                    args    => { start_with => 'mobile' },
                    expected=> '0123456789',
                },
                "Choose Mobile First, but Empty so use Tel"    => {
                    data    => {
                            telephone           => '9876543210',
                            mobile_telephone    => '',
                        },
                    args    => { start_with => 'mobile' },
                    expected=> '9876543210',
                },
                "Choose Mobile First, non-numeric in Mobile so use Tel"    => {
                    data    => {
                            telephone           => '9876543210',
                            mobile_telephone    => 'same as above',
                        },
                    args    => { start_with => 'mobile' },
                    expected=> '9876543210',
                },
                "Take out non-numeric Characters"    => {
                    data    => {
                            telephone           => '(01206)-345,6787',
                            mobile_telephone    => '',
                        },
                    args    => undef,
                    expected=> '012063456787',
                },
                "Take out non-numeric Characters, including '+' that isn't leading"    => {
                    data    => {
                            telephone           => '(01206)-345-6787',
                            mobile_telephone    => '+(01206)+345+6787+',
                        },
                    args    => { start_with => 'mobile' },
                    expected=> '+012063456787',
                },
                "Number less than <= 3 is Ignored, also take off leading/trailing spaces" => {
                    data    => {
                            telephone           => '  (01206)-345+6787  ',
                            mobile_telephone    => 'ext 456',
                        },
                    args    => { start_with => 'mobile' },
                    expected=> '012063456787',
                },
                "Both less than <= 3 is Ignored, get an Empty String" => {
                    data    => {
                            telephone           => ' 678  ',
                            mobile_telephone    => 'ext 456',
                        },
                    args    => { start_with => 'mobile' },
                    expected=> '',
                },
            );

        foreach my $label ( keys %tests ) {
            my $test    = $tests{ $label };
            note "Testing: $label";

            # update both Shipment & Order
            $shipment->update( $test->{data } );
            $order->update( $test->{data} );

            # test for both Shipment & Order
            my $got = $shipment->get_phone_number( $test->{args} );
            ok( defined $got, "Shipment: 'get_phone_number' got a Defined Value" );
            is( $got, $test->{expected}, "Shipment: 'get_phone_number' returned as Expected" );
            $got    = $order->get_phone_number( $test->{args} );
            ok( defined $got, "Order: 'get_phone_number' got a Defined Value" );
            is( $got, $test->{expected}, "Order: 'get_phone_number' returned as Expected" );
        }


        # now test the 'premier_mobile_number_for_SMS' used to get the
        # correct Mobile Number with Country Code based on the rules in CANDO-576
        note "TEST: 'premier_mobile_number_for_SMS' method";

        # break the link between Shipment & Order and method should return an Empty String
        $order->link_orders__shipments->delete;
        $order->update( { telephone => '123456789', mobile_telephone => '123456789' } );
        $shipment->update( { telephone => '123456789', mobile_telephone => '123456789' } );
        my $str = $shipment->discard_changes->premier_mobile_number_for_SMS;
        ok( defined $str, "For a NON-Order Shipment, 'premier_mobile_number_for_SMS' returns a Defined Value" );
        is( $str, "", "For a NON-Order Shipment, 'premier_mobile_number_for_SMS' returns an Empty String" );

        # restore the link between the Order and the Shipment
        $order->create_related( 'link_orders__shipments', { shipment_id => $shipment->id } );
        $shipment->discard_changes;

        my $dc_pfx  = $dc_country->phone_prefix;
        my $alt_pfx = $alt_country->phone_prefix;
        %tests  = (
                "Invoice & Shipping Country Same, Phone Numbers Same, use Shipping"   => {
                    data    => {
                        inv_addr    => { country => $dc_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '07900123321' },
                        shipment    => { mobile_telephone => '07900123321' },
                    },
                    expected    => "+${dc_pfx}7900123321",
                },
                "Invoice & Shipping Country Same, Phone Numbers Diff, use Shipping"   => {
                    data    => {
                        inv_addr    => { country => $dc_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '07900321123' },
                        shipment    => { mobile_telephone => '07900123321' },
                    },
                    expected    => "+${dc_pfx}7900123321",
                },
                "Invoice & Shipping Country Diff, Phone Numbers Same, Use Ship Phone & Inv Country"   => {
                    data    => {
                        inv_addr    => { country => $alt_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '07900123321' },
                        shipment    => { mobile_telephone => '07900123321' },
                    },
                    expected    => "+${alt_pfx}7900123321",
                },
                "Invoice & Shipping Country Diff, Phone Numbers Diff, Use Inv Phone & Inv Country"   => {
                    data    => {
                        inv_addr    => { country => $alt_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '07900321123' },
                        shipment    => { mobile_telephone => '07900123321' },
                    },
                    expected    => "+${alt_pfx}7900321123",
                },
                "Invoice & Shipping Country Diff, Mobile Numbers Empty, Use 'telephone' Number"   => {
                    data    => {
                        inv_addr    => { country => $alt_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '' },
                        shipment    => { mobile_telephone => '' },
                    },
                    expected    => "+${alt_pfx}123456789",  # default used for Telephone Numbers in the Test
                },
                "Invoice & Shipping Country Diff, Phone Numbers Empty, Get Empty String"   => {
                    data    => {
                        inv_addr    => { country => $alt_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { telephone => '', mobile_telephone => '' },
                        shipment    => { telephone => '', mobile_telephone => '' },
                    },
                    expected    => '',
                },
                "Invoice & Shipping Country Same, Phone Numbers Diff & Ship Number has leading '+', Don't add a Prefix to Ship Number"   => {
                    data    => {
                        inv_addr    => { country => $dc_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '07900321123' },
                        shipment    => { mobile_telephone => '+447900123321' },
                    },
                    expected    => '+447900123321',
                },
                "Invoice & Shipping Country Diff, Phone Numbers Diff & Inv Phone has leading '+', Don't add a Prefix to Inv Number"   => {
                    data    => {
                        inv_addr    => { country => $alt_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '+447900321123' },
                        shipment    => { mobile_telephone => '07900123321' },
                    },
                    expected    => '+447900321123',
                },
                "Invoice & Shipping Country Diff, Phone Numbers Diff & Shp Phone has leading '+', Use Shp Number Anyway"   => {
                    data    => {
                        inv_addr    => { country => $alt_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '+447900321123' },
                        shipment    => { mobile_telephone => '+447900123321' },
                    },
                    expected    => '+447900123321',
                },
                "Invoice & Shipping Country Diff, Inv Mobile Empty, Shp Mobile Not Empty, Use Inv Country & Ship Mobile"   => {
                    data    => {
                        inv_addr    => { country => $alt_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { telephone => '', mobile_telephone => '' },
                        shipment    => { telephone => '', mobile_telephone => '07900123321' },
                    },
                    expected    => "+${alt_pfx}7900123321",
                },
                "Invoice & Shipping Country Same, Inv Mobile Not Empty, Shp Mobile Empty, Use Shp Country + Inv Mobile"   => {
                    data    => {
                        inv_addr    => { country => $dc_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { telephone => '', mobile_telephone => '07900123321' },
                        shipment    => { telephone => '', mobile_telephone => '' },
                    },
                    expected    => "+${dc_pfx}7900123321",
                },
                #
                # these tests check that when a UK prefix (+44) is used the number has to be a Mobile I.E. start with a '7'
                #
                "Invoice & Shipping Country Different, Shp Mobile has leading '+' but not a UK mobile, Should go on to use Inv Mobile"   => {
                    data    => {
                        inv_addr    => { country => $alt_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '01900123321' },
                        shipment    => { mobile_telephone => '+441900123321' },
                    },
                    expected    => "+${alt_pfx}1900123321",
                },
                "Invoice & Shipping Country Same, Shp Mobile not a UK mobile, Inv Mobile Ignored, Get an Empty String" => {
                    data    => {
                        inv_addr    => { country => $dc_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '07900123321' },
                        shipment    => { mobile_telephone => '01900123321' },
                    },
                    expected    => "",
                },
                "Invoice & Shipping Country Same, Shp Mobile Empty, Inv Mobile not a UK mobile, Get an Empty String" => {
                    data    => {
                        inv_addr    => { country => $dc_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '01900123321' },
                        shipment    => { mobile_telephone => '' },
                    },
                    expected    => "",
                },
                "Invoice & Shipping Country Different, Inv Mobile not a UK mobile, Shp Mobile Ignored, Get an Empty String" => {
                    data    => {
                        inv_addr    => { country => $dc_country->country },
                        shp_addr    => { country => $alt_country->country },
                        order       => { mobile_telephone => '01900123321' },
                        shipment    => { mobile_telephone => '07900123321' },
                    },
                    expected    => "",
                },
                "Invoice & Shipping Country Different, Inv Mobile Empty, Shp Mobile not a UK mobile, Get an Empty String" => {
                    data    => {
                        inv_addr    => { country => $dc_country->country },
                        shp_addr    => { country => $alt_country->country },
                        order       => { mobile_telephone => '' },
                        shipment    => { mobile_telephone => '01900123321' },
                    },
                    expected    => "",
                },
                "Invoice & Shipping Country Same (Not UK), Shp Mobile is any thing, Get Shp Mobile Back" => {
                    data    => {
                        inv_addr    => { country => $alt_country->country },
                        shp_addr    => { country => $alt_country->country },
                        order       => { mobile_telephone => '01900123321' },
                        shipment    => { mobile_telephone => '23448343443' },
                    },
                    expected    => "+${alt_pfx}23448343443",
                },
                "Invoice (Not UK) & Shipping Country Different, Inv Mobile is any thing, Get Inv Mobile Back" => {
                    data    => {
                        inv_addr    => { country => $alt_country->country },
                        shp_addr    => { country => $dc_country->country },
                        order       => { mobile_telephone => '23448343443' },
                        shipment    => { mobile_telephone => '01900123321' },
                    },
                    expected    => "+${alt_pfx}23448343443",
                },
            );

        foreach my $label ( keys %tests ) {
            my $test    = $tests{ $label };
            note "Testing: $label";

            # default the Phone Numbers, '123456789' should be ignored unless 'mobile_telephone' is empty
            $order->update( { telephone => '123456789', mobile_telephone => '' } );
            $shipment->update( { telephone => '123456789', mobile_telephone => '' } );

            # set-up the data
            my $data    = $test->{data};
            $inv_addr->update( $data->{inv_addr} )      if ( $data->{inv_addr} );
            $shp_addr->update( $data->{shp_addr} )      if ( $data->{shp_addr} );
            $order->update( $data->{order} )            if ( $data->{order} );
            $shipment->update( $data->{shipment} )      if ( $data->{shipment} );

            my $got = $shipment->discard_changes->premier_mobile_number_for_SMS;
            ok( defined $got, "'premier_mobile_number_for_SMS' returned a Defined Value" );
            is( $got, $test->{expected}, "'premier_mobile_number_for_SMS' returned as Expected" );
        }
    };

    return;
}

# this tests the 'pre_order_create_cancellation_card_refund'
# method on the Shipment Class
sub _test_pre_order_create_cancellation_card_refund {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_pre_order_create_cancellation_card_refund", 1       if ( !$oktodo );

        note "TESTING 'pre_order_create_cancellation_card_refund'";

        # so don't have to type the long Constant name
        my $op_id   = $APPLICATION_OPERATOR_ID;

        my $order   = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order();
        my $shipment= $order->get_standard_class_shipment;
        my @items   = $shipment->shipment_items->search( {}, { order_by => 'id' } )->all;
        my @item_ids= map { $_->id } @items;


        # test when an Order/Shipment is NOT in
        # the right state to create a refund
        note "Test 'pre_order_create_cancellation_card_refund' methid returns 'undef' when it should";

        # when NOT linked to an Order
        $shipment->link_orders__shipments->delete;
        ok( !defined $shipment->pre_order_create_cancellation_card_refund,
                                            "method returns 'undef' when Shipment NOT for an Order" );
        $shipment->create_related('link_orders__shipments', { orders_id => $order->id } );

        # with NO tender value or Debit Card used
        my $tender  = $order->card_debit_tender;
        my $tmp_value   = $tender->value;
        $tender->update( { value => 0 } );
        ok( !defined $shipment->pre_order_create_cancellation_card_refund,
                                            "method returns 'undef' when Shipment NOT for an Order" );
        $tender->update( { value => $tmp_value } );

        # when the Shipment is NOT in the correct Class
        my %shipment_classes        = map { $_->id => $_ } $schema->resultset('Public::ShipmentClass')->all;
        my @ship_class_allowed      = map { delete $shipment_classes{ $_ } } (
                                                                        $SHIPMENT_CLASS__STANDARD,
                                                                    );
        my @ship_class_notallowed   = values( %shipment_classes );

        note "testing Shipment Classes which should return 'undef'";
        foreach my $class ( @ship_class_notallowed ) {
            $shipment->update( { shipment_class_id => $class->id } );
            ok( !defined $shipment->pre_order_create_cancellation_card_refund,
                                                "method returns 'undef' when Shipment Class is: " . $class->class );
        }
        $shipment->update( { shipment_class_id => $ship_class_allowed[0]->id } );

        # when the Shipment Items are at a Status that isn't Cancelled
        my %ship_item_statuses          = map { $_->id => $_ } $schema->resultset('Public::ShipmentItemStatus')->all;
        my @ship_item_status_allowed    = map { delete $ship_item_statuses{ $_ } } (
                                                                        $SHIPMENT_ITEM_STATUS__CANCELLED,
                                                                        $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                                                                    );
        my @ship_item_status_notallowed = values( %ship_item_statuses );

        note "testing Shipment Item Statuses which should return 'undef'";
        foreach my $status ( @ship_item_status_notallowed ) {
            $shipment->shipment_items->update( { shipment_item_status_id => $status->id } );
            ok( !defined $shipment->pre_order_create_cancellation_card_refund( \@item_ids, $op_id ),
                                                "method returns 'undef' when Shipment Item Statuses are all: " . $status->status );
        }
        $shipment->shipment_items->update( { shipment_item_status_id => $ship_item_status_allowed[0]->id } );

        # make the amount to Refund greater than the Amount paid with in the first place
        $tender->update( { value => 20 } );
        ok( !defined $shipment->pre_order_create_cancellation_card_refund( \@item_ids, $op_id ),
                                            "method returns 'undef' when Total to Refund is greater than Amount paid with" );
        $tender->update( { value => $tmp_value } );

        # make the amount to Refund ZERO or less than ZERO
        $shipment->shipment_items->update( { unit_price => 0, tax => 0, duty => 0 } );
        ok( !defined $shipment->pre_order_create_cancellation_card_refund( \@item_ids, $op_id ),
                                            "method returns 'undef' when Total to Refund is ZERO" );
        $shipment->shipment_items->update( { unit_price => -100, tax => 0, duty => 0 } );
        ok( !defined $shipment->pre_order_create_cancellation_card_refund( \@item_ids, $op_id ),
                                            "method returns 'undef' when Total to Refund is less than ZERO" );


        # now get a new Order because the other one
        # has been played about with too much
        $order      = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order();
        $shipment   = $order->get_standard_class_shipment;
        @items      = $shipment->shipment_items->search( {}, { order_by => 'id' } )->all;
        @item_ids   = map { $_->id } @items;
        $tender     = $order->card_debit_tender;

        # do some tests where it should come back with a Refund Invoice
        my %tests   = (
                'Generate a Cancel Refund for One Shipment Item'   => {
                        items           => [ $items[1] ],
                        item_status_ids => [ $ship_item_status_allowed[0] ],  # using 'Cancel' Status
                        expected_totals => _work_out_refund_totals( $items[1] ),
                    },
                'Generate a Cancel Refund for All Shipment Items'   => {
                        items           => [ @items ],
                        item_status_ids => [ map { $ship_item_status_allowed[0] } @items ], # using 'Cancel' Status
                        expected_totals => _work_out_refund_totals( @items ),
                    },
                'Generate a Cancel Refund for Some Shipment Items'   => {
                        items           => [ @items[0,2] ],
                        item_status_ids => [ @ship_item_status_allowed[0,1] ],  # using both 'Cancel' & 'Cancel Pending' Status
                        expected_totals => _work_out_refund_totals( @items[0,2] ),
                    },
                'Generate a Cancel Refund for Some Shipment Items which have already had a Part Refund for them'    => {
                        items           => [ @items[0,2] ],
                        item_status_ids => [ @ship_item_status_allowed[0,1] ],  # using both 'Cancel' & 'Cancel Pending' Status
                        do_pre_test     => sub {
                                my ( $shipment_rec, $ship_items )   = @_;

                                my @clone_items = @{ $ship_items };
                                $shipment_rec->discard_changes;
                                my $ship_item   = shift @clone_items;       # use the first shipment item
                                $ship_item->discard_changes;

                                # create an Invoice for one of the items
                                my $invoice = $shipment_rec->create_related('renumerations', {
                                                                                invoice_nr              => '',
                                                                                renumeration_type_id    => $RENUMERATION_TYPE__CARD_REFUND,
                                                                                renumeration_class_id   => $RENUMERATION_CLASS__RETURN,
                                                                                renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
                                                                            } );
                                # create its Renumeration Item
                                my $inv_item    = $invoice->discard_changes->create_related('renumeration_items', {
                                                                shipment_item_id    => $ship_item->id,
                                                                unit_price          => $ship_item->unit_price / 2,
                                                                tax                 => $ship_item->tax / 2,
                                                                duty                => $ship_item->duty / 2,
                                                            } );
                                my @item_totals = (
                                        {
                                            shipment_item_id=> $inv_item->discard_changes->shipment_item_id,
                                            unit_price      => $inv_item->unit_price,
                                            tax             => $inv_item->tax,
                                            duty            => $inv_item->duty,
                                        },
                                    );

                                # get the rest of the item totals
                                foreach my $item ( @clone_items ) {
                                    push @item_totals, {
                                            shipment_item_id=> $item->discard_changes->id,
                                            unit_price      => $item->unit_price,
                                            tax             => $item->tax,
                                            duty            => $item->duty,
                                        };
                                }

                                my $grand_total = 0;
                                $grand_total    += ( $_->{unit_price} + $_->{tax} + $_->{duty} )     foreach ( @item_totals );
                                $grand_total    = _d2( $grand_total );

                                # return the Expected Totals
                                return {
                                        grand_total => $grand_total,
                                        item_totals => \@item_totals,
                                    };
                            },
                    },
            );

        foreach my $label ( keys %tests ) {
            note "Testing: $label";

            my $test    = $tests{ $label };
            _prepare_data_for_refund_test( $shipment );

            my $ship_items      = $test->{items};
            my $item_status_ids = $test->{item_status_ids};
            my $expected_totals = (
                                    $test->{do_pre_test}
                                    ? $test->{do_pre_test}->( $shipment, $ship_items )
                                    : $test->{expected_totals}
                                  );

            my $grand_total     = $expected_totals->{grand_total};

            my @ship_item_ids;
            foreach my $idx ( 0..$#{ $ship_items } ) {
                $ship_items->[ $idx ]->discard_changes
                                    ->update( { shipment_item_status_id => $item_status_ids->[ $idx ]->id } );
                push @ship_item_ids, $ship_items->[ $idx ]->id;
            }

            my $refund  = $shipment->discard_changes
                                    ->pre_order_create_cancellation_card_refund( \@ship_item_ids, $op_id );
            isa_ok( $refund, 'XTracker::Schema::Result::Public::Renumeration', "Returned a Refund" );
            cmp_ok( $refund->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_REFUND, "Type is 'Refund'" );
            cmp_ok( $refund->renumeration_class_id, '==', $RENUMERATION_CLASS__CANCELLATION, "Class is 'Cancellation'" );
            cmp_ok( $refund->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_ACTION, "Status is 'Awaiting Action'" );
            is( _d2( $refund->grand_total ), $grand_total, "Refund Total as Expected: $grand_total" );

            my @renum_items = $refund->renumeration_items->search( {}, { order_by => 'shipment_item_id' } )->all;
            cmp_ok( @renum_items, '==', @{ $ship_items }, "Number for Renumeration Items as Expected" );
            is_deeply( _work_out_refund_totals( @renum_items ), $expected_totals, "Renumeration Item Totals as Expected" );

            my $renum_tender    = $refund->renumeration_tenders->first;
            cmp_ok( $renum_tender->tender_id, '==', $tender->id, "Renumeration Tender for Refund uses the correct Payment Tender" );
            is( _d2( $renum_tender->value ), $grand_total, "Renumeration Tender Total is as Expected: $grand_total" );
        }
    };

    return;
}

#-----------------------------------------------------------------------

# run tests on methods to check required parameters are passed in
sub _check_required_params {
    my ( $order )   = @_;

    my $shipment    = $order->shipments->first;

    note "Checking for Required Parameters passed to Methods";

    note "method: update_signature_required";
    dies_ok( sub {
            $shipment->update_signature_required( undef, $APPLICATION_OPERATOR_ID );
        }, "pass undefined 'new_state' parameter and method dies" );
    dies_ok( sub {
            $shipment->update_signature_required( 1, undef );
        }, "pass undefined 'operator' parameter and method dies" );
    dies_ok( sub {
            $shipment->update_signature_required( 'Y', $APPLICATION_OPERATOR_ID );
        }, "pass incorrect 'new_state' parameter and method dies" );


    $order      = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order();
    $shipment   = $order->get_standard_class_shipment;

    note "method: pre_order_create_cancellation_card_refund";
    throws_ok {
            $shipment->pre_order_create_cancellation_card_refund( undef, $APPLICATION_OPERATOR_ID );
        } qr/No Array of Cancelled Shipment Ids/i, "pass NO Array of Shipment Ids and method dies";
    throws_ok {
            $shipment->pre_order_create_cancellation_card_refund( { a => 'b' }, $APPLICATION_OPERATOR_ID );
        } qr/No Array of Cancelled Shipment Ids/i, "pass Shipment Ids but NOT an Array and method dies";
    throws_ok {
            $shipment->pre_order_create_cancellation_card_refund( [ 1 ] );
        } qr/No Operator Id/i, "pass NO Operator Id and method dies";
    $order->link_orders__pre_orders->delete;
    throws_ok {
            $shipment->pre_order_create_cancellation_card_refund( [ 1 ], $APPLICATION_OPERATOR_ID );
        } qr/Shipment's Order is NOT linked to a Pre-Order/i,
                            "use a Shipment whose Order isn't linked to a Pre-Order and method dies";

    return;
}

# Add more stuff here as needed
sub _test_get_shipment_info {
    my ( $schema, $order, $pids, $oktodo )  = @_;
    note "TESTING '_test_get_shipment_info'";

    my $dbh = $schema->storage->dbh;
    my $shipment = $order->shipments->first;

    my $delivery_date = DateTime->new(year => 2011, month => 11, day => 11);
    my $delivery_date_string = $delivery_date->ymd;

    my $shipping_charge = $schema->resultset('Public::ShippingCharge')->search->first;
    my $test_cases = [
        {
            description => "nominated_delivery_date is undef",
            setup       => {
                attribute => "nominated_delivery_date",
                value     => undef,
            },
            expected    => {
                column => "nominated_delivery_date",
                value  => undef,
            },
        },
        {
            description => "nominated_delivery_date is a date",
            setup       => {
                attribute => "nominated_delivery_date",
                value     => $delivery_date_string,
            },
            expected    => {
                column => "nominated_delivery_date",
                value  => $delivery_date,
            },
        },
        {
            description => "shipping_charge_id gets correct sku",
            setup       => {
                attribute => "shipping_charge_id",
                value     => $shipping_charge->id,
            },
            expected    => {
                column => "shipping_charge_sku",
                value  => $shipping_charge->sku,
            },
        },
    ];
    for my $case (@$test_cases) {
        note "* $case->{description}";
        my $setup = $case->{setup};
        my $expected = $case->{expected};

        my $row_restore = DBIx::Class::RowRestore->new();
        my $row_guard = guard { $row_restore->restore_rows };
        $row_restore->add_to_update(
            $shipment => { $setup->{attribute} => $setup->{value} },
        );

        my $shipment_info = get_shipment_info( $dbh, $shipment->id );

        is(
            possible_datetime_to_ymd( $shipment_info->{ $expected->{column} } ),
            possible_datetime_to_ymd( $expected->{value} ),
            "$expected->{column} ok",
        );
    }
}

sub possible_datetime_to_ymd {
    my ($datetime) = @_;
    ref($datetime) or return $datetime;
    $datetime->isa("DateTime") or return $datetime;
    $datetime or return undef;
    return $datetime->ymd;
}

# prepares data for doing the Refund tests:
#   removes any 'renumeration' records from the Shipment
#   updates the item status to be 'New'
sub _prepare_data_for_refund_test {
    my ( $shipment )    = @_;

    $shipment->discard_changes;

    $shipment->renumerations->search_related('renumeration_items')->delete;
    $shipment->renumerations->search_related('renumeration_status_logs')->delete;
    $shipment->renumerations->search_related('renumeration_tenders')->delete;
    $shipment->renumerations->delete;
    $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW } );

    return;
}

# return the refund totals for Refund tests:
#   the Grand Total
#   total for each Item
sub _work_out_refund_totals {
    my @items   = @_;

    my $retval  = {
            grand_total     => 0,
        };

    foreach my $item ( @items ) {
        my $total_for_item  = {
                shipment_item_id    => ( ref( $item ) =~ m/ShipmentItem/ ? $item->id : $item->shipment_item_id ),
                unit_price          => $item->unit_price,
                tax                 => $item->tax,
                duty                => $item->duty,
            };
        push @{ $retval->{item_totals} }, $total_for_item;
        $retval->{grand_total}  += $item->unit_price +
                                   $item->tax +
                                   $item->duty;
    }
    $retval->{grand_total}  = _d2( $retval->{grand_total} );

    return $retval;
}

# make sure something is to 2 decimal places
sub _d2 {
    return sprintf( "%0.2f", shift );
}

sub _test_can_have_in_the_box_promotions {
    my ( $schema, $shipment ) = @_;

    note '_test_can_have_in_the_box_promotions';

    my @valid_classes = (
        $SHIPMENT_CLASS__STANDARD,
        $SHIPMENT_CLASS__RE_DASH_SHIPMENT,
        $SHIPMENT_CLASS__REPLACEMENT,
    );

    my $shipment_classes = $schema->resultset('Public::ShipmentClass');

    while ( my $shipment_class = $shipment_classes->next ) {

        $shipment->update( {
            shipment_class_id => $shipment_class->id,
        } );

        my $pass = scalar grep
            { $shipment_class->id == $_ }
            @valid_classes;

        cmp_ok(
            $shipment->can_have_in_the_box_promotions,
            '==',
            $pass,
            'can_have_in_the_box_promotions returns ' . ( $pass ? 'True' : 'False' ) . ' for ' . $shipment_class->class
        );

    }

}
