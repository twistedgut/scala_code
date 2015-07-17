#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;
use Test::XTracker::ParamCheck;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw( :channel );
use XTracker::Database 'xtracker_schema';
use Test::XTracker::RunCondition dc => 'DC2';
use Test::XTracker::Carrier;

use Data::Dump  qw( pp );

BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Database::Shipment', qw( :carrier_automation get_shipment_info get_order_shipment_info get_shipment_boxes ));
    use_ok('XTracker::Database::Logging', qw( :carrier_automation ));
    use_ok('NAP::Carrier');

    can_ok("XTracker::Database::Shipment",qw(
                            set_carrier_automated
                            is_carrier_automated
                            set_shipment_qrt
                            get_shipment_qrt
                            get_shipment_info
                            get_order_shipment_info
                            autoable
                            process_shipment_for_carrier_automation
                            get_shipment_boxes
                        ) );
    can_ok("XTracker::Database::Logging",qw(
                            log_shipment_rtcb
                            get_log_shipment_rtcb
                        ) );
}

my $schema = xtracker_schema;
my $dbh = $schema->storage->dbh;

#---- Create UPS Shipment -------------------------------------

my $carrier_test = Test::XTracker::Carrier->new;
my $ups_shipment = $carrier_test->ups_shipment;

#---- Test Functions ------------------------------------------

# The original test was rolling back the changes this test made. It's generally
# bad practice to do that, and I don't know whether this test genuinely needs
# to roll back its changes or not, so keeping its behaviour by using txn_dont.
subtest 'test required parameters' => sub {
    $schema->txn_dont(sub{ _test_reqd_params($dbh,$schema,1); });
};
subtest 'test rtcb field and logging' => sub {
    $schema->txn_dont(sub{ _test_automated($dbh,$schema,1); });
};
subtest 'test av_quality_rating field and logging' => sub {
    $schema->txn_dont(sub{ _test_qrt($dbh,1); });
};
subtest 'test shipment queries' => sub { _test_shipment_queries($dbh,1); };

#--------------------------------------------------------------


done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# Test that the functions are checking for required parameters
sub _test_reqd_params {
    my $dbh     = shift;
    my $schema  = shift;
    my $cursors = _define_dbh_cursors($dbh);

    my $ship_id = $cursors->{max_id}();
    my $inv_id  = $cursors->{inv_ship_id}();
    my $param_check = Test::XTracker::ParamCheck->new();

    SKIP: {
        skip "_test_reqd_params",1           if (!shift);

        note "Testing for Required Parameters, Ship Id: $ship_id";

        $param_check->check_for_params(  \&set_carrier_automated,
                            'set_carrier_automated',
                            [ $dbh, $ship_id , 0 ],
                            [ "No Database Handle", "No Shipment Id", "No State to Set" ],
                            [ undef, $inv_id ],
                            [ undef, "No Shipment found for Shipment Id" ]
                        );
        $param_check->check_for_params(  \&is_carrier_automated,
                            'is_carrier_automated',
                            [ $dbh, $ship_id ],
                            [ "No Database Handle", "No Shipment Id" ]
                        );
        $param_check->check_for_params(  \&set_shipment_qrt,
                            'set_shipment_qrt',
                            [ $dbh, $ship_id, undef ],
                            [ "No Database Handle", "No Shipment Id" ],
                            [ undef, $inv_id ],
                            [ undef, "No Shipment found for Shipment Id" ]
                        );
        $param_check->check_for_params(  \&get_shipment_qrt,
                            'get_shipment_qrt',
                            [ $dbh, $ship_id ],
                            [ "No Database Handle", "No Shipment Id" ]
                        );
        $param_check->check_for_params(  \&log_shipment_rtcb,
                            'log_shipment_rtcb',
                            [ $dbh, $ship_id , 0, $APPLICATION_OPERATOR_ID, "REASON GOES HERE" ],
                            [ "No Database Handle", "No Shipment Id", "No New State was Given", "No Operator Id", "No Reason Given" ],
                            [ undef, $inv_id ],
                            [ undef, "No Shipment found for Shipment Id" ]
                        );
        $param_check->check_for_params(  \&get_shipment_qrt,
                            'get_shipment_qrt',
                            [ $dbh, $ship_id ],
                            [ "No Database Handle", "No Shipment Id" ]
                        );
        $param_check->check_for_params( \&autoable,
                            'autoable',
                            [ $schema, { shipment_id => $ship_id } ],
                            [ "No Schema Handle", "No Arguments Passed" ]
                        );
        $param_check->check_for_hash_params( \&autoable,
                                'autoable',
                                [ $schema, { shipment_id => $ship_id, mode => 'isit', operator_id => $APPLICATION_OPERATOR_ID } ],
                                [ "No Schema Handle", { shipment_id => "No Shipment Id Passed", mode => "No Mode Specified", operator_id => "No Operator Id Passed" } ],
                                [ undef, { shipment_id => $inv_id, mode => 'fred' } ],
                                [ undef, { shipment_id => "No Shipment found for Shipment Id", mode => "Inproper Mode Specified" } ]
                            );
        $param_check->check_for_params( \&process_shipment_for_carrier_automation,
                                'process_shipment_for_carrier_automation',
                                [ $schema, $ship_id, $APPLICATION_OPERATOR_ID ],
                                [ 'No Schema Handle', 'No Shipment Id', 'No Operator Id' ],
                                [ undef, -34, undef ],
                                [ undef, 'No Shipment found for Shipment Id: -34' ]
                            );
    }
}

# This tests that the setting of the 'rtcb' field is working
# and being logged properly
sub _test_automated {

    my $dbh     = shift;
    my $schema  = shift;

    my $cursors     = _define_dbh_cursors($dbh);
    my $resultset   = _define_dbic_resultset($schema);

    my $ship_id = $cursors->{max_id}();
    my $tmp;
    my $log_id;
    my ( $out_awb, $ret_awb ) = Test::XTracker::Data->generate_air_waybills;
    my $shipment= $schema->resultset('Public::Shipment')->find( $ship_id );


    note "Testing Shipment Automated Functionality, Ship Id: $ship_id";

    # set 'rtcb' to FALSE first
    set_carrier_automated( $dbh, $ship_id, 0 );

    # set-up shipment items ready for the test
    $cursors->{null_shipment_items_gifts}($ship_id);

    # set Carrier Automation for the Shipment's Channel to 'On'
    $resultset->{upd_AutoState}( $shipment, 'On' );

    set_carrier_automated( $dbh, $ship_id, 1 );
    $tmp    = is_carrier_automated( $dbh, $ship_id );
    cmp_ok($tmp,"==",1,"Shipment SET to be Automated");
    $tmp    = $resultset->{is_Automated}($ship_id);
    cmp_ok($tmp,"==",1,"Shipment SET to be Automated (Schema Method)");

    # set shipment AWBs to something so that they can be reset
    $resultset->{upd_AWBs}( $shipment, $out_awb, $ret_awb );
    isnt( $shipment->outward_airway_bill, 'none', "Shipment Outward AWB is not 'none' (".$shipment->outward_airway_bill.")" );
    isnt( $shipment->return_airway_bill, 'none', "Shipment Return AWB is not 'none' (".$shipment->return_airway_bill.")" );

    set_carrier_automated( $dbh, $ship_id, 0 );
    $tmp    = is_carrier_automated( $dbh, $ship_id );
    cmp_ok($tmp,"==",0,"Shipment NOT SET to be Automated");
    $tmp    = $resultset->{is_Automated}($ship_id);
    cmp_ok($tmp,"==",0,"Shipment NOT SET to be Automated (Schema Method)");
    # check shipment AWBs have been reset back to 'none'
    $shipment->discard_changes;
    is( $shipment->outward_airway_bill, 'none', "Shipment Outward AWB has been reset to 'none' (".$shipment->outward_airway_bill.")" );
    is( $shipment->return_airway_bill, 'none', "Shipment Return AWB has been reset to 'none' (".$shipment->return_airway_bill.")" );

    # Set up fields for log table to insert and check
    my @log_fields  = qw( shipment_id new_state operator_id reason_for_change );
    my @log_values  = (
            [ $ship_id, 1, $APPLICATION_OPERATOR_ID, "BECAUSE I FELT LIKE IT" ],
            [ $ship_id, 0, $APPLICATION_OPERATOR_ID, "BECAUSE I SAID SO" ]
        );

    log_shipment_rtcb( $dbh, @{ $log_values[0] } );
    log_shipment_rtcb( $dbh, @{ $log_values[1] } );
    $tmp    = get_log_shipment_rtcb( $dbh, $ship_id );
    foreach ( 0..$#log_fields ) {
        is($tmp->[0]{ $log_fields[$_] },$log_values[1][$_],"Log 'rtcb' field Pass 1, Checking Log Field: ".$log_fields[$_]);
    }
    foreach ( 0..$#log_fields ) {
        is($tmp->[1]{ $log_fields[$_] },$log_values[0][$_],"Log 'rtcb' field Pass 2, Checking Log Field: ".$log_fields[$_]);
    }

    $tmp    = NAP::Carrier->new( { schema => $schema, shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    isa_ok($tmp,"NAP::Carrier","Created new NAP::Carrier object");

    # set Shipment to not be Automated just to be sure
    set_carrier_automated( $dbh, $ship_id, 0 );

    $cursors->{make_premier}($ship_id);
    $tmp    = autoable( $schema, { mode => 'isit', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",0,"Premier Shipment Shouldn't be Autoable");

    $cursors->{make_domestic}($ship_id);

    $cursors->{make_gift_shipment}($ship_id);
    $tmp    = autoable( $schema, { mode => 'isit', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok( $tmp, "==", 1, "Gift Shipment Shouldn't be Autoable");

    $cursors->{make_nongift_shipment}($ship_id);
    $tmp    = autoable( $schema, { mode => 'isit', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",1,"Non Gift Shipment Should be Autoable");

    $cursors->{make_shipment_items_gifts}($ship_id);
    $tmp    = autoable( $schema, { mode => 'isit', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",1,"Shipment Items WITH Gift Messages Should NOT be Autoable");

    $cursors->{empty_shipment_items_gifts}($ship_id);
    $tmp    = autoable( $schema, { mode => 'isit', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",1,"Shipment Items with EMPTY Gift Messages Should be Autoable");

    $cursors->{null_shipment_items_gifts}($ship_id);        # check NULL and empty do the same thing
    $tmp    = autoable( $schema, { mode => 'isit', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",1,"Shipment Items with NULL Gift Messages Should be Autoable");


    $tmp    = autoable( $schema, { mode => 'deduce', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",1,"Shipment Should Have Been Set to be Autoable & Logged");

    $tmp    = is_carrier_automated( $dbh, $ship_id );
    cmp_ok($tmp,"==",1,"Shipment Has Been Set to be Autoable");
    $tmp    = get_log_shipment_rtcb( $dbh, $ship_id );
    cmp_ok($tmp->[0]{shipment_id},"==",$ship_id,"Autoable Logged the Correct Shipment Id");
    cmp_ok($tmp->[0]{operator_id},"==",$APPLICATION_OPERATOR_ID,"Autoable Logged the Correct Operator Id");
    cmp_ok($tmp->[0]{new_state},"==",1,"Autoable Logged the Correct State");
    is($tmp->[0]{reason_for_change},"AUTO: Changed After 'is_autoable' TEST","Autoable Logged the Correct Reason");

    # Store log id for later use
    $log_id  = $tmp->[0]{id};

    $tmp    = autoable( $schema, { mode => 'deduce', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",1,"Shipment Is Still Autoable & Shouldn't Have Been Logged");
    $tmp    = get_log_shipment_rtcb( $dbh, $ship_id );
    cmp_ok($tmp->[0]{id},"==",$log_id,"Autoable Did NOT Log the Non Change");

    # set Carrier Automation for the Shipment's Channel to 'Off'
    $resultset->{upd_AutoState}( $shipment, 'Off' );
    $tmp    = autoable( $schema, { mode => 'deduce', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",0,"Shipment Should Have Been set to NOT Autoable & Should Have Been Logged due to the State being set to Off");
    $tmp    = get_log_shipment_rtcb( $dbh, $ship_id );
    cmp_ok($tmp->[0]{id},"!=",$log_id,"Autoable Did Log the Change due to the State being set to Off");
    is($tmp->[0]{reason_for_change},"STATE: Carrier Automation State is 'Off'","Autoable Logged the Correct Reason when State is Off");
    $log_id = $tmp->[0]{id};
    # make a second call with the state set to Off and a new log entry should be made
    $tmp    = autoable( $schema, { mode => 'deduce', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",0,"Shipment Should Still be set to NOT Autoable & Should Have Been Logged due to the State being set to Off");
    $tmp    = get_log_shipment_rtcb( $dbh, $ship_id );
    cmp_ok($tmp->[0]{id},"!=",$log_id,"Autoable Did Log a new Log for the Change due to the State being set to Off");
    is($tmp->[0]{reason_for_change},"STATE: Carrier Automation State is 'Off'","Autoable Still Logged the Correct Reason when State is Off");

    # set Carrier Automation for the Shipment's Channel to 'Import_Off_Only'
    $resultset->{upd_AutoState}( $shipment, 'Import_Off_Only' );
    $tmp    = autoable( $schema, { mode => 'deduce', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",1,"Shipment Should Have Been Set to Autoable & Should Have Been Logged due to the State being set to Import Off Only");
    $tmp    = get_log_shipment_rtcb( $dbh, $ship_id );
    cmp_ok($tmp->[0]{id},"!=",$log_id,"Autoable Did Log the Change due to the State being set to Import Off Only");
    is($tmp->[0]{reason_for_change},"AUTO: Changed After 'is_autoable' TEST","Autoable Logged the Correct Reason when State is Import Off Only");
    # Store log id for later use
    $log_id  = $tmp->[0]{id};

    $cursors->{make_premier}($ship_id);
    $tmp    = autoable( $schema, { mode => 'deduce', shipment_id => $ship_id, operator_id => $APPLICATION_OPERATOR_ID } );
    cmp_ok($tmp,"==",0,"Shipment Should Have Been Set to NOT Autoable & Logged Change");

    $tmp    = is_carrier_automated( $dbh, $ship_id );
    cmp_ok($tmp,"==",0,"Shipment Has Been Set to be NOT Autoable");
    $tmp    = get_log_shipment_rtcb( $dbh, $ship_id );
    cmp_ok($tmp->[0]{id},"!=",$log_id,"Autoable Did Log Change");
    cmp_ok($tmp->[0]{shipment_id},"==",$ship_id,"Autoable Logged the Correct Shipment Id");
    cmp_ok($tmp->[0]{operator_id},"==",$APPLICATION_OPERATOR_ID,"Autoable Logged the Correct Operator Id");
    cmp_ok($tmp->[0]{new_state},"==",0,"Autoable Logged the Correct State");
    is($tmp->[0]{reason_for_change},"AUTO: Changed After 'is_autoable' TEST","Autoable Logged the Correct Reason");
}

# this tests the setting and logging of the 'av_quality_rating' field
sub _test_qrt {

    my $dbh     = shift;
    my $cursors = _define_dbh_cursors( $dbh );

    my $ship_id = $cursors->{max_id}();

    my $tmp;


    note "Testing QRT Functionality, Ship Id: $ship_id";

    set_shipment_qrt( $dbh, $ship_id, "0.6723" );
    $tmp    = get_shipment_qrt( $dbh, $ship_id );
    is($tmp,"0.6723","QRT Set and Returned");

    set_shipment_qrt( $dbh, $ship_id, "1.0" );
    $tmp    = get_shipment_qrt( $dbh, $ship_id );
    is($tmp,"1.0","QRT Set to 1.0 and Returned");

    set_shipment_qrt( $dbh, $ship_id, "1" );
    $tmp    = get_shipment_qrt( $dbh, $ship_id );
    is($tmp,"1","QRT Set to 1.0 and Returned");

    set_shipment_qrt( $dbh, $ship_id, "0" );
    $tmp    = get_shipment_qrt( $dbh, $ship_id );
    is($tmp,"0","QRT Set to ZERO and Returned");

    set_shipment_qrt( $dbh, $ship_id, "" );
    $tmp    = get_shipment_qrt( $dbh, $ship_id );
    is($tmp,"","QRT Cleared and Returned");
}

# This tests the 2 shipment query functions and the 'get_shipment_boxes' function
# are returning back the expected fields.
sub _test_shipment_queries {

    my $dbh     = shift;
    my $cursors = _define_dbh_cursors($dbh);

    my $ship_id     = $cursors->{max_id}();
    my $order_id    = $cursors->{order_id}($ship_id);

    my $tmp;
    my $rec;
    my @fields;

    note "Testing Shipment Info Queries, Ship Id: $ship_id";

    $rec    = get_shipment_info( $dbh, $ship_id );
    cmp_ok($rec->{id},"==",$ship_id,"Got Shipment Info for Ship Id");

    @fields = qw(
                    id
                    orders_id
                    date
                    gift
                    gift_message
                    outward_airway_bill
                    return_airway_bill
                    email
                    telephone
                    mobile_telephone
                    packing_instruction
                    shipping_charge
                    shipment_type_id
                    shipment_class_id
                    shipment_status_id
                    shipment_address_id
                    comment
                    gift_credit
                    store_credit
                    destination_code
                    shipping_account_id
                    class
                    type
                    status
                    shipping_charge_id
                    shipping_name
                    shipping_class_id
                    shipping_class
                    has_packing_started
                    sla_cutoff
                    carrier
                    shipping_account_name
                    shipping_account_number
                    premier_routing_id
                    premier_routing_description
                    real_time_carrier_booking
                    av_quality_rating
                    signature_required
                    is_signature_required
                    is_premier
                    nominated_delivery_date
                    shipping_charge_sku
                    shipping_charge_premier_routing_id
                    force_manual_booking
                    has_valid_address
        );
    is_deeply( [ sort keys %{ $rec } ], [ sort @fields ], "Shipment Info Keys Exist" );

    $rec    = get_order_shipment_info( $dbh, $order_id );
    cmp_ok($rec->{$ship_id}{id},"==",$ship_id,"Got Shipment Order Info for Ship Id");

    @fields = qw(
                    id
                    date
                    gift
                    gift_message
                    outward_airway_bill
                    return_airway_bill
                    email
                    packing_instruction
                    shipping_charge
                    shipment_type_id
                    shipment_class_id
                    shipment_status_id
                    shipment_address_id
                    has_packing_started
                    shipment_hold_reason_id
                    comment
                    gift_credit
                    store_credit
                    telephone
                    mobile_telephone
                    destination_code
                    shipping_account_id
                    class
                    type
                    status
                    shipping_class
                    carrier
                    carrier_tracking_uri
                    shipping_account_name
                    shipping_account_number
                    real_time_carrier_booking
                    av_quality_rating
                    signature_required
                    is_signature_required
        );
    is_deeply( [ sort keys %{ $rec->{$ship_id} } ], [ sort @fields ], "Shipment Order Info Keys Exist" );

    $rec    = get_shipment_boxes( $dbh, $ship_id );
    isa_ok($rec,"HASH", "get_shipment_boxes returns a HASH");
    cmp_ok(keys %{ $rec },">",0,"get_shipment_boxes returend some data");

    @fields = qw(
                    shipment_box_id
                    box_id
                    tracking_number
                    inner_box_id
                    box
                    weight
                    volumetric_weight
                    inner_box
                    outward_box_label_image
                    return_box_label_image
        );
    foreach my $key ( keys %{ $rec } ) {
        is_deeply( [ sort keys %{ $rec->{$key} } ], [ sort @fields ], "Shipment Box Keys Exist" );
    }
}

#--------------------------------------------------------------

# defines a set of commands to be used by a DBI connection
sub _define_dbh_cursors {

    my $dbh     = shift;

    my $cursors = {};
    my $sql     = "";

    $cursors->{inv_ship_id}  = sub {
            my $sql =<<SQL
SELECT  MAX(s.id)
FROM    shipment s
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute();
            my ($tmp) = $sth->fetchrow_array();
            return ++$tmp;
        };

    $cursors->{max_id}  = sub {
            my $sql =<<SQL
SELECT  MAX(s.id)
FROM    shipment s
        JOIN shipping_account sa ON sa.id = s.shipping_account_id
        JOIN carrier c ON c.id = sa.carrier_id AND c.name = 'UPS'
        JOIN shipment_box sb ON sb.shipment_id = s.id
WHERE   gift = FALSE
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute();
            return $sth->fetchrow_array();
        };

    $cursors->{order_id}= sub {
            my $sql =<<SQL
SELECT  orders_id
FROM    link_orders__shipment
WHERE   shipment_id = ?
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute( shift );
            return $sth->fetchrow_array();
        };

    $cursors->{make_premier}    = sub {
            my $sql =<<SQL
UPDATE shipment
    SET shipment_type_id = (SELECT id FROM shipment_type WHERE type = 'Premier')
WHERE id = ?
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute( shift );
        };
    $cursors->{make_domestic}  = sub {
            my $sql =<<SQL
UPDATE shipment
    SET shipment_type_id = (SELECT id FROM shipment_type WHERE type = 'Domestic')
WHERE id = ?
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute( shift );
        };
    $cursors->{make_gift_shipment}  = sub {
            my $sql =<<SQL
UPDATE shipment
    SET gift    = TRUE
WHERE id = ?
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute( shift );
        };
    $cursors->{make_nongift_shipment}   = sub {
            my $sql =<<SQL
UPDATE shipment
    SET gift    = FALSE
WHERE id = ?
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute( shift );
        };
    $cursors->{make_shipment_items_gifts}   = sub {
            my $sql =<<SQL
UPDATE shipment_item
    SET gift_message = 'Message'
WHERE shipment_id = ?
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute( shift );
        };
    $cursors->{null_shipment_items_gifts}  = sub {
            my $sql =<<SQL
UPDATE shipment_item
    SET gift_message = null
WHERE shipment_id = ?
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute( shift );
        };
    $cursors->{empty_shipment_items_gifts}  = sub {
            my $sql =<<SQL
UPDATE shipment_item
    SET gift_message = ''
WHERE shipment_id = ?
SQL
;
            my $sth = $dbh->prepare($sql);
            $sth->execute( shift );
        };


    return $cursors;
}

# defines a set of commands to be used by a DBiC connection
sub _define_dbic_resultset {

    my $schema      = shift;

    my $resultset   = {};
    my $rs          = $schema->resultset('Public::Shipment');

    $resultset->{is_Automated}  = sub {
            return $rs->find( shift )->is_carrier_automated;
        };
    $resultset->{upd_AWBs}      = sub {
            my $rec     = shift;
            $rec->discard_changes;
            $rec->update({
                    outward_airway_bill => shift,
                    return_airway_bill  => shift
                });
        };
    $resultset->{upd_AutoState} = sub {
            my $rec         = shift;
            my $auto_state  = $rec->order->channel->config_group->search( { name => 'Carrier_Automation_State' } )
                                               ->first->config_group_settings_rs->search( { setting => 'state' } )->first;
            $auto_state->update( { value => shift } );
        };

    return $resultset;
}
