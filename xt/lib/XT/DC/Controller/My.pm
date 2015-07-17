package XT::DC::Controller::My;
use NAP::policy "tt", 'class';

BEGIN {extends 'Catalyst::Controller'; }

use XT::DC::Handler;
use XTracker::Error;

sub my_preferences : Chained('/') PathPart('My/UserPref') Args(0) {
    my ( $self, $c ) = @_;

    my $handler = XT::DC::Handler->new({context => $c});
    my $schema  = $handler->schema;

    my $operator = $schema->resultset('Public::Operator')->find($handler->operator_id);
    # form submission
    if ($c->request->method and 'POST' eq $c->request->method) {
        $operator->update_or_create_preferences( $c->req->body_parameters );

        # clear the preferences in the session so they get picked up the next time a user clicks on anything
        delete $c->session->{op_prefs};

        $c->feedback_success('Preference Updated');
    }

    $c->stash(
        template        => 'shared/admin/userpref.tt',
        section         => 'My Preferences',
        sidenav         => [{ 'None' => [ { 'title' => 'Home', 'url' => '/Home' } ] }],

        user_info => {
            operator    => $operator,
            department  => $schema->resultset('Public::Department')->find($handler->department_id),
        },
        user_pref       => $operator->operator_preference,
        user_auth       => $operator->authorisation_as_hash,
        channels        => $schema->resultset('Public::Channel')->get_channels(),
    );

    return;
}
