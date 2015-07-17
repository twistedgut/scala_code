package Test::XTracker::Script::Customer::OutOfDateCustomerValue;
use NAP::policy qw( test class );

BEGIN {
    extends 'NAP::Test::Class';
    with    'Test::Role::WithSchema';
};

=head1 NAME

Test::XTracker::Script::Customer::OutOfDateCustomerValue

=head1 DESCRIPTION

Test the L<Test::XTracker::Script::Customer::OutOfDateCustomerValue> class.

=cut

use XTracker::Constants::FromDB ':storage_type';
use Test::Output;
use Test::XTracker::Data;

=head1 BEFORE ALL TESTS (STARTUP)

Ensure all the required classes are available and set some defaults.

=cut

sub test__startup : Tests( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    use_ok 'XTracker::Script::Customer::OutOfDateCustomerValue';
    use_ok 'XTracker::Schema::Result::Public::CustomerServiceAttributeLog';
    use_ok 'XTracker::Schema::Result::Public::ServiceAttributeType';

    $self->{valid_type} = 'Customer Value';

}

=head1 BEFORE EACH TEST (SETUP)

Start a transaction, clear all the tables we'll be using so they're empty and
insert only known data.

=cut

sub test__setup : Tests( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;

    $self->{db_now} = $self->schema->db_now;

    $self->schema->resultset('Public::CustomerServiceAttributeLog')->delete;
    $self->schema->resultset('Public::ServiceAttributeType')->delete;
    # remove all Account URNs of all Customers, so that they can be set by this test
    $self->schema->resultset('Public::Customer')->update( { account_urn => undef } );
    $self->create_service_attribute_type( $self->valid_type );

}

=head1 AFTER EACH TEST (TEARDOWN)

Rollback the transaction.

=cut

sub test__teardown : Tests( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_rollback;

}

=head1 TESTS

=head2 test__instantiation__no_options

Make sure that the object is instantiated with all the correct default
attribute values.

=cut

sub test__instantiation__no_options : Tests {
    my $self = shift;

    throws_ok( sub { $self->new_object },
        qr/You must provide either the 'days' option, or at least one of 'start-date' or 'end-date'./,
        'Got the correct error when no options where provided' );

}

=head2 test__instantiation__defaults

Check that when the object is instantiated with non-default specific values,
the attributes are set correctly.

=cut

sub test__instantiation__defaults : Tests {
    my $self = shift;

    my $object = $self->new_object( {
        # We have to pass some kind of date range.
        days => 10,
    } );

    cmp_deeply( $object,
        methods(
            verbose             => 0,
            include_never_sent  => 0,
            type                => $self->{valid_type},
        ),
        'The object has been instantiated with the correct defaults' );

}

=head2 test__instantiation__both_days_and_dates

Make sure that the object is instantiated with all the correct default
attribute values.

=cut

sub test__instantiation__both_days_and_dates : Tests {
    my $self = shift;

    my $options = {
        'start-date'    => $self->start_date,
        'end-date'      => $self->end_date,
        'days'          => 10,
    };

    throws_ok( sub { $self->new_object( $options ) },
        qr/The 'days' option cannot be used with start and end dates/,
        'Got the correct error when both days and dates were provided' );

}

=head2 test__instantiation__different_time_zones

Make sure that the object is instantiated with all the correct default
attribute values.

=cut

sub test__instantiation__different_time_zones : Tests {
    my $self = shift;

    my $options = {
        'start-date'    => $self->start_date->set_time_zone('+08:00'),
        'end-date'      => $self->end_date->set_time_zone('+09:00'),
    };

    throws_ok( sub { $self->new_object( $options ) },
        qr/The start date time zone \(.*\) must be the same as the end date time zone \(.*\)/,
        'Got the correct error when the time zones are different' );

}

=head2 test__instantiation__zero_days

Make sure that the object is instantiated with all the correct default
attribute values.

=cut

sub test__instantiation__zero_days : Tests {
    my $self = shift;

    my $options = {
        days    => 0,
    };

    throws_ok( sub { $self->new_object( $options ) },
        qr/The number of days must be greater than zero/,
        'Got the correct error when zero days is given' );

}

=head2 test__instantiation__invalid_date_format

Make sure that the object is instantiated with all the correct default
attribute values.

=cut

sub test__instantiation__invalid_date_format : Tests {
    my $self = shift;

    my $options = {
        'start-date'    => 'INVALID DATE',
        'end-date'      => 'INVALID DATE',
    };

    throws_ok( sub { $self->new_object( $options ) },
        qr/Unrecognised or invalid date format 'INVALID DATE', it must be a valid ISO8601 format/,
        'Got the correct error when the date format is invalid' );

}

=head2 test__instantiation__specific_values__date_range

Check that when the object is instantiated with non-default specific values,
the attributes are set correctly.

=cut

sub test__instantiation__specific_values__date_range : Tests {
    my $self = shift;

    $self->create_service_attribute_type( 'TESTING TESTING' );

    my $object = $self->new_object( {
        'verbose'               => 1,
        'start-date'            => $self->start_date,
        'end-date'              => $self->end_date,
        'include-never-sent'    => 1,
        'type'                  => 'TESTING TESTING',
    } );

    ok( ! $object->has_days,
        'When dates are used, the object does not have days set' );

    cmp_deeply( $object,
        methods(
            verbose             => 1,
            start_date          => $self->start_date,
            end_date            => $self->end_date,
            include_never_sent  => 1,
            type                => 'TESTING TESTING',
        ),
        'The object has been instantiated with the correct date range' );

}

=head2 test__instantiation__specific_values__days

Check that when the object is instantiated with non-default specific values,
the attributes are set correctly.

=cut

sub test__instantiation__specific_values__days : Tests {
    my $self = shift;

    $self->create_service_attribute_type( 'TESTING TESTING' );

    my $object = $self->new_object( {
        'verbose'               => 1,
        'days'                  => 10,
        'include-never-sent'    => 1,
        'type'                  => 'TESTING TESTING',
    } );

    ok( ! $object->has_start_date,
        'When days are used, the object does not have a start date' );

    ok( ! $object->has_end_date,
        'When days are used, the object does not have an end date' );

    cmp_deeply( $object,
        methods(
            verbose             => 1,
            days                => 10,
            include_never_sent  => 1,
            type                => 'TESTING TESTING',
        ),
        'The object has been instantiated with the correct days' );

}

=head2 test__instantiation__string_dates__no_timezone

Enusre that when using strings for the two date attributes (start-date and
end-date), they are correctly coerced into L<DateTime> objects

=cut

sub test__instantiation__string_dates__no_timezone : Tests {
    my $self = shift;

    my $object = $self->new_object( {
        'start-date'    => $self->start_date->iso8601,
        'end-date'      => $self->end_date->iso8601,
    } );

    cmp_ok( $object->start_date->time_zone_long_name,
        'eq',
        $self->start_date->set_time_zone('local')->time_zone_long_name,
        'The start date time zone is correct' );

    cmp_ok( $object->end_date->time_zone_long_name,
        'eq',
        $self->end_date->set_time_zone('local')->time_zone_long_name,
        'The end date time zone is correct' );

    cmp_ok( $object->start_date->iso8601,
        'eq',
        $self->start_date->iso8601,
        'The start date matches' );

    cmp_ok( $object->end_date->iso8601,
        'eq',
        $self->end_date->iso8601,
        'The end date matches' );

}

=head2 test__instantiation__string_dates__with_timezone

Enusre that when using strings for the two date attributes (start-date and
end-date), they are correctly coerced into L<DateTime> objects

=cut

sub test__instantiation__string_dates__with_timezone : Tests {
    my $self = shift;

    my $object = $self->new_object( {
        'start-date'    => $self->start_date->iso8601 . '+08:00',
        'end-date'      => $self->end_date->iso8601   . '+08:00',
    } );

    cmp_ok( $object->start_date->time_zone_long_name,
        'eq',
        $self->start_date->set_time_zone('+08:00')->time_zone_long_name,
        'The start date time zone is correct' );

    cmp_ok( $object->end_date->time_zone_long_name,
        'eq',
        $self->end_date->set_time_zone('+08:00')->time_zone_long_name,
        'The end date time zone is correct' );

    cmp_ok( $object->start_date->iso8601,
        'eq',
        $self->start_date->iso8601,
        'The start date matches' );

    cmp_ok( $object->end_date->iso8601,
        'eq',
        $self->end_date->iso8601,
        'The end date matches' );

}

=head2 test__invoke__unable_to_determine_searh_criteria

Make sure that the object is instantiated with all the correct default
attribute values.

=cut

sub test__invoke__unable_to_determine_searh_criteria : Tests {
    my $self = shift;

    my $object = $self->new_object( {
        days => 10,
    } );

    # This error should be impossible to get, so we have to hack the object
    # to get it.
    $object->clear_days;
    $object->clear_start_date;
    $object->clear_end_date;

    throws_ok( sub { $object->invoke },
        qr/Unable to determine the search criteria, please check your command line options/,
        'Got the correct error when no date attributes are set' );

}

=head2 test__invoke__verbose_true

Test that when verbose is set to TRUE, extra output is proivided.

=cut

sub test__invoke__verbose_true : Tests {
    my $self = shift;

    $self->new_object( {
        verbose => 1,
        days    => 10,
    } );

    output_like(
        sub { $self->invoke_lives_ok },
        qr/Service Attribute Type.*Include Never Sent/s,
        # Ignore STDERR because we will get an error saying there where no
        # records.
        undef,
        'When verbose is TRUE, we get a header printed out' );

}

=head2 test__invoke__verbose_false

Test that when verbose is set to FALSE, extra output is NOT proivided.

=cut

sub test__invoke__verbose_false : Tests {
    my $self = shift;

    $self->new_object( {
        verbose => 0,
        days    => 10,
    } );

    output_is(
        sub { $self->invoke_lives_ok },
        '',
        # Ignore STDERR because we will get an error saying there where no
        # records.
        undef,
        'When verbose is FALSE, no header is printed out' );

}

=head2 test__invoke__invalid_date_range

Test that when we pass invalid dates, we get the correct errors. The two
scenarios where these errors occur are:

1) The start date comes after the end date.
2) The start and end dates are the same.

=cut

sub test__invoke__invalid_date_range : Tests {
    my $self = shift;

    throws_ok( sub {
        $self->new_object( {
            'start-date'    => $self->end_date,
            'end-date'      => $self->start_date,
        } );
    }, qr/The start date must come before the end date/,
    'Got the correct exception for dates the wrong way round.' );

    throws_ok( sub {
        $self->new_object( {
            'start-date'    => $self->end_date,
            'end-date'      => $self->end_date,
        } );
    }, qr/The start date must be different from the end date/,
    'Got the correct exception for the start/end dates being the same.' );

}

=head2 test__invoke__valid_date_range

Test that with a valid date range, we get the correct account URNs and no
errors occur.

=cut

sub test__invoke__valid_date_range : Tests {
    my $self = shift;

    $self->create_common_test_data;

    my $object = $self->new_object( {
        'start-date'    => $self->db_now->subtract( days => 7 ),
        'end-date'      => $self->db_now->subtract( days => 1 ),
    } );

    output_is(
        sub { $self->invoke_lives_ok },
        "test:urn:one\ntest:urn:two\n",
        '',
        'With existing log entries and a valid date range, the output is correct' );

}


sub test__invoke__valid_date_range_including_never_sent : Tests {
    my $self = shift;

    $self->create_common_test_data;

    my $object = $self->new_object( {
        'start-date'            => $self->db_now->subtract( days => 7 ),
        'end-date'              => $self->db_now->subtract( days => 1 ),
        'include-never-sent'    => 1,
    } );

    output_is(
        sub { $self->invoke_lives_ok },
        "test:urn:never_sent\ntest:urn:one\ntest:urn:two\n",
        '',
        'With existing log entries, a valid date range and include-never-sent, the output is correct' );

}


=head2 test__invoke__valid_date_range_with_no_records

Test that with a valid date and no records in that range, we get no results
and the correct error message.

=cut

sub test__invoke__valid_date_range_with_no_records : Tests {
    my $self = shift;

    my $object = $self->new_object( {
        'verbose'       => 1,
        'start-date'    => $self->db_now->subtract( days => 7 ),
        'end-date'      => $self->db_now->subtract( days => 1 ),
    } );

    output_like(
        sub { $self->invoke_lives_ok },
        qr/No matching records found/,
        qr/\A\Z/,
        'With no log entries and a valid date range, the correct output is shown' );

}

=head2 test__invoke__invalid_type

Test that when we pass an invalid Service Attribute Type, we get the correct
error.

=cut

sub test__invoke__invalid_type : Tests {
    my $self = shift;

    throws_ok( sub {
        $self->new_object( {
            type    => 'Non Existent Type',
            days    => 10,
        } );
    }, qr/The service attribute type 'Non Existent Type' does not exist/,
    'Got the correct error for a non-existent type' );

}

=head2 test__invoke__valid_type

Test that the object can be instantiated with a valid type and doesn't throw
any exceptions.

=cut

sub test__invoke__valid_type : Tests {
    my $self = shift;

    lives_ok( sub {
        $self->new_object( {
            type    => $self->valid_type,
            days    => 10,
        } );
    },
    'Object instantiation lives with a valid type' );

}

=head2 test__invoke__valid_days

Test that with a valid number of days passed to C<days>, we get the correct
output.

=cut

sub test__invoke__valid_days : Tests {
    my $self = shift;

    $self->create_common_test_data;

    my $object = $self->new_object( {
        days => 5,
    } );

    output_is(
        sub { $self->invoke_lives_ok },
        "test:urn:before\ntest:urn:one\n",
        '',
        'With existing log entries and a valid number of days, the output is correct' );

}

=head2 test__invoke__valid_days_including_never_sent

Test that with a valid number of days passed to C<days> and with the
'include-never-sent' option, we get the correct output.

=cut

sub test__invoke__valid_days_including_never_sent : Tests {
    my $self = shift;

    $self->create_common_test_data;

    my $object = $self->new_object( {
        'days'                  => 5,
        'include-never-sent'    => 1,
    } );

    output_is(
        sub { $self->invoke_lives_ok },
        "test:urn:before\ntest:urn:never_sent\ntest:urn:one\n",
        '',
        'With existing log entries, a valid number of days and include-never-sent, the output is correct' );


}

=head2 test__invoke__valid_days_with_no_records

Test that with a valid number of days passed to C<days> and no log rescords
present, we get the correct output.

=cut

sub test__invoke__valid_days_with_no_records : Tests {
    my $self = shift;

    $self->create_common_test_data;

    my $object = $self->new_object( {
        'verbose'   => 1,
        'days'      => 9,
    } );

    output_like(
        sub { $self->invoke_lives_ok },
        qr/No matching records found/,
        qr/\A\Z/,
        'With no log entries and a valid number of days, the correct output is shown' );

}

=head1 METHODS

=head2 new_object( @options )

Instantiate a new instance of an L<XTracker::Script::Customer::OutOfDateCustomerValue>
object, check it has all the requried methods and the date attributes are L<DateTime>
objects. Returns the newly instantiated object (also stores it internally for other
methods to use).

The C<@options> are passed directly to the C<new_with_options> method on the class.

    my $object = $self->new_object(
        ...
    );

=cut

sub new_object {
    my ($self,  @options ) = @_;

    $self->{object} = XTracker::Script::Customer::OutOfDateCustomerValue
        ->new_with_options( @options );

    isa_ok( $self->{object},
        'XTracker::Script::Customer::OutOfDateCustomerValue',
        'The object instantiated using new_with_options' );

    can_ok( $self->{object} => qw(
        verbose
        start_date
        end_date
        type
        invoke
    ) );

    isa_ok( $self->{object}->start_date, 'DateTime', 'start_date method return value' )
        if $self->{object}->has_start_date;

    isa_ok( $self->{object}->end_date, 'DateTime', 'end_date method return value' )
        if $self->{object}->has_end_date;

    return $self->{object};

}

=head2 invoke_lives_ok

Call the C<invoke> method and make sure it doesn't die.

    $self->invoke_lives_ok;

=cut

sub invoke_lives_ok {
    my $self = shift;

    lives_ok(
        sub { $self->{object}->invoke },
        'Calling the invoke method lives ok' );

}

=head2 create_service_attribute_type( $type )

Create a new C<Public::ServiceAttributeType> record of C<$type>. Returns the
newly created record.

    my $record = $self->create_service_attribute_type('Customer Value');

=cut

sub create_service_attribute_type {
    my ($self,  $type ) = @_;

    return $self->schema->resultset('Public::ServiceAttributeType')->create( {
        type => $type,
    } );

}

=head2 create_customer( $arguments )

Create a test customer. The C<$arguments> are a HashRef that is passed
directly through to the L<Test::XTracker::Data> method C<create_test_customer>.

=cut

sub create_customer {
    my ($self,  $arguments ) = @_;

    return Test::XTracker::Data->create_test_customer(
        channel_id => Test::XTracker::Data->get_local_channel->id,
        ref( $arguments ) eq 'HASH' ? %$arguments : (),
    );

}

=head2 create_customer_service_attribute_log

Create a new C<Public::CustomerServiceAttributeLog> and related C<Public::Customer>
record. Returns the newly created record.

Accepts a HashRef of the following arguments:

last_sent               The C<Public::CustomerServiceAttributeLog> last_sent field.
service_attribute_type  The related C<Public::ServiceAttributeType> C<type> field.
customer                A HashRef that is passed to the L<Test::XTracker::Data>
                        C<create_test_customer> method.

    my $record = $self->create_customer_service_attribute_log( {
        last_sent               => DateTime->now,
        service_attribute_type  => 'Customer Value',
        customer                => {
            ...
        },
    } );

=cut

sub create_customer_service_attribute_log {
    my ($self,  $arguments ) = @_;

    $arguments = {
        last_sent               => $self->db_now,
        service_attribute_type  => $self->valid_type,
        customer                => {},
        ref( $arguments ) eq 'HASH' ? %$arguments : (),
    };

    return $self->schema->resultset('Public::CustomerServiceAttributeLog')->create( {
        customer_id             => $self->create_customer( $arguments->{customer} ),
        service_attribute_type  => { type => $arguments->{service_attribute_type} },
        last_sent               => $arguments->{last_sent},
    } );

}

=head2 create_common_test_data

Create some test data.

    $self->create_common_test_data;

=cut

sub create_common_test_data {
    my $self = shift;

    # Create a log entry before the date range.
    $self->create_customer_service_attribute_log( {
        last_sent   => $self->db_now->subtract( days => 8 ),
        customer    => { account_urn => 'test:urn:before' } } );

    # Create a log entry that will be included in the date range.
    $self->create_customer_service_attribute_log( {
        last_sent   => $self->db_now->subtract( days => 6 ),
        customer    => { account_urn => 'test:urn:one' } } );

    # Create another log entry that will be included in the date range.
    $self->create_customer_service_attribute_log( {
        last_sent   => $self->db_now->subtract( days => 2 ),
        customer    => { account_urn => 'test:urn:two' } } );

    # Create a log entry that will be included in the date range, but has no
    # URN.
    $self->create_customer_service_attribute_log( {
        last_sent   => $self->db_now->subtract( days => 2 ),
        customer    => { account_urn => undef } } );

    # Create another log entry that will be included in the date range, but
    # is for another service attribute type.
    $self->create_customer_service_attribute_log( {
        service_attribute_type  => $self->create_service_attribute_type('IGNORE')->type,
        last_sent               => $self->db_now->subtract( days => 2 ),
        customer                => { account_urn => 'test:urn:different_type' } } );

    # Create a log entry after the date range.
    $self->create_customer_service_attribute_log( {
        last_sent   => $self->db_now,
        customer    => { account_urn => 'test:urn:after' } } );

    # Create a customer that was never sent.
    $self->create_customer( {
        account_urn => 'test:urn:never_sent'
    } );

}

=head1 db_now

The current database concept of 'now'.

=cut

sub db_now {
    my $self = shift;
    return $self->{db_now}->clone;
}

=head1 start_date

Return the result of calling C<db_now> with 2 weeks subtracted.

=cut

sub start_date {
    my $self = shift;
    return $self->{db_now}->clone->subtract( weeks => 2 );
}

=head1 end_date

Return the result of calling C<db_now> with 1 week subtracted.

=cut

sub end_date {
    my $self = shift;
    return $self->{db_now}->clone->subtract( weeks => 1 );
}

=head1 valid_type

Returns the Service Attribute Type name that was created in SETUP.

=cut

sub valid_type {
    my $self = shift;
    return $self->{valid_type};
}

Test::Class->runtests;
