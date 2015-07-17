package XTracker::Role::WithXTLogger;
use NAP::policy "tt", 'role';

=head1 XTracker::Role::WithXTLogger

A role for returning a 'Log::Log4perl' Logger.

=cut

use XTracker::Logfile       qw( xt_logger );


=head1 METHODS

=head2 xtlogger

    $log4perl_obj   = $self->xtlogger( $optional_log_category );

Returns a 'Log::Log4perl' object.

=cut

my $_role_xtlogger_obj;

sub xtlogger {
    my ( $self, $category ) = @_;

    if ( $category || !$_role_xtlogger_obj ) {
        $_role_xtlogger_obj = xt_logger( $category );
    }

    return $_role_xtlogger_obj;
}

=head2 set_xtlogger

    $logger_obj = $self->set_xtlogger( $logger_obj );

Will set a Logger that will be returned by calling '$self->xtlogger'. If you
pass 'undef' or no '$logger_obj' this will cause you to default the Logger
to whatever 'XTracker::Logfile' defaults it to, most probably the 'XTracker'
log category.

=cut

sub set_xtlogger {
    my ( $self, $logger )   = @_;

    $_role_xtlogger_obj = $logger;

    return $self->xtlogger;
}


1;
