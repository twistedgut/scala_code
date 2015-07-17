package Test::XT::DB::BackFill;

use NAP::policy     qw( test );
use parent 'NAP::Test::Class';

=head1 NAME

Test::XT::DB::BackFill

=head1 DESCRIPTION

Tests the 'XT::DB::BackFill' Class that is used to Back-Fill database records
after new columns have been added.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::DBAdminBackFillJob;
use Test::XT::Data;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :dbadmin_back_fill_job_status );


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    use_ok('XT::DB::BackFill');
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;

    my $data = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::DBAdminBackFillJob',
        ],
    );
    $self->{data} = $data;
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}


=head1 TESTS

=head2 test_instantiation

Tests the 'XT::DB::BackFill' Class can be instantiated and
test the Attributes are of the correct Classes.

=cut

sub test_instantiation : Tests {
    my $self = shift;

    # create a Back Fill Job record
    my $back_fill_job_rec = $self->_data->back_fill_job;

    my $obj;
    lives_ok {
        $obj = XT::DB::BackFill->new( {
            back_fill_job => $back_fill_job_rec,
        } );
    } "'XT::DB::BackFill' can be instantiated";


    # test Attributes and their Classes
    my %test_isa = (
        schema      => 'XTracker::Schema',
        dbh         => 'DBI::db',
        start_time  => 'DateTime',
        finish_time => 'DateTime',
    );

    # set the two 'DateTime' Attributes with a Value
    $obj->set_start_time;
    $obj->set_finish_time;

    while ( my ( $attribute, $expect_class ) = each %test_isa ) {
        isa_ok( $obj->$attribute, $expect_class, "'${attribute}' Class is as Expected" );
    }

    cmp_ok( $obj->record_count, '==', 0, "'record_count' default is ZERO" );
    ok( !$obj->was_run, "'was_run' returns FALSE" );
}

=head2 test_start_finish_time_attributes

Check the 'start_time' and 'finish_time' Attributes.

=cut

sub test_start_finish_time_attributes : Tests {
    my $self = shift;

    # create a Back Fill Job record
    my $back_fill_job_rec = $self->_data->back_fill_job;

    # get an Instance of 'XT::DB::BackFill'
    my $obj = $self->_get_backfill_obj( $back_fill_job_rec );

    # check the Start & Finish times are NOT the same
    $obj->set_start_time;
    my $start_time  = $obj->start_time;
    # wait one second then get the finish time
    sleep(1);
    $obj->set_finish_time;
    my $finish_time = $obj->finish_time;
    cmp_ok( $finish_time->compare( $start_time ), '==', 1, "the 'finish_time' is greater than the 'start_time'" );

    # get the Time-Zone for the DB and make sure
    # it's the same as the Start/Finish Time-Zones
    my $db_time_zone_name = $self->schema->db_now->time_zone->name;
    is( $start_time->time_zone->name, $db_time_zone_name,
                    "'start_time' Time-Zone is the Same as the Database: '${db_time_zone_name}'" );
    is( $finish_time->time_zone->name, $db_time_zone_name,
                    "'finish_time' Time-Zone is the Same as the Database: '${db_time_zone_name}'" );
}

=head2 test_sql_comment

Tests the 'sql_comment' and that if set subsequently always has a 'newline'
character at the end.

By Testing the SQL Comment this will also be testing that the Types in
the class 'XT::DB::BackFill::Type' work along with the coercion into
those Types.

=cut

sub test_sql_comment : Tests {
    my $self = shift;

    my $back_fill_job_rec = $self->_data->back_fill_job;

    # get an Instance of 'XT::DB::BackFill'
    my $backfill_obj = $self->_get_backfill_obj( $back_fill_job_rec );

    # get what should be in the default comment
    my $proc_id      = $$;
    my $package_name = ref( $backfill_obj );
    my $job_id       = $back_fill_job_rec->id;

    like( $backfill_obj->sql_comment, qr/^-- .*PID: ${proc_id}.*${package_name}.*${job_id}.*\n$/i,
                    "Default SQL Comment is as Expected" );

    note <<EOM
TEST that when setting Custom Comments that they have
     leading '-- ' and trailing 'newline' characters added
     even if they didn't have them when they were set
EOM
;

    # some of these tests will test the coercion into the
    # 'XT::DB::BackFill::Type::EmptyOrSQLComment' Type
    my %tests = (
        "Setting a Comment that starts with '-- ' and ends with a newline" => {
            comment => "-- NEW COMMENT\n",
            expect  => "-- NEW COMMENT\n",
        },
        "Setting a Comment that doesn't start with '-- ' nor ends with a newline" => {
            comment => "NEW COMMENT",
            expect  => "-- NEW COMMENT\n",
        },
        "Setting a Multi-Line Comment all starting with '-- ' and ending with a newline" => {
            comment =>
                "-- comment line 1\n" .
                "-- comment line 2\n" .
                "-- comment line 3\n",
            expect  =>
                "-- comment line 1\n" .
                "-- comment line 2\n" .
                "-- comment line 3\n",
        },
        "Setting a Multi-Line Comment with some starting with '-- ' and the last not ending with a newline" => {
            comment =>
                "-- comment line 1\n" .
                "comment line 2\n" .
                "-- comment line 3",
            expect  =>
                "-- comment line 1\n" .
                "-- comment line 2\n" .
                "-- comment line 3\n",
        },
        "Setting a Multi-Line Comment with none starting with '-- ' and the last not ending with a newline" => {
            comment =>
                "comment line 1\n" .
                "comment line 2\n" .
                "comment line 3",
            expect  =>
                "-- comment line 1\n" .
                "-- comment line 2\n" .
                "-- comment line 3\n",
        },
        "Setting a Comment starting with '--' and no following space" => {
            comment => "--comment line 1",
            expect  => "-- comment line 1\n",
        },
        "Setting a Comment starting with multiple leading '-', should end up with '-- ' " => {
            comment => "------ comment line 1",
            expect  => "-- comment line 1\n",
        },
        "Setting a Comment starting with one leading '-', should end up with '-- ' " => {
            comment => "-comment line 1",
            expect  => "-- comment line 1\n",
        },
        "Setting a Comment starting with spaces and then '--' should end up with '-- ' " => {
            comment => "  -- comment line 1",
            expect  => "-- comment line 1\n",
        },
        "Setting a Multi-Line Comment which include spacer comment lines (lines that just have '--' in them)" => {
            comment =>
                "--\n" .
                "-- comment line\n" .
                "--",
            expect  =>
                "--\n" .
                "-- comment line\n" .
                "--\n",
        },
        "Setting a Comment with an Empty String and expect it to stay empty" => {
            comment => '',
            expect  => '',
        },
    );

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test    = $tests{ $label };
        my $comment = $test->{comment};
        my $expect  = $test->{expect};

        # test setting the Comment in the Constructor
        my $obj = $self->_get_backfill_obj( $back_fill_job_rec, {
            sql_comment => $comment,
        } );
        is( $obj->sql_comment, $expect, "Comment set using the Constuctor is as Expected" );

        # test setting the Comment using the Attribute's Writer
        $obj->sql_comment( $comment );
        is( $obj->sql_comment, $expect, "Comment set using the 'writer' is as Expected" );
    }
}

=head2 test_build_resultset_query

Tests the building of the Result-Set Query which should
return the list of 'Ids' for the records that need updating.

=cut

sub test_build_resultset_query : Tests {
    my $self = shift;

    my $back_fill_job_rec = $self->_data->back_fill_job;

    my %tests = (
        "Result-set with NO 'SELECT' or 'ORDER BY' part" => {
            setup => {
                back_fill_primary_key_field => 'id',
                resultset_select   => undef,
                resultset_from     => 'some_table',
                resultset_where    => 'last_updated IS NULL',
                resultset_order_by => undef,
                # this will be used to test the 'LIMIT' part of the query
                max_rows_to_update => 10,
            },
            expect => {
                query => qr/SELECT id FROM some_table WHERE last_updated IS NULL/i,
            },
        },
        "Result-set with a 'SELECT' part" => {
            setup => {
                back_fill_primary_key_field => 'id',
                resultset_select   => 'tbl_a.id',
                resultset_from     => 'some_table tbl_a JOIN other_table tbl_b ON tbl_b.id = tbl_a.id',
                resultset_where    => 'tbl_a.last_updated IS NULL',
                resultset_order_by => undef,
                max_rows_to_update => 10,
            },
            expect => {
                query => qr/
                    \QSELECT tbl_a.id\E\s
                    \QFROM some_table tbl_a JOIN other_table tbl_b ON tbl_b.id = tbl_a.id\E\s
                    \QWHERE tbl_a.last_updated IS NULL\E
                /xi,
            },
        },
        "Result-set with an 'ORDER BY' part" => {
            setup => {
                back_fill_primary_key_field => 'id',
                resultset_select   => undef,
                resultset_from     => 'some_table tbl_a JOIN other_table tbl_b ON tbl_b.id = tbl_a.id',
                resultset_where    => 'tbl_a.last_updated IS NULL',
                resultset_order_by => 'tbl_a.id',
                max_rows_to_update => 10,
            },
            expect => {
                query => qr/
                    \QSELECT id\E\s
                    \QFROM some_table tbl_a JOIN other_table tbl_b ON tbl_b.id = tbl_a.id\E\s
                    \QWHERE tbl_a.last_updated IS NULL\E\s
                    \QORDER BY tbl_a.id\E
                /xi,
            },
        },
        "Result-set with a 'SELECT' and an 'ORDER BY' part" => {
            setup => {
                back_fill_primary_key_field => 'id',
                resultset_select   => 'tbl_a.id',
                resultset_from     => 'some_table tbl_a JOIN other_table tbl_b ON tbl_b.id = tbl_a.id',
                resultset_where    => 'tbl_a.last_updated IS NULL',
                resultset_order_by => 'tbl_a.id',
                max_rows_to_update => 10,
            },
            expect => {
                query => qr/
                    \QSELECT tbl_a.id\E\s
                    \QFROM some_table tbl_a JOIN other_table tbl_b ON tbl_b.id = tbl_a.id\E\s
                    \QWHERE tbl_a.last_updated IS NULL\E\s
                    \QORDER BY tbl_a.id\E
                /xi,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # update the Back-Fill Job record for the Test
        $back_fill_job_rec->discard_changes->update( $setup );

        # get an Instance of 'XT::DB::BackFill'
        my $backfill_obj = $self->_get_backfill_obj( $back_fill_job_rec );

        my $expect_query = $expect->{query};

        my $got = $backfill_obj->build_resultset_query;
        like( $got, $expect_query, "ResultSet Query built as Expected" );

        # now get the Query but with the 'LIMIT' appended
        my $max_records = $back_fill_job_rec->max_rows_to_update;
        $got = $backfill_obj->build_limited_resultset_query;
        like( $got, qr/${expect_query} LIMIT ${max_records}/i,
                        "ResultSet Query with 'LIMIT' built as Expected" );
    }
}

=head2 test_build_update_statement

Tests the 'build_update_statement' method that builds the SQL Statement
that when called will actually Update fields.

=cut

sub test_build_update_statement : Tests {
    my $self = shift;

    my $back_fill_job_rec = $self->_data->back_fill_job;

    # general Table name used in the tests
    my $table_name = 'some_table';

    # these are the values for the Result-Set query
    # that will be set for each of the Tests
    my %resultset_fields = (
        resultset_select   => 'id',
        resultset_from     => $table_name,
        resultset_where    => 'last_updated IS NULL',
        resultset_order_by => undef,
        max_rows_to_update => 10,
    );
    # this is the RegEx for the Result-Set that will be
    # used as part of the RegEx to check the UPDATE query
    my $resultset_qry_re = qr/SELECT id FROM some_table WHERE last_updated IS NULL LIMIT 10/i;

    # this Comment should be at the start of all the UPDATE statements
    my $sql_comment = "-- A COMMENT\n";

    my %tests = (
        "When Updating ONE Field" => {
            setup => {
                back_fill_table_name        => $table_name,
                back_fill_primary_key_field => 'id',
                update_set                  => 'last_updated = now()',
            },
            expect => {
                statement => qr/
                    \QUPDATE ${table_name}\E\s
                    \QSET last_updated = now()\E\s
                    \QWHERE id IN ( \E ${resultset_qry_re} \Q )\E
                /xi,
            },
        },
        "When Updating TWO Fields" => {
            setup => {
                back_fill_table_name        => $table_name,
                back_fill_primary_key_field => 'id',
                update_set                  => 'last_updated = now(), ' .
                                               'start_counter = 0',
            },
            expect => {
                statement => qr/
                    \QUPDATE ${table_name}\E\s
                    \QSET last_updated = now(),\E\s
                        \Qstart_counter = 0\E\s
                    \QWHERE id IN ( \E ${resultset_qry_re} \Q )\E
                /xi,
            },
        },
        "When Updating a Handful of Fields" => {
            setup => {
                back_fill_table_name        => $table_name,
                back_fill_primary_key_field => 'foreign_key_id',
                update_set                  => "last_updated = now(), " .
                                               "start_counter = 0, " .
                                               "created = '1970-01-01 00:00:00', " .
                                               "new_status_id = 1, " .
                                               "description = 'a new field'",
            },
            expect => {
                statement => qr/
                    \QUPDATE ${table_name}\E\s
                    \QSET last_updated = now(),\E\s
                        \Qstart_counter = 0,\E\s
                        \Qcreated = '1970-01-01 00:00:00',\E\s
                        \Qnew_status_id = 1,\E\s
                        \Qdescription = 'a new field'\E\s
                    \QWHERE foreign_key_id IN ( \E ${resultset_qry_re} \Q )\E
                /xi,
            },
        },
        "When Updating Fields on a different table to the one in the Result-Set Query" => {
            setup => {
                back_fill_table_name        => 'another_table',
                back_fill_primary_key_field => 'id',
                update_set                  => 'last_updated = now(), ' .
                                               'start_counter = 0',
            },
            expect => {
                statement => qr/
                    \QUPDATE another_table\E\s
                    \QSET last_updated = now(),\E\s
                        \Qstart_counter = 0\E\s
                    \QWHERE id IN ( \E ${resultset_qry_re} \Q )\E
                /xi,
            },
        },
        "When Updating a field using an Inner query" => {
            setup => {
                back_fill_table_name        => $table_name,
                back_fill_primary_key_field => 'id',
                update_set                  => "last_updated = now(), " .
                                               "new_status_id = ( SELECT id FROM status WHERE name = 'New' ), " .
                                               "start_counter = 0",
            },
            expect => {
                statement => qr/
                    \QUPDATE ${table_name}\E\s
                    \QSET last_updated = now(),\E\s
                        \Qnew_status_id = ( SELECT id FROM status WHERE name = 'New' ),\E\s
                        \Qstart_counter = 0\E\s
                    \QWHERE id IN ( \E ${resultset_qry_re} \Q )\E
                /xi,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # update the Back-Fill Job record for the Test
        # including the Result-Set query fields
        my $update_rec_args = { %resultset_fields, %{ $setup } };
        $back_fill_job_rec->discard_changes->update( $update_rec_args );

        # get an Instance of 'XT::DB::BackFill'
        my $backfill_obj = $self->_get_backfill_obj( $back_fill_job_rec, {
            # use a known comment
            sql_comment => $sql_comment,
        } );

        my $expect_query = $expect->{statement};

        my $got = $backfill_obj->build_update_statement;
        like( $got, qr/^${sql_comment}${expect_query}/, "UPDATE Statement (including Comment) built as Expected" );
    }
}

=head2 test_get_statement_handle_for_update

Tests the 'get_statement_handle_for_update' method that returns a Statement
Handle for the Update query, it will also test that the correct Exception
get thrown if a Statement Handle can't be created.

=cut

sub test_get_statement_handle_for_update : Tests {
    my $self = shift;

    my $back_fill_job_rec = $self->_data->back_fill_job;

    # set some defaults for some of the fields
    $back_fill_job_rec->update( {
        resultset_select    => undef,
        resultset_order_by  => undef,
        max_rows_to_update  => 10,
    } );

    my %tests = (
        "With a Valid UPDATE SQL Statement" => {
            setup => {
                back_fill_table_name        => 'some_table',
                back_fill_primary_key_field => 'id',
                update_set                  => 'last_updated = now()',
                resultset_from              => 'some_table',
                resultset_where             => 'last_updated IS NULL',
            },
            expect => {
                to_live => 1,
            },
        },
        "With an Invalid UPDATE SQL Statement" => {
            setup => {
                back_fill_table_name        => 'some_table',
                back_fill_primary_key_field => 'id',
                update_set                  => 'last_updated = ?',
                resultset_from              => 'some_table',
                resultset_where             => 'last_updated IS NULL',
            },
            expect => {
                to_die           => 1,
                exception_thrown => 'XT::DB::BackFill::Exception::CanNotCreateUpdateStatementHandle',
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "TEST: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # setup the Back Fill Job record
        $back_fill_job_rec->discard_changes->update( $setup );

        my $backfill_obj = $self->_get_backfill_obj( $back_fill_job_rec );

        if ( $expect->{to_live} ) {
            my $sth;
            lives_ok {
                $sth = $backfill_obj->get_statement_handle_for_update;
            } "called 'get_statement_handle_for_update' without an Exception being thrown";
            isa_ok( $sth, 'DBI::st', "and the return value is a Statement Handle" );
        }

        if ( $expect->{to_die} ) {
            throws_ok {
                my $sth = $backfill_obj->get_statement_handle_for_update;
            } $expect->{exception_thrown}, "an Error was thrown with the Expected Exception";
        }
    }
}

=head2 test_run_job_with_exceptions

This tests the method 'run_job' (which actually runs
the UPDATE statement) when there are exceptions thrown.

=cut

sub test_run_job_with_exceptions : Tests {
    my $self = shift;

    # set some defaults for some of the fields
    my %default_update_args = (
        resultset_select    => undef,
        resultset_order_by  => undef,
        max_rows_to_update  => 2,
    );

    my %tests = (
        "An Invalid Update Statement that should throw an Exception" => {
            setup => {
                back_fill_table_name        => 'some_table_that_doesnt_exist',
                back_fill_primary_key_field => 'id',
                update_set                  => 'last_updated = now()',
                resultset_from              => 'some_table_that_doesnt_exist',
                resultset_where             => 'last_updated IS an elephant',
            },
            expect => {
                to_die           => 1,
                exception_thrown => 'XT::DB::BackFill::Exception::CanNotExecuteUpdateStatement',
            },
        },
        "An Update Statement with a Place Holder that should throw an Exception" => {
            setup => {
                back_fill_table_name        => 'customer',
                back_fill_primary_key_field => 'id',
                update_set                  => 'credit_check = ?',
                resultset_from              => 'customer',
                resultset_where             => "credit_check IS NULL",
            },
            expect => {
                to_die           => 1,
                exception_thrown => 'XT::DB::BackFill::Exception::CanNotCreateUpdateStatementHandle',
            },
        },
        "When the Time to Start Back Fill has not been Reached Yet" => {
            setup => {
                back_fill_table_name        => 'some_table_that_doesnt_exist',
                back_fill_primary_key_field => 'id',
                update_set                  => 'last_updated = now()',
                resultset_from              => 'some_table_that_doesnt_exist',
                resultset_where             => 'last_updated IS an elephant',
                time_to_start_back_fill     => $self->schema->db_now->clone->add( days => 1 ),
            },
            expect => {
                to_die           => 1,
                exception_thrown => 'XT::DB::BackFill::Exception::NotAbleToRunJob',
            },
        },
        "When the Back Fill Job Status is not Valid to be Run" => {
            setup => {
                back_fill_table_name        => 'some_table_that_doesnt_exist',
                back_fill_primary_key_field => 'id',
                update_set                  => 'last_updated = now()',
                resultset_from              => 'some_table_that_doesnt_exist',
                resultset_where             => 'last_updated IS an elephant',
                back_fill_job_status_id     => $DBADMIN_BACK_FILL_JOB_STATUS__ON_HOLD,
            },
            expect => {
                to_die           => 1,
                exception_thrown => 'XT::DB::BackFill::Exception::NotAbleToRunJob',
            },
        },
    );

    # because the above tests will generate DB failures, each
    # test can't be in a transaction because this will cause
    # all subsequent DB requests to fail until a rollback
    # is issued, so rollback the transaction that is started in
    # test 'setup' and at the end of this method start another
    # transaction which will get rolled back by test 'teardown'.
    $self->schema->txn_rollback;

    foreach my $label ( keys %tests ) {
        note "TEST: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        my $back_fill_job_rec = Test::XTracker::Data::DBAdminBackFillJob->create_one_back_fill_job( {
            %default_update_args,
            %{ $setup },
        } );

        my $backfill_obj = $self->_get_backfill_obj( $back_fill_job_rec );

        throws_ok {
            $backfill_obj->run_job;
        } $expect->{exception_thrown}, "an Error was thrown with the Expected Exception";

        $self->_common_run_job_test( $backfill_obj, 0 );
    }


    # start another transaction for test 'teardown' to
    # rollback so as not to break the whole test class
    $self->schema->txn_begin;
}

=head2 test_run_job_happy_path

This tests the method 'run_job' which actually runs
the UPDATE statement through the happy path.

=cut

sub test_run_job_happy_path : Tests {
    my $self = shift;

    # create three Customers that will be updated
    my @customers = map {
        Test::XTracker::Data->create_dbic_customer( {
            channel_id   => Test::XTracker::Data->any_channel->id,
            credit_check => undef,
        } )
    } 1..3;

    # this will be used so only the new records are included
    my $min_cust_id = $customers[0]->id;

    # set-up a count to get the number of Customer
    # records updated by the Back-fill Job
    my $customer_rs = $self->rs('Public::Customer')->search( {
        id           => { '>=' => $min_cust_id },
        credit_check => { '!=' => undef },
    } );

    my $back_fill_job_rec = $self->_data->back_fill_job;

    # set-up the back-fill job record, so that
    # two records will get uodated each time
    $back_fill_job_rec->update( {
        resultset_select            => undef,
        resultset_order_by          => undef,
        max_rows_to_update          => 2,
        back_fill_table_name        => 'customer',
        back_fill_primary_key_field => 'id',
        update_set                  => 'credit_check = now()',
        resultset_from              => 'customer',
        resultset_where             => "credit_check IS NULL AND id >= ${min_cust_id}",
    } );

    # run the following three tests in the following sequence
    my @tests = (
        {
            label => "Run the Back-fill Job, should update Two records",
            expect => {
                number_of_rows     => 2,
                total_rows_updated => 2,
            },
        },
        {
            label => "Run the Back-fill Job, should update One record",
            expect => {
                number_of_rows     => 1,
                total_rows_updated => 3,
            },
        },
        {
            label => "Run the Back-fill Job, should update ZERO records",
            expect => {
                number_of_rows     => 0,
                total_rows_updated => 3,
            },
        },
    );

    foreach my $test ( @tests ) {
        note "TEST: " . $test->{label};
        my $expect = $test->{expect};

        my $backfill_obj = $self->_get_backfill_obj( $back_fill_job_rec->discard_changes );

        my $num_recs;
        lives_ok {
            $num_recs = $backfill_obj->run_job;
        } "called 'run_job' without an Exception being thrown";

        cmp_ok( $num_recs, '==', $expect->{number_of_rows},
                        "'run_job' returned the Expected Number of Rows" );
        cmp_ok( $backfill_obj->record_count, '==', $expect->{number_of_rows},
                        "and 'record_count' Attribute has been set correctly" );
        cmp_ok( $customer_rs->reset->count, '==', $expect->{total_rows_updated},
                        "and the Expected number of Records have actually been Updated" );

        $self->_common_run_job_test( $backfill_obj, 1 );
    }
}

#-----------------------------------------------------------------------------

# some common tests for the 'run_job' method
sub _common_run_job_test {
    my ( $self, $backfill_obj, $check_for_success ) = @_;

    ok( defined $backfill_obj->start_time, "'start_time' has been set" );
    ok( defined $backfill_obj->finish_time, "'finish_time' has been set" );

    ok( $backfill_obj->was_run, "'was_run' method returns TRUE" );

    if ( $check_for_success ) {
        ok( $backfill_obj->run_and_successful, "'run_and_successful,' method returns TRUE" );
        ok( !$backfill_obj->run_and_error_thrown, "'run_and_error_thrown,' method returns FALSE" );
    }
    else {
        ok( $backfill_obj->run_and_error_thrown, "'run_and_error_thrown,' method returns TRUE" );
        ok( !$backfill_obj->run_and_successful, "'run_and_successful,' method returns FALSE" );
    }

    return;
}

sub _get_backfill_obj {
    my ( $self, $back_fill_job_rec, $other_args ) = @_;

    return XT::DB::BackFill->new( {
        back_fill_job => $back_fill_job_rec,
        ( $other_args ? %{ $other_args } : () ),
    } );
}

sub _data {
    my $self = shift;
    return $self->{data};
}

