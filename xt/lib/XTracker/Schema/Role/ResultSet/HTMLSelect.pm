package XTracker::Schema::Role::ResultSet::HTMLSelect;
use NAP::policy 'role';
use MooseX::Role::Parameterized;

=head1 NAME

XTracker::Schema::Role::ResultSet::HTMLSelect

=head1 DESCRIPTION

A parameterised role to add a method to a DBIx::Class ResultSet that
generates data suitable for constructing an HTML SELECT tag.

The role supports being linked to a relationship that provides grouping
information, so HTML OPTGROUP tags can be included automatically.

=head1 SYNOPSIS

    package XTracker::Schema::ResultSet::Public::SomeDataSet;
    use Moose;

    with 'XTracker::Schema::Role::ResultSet::HTMLSelect' => {
        group_label_column          => 'description',
        group_visible_column        => 'description_visible',
        group_sequence_column       => 'display_sequence',
        relationship                => 'category',
        sequence_column             => 'display_sequence',
        enabled_column              => 'enabled',
        value_column                => 'id',
        display_column              => 'description',
    };

=head1 PARAMETERS

=head2 group_label_column [String] [Required]

The name of the column from the table referred to by C<relationship>,
to be used as the group label.

=cut

parameter group_label_column => (
    isa         => 'Str',
    required    => 1,
);

=head2 group_visible_column [String] [Required]

The name of the column from the table referred to by C<relationship>,
to determine whether the group should be contained within an HTML OPTGROUP or
not.

=cut

parameter group_visible_column => (
    isa         => 'Str',
    required    => 1,
);

=head2 group_sequence_column [String] [Required]

The name of the column from the table referred to by C<relationship>,
to be used to determine the ordering of the groups.

=cut

parameter group_sequence_column => (
    isa         => 'Str',
    required    => 1,
);

=head2 relationship [String] [Required]

This is the name of the relationship for the table holding group information
for the ResultSet this role has been used in.

=cut

parameter relationship => (
    isa         => 'Str',
    required    => 1,
);

=head2 sequence_column [String] [Required]

The name of the column from the current table, to be used to determine the
ordering of the options.

=cut

parameter sequence_column => (
    isa         => 'Str',
    required    => 1,
);

=head2 enabled_column [String] [Required]

The name of the column from the current table, to be used to determine the
whether the option should be displayed or not.

=cut

parameter enabled_column => (
    isa         => 'Str',
    required    => 1,
);

=head2 value_column [String] [Required]

The name of the column from the current table, to be used to determine the
string to be used in the "value" attribute of the HTML OPTION tag.

=cut

parameter value_column => (
    isa         => 'Str',
    required    => 1,
);

=head2 display_column [String] [Required]

The name of the column from the current table, to be used to determine the
string to be used between the opening and closing HTML OPTION tags,
effectively the display value.

=cut

parameter display_column => (
    isa         => 'Str',
    required    => 1,
);

=head1 METHODS

=head2 html_select_data( $current_value )

Returns an ArrayRef of Hashrefs to be used when constructing an HTML SELECT
element. Each HashRef contains an C<action> and an optional C<data> key.

    my $result = $schema->resultset('Some::ResultSet')
        ->html_select_data('Selected Item');

    $result = [
        { action => 'insert-option', data => { value => '1', display => 'Item One', selected => 0 } }
        { action => 'insert-option', data => { value => '2', display => 'Item Two', selected => 1 } }
        { action => 'start-group',   data => { name => 'Group One' } }
        { action => 'insert-option', data => { value => '3', display => 'Item Three', selected => 0 } }
        { action => 'end-group' }
    ]

The C<data> key depends on the value of the C<action> key, which can be one
of the following:

=over

=item insert-option

This is an instruction to insert an HTML OPTION tag and will also contain a
C<data> key, with the keys C<value>, C<display> and C<selected>.

The C<value> key contains the string to be put in the "value" attribute of
the OPTION tag.

The C<display> key contains the string to be placed between the opening and
closing OPTION tags, i.e. the display value.

The C<selected> key is a boolean value indicating whether the OPTION should
be selected or not (determined by <$current_value>).

=item start-group

This is an instruction to open an HTML OPTGROUP tag and will also contain a
C<data> key, with the single key C<label>.

The C<label> key contains the "label" attribute for the OPTGROUP tag.

=item end-group

This is an intruction to close an HTML OPTGROUP tag and contains no C<data>
key.

=back

=cut

role {
    my $p = shift;

    method html_select_data => sub {
        my $self = shift;
        my ( $current_value ) = @_;

        my @groups;
        my @result;

        my $records = $self
            # Create a namespace boundry, because we're going to be joining
            # to another table.
            ->as_subselect_rs
            ->search({
                $self->current_source_alias . '.' . $p->enabled_column => 1,
            },{
                prefetch    => $p->relationship,
                columns     => {
                    group_label     => $p->relationship . '.' . $p->group_label_column,
                    group_visible   => $p->relationship . '.' . $p->group_visible_column,
                    value           => $self->current_source_alias . '.' . $p->value_column,
                    display         => $self->current_source_alias . '.' . $p->display_column,
                },
                order_by    => [
                    $p->relationship . '.' . $p->group_sequence_column,
                    $p->relationship . '.' . $p->group_label_column,
                    $self->current_source_alias . '.' . $p->sequence_column,
                    $self->current_source_alias . '.' . $p->display_column,
                ]
            });

        foreach my $record ( $records->all ) {

            my $group_label     = $record->get_column( 'group_label' );
            my $group_visible   = $record->get_column( 'group_visible' );
            my $value           = $record->get_column( 'value' );
            my $display         = $record->get_column( 'display' );
            my $current_group   = $groups[-1] // { label => '' };

            if ( $group_label ne $current_group->{label} ) {
                push @groups, { label => $group_label, visible => $group_visible, items => [] };
                $current_group = $groups[-1];
            }

            push @{ $current_group->{items} }, {
                value       => $value,
                display     => $display,
                selected    => ( $value eq ( $current_value // '' ) ? 1 : 0 ),
            };

        }

        foreach my $group ( @groups ) {

            # If the group is visible, add a start group action.
            push( @result, { action => 'start-group', data => { label => $group->{label} } } )
                if $group->{visible};

            foreach my $item ( @{ $group->{items} } ) {

                push @result, {
                    action  => 'insert-option',
                    data    => {
                        value       => $item->{value},
                        display     => $item->{display},
                        selected    => $item->{selected},
                    }
                };

            }

            # If the group is visible, add an end group action.
            push( @result, { action => 'end-group' } )
                if $group->{visible};

        }

        return \@result;

    };

};
