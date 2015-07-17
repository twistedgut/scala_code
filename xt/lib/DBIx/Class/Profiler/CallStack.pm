package DBIx::Class::Profiler::CallStack;
use strict;
use warnings;
use base 'DBIx::Class::Storage::Statistics';

=head1 NAME

DBIx::Class::Profiler::CallStack - DBIC logging of SQL query duration, and where it was called from

=head1 SYNOPSIS

    # On your command line / in your environment
    export DBIC_TRACE=1=/sql_duration_and_call_stack.log

    use DBIx::Class::Profiler::CallStack;
    my $schema = ...;
    DBIx::Class::Profiler::CallStack->enable_for_schema($self->schema);

    # Run queries with the $scema


=head1 DESCRIPTION

This DBIx::Class::Storage::Statistics based Profiler will log DBCI SQL
queries

Two log lines are logged for each request:

  SQL: {UPDATE ... WHERE ( id = ? )} PARAMS: {'1446'} CALLERS: {SQL executed at /a/File.pm line 74 <-- A::Class::update(', '<HASH>') called at /a/File.pm line 107 ... }

  EXECUTED: {UPDATE ... WHERE ( id = ? )} DURATION: {0.0011}

The first line contains the full parameter list and the call stack
separated by <--. This is useful for getting detailed information
about the query and where it came from.

The second line contains the stable SQL literal without parameters,
along with the query time. This is useful for collecting statistics
per query.


=head2 Configuration

If you run an Apache server, the output will end up in the error log
by default.

If you want to redirect the trace output to a file, set the DBIC_TRACE
environment variable

    export DBIC_TRACE=1=$(pwd)/../temp/logs/dbic.log

(It seems it must be absolute)

This will also log vanilla SQL queries, so you may need to filter
those out to focus on the CallStack log lines.

Make sure you have Apache configured to let the trace variables
propagate into your mod_perl application:

    PerlPassEnv DBI_TRACE
    PerlPassEnv DBIC_TRACE
    PerlPassEnv DBIC_TRACE_PROFILE

=cut


use Devel::StackTrace;
use Time::HiRes qw(time);



my $start;

sub query_start {
    my ($self, $sql, @params) = @_;

    my $trace = Devel::StackTrace->new(
        message      => "SQL executed",
        ignore_class => [
            # "main",
            "DBIx::Class",
            "Test::Class", # ?
            "Try::Tiny",
        ],
    );

    my $callers = $trace->as_string;
    chomp($callers);
    $callers =~ s/\n/ <-- /gsm;
    $callers =~ s/=?(HASH|ARRAY)\(0x\w+\)/<$1>/gsm;

    $self->print(
        "SQL: {$sql} PARAMS: {"
        . join( ', ', @params )
        . "} CALLERS: {$callers}\n",
    );

    $start = time();
}

sub query_end {
    my ($self, $sql, @params) = @_;

    my $elapsed = sprintf("%0.4f", time() - $start);
    $self->print("EXECUTED: {$sql} DURATION: {$elapsed}\n");

    $start = undef;
}

sub enable_for_schema {
    my ($class, $schema) = @_;
    $schema->isa("DBIx::Class::Schema") or return;
    $schema->storage->debugobj($class->new());
    $schema->storage->debug(1);
}

sub disable_for_schema {
    my ($class, $schema, $enable) = @_;
    $schema->isa("DBIx::Class::Schema") or return;
    $schema->storage->debugobj(undef);
    $schema->storage->debug(0);
}

1;
