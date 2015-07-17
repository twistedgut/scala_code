package Plack::Middleware::Debug::NAPEnv;
use strict;
use warnings;

use parent qw(Plack::Middleware::Debug::Base);

sub run {
    my ($self, $env, $panel) = @_;

    my $panel_data = {};
    $self->_prepare_panel_data($env, $panel_data);

    $panel->content(
        sub { $self->render_hash($panel_data) }
    );
    return;
}

sub _prepare_panel_data {
    my ($self, $env, $panel_data) = @_;

    # add RPM information
    foreach my $rpm (qw/
        perl-nap
        xt
        fulcrum
        apache-nap
        apache-config-nap
    /) {
        $panel_data->{"package: $rpm"} = rpm_info($rpm);
    }

    # a couple of ENV variables we might care about
    foreach my $env (qw/
        PLDEBUG
        QUICKDEV
        RUNAS
        XTDC_BASE_DIR
        XTDC_CONF_DIR
        XTDC_CONFIG_FILE
        XTDC_ENV_DEFINED
    /) {
        if (defined $ENV{$env}) {
            $panel_data->{$env} = $ENV{$env};
        }
        else {
            $panel_data->{$env} = '(unset)';
        }
    }

    return;
}

# this should reflect the versions of the RPMs when we're running, so we
# should cache it on the first hit and just return the cached value for later
# requests
my $rpm_info;

sub rpm_info {
    my $rpm = shift;

    return $rpm_info->{$rpm}
        if exists $rpm_info->{$rpm};

    ## no critic(ProhibitBacktickOperators)
    my $rpm_data =
        `yum info --disablerepo=\* -q $rpm 2>/dev/null`;

    if (not $rpm_data) {
        $rpm_info->{$rpm} = '(not installed)';
    }
    else {
        my ($version) =
            $rpm_data =~ m{Version\s+:\s+(.+?)$}xms;
        my ($release) =
            $rpm_data =~ m{Release\s+:\s+(.+?)$}xms;

        $rpm_info->{$rpm} = sprintf('%s-%s', $version, $release);
    }
    return $rpm_info->{$rpm};
}

1;
