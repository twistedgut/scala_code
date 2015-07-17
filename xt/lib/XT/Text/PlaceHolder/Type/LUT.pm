package XT::Text::PlaceHolder::Type::LUT;

use NAP::policy "tt",     'class';
extends 'XT::Text::PlaceHolder::Type';

=head1 XT::Text::PlaceHolder::Type::LUT

Look Up Table Place Holder.

    P[LUT.Table::ClassName.column_with_value,column=value]

=cut

use MooseX::Types::Moose qw(
    Str
    RegexpRef
);


=head1 ATTRIBUTES

=cut

=head2 schema

Schema is required for this Place Holder.

=cut

has '+schema' => (
    required    => 1,
    lazy        => 0,
);

=head2 part1_split_pattern

Used to get the Class name of the Table to query from.

=cut

has part1_split_pattern => (
    is      => 'ro',
    isa     => RegexpRef,
    default => sub {
        return qr/(?<_table_class_name>^.*\w+::\w+.*$)/;
    },
);

=head2 part2_split_pattern

Used to get the Column that holds the Value along with
the Column & Value to use in the Query.

=cut

has part2_split_pattern => (
    is      => 'ro',
    isa     => RegexpRef,
    default => sub {
        return qr/(?<_column_with_value>\w+),(?<_column_to_query>\w+)=(?<_value_to_query_for>.+)/;
    },
);


#
# These will be populated when the Parts get split up by the
# Parent method '_split_up_parts' at the point of instantiation
#

has _table_class_name => (
    is      => 'rw',
    isa     => Str,
);

has _column_with_value => (
    is      => 'rw',
    isa     => Str,
);

has _column_to_query => (
    is      => 'rw',
    isa     => Str,
);

has _value_to_query_for => (
    is      => 'rw',
    isa     => Str,
);

=head1 METHODS

=head2 value

    $scalar = $self->value;

Will get the Value for the Place Holder from the Look Up Table.

=cut

sub value {
    my $self    = shift;

    my $rs  = $self->schema->resultset( $self->_table_class_name )->search( {
        $self->_column_to_query => $self->_value_to_query_for,
        ( $self->_is_channelised ? ( channel_id => $self->channel->id ) : () ),
    } );
    my $rec = $rs->first;

    if ( !$rec ) {
        $self->_log_croak(
            "Class: '" . $self->_table_class_name . "', " .
            "Column to Query: '" . $self->_column_to_query . "', " .
            "Value to check for: '" . $self->_value_to_query_for . "'" .
            " didn't return a Record"
        );
    }

    my $col_with_value  = $self->_column_with_value;

    if ( !$rec->can( $col_with_value ) ) {
        $self->_log_croak(
            "Column with Value: '${col_with_value}' " .
            "is not found on the Class: '" . $self->_table_class_name . "'"
        );
    }

    return $self->_check_value( $rec->$col_with_value );
}

