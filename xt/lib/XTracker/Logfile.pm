package XTracker::Logfile;

=head2 NAME

XTracker::Logfile - Write log messages

=head2 SYNPOSIS

    use XTracker::Logfile 'xt_logger';

    xt_logger->trace("What exactly is happening in here");
    xt_logger->debug("Stuff that might be useful");
    if (xt_logger->is_debug) {
        my $data = expensive_method_call()->{something};
        xt_logger->debug("Data is $data");
    }
    xt_logger->info("A normal thing happened");
    xt_logger->warn("Warning, but continuing");
    xt_logger->error("Error");

=head2 SEE ALSO

http://confluence.net-a-porter.com/display/BAK/Logging

=cut

use strict;
use warnings;

use Perl6::Export::Attrs;
use Log::Log4perl;
use XTracker::Config::Local qw( log_conf_dir );

my $CONFIG_RELOAD_DELAY = 5 * 60; # config watch in seconds

BEGIN {
    unless ($ENV{NO_XT_LOGGER}) {
        my $log_conf_file = log_conf_dir();
        $log_conf_file .= '/' if ($log_conf_file !~ /\/$/);
        # If we haven't specified a log4perl conf in XT_LOGCONF and we are
        # running tests (i.e. HARNESS_ACTIVE is true), pick test.conf.
        # Otherwise the assumptions we are running scripts (or something
        # non-test-related anyway), and we want to log with a different
        # profile.
        $log_conf_file .= $ENV{XT_LOGCONF}
                      ||= ( $ENV{HARNESS_ACTIVE} ? 'test.conf' : 'default.conf' );
        if (!Log::Log4perl->initialized()) {
            Log::Log4perl::init_and_watch($log_conf_file, $CONFIG_RELOAD_DELAY);

    # setup handler to redirect warn messages
            $SIG{__WARN__} = sub { ## no critic(RequireLocalizedPunctuationVars)
                local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
                my $logger = Log::Log4perl->get_logger("");
                $logger->warn(@_);
                warn @_;
            };

            # Setup handler so ALL die commands will be written to log.
            #
            # Apparently the correct way is to use *CORE::GLOBAL::die,
            # couldnt get this to work tho, so leaving as $SIG{__DIE__}.

            $SIG{__DIE__} = sub { ## no critic(RequireLocalizedPunctuationVars)
                # this was added to catch undefined $^S which seems
                # to happen if an eval fails in a BEGIN block
                if ((!defined($^S)) || ($^S)) {
                    # We're in an eval {} and don't want log
                    # this message but catch it later
                   return;
                }

                local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
                my $logger = Log::Log4perl->get_logger("");
                $logger->fatal(@_);
                die @_; # Now terminate really
            };
        }
    }
}



### Subroutine : xt_logger                      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #
sub xt_logger :Export() {
    my $category = shift || undef;

    if ($category)  {
        return Log::Log4perl->get_logger($category);
    } else {
        return Log::Log4perl->get_logger((caller(0))[0]);
    }
}

1;
