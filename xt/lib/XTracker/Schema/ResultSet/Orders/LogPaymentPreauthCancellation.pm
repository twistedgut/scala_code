package XTracker::Schema::ResultSet::Orders::LogPaymentPreauthCancellation;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Moose;
with 'XTracker::Schema::Role::ResultSet::MovePaymentLogs';


# this returns a set of records that the supplied
# Pre-Auth ref was succesfully Cancelled
sub get_preauth_cancelled_success {
    my ( $rs, $preauth_ref )    = @_;

    my $log_rs = $rs->search(
        {
            cancelled            => 1,
            preauth_ref_cancelled=> $preauth_ref,
        },
    );

    return $log_rs;
}


# this returns a set of records that the supplied
# Pre-Auth ref was NOT succesfully Cancelled
sub get_preauth_cancelled_failure {
    my ( $rs, $preauth_ref )    = @_;

    my $log_rs = $rs->search(
        {
            cancelled            => 0,
            preauth_ref_cancelled=> $preauth_ref,
        },
    );

    return $log_rs;
}


# this returns a set of records that the supplied
# Pre-Auth ref has attempted to be cancelled
sub get_preauth_cancelled_attempts {
    my ( $rs, $preauth_ref )    = @_;

    my $log_rs = $rs->search(
        {
            preauth_ref_cancelled=> $preauth_ref,
        },
    );

    return $log_rs;
}

1;

