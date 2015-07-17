package XT::DC::Controller::Admin::ACLMainNavInfo;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

use XTracker::Config::Local         qw( use_acl_to_build_main_nav );
use XTracker::Logfile               qw( xt_logger );

use Try::Tiny;
use Carp;
use JSON::XS;

=head1 NAME

XT::DC::Controller::Admin::ACLMainNavInfo

=head1 DESCRIPTION

Controller for /Admin/ACLMainNavInfo used to findout all available authorisation_roles
and corresponding Nav options

=head1 METHODS

=over

=item B<root>

Beginning of the chain for Admin/ACLMainNavInfo, containing common tasks for all actions.

=cut

# ----- common -----

sub root :Path('/Admin/ACLMainNavInfo') :Args(0) {
    my ($self, $c) = @_;

    $c->check_access('Admin', 'ACL Main Nav Info');
    my $schema = $c->model('DB')->schema;

    $c->stash(
        section     => 'Admin',
        subsection  => 'ACL Main Nav Info',
        template    => 'shared/admin/aclnavinfo.tt',
        css         => [ '/css/acl_mainnavinfo.css', '/css/jquery.jqtree.css'],
        js          => [ '/javascript/acl_mainnavinfo.js','/javascript/jquery.tree.jquery.js' ],
    );


    my $nav_options = $schema->resultset('Public::AuthorisationSubSection')->get_all_main_nav_options;
    my $user_roles  = $schema->resultset('ACL::AuthorisationRole')->get_all_roles;

    $c->stash(
        nav_options => $nav_options,
        user_roles  => $user_roles,
    );

    if ( $c->req->parameters->{'user_roles'} ) {
        my $roles = ( ref $c->req->parameters->{'user_roles'} eq 'ARRAY' ) ?
            $c->req->parameters->{'user_roles'} :
            [ $c->req->parameters->{'user_roles'} ];
        my $result = [];
        $result = $schema->resultset('ACL::AuthorisationRole')->get_main_nav_options_for_ui( $roles );

        $c->stash (
            result_title    => 'Navigation Menu',
            result          => JSON::XS->new->pretty->encode($result),
            collapse        => 1,
            selection_list  => join(',', @{$roles} )
        );
        return;

    };

    if ( $c->req->parameters->{'nav_options'} ) {
        my $options = ( ref $c->req->parameters->{'nav_options'} eq 'ARRAY' ) ?
            $c->req->parameters->{'nav_options'} :
            [ $c->req->parameters->{'nav_options'} ];
        my $result = $schema->resultset('Public::AuthorisationSubSection')->get_user_roles_for_ui($options);

        $c->stash(
            result_title    => 'User Roles',
            result          => JSON::XS->new->pretty->encode($result),
            collapse        => 0,
            selection_list  => join(',', @{$options}),
        );
        return;
    };

    return;
}


1;
