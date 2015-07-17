package XTracker::Error;
# vim: ts=8 sts=4 et sw=4 sr sta
use NAP::policy "tt", 'exporter';
use Log::Log4perl ':easy';
# use Carp;
use Perl6::Export::Attrs;
use Readonly;
use Data::Dump 'pp';

Readonly my @ERROR_LEVELS => qw( warning fatal info );

=head1 NAME

XTracker::Error

=cut

# TODO: Rename this to XTracker::Feedback

# make this an inside out class
{
    sub xt_warn :Export(:DEFAULT) {
        my $error_message = shift;

        # make sure that error message is a string
        $error_message = "$error_message";

        INFO $error_message;
        xt_feedback('WARN', $error_message);
    }

    sub xt_die :Export(:DEFAULT) {
        my $error_message = shift;

        # make sure that error message is a string
        $error_message = "$error_message";

        FATAL $error_message;
        xt_feedback('FATAL', $error_message);
    }

    sub xt_info :Export(:DEFAULT) {
        my $error_message = shift;

        # make sure that error message is a string
        $error_message = "$error_message";

        INFO $error_message;
        xt_feedback('INFO', $error_message);
    }

    sub xt_success :Export(:DEFAULT) {
        my $error_message = shift;

        # make sure that error message is a string
        $error_message = "$error_message";

        INFO $error_message;
        xt_feedback('SUCCESS', $error_message);
    }

    sub xt_error :Export(:DEFAULT) {
        my $error_message = shift;
        ERROR $error_message;
        xt_feedback('ERROR', $error_message);
    }

    sub xt_debug :Export(:DEFAULT) {
        my $error_message = shift;
        $error_message = pp($error_message) if ref($error_message);
        DEBUG $error_message;
        xt_feedback('DEBUGMSG', $error_message);
    }

    sub xt_feedback :Export(:DEFAULT) {
        my ($error_type, $error_message) = @_;
        my $session;

        # make sure that error message is a string
        $error_message = "$error_message";

        try {
            require XTracker::Session;
            $session = XTracker::Session->session;

            if (not defined $session) {
                carp "[session undefined] ($error_type) $error_message";
                return; # returns from the try
            }

            $error_message=_smart_cleanup($error_message);

            # Append new message if one already exists
            # TODO: Rename xt_error to xt_feedback
            if (
                exists($session->{xt_error})
                && exists($session->{xt_error}{message})
                && exists($session->{xt_error}{message}{$error_type})
            ) {
                $error_message = $session->{xt_error}{message}{$error_type} . "<br />$error_message";
            }

            # set the appropriate section of the session
            $session->{xt_error}{message}{$error_type} = $error_message;
        }
        catch {
            WARN "[Can't get a session] ($error_type) $error_message";
        };

        return;
    }

    sub xt_has_errors :Export(:DEFAULT) {
        return xt_has_feedback("ERROR");
    }

    sub xt_has_warnings :Export(:DEFAULT) {
        return xt_has_feedback("WARN");
    }

    sub xt_has_feedback :Export(:DEFAULT) {
        my ($message_type) = @_;
        my $session = XTracker::Session->session();

        defined $session->{xt_error}                             or return;
        defined $session->{xt_error}->{message}                  or return;
        defined $session->{xt_error}->{message}->{$message_type} or return;

        return 1; # errors have been set
    }

    sub _smart_cleanup {
        my ($s)=@_;

        # we sometimes put <br> or <br /> or </?a> in our messages; we want to
        # keep those, but escape everything else and yes, escaping '<' is
        # enough
        $s =~ s{ < (?! (?:/? a \b .*? >| br \s*/? >) ) }{&lt;}smxgi;
        return $s;

    }
}

=pod

=head1 NAME

XTracker::Error - add generic application error message handling and generation

=head1 SYNOPSIS

  package XTracker::Some::Handler;
  use XTracker::Error;

  sub some_method {
    my ($self) = @_;

    # ...

    # test for something that shouldn't happen
    if ($something_a_bit_bad) {
      xt_warn( q{Something a bit bad happened} );
    }

    # ...

    # test for something that's really not good at all!
    if ($something_REALLY_bad) {
      xt_warn( q{Something terrible happened!} );
    }
  }

=head1 METHODS

=over 4

=item xt_warn($message)

This method causes the session data to be populated with a non-fatal error
message. This results in a block of text near the top of the screen AND still
shows the rest of the expected screen.

  # tell someone they aren't allowed to view somewhere
  xt_warn( q{You don't have permission to access SomeSection.} );

=item xt_die($message)

This method causes the session data to be populated with a fatal error
message. This results in a block of text near the top of the screen AND nothing else.

  # something went really wrong with the database, it's safer to barf
  xt_die( q{An unrecoverable error has occurred.} );

=item xt_has_errors

Use this function to determine if any errors have been raised for the current
request.

  if (xt_has_errors()) {
    # show a different template
  }

=back

=head1 SEE ALSO

L<XTracker::XTemplate>

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>

=cut

1;
