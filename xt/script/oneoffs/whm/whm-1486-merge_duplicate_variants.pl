#!/opt/xt/xt-perl/bin/perl
use NAP::policy 'tt';
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/schema_handle get_database_handle/;
use XTracker::Config::Local 'config_var';

=head1 disclaimer

This is my worst code to date. This for a run-once script with
exceptionally lazy flow control, bad function/variables names
and it has to requery the variant table multiple times for the
same data.

however it should work correctly and safely.

=cut

my $fulcrum_dbh = get_database_handle({ name => 'Fulcrum' });
my $dbh = get_database_handle({ name => 'xtracker', type => 'transaction' });

my $rows_done = 0;
my $total_rows = 0;

my $write_sql_to_file = 0;   ## TOGGLE THIS TO CHANGE BEHAVIOUR
my $filename = 'generatedsql.sql';

=head2 TransactionAwareTarget

A role allowing the application to produce its output in different ways

=cut

package TransactionAwareTarget {
    use Moose::Role;
    requires 'begin';
    requires 'write_sql_fix';
    requires 'write_note';
    requires 'write_stdout';
    requires 'commit';
    requires 'finished';
};

=head2 LiveDBWriter

if $write_sql_to_file is set to false, the application will use a
LiveDBWriter object in order to fix data in realtime against a database.

=cut

package LiveDBWriter { ## no critic(ProhibitMultiplePackages)
    use Moose;
    with 'TransactionAwareTarget';

    sub begin {}
    sub commit {
        print("EXEC: commit;\n");
        $dbh->commit();
    }

    sub rollback {
        print("EXEC: rollback;\n");
        $dbh->rollback();
    }

    sub write_sql_fix {
        my ($self, $sql_statement) = @_;

        print("EXEC: $sql_statement\n");
        my $sth = $dbh->prepare($sql_statement);
        $sth->execute();
        print("RECORDS AFFECTED: ". $sth->rows . "\n");
        die("Generated a redundant SQL statement, possible sign of bad logic\n") if ($sth->rows == 0);
    }

    sub write_note {
        my ($self, $text) = @_;
        print "$text\n";
    }

    sub write_stdout {}
    sub finished {}

};

=head2 LiveDBWriter

if $write_sql_to_file is set to true, the application will use this
FileWriter object in order to fix data in SQL file.

=cut

package FileWriter { ## no critic(ProhibitMultiplePackages)
    use Moose;
    with 'TransactionAwareTarget';

    has 'file_handle' => (is => 'rw');
    has 'transaction' => (is => 'rw');

    sub BUILD {
        my $self = shift;
        open(my $fh, '>', $filename);
        $self->file_handle($fh);
        $self->transaction([]);
    }

    sub begin {
        shift->write_sql_fix("begin;\n");
    }

    sub commit {
        my $self = shift;
        print { $self->file_handle } "$_\n" foreach @{ $self->transaction };
        print { $self->file_handle } "commit;\n";
        $self->transaction([]);
    }

    sub rollback {
        shift->transaction([]);
    }

    sub write_sql_fix {
        my ($self, $sql_statement) = @_;
        push($self->transaction, $sql_statement);
    }

    sub write_note {
        my ($self, $text) = @_;
        print { $self->file_handle } "--- $text\n";
    }

    sub write_stdout {
        my ($self, $text) = @_;
        print($text);
    }

    sub finished {
        close(shift->file_handle);
    }
};

=head2 $target

global reference to a TransactionAwareTarget for the scripts output to go to

=cut

my $target;

=head2 @primary_variant_resolvers

references functions that know how to decide which variant in a set of dupes to keep.

=cut

my @primary_variant_resolvers = (
    { name => 'choose the one that was specified manually',         resolver => \&choose_the_one_that_was_specified_manually },
    { name => 'choose xt variant that matches its own size scheme', resolver => \&choose_xt_variant_that_matches_its_own_size_scheme },
    { name => 'choose closest variant from fulcrum',                resolver => \&choose_closest_variant_from_fulcrum },
    { name => 'choose first record if dupes are exact matches',     resolver => \&choose_first_record_if_dupes_are_exact_matches },

    # this was not a good rule
    #{ name => 'where no stock to manually rectify conflict delete', resolver => \&where_no_stock_to_manually_rectify_conflict_delete }
);

=head2 variant_reference_map

This variable lists which tables may incorrectly reference the duplicate
reference and points to a function which can solve it.

=cut

my @variant_reference_map = (
    { table_name => 'channel_transfer_pick',          resolver => \&simple_ref_changer },
    { table_name => 'channel_transfer_putaway',       resolver => \&simple_ref_changer },
    { table_name => 'legacy_designer_size',           resolver => \&delete_references  }, # table scheduled for deletion in LSR 6
    { table_name => 'old_log_location',               resolver => \&simple_ref_changer },
    { table_name => 'log_putaway_discrepancy',        resolver => \&simple_ref_changer },
    { table_name => 'log_pws_reservation_correction', resolver => \&simple_ref_changer },
    { table_name => 'log_rtv_stock',                  resolver => \&simple_ref_changer },
    { table_name => 'orphan_item',                    resolver => undef }, # set to undef (record ignored if item present)
    { table_name => 'pre_order_item',                 resolver => \&simple_ref_changer },
    { table_name => 'putaway_prep_inventory',         resolver => undef }, # set to undef
    { table_name => 'old_quantity',                   resolver => \&delete_references  }, # table marked for deletion in LSR 6
    { table_name => 'quarantine_process',             resolver => \&simple_ref_changer },
    { table_name => 'reservation_consistency',        resolver => undef },
    { table_name => 'reservation',                    resolver => \&simple_ref_changer },
    { table_name => 'return_item',                    resolver => \&simple_ref_changer },
    { table_name => 'rma_request_detail',             resolver => \&simple_ref_changer },
    { table_name => 'rtv_quantity',                   resolver => \&simple_ref_changer },
    { table_name => 'sample_request_cart',            resolver => undef },
    { table_name => 'sample_request_conf_det',        resolver => \&simple_ref_changer },
    { table_name => 'sample_request_det',             resolver => \&simple_ref_changer },
    { table_name => 'shipment_item',                  resolver => \&simple_ref_changer },
    { table_name => 'stock_consistency',              resolver => undef },
    { table_name => 'stock_count',                    resolver => \&simple_ref_changer },
    { table_name => 'stock_count_variant',            resolver => \&simple_ref_changer },
    { table_name => 'stock_order_item',               resolver => \&simple_ref_changer },
    { table_name => 'stock_recode',                   resolver => \&simple_ref_changer },
    { table_name => 'stock_transfer',                 resolver => \&simple_ref_changer },
    { table_name => 'third_party_sku',                resolver => \&simple_ref_changer },
    { table_name => 'variant_measurement',            resolver => \&merge_variant_measurements },
    { table_name => 'variant_measurements_log',       resolver => \&simple_ref_changer },
    { table_name => 'quantity',                       resolver => \&merge_quantity_records },
);

# general code structure

# main                                                                                   retrieves all skus that contain duplicate variants
#  |-> process_sku                                                                       given a sku, get all variants that are duplicates   (for each sku above)
#        |-> process_variants                                                            given a list of duplicated variants, choose the primary variant to keep
#                |-> filter_for_primary_variant                                          of all the variants, choose the most record to keep using different heuristics
#                           |-> choose_xt_variant_that_matches_its_own_size_scheme
#                           |-> choose_closest_variant_from_fulcrum
#                           |-> choose_first_record_if_dupes_are_exact_matches
#                |-> integrate_record                                                    given record to keep and record to delete, use an array of algorithms to solve the data
#                           |-> simple_ref_changer                                       replace the old variant id with a new one
#                           |-> delete_references                                        delete data on an old variant id
#                           |-> merge_variant_measurements                               keep all measurements data providing they don't duplicate or conflict each other
#                           |-> merge_quantity_records                                   combine stock quantity data

sub main {

    if ($write_sql_to_file) {
        $target = FileWriter->new();
    } else {
        $target = LiveDBWriter->new();
    }

    my $list_duplicate_variants_qry = "
        SELECT
            sku.product_id || '-' || sku_padding(sku.size_id) sku,
            sku.product_id,
            sku.size_id,
            sku.type_id,
            vt.type,
            s.season,
            SUM(COALESCE(q.quantity,0)) quantity,
            count(*) count
        FROM (
            SELECT v.product_id, v.size_id, v.type_id
            FROM variant v
            GROUP BY v.product_id, v.size_id, v.type_id
            HAVING count(*) > 1) sku
        JOIN variant v USING (product_id, size_id, type_id)
        JOIN variant_type vt ON vt.id = sku.type_id
        LEFT JOIN quantity q ON q.variant_id = v.id
        JOIN product p ON v.product_id = p.id
        JOIN season s ON s.id = p.season_id
        GROUP BY
            sku.product_id,
            sku.size_id,
            sku.type_id,
            vt.type,
            s.id,
            s.season
        ORDER BY s.id, sku
    ";
    my $sth = $dbh->prepare($list_duplicate_variants_qry);
    $sth->execute();

    $total_rows = $sth->rows;
    $target->write_note("$total_rows duplicates to process");
    $target->write_stdout("$total_rows duplicates to process\n");

    my $success_count = 0;

    while (my $dupe = $sth->fetchrow_hashref()) {

        my $sku = $dupe->{sku};
        $target->write_stdout(sprintf("[%d/%d] %.2f%% sku_id: %s   ",
            $rows_done,
            $total_rows,
            _get_pct(),
            $sku
        ));

        $target->write_note(sprintf("[%d/%d] %.2f%% sku_id: %s\n-----------------------------------\n",
            $rows_done,
            $total_rows,
            _get_pct(),
            $sku
        ));

        my $success = process_sku({
            sku => $sku,
            product_id => $dupe->{product_id},
            size_id => $dupe->{size_id},
            type_id => $dupe->{type_id}
        });

        if ($success) {
            $success_count++;
            $target->write_stdout("[  OK  ]\n");
        } else {
            $target->write_stdout("[ FAILED SAFELY ]\n");
        }

        $rows_done++;
    }

    $target->write_stdout("All records evaluated. Failures: ". ($total_rows - $success_count) . "\n");
    $target->write_note("All records evaluated. Failures: ". ($total_rows - $success_count));

    if ($success_count < $total_rows) {
        $target->write_stdout("Due to failures to resolve ALL duplicates, the contraint won't be applied\n");
        $target->write_stdout("Records that were ported: $success_count\n");
        $target->write_note("Due to failures to resolve ALL duplicates, the contraint won't be applied");
        $target->write_note("Records that were ported: $success_count");
    } else {
        $target->write_stdout("Resolved ALL duplicates. Applying constraint to stop this happenning again...\n");
        $target->write_note("Resolved ALL duplicates. Applying constraint to stop this happenning again...");
        apply_variant_constraint();
    }

    $target->write_stdout("Script finished\n");
    $target->finished();
}

=head2 process_sku

Given one sku which is duplicated, fetch all the variants which
contribute to the duplication and call process_variants.

this function is responcible for begin/commit/rollback management
of a given sku

=cut

sub process_sku {
    my $sku_info = shift;

    # get all the variants that make up the duplicate sku
    my $get_variants_sql = "
        select
            id,
            product_id,
            size_id,
            designer_size_id
        from
            variant
        where
            product_id=?
        and size_id=?
        and type_id=?
        order by
            id
    ";

    my $sthd = $dbh->prepare($get_variants_sql);
    $sthd->execute(
        $sku_info->{product_id},
        $sku_info->{size_id},
        $sku_info->{type_id}
    );

    my @variants;

    while (my $vx = $sthd->fetchrow_hashref()) {
        push(@variants, $vx);
    }

    $target->begin();

    my $safe = process_variants(@variants);

    if ($safe) {
        $target->commit();
    } else {
        $target->rollback();
    }

    return $safe;
}

=head2 process_variants

Given a list of variants, ask which is the primary and then ask
each non-primary record to be integrated into that primary

=cut

sub process_variants {
    my @variants = @_;

    my $primary_variant;

    # phase 1: get the primary record
    try {
        $primary_variant = filter_for_primary_variant(@variants);
        @variants = grep { $_->{id} != $primary_variant } @variants;
        @variants = map { $_->{id} } @variants;
    } catch {
        $target->write_note("EXCEPTION: choosing primary: $_\n");
    };

    if (!defined($primary_variant)) {
        $target->write_note("## Unexpected primary finding exception ## (dupe sku skipped!)\n");
        return 0;
    }

    $target->write_note(sprintf("> primary variant: %d. duplicates to merge: %s",
        $primary_variant,
        join(', ', @variants)
    ));

    # phase 2: migrate all data to the primary record
    foreach my $variant_to_remove(@variants) {

        my $return_failure = 0;

        try {
            my $success = integrate_record($variant_to_remove, $primary_variant);
            $return_failure = 1 if (!$success);
        } catch {
            $target->write_note("## Unexpected exception: $_\n");
            $return_failure = 1;
        };

        return 0 if $return_failure;
    }

    return 1;
}

=head2 variant_reference_map

=head2 integrate_record (variant_to_remove, primary_variant)

This function has one task. Given a variant, move it into the other variant, if possible.

The technique is to iterate over @variant_reference_map which is a list of every table
with a foreign key relationship on the variant table. count the records pointing back to
the variant table. If it's none, there is nothing to do. If there are records pointing
to our old variant, the variant_reference_maps keeps function_pointers to functions
that can fix the data for us.

If nothing explodes, we can go right a head a delete the duplicate variant itself :-)

=cut

sub integrate_record {
    my ($variant_to_remove, $primary_variant) = @_;

    $target->write_note("## moving $variant_to_remove into $primary_variant ##");
    $target->write_note(">> querying what points to the old variant...");

    foreach my $potential_reference (@variant_reference_map) {

        my $table_name = $potential_reference->{table_name};
        my $table_check_qry = "select count(*) from $table_name where variant_id = ?";
        my $count = $dbh->selectcol_arrayref($table_check_qry, {}, ($variant_to_remove))->[0];

        if ($count > 0) {
            # ok lets migrate this pointer to the variant.
            my $func_ptr = $potential_reference->{resolver};

            if (!defined($func_ptr)) {
                die("EXCEPTION: No solution for $table_name reference so unable to migrate this record\n");
            }

            my $success = $func_ptr->($table_name, $variant_to_remove, $primary_variant);
            return 0 if (!$success);
        }

    }

    $target->write_sql_fix("delete from variant where id=$variant_to_remove;");

    return 1;

}

=head2 simple_ref_changer

Given:
    a) a table
    b) a pointer to the old variant
    c) a pointer to the new variant

Makes the record pointing to the old variant point to the new one.
It can be used if the table is an unbounded one-to-many, e.g. a shipment item
where any number of records can point to the new variant row.

=cut

sub simple_ref_changer {
    my ($table_name, $old_variant, $new_variant) = @_;

    $target->write_sql_fix("update $table_name set variant_id=$new_variant where variant_id=$old_variant;");
    return 1;
}

=head2 merge_variant_measurements

merge variant measures or delete duplicates.
Throws an exception if there are conflicting measurements for a given sku.
You'll have to go measure the product yourself in that situation.

=cut

sub merge_variant_measurements {
    my ($table_name, $old_variant, $new_variant) = @_;

    # get measurement values for existing variant into a hash
    my $existing_values_qry = "select measurement_id, value from variant_measurement where variant_id=$new_variant";
    my $sth = $dbh->prepare($existing_values_qry);
    $sth->execute();

    my $existing_measures = {};
    while (my $new_var_measurements = $sth->fetchrow_hashref()) {
        $existing_measures->{ $new_var_measurements->{measurement_id} } = $new_var_measurements->{value};
    }

    # get the dupe's measurement values for comparison
    my $new_values_qry = "select measurement_id, value from variant_measurement where variant_id=$old_variant";
    $sth = $dbh->prepare($new_values_qry);
    $sth->execute();

    while (my $dupes_measurements = $sth->fetchrow_hashref()) {

        my $dupe_measure_id = $dupes_measurements->{measurement_id};

        if (exists($existing_measures->{$dupe_measure_id})) {
            # this measurement id already exists for the primary variant.
            if ($dupes_measurements->{value} == $existing_measures->{$dupe_measure_id}) {
                # new variant already has this entry, just delete this entry
                $target->write_sql_fix("delete from variant_measurement where variant_id=$old_variant and measurement_id=$dupe_measure_id;");
            } else {

                #new behaviour, just ignore conflicts and keep the new record.
                $target->write_sql_fix("delete from variant_measurement where variant_id=$old_variant and measurement_id=$dupe_measure_id;");

                #die("EXCEPTION: new measurement and old measurement for each variant differ by value... please resolve manually (remeasure the product if necessary)\n");
            }
        } else {
            $target->write_sql_fix("update variant_measurement set variant_id=$new_variant where variant_id=$old_variant and measurement_id=$dupe_measure_id;");
        }
    }

    return 1;
}

=head2 merge_quantity_records

sum the data and update the quantity records that are being kept if primary keys prevent old variant data
from being straight replaced with the new variant id.

=cut

sub merge_quantity_records {
    my ($table_name, $old_variant, $new_variant) = @_;

    my $existing_values_qry = "select location_id, channel_id, status_id, quantity from quantity where variant_id=$new_variant";
    my $sth = $dbh->prepare($existing_values_qry);
    $sth->execute();

    my $existing_quantities = {};
    while (my $new_quantities = $sth->fetchrow_hashref()) {
        my $id_str = $new_quantities->{location_id} . "|" . $new_quantities->{channel_id} . "|" . $new_quantities->{status_id};
        $existing_quantities->{ $id_str } = $new_quantities->{quantity};
    }

    # get the dupe's quantity data for comparison
    my $dupes_values_qry = "select location_id, channel_id, status_id, quantity from quantity where variant_id=$old_variant";
    $sth = $dbh->prepare($dupes_values_qry);
    $sth->execute();

    while (my $dupes_quantities = $sth->fetchrow_hashref()) {

        my $loc_id = $dupes_quantities->{location_id};
        my $chan_id = $dupes_quantities->{channel_id};
        my $status_id = $dupes_quantities->{status_id};
        my $id_str = $dupes_quantities->{location_id} . "|" . $dupes_quantities->{channel_id} . "|" . $dupes_quantities->{status_id};

        if (exists($existing_quantities->{$id_str})) {
            $target->write_sql_fix("update quantity prim set quantity=(prim.quantity + dupe.quantity) from quantity dupe
                           where dupe.variant_id=$old_variant and prim.variant_id=$new_variant
                           and dupe.location_id=prim.location_id and prim.location_id = $loc_id
                           and dupe.channel_id=prim.channel_id and prim.channel_id = $chan_id
                           and dupe.status_id=prim.status_id and prim.status_id = $status_id;");

            $target->write_sql_fix("delete from quantity where variant_id=$old_variant and location_id=$loc_id and status_id=$status_id and channel_id=$chan_id;");
        } else {
            $target->write_sql_fix("update quantity set variant_id=$new_variant where variant_id=$old_variant
                           and location_id = $loc_id and status_id = $status_id and channel_id = $chan_id;");
        }
    }

    return 1;
}

=head2 delete_references

Deletes records out of a table to remove dependencies on the variant table
should we not care about that data.

=cut

sub delete_references {
    my ($table_name, $old_variant, $new_variant) = @_;

    $target->write_sql_fix("delete from $table_name where variant_id=$old_variant;");
    return 1;

}

=head2 filter_for_primary_variant

This function calls upon the help of an array called @primary_variant_resolvers
that points to several algorithms responcible for deciding which of a group of variants
is the one that should be kept, and the others merged into.

=cut

sub filter_for_primary_variant {
    my @variants = @_;

    $target->write_note("currently ". scalar(@variants) . " potential primary variants remaining: ". join(', ', map { $_->{id} } @variants));
    my @algos = @primary_variant_resolvers;

    while (@variants > 1) { # can still filter the list further.
        my $algo = shift(@algos);
        last if !defined($algo);
        $target->write_note("attempting to reduce primary variants using algorithm: ". $algo->{name});
        @variants = $algo->{resolver}->(@variants);
        $target->write_note("currently ". scalar(@variants) . " potential primary variants remaining: ". join(', ', map { $_->{id} } @variants));
    }

    if (@variants == 1) {
        $target->write_note("primary variant found: ". $variants[0]->{id});
        return $variants[0]->{id};
    } elsif (@variants == 0) {
        die("EXCEPTION: sorry mate. zero primary records?");
    } else {
        die("EXCEPTION: unable to resolve best match.");
    }

}

=head2 choose_closest_variant_from_fulcrum

Choose which variant to keep by using a heristic score
determined by comparing the data with what's in the Fulcrum database.

=cut

sub choose_closest_variant_from_fulcrum {
    my @variants = @_;

    my $product_id = $variants[0]->{product_id};
    my $size_id = $variants[0]->{size_id};

    # lets fetch everything we need from xt for a variant comparison
    my $xt_variant_scanner_qry = "
        select
          v.id variant_id,
          v.product_id,
          v.size_id,
          ns.size as nap_size,
          v.designer_size_id,
          ds.size as designer_size
        from
          variant v,
          size ns,
          size ds
        where
          v.size_id=ns.id
        and v.designer_size_id=ds.id
        and v.id in (" . join(', ', map { $_->{id} } @variants) . ")
        order by
            v.id
    ";

    my $xt_sth = $dbh->prepare($xt_variant_scanner_qry);
    $xt_sth->execute();
    my $xt_variants = {};

    $target->write_note("performing fulcrum/xt conflict resolution");

    while (my $xt_r = $xt_sth->fetchrow_hashref()) {
        my $variant_id = $xt_r->{variant_id};
        $xt_variants->{$variant_id}->{row} = $xt_r;
        $xt_variants->{$variant_id}->{matches} = 0;
        $target->write_note(sprintf("xtracker variant: %s, nap_size: %s, designer_size: %s",
            $xt_r->{variant_id},
            $xt_r->{nap_size},
            $xt_r->{designer_size}
        ));
    }

    my $fulcrum_sku_scanner_qry = "
        select
          v.product_id || '-' || s.size_id sku,
          v.id variant_id,
          s.size_id as NAP_ID,
          dn.id nap_id,
          dn.size nap_size,
          ds.size designer_size
        from
          product.variant v,
          size_scheme_variant_size s,
          size dn,
          size ds
        where
            v.product_id = ?
        and s.size_id = ?
        and v.size_variant_id = s.id
        and s.size_id = dn.id
        and s.designer_size_id = ds.id
    ";

    my $ful_sth = $fulcrum_dbh->prepare($fulcrum_sku_scanner_qry);
    $ful_sth->execute($product_id, $size_id);

    my $count = 0;

    while (my $f_sku = $ful_sth->fetchrow_hashref()) {

        if ($count > 0) {
            die("EXCEPTION: MULTIPLE MATCHING VARIANTS FOR SKU IN FULCRUM");
        }

        foreach my $xt_h (values $xt_variants) {

            $target->write_note(sprintf("fulcrum variant: %s (sku: %s), nap_size: %s, designer_size: %s",
                $f_sku->{variant_id},
                $f_sku->{sku},
                $f_sku->{nap_size},
                $f_sku->{designer_size}
            ));

            $xt_h->{nap_size_match} = ($f_sku->{nap_size} eq $xt_h->{row}->{nap_size}) ? 1 : 0; # nap size most important factor
            $xt_h->{designer_size_match} = ($f_sku->{designer_size} eq $xt_h->{row}->{designer_size}) ? 1 : 0;
            $xt_h->{variant_id_match} = ($f_sku->{variant_id} == $xt_h->{row}->{variant_id}) ? 1 : 0;

            $target->write_note("xt variant nap_size_match with fulcrum? ". ($xt_h->{nap_size_match} ? 'y' : 'n'));
            $target->write_note("xt variant designer_size_match with fulcrum? ". ($xt_h->{designer_size_match} ? 'y' : 'n'));
            $target->write_note("xt variant variant_id_match with fulcrum? ". ($xt_h->{variant_id} ? 'y' : 'n'));

            $xt_h->{matches} += (5 * $xt_h->{nap_size_match});  # 5 points for griffindor (or rather for a matching nap size description).
            $xt_h->{matches} += (3 * $xt_h->{designer_size_match});  # 3 points for hufflepuff (or rather for a matching designer size description)
            $xt_h->{matches} += 1 if ($xt_h->{variant_id_match});  # perfectly aligned data!
        }

        $count++;
    }

    if ($count == 0) {
        $target->write_note("aint no fulcrum record.");
        return @variants;
    }

    # just return record with best matching score.
    my $best_match_score = -1;
    my @best_matches;

    foreach my $xt_var (values $xt_variants) {
        $target->write_note(sprintf("xt variant: %d, nap_size: %s, designer_size: %s, match_score: %s",
            $xt_var->{row}->{variant_id},
            $xt_var->{row}->{nap_size},
            $xt_var->{row}->{designer_size},
            $xt_var->{matches}
        ));
        if ($xt_var->{matches} > $best_match_score) {
            @best_matches = ($xt_var);
            $best_match_score = $xt_var->{matches};
        } elsif ($xt_var->{matches} == $best_match_score) {
            push(@best_matches, $xt_var);
        }
    }

    if ($best_match_score < 8) {
        $target->write_note("no fulcrum xt match on designer size?");
    }

    # replace filtering with input.
    my @new_variants;
    foreach my $x (@variants) {
        if (grep { $_->{row}->{variant_id} == $x->{id} } @best_matches) {
            push(@new_variants, $x);
        }
    }

    return @new_variants;
}

=head2 choose_xt_variant_that_matches_its_own_size_scheme

Name says it all. If we have variants on product like this:

is dupe                       X         X
variant id    23      24     25        26              27
sku        10-23   10-24   10-25    10-25           10-27
size       small   medium  large       L      extra large

it looks at the size scheme to determine which is the odd one out
between duplicate skus 25 and 26. Since large fits in with
the small/medium/large style of designer sizes and "L" doesn't,
we choose to keep 25.

=cut

sub choose_xt_variant_that_matches_its_own_size_scheme {
    my @variants = @_;

    my $product_id = $variants[0]->{product_id};

    # firstly.. this only works if the variants differ on designer_size_id
    # or else we're wasting our time.
    my $conflict = conflicting_xt_records(@variants);
    return @variants if (!$conflict);

    my $dupe_id_list = join(", ", map { $_->{id} } @variants);

    # lets first check we have a consistent size scheme across the remaining variables,
    # else we won't solve a thing!
    my $size_schemes_employed_by_non_duplicated_records = $dbh->selectcol_arrayref("
        select
            size_scheme_id
        from
            product_attribute
        where
            size_scheme_id in (
                select
                    distinct(size_scheme_id)
                from
                    size_scheme_variant_size
                where designer_size_id in (
                    select
                        designer_size_id
                    from
                        variant
                    where
                        product_id=? and id not in ($dupe_id_list)
                )
            ) and product_id=?;", {}, ($product_id, $product_id));

    if (@$size_schemes_employed_by_non_duplicated_records != 1) {
        return @variants; # why bother?
    }

    my $target_size_scheme = $size_schemes_employed_by_non_duplicated_records->[0];

    if (!defined($target_size_scheme)) {
        return @variants;
    }

    # get all the designer sizes for the product's denoted size scheme

    my $valid_designer_size_ids_for_the_target_size_scheme = $dbh->selectcol_arrayref("
        select
            designer_size_id
        from
            size_scheme_variant_size
        where
            size_scheme_id = ?
    ", {}, ($target_size_scheme));

    $target->write_note("valid designer_size_ids for the used size scheme: ". join(", ", @$valid_designer_size_ids_for_the_target_size_scheme) . "\n");

    my @matches;

    foreach my $var (@variants) {
        if (grep { $_ == $var->{designer_size_id} } @{ $valid_designer_size_ids_for_the_target_size_scheme } ) {
            push(@matches, $var);
        }
    }

    if (@matches == 0) {
        #die("mismatched size schemes");
        #everything still in contention
        return @variants;
    }

    return @matches;

}

=head2 choose_first_record_if_dupes_are_exact_matches

If the records don't conflict on designer_size_id then
they're effectively exact dupes, so it doesn't matter
which one we choose.

(We choose the first, aka the lowest id)

=cut

sub choose_first_record_if_dupes_are_exact_matches {
    my @variants = @_;

    my $conflict = conflicting_xt_records(@variants);
    if (!$conflict) {
        return shift(@variants);
    } else {
        return @variants;
    }
}

# these were hand picked by nuno
my $hand_picked = {
    'DC1' => [
        17319,
        5967,
        7649,
        27118,
        27977,
        29197,
        29290,
        213553,
        1177239,
        884907
    ],
    'DC2' => [
        139551,
        1090091,
        1062675,
        749231,
        832116,
        832125,
        832143,
        832152,
        660889,
        2265569
    ]
};

=head2 choose_the_one_that_was_specified_manually

Where we manually decided how to resolve a conflict, we wrote the
variant id in the dictionary above. This allows us to override anything
that would result in a conflict.

=cut

sub choose_the_one_that_was_specified_manually {
    my @variants = @_;

    my $dc_name = config_var( 'DistributionCentre', 'name' );

    foreach my $variant (@variants) {
        return ($variant) if (grep { $variant->{id} == $_ } @{ $hand_picked->{$dc_name} });
    }

    # all in contention
    return @variants;

}

=head2 where_no_stock_to_manually_rectify_conflict_delete

Got one sku with a designer size of 6 and another row saying the designer size is 7?
The fix is easy, pull stock out of IWS and look at the designer's label on the clothes.
No stock? how are you gonna manually fix it?

=cut

sub where_no_stock_to_manually_rectify_conflict_delete {
    my @variants = @_;
    my $conflict = conflicting_xt_records(@variants);
    return @variants if (!$conflict);

    my $dupe_list = join(', ', map { $_->{id} } @variants);

    my $total_quantity = $dbh->selectcol_arrayref("
        select
            coalesce(sum(quantity),0) stock
        from
            quantity
        where
            variant_id in ($dupe_list);
    ", {})->[0];

    if ($total_quantity == 0) {
        $target->write_note("No stock for any of these variants. choosing first record as no manual way to resolve");
        return shift @variants;
    } else {
        $target->write_note("There is stock for this duplicated sku (quantity=$total_quantity). fetch it and check the designer size please");
        return @variants;
    }
}

=head conflicting_xt_records

because the skus are dupes, the only other value in the variant table
that matters is the designer size.

=cut

sub conflicting_xt_records {
    my @variants = @_;
    # designer_id != designer_id

    my $designer_size_id = $variants[0]->{designer_size_id};

    foreach my $var (@variants) {
        return 1 if ($var->{designer_size_id} != $designer_size_id);
    }

    return 0;
}

=head2 apply_variant_constraint

The moment we've all been waiting for...

=cut

sub apply_variant_constraint {
    $target->begin();
    $target->write_note("the big finale!!\n\n");

    $target->write_note("# RUN THIS AS POSTGRES TECHOPS ");
    $target->write_note("SQL: alter table variant add constraint variant_unique_variant unique(product_id, size_id, type_id);");
    $target->commit();
}

=head2 _get_pct

get percentage of work done

=cut

sub _get_pct {
    return 0 if ($total_rows == 0);
    return 0 if ($rows_done == 0);
    return (($rows_done / $total_rows) * 100);
}

main();

