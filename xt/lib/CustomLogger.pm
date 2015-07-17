package CustomLogger;
use NAP::policy "tt";
use Devel::StackTrace;
use Carp;

use XTracker::Logfile qw( xt_logger );
use XTracker::Config::Local qw/config_var/;

my $logger = xt_logger( qw( Web_DBH ) );

sub new {
    my $self = {};

    $self->{_logger} = $logger;
    $self->{_buf} = '';
    return bless $self, shift;
}

sub log {
    my $self = shift;
    return unless exists $self->{_logger};
    my $log = $self->{_logger};

    $self->{_buf} .= shift;
#
# DBI feeds us pieces at a time, so accumulate a complete line
# before outputing
#
    my $trace = Devel::StackTrace->new;
    if ($self->{_buf} =~ tr/\n//) {
        $log->info(
            $self->{_buf}
            . $trace->as_string
            . "\n");
        $self->{_buf} = ''
    }
}

sub close {
    my $self = shift;
    return unless exists $self->{_logger};
    delete $self->{_logger};
}

1;
