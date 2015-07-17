package XTracker::Session;
use NAP::policy "tt";

use Plack::App::FakeApache1::Constants qw(:common);

use Readonly;

#use XTracker::Database qw(:common);
use XTracker::Logfile qw( xt_logger );
use XTracker::Config::Local qw( config_var );
use XTracker::Version;

our $SESSION;

sub session {
    return $SESSION;
}

sub handler {
    my $r       = shift;

    given ($r) {
        when ($_->isa('Plack::App::FakeModPerl1')) {
            _handler_plack($r);
        }

        when ($_->isa('Catalyst::Component')) {
            _handler_catalyst($r);
        }

        default {
            die sprintf('%s - unsupported handler type', ref($r));
        }
    }

    return OK;
}

sub _handler_plack {
    my $r = shift;
    # we use Plack::Middleware::Session to save us all the pain we used to
    # have to go through with mod_perl sessions

    # we want to NOT break the sessions we already have, so we:
    #  - create a Plack::Session
    #  - add the session id to the session data
    #  - return the session data hash and NOT the Plack::Session object
    #
    # mostly useful for thing's like DblSubmit:
    #   $session_id = $session->{_session_id};
    require Plack::Session;
    my $session = Plack::Session->new($r->{env});
    $session->set('_session_id', $session->id);
    $SESSION = $session->session;
    _set_common_data();
    return;
}

sub _handler_catalyst {
    my $c = shift;
    # _session_id should already be set
    $SESSION = $c->session;
    _set_common_data();
    return;
}


sub _set_common_data {
    my $session = session();
    return
        unless $session;

    # store the application version
    $session->{application}{version}{string} = $XTracker::Version::VERSION;

    # store the current IWS rollout phase
    $session->{application}{iws_rollout_phase} = config_var('IWS', 'rollout_phase') || 0;

    # and the current PRL rollout phase
    $session->{application}{prl_rollout_phase} = config_var('PRL', 'rollout_phase') || 0;

    # and the EditPO rollout phase
    $session->{application}{editpo_rollout_phase}
        = config_var('Features', 'edit_purchase_order_rollout_phase') || 0;

    # store distribution channel
    $session->{application}{distribution_channel} = config_var('DistributionCentre', 'name');

    return;
}

sub prepare_xt_error_for_view {
    my $session = shift;
    my $xt_error;

    # automatically push an error information out to TT
    if (defined $session->{xt_error}) {
        if (ref $session->{xt_error}) {
            $xt_error = delete($session->{xt_error});
        }
        else {
            $xt_error->{message} = delete($session->{xt_error});
        }
        $xt_error->{level} ||= 'warning';

        # Preformat output if it looks like t3h PeRL
        my $error_output = eval {
            join '', values %{ $xt_error->{message} }
        };
        $xt_error->{preformatted} = ($error_output =~ m/::/) ? 1 : 0;
    }

    return $xt_error;
}

1;
__END__
