package XTracker::Schema::ResultSet::ACL::AuthorisationRole;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::RAVNI_transient   qw( is_ravni_disabled_section );
use XTracker::PRLPages          qw( is_prl_disabled_section );

use Carp;


sub get_all_roles {
    my $self = shift;

    my @user_roles = $self->search( { }, {
        order_by =>  [ 'me.authorisation_role' ]
    })->all;

    my @all_roles;
    foreach my $role ( @user_roles ) {
        push(@all_roles, $role->authorisation_role);
    }

    return \@all_roles;
}

=head2 get_main_nav_options

    $hash_ref = $self->get_main_nav_options( [
        # list of Roles to get options for
        'app_canPick',
        ...
    ] );

Will return a Hash Ref. of Options used to build the Main Navigation.

Pass in a list of Roles and it will return all the Main Nav options
assigned to those Roles.

=cut

sub get_main_nav_options {
    my ( $self, $roles )    = @_;

    return { }      if ( !$roles || !@{ $roles } );

    # make the Role search case insensative
    my @lc_roles    = map { lc( $_ ) } @{ $roles };

    my @sections = $self->search(
        {
            'LOWER(authorisation_role)' => { IN   => \@lc_roles },
            # need this because the joins used are 'LEFT' and
            # only want Roles which have Main Nav options
            'section.id'                => { '!=' => undef },
        },
        {
            '+select'   => [
                'section.section',
                'authorisation_sub_section.sub_section',
                'authorisation_sub_section.ord',
            ],
            '+as'       => [
                'section',
                'sub_section',
                'ord',
            ],
            join        => {
                link_authorisation_role__authorisation_sub_sections => {
                    authorisation_sub_section => 'section',
                },
            },
        }
    )->all;

    my %main_nav;

    OPTION:
    foreach my $option ( @sections ) {
        my $section     = $option->get_column('section');
        my $sub_section = $option->get_column('sub_section');
        my $ord_sequence= $option->get_column('ord');

        # DCEA check
        next OPTION     if ( is_ravni_disabled_section( $section, $sub_section ) );

        # DC2A/PRL check
        next OPTION     if ( is_prl_disabled_section( $section, $sub_section ) );

        $main_nav{ $section }{ $ord_sequence }  = {
            section     => $section,
            sub_section => $sub_section,
            ord         => $ord_sequence,
        };
    }

    return \%main_nav;
}

=head2 get_roles_for_main_nav_option

    $array_ref = $self->get_roles_for_main_nav_option( {
        section     => 'Customer Care',
        sub_section => 'Order Search',
    } );

Will return an Array Ref. of 'ACL::AuthorisationRole' objects that
are Required to access the passed in Main Nav option.

=cut

sub get_roles_for_main_nav_option {
    my ( $self, $section, $sub_section )    = @_;

    croak "No 'section' passed in to '" . __PACKAGE__ . "->get_roles_for_main_nav_option'"
                        if ( !$section );
    croak "No 'sub_section' passed in to '" . __PACKAGE__ . "->get_roles_for_main_nav_option'"
                        if ( !$sub_section );

    my @roles = $self->search(
        {
            'section.section'                       => $section,
            'authorisation_sub_section.sub_section' => $sub_section,
        },
        {
            join        => {
                link_authorisation_role__authorisation_sub_sections => {
                    authorisation_sub_section => 'section',
                },
            },
        }
    )->all;

    return \@roles;
}

=head2 get_role_names_for_main_nav_option

    $array_ref = $self->get_role_names_for_main_nav_option( {
        section     => 'Customer Care',
        sub_section => 'Order Search',
    } );

Will return an Array Ref. of Role Names that are
Required to access the passed in Main Nav option.

=cut

sub get_role_names_for_main_nav_option {
    my ( $self, $section, $sub_section )    = @_;

    my $roles = $self->get_roles_for_main_nav_option( $section, $sub_section );

    return $self->_get_role_names( $roles );
}

=head2 get_roles_for_url_path

    $array_ref = $self->get_roles_for_url_path( '/This/Sensitive/Page' );

Will return an Array Ref. of 'ACL::AuthorisationRole' objects that
are Required to access the passed in URL Path.

=cut

sub get_roles_for_url_path {
    my ( $self, $url_path ) = @_;

    croak "No 'url_path' passed in to '" . __PACKAGE__ . "->get_roles_for_url_path'"
                        if ( !defined $url_path );

    $url_path = "/". $url_path unless ( $url_path =~ m{^/} );

    my @roles = $self->search(
        {
            'url_path.url_path' => $url_path,
        },
        {
            join => { link_authorisation_role__url_paths => 'url_path' },
        }
    )->all;

    return \@roles;
}

=head2 get_role_names_for_url_path

    $array_ref = $self->get_role_names_for_url_path( '/This/Sensitive/Page' );

Will return an Array Ref. of Role Names that are
Required to access a URL Path.

=cut

sub get_role_names_for_url_path {
    my ( $self, $url_path ) = @_;

    my $roles = $self->get_roles_for_url_path( $url_path );

    return $self->_get_role_names( $roles );
}


# private method to just get the Role
# Names from a list of Role objects
sub _get_role_names {
    my ( $self, $roles ) = @_;

    my @role_names;
    if ( $roles ) {
        @role_names = map { $_->authorisation_role } @{ $roles }
    }

    return \@role_names;
}

=head2 get_main_nav_options_for_ui

Given array of user roles this method returns formatted data
to be represented in tree structure.

=cut


sub get_main_nav_options_for_ui {
    my ( $self, $roles ) = @_;

    return {} if( !$roles );

    my $nav_result = $self->get_main_nav_options( $roles );

    my $data;
    my @return_results = ();

    # Format data
    foreach my $section ( sort keys %$nav_result ) {
        $data = {};
        $data->{label} = $section;

        my @children;
        my $format_data;
        foreach my $id ( sort { $a <=> $b} keys %{$nav_result->{$section}} ) {
            $format_data = {};
            my $ord_id = $nav_result->{$section}->{$id};
            $format_data->{label} = $ord_id->{sub_section};
            push(@children, $format_data);
        }
        $data->{children} = \@children if ( scalar(@children) > 0 );

       push( @return_results, $data );

    }

    return \@return_results;;
}

1;
