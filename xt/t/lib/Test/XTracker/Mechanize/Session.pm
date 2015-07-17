package Test::XTracker::Mechanize::Session;

use NAP::policy "tt",     qw( test class );

=head1 NAME

Test::XTracker::Mechanize::Session

=head1 DESCRIPTION

Object to Get and Store a User's Session data.

=cut

use XTracker::Database ':common';

use Plack::Session::Store::DBI;


=head1 ATTRIBUTES

=head2 mech

Test::XTracker::Mechanize object.

=cut

has mech => (
    is       => 'ro',
    required => 1,
);

=head2 session_id

=cut

has session_id => (
    is          => 'rw',
    isa         => 'Str',
    lazy_build  => 1,
);

# private attribute for the Session Storage
has _session_store => (
    is         => 'ro',
    init_arg   => undef,
    lazy_build => 1,
);

# private attribute which holds the Session
# each time 'get_session' is called and is
# used by 'store' to save changes
has _session => (
    is  => 'rw',
    isa => 'HashRef',
);


#
# lazy build methods
#

sub _build_session_id {
    my $self    = shift;

    # extract session_id from cookie jar
    my ( $k )       = keys %{ $self->mech->{cookie_jar}{COOKIES} };
    my $session_id  = $self->mech->cookie_jar->{COOKIES}{ $k }{"/"}{plack_session}[1];

    return $session_id;
}

sub _build__session_store {
    my $self    = shift;

    return Plack::Session::Store::DBI->new(
        get_dbh => sub { xtracker_schema->storage->dbh },
    );
}


=head1 METHODS

=head2 get_session

    $hash_ref = $self->get_session();

Return the Session.

=cut

sub get_session {
    my $self    = shift;

    # set '_session' so that 'save_session'
    # is always using the latest version
    $self->_session( $self->_session_store->fetch( $self->session_id ) );

    return $self->_session;
}

=head2 save_session

    $self->save_session();

Save changes to the Session.

=cut

sub save_session {
    my $self    = shift;

    $self->_session_store->store( $self->session_id, $self->_session );

    return;
}

=head2 replace_acl_roles

    $self->replace_acl_roles( $array_ref_of_role_names );

This will update the Session's '{acl}{operator_roles}' value
with the list of Role Names passed in replacing the previous
value.

Passing in 'undef' to wipe out the Roles is allowed.

=cut

sub replace_acl_roles {
    my ( $self, $role_list )    = @_;

    die "Must pass in an Array Ref. of Role Names to '" . __PACKAGE__ . "->replace_acl_roles'"
                        if ( defined $role_list && !ref( $role_list ) eq 'ARRAY' );

    my $session = $self->get_session;

    return $self->_update_acl_roles( $role_list );
}

=head2 add_acl_roles

    $self->add_acl_roles( $array_ref_of_role_names );

This will add the list of Roles to the Session's '{acl}{operator_roles}'
key.

=cut

sub add_acl_roles {
    my ( $self, $role_list ) = @_;

    die "Must pass in an Array Ref. of Role Names to '" . __PACKAGE__ . "->add_acl_roles'"
                        if ( !ref( $role_list ) eq 'ARRAY' );

    my $session = $self->get_session;

    my @current_roles = @{ $session->{acl}{operator_roles} };

    ROLE:
    foreach my $role ( @{ $role_list } ) {
        # don't duplicate the Role Name
        next ROLE       if ( scalar( grep { lc( $role ) eq lc( $_ ) } @current_roles ) );

        # add the Role
        push @current_roles, $role;
    }

    # put the new list back in the Session
    return $self->_update_acl_roles( \@current_roles );
}

=head2 remove_acl_roles

    $self->remove_acl_roles( $array_ref_of_role_names );

This will remove the list of Roles from the Session's '{acl}{operator_roles}'
key.

=cut

sub remove_acl_roles {
    my ( $self, $role_list ) = @_;

    die "Must pass in an Array Ref. of Role Names to '" . __PACKAGE__ . "->remove_acl_roles'"
                        if ( !ref( $role_list ) eq 'ARRAY' );

    my $session = $self->get_session;

    my @current_roles = @{ $session->{acl}{operator_roles} };
    my @new_roles;

    ROLE:
    foreach my $role ( @current_roles ) {
        # if the Role is to be removed then don't proceed
        next ROLE       if ( scalar( grep { lc( $role ) eq lc( $_ ) } @{ $role_list } ) );

        # let the Role stay
        push @new_roles, $role;
    }

    # put the new list back in the Session
    return $self->_update_acl_roles( \@new_roles );
}


# helper to just update the
# roles to the list provided
sub _update_acl_roles {
    my ( $self, $role_list ) = @_;

    my $session = $self->get_session;
    $session->{acl}{operator_roles} = $role_list;
    $self->save_session;
    return;
}

