#!/opt/xt/xt-perl/bin/perl
use NAP::policy;
use Daemon::Control;
use NAP::Messaging::MultiRunner;
use FindBin::libs 'base=lib_dynamic';

exit Daemon::Control->new({
    name         => 'XT AMQ consumer application',
    user         => 'xt-amq',
    group        => 'xt',

    kill_timeout => 5,
    fork         => 2,
    directory    => '/',
    umask        => oct('002'),

    lsb_start    => '$local_fs $remote_fs $network $named',
    lsb_stop     => '$local_fs $remote_fs $network',
    lsb_sdesc    => 'start and stop XT AMQ consumer',
    lsb_desc     => 'XT AMQ consumer application',

    pid_file     => '/var/run/xt_activemq_dc_server.pid',
    stderr_file  => '/var/log/nap/xt/amq_consumer_stderr.log',
    stdout_file  => '/var/log/nap/xt/amq_consumer_stdout.log',

    path         => '/opt/xt/deploy/xtracker/script/xt_activemq_dc_server.pl',
    program      => sub {
        # turn off default xtracker logging, so that the logging is initialised from
        # NAP::Messaging::Catalyst and picks up config from xt_dc_messaging.conf
        $ENV{NO_XT_LOGGER}           = 1;
        $ENV{XT_DC_MESSAGING_CONFIG} = '/etc/xtdc/xt_dc_messaging.conf';
        NAP::Messaging::MultiRunner->new('XT::DC::Messaging')->run_multiple;
    },
})->run;
