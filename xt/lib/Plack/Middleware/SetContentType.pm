package Plack::Middleware::SetContentType;
use NAP::policy "tt";
use parent 'Plack::Middleware';
use Plack::Util;

sub call {
    my ($self, $env) = @_;
    my $res = $self->app->($env);

    $self->response_cb($res, sub {
        my $res = shift;
        my $h = Plack::Util::headers($res->[1]);

        given ($env->{HTTP_X_REQUESTED_WITH}) {
            when('XMLHttpRequest') {
                $h->set('content-type' => 'application/json');
            }

            default {
                # don't interfere
            }
        }
    });
}

1;
