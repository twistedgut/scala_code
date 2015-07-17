package XT::DC::Controller::Root;
# vim: set ts=4 sts=4 sw=4:
use NAP::policy "tt", 'class';
use Data::Dumper;
use namespace::autoclean;
use MIME::Base64;
use XTracker::Config::Local qw( config_var );
use XTracker::DblSubmitToken;
use XTracker::Logfile qw(xt_logger);
use XTracker::Session;
use URI::Escape;
use Storable qw(thaw);
use XT::AccessControls::InsecurePaths 'permitted_insecure_path';

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(

  # Sets the actions in this controller to be registered with no prefix
  # so they function identically to actions created in MyApp.pm
  namespace => '',

  # Configs for Action::REST
  map => {
    # mime type => seriazlier class
    'application/json' => 'JSON'
  },
  stash_key => 'json',
  default => 'application/json',
);

=head1 NAME

XT::DC::Controller::Root - Root Controller for XT::DC

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub auto : Private {
    my ($self, $c) = @_;

    # We're going to enforce authorisation but only if not an /api/* url
    unless ( permitted_insecure_path( $c->request->path ) ) {
        # If the operator is a disabled account logout
        my $user_id = $c->session->{user_id};
        if ( ! $user_id ) {
            xt_logger->warn( 'Attempt to access XT::DC without user_id in session' );
            $self->redirect_to_logout($c);
            return 0;
        }

        my $operator = $c->model('DB::Public::Operator')->search( { 'LOWER(username)' => lc( $user_id ) } )->first;
        if ( ! $operator ) {
            xt_logger->warn( "Attempt to access XT::DC with unknown username $user_id" );
            $self->redirect_to_logout($c);
            return 0;
        }
        else {

            if ( $operator->disabled ) {

                xt_logger('UserAccess')->warn(
                    sprintf 'ACCESS DENIED: REASON="%s" OPERATOR="%s" USER="%s" SESSION="%s"',
                        'DISABLED ACCOUNT',
                        ($operator->id // "[* UNKNOWN OPERATOR *]"),
                        ($operator->username // "[* UNKNOWN OPERATOR *]"),
                        ($c->session->{_session_id}//'[* NO SESSION *]')
                    );

                # Add disabled account flag to session
                $c->session->{disabled_account} = 1;

                $self->redirect_to_logout($c);
                return 0;
            }
        }
    }

    # add the Catalyst logo in the footer
    $c->stash( catalyst_powered => 1 );

    # success - continue as normal
    return 1;
}

sub redirect_to_logout : Private {
    my ($self, $c) = @_;
    $c->res->redirect( $c->request->base .'logout' );
    $c->detach();
}

sub default :Path {
    my ( $self, $c ) = @_;
    $c->res->status( 404 );
    $c->res->body('404 not found');
    $c->res->content_type('text/plain');
}

sub _check_dbl_submit_token {
    my ($self, $c) = @_;

    xt_logger->warn('DEPRECATED: _check_dbl_submit_token()');
    return;
}

sub _generate_new_dbl_submit_token {
    my ($self, $c) = @_;

    xt_logger->warn('DEPRECATED: _generate_new_dbl_submit_token()');
    return;
}

=head2 serialize

 $c->stash(json => { x => [ 1, 2, 3 ] });
 $c->forward('/serialize');

A replacement for an end action that will serialize the contents of the C<json>
stash key to JSON based on the C<Accept:> headers sent by the client. If you
use jQuery's C<$.getJson()> or C<$.post(url, cb, 'json')> they will be
automatically set correctly.

=cut

sub begin : Private {
    my ($self, $c) = @_;

    # put the ACL into the 'XTracker::Schema' class
    my $schema = $c->model('DB')->schema;
    $schema->clear_acl;     # make sure it is empty
    if ( my $acl = $c->model('ACL') ) {
        $schema->set_acl( $acl );
    }
}

sub serialize : Private {
    my ($self, $c) = @_;
    $c->forward('/serializer');
}

sub serializer : ActionClass('Serialize') {}

=head2 json

Any action chained after this will use the JSON view.

=cut

sub json : Chained PathPart CaptureArgs(0) {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';
}

=head2 json_get_operators

Do a search on operators by name on the value for the 'C<query>' GET paramter.
This is used for the YUI autocomplete widget (which in XT is actually hardcoded
to work with operators, so it's probably misnamed).

=cut

sub json_get_operators : Chained('json') PathPart('operators') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{json_data}{ResultSet}{Result} = [
        map { +{
            id            => $_->id,
            name          => $_->name,
            email_address => $_->email_address,
            department    => $_->department ? $_->department->department : 'Unknown Department',
        } } $c->model('DB::Public::Operator')->search(
            { name => { ilike => $c->req->query_params->{query} . q{%} } },
            {
                columns      => [qw/id name email_address department.department/],
                join         => 'department',
                order_by     => 'name',
            }
        )->all
    ];
}

sub app_version :Path('version') :Args(0) {
    my ($self, $c) = @_;
    $c->response->body( $c->session->{application}{version}{string} || 'error: no version' );
}

sub end : Private {
    my ($self, $c) = @_;

    $c->forward('render');

    # this DTRT for people that are using xt_info() etc in Catalyst based
    # handlers
    # This is "wrong" and we ought to find a sane way to encourage them to use
    # $c->feedback_info() etc

    # DO NOT DO THIS FOR A NOT_FOUND OR REDIRECT! WE WANT THE DATA TO STAY TO
    # BE DISPLAYED IN AN ACTUAL PAVE VIEW
    my $xt_error_data;
    if ($c->response->status !~ /^(?:30[23]|404)$/) {
        $xt_error_data = XTracker::Session::prepare_xt_error_for_view(
            $c->session
        );
        $c->stash( xt_error => $xt_error_data )
            if (defined $xt_error_data);
    }

    # We go through the end() method, even if we're a 404 and handing on to
    # legacy-xt to see if it handles the request
    # After speaking to gianni we'll only warn on 2xx and 3xx responses
    if (defined $xt_error_data and $c->response->status =~ /^[23]/) {
        # let people know they're using xt_info() and friends when they ought not
        warn 'DEPRECATED: use of XTracker::Error::xt_*() method under XT::DC' .qq{\n};
        given ($xt_error_data->{message}) {
            when (exists $_->{INFO}) {
                warn 'DEPRECATED: use $c->feedback_info() instead of xt_info()' . qq{\n};
                continue;
            }
            when (exists $_->{WARN}) {
                warn 'DEPRECATED: use $c->feedback_warn() instead of xt_warn()' . qq{\n};
                continue;
            }
            when (exists $_->{SUCCESS}) {
                warn 'DEPRECATED: use $c->feedback_success() instead of xt_success()' . qq{\n};
                continue;
            }
            when (exists $_->{FATAL}) {
                warn 'DEPRECATED: use $c->feedback_fatal() instead of xt_die()' . qq{\n};
                continue;
            }
        }
        warn(Dumper($xt_error_data->{message}) . qq{\n});
    }

    return if (!$c->res->output || $c->res->content_type ne 'text/html');

    $c->fillform(($c->stash->{formdata}||{}), { fill_password => 0 });
}

sub render : ActionClass('RenderView') {}

=head1 AUTHOR

Rob Edwards,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
