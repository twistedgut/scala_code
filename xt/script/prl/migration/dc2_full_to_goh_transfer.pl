#!/opt/xt/xt-perl/bin/perl

=head1 NAME

dc2_full_to_goh_transfer.pl - Transfer stock from Full PRL to GOH

=head1 SYNOPSIS

  RUN_NAME=first ./script/prl/migration/dc2_full_to_goh_transfer.pl <some argument> <data_dir>

where <some argument> would be only one of these commands for each run

--load

    Prepare for a PRL to PRL stock migration by loading the PRL inventory
    into XTracker's database where it is accessible for SQL joins and update
    statements.

    Steps:
    1. create inventory table for PRL data
    2. load PRL data in
    3. modify PRL data to make joining easier

    4. create a fulfilment table for PRL data
    5. load the PRL data in

--move-stock-to-goh

    Perform the actual stock move.

    Steps:
    1. Inserts records into log_location
    2. Subtracts stock from PRL Full rows
    3. Creates PRL GOH rows
    4. Delete empty rows

    Move the allocations
    1. update allocation records.

--show-inventory-join

    Allows you to inspect how the system reconciles XT inventory with the PRL's
    which is useful for debugging or problem diagnosis.

The data_dir argument is optional, and defaults to '.' if not supplied. It is
used only with the --load argument, to specify where the data files are.

=head1 DESCRIPTION

This script forms part of the stock migration from the Full PRL to the GOH PRL.
Specifically, this script runs on XT, after the data has been moved to the GOH PRL.

Using SQL, we stock adjust everything down that we've moved out of Full PRL and
we create brand new Quantity records for our moved stock in the GOH PRL.

First, run the script with --load. It requires the inventory dump file used
earlier in the migration process. This essentially just loads that file
into the database, so it's availabe for bulk select/insert/update commands.

After the data is loaded, a --show-inventory-join option allows you to see how a single
inventory record in XT may tie up with multiple inventory records in the PRL. We
can ensure quantities, stock statuses and other data are as we expect.

When we are ready, we can use --move-stock-to-goh. This command performs the
actual stock adjustment to the quantity table in XT.

The RUN_NAME environmental variable must be provided. It ties this script back
with the files that were used in the dump of the PRL data in the first place.
It remain the same across all the scripts run during a single migration run.

=cut

use NAP::policy "tt";
use FindBin::libs;
use XTracker::Constants '$APPLICATION_OPERATOR_ID';
use XTracker::Database 'schema_handle';
use XTracker::Config::Local 'config_var';
use Pod::Usage;
use PRL::Migration::Utils;

my $schema;
my $dbh;
my $prl_inventory_table;
my $prl_fulfilment_table;

sub setup {

    $schema = schema_handle();
    $dbh = $schema->storage->dbh;

    my $host = config_var('Database_xtracker','db_host');
    my $schema_name = config_var('Database_xtracker','db_name');
    my $user = config_var('Database_xtracker','db_user_patcher') // 'postgres';
    my $pass = config_var('Database_xtracker','db_pass_patcher');

    print "connection details passed to psql: $host $user $schema_name\n";
}

sub main {

    my $arg = $ARGV[0] // '';
    my $data_dir = $ARGV[1] // '.';
    pod2usage(3) if ($arg eq '');
    pod2usage(3) if (defined($ARGV[2]));

    if (!defined($ENV{RUN_NAME}) || $ENV{RUN_NAME} eq '') {
        warn("error: You forgot to provide the \$RUN_NAME env variable\n");
        pod2usage(2);
    }

    $prl_inventory_table = 'prl_inventory_' . $ENV{RUN_NAME};
    $prl_fulfilment_table = 'prl_fulfilment_' . $ENV{RUN_NAME};

    setup();

    if ($arg eq '--load') {

        die("error: this command has already been run\n")
            if (is_data_loaded());

        create_prl_inventory_table();
        load_prl_inventory_table($data_dir);
        populate_stock_status();
        print "script finished successfully\n";
    }

    if ($arg eq '--move-stock-to-goh') {

        $schema->txn_do(sub {
            ensure_data_loaded();
            insert_log_entries();
            subtract_full_prl_entries();
            insert_goh_prl_entries();
            delete_zero_quantity_records();
            print "script finished successfully\n";
        });
    }

    if ($arg eq '--show-inventory-join') {
        ensure_data_loaded();
        show_inventory_join()
    }

}

sub _execute_sql {
    my $sql = shift;
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my $recs_affected = $sth->rows();
    print("executed query: $sql\nrecords affected: $recs_affected\n");
    return $sth;
}

# This is the most important query of the script. It joins xtracker's inventory
# to the PRL's based on SKU and stock status.

# The command line option --show-inventory-join will show the main fields from the query
# so you can ensure it joins correctly.

# This query is used as the basis for selecting and updating xtracker's inventory.

sub get_inventory_join_sql {

    return "
        select
          xt.quantity_id quantity_id,
          prl.ids prl_inventory_ids,
          xt.variant_id variant_id,
          xt.channel_id xt_channel_id,
          xt.sku xt_sku,
          prl.sku prl_sku,
          xt.location_id xt_location_id,
          xt.location xt_location,
          prl.int_locs prl_internal_locations,
          xt.quantity xt_quantity,
          prl.quantity prl_quantity,
          xt.stock_status_id xt_stock_status_id,
          xt.stock_status xt_stock_status,
          prl.stock_status prl_stock_status
        from
        (select
            q.id quantity_id,
            v.id variant_id,
            v.product_id || '-' || sku_padding(v.size_id) sku,
            q.location_id,
            l.location,
            q.quantity,
            q.status_id stock_status_id,
            fs.name stock_status,
            q.channel_id
        from
            quantity q,
            variant v,
            location l,
            flow.status fs
        where
            q.variant_id = v.id
        and q.location_id = l.id
        and q.status_id = fs.id) xt,
        (
        select
           sku_id sku,
           stock_status,
           string_agg(id || '', ', ') ids,
           sum(quantity) quantity,
           string_agg(location_id, ', ') int_locs
        from
           $prl_inventory_table
        group by
           sku_id,
           stock_status
        ) prl
        where
            xt.sku = prl.sku
        and xt.stock_status = prl.stock_status
        and xt.location = 'Full PRL'
    ";

}

sub create_prl_inventory_table {

    _execute_sql("
        CREATE TABLE $prl_inventory_table (
            id integer not null primary key,
            sku_id text not null,
            location_id text not null,
            quantity integer not null,
            allocated_quantity integer not null,
            pgid text not null,
            is_return boolean not null,
            expiration_date text,
            stock_status_id integer not null
        );
    ");
}

sub _execute_psql_load_command {
    my ($sql, $filename) = @_;

    my $host = config_var('Database_xtracker','db_host');
    my $schema_name = config_var('Database_xtracker','db_name');
    my $user = config_var('Database_xtracker','db_user_patcher') // 'postgres';
    my $pass = config_var('Database_xtracker','db_pass_patcher');

    print "connection details passed to psql: $host $user $schema_name\n";

    my $psql_command = sprintf('psql -h %s -U %s %s -c "%s" < %s',
        $host,
        $user,
        $schema_name,
        $sql,
        $filename
    );

    # execute.
    print "executing command: $psql_command\n";
    print `$psql_command` . "\n"; ## no critic(ProhibitBacktickOperators)
    my $retval = $?;

    if ($retval) {
        die("error with psql command: $retval\n");
    }

}

sub load_prl_inventory_table {
    my ($data_dir) = @_;
    # we shell out to psql for this.

    _execute_psql_load_command(
        "copy $prl_inventory_table from stdin with csv header;",
        "$data_dir/dbdump.inventory.". $ENV{RUN_NAME} . ".csv"
    );
}

sub populate_stock_status {

    _execute_sql("
        alter table $prl_inventory_table
        add column stock_status text;
    ");

    _execute_sql("
        update $prl_inventory_table
        set   stock_status='Main Stock'
        where stock_status_id=1;
    ");

    _execute_sql("
        update $prl_inventory_table
        set   stock_status='Dead Stock'
        where stock_status_id=2;
    ");
}

sub insert_log_entries {

    my $join_sql = get_inventory_join_sql();

    _execute_sql("
        insert into log_location (
          variant_id,
          location_id,
          operator_id,
          channel_id
        ) select
          joined.variant_id,
          joined.xt_location_id,
          $APPLICATION_OPERATOR_ID,
          joined.xt_channel_id
        from (
          $join_sql
        ) joined;
    ");
}

sub subtract_full_prl_entries {
    my $join_sql = get_inventory_join_sql();

    _execute_sql("
        update quantity w_quantity
        set quantity = w_quantity.quantity - joined.prl_quantity
        from (
            $join_sql
        ) joined
        where
            w_quantity.id = joined.quantity_id;
    ");
}

sub insert_goh_prl_entries {
    print("create_goh_prl_entries\n");

    my $join_sql = get_inventory_join_sql();

    _execute_sql("insert into quantity (
          variant_id,
          location_id,
          quantity,
          channel_id,
          status_id,
          date_created
        ) select
          joined.variant_id,
          (select id from location where location='GOH PRL'),
          joined.prl_quantity,
          joined.xt_channel_id,
          joined.xt_stock_status_id,
          now()
        from
            ($join_sql) joined;
    ");

}

sub delete_zero_quantity_records {
    _execute_sql("delete from quantity where quantity = 0;");
}

# column width
my $CW = 60;

sub _print_rs {
    my ($rs, $key, $col_headers) = @_;

    if ($rs->rows() == 0) {
        print "0 results\n";
        return;
    }

    my $results = $rs->fetchall_hashref($key);

    print (sprintf(" %" . $CW . "s |", $_)) foreach @$col_headers;
    print ("\n" . ('-' x (($CW + 3) * scalar(@$col_headers))) . "\n");

    foreach my $row (values %{ $results }) {
        foreach my $col (@$col_headers) {
            print sprintf(" %" . $CW . "s |", $row->{$col} || '');
        }
        print "\n";
    }

}

sub show_inventory_join {

    ensure_data_loaded();

    my $join_sql = get_inventory_join_sql();

    my $rs = _execute_sql("
        select
            quantity_id,
            prl_inventory_ids,
            variant_id,
            xt_sku,
            prl_sku,
            xt_location,
            prl_internal_locations,
            xt_quantity,
            prl_quantity,
            xt_stock_status,
            prl_stock_status
        from
            ($join_sql) joined
        order by
            xt_sku;
    ");

    _print_rs($rs, 'quantity_id', [
        'quantity_id',
        'prl_inventory_ids',
        'variant_id',
        'xt_sku',
        'prl_sku',
        'xt_location',
        'prl_internal_locations',
        'xt_quantity',
        'prl_quantity',
        'xt_stock_status',
        'prl_stock_status'
    ]);
}

sub ensure_data_loaded {
    if (!is_data_loaded()) {
        die("error: you cannot perform this operation until you've loaded the data with --load\n");
    }
}

sub is_data_loaded {

    my $rs = _execute_sql("
        select exists (
            select *
            from information_schema.tables
            where table_name='$prl_inventory_table'
        ) table_exists;
    ");

    my $result = $rs->fetchrow_hashref();
    return !!$result->{table_exists};

}

main;
