#!/usr/bin/env perl
use NAP::policy "tt", 'test';
package SchemaTest;

use Test::DBIx::Class::Schema 0.01013;
use base 'Test::DBIx::Class::Schema';


use XTracker::Database;

sub new {
    my ($proto, $options) = @_;

    if (exists $options->{dsn_from}) {
        # yes totally wrong to use a "private" method - CCW :)
        my $params = XTracker::Database::_db_connect_params(
            {
                name       => $options->{dsn_from},
                autocommit => 1,
            }
        );
        $options->{dsn} = XTracker::Database::_connection_string( $params );
        $options->{username} = $params->{db_user} || undef;
        $options->{password} = $params->{db_pass} || undef;
        # make it an is() test for missing tests, diag() no longer acceptable
        # (except for the pesky voucher-po ... that needs to be resolved, but
        # until it is we'll let it diag())
        $options->{test_missing} =
            defined $options->{fail_on_missing}
                ? delete $options->{fail_on_missing}
                : 1;
    }

    my $self = Test::DBIx::Class::Schema::new($proto, $options);

    return $self;
}

1;
