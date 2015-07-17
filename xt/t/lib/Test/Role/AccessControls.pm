package Test::Role::AccessControls;

use NAP::policy     qw( test role tt );

requires 'get_schema';

with    qw(
    Test::Role::SystemConfig
    Test::Role::Legacy::Operator
);

=head1 NAME

Test::Role::AccessControls

=head1 DESCRIPTION

Used to set-up data for Access Control related stuff.

=cut

use XTracker::Config::Local         qw( sys_config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :authorisation_level );
use XTracker::Utilities             qw( parse_url_path );


=head1 METHODS

=head2 save_role_to_sub_section_links

    $array_ref = __PACKAGE__->save_role_to_sub_section_links;

Saves the current contents of the 'acl.link_authorisation_role__authorisation_sub_section'
table.

This returns an Array Ref. of the current Link's columns (but NOT an Array Ref. of DBIC
Classes) use this to pass into 'restore_role_to_sub_section_links' if you plan on making
many changes in one test and want to restore to different stages.

=head2 restore_role_to_sub_section_links

    __PACKAGE__->restore_role_to_sub_section_links;
            or
    __PACKAGE__->restore_role_to_sub_section_links( $array_ref_of_links );

Restores the contents of the 'acl.link_authorisation_role__authorisation_sub_section'
table.

Called without an Array Ref. of Links will restore what ever was saved the last time
that 'save_role_to_sub_section_links' was called.

Called with an Array Ref. of Link Columns (NOT an Array Ref. of DBIC Classes) will
restore those specifically, use this feature if you plan on making many calls to
'save_role_to_sub_section_links' in one test and want to restore to a particualr state.

=cut

my $_original_role_to_sub_section_links;

sub save_role_to_sub_section_links {
    my $self = shift;

    my $schema  = $self->get_schema;

    note "Saving current contents of 'acl.link_authorisation_role__authorisation_sub_section' table";

    my @links = $schema->resultset('ACL::LinkAuthorisationRoleAuthorisationSubSection')->all;
    push @{ $_original_role_to_sub_section_links }, { $_->get_columns }     foreach ( @links );

    return $_original_role_to_sub_section_links;
}

sub restore_role_to_sub_section_links {
    my ( $self, $links ) = @_;

    # if nothing to restore then just return
    return      if ( !$links && !$_original_role_to_sub_section_links );

    my $schema  = $self->get_schema;
    my $rs      = $schema->resultset('ACL::LinkAuthorisationRoleAuthorisationSubSection');

    note "Restoring contents of 'acl.link_authorisation_role__authorisation_sub_section' table";

    # remove all current links
    $self->clearout_link_role_to_sub_section( { suppress_not_in_transaction_warning => 1 } );

    $rs->create( $_ )   foreach ( @{ $links || $_original_role_to_sub_section_links } );

    $_original_role_to_sub_section_links = undef    if ( !$links );

    return;
}

=head2 clearout_link_role_to_sub_section

    __PACKAGE__->clearout_link_role_to_sub_section;

Clear out all links between Roles and Sub Sections.

=cut

sub clearout_link_role_to_sub_section {
    my ( $self, $args ) = @_;

    my $schema  = $self->get_schema;

    # show a warning if not in a Transaction
    if ( !$self->_in_transaction && !$args->{suppress_not_in_transaction_warning} ) {
        note "WARNING: calling 'clearout_link_role_to_sub_section' when Not in a Transaction";
        note "         this will permanently remove links between Roles & Authorisation Sub-Sections";
        if ( !$_original_role_to_sub_section_links) {
            note "         consider using 'save_role_to_sub_section_links' & 'restore_role_to_sub_section_links'";
            note "         methods to help in not breaking other tests that rely on the contents of this table";
        }
    }

    $schema->resultset('ACL::LinkAuthorisationRoleAuthorisationSubSection')->delete;

    return;
}

=head2 clearout_link_role_to_url_path

    __PACKAGE__->clearout_link_role_to_url_path;

Clear out all links between Roles and URL Paths

=cut

sub clearout_link_role_to_url_path {
    my $self    = shift;

    my $schema  = $self->get_schema;

    # show a warning if not in a Transaction
    if ( !$self->_in_transaction ) {
        note "WARNING: calling 'clearout_link_role_to_url_path' when Not in a Transaction";
        note "         this will permanently remove links between Roles & URL Paths";
    }

    $schema->resultset('ACL::LinkAuthorisationRoleURLPath')->delete;

    return;
}

=head2 link_role_to_sub_section

    __PACKAGE__->link_role_to_sub_section( {
        app_can_do_stuff => [
            'Admin/User Admin',
            ...
        ],
        ...
    } );

Create a link between ACL Roles and Authorisation Sub Sections used for
the Main Navigation.

=cut

sub link_role_to_sub_section {
    my ( $self, $args ) = @_;

    my $schema = $self->get_schema;

    my $role_rs                  = $schema->resultset('ACL::AuthorisationRole');
    my $link_role_sub_section_rs = $schema->resultset('ACL::LinkAuthorisationRoleAuthorisationSubSection');
    my $sub_section_rs           = $schema->resultset('Public::AuthorisationSubSection');

    foreach my $role ( keys %{ $args } ) {
        foreach my $option ( @{ $args->{ $role } } ) {
            if ( $option =~ m{(?<section>.*)/(?<sub_section>.*)} ) {
                my $sub_section_rec = $sub_section_rs->search(
                    {
                        'section.section' => $+{section},
                        'sub_section'     => $+{sub_section},
                    },
                    {
                        join => 'section',
                    }
                )->first;

                my $role_rec = $role_rs->find_or_create( { authorisation_role => $role } );

                $link_role_sub_section_rs->update_or_create( {
                    authorisation_role_id        => $role_rec->discard_changes->id,
                    authorisation_sub_section_id => $sub_section_rec->id,
                } );
            }
        }
    }

    return;
}

=head2 roles_for_tests

    $array_ref = __PACKAGE__->roles_for_tests;

This will give a list of Roles that can be used in tests, so that
people don't have to come up with a list all the time for each
individual test.

The following Roles will be returned:

    app_has_admin_rights
    app_can_pack
    app_can_make_tea
    app_has_superpowers
    app_can_fly
    app_can_see_dead_people

=cut

sub roles_for_tests {
    my $self    = shift;

    return [ qw(
        app_has_admin_rights
        app_can_pack
        app_can_make_tea
        app_has_superpowers
        app_can_fly
        app_can_see_dead_people
    ) ];
}

=head2 get_acl_obj

    $object = __PACKAGE__->get_acl_obj;
        or
    $object = __PACKAGE__->get_acl_obj( {
        operator => $dbic_operator,
        roles    => [
            # list of roles
            'app_can_do',
            ...
        ],
    } );

Returns an 'XT::AccessControls' object. Will use
default Roles from 'roles_for_tests' unless they
are passed in.

It will choose an arbitrary Operator unless one is
specified.

=cut

sub get_acl_obj {
    my ( $self, $args ) = @_;

    my $schema = $self->get_schema;

    my $operator = $args->{operator} //
        $schema->resultset('Public::Operator')
                ->search( {
        id          => { '!=' => $APPLICATION_OPERATOR_ID },
        username    => { '!=' => 'it.god' },
        disabled    => 0,
    } )->first;

    my $roles = $args->{roles} // $self->roles_for_tests;

    return XT::AccessControls->new( {
        operator    => $operator,
        session     => {
            acl => {
                operator_roles => $roles,
            },
        },
    } );
}

=head2 set_build_main_nav_setting

    __PACKAGE__->set_build_main_nav_setting( 'on' or 'off' );

Sets the global 'build_main_nav' setting in the System Config
for the 'ACL' group. This is used to indicate whether the main
nav should be build using Roles if possible.

=cut

# used to store the original value of the
# 'build_main_nav' setting for the ACL group
my $_original_build_main_nav_setting;

sub set_build_main_nav_setting {
    my ( $self, $value )    = @_;

    if ( !defined $_original_build_main_nav_setting ) {
        $_original_build_main_nav_setting = sys_config_var( $self->get_schema, 'ACL', 'build_main_nav' ) // 'off';
    }

    $self->_set_acl_group_setting( 'build_main_nav', $value );

    return;
}

=head2 restore_build_main_nav_setting

    __PACKAGE__->restore_build_main_nav_setting;

Restores the 'build_main_nav' setting in the 'ACL' group
to what it was before 'set_build_main_nav_setting' was
called for the first time.

=cut

sub restore_build_main_nav_setting {
    my $self    = shift;

    return      if ( !defined $_original_build_main_nav_setting );

    $self->_set_acl_group_setting(
        'build_main_nav',
        $_original_build_main_nav_setting,
    );

    return;
}

=head2 set_main_nav_options

    __PACKAGE__->set_main_nav_options( {
        acl => {
            role_name => [
                'Admin/User Admin',
            ],
        },
        non_acl => {
            operator => $operator_obj,
            department => 'Customer Care',
            AUTH_LEVEL => [
                'Admin/User Admin',
            ],
        },
        # optional
        delete_existing_acl_options => 1,
    } );

Sets up Main Nav options either using ACL or NON-ACL modes or both.

Passing the optional argument 'delete_existing_options' will
clear out any existing links between Roles and Main Nav options.

=cut

sub set_main_nav_options {
    my ( $self, $args ) = @_;

    if ( $args->{acl} ) {
        $self->clearout_link_role_to_sub_section        if ( $args->{delete_existing_acl_options} );
        $self->link_role_to_sub_section( $args->{acl} );
    }

    if ( $args->{non_acl} ) {
        my %non_acl  = %{ $args->{non_acl} };
        my $dept     = delete $non_acl{department};
        my $operator = delete $non_acl{operator};

        my @perms;
        foreach my $auth_level ( keys %non_acl ) {
            foreach my $option ( @{ $non_acl{ $auth_level } } ) {
                my ( $section, $sub_section ) = split( /\//, $option );
                push @perms, {
                    section     => $section,
                    sub_section => $sub_section,
                    level       => $auth_level,
                };
            }
        }

        $self->setup_user( {
            auth  => { user => $operator->username },
            perms => \@perms,
            dept  => $dept,
        } );
    }

    return;
}

=head2 set_url_path_roles

    __PACKAGE__->set_url_path_roles( {
        role_name => [
            '/url',
            '/another/url',
            ...
        ],
        ...
    } );

Given a set of Roles to URLs will create the relevant records
in the 'acl.authorisation_role', 'acl.link_authorisation_role__url_path'
and 'acl.url_path' tables.

=cut

sub set_url_path_roles {
    my ( $self, $args ) = @_;

    $self->clearout_link_role_to_url_path;

    my $schema = $self->get_schema;

    my $role_rs                 = $schema->resultset('ACL::AuthorisationRole');
    my $link_role_url_path_rs   = $schema->resultset('ACL::LinkAuthorisationRoleURLPath');
    my $url_path_rs             = $schema->resultset('ACL::URLPath');

    foreach my $role ( keys %{ $args } ) {
        foreach my $path ( @{ $args->{ $role } } ) {
            my $role_rec = $role_rs->find_or_create( { authorisation_role => $role } );
            my $url_path = $url_path_rs->find_or_create( { url_path => $path } );

            $link_role_url_path_rs->update_or_create( {
                authorisation_role_id   => $role_rec->discard_changes->id,
                url_path_id             => $url_path->discard_changes->id,
            } );
        }
    }

    return;
}


=head2 get_all_main_nav_options

    $hash_ref = __PACKAGE__->get_all_main_nav_options( $operator );

Get all the Main Nav options specified for an Operator and Roles.

Returns a Hash Ref. of Main Nav options with the Auth Level for the option:

    {
        Admin => {
            'User Admin' => $AUTHORISATION_LEVEL__READ_ONLY,
            ...
        },
        ...
    }

=cut

sub get_all_main_nav_options {
    my ( $self, $operator ) = @_;

    my $schema = $self->get_schema;

    my %nav_options;

    # get the options for Roles first
    my @options = $schema->resultset('ACL::LinkAuthorisationRoleAuthorisationSubSection')->all;
    foreach my $option ( @options ) {
        my $section     = $option->authorisation_sub_section->section->section;
        my $sub_section = $option->authorisation_sub_section->sub_section;
        # default all Authorisation Roles to have an Auth Level of Read-Only
        $nav_options{ $section }{ $sub_section }    = $AUTHORISATION_LEVEL__READ_ONLY;
    }

    # now get the options in the 'operator_authorisation' table
    @options    = $schema->resultset('Public::OperatorAuthorisation')
                            ->search( { operator_id => $operator->id } )->all;
    foreach my $option ( @options ) {
        my $section     = $option->auth_sub_section->section->section;
        my $sub_section = $option->auth_sub_section->sub_section;
        $nav_options{ $section }{ $sub_section }    = $option->authorisation_level_id;
    }

    return \%nav_options;
}

=head2 get_roles_for_url_paths

    my $array_ref = __PACKAGE__->get_roles_for_url_paths( [
        # list for URL Paths
        '/Some/URL',
        '/Some/Other/URL',
        # as a 'LIKE' will be used to get the Roles
        # you can put a '%' on the end to get matches
        '/URL/Like/This%',
    ] );

Returns a unique list of Roles required for a list of URL Paths.

Use a '%' on the end of any URL that you would like to find by a
'LIKE' SQL statement so that you don't have to pass every URL
for a feature that all have the same prefix.

=cut

sub get_roles_for_url_paths {
    my ( $self, $paths ) = @_;
    $paths  //= [];

    my $schema      = $self->get_schema;
    my $url_path_rs = $schema->resultset('ACL::URLPath');
    my $role_rs     = $schema->resultset('ACL::AuthorisationRole');

    my %roles;
    foreach my $path ( @{ $paths } ) {
        my @path_recs = $url_path_rs->search( { url_path => { LIKE => $path } } )->all;
        foreach my $path_rec ( @path_recs ) {
            my $role_names = $role_rs->get_role_names_for_url_path( $path_rec->url_path );
            %roles  = (
                %roles,
                map { $_ => 1 } @{ $role_names }
            );
        }
    }

    return [ keys %roles ];
}

=head2 get_roles_for_main_nav

    $role_names_array_ref = __PACKAGE__->get_roles_for_main_nav( [
        'Customer Care/Order Search',
        'Finance/Credit Check',
        ...
    ] );

Given an Array Ref. of Main Nav options this will return a list of Roles required to access those
options.

=cut

sub get_roles_for_main_nav {
    my ( $self, $main_nav_options, $args ) = @_;

    my $role_rs = $self->get_schema->resultset('ACL::AuthorisationRole');

    # turn each Main Nav Option into a URL
    # and then get Roles for it, if there
    # aren't any then make-up params for
    # the old 'grant_permissions' method
    my @old_method_params;
    my %roles;
    foreach my $option ( @{ $main_nav_options } ) {
        $option =~ s{^/}{};
        my ( $section, $sub_section ) = split( /\//, $option );
        my $url = '/' . $option;
        $url    =~ s/\s//g;

        my $role_names_for_url = $role_rs->get_role_names_for_url_path( $url );
        my $role_names_for_nav = $role_rs->get_role_names_for_main_nav_option( $section, $sub_section );

        my @role_names = (
            @{ $role_names_for_url // [] },
            @{ $role_names_for_nav // [] },
        );

        %roles = (
            %roles,
            map { $_ => 1 } @role_names
        );
    }

    return [ keys %roles ];
}

=head2 get_main_nav_options_for_roles

    $hash_ref = __PACKAGE__->get_main_nav_options_for_roles( [
        'app_can_do_stuff',
        'app_can_do_more_stuff',
        ...
    ] );

Given an Array Ref. of Role Names this method will return a Hash Ref. of
Role Name to Main Nav options that can be accessed using it. This Hash Ref
can be passed in to the 'set_main_nav_options' method which sets up the
access to those Options.

Returned:

    {
        app_can_do_stuff => [
            'Customer Care/Order Search',
        ],
        app_can_do_more_stuff => [
            'Finance/Credit Check',
            'Finance/Credit Hold',
        ],
    },

or feed it into __PACKAGE__->set_main_nav_options:

    __PACKAGE__->set_main_nav_options( {
        acl => __PACKAGE__->get_main_nav_options_for_roles( [
            'app_can_do_stuff',
            'app_can_do_more_stuff',
        ] ),
    } );

=cut

sub get_main_nav_options_for_roles {
    my ( $self, $roles ) = @_;

    my $schema      = $self->get_schema;
    my $url_path_rs = $schema->resultset('ACL::URLPath');
    my $role_rs     = $schema->resultset('ACL::AuthorisationRole');

    my %main_nav;
    foreach my $role ( @{ $roles } ) {
        my $role_rec  = $role_rs->search( { authorisation_role => { ILIKE => $role } } )->first;
        my @path_recs = $role_rec->link_authorisation_role__url_paths->all;
        my @auth_recs = $role_rec->link_authorisation_role__authorisation_sub_sections->all;

        my %nav_options;
        PATH:
        foreach my $path ( @path_recs ) {
            # only interested in Paths with 2 parts
            # anything more or less can't be a menu
            # option so don't use it or try and infer
            my $path_details = parse_url_path( $path->url_path->url_path );
            next PATH       if ( scalar( @{ $path_details->{levels} } ) != 2 );

            $nav_options{ $path_details->{section} . '/' . $path_details->{sub_section} } = 1,
        }

        # go through the link between Role & Authorisation Sub Section
        foreach my $link_auth_rec ( @auth_recs ) {
            my $sub_section = $link_auth_rec->authorisation_sub_section;
            my $section     = $sub_section->section;
            $nav_options{ $section->section . '/' . $sub_section->sub_section } = 1;
        }

        # get a unique list of Main Nav options for the Role, if there are any
        $main_nav{ $role_rec->authorisation_role } = [ sort keys %nav_options ]
                            if ( keys %nav_options );
    }

    return \%main_nav;
}

=head2 setup_user

    $hash_ref = __PACKAGE__->setup_user( $args );

Sets a User up using either ACL Roles or using Authorisation Sub-Section
permissions.

=cut

sub setup_user {
    my ($self,$opts) = @_;

    # find out if the Department should be set to 'undef'
    my $set_dept_to_undef   = ( exists( $opts->{dept} ) && !defined $opts->{dept} ? 1 : 0 );

    my $dept    = delete $opts->{dept}  || undef;
    my $perms   = delete $opts->{perms} || [];
    my $roles   = delete $opts->{roles};
    my $auth    = delete $opts->{auth}  || {
        user    => 'it.god',
        passwd  => 'it.god',
    };

    # Remove all existing permissions, do this even when using
    # ACL Roles to make sure the old way doesn't get used
    $self->delete_all_permissions($auth->{user});

    $self->set_department( $auth->{user}, $dept ) unless (not defined $dept);

    if ( $roles ) {
        # using Roles
        note "setting up Operator's ACL Roles";

        # make sure the Main Nav is built using Roles
        $self->set_build_main_nav_setting( 'On' );

        # make sure the Operator is enabled and set-up to Build the Main Nav using Roles
        my $operator = $self->_get_operator( $auth->{user} );
        $operator->department( undef )      if ( $set_dept_to_undef );
        $self->_enable_user( $operator, { use_acl_for_main_nav => 1 } );

        # find the Roles required for the URLs asked for
        my $roles_for_urls = $self->get_roles_for_url_paths( $roles->{paths} );

        # find the Roles required for the Main Nav asked for
        my $roles_for_nav = $self->get_roles_for_main_nav( $roles->{main_nav} );

        # combine the above with Roles Names explictly asked for
        my %role_names  = (
            ( map { $_ => 1 } @{ $roles->{names} || [] } ),
            ( map { $_ => 1 } @{ $roles_for_urls || [] } ),
            ( map { $_ => 1 } @{ $roles_for_nav  || [] } ),
        );

        # get a unique list of Roles Names to be put into
        # the Session after the Operator has Logged In
        $auth->{operator_roles}  = [ sort keys %role_names ];

        # set-up the Main Nav options for the Roles
        my $main_nav = $self->get_main_nav_options_for_roles( $auth->{operator_roles} );
        $self->set_main_nav_options( { acl => $main_nav, dont_delete_existing_acl_options => 1 } );

        # set-up any Non ACL Main Nav options using the old style if 'setup_fallback_perms' passed in
        if ( $roles->{setup_fallback_perms} && $main_nav ) {
            # whilst the XT Access Controls project is still incomplete we will
            # need to set old style permissions for Main Nav options so that some
            # URLs that share the same Section & Sub-Section will still function
            # such as 'Finance/CreditHold' & 'Finance/CreditHold/ChangeOrderStatus'
            # the latter if un-protected still needs to be set-up in the old way
            # even if the former has been protected.
            foreach my $nav_options ( values %{ $main_nav } ) {
                # call the old style method but don't get it to call '_enable_user'
                # because that's already been done and will revert the changes made above
                $self->grant_permissions(
                    $auth->{user},
                    split( /\//, $_ ),
                    # default to Operator level access
                    $AUTHORISATION_LEVEL__OPERATOR,
                    { dont_enable_user => 1 },
                )   foreach ( @{ $nav_options } );
            }
        }
    }
    else {
        # using 'operator_authorisation'

        foreach my $perm (@{$perms}) {
            # two possibles to avoid breaking backwards compatiability
            if (ref($perm) eq 'HASH') {
                $self->grant_permissions(
                    $auth->{user},
                    $perm->{section},
                    $perm->{sub_section},
                    $perm->{level}
                );
            } elsif (ref($perm) eq 'ARRAY') {
                $self->grant_permissions(@$perm);
            }

        }
    }

    return $auth;
}

#-----------------------------------------------------------------

sub _set_acl_group_setting {
    my ( $self, $setting, $value )  = @_;

    $self->remove_config_group( 'ACL' );
    $self->create_config_group( 'ACL', {
        settings => [
            {
                setting => $setting,
                value   => $value,
            },
        ],
    } );

    return;
}

# returns TRUE or FALSE depending on
# whether Schema is in a transation or not
sub _in_transaction {
    my $self    = shift;

    return ( $self->get_schema->storage->dbh->{AutoCommit} ? 0 : 1 );
}

