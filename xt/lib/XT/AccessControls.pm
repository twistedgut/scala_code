package XT::AccessControls;

use NAP::policy     qw( class tt );

=head1 NAME

    XT::AccessControls

=head1 SYNOPSYS

    $acl = XT::AccessControls->new( {
        # required:
        operator    => $operator_dbic_object,
        session     => $session,
    } );

    $boolean = $acl->operator_has_role_in( [ qw( role1 role2 role3 ) ] );

    # use in conjunction with 'XTracker::Schema'
    use XTracker::Database      qw( schema_handle );

    $schema = schema_handle();
    $schema->set_acl( $acl );

    ...

    if ( $schema->acl->operator_has_role_in( [ qw( role1 role2 ) ] ) ) {
        print "then you can do something";
    }
    else {
        print "you can't do that";
    }

=head1 DESCRIPTION

This forms the basis of Access Controls in the App. providing access to an Operator's
Session and therfore their Roles. Also provides various Methods to enable you to decide
if an Operator is allowed to do something or not.

Used in conjunction with 'XTracker::Schema' enables an Operator's Roles to be accessed
anywhere a Schema connection is used which should be in most places and if not can be
an easy replacement for a DBH connection.

This module will be built on in stages providing more Access Control functionality as
required.

=cut

use MooseX::Types::Moose    qw(
    ArrayRef
    HashRef
);

use XTracker::Constants::FromDB qw(
    :authorisation_level
);
use XTracker::Config::Local     qw( use_acl_to_build_main_nav config_var );
use XTracker::Logfile           qw( xt_logger );
use XTracker::Navigation        qw( build_nav );
use XTracker::Utilities         qw( parse_url_path );
use XTracker::Utilities::ACL    qw( filter_acl_roles_and_get_role_names );


=head1 ATTRIBUTES

=head2 logger

To provide Logging!

=cut

has logger => (
    is          => 'ro',
    isa         => 'Log::Log4perl::Logger',
    init_arg    => undef,
    default     => sub {
        return xt_logger();
    },
);

=head2 operator

Holds the 'Public::Operator' record passed to this module at instantiation.

=cut

has operator => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Operator',
    required    => 1,
    init_arg    => 'operator',
);

=head2 schema

A Schema connection, this will be derived from the 'operator' Attribute.

=cut

has schema => (
    is          => 'ro',
    isa         => 'XTracker::Schema',
    init_arg    => undef,
    lazy_build  => 1,
);

=head2 dbh

A DBH connection, this will be derived from the 'schema' Attribute.

=cut

has dbh => (
    is          => 'ro',
    isa         => 'DBI::db',
    init_arg    => undef,
    lazy_build  => 1,
);

=head2 session

Holds the Operator's Session which is passed to this module at instantiation. This
will be used to get the Operator's Roles and any other required Session information.

This expects there to be an 'acl' key in the Session Hash which contains
the following:

    {
        ...
        acl => {
            operator_roles => [ ... ],
        },
        ...
    }

=cut

has session => (
    is          => 'ro',
    isa         => HashRef,
    required    => 1,
    init_arg    => 'session',
);

=head2 operator_roles

Contains a Hash Ref of the Operator's Roles where each key is a Role
the Operator has and all will have the value of '1'.

This Attribute has 'Hash' traits and can support the following methods

    $integer = $self->number_of_roles_for_operator
        Returns the number of Roles the Operator has.
    @array   = $self->list_of_roles_for_operator
        Returns a list of all the Roles.

All Roles are stored in this Hash Ref in Lowercase.

=cut

has operator_roles => (
    is          => 'ro',
    isa         => HashRef,
    init_arg    => undef,
    lazy_build  => 1,
    clearer     => '_clear_operator_roles',
    traits      => ['Hash'],
    handles     => {
        number_of_roles_for_operator => 'count',
        list_of_roles_for_operator   => 'keys',
    },
);

=head2 url_restrictions

Contains All URL's defined in 'acl.url_path' and the
Roles required to access them.

=cut

has url_restrictions => (
    is          => 'ro',
    isa         => 'HashRef',
    init_arg    => undef,
    lazy_build  => 1,
);

=head2 can_build_main_nav_using_acl

Returns TRUE or FALSE based on whether the Main Nav can be built
using ACL Roles for the Operator.

=cut

has can_build_main_nav_using_acl => (
    is          => 'ro',
    isa         => 'Bool',
    init_arg    => undef,
    lazy_build  => 1,
);


#
# private Attributes
#

# return a string containing the
# Operator for Log entries
has _operator_for_log => (
    is          => 'ro',
    isa         => 'Str',
    init_arg    => undef,
    lazy_build  => 1,
);


#
# private methods to support Lazy Builds of the Attributes above
#

sub _build_schema {
    my $self    = shift;
    return $self->operator->result_source->schema;
}

sub _build_dbh {
    my $self    = shift;
    return $self->schema->storage->dbh;
}

sub _build_operator_roles {
    my $self    = shift;

    # check if the expected key is present in the Session
    # NOTE: not having Roles is not the same as not having the key
    if ( !exists( $self->session->{acl}{operator_roles} ) ) {
        $self->logger->logdie( q/Session doesn't have a '{acl}{operator_roles}' key, can't find Operator Roles/ );
    }

    my $filtered_roles = filter_acl_roles_and_get_role_names( $self->session->{acl}{operator_roles} );
    return {
        # make sure all Roles are in Lowercase
        map { lc( $_ ) => 1 } @{ $filtered_roles }
    };
}

sub _build_url_restrictions {
    my $self    = shift;

    # Search all configured paths
    my @paths = $self->schema->resultset('ACL::URLPath')->all;

    # Flatten role restrictions to a hash
    my %restrictions;
    foreach my $path ( @paths ) {
        $restrictions{ $path->url_path } = [
            map { $_->authorisation_role } $path->authorisation_roles->all
        ];
    }

    return \%restrictions;
}

sub _build_can_build_main_nav_using_acl {
    my $self    = shift;

    # Return FALSE for any of the following reasons:
    #   * The Operator has NO Roles assigned to them.
    #   * The Operator's 'use_acl_for_main_nav' flag is FALSE.
    #   * The Global 'build_main_nav' settting in the 'ACL'
    #     System Config Group is 'off'.
    #   * The Operator has Roles, but NONE have been assigned
    #     any Options
    return 0    if ( !$self->number_of_roles_for_operator );
    return 0    if ( !$self->operator->use_acl_for_main_nav );
    return 0    if ( !use_acl_to_build_main_nav( $self->schema ) );

    # check that at least one of the Operator's
    # Roles has been assigned a Sub Section
    my $count   = $self->schema->resultset('ACL::LinkAuthorisationRoleAuthorisationSubSection')
                        ->search(
        {
            'LOWER(authorisation_role.authorisation_role)' => { IN => [ $self->list_of_roles_for_operator ] },
        },
        {
            join => 'authorisation_role',
        }
    )->count;
    return 0    if ( !$count );

    return 1;
}

sub _build__operator_for_log {
    my $self = shift;
    return $self->operator->id . ' - ' . $self->operator->username;
}


=head1 METHODS

=head2 operator_has_the_role

    $boolean = $self->operator_has_the_role( $role_name );

Returns TRUE or FALSE based on whether the Operator has the Role
passed in. This check is case insensative.

=cut

sub operator_has_the_role {
    my ( $self, $role ) = @_;

    return 0        if ( !$role );

    # all Roles are stored in Lowercase so change the case of the Role to match
    return ( exists( $self->operator_roles->{ lc( $role ) } ) ? 1 : 0 );
}

=head2 operator_has_role_in

    $boolean    = $self->operator_has_role_in( [ qw( role1 role2 ) ] );
            or
    $boolean    = $self->operator_has_role_in( 'role1' );

Returns TRUE or FALSE based on whether the Operator's list of Roles includes
any of the Roles that were passed in to check for.

    # if an Operator only has 'role1' then all of these will return TRUE
    $boolean = $self->operator_has_role_in( 'role1' );
    $boolean = $self->operator_has_role_in( [ qw( role2 role1 role3 ) ] );
    $boolean = $self->operator_has_role_in( [ qw( role4 role5 role1 ) ] );

    # if an Operator only has 'role1' then this will return FALSE
    $boolean = $self->operator_has_role_in( [ qw( role4 role5 role3 ) ] );

=cut

sub operator_has_role_in {
    my ( $self, $roles )    = @_;

    # No Roles passed then return FALSE
    return 0    if ( !$roles );

    # make sure $roles is an ArrayRef
    if ( ref( $roles ) && ref( $roles ) ne 'ARRAY' ) {
        $self->logger->logdie(
            "Roles passed in must be a Scalar or an Array Ref and NOT a '" . ref( $roles ) . "'"
            . " for '" . __PACKAGE__ . "->operator_has_role_in'"
        );
    }
    $roles  = [ $roles ]    if ( !ref( $roles ) );

    my $retval  = 0;

    ROLE:
    foreach my $role ( @{ $roles } ) {
        if ( $self->operator_has_the_role( $role ) ) {
            $retval = 1;
            last ROLE;
        }
    }

    return $retval;
}

=head2 operator_has_all_roles

    $boolean    = $self->test_operator_has_all_roles( [ qw( role1 role2 ) ] );
            or
    $boolean    = $self->test_operator_has_all_roles( 'role1' );

Returns TRUE or FALSE based on whether the Operator's list of Roles has
any of the Roles that were passed in to check for.

    # if an Operator has the Roles 'role1', 'role2', 'role3' & 'role4'
    # then these will return TRUE
    $boolean = $self->operator_has_all_roles( 'role1' );
    $boolean = $self->operator_has_all_roles( [ qw( role2 role1 role3 ) ] );
    $boolean = $self->operator_has_all_roles( [ qw( role4 role2 role1 ) ] );

    # but this will return FALSE
    $boolean = $self->operator_has_role_in( [ qw( role4 role5 role3 ) ] );

=cut

sub operator_has_all_roles {
    my ( $self, $roles )    = @_;

    # No Roles passed then return FALSE
    return 0    if ( !$roles );

    # make sure $roles is an ArrayRef
    if ( ref( $roles ) && ref( $roles ) ne 'ARRAY' ) {
        $self->logger->logdie(
            "Roles passed in must be a Scalar or an Array Ref and NOT a '" . ref( $roles ) . "'"
            . " for '" . __PACKAGE__ . "->operator_has_all_roles'"
        );
    }
    $roles  = [ $roles ]    if ( !ref( $roles ) );

    # if an Empty Array passed then return FALSE
    return 0    if ( !@{ $roles } );

    my $retval  = 1;

    ROLE:
    foreach my $role ( @{ $roles } ) {
        if ( !$self->operator_has_the_role( $role ) ) {
            $retval = 0;
            last ROLE;
        }
    }

    return $retval;
}

=head2 build_main_nav

    $hash_ref = $self->build_main_nav;

Returns a Hash Ref of Main Navigation Options which are then used to
build the Main Navigation for the page.

This will use the Operator's Roles to build the Main Navigation unless
the Attribute 'can_build_main_nav_using_acl' is FALSE.

=cut

sub build_main_nav {
    my $self    = shift;

    # check to see if using Roles to build the
    # Main Nav is available for the Operator
    if ( $self->can_build_main_nav_using_acl ) {
        # build the Main Nav based on the Operator's Roles
        $self->logger->debug( "Using Roles to Build Main Nav for: '" . $self->_operator_for_log . "'" );
        return $self->schema->resultset('ACL::AuthorisationRole')->get_main_nav_options(
            [ $self->list_of_roles_for_operator ],
        );
    }
    else {
        # else use the old way
        $self->logger->debug( "NOT Using Roles to Build Main Nav for: '" . $self->_operator_for_log . "'" );
        return build_nav( {
            dbh         => $self->dbh,
            operator_id => $self->operator->id,
        } );
    }
}

=head2 has_permission

    $boolean = $self->has_permission( $url_path );
        or
    $boolean = $self->has_permission( $url_path, {
        # optional arguments
        update_session => 1,
        can_use_fallback => 1,
    } );

Returns TRUE or FALSE depending on whether an Operator is authorised to access a URL.

If the URL is not in the 'acl.url_path' table OR has not had any Roles linked
to it then this method will return FALSE.

Pass the URL such as '/CustomerCare/OrderSearch' into the Method.

In order to maintain backward compatibility with how Access to pages was being
checked (which used the 'authorisation_sub_section' & 'authorisation_section'
tables to just check the first two parts of the URL - Section & Sub-Section) you
should use the 'can_use_fallback' optional argument which will change the behavior
of this method to the following:

    * If the URL Path has been defined AND linked to any Roles then check to
      see if the Operator has the correct Roles for the URL
    * If the URL Path has NOT been defined or NOT linked to any Roles then:
        * call 'can_build_main_nav_using_acl':
            * TRUE:  use Roles linked to the 'authorisation_sub_section' table
                     to see if the Operator is Authorised
            * FALSE: use the old 'operator_authorisation' table to see if
                     an Operator is Authorised

If you pass 'update_session' then the following key in the Session will be
updated with the value of '1': $session->{acl}{authorisation_granted}, if
the URL is authorised, see below for what 'update_session' does when the
'can_use_fallback' argument is passed.

If you pass 'can_use_fallback' then you can also pass the optional argument
'update_session' which will cause the Session's 'auth_level' and 'department_id'
keys to be populated. This is to maintain backward compatibility to how the old
way was used to decide if the Operator can access a Menu Option and so should
only be used when the Operator is first Authorised.


NOTE:
If you are working on the XT Access Controls project then you should never be
using 'can_use_fallback' when working on a page to check access to anything.
In practice this argument should only be used for Authorising Main Nav options
to maintain backward compatibility for pages that have not been dealt with
yet by the Access Controls project.


PLEASE BE AWARE that the 'can_use_fallback' & 'update_session' will be removed
once the XT Access Controls project has been completed as there will no longer
be a need for them.

=cut

sub has_permission {
    my ( $self, $url_path, $args ) = @_;

    die "Must pass a URL Path as a simple SCALAR to '" . __PACKAGE__ . "->has_permission'"
                    if ( ref( $url_path ) );
    $self->logger->debug( "Checking Permission for URL: '" . ( $url_path // 'undef' ) . "'" );

    my $authorised  = 0;

    return $authorised      if ( !defined $url_path || $url_path eq '' );

    # get all Roles that have access to the URL
    my $role_names = $self->schema->resultset('ACL::AuthorisationRole')
                                ->get_role_names_for_url_path( $url_path );

    if ( $role_names && @{ $role_names } ) {
        $authorised = ( $self->operator_has_role_in( $role_names ) ? 1 : 0 );
        if ( $authorised && $args->{update_session} ) {
            # this bit is here to work with the current way Authorisation
            # is granted and has to be maintained until the Access Controls
            # project is finished, when it is this 'if' can be removed
            # with no need to set anything in the Session
            $self->session->{acl}{authorisation_granted} = 1;
        }
        $self->logger->debug(
            "Using URL Path table to Authorise: '${url_path}'" .
            " for: '" . $self->_operator_for_log . "'" .
            " with result: '${authorised}'"
        );
    }
    elsif ( $args->{can_use_fallback} ) {
        # if NO Role Names were returned
        # AND the Fallback way can be used
        $authorised = $self->_fallback_check_authorised_access( $url_path, $args );
    }

    return $authorised;
}

=head2 update_roles

Updates the operators roles with a new list. The new list must be passed as
as array reference.

This will update both the XT::AccessControls operator_roles attribute and the
session->{acl}->{operator_roles} data.

=cut

sub update_roles {
    my ( $self, $roles ) = @_;

    die "You must pass a list of roles in an array ref"
        unless $roles && ref $roles eq 'ARRAY';

    # Update the list of roles in the session
    $self->session->{acl}->{operator_roles} = $roles;

    # and then clear the operator_roles attribute so it gets rebuild on use
    $self->_clear_operator_roles;

    return;
}

=head2 can_protect_sidenav

    $boolean = $self->can_protect_sidenav( { call_frame => 1 # call frame number } );
        or
    $boolean = $self->can_protect_sidenav( { url => '/Some/Url' } );

Use this method to determine if the Sidenav that is produced by a Handler
should be protected using ACL. This can be achieved in one of two ways.

Either by passing in the Call Frame number that will return the Handler
that is being used when this method uses the 'caller' function. This is
the prefered method to use for non-Catalyst Handlers.

This method will then look up the package name of the Handler to see if it
is in the 'ACL_Protected_Sidenav' config using the 'name' setting, if it is,
it will return TRUE else it will return FALSE.

Another way is to pass in the URL of the request for the Handler and then
to use that to search against the config section 'ACL_Protected_Sidenav'
using the 'url' setting, it it is, it will return TRUE else it will return
FALSE.

RegEx patterns can be used in either of the 'name' or 'url' config settings,
so that for example using '/Some/Url.*' would match against all URLs starting
with '/Some/Url' and a similar idea for Package Names when using the 'call_frame'
argument.


PLEASE BE AWARE that this method will be removed once the XT Access Controls
project has been completed as all Sidenavs will then be protected by ACL.

=cut

sub can_protect_sidenav {
    my ( $self, $args ) = @_;

    my $list_to_search;
    my $search_for;

    if ( my $call_frame = $args->{call_frame} ) {
        $list_to_search = config_var('ACL_Protected_Sidenav', 'name') // '';
        # get the package to look for
        $search_for     = ( caller( $call_frame ) )[0] // '';
    }
    elsif ( my $url = $args->{url} ) {
        $list_to_search = config_var('ACL_Protected_Sidenav', 'url') // '';

        if ( !$url ) {
            carp "No URL passed in to 'can_protect_sidenav'";
            return 0;
        }

        # make sure URL has leading '/'
        $url        = '/' . $url        if ( $url !~ m{^/} );
        $search_for = $url;
    }
    else {
        carp "Neither 'call_frame' or 'url' were passed into 'can_protect_sidenav'";
        return 0;
    }

    $list_to_search = ( ref( $list_to_search ) ? $list_to_search : [ $list_to_search ] );

    # check if $search_for is in the list
    my $result = (
        scalar(
            grep {
                $_ &&
                $search_for =~ m/\A${_}\Z/
            } @{ $list_to_search }
        )
        ? 1
        : 0
    );

    $self->logger->debug(
        "Checking if Sidenav is Protected for '${search_for}', result: '${result}'"
    );

    return $result;
}

#------------------------------------------------------------------------------

# private method to get the Authorisation Level Id for a Main
# Nav Option for the Operator, this is for backward compatibility
sub _get_auth_level_for_operator {
    my ( $self, $section, $sub_section )    = @_;

    return $self->schema->resultset('Public::OperatorAuthorisation')
                            ->get_auth_level_for_main_nav_option( {
            operator_id => $self->operator->id,
            section     => $section,
            sub_section => $sub_section,
        } );
}

# private method used by 'check_authorised_access' to fallback to
# if no Roles could be found that were linked to a URL path.
# When the XT Access Controls project is complete there will be no
# no need for this fallback and this method can be removed.
sub _fallback_check_authorised_access {
    my ( $self, $url_path, $args )  = @_;

    my $parsed_url  = parse_url_path( $url_path );
    my $section     = $parsed_url->{section};
    my $sub_section = $parsed_url->{sub_section};

    my $auth_level;
    my $authorised  = 0;

    # flag to indicate whether there is a need to
    # query the database again to get the Auth Level
    my $get_auth_level  = ( $args->{update_session} ? 1 : 0 );

    if ( $self->can_build_main_nav_using_acl ) {
        my $role_names = $self->schema->resultset('ACL::AuthorisationRole')
                                ->get_role_names_for_main_nav_option( $section, $sub_section );

        if ( $self->operator_has_role_in( $role_names ) ) {
            $authorised = 1;

            if ( $get_auth_level ) {
                # need to get the Authorisation Level, this is for backward
                # compatibility as there is no Auth Level in regards to Roles,
                # so the one assigned to the 'operator_authorisation' will be
                # used, if that doesn't exist then will default to Read-Only.
                $auth_level = $self->_get_auth_level_for_operator( $section, $sub_section )
                                        || $AUTHORISATION_LEVEL__READ_ONLY;
            }
        }

        $self->logger->debug(
            "Using Roles to Authorise Main Nav Option: '${section}/${sub_section}'" .
            " for: '" . $self->_operator_for_log . "'" .
            " with result: '${authorised}'"
        );
    }
    else {
        $authorised = $self->schema->resultset('Public::OperatorAuthorisation')
                            ->operator_has_permission( {
            operator_id => $self->operator->id,
            section     => $section,
            sub_section => $sub_section,
            # use the minimal Authorisation Level required
            auth_level  => $AUTHORISATION_LEVEL__READ_ONLY,
        } );
        $auth_level = $self->_get_auth_level_for_operator( $section, $sub_section )
                                                if ( $authorised && $get_auth_level );

        $self->logger->debug(
            "NOT Using Roles to Authorise Main Nav Option: '${section}/${sub_section}'" .
            " for: '" . $self->_operator_for_log . "'" .
            " with result: '${authorised}'"
        );
    }

    if ( $authorised && $args->{update_session} ) {
        $self->session->{auth_level}    = $auth_level;
        $self->session->{department_id} = $self->operator->department_id,
    }

    return $authorised;
}

