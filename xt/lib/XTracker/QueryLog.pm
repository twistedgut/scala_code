package XTracker::QueryLog;
# vim: ts=8 sts=4 et sw=4 sr sta
use NAP::policy;

use DBIx::QueryLog ();
use Log::Log4perl::Level;
use XTracker::Logfile qw/ xt_logger /;

sub start {
    my ($class) = @_;

    # There's no reason to start twice in the same process
    unless (DBIx::QueryLog->is_enabled) {

        # Retrieve the Log4perl object
        my $logger = xt_logger('QueryLog')
            or xt_logger->warn('No QueryLog in the logging configuration files')
            and return;

        # Log scrubbed SQL at level DEBUG
        # and log full SQL at level TRACE
        if ($logger->is_debug) {

            DBIx::QueryLog->skip_bind(1) unless $logger->is_trace;

            $DBIx::QueryLog::OUTPUT = sub {
                my %params = @_;
                $logger->debug(
                    sprintf ( "[%fs] %s at %s line %d\n",
                              @params{qw/time sql file line/} )
                );
            };

            DBIx::QueryLog->enable;
        }
    }

    return;
}

1;

__END__

=pod

=head1 NAME

XTracker::QueryLogger - for logging SQL queries

=head1 SYNOPSIS

Configure within Log4perl by setting LOGLEVEL_SQL to:
 TRACE (full queries)
 DEBUG (no params shown)

 XTracker::QueryLogger->start;

=head1 DESCRIPTION

This module:

=over

=item

logs all SQL queries passing through the DBI handle

=item

does not display potentially sensitive query data at log level DEBUG

=back

=head1 SEE ALSO

 XTracker::QueryAnalyzer (one-hit SQL log to html file)
 XTracker::Database (webdbh_logging - DBI trace for webs)

=head1 AUTHOR

Philip Abrahamson C<< <philip.abrahamson@net-a-porter.com> >>

=cut
