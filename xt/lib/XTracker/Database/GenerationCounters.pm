package XTracker::Database::GenerationCounters;
use NAP::policy qw(exporter tt);

use Perl6::Export::Attrs;

sub _update_counters {
    my ($dbh, @names) = @_;
    # Increment the counter using a (cyclic) sequence to not have to
    # care about wrapping (not that a bigint will wrap any time soon)
    #
    # It doesnt matter that the values for each name are sparse, we
    # only care about whether they've changed. Each updated row gets a
    # new value from the sequence.
    return +{ map { @{$_} } @{ $dbh->selectall_arrayref(q{
        UPDATE generation_counter
        SET counter = nextval('generation_counter_seq')
        WHERE name = ANY(?)
        RETURNING name, counter
    }, {}, \@names) } };
}

sub _insert_counters {
    my ($dbh, @names) = @_;
    # unnest(array) returns a table with one row per element of the
    # array, allowing us to insert several rows in one go without
    # having to do a variable-length values (?),(?),... list
    return +{ map { @{$_} } @{ $dbh->selectall_arrayref(q{
        INSERT INTO generation_counter (name) SELECT unnest(?::text[])
        RETURNING name, counter
    }, {}, \@names ) } };
}

# http://www.depesz.com/2012/06/10/why-is-upsert-so-complicated/
sub increment_generation_counters :Export() {
    my ($dbh, @names) = @_;

    # First, update the counters of already-existing names
    my $values = _update_counters($dbh, @names);

    # Retry as long as there are some missing ones
    while (my @missing = grep { !exists $values->{$_} } @names) {
        # Create a savepoint so we don't abort the whole transaction
        # if the below insert fails due to duplicate key error
        $dbh->pg_savepoint("generation_counter");

        my $missing_values = try {
            # Try to insert the missing names
            _insert_counters($dbh, @missing);
        } catch {
            die $_ unless /duplicate key value violates unique constraint/;

            # Someone else inserted one or more of the names
            # concurrently, so roll back to the savepoint to revert
            # the aborted transaction state
            $dbh->pg_rollback_to("generation_counter");

            # Update the ones that were just added, and go around the
            # loop again to insert the remaining ones
            _update_counters($dbh, @missing);
        };

        # All done this time around, release the savepoint
        $dbh->pg_release("generation_counter");
        # Add the newly-inserted or -updated values to the set we have
        $values = +{ %{$values}, %{$missing_values} };
    }
    return $values;
}

sub get_generation_counters :Export() {
    my ($dbh, @names) = @_;

    return +{
        (map { $_ => -1 } @names), # fallback values
        (map { @{$_} } @{$dbh->selectall_arrayref( # stored values
            q{SELECT name, counter FROM generation_counter WHERE name = ANY(?)},
            {},
            \@names
        )}),
    }
}

sub get_changed_generation_counters :Export() {
    my ($dbh, $names) = @_;
    my $cond = join ' OR ', ('(name = ? AND counter != ?)') x keys %{$names};
    my %changed = map { @{$_} } @{
        $dbh->selectall_arrayref(
            qq{SELECT name, counter FROM generation_counter WHERE $cond},
            {},
            %{$names}
        )
    };
    return \%changed;
}

sub generations_have_changed :Export() {
    my ($dbh, $names) = @_;

    return !! %{get_changed_generation_counters($dbh,$names)};
}
