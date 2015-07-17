package XTracker::Schema::Role::ResultSet::FromText;

use strict;
use warnings;
use Carp;

use MooseX::Role::Parameterized;

=head1 NAME

XTracker::Schema::Role::ResultSet::FromText

=head1 DESCRIPTION

A Parameterised Role to extract valid numbers from a piece of given text to return a ResultSet using the field name to search against using the numbers.

Example:

    package XTracker::Schema::ResultSet::Public::SomeClass;
    ...
    with 'XTracker::Schema::Role::ResultSet::FromText' => { field_name => 'some_number_field' };
    ...
    1;

The method "from_text" will return a ResultSet where all the numbers match against the field "some_number_field".

=cut

use XTracker::Database::Utilities   qw( is_valid_database_id );

=head1 PARAMETERS

=head2 field_name

Field name to query against to build a ResultSet

=cut

parameter field_name => (
    isa => 'Str',
    required => 1,
);

=head1 METHODS

=head2 B<from_text($input, $invalid, $pattern)>

Takes a string/text ($input) and gets values out of it relevant to the field that
match the regular expression ($pattern) if no regex is supplied then it will default
to 'qr/\d+/' and only look for numbers.

It returns a ResultSet containing valid values, according to their existence in
the database, and populates an ArrayRef of HashRef's ($invalid) with invalid values.

    my $numbers = q[
        123 456,789
        321 : 654 / 987
    ];
    my $invalid = [];

    $schema-E<gt>resultset('Public::Orders')-E<gt>from_text( $numbers, $invalid );

    # If all the numbers in $numbers exist except 456 & 987, we would then have the following:
    # $numbers = ResultSet containing 123, 789, 321 and 654
    # $invalid = [ { field_name => 456, reason => 'Does not exist' },
    #              { field_name => 987, reason => 'Does not exist' } ];

=cut

role {
    my $p = shift;

    method from_text => sub {
        my $self = shift;
        my ( $input, $invalid, $pattern ) = @_;

        my $valid = [];

        # If not provided, default to empty array reference.
        $invalid ||= [];

        # find out the Field's data type so as to know
        # as to whether to check for a valid database id
        my $chk_for_valid_id = 0;
        if ( my $field_info = $self->result_source->column_info( $p->field_name )  ) {
            $chk_for_valid_id = 1   if ( lc( $field_info->{data_type} ) eq 'integer' );
        }
        else {
            croak "Can't find Column Info for field: '" . $p->field_name . "' in Role: '" . __PACKAGE__ . "'";
        }

        # if no pattern provided default to numbers only
        $pattern //= qr/\d+/;
        # treat $input as a single line and find all occurences that match
        my @parsed_values = ( $input =~ m/${pattern}/gs );

        # process each value found in @parsed_values
        foreach my $value ( @parsed_values ) {

            # Make sure we got something useful.
            if ( $value ne '' ) {
                my $valid_value;

                my $ok_to_find_record = 1;
                if ( $chk_for_valid_id ) {
                    $ok_to_find_record = 0      unless ( is_valid_database_id( $value ) );
                }
                $valid_value = $self->find( { $p->field_name => $value } )    if ( $ok_to_find_record );

                # If we got a valid ResultSet, add the order number to the list of valid ones.
                if ( defined $valid_value ) {
                    push @$valid, $value;
                } else {
                    push @$invalid, { $p->field_name => $value, reason => 'Does not exist' };
                }

            }

        }
        # Now return the complete ResultSet containing all valid values.
        return $self->search( {
            $p->field_name => {
                '-in' => $valid
            }
        } );

    };
};

1;
