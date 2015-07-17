package XTracker::Script::Customer::OutOfDateCustomerValue;
use NAP::policy qw( class tt );

extends 'XT::Common::Script';
with 'MooseX::Getopt';
with 'XTracker::Script::Feature::Schema';
with 'XTracker::Script::Feature::Logger';

use DateTime::Format::ISO8601;
use Moose::Util::TypeConstraints;

=head1 NAME

XTracker::Script::Customer::OutOfDateCustomerValue

=head1 DESCRIPTION

Generate a list of Account URNs that have either never been sent to a service,
or where last sent within a given date range to a specific service.

=head1 SYNOPSIS

    XTracker::Script::Customer::OutOfDateCustomerValue
        ->new_with_options
        ->invoke;

Example usage of script:

On it's own, all defaults will be used and URNs will be listed for all
customers (but URNs never sent before will not be included).

    script.pl

With a date range, URNs will be listed for all customers that where last sent
to the service in that date range (again, URNs never sent before will not be
included).

    script.pl --start-date <date> --end-date <date>

With a date range and the include-never-sent option, the same as above will
happen, but URNs never sent before WILL be included.

    script.pl --start-date <date> --end-date <date> --include-never-sent

To get all out of date URNs before a certain date, including those never sent
before, use the following (note we ommit the start date):

    script.pl --end-date <date> --include-never-sent

=cut

    # Set all the attributes that we've either inherited or consumed, to not be
    # exposed as an argument.
    has "+$_" => ( traits => ['NoGetopt'] )
        foreach _no_get_opt_list();

=head1 DATATYPES

=head2 DateTime::ISO8601

Extends L<DateTime> by adding coercion from a string using
L<DateTime::Format::ISO8601>.

=cut

subtype 'DateTime::ISO8601'
    => as 'DateTime';

coerce 'DateTime::ISO8601'
    => from 'Str'
    => via { _date_coercion_from_iso8601( $_ ) };

MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
    'DateTime::ISO8601' => '=s' );

=head1 ATTRIBUTES/ARGUMENTS

=head2 verbose [optional] <boolean>

Provide additional output, defaults to false.

=cut

has verbose => (
    is              => 'ro',
    isa             => 'Bool',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 'v',
    documentation   => 'Provide verbose output (default: No).',
    default         => 0,
);

=head2 start-date [optional] <DateTime::ISO8601>

The start date range. The accessor method for this attribute is C<start_date>.

=cut

has 'start-date' => (
    is              => 'ro',
    isa             => 'DateTime::ISO8601',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 's',
    documentation   => 'The date to start from (default: The epoch, as defined in "perldoc Datetime").',
    coerce          => 1,
    reader          => 'start_date',
    writer          => 'set_start_date',
    clearer         => 'clear_start_date',
    predicate       => 'has_start_date',
);

=head2 end-date [optional] <DateTime::ISO8601>

The end date range. The accessor method for this attribute is C<end_date>.

=cut

has 'end-date' => (
    is              => 'ro',
    isa             => 'DateTime::ISO8601',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 'e',
    documentation   => 'The date to end on (default: Now).',
    coerce          => 1,
    reader          => 'end_date',
    writer          => 'set_end_date',
    clearer         => 'clear_end_date',
    predicate       => 'has_end_date',
);

=head2 days [optional] <integer>

Gets URNs that are older than the number of C<days> given.

=cut

has 'days' => (
    is              => 'ro',
    isa             => 'Int',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 'd',
    documentation   => 'Get URNs last updated longer than X days ago.',
    writer          => 'set_days',
    clearer         => 'clear_days',
    predicate       => 'has_days',
);

=head2 include-never-sent [optional] <boolean>

If this is set to true, customer URNs will be included for customers that
have never been pushed to any service before. Defaults to false.

The accessor method for this attribute is C<include_never_sent>.

=cut

has 'include-never-sent' => (
    is              => 'ro',
    isa             => 'Bool',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 'i',
    documentation   => 'Include customers that have never been pushed to the service before (default: No).',
    default         => 0,
    reader          => 'include_never_sent',
);

=head2 type [optional] <string>

The service attribute type to use, currently defaults to 'Customer Value'.

=cut

has type => (
    is              => 'ro',
    isa             => 'Str',
    traits          => [ 'Getopt' ],
    cmd_aliases     => 't',
    documentation   => 'The service attribute type to use (default: Customer Value).',
    default         => 'Customer Value',
);

sub BUILD {
    my $self = shift;

    $self->_set_option_defaults;
    $self->_validate_option_combinations;
    $self->_validate_dates;
    $self->_validate_type;
    $self->_validate_days;

}

=head1 METHODS

=head2 log4perl_category

Sets the log category to: Script::Customer::OutOfDateCustomerValue

=cut

sub log4perl_category {
    return 'Script::Customer::OutOfDateCustomerValue';
}

=head2 invoke

Run the script.

=cut

sub invoke {
    my $self = shift;

    $self->log_info( '** Script Started **' );

    $self->log_info( 'Service Attribute Type .. ' . $self->type );
    $self->log_info( 'Include Never Sent ...... ' . ( $self->include_never_sent ? 'Yes' : 'No' ) );
    $self->_date_range_display;

    my $customers = $self->schema->resultset('Public::Customer')->search( {
        account_urn => { '!=' => undef },
    } , {
        join        => { 'customer_service_attribute_logs' => 'service_attribute_type' },
        order_by    => 'account_urn',
    } );

    if ( $self->include_never_sent ) {

        $customers = $customers->search( {
            'service_attribute_type.type'   => [ undef, $self->type ],
            -or =>                          => [
                'customer_service_attribute_logs.last_sent' => undef,
                'customer_service_attribute_logs.last_sent' => $self->_date_range_criteria,
            ],
        } );

    } else {

        $customers = $customers->search( {
            'service_attribute_type.type'               => $self->type,
            'customer_service_attribute_logs.last_sent' => $self->_date_range_criteria,
        } );

    }

    my @urn_list =
        map { $_->account_urn }
        $customers->all;

    if ( @urn_list ) {

        $self->log_info( 'Number of Records ....... ' . ( scalar @urn_list ) );
        say join( "\n", @urn_list );

    } else {

        $self->log_error( "No matching records found" );

    }

    $self->log_info( '** Script Finished **' );

    return;

}

=head1 PRIVATE METHODS

=head2 _validate_option_combinations

Check that only the correct combinations of options are present.

=cut

sub _validate_option_combinations {
    my $self = shift;

    die "The 'days' option cannot be used with start and end dates.\n"
        if $self->has_days &&
        (
            $self->has_start_date ||
            $self->has_end_date
        );

    die "You must provide either the 'days' option, or at least one of 'start-date' or 'end-date'.\n"
        unless
            $self->has_start_date ||
            $self->has_end_date ||
            $self->has_days;

}

=head2 _validate_dates

Make sure that the C<start_date> and C<end_date> attributes are not equal and
the C<start_date> comes before the  C<end_date>. Also check the time zone of
each date matches.

=cut

sub _validate_dates {
    my $self = shift;

    return unless
        $self->has_start_date &&
        $self->has_end_date;

    $self->_validate_time_zones;

    die "The start date must come before the end date.\n" if
        $self->start_date > $self->end_date;

    die "The start date must be different from the end date.\n" if
        $self->start_date == $self->end_date;

}

=head2 _validate_time_zones

Make sure the C<start_date> and C<end_date> time zones are the same.

=cut

sub _validate_time_zones {
    my $self = shift;

    return unless
        $self->has_start_date &&
        $self->has_end_date;

    my $start_timezone = $self->start_date->time_zone_long_name;
    my $end_timezone   = $self->end_date->time_zone_long_name;

    die "The start date time zone ($start_timezone) must be the same as the end date time zone ($end_timezone).\n" if
        $start_timezone ne $end_timezone;

}

=head2 _validate_type

Make sure the C<type> attribute exists in the C<Public::ServiceAttributeType>
table.

=cut

sub _validate_type {
    my $self = shift;

    die "The service attribute type '" . $self->type . "' does not exist.\n" unless
        $self->schema->resultset('Public::ServiceAttributeType')
            ->search( { type => $self->type } )
            ->count == 1;

}

=head2 _validate_days

Check the number of C<days> fiven is greater than zero.

=cut

sub _validate_days {
    my $self = shift;

    return unless
        $self->has_days;

    die "The number of days must be greater than zero.\n"
        unless $self->days > 0;

}

=head2 _set_option_defaults

Set the defaults based on what has been passed into the script.

If C<days> has been provided, this will clear both the C<start-date> and
C<end-date>. If only one of the dates is provided, the other will have it's
default set.

=cut

sub _set_option_defaults {
    my $self = shift;

    my $db_now = $self->schema->db_now;

    if ( $self->has_start_date && ! $self->has_end_date ) {
    # If we've been given only the start date, set the end date to a default
    # value.

        $self->set_end_date( $db_now )
            unless $self->has_end_date;

    }

    if ( $self->has_end_date && ! $self->has_start_date ) {
    # If we've been given only the end date, set the start date to a default
    # value.

        $self->set_start_date( DateTime->from_epoch( epoch => 0, time_zone => $db_now->time_zone ) )
            unless $self->has_start_date;

    }

}

=head2 _date_range_criteria

Based on what command line options where given, return a HashRef containing
an appropriate search condition clause.

=cut

sub _date_range_criteria {
    my $self = shift;

    if ( $self->has_days ) {

        return {
            # Use interval multiplication so we can have a bind variable.
            '<' => \[ "( now() - ( interval '1 day' * ?::integer ) )", $self->days ],
        };

    } elsif ( $self->has_start_date && $self->has_end_date ) {

        return {
            -between => [
                $self->schema->storage->datetime_parser->format_datetime( $self->start_date ),
                $self->schema->storage->datetime_parser->format_datetime( $self->end_date ),
            ],
        };

    } else {

        die "Unable to determine the search criteria, please check your command line options.\n";

    }

}

=head2 _date_range_display

Based on what command line options where given, display details about them.

=cut

sub _date_range_display {
    my $self = shift;

    if ( $self->days ) {

        $self->log_info( 'Last Sent More Than ..... ' . $self->days . ' ' . ( $self->days == 1 ? 'day' : 'days' ) . ' ago' );

    } elsif ( $self->start_date && $self->end_date ) {

        my $db_now = $self->schema->db_now;
        my $start  = $self->start_date->clone->set_time_zone( $db_now->time_zone );
        my $end    = $self->end_date->clone->set_time_zone( $db_now->time_zone );

        $self->log_info( 'Service Attribute Type .. ' . $self->type );
        $self->log_info( 'Include Never Sent ...... ' . ( $self->include_never_sent ? 'Yes' : 'No' ) );

        $self->log_info( 'Requested Start Date .... ' . $self->start_date->strftime('%F %T [%Z]') );
        $self->log_info( 'Requested End Date ...... ' . $self->end_date->strftime('%F %T [%Z]') );
        $self->log_info( 'Current Database Time ... ' . $db_now->strftime('%F %T [%Z]') );
        $self->log_info( 'Database Start Date ..... ' . $start->strftime('%F %T [%Z]') );
        $self->log_info( 'Database End Date ....... ' . $end->strftime('%F %T [%Z]') );

    }

}

=head2 _date_coercion_from_iso8601( $date )

Die with a useful error message if a date cannot be coerced from a string
into a L<DateTime> object.

Coercion is done by passing the C<$date> string into the C<parse_datetime>
method of DateTime::Format::ISO8601, meaning that any ISO-8601 date is
valid.

=cut

sub _date_coercion_from_iso8601 {
    my ( $date ) = @_;

    my $result;

    try {

        say "Coercing: $date";

        $result = DateTime::Format::ISO8601
            ->parse_datetime( $date );

        say 'Timezone: ' . $result->time_zone_long_name;

        # If no time zone was given, default to the local time zone.
        $result->set_time_zone('local')
            if $result->time_zone_long_name eq 'floating';

    } catch {

        die "Unrecognised or invalid date format '$date', it must be a valid ISO8601 format (see 'parse_datetime' in perldoc DateTime::Format::ISO8601 for more details).\n";
    };

    return $result;

}

sub _no_get_opt_list {

    # Get a list of all attributes provided from MooseX::Getopt, because
    # these are the ones we want to keep.
    my %getopt_hash;
    my @getopt = MooseX::Getopt->meta->get_attribute_list;
    @getopt_hash{ @getopt } = 1;

    # Remove the MooseX::Getopt attributes from the list of attributes in the
    # current class, leaving just the ones we don't want as arguments.
    return
        grep { ! exists $getopt_hash{ $_ } }
        __PACKAGE__->meta->get_attribute_list;

}
