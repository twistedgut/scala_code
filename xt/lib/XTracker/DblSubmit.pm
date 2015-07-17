package XTracker::DblSubmit;
use strict;
use warnings;

use XTracker::Database qw( get_database_handle );
use XTracker::Logfile qw( xt_logger );
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Error qw( xt_warn );
use XTracker::DblSubmitToken;
use XTracker::Handler;
use URI::Escape;

=item handler

If the submission is a POST, it ensures it has an unused dbl_submit_token attached
to it. If the token is missing or has already been used then the user is shown
an error page and apache is told to stop processing other requests in the nchain

=cut

sub handler {
    return DECLINED;
}

sub _test_submission {
    my $handler = shift;

    my $schema = $handler->schema();

    return 1 if ($handler->method() ne "POST");

    if (!exists($handler->{param_of}{'dbl_submit_token'})) {
        xt_logger->warn("dbl_submit_token is missing. user will be shown an error page");
        xt_warn("This page is missing a Double Submit token. Please report this issue to the Service Desk.\n");
        $handler->redirect_to($handler->{referer});
        return 0;
    }

    my $dbl_submit_token = uri_unescape($handler->{param_of}{'dbl_submit_token'});
    xt_logger->trace("Double Submit Token: $dbl_submit_token");

    # mark the token as empty so that it when other code iterates over XHandler params
    # dbl_submit_token does not show up
    delete $handler->{param_of}{'dbl_submit_token'};

    my $is_valid = 0;

    if (my $dbl_submit_token_seq = XTracker::DblSubmitToken->validate_token($dbl_submit_token, $schema)) {
        $is_valid = $schema->resultset('Public::DblSubmitToken')->mark_as_used($dbl_submit_token_seq);

        xt_logger->debug('cause of invalid token was that it was already marked as used in the database') if (!$is_valid);
    }

    if (!$is_valid) {
       xt_logger->warn("dbl_submit_token is invalid. user will be forwarded to an error page");
       xt_warn("This is a duplicate submission.\n");
       $handler->redirect_to($handler->{referer});
       return 0;
    }

    return 1;

}

1;
