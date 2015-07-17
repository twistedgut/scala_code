package XTracker::Admin::UserClone;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Database;
use XTracker::Database::Operator qw( :common );
use XTracker::Error;
use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;

sub handler {
    # get a handler and set up all the common stuff
    my $handler = XTracker::Handler->new( shift );
    my $return_status;

    # let people navigate back to the user list
    $handler->{data}{sidenav} = [
        { "None" => [
                { 'title' => 'Back to User List', 'url' => "/Admin/UserAdmin" }
            ]
        }
    ];

    # enable YUI goodness
    $handler->{data}{yui_enabled} = 1;
    # include the auto-complete js file
    $handler->{data}{js} = [
        '/javascript/yui_autocomplete.js',
    ];

    # if we have any params we should probably work out what to do with them
    if (exists $handler->{param_of}) {
        #xt_logger->debug( pp($handler->{param_of}) );

        # we should see a 'form_submit' parameter, if not, I have no idea what
        # crazy stuff someone is trying to do here
        if (defined $handler->{param_of}{form_submit}) {
            $return_status = clone_user_submit( $handler );
        }
        else {
            xt_die( q{expected param not found - what are you trying to do?} );
        }
    }

    # otherwise it's just a page/form view for filling in
    else {
        #xt_logger->debug( q{no params spotted} );
        # set the template to use
        $handler->{data}{content} = 'shared/admin/cloneuser.tt';
    }

    if (defined $return_status) {
        if (REDIRECT == $return_status) {
            return REDIRECT;
        }
    }

    $handler->process_template( undef );
    return OK;
}

sub clone_user_submit {
    my $handler = shift;
    my $param_of = $handler->{param_of}; # less typing
    my $session = XTracker::Session->session();
    my $new_id;

    # make sure we have expected formdata
    if ($param_of->{full_name} =~ m{\A\s*\z}xms) {
        xt_warn( q{You need to provide the user's full name} );
    }
    if ($param_of->{username} =~ m{\A\s*\z}xms) {
        xt_warn( q{You need to provide the user's intended username} );
    }
    if ($param_of->{clone_from_id} =~ m{\A\s*\z}xms) {
        xt_warn( q{You need to select whose permissions you're cloning the new user from} );
    }

    # if we don't have any errors, try the cloning operation
    if (not xt_has_errors()) {
        $new_id = clone_user( $handler );
    }

    # if we've got any errors we'll need to redisplay the form
    if (xt_has_errors()) {
        # put form data into the form_data stash for repopulation
        $session->{stash}{form_data} = $handler->{param_of};
        # set the template with the form
        $handler->{data}{content} = 'shared/admin/cloneuser.tt';
    }
    else {
        return $handler->redirect_to( q{/Admin/UserAdmin/Profile/} . $new_id );
    }

    return;
}

sub clone_user {
    my $handler = shift;
    my $param_of = $handler->{param_of}; # less typing
    #xt_logger->debug( pp($param_of) );
    my ($current_operator, $userinfo, $new_operator, $new_id);

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    my $guard = $schema->txn_scope_guard;
    # step 1 - get the details/permissions of existing user
    $current_operator = get_operator_by_id( $dbh, $param_of->{clone_from_id} );

    # step 2 - create the new user
    # make sure we haven't already used that username
    $userinfo = get_operator_by_username( $dbh, $param_of->{username} );
    if (defined $userinfo) {
        xt_warn( q{That username has already been used} );
        return;
    }

    xt_logger->debug( pp($param_of) );

    # wrap the database bits up in a transaction
    eval {
        # ok, let's create a new user (with no permissions yet)
        $new_operator = {
            name            => $param_of->{full_name},
            username        => $param_of->{username},
            email_address   => $param_of->{email_address},
            auto_login      => $current_operator->{auto_login},
            disabled        => $current_operator->{disabled},
            department_id   => $current_operator->{department_id},
        };
        $new_id = create_new_operator( $dbh, $new_operator );

        # step 3 - clone the permissions
        copy_operator_permissions( $dbh, $current_operator->{id}, $new_id );

        # commit all our changes
        $guard->commit;
    };
    if ($@) {
        xt_warn( $@ );
        xt_logger->warn( $@ );
    }

    return $new_id;
}

1;
