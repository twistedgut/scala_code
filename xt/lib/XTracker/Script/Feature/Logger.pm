package XTracker::Script::Feature::Logger;

use Moose::Role;

use feature         qw( say );

requires 'log4perl_category';

=head1 NAME

XTracker::Script::Feature::Logger

=head1 DESCRIPTION

This role provides the script with  Logging facility.

=head1 SYNOPSIS

  package MyScript;
  use Moose;
  extends 'XTracker::Script';
  with 'XTracker::Script::Feature::Logger';

  sub invoke {
    # normal script stuff here - with $self->logger available
  }

  1;

=cut

use XTracker::Logfile       qw( xt_logger );

has logger => (
    isa => 'Log::Log4perl::Logger',
    is => 'rw',
    lazy_build => 1,
);


sub _build_logger {
    my ($self, $args) = @_;

    # set up logging
    return xt_logger( $self->log4perl_category );
};

=head1 METHODS

These methods will allow you to log at different levels and also if you have a boolean method 'verbose'
allow the log message to be displayed to STDOUT as well.

=over 4

=item B<log_croak>

Log Croak and print message to screen if script is running in verbose
mode

=back

=cut

sub log_croak {
    my ( $self, $msg )  = @_;
    $self->_log_and_maybe_msg( 'logcroak', $msg );
}

=over 4

=item B<log_error>

Log at error level and print message to screen if script is running in verbose
mode

=back

=cut

sub log_error {
    my ($self, $msg) = @_;
    $self->_log_and_maybe_msg('error', $msg);
}

=over 4

=item B<log_info>

Log at info level and print message to screen if script is running in verbose
mode

=back

=cut

sub log_info {
    my ($self, $msg) = @_;
    $self->_log_and_maybe_msg('info', $msg);
}

=over 4

=item B<log_debug>

Log at debug level and print message to screen if script is running in verbose
mode

=back

=cut

sub log_debug {
    my ($self, $msg) = @_;
    $self->_log_and_maybe_msg('debug', $msg);
}

sub _log_and_maybe_msg {

    my ($self, $log_method, $msg) = @_;

    # Oh dear, we've confused Log4perl
    local $Log::Log4perl::caller_depth += 2;

    my $allowed_methods = { debug => 1,
                            info  => 1,
                            error => 1,
                            logcroak => 1,
                          };

    $log_method = 'info' unless $allowed_methods->{$log_method};

    $msg = "DRY-RUN: ${msg}"        if ( $self->can('dryrun') && $self->dryrun );

    if ( $self->can('verbose') && $self->verbose ) { say $msg }
    $self->logger->$log_method($msg);
}

1;
