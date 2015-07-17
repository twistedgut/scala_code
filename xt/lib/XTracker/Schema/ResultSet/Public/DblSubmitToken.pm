package XTracker::Schema::ResultSet::Public::DblSubmitToken;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Logfile qw( xt_logger );

sub mark_as_used {
    my ( $self, $dbl_submit_token_seq) = @_;

    eval {
        $self->create({
            id          => $dbl_submit_token_seq,
        });
    };

    if ($@) {

        if ($@ =~ /duplicate key value violates unique constraint "dbl_submit_token_pk"/) {
            #xt_logger->info("Double Submit Token already used. post will fail (dbl_submit_token_seq: $dbl_submit_token_seq)");
            return 0;
        } else {
            die "Failed to mark dbl_submit_token_seq: $@";
        }
    }

    #xt_logger->debug("dbl_submit_token marked as used. (dbl_submit_token_seq: $dbl_submit_token_seq)");
    return 1;

}

1;
