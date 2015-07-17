package XT::DC::Controller::Admin::UserRoles;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Try::Tiny;

use XTracker::Interface::LDAP;
use XTracker::Config::Local qw( config_var );
use XTracker::Logfile       qw( xt_logger );
use XTracker::Utilities     qw( running_in_dave );
use XT::AccessControls;

has acl => (
    is          => 'ro',
    writer      => '_set_acl',
    isa         => 'XT::AccessControls',
    init_arg    => undef,
);

has available_roles => (
    is          => 'ro',
    isa         => 'HashRef',
    init_arg    => undef,
    lazy_build  => 1,
    traits      => ['Hash'],
    handles     => {
        list_available_roles    => 'keys',
        role_exists             => 'exists',
    },
);

sub _build_available_roles {
    my $self = shift;
    my $ldap;
    my @roles;

    return try {
        $ldap = XTracker::Interface::LDAP->new();
        $ldap->connect;

        @roles = @{ $ldap->get_ldap_roles };
        return {
            map { $_ => 1 } @roles
        };
    }
    catch {
        warn "Cannot connect to LDAP service to get available roles - $_";
        return {};
    };

}

sub auto :Private {
    my ($self, $c) = @_;

    unless ( defined $c->session->{operator_id} && running_in_dave() ) {
        $c->res->redirect( '/Home' );
    }

    $c->stash(
        section             => 'Admin',
        subsection          => 'User Roles',
        current_sub_section => 'DAVE ONLY &#8226; Admin &#8226; User Roles',
        javascript          => [ 'admin_userroles.js' ],
    );

    if ( $c->model('ACL') ) {
        $self->_set_acl( $c->model('ACL') );
    }
}

sub index :Path('/Admin/UserRoles') :Args(0) {
    my ($self, $c) = @_;

    if ( $c->req->parameters->{'newroles'} ) {
        my %error;
        my @roles;

        my $role_prefix = config_var( 'ACL', 'role_parsing' )->{role_prefix};

        my $new_roles = ( ref $c->req->parameters->{'newroles'} eq 'ARRAY' ) ?
            $c->req->parameters->{'newroles'} :
            [ $c->req->parameters->{'newroles'} ];

        foreach my $role ( @$new_roles ) {
            if ( $self->role_exists($role) || $role =~ /\A\Q$role_prefix\E/i ) {
                push @roles, $role;
            }
            else {
                $error{$role}++;
            }
        }

        if ( ! keys %error ) {
            try {
                $self->acl->update_roles( \@roles );
                $c->finalize_session;
            }
            catch {
                $c->feedback_error( "Unable to update roles : $_" );
            }
            finally {
                $c->feedback_success( "Roles Updated" ) unless $@;
            };
        }
        else {
            $c->feedback_error( "Cannot update roles. These roles are not valid: " . join(' ', keys %error) );
            $c->stash( errors => \%error );
        }
    }

    $c->stash(
        template        => 'shared/admin/userroles.tt',
        current_roles   => [ $self->acl->list_of_roles_for_operator ],
        available_roles => [
                grep { ! defined $self->acl->operator_roles->{lc($_)} }
                    $self->list_available_roles
            ],
        session         => $c->session,
    );
}

__PACKAGE__->meta->make_immutable;

1;
