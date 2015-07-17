package XTracker::DblSubmitToken;

use strict;
use warnings;

use Digest::MD5 qw( md5_base64 );

# this would just be noise in a config file
my $XTRACKER_SECRET = 'jn432bk424432';

sub validate_token {
    my ($self, $dbl_submit_token, $schema) = @_;

    if ($dbl_submit_token =~ /(\d+):(.*)/) {

        my $dbl_submit_token_seq = $1;
        my $dbl_submit_hash = $2;

        my $hash_test = $self->make_hash($dbl_submit_token_seq);

        return $dbl_submit_token_seq if ($hash_test eq $dbl_submit_hash);
    }

    return 0;

}


=item generate_new_dbl_submit_token

Attached to XTracker::Handler->new() so that all requests
have a token attached if they wish to make a form post later.

=cut

sub generate_new_dbl_submit_token {
    my ($self, $schema) = @_;

    my $dbl_submit_token_seq = $self->next_val($schema);
    my $dbl_submit_hash = $self->make_hash($dbl_submit_token_seq);
    my $dbl_submit_token = "$dbl_submit_token_seq:$dbl_submit_hash";
    return $dbl_submit_token;

}

sub next_val {
    my ($self, $schema) = @_;
    return $schema->storage->dbh->selectrow_arrayref("SELECT nextval('dbl_submit_token_seq')")->[0];
}

sub make_hash {
    my ($self, $dbl_submit_token_seq) = @_;
    return md5_base64("$dbl_submit_token_seq:$XTRACKER_SECRET");
}

1;
