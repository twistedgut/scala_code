package Plack::Middleware::DefaultContentType;
use strict;
use warnings;
use parent 'Plack::Middleware';
use Plack::Util;

sub call {
    my ($self, $env) = @_;
    my $res = $self->app->($env);

    $self->response_cb($res, sub {
        my $res = shift;
        my $h = Plack::Util::headers($res->[1]);

        if (not $h->get('content-type')) {
            $h->set('content-type' => 'text/plain');
        }
    });
}

1;
