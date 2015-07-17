package Plack::App::XT::Progressive;
use NAP::policy "tt";

use parent 'Plack::Component';
use Plack::Response;

use XT::DC;
use HTTP::Status qw(:constants);
use Plack::App::FakeModPerl1;

sub prepare_app {
    my $self = shift;

    $self->{xtdc} = XT::DC->psgi_app;

    return;
}

sub call {
    my ($self, $env) = @_;

    # let catalyst have a go first
    my $response = $self->{xtdc}->($env);

    $self->response_cb($response,sub { $self->_postprocess_response($env,@_) });
}

sub _postprocess_response {
    my ($self,$env,$response) = @_;
    my $handled_by;

    # if we got a NOT_FOUND from the catalyst app, pass through to the (legacy)
    # XT code
    if (HTTP_NOT_FOUND eq $response->[0]) {
        @$response = @{Plack::App::FakeModPerl1::handle_psgi(
            $env,
            $ENV{XTDC_BASE_DIR} . '/conf/xt_location.conf',
        )};
        $handled_by = 'Plack::App::FakeModPerl1';
    }
    else {
        # cf,if we didn't 404 XT::DC handled the response, add a header in
        # case we want to debug the source of responses later
        $handled_by = 'XT::DC';
    }

    # only set our custopm header if something chose to handle the response
    if (HTTP_NOT_FOUND ne $response->[0]) {
        push @{$response->[1]},
            ('X-Handled-By', $handled_by);
    }

    return;
}

1;

=pod

=head1 NAME

Plack::App::XT::Progressive - a combined Catalyst/MP1 plack-app

=head1 DESCRIPTION

This module provides a Plack application that responds 'correctly' to requests for both
old-modperl-XT and new-catalyst-XT URIs.

=head1 EXPLANATION

This module exists to assist in unpicking the XT::DC Catalyst appliction out
from the guts of the mod_perl1 XT chain.

Because we'd like the Catalyst application to grown and become the main area
of code, we check this code first to see if it will dispatch the requested
URI. If it returns a HTTP_NOT_FOUND we pass the request on to our faked
mod_perl1.

If they both return HTTP_NOT_FOUND we let the status propagate back up the
stack and get dealt with in a normal fashion - e.g. 404.html

=head1 CUSTOM RESPONSE HEADER

In case it's useful, when one of our sub-applications handles the request we
add a custom header, C<X-Handled-By>, to the HTTP response.

=head1 PERFORMANCE

If it transpires that there's a performance degredation always calling the
Catalyst dispatcher first, it should be trivial to reverse the order we call
each sub-application.

Hopefully this won't be required.

=head1 AUTHOR

Chisel Wright << <chisel.wright@net-a-porter.com> >>

=cut
