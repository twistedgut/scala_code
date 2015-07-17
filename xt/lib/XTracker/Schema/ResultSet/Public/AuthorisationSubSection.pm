package XTracker::Schema::ResultSet::Public::AuthorisationSubSection;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub data_for_user_access_report {
    my ( $self ) = @_;

    return $self->search(
        undef,
        {
            columns => [ 'operator.name', 'department.department', 'me.sub_section', 'section.section', 'auth_level.description' ],
            join => [
                'section',
                { 'operator_authorisations' => [
                        'auth_level',
                        { 'operator' => 'department' }
                    ]
                }
            ],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    );
}

sub permissions_hashref {
    my ( $self ) = @_;

    return $self->search(
        undef,
        {
            columns  => [ 'section.section', 'me.sub_section' ],
            join     => 'section',
            order_by => [ 'section.section', 'me.ord' ],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    );
}


sub get_all_main_nav_options {
    my $self = shift;

    my @nav_options = $self->search({ }, {
        '+select' => [ 'section.section' ],
        '+as' => [ 'section' ],
        join => [ 'section'],
        order_by => [ 'section.section', 'me.ord' ],
    })->all;

    my %main_nav;
    foreach my $option ( @nav_options ) {
        my $section    = $option->get_column('section');
        push @{ $main_nav{ $section} } , {
            sub_section => $option->sub_section,
            id          => $option->id,
        };
    }

    return \%main_nav;
}


=head2 get_user_roles

     $hash_ref = $self->get_user_roles( [
        #list of authorisation_sub_section_ids
        .....
    ]);

Will return a Hash Ref. having user roles as key and value having following format
{
    <ord> => {
        sub_section => <sub_section>,
        section     => <section>,
        ord         => <ord>
    }
}

Pass in a list of Authorisation SubSection ids and it will return all the authorisation roles
available as hash keys with additional information.

=cut

sub get_user_roles {
    my ( $self, $sub_section_ids ) = @_;

    return { } if ( !$sub_section_ids || !@{ $sub_section_ids } );

    my @user_roles = $self->search(
    {
            'me.id' => { IN => $sub_section_ids },
    },
    {
        '+select'   => [
            'authorisation_role.authorisation_role',
            'section.section',
         ],
        '+as'       => [
            'authorisation_role',
            'section',
        ],
        join => [ 'section',  {'link_authorisation_role__authorisation_sub_sections' =>  'authorisation_role' }],
    })->all;

    my %auth_roles;
    foreach my $option ( @user_roles ) {
        my $section    = $option->get_column('section');
        my $user_role  = $option->get_column('authorisation_role')// 'None';

        $auth_roles{ $user_role }{ $option->ord } = {
            sub_section => $option->sub_section,
            section     => $section,
            ord         => $option->ord,
        };
    }

    return \%auth_roles;
}


sub get_user_roles_for_ui {
    my ( $self, $auth_roles ) = @_;

    return {} if( !$auth_roles );

    my @return_result   = ();
    my $user_roles      = $self->get_user_roles( $auth_roles );

    foreach my $role (sort keys %{$user_roles} ) {
        my $data         = {};
        my $format_data  = {};
        $data->{label}   = $role;
        my @children;

        if( $role eq 'None' ) {
            $data->{label} = "No roles for these menu options";
        }

        foreach my $id ( sort keys %{ $user_roles->{$role} } ) {
            my $data_hash         = $user_roles->{$role}->{$id};
            $format_data->{label} = $data_hash->{section};
            push( @children, $data_hash->{sub_section} );
        }

        $format_data->{children} = \@children if scalar(@children);
        $data->{children}        = [ $format_data];

        push( @return_result, $data );
    }

    return \@return_result;
}

1;
