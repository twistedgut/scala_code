package Test::XT::Text::PlaceHolder;

use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::Text::PlaceHolder

=head1 SYNOPSIS

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::FraudRule;
use Test::XT::Data;
use Test::MockObject;

use XTracker::Config::Local;
use XTracker::Constants::FromDB     qw( :customer_category );

use XT::Text::PlaceHolder;
use XT::Text::PlaceHolder::Type;

use JSON;

=head1 TESTS

=cut

# to be done first before ALL the tests start
sub startup : Test( startup => 0 ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
}

# to be done BEFORE each test runs
sub setup : Test( setup => 2 ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{data}   = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::Order',
        ],
    );
    $self->{order}      = $self->data->new_order->{order_object};
    $self->{customer}   = $self->{order}->customer;
    $self->{channel}    = $self->{order}->channel;

    $self->schema->txn_begin;
}

# to be done AFTER every test runs
sub teardown : Test( teardown => 0 ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}

=head2 test_place_holder_type_class

Tests when instantiating 'XT::Text::PlaceHolder::Type' the correct
'Type::*' Class is returned.

=cut

sub test_place_holder_type_class :Tests() {
    my $self    = shift;

    my $objects_arr = [
        $self->order,
        $self->customer,
        Fake::Object->new,
    ];

    my %tests   = (
        "Failure with Channel Option and NO Channel Provided" => {
            args    => {
                place_holder  => 'P[LUT.Public::CreditHoldThreshold.value,name=Test_Number Done In a Week:channel]',
                schema  => $self->schema,
            },
            expect  => {
                success => 0,
                failure => qr/Can't.*Sales Channel/i,
            },
        },
        "LUT Failure with incorrect Part 1" => {
            args    => {
                place_holder  => 'P[LUT.CreditHoldThreshold.value,name=Test_Number Done In a Week]',
                schema  => $self->schema,
            },
            expect  => {
                success => 0,
                failure => qr/LUT.*Split Part 1/i,
            },
        },
        "LUT Failure with incorrect Part 2" => {
            args    => {
                place_holder  => 'P[LUT.Public::CreditHoldThreshold.value]',
                schema  => $self->schema,
            },
            expect  => {
                success => 0,
                failure => qr/LUT.*Split Part 2/i,
            },
        },
        "LUT Failure with NO Schema Provided" => {
            args    => {
                place_holder  => 'P[LUT.Public::CreditHoldThreshold.value,name=Test_Number Done In a Week]',
            },
            expect  => {
                success => 0,
                failure => qr/attribute.*\(schema\)/i,
            },
        },
        "LUT Success" => {
            args    => {
                place_holder  => 'P[LUT.Public::CreditHoldThreshold.value,name=Test_Number Done In a Week]',
                schema  => $self->schema,
            },
            expect  => {
                success => 1,
                class_name => 'XT::Text::PlaceHolder::Type::LUT',
                attributes => {
                    _is_channelised     => 0,
                    cache_the_value     => 1,
                    _table_class_name   => 'Public::CreditHoldThreshold',
                    _column_with_value  => 'value',
                    _column_to_query    => 'name',
                    _value_to_query_for => 'Test_Number Done In a Week',
                }
            },
        },
        "SMC Failure with incorrect Part 1" => {
            args    => {
                place_holder  => 'P[SMC.Orders.id]',
                objects => $objects_arr,
            },
            expect  => {
                success => 0,
                failure => qr/SMC.*Split Part 1/i,
            },
        },
        "SMC Failure with incorrect Part 2" => {
            args    => {
                place_holder  => 'P[SMC.Public::Orders.]',
                objects => $objects_arr,
            },
            expect  => {
                success => 0,
                failure => qr/SMC.*Split Part 2/i,
            },
        },
        "SMC Failure with NO Objects Provided" => {
            args    => {
                place_holder  => 'P[SMC.Public::Orders.id]',
            },
            expect  => {
                success => 0,
                failure => qr/.*objects.*required/i,
            },
        },
        "SMC Success" => {
            args    => {
                place_holder  => 'P[SMC.Public::Orders._id-val:nocache]',
                objects => $objects_arr,
            },
            expect  => {
                success => 1,
                class_name => 'XT::Text::PlaceHolder::Type::SMC',
                attributes => {
                    _is_channelised     => 0,
                    cache_the_value     => 0,
                    _class_name         => 'Public::Orders',
                    _method_name        => '_id-val',
                }
            },
        },
        "AMC Failure with incorrect Part 1" => {
            args    => {
                place_holder  => 'P[AMC.Fake.test(test)]',
                objects => $objects_arr,
            },
            expect  => {
                success => 0,
                failure => qr/AMC.*Split Part 1/i,
            },
        },
        "AMC Failure with missing Part 2" => {
            args    => {
                place_holder  => 'P[AMC.Fake::Object.]',
                objects => $objects_arr,
            },
            expect  => {
                success => 0,
                failure => qr/AMC.*Split Part 2/i,
            },
        },
        "AMC Failure with incorrect Part 2" => {
            args    => {
                place_holder  => 'P[AMC.Fake::Object.test()]',
                objects => $objects_arr,
            },
            expect  => {
                success => 0,
                failure => qr/AMC.*Split Part 2/i,
            },
        },
        "AMC Failure with NO Objects Provided" => {
            args    => {
                place_holder  => 'P[AMC.Fake::Object.test(test)]',
            },
            expect  => {
                success => 0,
                failure => qr/.*objects.*required/i,
            },
        },
        "AMC Success" => {
            args    => {
                place_holder  => 'P[AMC.Fake::Object.test(test):nocache]',
                objects => $objects_arr,
            },
            expect  => {
                success => 1,
                class_name => 'XT::Text::PlaceHolder::Type::AMC',
                attributes => {
                    _is_channelised     => 0,
                    cache_the_value     => 0,
                    _class_name         => 'Fake::Object',
                    _method_name        => 'test',
                }
            },
        },
        "SC Failure with incorrect Part 1" => {
            args    => {
                place_holder  => 'P[SC. .Setting]',
                schema => $self->schema,
            },
            expect  => {
                success => 0,
                failure => qr/SC.*Split Part 1/i,
            },
        },
        "SC Failure with incorrect Part 2" => {
            args    => {
                place_holder  => 'P[SC.Group. ]',
                schema => $self->schema,
            },
            expect  => {
                success => 0,
                failure => qr/SC.*Split Part 2/i,
            },
        },
        "SC Failure with NO Schema Provided" => {
            args    => {
                place_holder  => 'P[SC.Group.Setting]',
            },
            expect  => {
                success => 0,
                failure => qr/attribute.*\(schema\)/i,
            },
        },
        "SC Success" => {
            args    => {
                place_holder  => 'P[SC.Gro up.Sett ing:channel]',
                schema => $self->schema,
                channel => $self->channel,
            },
            expect  => {
                success => 1,
                class_name => 'XT::Text::PlaceHolder::Type::SC',
                attributes => {
                    _is_channelised     => 1,
                    cache_the_value     => 1,
                    _config_group       => 'Gro up',
                    _config_setting     => 'Sett ing',
                }
            },
        },
        "C Failure with incorrect Part 1" => {
            args    => {
                place_holder  => 'P[C. .Setting]',
            },
            expect  => {
                success => 0,
                failure => qr/C.*Split Part 1/i,
            },
        },
        "C Failure with incorrect Part 2" => {
            args    => {
                place_holder  => 'P[C.Group. ]',
            },
            expect  => {
                success => 0,
                failure => qr/C.*Split Part 2/i,
            },
        },
        "C Failure with NO Channel Provided when 'channel' option used" => {
            args    => {
                place_holder  => 'P[C.Group.Setting:channel]',
            },
            expect  => {
                success => 0,
                failure => qr/Can't.*Sales Channel/i,
            },
        },
        "C Success" => {
            args    => {
                place_holder  => 'P[C.Group.Setting:channel,nocache]',
                channel => $self->channel,
            },
            expect  => {
                success => 1,
                class_name => 'XT::Text::PlaceHolder::Type::C',
                attributes => {
                    _is_channelised     => 1,
                    cache_the_value     => 0,
                    _config_section     => 'Group',
                    _config_setting     => 'Setting',
                }
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $expect  = $test->{expect};

        if ( $expect->{success} ) {
            my $ph;
            lives_ok {
                $ph = XT::Text::PlaceHolder::Type->new( $test->{args} );
            }
            "got Place Holder Type";
            isa_ok( $ph, $expect->{class_name}, "and is of the expected Class" );

            my %got_attrs   = (
                map { $_ => $ph->$_ } keys %{ $expect->{attributes} }
            );
            is_deeply( \%got_attrs, $expect->{attributes},
                            "Place Holder Type's Attributes as Expected" );
        }
        else {
            my $failure = $expect->{failure};
            throws_ok {
                my $ph = XT::Text::PlaceHolder::Type->new( $test->{args} );
            }
            qr/${failure}/,
            "got expected Failure";
            note "Error Thrown: '${@}'";
        }
    }
}

=head2 test__replace_place_holders

This tests the 'replace' method.

=cut

sub test__replace_place_holders : Tests() {
    my $self    = shift;

    # create test data
    $self->_create_test_data( [
        {
            type => 'SystemConfig',
            group => 'TestGroup1',
            settings => [ { setting => 'TestSetting', value => 4 } ],
        },
        {
            type => 'SystemConfig',
            channel => $self->channel,
            group => 'TestGroup1',
            settings => [ { setting => 'Test Setting', value => 'fred' } ],
        },
        {
            type => 'SystemConfig',
            group => 'TestGroup2',
            settings => [ { setting => 'Test Setting', value => 8 } ],
        },
        {
            type => 'SystemConfig',
            channel => $self->channel,
            group => 'TestGroup2',
            settings => [ { setting => 'TestSetting', value => 'qwerty' } ],
        },
        { type => 'Config', section => 'TestGroup1', setting => 'TestSetting', value => 104 },
        { type => 'Config', section => 'TestGroup1', setting => 'TestSetting', value => 'sheep', channel => $self->channel },
        { type => 'Config', section => 'TestGroup2', setting => 'TestSetting', value => 108 },
        { type => 'Config', section => 'TestGroup2', setting => 'TestSetting', value => 'cow/horse', channel => $self->channel },
        {
            type => 'Table',
            class => 'Public::DistribCentre',
            args  => {
                name    => 'TEST DC',
                alias   => 'mars',
            },
        },
        {
            type => 'Table',
            class => 'Public::CreditHoldThreshold',
            args  => {
                channel_id  => $self->channel->id,
                name        => 'Test_Number Done In a Week',
                value       => 45,
            },
        },
        {
            type => 'Config',
            section => 'TestGroup2',
            setting => 'ValueWithRegExChars',
            value => '1\.2\3\s.45(4)*re?d(?<captha>fred)$er',
        },
    ] );


    my %tests   = (
        "System Config Place Holder, Not Channelised" => {
            string  => '{ key => P[SC.TestGroup1.TestSetting] }',
            expected=> '{ key => 4 }',
        },
        "System Config Place Holder, Channelised" => {
            string  => '{ key => "P[SC.TestGroup1.Test Setting:channel]" }',
            expected=> '{ key => "fred" }',
        },
        "Normal Config Place Holder, Not Channelised" => {
            string  => 'P[C.TestGroup1.TestSetting]',
            expected=> '104',
        },
        "Normal Config Place Holder, Channelised" => {
            string  => '{ key => [ "P[C.TestGroup1.TestSetting:channel]" ] }',
            expected=> '{ key => [ "sheep" ] }',
        },
        "Table Place Holder, Not Channelised" => {
            string  => 'P[LUT.Public::DistribCentre.alias,name=TEST DC]',
            expected=> 'mars',
        },
        "Table Place Holder, Channelised" => {
            string  => '{ key => P[LUT.Public::CreditHoldThreshold.value,name=Test_Number Done In a Week:channel] }',
            expected=> '{ key => 45 }',
        },
        "Simple Method Call Place Holder" => {
            string  => '{ key => P[SMC.Public::Orders.get_total_value_in_local_currency] }',
            expected=> '{ key => ' . $self->order->get_total_value_in_local_currency . ' }',
        },
        "Advanced Method Call Place Holder - Single Scalar" => {
            string  => '{ key => P[AMC.Fake::Object.array_test(test)] }',
            expected=> '{ key => ["test"] }',
        },
        "Advanced Method Call Place Holder - Double Scalar" => {
            string  => '{ key => P[AMC.Fake::Object.array_test(test,test)] }',
            expected=> '{ key => ["test","test"] }',
        },
        "Advanced Method Call Place Holder - Single ArrayRef" => {
            string  => '{ key => P[AMC.Fake::Object.arrayref_test(test)] }',
            expected=> '{ key => [["test"]] }',
        },
        "Advanced Method Call Place Holder - Double ArrayRef" => {
            string  => '{ key => P[AMC.Fake::Object.arrayref_test(test,test)] }',
            expected=> '{ key => [["test","test"]] }',
        },
        "Advanced Method Call Place Holder - Single HashRef" => {
            string  => '{ key => P[AMC.Fake::Object.hashref_test(test)] }',
            expected=> '{ key => [{"in":["test"]}] }',
        },
        "Advanced Method Call Place Holder - Double HashRef" => {
            string  => '{ key => P[AMC.Fake::Object.hashref_test(test,test)] }',
            expected=> '{ key => [{"in":["test","test"]}] }',
        },
        "Multiple uses of Place Holders" => {
            string  => 'P[SC.TestGroup2.Test Setting], '
                       . '{ key => [ P[LUT.Public::CreditHoldThreshold.value,name=Test_Number Done In a Week:channel] ] }, '
                       . '"P[SC.TestGroup1.Test Setting:channel]"',
            expected => '8, { key => [ 45 ] }, "fred"',
        },
        "Multiple uses of Place Holders over new lines" => {
            string  => 'P[SC.TestGroup1.Test Setting:channel],'
                       . "\n" . '{ key => [ P[LUT.Public::CreditHoldThreshold.value,name=Test_Number Done In a Week:channel] ] },'
                       . "\n" . '"P[SC.TestGroup2.TestSetting:channel]"',
            expected => 'fred,' . "\n" . '{ key => [ 45 ] },' . "\n" . '"qwerty"',
        },
        "Multiple Occurences of the same Place Holders" => {
            string  => 'P[SC.TestGroup1.Test Setting:channel]P[SC.TestGroup1.Test Setting:channel]P[SC.TestGroup1.Test Setting:channel]',
            expected=> 'fredfredfred',
        },
        "Another Multiple Occurences of the same Place Holders" => {
            string  => 'P[C.TestGroup1.TestSetting], { key => "P[LUT.Public::CreditHoldThreshold.value,name=Test_Number Done In a Week:channel]" }, '
                     . '[ P[LUT.Public::CreditHoldThreshold.value,name=Test_Number Done In a Week:channel], P[C.TestGroup1.TestSetting] ]',
            expected=> '104, { key => "45" }, [ 45, 104 ]',
        },
        "A Place Holder whose Replacement Value has RegEx Chars in it, they should just be treated as text" => {
            string  => 'P[C.TestGroup2.ValueWithRegExChars]',
            expected=> '1\.2\3\s.45(4)*re?d(?<captha>fred)$er',
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        my $ph = XT::Text::PlaceHolder->new( {
            string      => $test->{string},
            schema      => $self->schema,
            channel     => $self->channel,
            objects     => [
                $self->order,
                $self->customer,
                Fake::Object->new,
            ],
        } );

        my $got = $ph->replace;
        is( $got, $test->{expected}, "Place Holders were replaced correctly: '${got}'" );
    }
}

=head2 test_just_passing_a_string

Will test 'XT::Text::PlaceHolder' being only passed a string
to replace and no other arguments also tests a string which has no place-holders.

=cut

sub test_just_passing_a_string : Tests() {
    my $self    = shift;

    $self->_create_test_data( [
        { type => 'Config', section => 'TestGroup', setting => 'TestSetting', value => 104 },
    ] );

    my %tests   = (
        "Just passing a 'C' Place Holder with no other arguments" => {
            string  => 'P[C.TestGroup.TestSetting]',
            expected=> '104',
        },
        "Passing an Empty String" => {
            string  => '',
            expected=> '',
        },
        "Passing an 'undef' String, get an Empty String back" => {
            string  => undef,
            expected=> '',
        },
        "Passing '0' and should get the same back" => {
            string  => '0',
            expected=> '0',
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        # just pass 'string'
        my $ph = XT::Text::PlaceHolder->new( {
            string  => $test->{string},
        } );
        my $got = $ph->replace;
        is( $got, $test->{expected}, "got expected replacement: '${got}' when only passing 'string'" );

        # pass 'string' but all other arguments as 'undef'
        $ph = XT::Text::PlaceHolder->new( {
            string  => $test->{string},
            schema  => undef,
            channel => undef,
            objects => undef,
        } );
        $got = $ph->replace;
        is( $got, $test->{expected},
            "got expected replacement: '${got}' when passing 'string' and 'undef' for all other arguments" );
    }
}

=head2 test_passing_missing_and_undef_args

Test passing missing Arguments and Arguments that are set to 'undef'
and that the expected errors are thrown.

=cut

sub test_passing_missing_and_undef_args : Tests() {
    my $self    = shift;

    my $objects_arr = [
        $self->order,
        $self->customer,
    ];

    my %tests   = (
        "SC Place Holder" => {
            string          => 'P[SC.Group.Setting]',
            expected_error  => qr/attribute.*\(schema\)/i,
        },
        "SC Channelised Place Holder" => {
            string          => 'P[SC.Public::Table.field,field=value:channel]',
            expected_error  => qr/Can't.*Sales Channel/i,
        },
        "LUT Place Holder" => {
            string          => 'P[LUT.Public::Table.field,field=value]',
            expected_error  => qr/attribute.*\(schema\)/i,
        },
        "LUT Channelised Place Holder" => {
            string          => 'P[LUT.Public::Table.field,field=value:channel]',
            expected_error  => qr/Can't.*Sales Channel/i
        },
        "SMC Place Holder" => {
            string          => 'P[SMC.Public::Table.field]',
            expected_error  => qr/attribute.*\(objects\)/i,
        },
        "AMC Place Holder" => {
            string          => 'P[AMC.Fake::Object.array_test(test)]',
            expected_error  => qr/attribute.*\(objects\)/i,
        },
    );

    foreach  my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        my $expected_error  = $test->{expected_error};

        throws_ok {
            my $ph = XT::Text::PlaceHolder->new( {
                string  => $test->{string},
            } );
            $ph->replace;
        }
        qr/${expected_error}/,
        "got Expected Error when passed NO arguments";
        note "Error Thrown: '${@}'";

        throws_ok {
            my $ph = XT::Text::PlaceHolder->new( {
                string  => $test->{string},
                schema  => undef,
                channel => undef,
                objects => undef,
            } );
            $ph->replace;
        }
        qr/${expected_error}/,
        "got Expected Error when passed 'undef' for arguments";
        note "Error Thrown: '${@}'";
    }
}

sub test_amc_placeholder_with_fraudlist : Tests() {
    my $self = shift;

    my $data_obj = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::FraudList',
        ],
    );

    my $list = $data_obj->fraud_list;
    isa_ok( $list, 'XTracker::Schema::Result::Fraud::StagingList');

    # evaluate placeholder
    my $objects_arr = [
        $self->order,
        $self->customer,
        $list->result_source->resultset,
    ];

    my $list_id = $list->id;
    my $items = $list->discard_changes->all_list_items;

    my $ph = XT::Text::PlaceHolder->new( {
        string  => "P[AMC.XTracker::Schema::ResultSet::Fraud::StagingList.values_by_list_id($list_id)]",
        schema  => $self->{schema},
        channel => undef,
        objects => $objects_arr,
    } );

    my $got = JSON->new->decode($ph->replace);

    cmp_deeply( $got, bag( @{ $items } ), "List values correctly returned by placeholder" );
}

#-------------------------------------------------------------------------

sub data {
    my $self    = shift;
    return $self->{data};
}

sub channel {
    my $self    = shift;
    return $self->{channel};
}

sub order {
    my $self    = shift;
    return $self->{order};
}

sub customer {
    my $self    = shift;
    return $self->{customer};
}

# create test data for Place Holders
sub _create_test_data {
    my ( $self, $test_data )    = @_;

    my $config  = \%XTracker::Config::Local::config;

    foreach my $data ( @{ $test_data } ) {
        given ( $data->{type} ) {
            when ('SystemConfig') {
                Test::XTracker::Data->remove_config_group( $data->{group}, $data->{channel} );
                Test::XTracker::Data->create_config_group( $data->{group}, {
                    ( $data->{channel} ? ( channel => $data->{channel} ) : () ),
                    settings => $data->{settings},
                } );
            }
            when ('Config') {
                my $config_section  = '';
                $config_section     = '_' . $data->{channel}->business->config_section
                                                if ( $data->{channel} );
                $config->{ $data->{section} . $config_section }{ $data->{setting} } = $data->{value};
            }
            when ('Table') {
                my $id  = $self->rs( $data->{class} )->get_column('id')->max() // 0;
                $id++;
                $self->rs( $data->{class} )->create( { id => $id, %{ $data->{args} } } );
            }
        }
    }

    return;
}

# This is used to test the Advanced Method Call with an object we have
# complete control over.

package Fake::Object; ## no critic(ProhibitMultiplePackages)
use Moose;

sub array_test    { shift and return @_               }
sub arrayref_test { shift and return [ @_ ]           }
sub hashref_test  { shift and return { in => [ @_ ] } }
