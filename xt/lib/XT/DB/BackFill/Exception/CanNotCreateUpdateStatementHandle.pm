package XT::DB::BackFill::Exception::CanNotCreateUpdateStatementHandle;

use NAP::policy     qw( class );
extends 'XT::DB::BackFill::Exception';

=head1 NAME

XT::DB::BackFill::Exception::CanNotCreateUpdateStatementHandle

=head1 SYNOPSIS

    package My::Class;

    ...

    use XT::DB::BackFill::Exception::CanNotCreateUpdateStatementHandle;

    ...

    sub my_method {
        try {
            $sth = $dbh->prepare( $update_sql_string );
        } catch {
            my $error_message = $_;
            XT::DB::BackFill::Exception::CanNotCreateUpdateStatementHandle->throw( {
                job_name   => $back_fill_job_rec->name,
                update_sql => $update_sql_string,
                error      => $error_message,
            } );
        };
    };

=head1 DESCRIPTION

Used to generate an Exception when a Statement Handle can't be created
for the UPDATE SQL Statement.

This Class extends 'XT::DB::BackFill::Exception'.

=cut


=head1 ATTRIBUTES

=head2 update_sql

The UPDATE SQL Statement that caused the issue.

=cut

has update_sql => (
    is      => 'ro',
    isa     => 'Str',
);

=head2 +message

The error message that gets generated.

=cut

has '+message' => (
    default  => '[DB Back-Fill Error] - Back Fill Job: %{job_name}s' .
                " - Can't create a Statement Handle for the SQL UPDATE Statement: \%{update_sql}s," .
                ' with Error: %{error}s,' .
                ' found at %{stack_trace}s',
);

