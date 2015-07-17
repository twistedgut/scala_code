package Test::XTracker::RequiresAMQ;
use NAP::policy "tt", 'test';
use File::Slurp;

if (not defined $ENV{XTDC_BASE_DIR}) {
    fail(q{XTDC_BASE_DIR is undefined});
    diag("did you remember to source xtdc.env?");
    done_testing;
    exit;
}

my $pidfile = "$ENV{XTDC_BASE_DIR}/t/tmp/active_mq_daemon.pid";

if (! -e $pidfile) {
    fail("file not found: $pidfile");
    diag("is the test AMQ consumer running?");
    done_testing;
    exit;
}

pass("found: $pidfile");

my $pid = read_file($pidfile);
my $exists = kill 0, $pid;
ok($exists, 'test AMQ consumer appears to be running');

# NOTE: don't use done_testing in this module; it reeally messes up the test
# count in the class you called it from
# e.g.
#     # Looks like you planned 2 tests but ran 1119.


=pod

=head1 NAME

Test::XTracker::RequiresAMQ - ensure an AMQ consumer appears to be running

=head1 SYNOPSIS

    #!perl
    # my test script
    ...
    use Test::XTracker::RequiresAMQ;
    # ...
    done_testing;

=head1 DESCRIPTION

Ever been bitten by this?

    #   Failed test 'test_packing_nonsticky died (Requested 1 file(s)
    #     not found in allowable time at
    #     .../xt/t/lib/Test/XT/Flow/WMS.pm line 89)'

How long did it take you to realise you'd forgotten to start your test AMQ
consumer?

As a test author you can help people track this down more quickly by using
this module in test scripts and classes that you know require AMQ consumption
to work correctly.

    use Test::XTracker::RequiresAMQ;

=head1 CAVEATS

=head2 Moving the pidfile

The test consumer script accepts a -p argument to specify a different location
for the pidfile.

This module currently has no way to determine if this has been used, and may
falsely report that you are not running the consumer

=head2 Permission to kill()

This module relies on 'kill 0'.

=over 4

'If SIGNAL is zero, no signal is sent to the process, but "kill" checks
whether it's possible to send a signal to it (that means, to be brief, that
the process is owned by the same user, or we are the super-user).'

=back

If you run your processes as mixed users you may be incorrectly told that your
consumer is not running.

=head1 AUTHOR

Chisel C<< <chisel.wright@net-a-porter.com> >>

=cut
