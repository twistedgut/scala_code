package Test::More::DBI;

=head1 NAME

Test::More::DBI - Put test output in the DBI trace output

=head1 DESCRIPTION

Put diag / note, etc. messages in the DBI trace output.

Also, increase the max length of the SQL queries.

=head1 SYNOPSIS

 use Test::More::DBI qw/ dbi_trace /;

 dbi_trace("Doing that ting");    # Put "Doing that ting" in the
                                  # DBI_TRACE output

 dbi_trace(note     => "Doing that ting"); # also note("Doing that ting")
 dbi_trace(diag     => "Doing that ting"); # also diag("Doing that ting")
 dbi_trace(whatever => "Doing that ting"); # this actually works for any function call

Note that note/diag/etc will always put your $message on a new line,
but the DBI trace message will keep the following SQL query on the
same line if you don't end it with '\n'.

This means you can easily grep the DBI trace output for just the
queries you add a trace message for.

=head1 AUTHOR

Johan Lindstrom - C<johanl@cpan.org> on behalf of
L<http://www.net-a-porter.com/|Net-A-Porter>.

=cut

use strict;
use warnings;

use parent 'Exporter';
our @EXPORT_OK = qw(dbi_trace);


use DBI;
{
    no warnings "once"; ## no critic(ProhibitNoWarnings)
    $DBI::neat_maxlen = 8000;
}

sub dbi_trace {
    my $message = pop // "";
    my $output_sub = pop;

    {
        no strict "refs"; ## no critic(ProhibitNoStrict)
        $output_sub and &$output_sub($message);
    }

    DBI->trace_msg($message);
}

1;
