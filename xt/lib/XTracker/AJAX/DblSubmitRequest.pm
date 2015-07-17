package XTracker::AJAX::DblSubmitRequest;

use XTracker::DblSubmitToken;
use XTracker::Handler;
use XTracker::Logfile 'xt_logger';
use JSON;
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Config::Local qw( config_var );
use URI::Escape;

use strict;
use warnings;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema  = $handler->{schema};

    my @tokens;

    my $tokens_to_generate = config_var( 'dbl_submit_tokens_to_generate' ) || 5;

    for (1..$tokens_to_generate) {
        my $dbl_submit_token = XTracker::DblSubmitToken->generate_new_dbl_submit_token(
            $schema,
        );

        push(@tokens, uri_escape($dbl_submit_token));
    }

    my ($first_t, $last_t) = ($tokens[0], $tokens[-1]);
    xt_logger->info("token batch requested. returning: $first_t -> $last_t");

    $handler->{request}->print(encode_json(\@tokens));
    return OK;

}

1;
