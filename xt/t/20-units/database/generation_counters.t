#!/usr/bin/env perl
use NAP::policy qw(test tt);
use POSIX ':sys_wait_h';
use Test::SharedFork;
use Test::Fatal;
use Test::XTracker::Data;
use Time::HiRes qw(gettimeofday usleep);

use ok 'XTracker::Database::GenerationCounters', qw(:ALL);

my $schema = Test::XTracker::Data->get_schema;

sub generation_hash { +{ map { $_ => re(qr/\A-?[0-9]+/) } @_ } }

$schema->txn_do(sub {
    $schema->resultset("Public::GenerationCounter")->delete;
    my $dbh = $schema->storage->dbh;

    my @names1 = qw(foo bar baz);
    my @names2 = qw(bar baz zoot);

    my $original = get_generation_counters($dbh, @names1);

    cmp_deeply($original, generation_hash(@names1), "initial states");

    my $updated = increment_generation_counters($dbh, @names2);

    cmp_deeply($updated, generation_hash(@names2), "incremented states");

    ok(generations_have_changed($dbh, $original), "some generations have changed");
    ok(generations_have_changed($dbh, { $_ => $original->{$_} }), "$_ generation has changed")
        foreach qw(bar baz);
    ok(!generations_have_changed($dbh, { $_ => $original->{$_} }), "$_ generation hasn't changed")
        foreach qw(foo);

    $schema->txn_rollback;
});

my %children;
my $ppid = $$;
foreach (1..10) {
    if (my $pid = fork) {
        $children{$pid} = undef;
    } elsif (defined $pid) {
        test_counters($ppid);
        exit 0;
    } else {
        die "fork failed: $!\n";
    }
}

my @children = keys %children;
while (keys %children) {
    my $dead_child = wait;
    next if $dead_child <= 0; # interrupted by a signal

    delete $children{$dead_child};

    my $exit_code = ${^CHILD_ERROR_NATIVE};
    if (WIFEXITED($exit_code)) {
        my $status = WEXITSTATUS($exit_code);
        is($status, 0, "child $dead_child exited successfully")
            or diag "exit status: $status";
    }
    elsif (WIFSIGNALED($exit_code)) {
        my $signal = WTERMSIG($exit_code);
        fail("child $dead_child exited successfully");
        diag "killed by signal: $signal";
    }
}

# Clean up after ourselves
$schema->resultset("Public::GenerationCounter")->search({
    name => [ @children, $ppid ],
})->delete;

sub test_counters {
    my ($shared) = @_;
    my $own = $$;
    my $cs = $schema->source("Public::GenerationCounter");
    my $original = $cs->get_counters($shared, $own);

    # sleep until the next whole second to sync up with the other
    # children and maximise the chance of collisions
    my (undef, $usec) = gettimeofday;
    usleep(1e6 - $usec);
    for (1..10) {
        is exception {
            my $incremented = $schema->txn_do(sub {
                $cs->increment_counters($shared, $own);
            });
            isnt( $incremented->{$own}, $original->{$own}, "own counter incremented ($own)" );
            isnt( $incremented->{$shared}, $original->{$shared}, "shared counter incremented ($shared)" );
            ok( $cs->have_changed($original), "counters have changed in db ($own)" );
            $original = $incremented;
        }, undef, "concurrent update lives ($own)"
    }
}

done_testing();
