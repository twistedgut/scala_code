package XT::Plack::CSRF;
use NAP::policy "tt";

use HTTP::Status qw(:constants);

=head1 NAME

XT::Plack::CSRF - CSRF related functionality

=head1 METHODS

=head2 handle_csrf ($env)

This is the C<sub()> that's called in the C<blocked> option for
L<Plack::Middleware::CSRFBlock>.

If the request has an HTTP_REFERER we set an C<xt_warn()> message for the user
and send them back to where they came from.

If, for some strange reason, the request does not have an HTTP_REFERER a
plain-text message is shown.

No form processing takes place.

=head3 Using xt_warn

Because this is a standalone PSGI application outside the scope of the normal
application we don't have the same easy ways to manipulate the session data and
user feedback messages.

As we know a little about the underlying modules (L<XTracker::Session> and
L<XTracker::Error>) we can take advantage of some of the leaky behaviour in
them. This may be prone to breakage if we drastically change the way we handle
either of these features.

=cut
sub handle_csrf {
    my ($env) = @_;

    # TODO: this could be cleaned up a bit, and use the looks_like_ajax sub
    # that's $somewhere-else
    use Plack::Request;
    my $req = Plack::Request->new($env);
    my $header  = $req->headers->header('X-Requested-With') // '';
    my $looks_like_ajax = ( lc( $header ) eq 'xmlhttprequest' ? 1 : 0 );
    if ( $looks_like_ajax ) {
        # get a new token to pass back to the AJAX call
        my $csrf_token = $env->{'psgix.session'}{csrf_token};
        return [
            HTTP_UNAUTHORIZED,
            [ 'Content-Type' => 'application/json' ],
            [ '{"error":"CSRF Behaviour Detected. AJAX POST Aborted","csrf_token":"' . $csrf_token . '"}' ]
        ];
    }

    # we ought to be able to redirect back to our referererer
    if ($env->{HTTP_REFERER}) {
        # grab the plack session
        require Plack::Session;
        my $session = Plack::Session->new($env)->session;

        # inject it into XTracker::Session
        require XTracker::Session;
        $XTracker::Session::SESSION = $session;

        # use xt_warn() to display the error message to the user
        require XTracker::Error;
        XTracker::Error::xt_warn('CSRF Behaviour Detected. Form Submission Aborted.');

        # redirect the user back to where they came from
        [HTTP_SEE_OTHER, [ Location => $env->{HTTP_REFERER} ], []];
    }
    else {
        my $body = 'CSRF Detected. No HTTP_REFERER. Action aborted.';
        [HTTP_FORBIDDEN, ['Content-Type' => 'text/plain', 'Content-Length' => length($body)], [$body]];
    }
}


=head1 AUTHOR

Chisel C<< <chisel.wright@net-a-porter.com> >>
