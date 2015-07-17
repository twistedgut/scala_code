package XT::DB::BackFill;

use NAP::policy     qw( class );

=head1 NAME

XT::DB::BackFill

=head1 SYNOPSIS

    use XT::DB::BackFill;

    my $backfill;
    try {
        $backfill = XT::DB::BackFill->new( {
            back_fill_job => $back_fill_job_dbic_record,
        } );
        $backfill->run_job();
    } catch {
        $log->error( $_ );
        ...
    }

    # find out how many records were updated
    my $number_of_records_updated = $backfill->record_count;

    # find out when the Back-Fill started and finished
    my $start_time  = $backfill->start_time;
    my $finish_time = $backfill->finish_time;

=head1 DESCRIPTION

Given a 'dbadmin.back_fill_job' record this Class will run the Job. This means
the SQL will be built and then run to actually update the records.

It will provide a record count of how many records were updated along with
the Start and Finish timestamps so that the duration it took can be tracked.

This class will also throw Exception Classes that are extended
from 'XT::DB::BackFill::Exception'.

It will run the Update Statement in its own Transaction so there is no
need to start your own transaction and call 'run_job' within it.

=cut

use XT::DB::BackFill::Type  qw( EmptyOrPrettySQLComment );

use XT::DB::BackFill::Exception::InvalidMaxRowsToUpdate;
use XT::DB::BackFill::Exception::CanNotCreateUpdateStatementHandle;
use XT::DB::BackFill::Exception::CanNotExecuteUpdateStatement;
use XT::DB::BackFill::Exception::NotAbleToRunJob;

use Scalar::Util            qw( blessed );


=head1 ATTRIBUTES

=head2 back_fill_job

The DBIC DBAdmin::BackFillJob record that will be used to do the back-filling.

=cut

has back_fill_job => (
    is       => 'ro',
    isa      => 'XTracker::Schema::Result::DBAdmin::BackFillJob',
    required => 1,
);

=head2 record_count

The number of Records that get Updated.

=cut

has record_count => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
    writer  => '_set_record_count',
    init_arg=> undef,
);

=head2 start_time

=head2 finish_time

The Start and Finish times of the Back-filling, this can be
used to track how long each Back-fill takes.

'XTracker::Schema->db_clock_timestamp()' will be used to get
the time as this uses a Pg function that returns the current
time even when in a Transaction.

These attributes won't have any values until they've been set. Set
them by using the methods 'set_start_time' and 'set_finish_time'.

=cut

has start_time => (
    is      => 'ro',
    isa     => 'DateTime',
    writer  => '_set_start_time',
    init_arg=> undef,
);

has finish_time => (
    is      => 'ro',
    isa     => 'DateTime',
    writer  => '_set_finish_time',
    init_arg=> undef,
);

=head2 schema

DBIC Schema connection derived from the 'back_fill_job' DBIC object.

=cut

has schema => (
    is      => 'ro',
    isa     => 'XTracker::Schema',
    lazy    => 1,
    builder => '_build_schema',
    init_arg=> undef,
);

sub _build_schema {
    my $self = shift;
    return $self->back_fill_job
                ->result_source
                ->schema;
}

=head2 dbh

The DBI Database Handler, this will be derived from the
'back_fill_job' DBIC object. This is used to execute the
SQL Update because new Columns won't exist in any DBIC
Class initially.

=cut

has dbh => (
    is      => 'ro',
    isa     => 'DBI::db',
    lazy    => 1,
    builder => '_build_dbh',
    init_arg=> undef,
);

sub _build_dbh {
    my $self = shift;
    return $self->schema->storage->dbh;
}

=head2 sql_comment

This will hold the SQL Comment that will appear at the front of
the UPDATE statement, which means that checking the active
statements on the Database will easily identify this query
which could be useful if it is the cause of DB Locks.

The default will be this Package Name along with the Back Fill
Job Id and the Process Id.

This uses the 'XT::DB::BackFill::Type::EmptyOrPrettySQLComment' Type
along with Coercion to get a normal String into an SQL Comment
format with leading '-- ' and a newline character at the end.

=cut

has sql_comment => (
    is      => 'rw',
    isa     => EmptyOrPrettySQLComment,
    lazy    => 1,
    builder => '_build_sql_comment',
    coerce  => 1,
);

sub _build_sql_comment {
    my $self = shift;

    my $back_fill_job_id = $self->back_fill_job->id;
    my $package_name     = __PACKAGE__;
    my $proc_id          = $$;

    # need a 'newline' at the end otherwise
    # it will comment out the whole statement
    return "-- (PID: ${proc_id}) - ${package_name} - Job Id: ${back_fill_job_id}\n";
}


# private Attributes

# use this to determine if the Back-fill Job has been run yet
has _was_run => (
    is        => 'rw',
    isa       => 'Bool',
    init_arg  => undef,
    default   => 0,
    reader    => 'was_run',
);

# if an error was thrown then set this to TRUE,
# this is used by the method 'run_and_error_thrown'
# and by 'run_and_successful' which checks that
# this field is FALSE.
has _error_was_thrown => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    init_arg=> undef,
);


=head1 METHODS

=head2 run_job

    my $number_of_records = $self->run_job;

This will run the UPDATE Statement to actually do the
back-filling of the records.

It will return the number of records processed and also
set the 'record_count' Attribute.

The Update Statement will be done within a Transaction.

=cut

sub run_job {
    my $self = shift;

    my $update_sth;

    $self->set_start_time;

    try {
        # first check that it's ok to run the Job
        if ( !$self->back_fill_job->job_ok_to_run ) {
            XT::DB::BackFill::Exception::NotAbleToRunJob->throw( {
                job_name   => $self->back_fill_job->name,
                start_time => $self->back_fill_job->time_to_start_back_fill,
                job_status => $self->back_fill_job->back_fill_job_status->status,
            } );
        }

        $self->schema->txn_do( sub {
            $update_sth = $self->get_statement_handle_for_update;
            my $result  = $update_sth->execute();
            if ( !defined $result ) {
                # if result is undefined then an error occured
                die "'execute' returned 'undef', sth->err is: " . ( $update_sth->err // 'undefined' ) . "\n";
            }
        } );
    } catch {
        $self->set_finish_time;
        $self->_was_run( 1 );
        $self->_error_was_thrown( 1 );

        if ( blessed( $_ ) && $_->isa('XT::DB::BackFill::Exception')  ) {
            # if it's a known Exception (meaning the Exception class
            # extends 'XT::DB::BackFill::Exception') then throw it again
            die $_;
        }

        my $error_message = $_;

        XT::DB::BackFill::Exception::CanNotExecuteUpdateStatement->throw( {
            job_name    => $self->back_fill_job->name,
            error       => $error_message,
            update_sql  => $self->build_update_statement,
        } );
    };

    $self->set_finish_time;
    $self->_was_run( 1 );

    # set and return the number of rows updated
    return $self->_set_record_count( $update_sth->rows );
}

=head2 build_resultset_query

    $string = $self->build_resultset_query;

Builds the ResultSet Query that will be used in the Update statement.

This will use the 'resultset_' fields on the Back-Fill Job record.

=cut

sub build_resultset_query {
    my $self = shift;

    my $back_fill_job = $self->back_fill_job;

    # if 'resultset_select' hasn't been specified
    # then just use the Primary Key field
    my $select   = $back_fill_job->resultset_select ||
                        $back_fill_job->back_fill_primary_key_field;

    my $from     = $back_fill_job->resultset_from;
    my $where    = $back_fill_job->resultset_where;
    # if 'resultset_order_by' is undefined then use an empty string
    my $order_by = $back_fill_job->resultset_order_by || "";

    return
        "SELECT ${select} " .
        "FROM ${from} " .
        "WHERE ${where}" .
        ( $order_by ? " ORDER BY ${order_by}" : "" )
    ;
}

=head2 build_limited_resultset_query

    $string = $self->build_limited_resultset_query;

Will buld the ResultSet Query using 'build_resultset_query' and then
append a 'LIMIT' to it using the 'max_rows_to_update' value from
the Back-Fill Job record.

=cut

sub build_limited_resultset_query {
    my $self = shift;

    my $max_rows = $self->back_fill_job->max_rows_to_update;
    if ( $max_rows <= 0 ) {
        XT::DB::BackFill::Exception::InvalidMaxRowsToUpdate->throw( {
            job_name           => $self->back_fill_job->name,
            max_rows_to_update => $self->back_fill_job->max_rows_to_update,
        } );
    };

    my $query = $self->build_resultset_query;

    return "${query} LIMIT ${max_rows}";
}

=head2 build_update_statement

    $string = $self->build_update_statement;

Will build the UPDATE Statement that actually updates the
fields using 'build_limited_resultset_query' to get the
Result-Set of records to update.

=cut

sub build_update_statement {
    my $self = shift;

    my $back_fill_job = $self->back_fill_job;

    my $table_to_update  = $back_fill_job->back_fill_table_name;
    my $primary_key      = $back_fill_job->back_fill_primary_key_field;
    my $fields_to_update = $back_fill_job->update_set;

    # get the Result-Set Query which will be
    # used in the 'IN' part of the WHERE clause
    my $resultset_query = $self->build_limited_resultset_query;

    # build the UPDATE statement with the SQL Comment first
    return
        $self->sql_comment .
        "UPDATE ${table_to_update} " .
        "SET ${fields_to_update} " .
        "WHERE ${primary_key} IN ( " .
            $resultset_query .
        " )"
    ;
}

=head2 get_statement_handle_for_update

    $sth = $self->get_statement_handle_for_update;

This will call the method 'build_update_statement' and then
produce a Statement Handle which can then be executed to
actually update the records.

An exception will be thrown if the Statement Handle can't
be created.

=cut

sub get_statement_handle_for_update {
    my $self = shift;

    my $update_sql = $self->build_update_statement;

    my $sth;

    try {
        $sth = $self->dbh->prepare( $update_sql );

        # check if there are any placeholders in the query,
        # because if they are they are not going to be binded
        my $num_bind_params = $sth->{NUM_OF_PARAMS} // 0;
        if ( $num_bind_params > 0 ) {
            die "There are ${num_bind_params} PlaceHolders (?) in the statement & they won't be associated with any values\n";
        }
    } catch {
        my $error_message = $_;
        XT::DB::BackFill::Exception::CanNotCreateUpdateStatementHandle->throw( {
            job_name    => $self->back_fill_job->name,
            error       => $error_message,
            update_sql  => $update_sql,
        } );
    };

    return $sth;
}

=head2 set_start_time

    $self->set_start_time;

Sets the 'start_time' Attribute with the Current Time at the time
of the call to this method.

=cut

sub set_start_time {
    my $self = shift;
    $self->_set_start_time( $self->schema->db_clock_timestamp() );
    return;
}

=head2 set_finish_time

    $self->set_finish_time;

Sets the 'finish_time' Attribute with the Current Time at the time
of the call to this method.

=cut

sub set_finish_time {
    my $self = shift;
    $self->_set_finish_time( $self->schema->db_clock_timestamp() );
    return;
}

=head2 was_run

A boolean that returns whether the Back-fill Job
has been run or not. Use the next two to indicate
whether the Job run Successfully or an Error was
thrown.

=head2 run_and_successful

=head2 run_and_error_thrown

These two methods are booleans that indicate whether the Backfill-job
was run succesfully (which can include updating zero records) or
whether an error was throws whilst running.

=cut

sub run_and_successful {
    my $self = shift;
    return $self->was_run && !$self->_error_was_thrown;
}

sub run_and_error_thrown {
    my $self = shift;
    return $self->was_run && $self->_error_was_thrown;
}

