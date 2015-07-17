#!/usr/bin/env perl

use NAP::policy "tt",     'test';

# Originally done for:CANDO - 578


use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :shipment_status
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :shipment_hold_reason
                                        :ship_restriction
                                        :customer_category
                                    );
use Test::XTracker::Data;
use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 ) ], export => [ qw( $distribution_centre ) ];
use Test::XTracker::Data::Order;
use XTracker::Config::Local qw( config_var local_timezone);
use XTracker::Script::Shipment::CheckSLA;
use XT::Rules::Solve;
use Test::MockModule;

my $schema   = Test::XTracker::Data->get_schema;
my @channels = $schema->resultset('Public::Channel')->search({'is_enabled'=>1},{ order_by => { -desc => 'id' } })->all;

my $expected_charge_class  = {
    $SHIPPING_CHARGE_CLASS__SAME_DAY => { 'query_result' => 0 },
    $SHIPPING_CHARGE_CLASS__AIR => {'query_result' => 1 },
    $SHIPPING_CHARGE_CLASS__GROUND => { 'query_result' => 1 }
};

my $expected_shipping_hold_reason = {
    $SHIPMENT_HOLD_REASON__STOCK_DISCREPANCY => { 'query_result' => 1 },
    $SHIPMENT_HOLD_REASON__ACCEPTANCE_OF_CHARGES => {'query_result' => 1 },
    $SHIPMENT_HOLD_REASON__CHANGE_OF_ADDRESS => { 'query_result' => 1 },
    $SHIPMENT_HOLD_REASON__DAMAGED__FSLASH__FAULTY_GARMENT => { 'query_result' => 1 },
    $SHIPMENT_HOLD_REASON__UNABLE_TO_MAKE_CONTACT_TO_ORGANISE_A_DELIVERY_TIME => { 'query_result' => 1},
    $SHIPMENT_HOLD_REASON__OTHER => { 'query_result' => 1 },
    $SHIPMENT_HOLD_REASON__CUSTOMER_REQUEST => { 'query_result' => 0 },
    $SHIPMENT_HOLD_REASON__ACCEPTANCE_OF_CHARGES => { 'query_result' => 0 },
    $SHIPMENT_HOLD_REASON__CUSTOMER_ON_HOLIDAY => { 'query_result' => 0 },
    $SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS => { 'query_result' => 0 },
    $SHIPMENT_HOLD_REASON__ORDER_PLACED_ON_INCORRECT_WEBSITE => { 'query_result' => 0 },
    $SHIPMENT_HOLD_REASON__PREPAID_ORDER => { 'query_result' => 0 },
    $SHIPMENT_HOLD_REASON__UNABLE_TO_MAKE_CONTACT_TO_ORGANISE_A_DELIVERY_TIME => { 'query_result' => 0 },
    $SHIPMENT_HOLD_REASON__ACCEPTANCE_OF_CHARGES => { 'query_result' => 0 },
    $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS => { 'query_result' => 0 },
};

my $expected_shipping_item_status = {
    $SHIPMENT_ITEM_STATUS__NEW  => { 'query_result' => 1 },
    $SHIPMENT_ITEM_STATUS__SELECTED  => { 'query_result' => 1 },
    $SHIPMENT_ITEM_STATUS__PICKED  => { 'query_result' => 1 },
    $SHIPMENT_ITEM_STATUS__PACKED  => { 'query_result' => 0 },
    $SHIPMENT_ITEM_STATUS__DISPATCHED  => { 'query_result' => 0 },
    $SHIPMENT_ITEM_STATUS__RETURN_PENDING  => { 'query_result' => 0 },
    $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED  => { 'query_result' => 0 },
    $SHIPMENT_ITEM_STATUS__RETURNED  => { 'query_result' => 0 },
    $SHIPMENT_ITEM_STATUS__CANCEL_PENDING => { 'query_result' => 0 },
    $SHIPMENT_ITEM_STATUS__CANCELLED => { 'query_result' => 0 },
    $SHIPMENT_ITEM_STATUS__LOST  => { 'query_result' => 0 },
    $SHIPMENT_ITEM_STATUS__UNDELIVERED  => { 'query_result' => 0 },
    $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION  => { 'query_result' => 1 },
};

my $expected_shipment_status = {
    $SHIPMENT_STATUS__FINANCE_HOLD => { 'query_result' => 0 },
    $SHIPMENT_STATUS__PROCESSING => { 'query_result' => 1 },
    $SHIPMENT_STATUS__HOLD => { 'query_result' => 1 },
    $SHIPMENT_STATUS__DISPATCHED => { 'query_result' => 0 },
    $SHIPMENT_STATUS__CANCELLED => { 'query_result' => 0 },
    $SHIPMENT_STATUS__RETURN_HOLD => { 'query_result' => 0 },
    $SHIPMENT_STATUS__EXCHANGE_HOLD => { 'query_result' => 0 },
    $SHIPMENT_STATUS__LOST => { 'query_result' => 0 },
    $SHIPMENT_STATUS__DDU_HOLD => { 'query_result' => 0 },
    $SHIPMENT_STATUS__RECEIVED => { 'query_result' => 0 },
    $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD => { 'query_result' => 0 },
};


#######################
# Test query
_test_breached_sla_rs($schema, 1);
_test_upgrade_functionality($schema, 1);
_test_upgrade_conditions($schema, 1);
_test_no_air_upgrade_on_aerosols($schema);
_test_script($schema, 1);
_test_upgrade_when_product_has_restrictions( $schema, 1 );

done_testing;
#######################
sub _test_script {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip "test _test_script", 1 if (!$oktodo);

        note "******************** Testing _test_script";

        note " ************** Test for existence of script ";

        #check the housekeeping script exists
        my $script = config_var('SystemPaths', 'script_dir').'/housekeeping/shipment/checkSLA.pl';
        my $file_check = 0;
        if (-e $script) {
            $file_check = 1 ;
        }
        #check existence of script
        cmp_ok($file_check, '==', 1, "Script $script Exists");


        $schema->txn_do( sub{

            my $order    = _create_order();
            my $shipment = $order->shipments->first;
            my $channel  = $order->channel;
            $shipment  = update_shipping_charge_class($channel, $shipment);

            $shipment->update( { sla_cutoff => \q{current_timestamp - interval '1 day'} } );

            #check if the shippment before running script is Ground
            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");

            #run script
            _run_script($shipment);

            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__AIR, "Shipping charge class is : AIR");

            # rollback changes
            $schema->txn_rollback();
        });#end of txn_do

    }; #end of skip
}


sub _test_upgrade_conditions {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip "test _test_upgrade_conditions", 1 if (!$oktodo);

        note "******************** Testing _test_upgrade_conditions";

        $schema->txn_do( sub{

            my $correspondence_template = $schema->resultset('Public::CorrespondenceTemplate');

            my $order    = _create_order();
            my $shipment = $order->shipments->first;
            my $channel  = $order->channel;
            $shipment  = update_shipping_charge_class($channel, $shipment);
            $shipment->discard_changes();

            note "**********************Testing Shipment with condition - NOT breached_sla, NOT Premier, NOT Staff, Channel not JC";

            $shipment->update( { sla_cutoff => \q{current_timestamp + interval '5 day'} } );

            #check if the shippment before running script is Ground
            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");

            #run script
            _run_script($shipment);

            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");

            note "***************** Testing Shipment with conditions - breached_sla, NOT Premier, NOT Staff, Channel not JC";

            #update shipment to make it breach SLA
            $shipment->update( { sla_cutoff => \q{current_timestamp - interval '1 day'} } );
            #check shippment, before running script is Ground
            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");

             #run script
            _run_script($shipment);

            # check after running script shipment is upgraded from Ground to Express
            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__AIR, "Shipment was upgrade from Ground to Express");
            #check if shipment_notes is updated
            ok($shipment->shipment_notes->first->note =~ /Dispatch SLA Breach: Shipment breached SLA so it was upgraded to speedup the delivery as a complimentary gesture/, 'Shipment Notes are updated');
            my $t_id = get_template_id( $shipment, $correspondence_template );
            cmp_ok($shipment->shipment_email_logs->first->correspondence_templates_id, '==', $t_id, "shipment_email_log table was updated");


            note "***************** Testing Shipment with conditions - breached_sla, Premier, NOT Staff, Channel not JC";
            $order    = _create_order(undef, { shipment_type => $SHIPMENT_TYPE__PREMIER } );
            $shipment = $order->shipments->first;
            $channel  = $order->channel;
            $shipment  = update_shipping_charge_class($channel, $shipment);
            $shipment->discard_changes();

            cmp_ok($shipment->shipment_type->id, '==',$SHIPMENT_TYPE__PREMIER, "Shipment is Premier shipment");

            #run script
            _run_script($shipment);

            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipment charge class is: GROUND");

            note "*********************** Testing Shipment with conditions - breached_sla, NOT Premier, Staff, Channel not JC";
            $order    = _create_order(undef);
            $shipment = $order->shipments->first;
            $channel  = $order->channel;
            $shipment  = update_shipping_charge_class($channel, $shipment, $SHIPPING_CHARGE_CLASS__GROUND);
            $shipment->discard_changes();


            $order->customer->update({ category_id => $CUSTOMER_CATEGORY__STAFF } );
            #update shipment to make it breach SLA
            $shipment->update( { sla_cutoff => \q{current_timestamp - interval '1 day'} } );
            #check if the shippment before running script is Ground
            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");

            #run script
            _run_script($shipment);

            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");

            note "*********************** Testing Shipment with conditions - breached_sla, NOT Premier, NOT Staff, Channel IS JC";

            $order    = _create_order(undef);
            $shipment = $order->shipments->first;
            $channel  = $order->channel;
            $shipment  = update_shipping_charge_class($channel, $shipment, $SHIPPING_CHARGE_CLASS__GROUND);
            $shipment->discard_changes();
            #update channel to JC
            my $channel_id = get_channel_id('jc');
            $order->update( { channel_id => $channel_id });
            #update shipment to make it breach SLA
            $shipment->update( { sla_cutoff => \q{current_timestamp - interval '1 day'} } );

            #check if the shippment before running script is Ground
            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");

            #run script
            _run_script($shipment);

            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");

            # rollback changes
            $schema->txn_rollback();
        }); #end of txn_do
    };# end of skip

}

# this tests to make sure that when products have
# restrictions such as 'HAZMAT' then some Shipping
# Options aren't used
sub _test_upgrade_when_product_has_restrictions {
    my ( $schema, $oktodo ) = @_;

    SKIP: {
        skip "test _test_upgrade_conditions", 1 if (!$oktodo);

        note "******************** Testing _test_upgrade_when_product_has_restrictions";

        $schema->txn_do( sub{

            my $order    = _create_order();
            my $shipment = $order->shipments->first;
            my $channel  = $order->channel;
            $shipment  = update_shipping_charge_class($channel, $shipment);
            $shipment->discard_changes();

            my $charges = XT::Rules::Solve->solve( 'Configuration::ShipRestrictionsAllowedCharges' => {
                channel_id => $order->channel_id,
            } );
            my $allowed_lq_hazmat_charges = $charges->{ $SHIP_RESTRICTION__HZMT_LQ };

            note "*********************** Testing Shipment with Product Restrictions of 'HAZMAT LQ'";
            my %expects = (
                DC1 => {
                    # can only be upgraded to these Charges (keyed by Charge Id)
                    charges => $allowed_lq_hazmat_charges,
                },
                DC2 => {
                    # can be upgraded to any Air Charge
                    charge_class_id => $SHIPPING_CHARGE_CLASS__AIR,
                },
                DC3 => {
                    # can be upgraded to any Air Charge
                    charge_class_id => $SHIPPING_CHARGE_CLASS__AIR,
                },
            );
            my $expect  = $expects{ $distribution_centre };
            if ( !$expect ) {
                fail( "No Expectation set for HAZMAT LQ Restriction for DC: '${distribution_centre}'" );
            }

            #update shipment to make it breach SLA
            $shipment->update( { sla_cutoff => \q{current_timestamp - interval '1 day'} } );
            Test::XTracker::Data::Order->set_item_shipping_restrictions(
                $shipment,
                {
                    ship_restrictions => [
                        $SHIP_RESTRICTION__HZMT_LQ,
                    ],
                },
            );
            #check shippment, before running script is Ground
            cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");

            #run script
            _run_script($shipment);

            if ( exists( $expect->{charge_class_id} ) ) {
                cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $expect->{charge_class_id},
                                "Shipping Charge Class after Script has run as Expected" );
            }
            else {
                ok( exists( $expect->{charges}{ $shipment->shipping_charge_id } ),
                                "Shipping Charge after Script has run is one of the Allowed Charges" );
            }


            # rollback changes
            $schema->txn_rollback();
        }); #end of txn_do
    };
}

sub _test_upgrade_functionality {
    my ($schema, $oktodo ) = @_;

    SKIP: {
        skip "test _test_upgrade_functionality", 1 if (!$oktodo);

        note "************* Testing _test_upgrade_functionality";

        my $correspondence_template = $schema->resultset('Public::CorrespondenceTemplate');

        my $order    = _create_order(undef);
        my $shipment = $order->shipments->first;
        my $channel  = $order->channel;
        $shipment->update( { premier_routing_id => 0 } );

        $shipment  = update_shipping_charge_class($channel, $shipment);

        #Saving id for latter use
        my $ShipmentID = $shipment->id;
        #update shipment to make it breach SLA
        $shipment->update( { sla_cutoff => \q{current_timestamp - interval '1 day'} } );
        #check if the shippment before running script is Ground
        cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");


        note "************ Test Shipment with shipping charge class as ground - IN DRY RUN MODE, nothing should happen";
        # dryrun stuff here and nothing should be changed
        #redefined 'send_customer_email'
        no warnings "redefine";
        my $email_flag  = 0;
        my $email_to    = "";
        *XTracker::Script::Shipment::CheckSLA::send_customer_email = sub {
                                my $data = shift;
                                note "====== IN REDEFINED 'send_customer_email' FUNCTION ======";
                                $email_to   = $data->{to};
                                $email_flag = 1;
                                return 1;
        };
        use warnings "redefine";

        _run_script($shipment, { dryrun => 1 });
        cmp_ok( $email_flag, '==', 0, "When in Dry-Run Email Not Sent" );
        is( $email_to, "", "and Email To field is still empty" );
        cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");
        cmp_ok($shipment->shipment_notes->count, '==', 0, "Shipment notes - None Created" );
        cmp_ok($shipment->shipment_email_logs->count, '==', 0, "Shipment Email Log - Nothing Logged" );
        $email_flag = 0;
        $email_to   = "";
        cmp_ok( _change_log( 'count', $shipment ), '==', 0, "NO Change Logs have been Created" );


        note "************ Test Shipment with shipping charge class as ground";

        # what is expected in the Change Log
        my $change_log  = {
                shipment_id             => $shipment->id,
                old_shipping_charge_id  => $shipment->shipping_charge_id,
                old_shipping_account_id => $shipment->shipping_account_id,
                operator_id             => $APPLICATION_OPERATOR_ID,
            };

        # run script
        _run_script($shipment);

        # check after running script shipment is upgraded from Ground to Express
        cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__AIR, "Shipment was upgrade from Ground to Express");
        cmp_ok( $email_flag, '==', 1, "When NOT in Dry-Run Mode Email IS Sent" );
        is( $email_to, $shipment->email, "and Email To Address used is the Shipments: $email_to" );

        #check if shipment_notes is updated
        ok($shipment->shipment_notes->first->note =~ /Dispatch SLA Breach: Shipment breached SLA so it was upgraded to speedup the delivery as a complimentary gesture/, 'Shipment Notes are updated');

        my $t_id = get_template_id( $shipment, $correspondence_template );
        cmp_ok($shipment->shipment_email_logs->first->correspondence_templates_id, '==', $t_id, "shipment_email_log table was updated");

        # look at the 'shipment_shipping_charge_change_log' table
        cmp_ok( _change_log( 'count', $shipment ), '==', 1, "One Change Log has been Created" );
        my $log_dets    = _change_log( 'select', $shipment );
        delete $log_dets->{date};
        delete $log_dets->{id};
        $change_log->{new_shipping_charge_id}   = $shipment->shipping_charge_id;
        $change_log->{new_shipping_account_id}  = $shipment->shipping_account_id;
        is_deeply( $log_dets, $change_log, "Change Log as Expected" );


        note "************* Test - Above Shipment which is upgraded is not picked up by the script Again ";

        #check if we are using the above shipment
        cmp_ok($shipment->id, '==', $ShipmentID, "Shipment is same as above ");
        #run script
        _run_script($shipment);

        # make sure shipment did not get picket up the script
        cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__AIR, "Shipment was upgrade from Ground to Express");
        cmp_ok($shipment->shipment_notes->count, '==', 1, "Shipment notes - Shipment did not get picked up second time");
        cmp_ok($shipment->shipment_email_logs->count, '==', 1, "Shipment Email Log - Shipment did not get picked up second time");
        cmp_ok( _change_log( 'count', $shipment ), '==', 0, "NO Change Log has been Created" );


        note "*********** Test - Premier Shipment does not get picked up by script";
        $order    = _create_order(undef, { shipment_type => $SHIPMENT_TYPE__PREMIER } );
        $shipment = $order->shipments->first;
        $channel  = $order->channel;
        $shipment->update( { premier_routing_id => 0 } );

        #update shipment to make it breach SLA
        $shipment->update( { sla_cutoff => \q{current_timestamp - interval '1 day'} } );

        $shipment  = update_shipping_charge_class($channel, $shipment, $SHIPPING_CHARGE_CLASS__SAME_DAY);
        $shipment->discard_changes();

        cmp_ok($shipment->shipment_type->id, '==',$SHIPMENT_TYPE__PREMIER, "Shipment is Premier shipment");
        # check if shipment before running script is
        cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__SAME_DAY, "Shipment charge class is : SAME DAY");

        #run script
        _run_script($shipment);

        # make sure shipment did not get picked up the script
        cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__SAME_DAY, "Shipment charge class is : SAME DAY");
        cmp_ok($shipment->shipment_notes->count, '==', 0, "Shipment notes - Shipment did not get picked up second time");
        cmp_ok($shipment->shipment_email_logs->count, '==', 0, "Shipment Email Log - Shipment did not get picked up second time");
        cmp_ok( _change_log( 'count', $shipment ), '==', 0, "NO Change Log has been Created" );

    }; # END of skip

}

sub _test_breached_sla_rs {
    my ($schema, $oktodo) = @_;

    SKIP: {
        skip "test test_breached_sla_rs", 1 if (!$oktodo);

        note "*************** Testing _test_breached_sla_rs";

        my $checkSLA  = XTracker::Script::Shipment::CheckSLA->new();
        $checkSLA->schema($schema);

        $schema->txn_do( sub {

            foreach my $channel ( @channels ) {

                note "************ Creating Order for Channel: ".$channel->name." (".$channel->id.")";
                my $order = _create_order( $channel );
                my $shipment = $order->shipments->first;
                update_shipping_charge_class($channel, $shipment, undef, { force => 1 } );

                if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
                    diag "Shipping Acc.: ".$shipment->shipping_account_id;
                }

                my $result_hash = {};

                my @status = (
                            $SHIPMENT_STATUS__FINANCE_HOLD,
                            $SHIPMENT_STATUS__PROCESSING,
                            $SHIPMENT_STATUS__HOLD,
                            $SHIPMENT_STATUS__DISPATCHED,
                            $SHIPMENT_STATUS__CANCELLED,
                            $SHIPMENT_STATUS__RETURN_HOLD,
                            $SHIPMENT_STATUS__EXCHANGE_HOLD,
                            $SHIPMENT_STATUS__LOST,
                            $SHIPMENT_STATUS__DDU_HOLD,
                            $SHIPMENT_STATUS__RECEIVED,
                            $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD,
                    );

                foreach my $status ( @status ) {
                    #update shipment__status
                    $shipment->update({ shipment_status_id => $status });

                    my $delayedShipment_rs = $checkSLA->_build_breached_sla_rs();
                    my $result_rs = $delayedShipment_rs->search( {'me.id' =>  $shipment->id } );
                    $result_hash->{$status}->{'query_result'} = $result_rs->count;
                }

                #note "Testing  Shipment with different Status";
                is_deeply( $result_hash , $expected_shipment_status, "Query works correctly for Shipment having correct status" );

                #reset result_hash and shipment
                $result_hash = {};
                $shipment = reset_shipment($shipment);

                # Test for Shipment with different Shipping charge class;
                foreach my $class ($SHIPPING_CHARGE_CLASS__SAME_DAY, $SHIPPING_CHARGE_CLASS__AIR, $SHIPPING_CHARGE_CLASS__GROUND) {

                    $shipment  = update_shipping_charge_class($channel, $shipment, $class, { force => 1 } );
                    $shipment->discard_changes();

                    # test if the shipment is in query_rs
                    my $delayedShipment_rs = $checkSLA->_build_breached_sla_rs();
                    my $result_rs = $delayedShipment_rs->search( {'me.id' =>  $shipment->id } );

                    #build up the hash
                    $result_hash->{$class}->{'query_result'} = $result_rs->count;

                }
                #note "Testing  Shipment with different Shipping charge class";
                is_deeply( $result_hash , $expected_charge_class, "Query works correctly for shipment having right Charge Class" );

                #reset result_hash and shipment
                $result_hash = {};
                $shipment = reset_shipment($shipment);

                # Test to check shipment_hold_reason(s)
                #update shipment_hold
                my @hold_reasons = (
                                     $SHIPMENT_HOLD_REASON__STOCK_DISCREPANCY,
                                     $SHIPMENT_HOLD_REASON__ACCEPTANCE_OF_CHARGES,
                                     $SHIPMENT_HOLD_REASON__CHANGE_OF_ADDRESS,
                                     $SHIPMENT_HOLD_REASON__DAMAGED__FSLASH__FAULTY_GARMENT,
                                     $SHIPMENT_HOLD_REASON__UNABLE_TO_MAKE_CONTACT_TO_ORGANISE_A_DELIVERY_TIME,
                                     $SHIPMENT_HOLD_REASON__OTHER,
                                     $SHIPMENT_HOLD_REASON__CUSTOMER_REQUEST,
                                     $SHIPMENT_HOLD_REASON__ACCEPTANCE_OF_CHARGES,
                                     $SHIPMENT_HOLD_REASON__CUSTOMER_ON_HOLIDAY,
                                     $SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS,
                                     $SHIPMENT_HOLD_REASON__ORDER_PLACED_ON_INCORRECT_WEBSITE,
                                     $SHIPMENT_HOLD_REASON__PREPAID_ORDER,
                                     $SHIPMENT_HOLD_REASON__UNABLE_TO_MAKE_CONTACT_TO_ORGANISE_A_DELIVERY_TIME,
                                     $SHIPMENT_HOLD_REASON__ACCEPTANCE_OF_CHARGES,
                                     $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
                                  );

                foreach my $hold_reason ( @hold_reasons) {

                    #update hold reason of shipment
                    $shipment = insert_or_update_shipment_hold($shipment, $hold_reason);
                    $shipment->discard_changes;

                    #test if the shipment is in query_rs
                    my $delayedShipment_rs = $checkSLA->_build_breached_sla_rs();
                    my $result_rs = $delayedShipment_rs->search( {'me.id' =>  $shipment->id } );

                    $result_hash->{$hold_reason}->{'query_result'} = $result_rs->count;
                    delete_shipment_hold($shipment);
                }

                #note "Testing  Shipment with different Shipping Hold Reason";
                is_deeply( $result_hash , $expected_shipping_hold_reason, "Query works correctly for shipment having correct Shipping Hold Reasons" );


                #Test to check shipment_item status

                $result_hash = {};

                my @shipment_item_status = (
                                             $SHIPMENT_ITEM_STATUS__NEW,
                                             $SHIPMENT_ITEM_STATUS__SELECTED,
                                             $SHIPMENT_ITEM_STATUS__PICKED,
                                             $SHIPMENT_ITEM_STATUS__PACKED,
                                             $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                             $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                                             $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                                             $SHIPMENT_ITEM_STATUS__RETURNED,
                                             $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                                             $SHIPMENT_ITEM_STATUS__CANCELLED,
                                             $SHIPMENT_ITEM_STATUS__LOST,
                                             $SHIPMENT_ITEM_STATUS__UNDELIVERED,
                                             $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                         );

                foreach my $item_status ( @shipment_item_status ) {
                    #update shipment_item_status
                    $shipment->shipment_items->update({ shipment_item_status_id => $item_status });

                    my $delayedShipment_rs = $checkSLA->_build_breached_sla_rs();
                    my $result_rs = $delayedShipment_rs->search( {'me.id' =>  $shipment->id } );

                    $result_hash->{$item_status}->{'query_result'} = $result_rs->count;
                }

                #note "Testing  Shipment Item  with different Status";
                is_deeply( $result_hash , $expected_shipping_item_status, "Query works correctly for Shipment_Item having correct status" );

            }
            # rollback changes
            $schema->txn_rollback();
         });
    };

}

sub _test_no_air_upgrade_on_aerosols {
    my $schema = shift;
    note "*************** Testing _test_no_air_upgrade_on_aerosols";

    # order looks like aerosol
    my $mock_shipment = Test::MockModule->new('XTracker::Schema::Result::Public::Shipment');
    $mock_shipment->mock('has_aerosol_items', sub { return 1 });

    my $checkSLA  = XTracker::Script::Shipment::CheckSLA->new();
    $checkSLA->schema($schema);

    my $order = _create_order( undef );
    my $shipment = $order->shipments->first;
    my $channel  = $order->channel;
    $shipment  = update_shipping_charge_class($channel, $shipment, $SHIPPING_CHARGE_CLASS__GROUND);

    #update shipment to make it breach SLA
    $shipment->update( { sla_cutoff => \q{current_timestamp - interval '1 day'} } );
    #check shippment, before running script is Ground
    cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipping charge class is : GROUND");
    ok(!$shipment->is_carrier_automated(), 'Shipment is not carrier automated');

     #run script
    _run_script($shipment);

    # check after running script shipment is NOT upgraded from Ground to Express
    cmp_ok($shipment->shipping_charge_table->shipping_charge_class->id, '==', $SHIPPING_CHARGE_CLASS__GROUND, "Shipment was NOT upgraded");

    # ensure carrier automation still disabled
    $shipment->discard_changes;

    ok(!$shipment->is_carrier_automated(), 'Shipment is still not carrier automated');

}

sub _create_order {
    my $channel_rs = shift;
    my $args = shift;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
            how_many    => 1,
            channel     => $channel_rs || 'nap',
            ensure_stock_all_variants => 1,
    } );

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );
    my $base = {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        shipment_type => $args->{shipment_type} || $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
    };

    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        base => $base,
        pids => $pids,
        attrs => [
            { price => 100.00 }
        ],
    });

    if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
        diag "Order Nr:". $order->order_nr;
    }

    # update the Email addresses to be all different so
    # that the tests can identify which one is being used
    $customer->update( { email => 'customer.email@address.com' } );
    $order->update( { email => 'order.email@address.com' } );
    $order->get_standard_class_shipment->update( { email => 'shipment.email@address.com' } );

    Test::XTracker::Data::Order->clear_item_shipping_restrictions( $order->get_standard_class_shipment );

    return $order->discard_changes;
}

sub query_shipping_charge_table {
    my ( $channel, $charge_id, $force ) = @_;

    my $shipping_charge = $schema->resultset('Public::ShippingCharge');

    my $class_srch->{class_id}  = $charge_id;
    delete $class_srch->{class_id}      if ( $force );

    my $shipping_charge_rs =  $shipping_charge->search( {
                                          'description' => {'!=' => 'Unknown' },
                                          'channel_id' => $channel->id,
                                          %{ $class_srch },
                                      })->first;
    $shipping_charge_rs->update ({ class_id => $charge_id })    if ( $force );

    return $shipping_charge_rs;
}

sub insert_or_update_shipment_hold {
    my $shipment = shift;
    my $reason = shift;


    my $sh = $schema->resultset('Public::ShipmentHold')
                        ->update_or_create(
                          {
                            'shipment_id' => $shipment->id,
                            'shipment_hold_reason_id' => $reason,
                            'operator_id' => $APPLICATION_OPERATOR_ID,
                            'comment' => 'testing',
                            'hold_date' => 'now()'
                          },
                        );

    #also update shipment status to hold
    $shipment->update({ 'shipment_status_id' => $SHIPMENT_STATUS__HOLD } );

    return $shipment;

}

sub reset_shipment {
    my $shipment = shift;

    $shipment->update( { shipment_type_id   => $SHIPMENT_TYPE__DOMESTIC,
                         shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
                     });

    $shipment->shipment_items->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW });

    return $shipment;

}

sub delete_shipment_hold {
    my $shipment = shift;

    $schema->resultset('Public::ShipmentHold')->search({ 'shipment_id' => $shipment->id } )->delete;

    #update status back to processing
    $shipment->update({ 'shipment_status_id' => $SHIPMENT_STATUS__PROCESSING } );


}

sub update_shipping_charge_class {
    my $channel = shift;
    my $shipment = shift;
    my $charge_id = shift || $SHIPPING_CHARGE_CLASS__GROUND;
    my $args    = shift;

    my $shipping_charge_rs = query_shipping_charge_table( $channel, $charge_id, $args->{force} );

    # update shipment with this shipping_charge
    $shipment->update( { 'shipping_charge_id' => $shipping_charge_rs->id } );
    $shipment->discard_changes;

    return $shipment;
}

sub get_template_id {
    my $shipment = shift;
    my $correspondence_template = shift;

    my $b_name = $shipment->order->channel->business->config_section;
    my $template_name = "Dispatch-SLA-Breach-$b_name";

    my $template = $correspondence_template->find({ name => $template_name, department_id => undef });

    return $template->id;
}

sub get_channel_id {
    my $web_name = shift;

    my $channel_rs = $schema->resultset('Public::Channel')->search({
        web_name => { ilike => "%${web_name}%" }
    })->first;

    return $channel_rs->id ;
}
sub _run_script {
    my $shipment = shift->discard_changes;
    my $args = shift;

    # clear any change logs
    _change_log( 'delete', $shipment );

    my $checkSLA  = XTracker::Script::Shipment::CheckSLA->new();
    $checkSLA->schema($schema);
    my $delayedShipment_rs = $checkSLA->_build_breached_sla_rs();
    my $result_rs = $delayedShipment_rs->search( {'me.id' =>  $shipment->id } );

    $checkSLA->breached_sla_rs($result_rs);
    $checkSLA->invoke(%{$args});

    $shipment->discard_changes;
    cmp_ok( $shipment->premier_routing_id, '==', 0, "Shipment's Premier Routing Id is still ZERO" );

    return $checkSLA;
}

# helper to inspect the 'shipment_shipping_charge_change_log' table
sub _change_log {
    my ( $action, $shipment )   = @_;

    my $dbh = $schema->storage->dbh;

    my %actions = (
            count       => sub {
                    my $qry     = $dbh->prepare('SELECT COUNT(*) FROM shipment_shipping_charge_change_log WHERE shipment_id = ?');
                    $qry->execute( $shipment->id );
                    my ( $result )  = $qry->fetchrow_array();
                    return $result;
                },
            delete      => sub {
                    my $qry     = $dbh->prepare('DELETE FROM shipment_shipping_charge_change_log WHERE shipment_id = ?');
                    $qry->execute( $shipment->id );
                    return;
                },
            select      => sub {
                    my $qry     = $dbh->prepare('SELECT * FROM shipment_shipping_charge_change_log WHERE shipment_id = ?');
                    $qry->execute( $shipment->id );
                    return $qry->fetchrow_hashref('NAME_lc');
                },
        );

    return $actions{ $action }->();
}
