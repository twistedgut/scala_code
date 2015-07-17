package Test::XT::DC::Messaging::Consumer::OnlineFraud;
use NAP::policy "tt",     'test';

use parent "NAP::Test::Class";

=head1 NAME

Test::XT::DC::Messaging::Consumer::OnlineFraud

=head1 DESCRIPTION

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];

use XTracker::Config::Local         qw( config_var get_config_sections );
use Test::XTracker::MessageQueue;
use String::Random;


# this is done once, when the test starts
sub startup : Test( startup => 1 ) {
    my $self = shift;
    $self->SUPER::startup;

    ($self->{amq},$self->{consumer}) = Test::XTracker::MessageQueue->new_with_app;
    $self->{queue}  = Test::XTracker::Config->messaging_config->{'Consumer::OnlineFraud'}{routes_map}{destination};

    $self->{schema} = Test::XTracker::Data->get_schema;

    $self->{hotlist_rs} = $self->schema->resultset('Public::HotlistValue')->search( {}, { order_by => 'id' } );

    # get This DC and another DC
    my ( $other_dc )    = $self->schema->resultset('Public::DistribCentre')->search( {
        name    => { '!=' => $distribution_centre },
    } )->all;

    $self->{other_dc}   = $other_dc->name;
    $self->{this_dc}    = $distribution_centre;
}

# done everytime before each Test method is run
sub setup: Test(setup) {
    my $self = shift;
    $self->SUPER::setup;

    # clear all messages from the topic
    $self->amq->clear_destination( $self->{queue} );

    # clear out all current data
    $self->hotlist_rs->delete;

    # turn on listening for hotlist updates
    XT::DC::Messaging->component('XT::DC::Messaging::Consumer::OnlineFraud')
          ->{listen_for_hotlist_update}   = 'yes';
}

# done everytime after each Test method has run
sub teardown: Test(teardown) {
    my $self    = shift;
    $self->SUPER::teardown;

    $self->amq->clear_destination( $self->{queue} );
}


=head1 TEST METHODS

=head2 test_update_hotlist_payload_validation

This tests that if the 'from_dc' key from the payload is
missing then the payload validation fails.

=cut

sub test_update_hotlist_payload_validation : Tests() {
    my $self    = shift;

    my $data    = $self->_create_data_for_payload( {
        num_to_generate => 3,
    } );

    my $result  = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { from_dc => undef, records => $data } ),
    );
    ok( $result->is_error, "Message was NOT Consumed, when 'from_dc' is undef" );
    cmp_ok( $self->hotlist_rs->count, '==', 0, "NO records were created" );

    $result = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { from_dc => '', records => $data } ),
    );
    ok( $result->is_error, "Message was NOT Consumed, when 'from_dc' is empty" );
    cmp_ok( $self->hotlist_rs->count, '==', 0, "NO records were created" );
}

=head2 test_update_hotlist_with_unknown_action

Tests that when there is an unknown option in the 'action' argument
for the 'records' part of the payload, nothing happens.

=cut

sub test_update_hotlist_with_unknown_action : Tests() {
    my $self    = shift;

    my $data    = $self->_create_data_for_payload( {
        num_to_generate => 1,
    } );
    $data->[0]{action}  = 'unknown';

    my $result  = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok( $self->hotlist_rs->count, '==', 0, "NO records were created" );
}

=head2 test_update_hotlist_when_not_listening

Tests that when configured for NOT listening to Hotlist Value updates then NO records are created.

=cut

sub test_update_hotlist_when_not_listening : Tests() {
    my $self    = shift;

    my $data    = $self->_create_data_for_payload( {
        num_to_generate => 1,
    } );

    # turn off listening in the configuration
    XT::DC::Messaging->component('XT::DC::Messaging::Consumer::OnlineFraud')
          ->{listen_for_hotlist_update}   = 'no';

    my $result  = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok( $self->hotlist_rs->count, '==', 0, "NO records were created" );
}

=head2 test_add_data_to_hotlist

This tests that the Consumer will update the 'hotlist_value' table with new values.

=cut

sub test_add_data_to_hotlist : Tests() {
    my $self    = shift;

    my $num_to_generate = 41;
    my $data    = $self->_create_data_for_payload( {
        num_to_generate => $num_to_generate,
    } );

    my $result  = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok( $self->hotlist_rs->count, '==', $num_to_generate, "${num_to_generate} records have been created" );

    my $expect  = $self->_get_expected_data( $data );
    my $got     = $self->_xform_data_for_testing();
    is_deeply( $got, $expect, "and the data is as expected" );
}

=head2 test_add_data_to_hotlist_from_same_dc

This tests that when a Consumer consumes a message that its DC generates then NOTHING gets updated.

=cut

sub test_add_data_to_hotlist_from_same_dc : Tests() {
    my $self    = shift;

    my $data    = $self->_create_data_for_payload( {
        num_to_generate => 5,
    } );

    my $result  = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( {
            from_dc => $self->{this_dc},
            records => $data,
        } )
    );
    ok( $result->is_success, "Consumed Message ok" );

    cmp_ok( $self->hotlist_rs->count, '==', 0, "NO records were added" );
}

=head2 test_add_duplicate_hotlist_data

This tests that when adding Duplicate data for the Fraud Hot Lists that it is
not inserted into the table and the Consumer doesn't crash.

=cut

sub test_add_duplicate_hotlist_data : Tests() {
    my $self    = shift;

    note "add some new Data first all should be created";

    my $num_to_generate1 = 3;
    my $data1   = $self->_create_data_for_payload( {
        num_to_generate => $num_to_generate1,
    } );

    my $result  = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data1 } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok( $self->hotlist_rs->count, '==', $num_to_generate1, "${num_to_generate1} records have been created" );

    my $expect  = $self->_get_expected_data( $data1 );
    my $got     = $self->_xform_data_for_testing();
    is_deeply( $got, $expect, "and the data is as expected" );

    note "now add some more data some of which would be duplicates";

    my $num_to_generate2 = 5;
    my $total_generated  = $num_to_generate1 + $num_to_generate2;
    my $data2   = $self->_create_data_for_payload( {
        num_to_generate => $num_to_generate2,
    } );
    # put the new data in with the old
    $data2  = [ @{ $data1 }, @{ $data2} ];

    $result = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data2 } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok(
        $self->hotlist_rs->count,
        '==',
        $total_generated,
        $total_generated . " records were sent to the Consumer but only ${num_to_generate2} have been added"
    );

    $expect = $self->_get_expected_data( $data2 );
    $got    = $self->_xform_data_for_testing();
    is_deeply( $got, $expect, "and all the data is as expected" );
}

=head2 test_add_duplicate_with_null_order_numbers

This will test that when adding duplicate entries with 'NULL' as Order Number or with Empty Strings that
all are considered a duplicate and only one is created.

=cut

sub test_add_duplicate_with_null_order_numbers : Tests() {
    my $self    = shift;

    # just get a piece of data
    my $data    = $self->_create_data_for_payload( {
        num_to_generate => 1,
    } );

    note "Start with NULL then an Empty String duplicate";
    delete $data->[0]{order_number};        # make the first one a 'NULL' order number
    push @{ $data }, { %{ $data->[0] } };   # now clone the first to be the second entry
    $data->[1]{order_number}    = '';       # and make the second entry have an empty string

    my $result  = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok(
        $self->hotlist_rs->count,
        '==',
        1,
        "Only 1 record was inserted",
    );

    note "now with an Empty String then a NULL duplicate";
    $self->hotlist_rs->delete;              # clear out previous records
    push @{ $data }, shift @{ $data };      # swap first to last

    $result = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok(
        $self->hotlist_rs->count,
        '==',
        1,
        "Only 1 record was inserted",
    );
}

=head2 test_just_add_one_hotlist_value

This tests that just adding one new value on its own still works.

=cut

sub test_just_add_one_hotlist_value : Tests() {
    my $self    = shift;

    my $data    = $self->_create_data_for_payload( {
        num_to_generate => 1,
    } );

    my $result  = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok( $self->hotlist_rs->count, '==', 1, "1 record has been created" );

    my $expect  = $self->_get_expected_data( $data );
    my $got     = $self->_xform_data_for_testing();
    is_deeply( $got, $expect, "and the data is as expected" );

    note "now add it again to check that it doesn't duplicate";

    $result = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok( $self->hotlist_rs->count, '==', 1, "still only 1 record has been created" );
}

=head2 test_add_already_prefixed_order_numbers

This tests that when adding records with already prefixed Order Numbers
such as 'DC2: 2342342' that the prefixed isn't added again.

=cut

sub test_add_already_prefixed_order_numbers : Tests() {
    my $self    = shift;

    my $num_to_generate = 17;
    my $data    = $self->_create_data_for_payload( {
        num_to_generate => $num_to_generate,
        generate_previous_sync_order_numbers => 1,
    } );

    my $result  = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok( $self->hotlist_rs->count, '==', $num_to_generate, "${num_to_generate} records have been created" );

    my $expect  = $self->_get_expected_data( $data );
    my $got     = $self->_xform_data_for_testing();
    is_deeply( $got, $expect, "and the data is as expected" );

    note "now add them again to check that they don't duplicate";

    # go through each normal Order Number in the list and
    # add this DCs prefix then check it doesn't duplicate
    foreach my $row ( @{ $data } ) {
        if ( $row->{order_number} =~ m/^\d+$/ ) {
            $row->{order_number}    = $self->{other_dc} . ': ' . $row->{order_number};
        }
    }

    $result = $self->{amq}->request(
        $self->{consumer},
        $self->{queue},
        $self->_payload_and_header( { records => $data } ),
    );
    ok( $result->is_success, "Consumed Message ok" );
    cmp_ok( $self->hotlist_rs->count, '==', $num_to_generate, "still only ${num_to_generate} records have been created" );
}

#-----------------------------------------------------------------------------------------

# create 'records' part of the payload
sub _create_data_for_payload {
    my ( $self, $args )     = @_;

    my $rstring = String::Random->new();

    my @fields  = $self->schema->resultset('Public::HotlistField')->all;
    my @channels= $self->schema->resultset('Public::Channel')->all;

    my @data;
    my $num_to_generate = $args->{num_to_generate};

    foreach my $counter ( 1..$num_to_generate ) {
        my $channel = shift @channels;
        my $field   = shift @fields;

        my $order_nr;
        if ( !$args->{generate_previous_sync_order_numbers} ) {
            # generate a value for the 'order_nr' field
            # make sure it covers being 'undef', empty
            # with just a number and with a prefix
            if ( $counter % 4 ) {
                $order_nr= ( $counter % 3 ? 'PRFX ' : '' );
                $order_nr   .= $counter * 1235;
            }
            elsif ( $counter % 3 ) {
                $order_nr   = '';
            }
        }
        else {
            # generate order numbers with already 'DCX: '
            # in front of it to make sure that prefix is
            # not repeated when synced accross
            if ( $counter % 2 ) {
                $order_nr   = 'DC9: 12313445';
            }
            else {
                $order_nr   = '123123123';
            }
        }

        push @channels, $channel;
        push @fields, $field;

        push @data, {
            action                  => 'add',
            hotlist_field_name      => $field->field,
            channel_config_section  => $channel->business->config_section,
            value                   => $rstring->randregex( '\w' x 37 ),
            # only pass 'order_number' if it's defined
            ( defined $order_nr ? ( order_number => $order_nr ) : () ),
        };
    }

    return \@data;
}

# get data from the 'hotlist_value' table and
# transform it so that it can be compared for tests
sub _xform_data_for_testing {
    my $self    = shift;

    my @data    = map {
        {
            hotlist_field_name      => $_->hotlist_field->field,
            channel_config_section  => $_->channel->business->config_section,
            value                   => $_->value,
            order_number            => $_->order_nr,
        }
    } $self->hotlist_rs->all;

    return \@data;
}

# prefix all the order numbers with 'DC?: ' to show they
# have come from another DC, used in comparison tests and
# any other things to make testing for expected data easier
sub _get_expected_data {
    my ( $self, $data ) = @_;

    my @rows;
    foreach my $row ( @{ $data } ) {
        my %new_row = %{ $row };
        $new_row{order_number}  = (
            # check it has a value and doesn't already have the 'DC' prefix
            $new_row{order_number} && $new_row{order_number} !~ m/^DC\d+: /
            ? $self->{other_dc} . ': ' . $new_row{order_number}
            : $new_row{order_number}
        );
        delete $new_row{action};
        push @rows, \%new_row;
    }

    return \@rows;
}

sub _payload_and_header {
    my ( $self, $data ) = @_;

    return {
        from_dc => $self->{other_dc},
        %{ $data },
    },{
        'type' => 'update_fraud_hotlist',
    };
}

sub amq {
    my $self    = shift;
    return $self->{amq};
}

sub schema {
    my $self    = shift;
    return $self->{schema};
}

sub hotlist_rs {
    my $self    = shift;
    return $self->{hotlist_rs}->reset;
}
