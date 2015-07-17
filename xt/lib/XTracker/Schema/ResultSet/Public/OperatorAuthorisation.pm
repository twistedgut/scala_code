package XTracker::Schema::ResultSet::Public::OperatorAuthorisation;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';


=head2 operator_has_permission

    do_something() if $opauth_rs->operator_has_permission( {
        operator_id     => $operator_id,
        section         => 'Customer Care',
        sub_section     => 'Order Search',
        auth_level      => $AUTHORISATION_LEVEL__READ_ONLY,
    } );

Returns true if the operator has the specified authorisation level on
the given authorisation sub section in the specified section.

All listed parameters are required.

=cut

sub operator_has_permission {
    my ( $self, $args ) = @_;

    foreach my $required ( qw( operator_id section sub_section auth_level ) ) {
        if ( ! exists $args->{$required} && $args->{$required} ) {
            die "$required is required";
        }
    }

    my $auth = $self->search( {
        'me.operator_id'                => $args->{operator_id},
        'section.section'               => $args->{section},
        'auth_sub_section.sub_section'  => $args->{sub_section},
        'auth_level.id'                 => { '>=' => $args->{auth_level} },
    },
    {
        join => [ { 'auth_sub_section' => 'section' },
                  'auth_level',
                ],
    } );

    return ( $auth->count > 0 ) ? 1 : 0;
}

=head2 get_auth_level_for_main_nav_option

    my $integer = get_auth_level_for_main_nav_option( {
        operator_id     => $operator_id,
        section         => 'Customer Care',
        sub_section     => 'Order Search',
    } );

Gets the Authorisation Level Id for an Operator for a Main NAv option
based on the Operator Id, Section & Sub Section.

All listed parameters are required.

=cut

sub get_auth_level_for_main_nav_option {
    my ( $self, $args ) = @_;

    foreach my $required ( qw( operator_id section sub_section ) ) {
        if ( ! exists $args->{$required} && $args->{$required} ) {
            die "$required is required";
        }
    }

    my $auth = $self->search( {
        'me.operator_id'                => $args->{operator_id},
        'section.section'               => $args->{section},
        'auth_sub_section.sub_section'  => $args->{sub_section},
    },
    {
        join => { auth_sub_section => 'section' },
    } )->first;

    return ( $auth ? $auth->authorisation_level_id : undef );
}

1;
