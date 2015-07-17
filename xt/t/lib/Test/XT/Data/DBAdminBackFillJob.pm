package Test::XT::Data::DBAdminBackFillJob;

use NAP::policy     qw( test role );

requires 'schema';

=head1 NAME

Test::XT::Data::DBAdminBackFillJob

=head1 DESCRIPTION

Create a Back Fill Job record in the 'dbadmin.back_fill_job' table.

=cut

use XTracker::Constants::FromDB     qw( :dbadmin_back_fill_job_status );
use XTracker::Config::Local         qw( config_var );

use Test::XTracker::Data;

use DateTime;

use Log::Log4perl ':easy';
Log::Log4perl->easy_init({ level => $INFO });

use String::Random;


has _random_string_obj => (
    is       => 'ro',
    init_arg => undef,
    default  => sub {
        return String::Random->new( max => 10 );
    },
);

=head1 ATTRIBUTES

=head2 back_fill_job

The 'back_fill_job' record.

=cut

has back_fill_job => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_back_fill_job',
);

=head2 new_column_name

This is not a column on the 'back_fill_job' table but is used to set
the defaults of some of the Attributes below. This is the name of the
new column that has been added and is requiring back-filling. The
default is 'new_column_added'.

=cut

has new_column_name => (
    is      => 'rw',
    lazy    => 1,
    default => 'new_column_added',
);


=head2 name

The name for the Back-fill job, default is 'Back Fill Job - '
followed by a Random String and these need to be unique within
the table.

=cut

has name => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return 'Back Fill Job - ' . $self->_get_random_string;
    },
);

=head2 description

A description for the Back-fill job, default is undef.

=cut

has description => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->name . ' Description';
    },
);

=head2 back_fill_job_status_id

The Status Id for the Back-fill job, default is 'New'.

=cut

has back_fill_job_status_id => (
    is      => 'rw',
    lazy    => 1,
    default => $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
);

=head2 back_fill_table_name

The table name that will be back-filled, default is 'customer'.

=cut

has back_fill_table_name => (
    is      => 'rw',
    lazy    => 1,
    default => 'customer',
);

=head2 back_fill_primary_key_field

The primary key of the back-fill table, default is 'id'.

=cut

has back_fill_primary_key_field => (
    is      => 'rw',
    lazy    => 1,
    default => 'id',
);

=head2 update_set

What gets put in the SET part of the UPDATE statement, the default
is the value of 'new_column_name' and the literal 'BACKFILL':

    new_column_added = 'BACKFILL'

=cut

has update_set => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->new_column_name . " = 'BACKFILL'";
    },
);

=head2 resultset_select

What forms the SELECT part of the Result Set Query, default is undef,

=cut

has resultset_select => (
    is => 'rw',
);

=head2 resultset_from

What forms the FROM part of the Result Set Query, default is
the value of 'back_fill_table_name'.

=cut

has resultset_from => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->back_fill_table_name;
    },
);

=head2 resultset_where

What forms the WHERE part of the Result Set Query, default is
the value of 'new_column_name' equalling NULL:

    'new_column_added IS NULL'

=cut

has resultset_where => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->new_column_name . ' IS NULL';
    },
);

=head2 resultset_order_by

What forms the ORDER BY part of the Result Set Query, default is undef.

=cut

has resultset_order_by => (
    is  => 'rw',
);

=head2 max_rows_to_update

The number of rows to update at a time, default is 1.

=cut

has max_rows_to_update => (
    is      => 'rw',
    lazy    => 1,
    default => 1,
);

=head2 max_jobs_to_create

The number of Job to create on TheSchwartz Job Queue, default is 2.

=cut

has max_jobs_to_create => (
    is      => 'rw',
    lazy    => 1,
    default => 2,
);

=head2 time_to_start_back_fill

The Time that the Back-fill can start from, default is now().

=cut

has time_to_start_back_fill => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->schema->db_now();
    },
);

=head2 contact_email_address

The Email address to send alerts to, default is the xtracker email address.

=cut

has contact_email_address => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return config_var('Email', 'xtracker_email');
    },
);


# Create a Back Fill Job
sub _set_back_fill_job {
    my $self    = shift;

    my %create_args = map { $_ => $self->$_ } qw(
        name
        description
        back_fill_job_status_id
        back_fill_table_name
        back_fill_primary_key_field
        update_set
        resultset_select
        resultset_from
        resultset_where
        resultset_order_by
        max_rows_to_update
        max_jobs_to_create
        time_to_start_back_fill
        contact_email_address
    );
    my $back_fill_job = $self->schema->resultset('DBAdmin::BackFillJob')->create( \%create_args );

    note "Back Fill Job Created: '(" .  $back_fill_job->id . ") " . $back_fill_job->name . "'";

    return $back_fill_job;
}


sub _get_random_string {
    my $self = shift;
    return $self->_random_string_obj->randregex( '\w' x 10 );
}

1;
