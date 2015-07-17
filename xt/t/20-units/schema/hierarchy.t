#!/usr/bin/env perl
use NAP::policy "tt", 'test';

=head2 Tests for the 'XTracker::Schema::Role::Hierarchy' Role and 'XTracker::Database::SchemaHierarchy'

This tests the Hierarchy Role used by many classes for various Hierarchies defined in 'XTracker::Database::SchemaHierarchy'
(currently only 'Customer Hierarchy' is defined).

It will also test the use of the following Hierarchies specifically:
    * Customer Hierarchy


please add more as they are defined.

=cut

use Test::XTracker::Data;
use Test::XT::Data;
use Test::XTracker::MessageQueue;

use XT::Domain::Returns;
use XTracker::Config::Local         qw( config_var config_section_slurp );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_issue_type
                                        :renumeration_type
                                    );
use XTracker::Database::SchemaHierarchy     qw(
                                                get_hierarchy_definition
                                                get_hierarchy_name
                                                get_hierarchy_names_for_class
                                                class_higher_or_same
                                            );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

$schema->txn_do( sub {

        my $recs    = _create_an_order( Test::XTracker::Data->channel_for_nap );

        #--------------- Tests ---------------
        _test_schema_hierarchy_functions( $recs, 1 );
        _test_customer_hierarchy( $recs, 1 );
        #-------------------------------------

        # rollback changes
        $schema->txn_rollback;
    } );

done_testing;

# test the Schema Hierarchy general functions using the 'Customer Hierarchy' to test with.
sub _test_schema_hierarchy_functions {
    my ( $recs, $oktodo )   = @_;

    SKIP: {
        skip '_test_schema_hierarchy', 1        if ( !$oktodo );

        note "TESTING '_test_schema_hierarchy_functions'";

        note "check functions return nothing when they should";
        foreach my $class_name ( undef, "", "GarbageClassName" ) {
            # get_hierarchy_names_for_class
            my $desc    = $class_name // 'undef';
            my @names   = get_hierarchy_names_for_class( $class_name );
            cmp_ok( @names, '==', 0, "Array Context: 'get_hierarchy_names_for_class' returns empty array when called with '$desc'" );
            my $names   = get_hierarchy_names_for_class( $class_name );
            isa_ok( $names, 'ARRAY', "Array Ref Context: Got an Array Ref back" );
            cmp_ok( @{ $names }, '==', 0, "Array Ref Context: 'get_hierarchy_names_for_class' returns empty array when called with '$desc'" );

            # get_hierarchy_name
            my $name    = get_hierarchy_name( $class_name );
            ok( !defined $name, "'get_hierarchy_name' returns 'undef' when called with '$desc'" );

            # get_hierarchy_definition
            my $def = get_hierarchy_definition( $class_name );
            ok( !defined $def, "'get_hierarchy_definition' returns 'undef' when called with '$desc'" );
        }

        note "check functions return something when they should";
        foreach my $class ( 'Customer',$recs->{ship_renum}, $recs->{reservation} ) {
            my $desc    = ( ref( $class ) ? ref( $class ) : $class );

            my @names   = get_hierarchy_names_for_class( $class );
            cmp_ok( @names, '==', 1, "Array Context: 'get_hierarchy_names_for_class' returned an Array with 1 element when called with '$desc'" );
            is( $names[0], 'Customer', "and the first element has the expected Name" );
            my $names   = get_hierarchy_names_for_class( $class );
            isa_ok( $names, 'ARRAY', "Array Ref Context: Got an Array Ref back" );
            cmp_ok( @{ $names }, '==', 1, "Array Ref Context: 'get_hierarchy_names_for_class' returned an Array with 1 element when called with '$desc'" );
            is( $names->[0], 'Customer', "and the first element has the expected Name" );

            if ( ref( $class ) ) {
                # check using a full class name
                is( get_hierarchy_name( ref( $class ) ), 'Customer', "'get_hierarchy_name' with a full class name returned as expected with '$desc'" );
            }
            is( get_hierarchy_name( $class ), 'Customer', "'get_hierarchy_name' returned as expected with '$desc'" );

            my $def = get_hierarchy_definition( $class );
            isa_ok( $def, 'HASH', "'get_hierarchy_definition' returned a Hash Ref when called with '$desc'" );
            ok( exists( $def->{hierarchy}{Return} ), "with a 'hierarchy->Return' key" );
            ok( exists( $def->{traverse_hierarchy}{Return} ), "with a 'traverse_hierarchy->Return' key" );
        }


        note "check 'class_higher_or_same'";
        throws_ok { class_higher_or_same() } qr/No Hierarchy Name passed/i, "function dies when no 'Hierarchy' name is passed in";
        my $got = class_higher_or_same( 'TestName', $recs->{shipment}, 'Shipment' );
        ok( defined $got, "When passed with an unknown Hierarchy Name returns a defined value" );
        cmp_ok( $got, '==', 0, "and the value is FALSE" );

        my %tests   = (
                'when passed with no Class or Record' => {
                            params  => [ ],
                            expected=> 0,
                    },
                'when passed with no Class' => {
                            params  => [ $recs->{shipment} ],
                            expected=> 0,
                    },
                'when passed with no Record' => {
                            params  => [ undef, 'Shipment' ],
                            expected=> 0,
                    },
                'when passed with Class undef' => {
                            params  => [ $recs->{shipment}, undef ],
                            expected=> 0,
                    },
                'when passed with an Unknown Class to the Hierarchy' => {
                            params  => [ $recs->{shipment}, 'Country' ],
                            expected=> 0,
                    },
                'when passed with an Unknown Record to the Hierarchy' => {
                            params  => [ $recs->{shipment}->shipment_type, 'Shipment' ],
                            expected=> 0,
                    },
                'Shipment is the same as Shipment' => {
                            params  => [ $recs->{shipment}, 'Shipment' ],
                            expected=> 1,
                    },
                'Orders is higher than Shipment' => {
                            params  => [ $recs->{shipment}, 'Public::Orders' ],
                            expected=> 0,
                    },
                'Return is Lower than Shipment' => {
                            params  => [ $recs->{shipment}, 'Public::Return' ],
                            expected=> 1,
                    },
            );
        foreach my $label ( keys %tests ) {
            my $test    = $tests{ $label };
            note "Test: $label";
            my $result_desc = ( $test->{expected} ? 'TRUE' : 'FALSE' );
            $got    = class_higher_or_same( 'Customer', @{ $test->{params} } );
            ok( defined $got, "function returned a defined value" );
            cmp_ok( $got, '==', $test->{expected}, "and value is as expected: $result_desc" );
        }

        note "check various hierarchy traversing methods";

        note "Testing methods fail when incorrect parameters are passed";
        throws_ok { $recs->{customer}->next_in_hierarchy_isa } qr/No Class Name passed/,
                                                "'next_in_hierarchy_isa' method fails when no 'Class' passed";
        throws_ok { $recs->{customer}->next_in_hierarchy_from_class } qr/No Class Name passed/,
                                                "'next_in_hierarchy_from_class' method fails when no 'Class' passed";
        throws_ok { $recs->{customer}->next_in_hierarchy_from_class( 'Customer', [ 1 ] ) } qr/Arguments is not a Hash Ref passed/,
                                                "'next_in_hierarchy_from_class' method fails when improper 'Arguments' are passed";
        throws_ok { $recs->{customer}->next_in_hierarchy_with_method } qr/No Method Name passed/,
                                                "'next_in_hierarchy_with_method' method fails when no 'Method' passed";
        throws_ok { $recs->{customer}->next_in_hierarchy_with_method( 'Customer', [ 1 ] ) } qr/Arguments is not a Hash Ref passed/,
                                                "'next_in_hierarchy_with_method' method fails when improper 'Arguments' are passed";

        %tests  = (
                "'next_in_hierarchy' without specifying a Hierarchy Name" => {
                        params  => [],
                        method  => 'next_in_hierarchy',
                        rec     => $recs->{shipment},
                        expect  => $recs->{order},
                    },
                "'next_in_hierarchy' specifying a Hierarchy Name" => {
                        params  => [ 'Customer' ],
                        method  => 'next_in_hierarchy',
                        rec     => $recs->{shipment},
                        expect  => $recs->{order},
                    },
                "'next_in_hierarchy' specifying an Invalid Hierarchy Name" => {
                        params  => [ 'Garbage' ],
                        method  => 'next_in_hierarchy',
                        rec     => $recs->{shipment},
                        expect  => undef,
                    },
                "'next_in_hierarchy_isa' without specifying Hierarchy Name" => {
                        params  => [ 'Orders' ],
                        method  => 'next_in_hierarchy_isa',
                        rec     => $recs->{shipment},
                        expect  => 1,
                    },
                "'next_in_hierarchy_isa' specifying a Hierarchy Name" => {
                        params  => [ 'Customer', 'Orders' ],
                        method  => 'next_in_hierarchy_isa',
                        rec     => $recs->{shipment},
                        expect  => 1,
                    },
                "'next_in_hierarchy_isa' specifying an Invalid Hierarchy Name" => {
                        params  => [ 'Garbage', 'Orders' ],
                        method  => 'next_in_hierarchy_isa',
                        rec     => $recs->{shipment},
                        expect  => 0,
                    },
                "'next_in_hierarchy_from_class' without specifying Hierarchy Name" => {
                        params  => [ 'Orders' ],
                        method  => 'next_in_hierarchy_from_class',
                        rec     => $recs->{shipment},
                        expect  => $recs->{order},
                    },
                "'next_in_hierarchy_from_class' without specifying Hierarchy Name and with Args" => {
                        params  => [ 'Orders', { stop_if_me => 1 } ],
                        method  => 'next_in_hierarchy_from_class',
                        rec     => $recs->{order},
                        expect  => $recs->{order},
                    },
                "'next_in_hierarchy_from_class' specifying a Hierarchy Name" => {
                        params  => [ 'Customer', 'Orders' ],
                        method  => 'next_in_hierarchy_from_class',
                        rec     => $recs->{shipment},
                        expect  => $recs->{order},
                    },
                "'next_in_hierarchy_from_class' specifying a Hierarchy Name and with Args" => {
                        params  => [ 'Customer', 'Orders', { stop_if_me => 1 } ],
                        method  => 'next_in_hierarchy_from_class',
                        rec     => $recs->{order},
                        expect  => $recs->{order},
                    },
                "'next_in_hierarchy_from_class' specifying an Invalid Hierarchy Name" => {
                        params  => [ 'Garbage', 'Orders' ],
                        method  => 'next_in_hierarchy_from_class',
                        rec     => $recs->{shipment},
                        expect  => undef,
                    },
                "'next_in_hierarchy_with_method' without specifying Hierarchy Name" => {
                        params  => [ 'order_nr' ],
                        method  => 'next_in_hierarchy_with_method',
                        rec     => $recs->{shipment},
                        expect  => $recs->{order},
                    },
                "'next_in_hierarchy_with_method' without specifying Hierarchy Name and with Args" => {
                        params  => [ 'order_nr', { stop_if_me => 1 } ],
                        method  => 'next_in_hierarchy_with_method',
                        rec     => $recs->{order},
                        expect  => $recs->{order},
                    },
                "'next_in_hierarchy_with_method' specifying a Hierarchy Name" => {
                        params  => [ 'Customer', 'order_nr' ],
                        method  => 'next_in_hierarchy_with_method',
                        rec     => $recs->{shipment},
                        expect  => $recs->{order},
                    },
                "'next_in_hierarchy_with_method' specifying a Hierarchy Name and with Args" => {
                        params  => [ 'Customer', 'order_nr', { stop_if_me => 1 } ],
                        method  => 'next_in_hierarchy_with_method',
                        rec     => $recs->{order},
                        expect  => $recs->{order},
                    },
                "'next_in_hierarchy_with_method' specifying an Invalid Hierarchy Name" => {
                        params  => [ 'Garbage', 'order_nr' ],
                        method  => 'next_in_hierarchy_with_method',
                        rec     => $recs->{shipment},
                        expect  => undef,
                    },
            );
        foreach my $label ( sort keys %tests ) {
            note "Test: $label";
            my $test    = $tests{ $label };
            my $method  = $test->{method};
            my $rec     = $test->{rec};
            my $expect  = $test->{expect};
            my @params  = @{ $test->{params} };

            $got    = $rec->$method( @params );
            if ( defined $expect ) {
                if ( ref( $expect ) ) {
                    isa_ok( $got, ref( $expect ), "method returned expected Class" );
                    cmp_ok( $got->id, '==', $expect->id, "and expected Record" );
                }
                else {
                    cmp_ok( $got, '==', $expect, "method returned as expected: $got" );
                }
            }
            else {
                ok( !defined $got, "method returned 'undef' as expected" ) or note "Got: $got";
            }
        }

    };

    return;
}

# tests the Customer Hierarchy defined in 'XTracker::Database::SchemaHierarchy'
sub _test_customer_hierarchy {
    ## no critic(ProhibitDeepNests)
    my ( $recs, $oktodo )   = @_;

    SKIP: {
        skip '_test_customer_hierarchy', 1      if ( !$oktodo );

        note "TESTING '_test_customer_hierarchy'";

        # get a class prefix to be used for the tests below
        my $class_prefix= ref( $recs->{customer} );
        $class_prefix   =~ s/::Customer$//g;

        note "Testing 'class_higher_or_the_same' method";
        cmp_ok( class_higher_or_same( 'Customer', $recs->{shipment}, 'Return' ), '==', 1, "'class_higher_or_same' Shipment > Return returns TRUE" );
        cmp_ok( class_higher_or_same( 'Customer', $recs->{shipment}, 'Shipment' ), '==', 1,
                                        "'class_higher_or_same' Shipment = Shipment returns TRUE" );
        cmp_ok( class_higher_or_same( 'Customer', $recs->{shipment}, 'Orders' ), '==', 0, "'class_higher_or_same' Shipment < Orders returns FALSE" );
        cmp_ok( class_higher_or_same( 'Customer', $recs->{shipment}, ""), '==', 0,
                                        "'class_higher_or_same' returns FALSE when empty string Class used" );
        cmp_ok( class_higher_or_same( 'Customer', $recs->{shipment}, undef ), '==', 0,
                                        "'class_higher_or_same' returns FALSE when 'undef' Class used" );
        cmp_ok( class_higher_or_same( 'Customer', $recs->{shipment}, 'Garbage' ), '==', 0,
                                        "'class_higher_or_same' returns FALSE when invalid Class used" );
        cmp_ok( class_higher_or_same( 'Customer', $recs->{ship_renum}, 'Return' ), '==', 1,
                                        "'class_higher_or_same' returns TRUE for 'ship_renum' compared to 'Return'" );
        cmp_ok( class_higher_or_same( 'Customer', $recs->{ret_renum}, 'Return' ), '==', 0,
                                        "'class_higher_or_same' returns FALSE for 'ret_renum' compared to 'Return'" );

        note "Testing 'next_in_hierarchy' & 'next_in_hierarchy_isa' method";
        # details what record should get which Class back when 'next_in_hierarchy' is called
        my %tests   = (
                customer    => undef,
                order       => { Customer => 'customer' },
                shipment    => { Orders => 'order' },
                ship_renum  => { Shipment => 'shipment' },
                'return'    => { Shipment => 'shipment' },
                ret_renum   => { Return => 'return' },
                reservation => { Customer => 'customer' },
            );
        foreach my $rectotest ( keys %tests ) {
            note "with '$rectotest'";
            my $test= $tests{ $rectotest };
            my $got = $recs->{ $rectotest }->next_in_hierarchy;
            if ( $test ) {
                my ( $expected, $exprec )   = each %{ $test };
                isa_ok( $got, "${class_prefix}::${expected}", "'next_in_hierarchy' method returned Expected record Class" );
                cmp_ok( $got->id, '==', $recs->{ $exprec }->id, "and record returned is the one Exepcted" );
                $got    = $recs->{ $rectotest }->next_in_hierarchy_isa( $expected );
                ok( defined $got, "'next_in_hierarchy_isa' returned a defined value" );
                cmp_ok( $got, '==', 1, "and value is TRUE" );
                $got    = $recs->{ $rectotest }->next_in_hierarchy_isa( 'GARBAGE' );
                ok( defined $got, "returned a defined value asking for a nonsense Class" );
                cmp_ok( $got, '==', 0, "and value is FALSE" );
            }
            else {
                ok( !defined $got, "'next_in_hierarchy' method returned back 'undef'" );
                $got    = $recs->{ $rectotest }->next_in_hierarchy_isa( 'GARBAGE' );
                ok( defined $got, "'next_in_hierarchy_isa' returned a defined value asking for a nonsense Class" );
                cmp_ok( $got, '==', 0, "and value is FALSE" );
            }
        }

        note "Testing 'next_in_hierarchy_from_class' method";
        # details the Classes requested for a record and what records are expected back
        %tests  = (
                customer    => [
                        { Customer => undef },
                        { Orders => undef },
                        { Reservation => undef },
                    ],
                order       => [
                        { Customer => 'customer' },
                        { Shipment => 'customer' },
                    ],
                shipment    => [
                        { Customer => 'customer' },
                        { Orders => 'order' },
                        { Return => 'order' },
                    ],
                ship_renum  => [
                        { Shipment => 'shipment' },
                        { Orders => 'order' },
                        { Customer => 'customer' },
                        { Return => 'shipment' },
                        { Reservation => 'order' },
                    ],
                'return'    => [
                        { Shipment => 'shipment' },
                        { Orders => 'order' },
                        { Customer => 'customer' },
                        { Renumeration => 'shipment' },
                    ],
                ret_renum   => [
                        { Return => 'return' },
                        { Shipment => 'shipment' },
                        { Orders => 'order' },
                        { Customer => 'customer' },
                        { Reservation => 'order' },
                    ],
                reservation => [
                        { Customer => 'customer' },
                        { Shipment => 'customer' },
                    ],
            );
        foreach my $rectouse ( keys %tests ) {
            note "with '$rectouse'";

            # check with 'stop_if_me' parameter passed, should return it'self
            my $got = $recs->{ $rectouse }->next_in_hierarchy_from_class( ref( $recs->{ $rectouse } ), { stop_if_me => 1 } );
            isa_ok( $got, ref( $recs->{ $rectouse } ), "checking using its own class with 'stop_if_me' set, returned Expected record Class" );
            cmp_ok( $got->id, '==', $recs->{ $rectouse }->id, "and record returned is the one Exepcted" );

            my $want_classes    = $tests{ $rectouse };
            foreach my $want ( @{ $want_classes } ) {
                my ( $class, $exprec )  = each %{ $want };
                my $got = $recs->{ $rectouse }->next_in_hierarchy_from_class( $class );
                if ( $exprec ) {
                    isa_ok( $got, ref( $recs->{ $exprec } ), "wanting Class '$class', method returned Expected record Class" );
                    cmp_ok( $got->id, '==', $recs->{ $exprec }->id, "and record returned is the one Exepcted" );
                }
                else {
                    ok( !defined $got, "wanting Class '$class', method returned 'undef'" ) or note "Got: " . $got;
                }
            }
        }

        note "Testing 'next_in_hierarchy_with_method' method";
        # search with various known methods and test that the correct record is returned
        my @tests   = (
                {
                    method  => 'order_nr',
                    rectoget=> 'order',
                    undef_if_rec => [ qw( customer reservation order ) ],
                },
                {
                    method  => 'is_customer_number',
                    rectoget=> 'customer',
                    undef_if_rec => [ qw( customer ) ],
                },
                {
                    method  => 'id',
                    rectoget=> 'next',      # means next in hierarchy
                    undef_if_rec => [ qw( customer ) ],
                },
                {
                    label   => "find method 'id' with 'stop_if_me' argument passed in",
                    method  => 'id',
                    rectoget=> undef,       # means should return the record used
                    params  => {
                            stop_if_me => 1,
                        },
                },
                {
                    label   => "find method 'order_nr' with 'from_class' argument passed in",
                    method  => 'order_nr',
                    rectoget=> 'order',
                    params  => {
                            from_class => 'Return',
                        },
                    undef_if_rec => [ qw( customer order reservation ) ],
                },
                {
                    label   => "find method 'id' but Starting at 'Shipment'",
                    method  => 'id',
                    # this provides a mapping between the Class of the record being used
                    # and the record that is expected to be returned, the first element
                    # is 'default' and means any Class not listed should expect the first
                    # element in the 'rectoget' array
                    rectouse=> [ qw( default shipment order reservation ) ],
                    rectoget=> [ qw( shipment order customer customer) ],
                    params  => {
                            from_class => 'Shipment',
                        },
                    undef_if_rec => [ qw( customer ) ],
                },
                {
                    label   => "find method 'id' with 'from_class' & 'stop_if_me' arguments passed in",
                    method  => 'id',
                    rectoget=> undef,       # means should return the record used
                    params  => {
                            stop_if_me => 1,
                            from_class => 'Orders',
                        },
                },
                {
                    label   => "find method 'id' with a 'from_class' that doesn't exist, should all return 'undef'",
                    method  => 'id',
                    # no 'rectoget' means all records should return 'undef'
                    params  => {
                            from_class => 'GarbageClass',
                        },
                },
            );
        # loop round each record and run all the above tests
        foreach my $rectouse ( keys %{ $recs } ) {
            note "with '$rectouse'";
            my $rec = $recs->{ $rectouse };

            foreach my $test ( @tests ) {
                note ( exists( $test->{label} ) ? $test->{label} : "find method '$test->{method}'" );

                my @params  = ( $test->{method} );
                push @params, $test->{params}       if ( exists( $test->{params} ) );
                my $got = $rec->next_in_hierarchy_with_method( @params );

                # if 'rectoget' key doesn't exist in the test data then expect 'undef' for any record
                push @{ $test->{undef_if_rec} }, $rectouse      if ( !exists( $test->{rectoget} ) );

                if ( !grep { $rectouse eq $_ } @{ $test->{undef_if_rec} } ) {
                    my $exp_class;
                    my $rectoget;

                    # work out which Class & Record is expected
                    if ( !defined $test->{rectoget} ) {
                        $rectoget   = $rec;
                    }
                    elsif ( ref( $test->{rectoget} ) eq 'ARRAY' ) {
                        $rectoget   = $test->{rectoget}[0];
                        REC_CHK:
                        foreach my $i ( 0..$#{ $test->{rectouse} } ) {
                            if ( $test->{rectouse}[ $i ] eq $rectouse ) {
                                $rectoget   = $test->{rectoget}[ $i ];
                                last REC_CHK;
                            }
                        }
                        $rectoget   = $recs->{ $rectoget };
                    }
                    elsif ( $test->{rectoget} eq 'next' ) {
                        $rectoget   = $rec->next_in_hierarchy;
                    }
                    else {
                        $rectoget   = $recs->{ $test->{rectoget} };
                    }
                    $exp_class  = ref( $rectoget );

                    isa_ok( $got, $exp_class, "method returned Expected record Class" );
                    cmp_ok( $got->id, '==', $rectoget->id, "and record returned is the one Exepcted" );
                }
                else {
                    ok( !defined $got, "method returned 'undef'" ) or note "Got: " . $got;
                }
            }
        }
    };

    return
}

#-------------------------------------------------------------------------------------------

# create an Order
sub _create_an_order {
    my $channel     = shift;

    my $num_pids    = 2;

    my $framework   = Test::XT::Data->new_with_traits(
        traits => [
                'Test::XT::Data::Channel',
                'Test::XT::Data::Customer',
            ],
    );
    # need to do this because 'ReservationSimple' contains attributes which clash with the above
    my $framework2  = Test::XT::Data->new_with_traits(
        traits => [
                'Test::XT::Data::ReservationSimple',
            ],
    );
    # need AMQ in order for 'XT::Domain::Return' to work
    my $amq = Test::XTracker::MessageQueue->new( {
        schema  => $schema,
    } );
    # get a new instance of 'XT::Domain::Return'
    my $domain  = XT::Domain::Returns->new(
                            schema => $schema,
                            msg_factory => $amq,
                        );

    $framework->channel( $channel );
    $framework2->channel( $channel );
    my $customer    = $framework->customer;
    $framework2->customer( $customer );
    my $reservation = $framework2->reservation;

    # clear the frameworks
    $framework  = undef;
    $framework2 = undef;

    my ( $forget, $pids )   = Test::XTracker::Data->grab_products( {
                                                how_many    => $num_pids,
                                                channel     => $channel,
                                            } );

    my $base    = {
            create_renumerations    => 1,
            shipping_charge         => 10,
            customer_id             => $customer->id,
            channel_id              => $channel->id,
            tenders                 => [ { type => 'card_debit', value => 10 + ( 100 * $num_pids ) } ],
        };

    my ( $order )   = Test::XTracker::Data->create_db_order( {
                                                pids    => $pids,
                                                base    => $base,
                                                attrs   => [ map { price => 100, tax => 0, duty => 0 }, ( 1..$num_pids ) ],
                                        } );

    my $shipment    = $order->get_standard_class_shipment;
    my $shp_renum   = $shipment->renumerations->first;

    my $return  = $domain->create( {
                        operator_id => $APPLICATION_OPERATOR_ID,
                        shipment_id => $shipment->id,
                        pickup => 0,
                        refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
                        return_items => {
                                map {
                                        $_->id => {
                                            type        => 'Return',
                                            reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                        }
                                    } $shipment->shipment_items->all
                            }
                    } );
    my $ret_renum   = $return->renumerations->first;

    note "Customer Nr/Id  : ".$customer->is_customer_number."/".$customer->id;
    note "Order Nr/Id     : ".$order->order_nr."/".$order->id;
    note "Shipment Id     : ".$shipment->id;
    note "Ship Renum Id   : ".$shp_renum->id;
    note "Return RMA/Id   : ".$return->rma_number."/".$return->id;
    note "Ret. Renum Id   : ".$ret_renum->id;
    note "Reservation Id  : ".$reservation->id;

    return {
            customer    => $customer->discard_changes,
            order       => $order->discard_changes,
            shipment    => $shipment->discard_changes,
            ship_renum  => $shp_renum->discard_changes,
            return      => $return->discard_changes,
            ret_renum   => $ret_renum->discard_changes,
            reservation => $reservation->discard_changes,
        };
}
