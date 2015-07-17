package Plack::Middleware::NAP::ClearSingletonDBH;

use NAP::policy "tt";

use parent 'Plack::Middleware';

use Plack::Util;
use XTracker::Database;

sub call {
    my ( $self, $env ) = @_;
    my $res = $self->app->($env);

    $self->response_cb($res, sub {
        XTracker::Database::clear_xtracker_schema();
        XTracker::Database::clear_xtracker_dbh_no_autocommit;
        return;
    });
}

1;
