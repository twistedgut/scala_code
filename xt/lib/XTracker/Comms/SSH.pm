package XTracker::Comms::SSH;

use strict;
use warnings;

use Perl6::Export::Attrs;
use Net::SSH::Perl;

use XTracker::Config::Local qw( ssh_known_hosts_file
                staging_ssh_host
                staging_ssh_user
                staging_ssh_port
                staging_ssh_identity_file
                staging_ssh_protocol
                staging_ssh_cipher
                config_section_exists
                config_var );


### Subroutine : get_ssh_handle                 ###
# usage        : $ssh = get_ssh_handle($server)   #
# description  : Return Net::SSH::Perl object for #
#              : connection to a given server. The#
#              : $serv param corresponds to a     #
#              : section in the config file       #
#              : server.                          #
# parameters   : $serv                            #
# returns      : Net::SSH::Perl                   #

sub get_ssh_handle :Export(:DEFAULT) {
    my ($serv) = @_;

    my $section    = "${serv}_SSH";

    if (!config_section_exists($section)) {
    die("get_ssh_handle: Unable to determine SSH connection parameters for $serv: No [$section] entry in config file.");
    }

    my $host       = config_var($section, 'host');
    my $port       = config_var($section, 'port');
    my $user       = config_var($section, 'user');
    my $id_files   = config_var($section, 'identity_file');
    my $protocol   = config_var($section, 'protocol');
    my $cipher     = config_var($section, 'cipher');

    my $known_hosts_file = config_var('SSH', 'known_hosts_file');

    if (! ($user && $host && $known_hosts_file)) {
    die("get_ssh_handle: Unable to determine SSH connection parameters for $serv");
    }


    if (ref($id_files) ne 'ARRAY') {
    $id_files = [$id_files];
    }

    my $ssh = Net::SSH::Perl->new($host, (port           => $port,
                      protocol       => $protocol,
                      cipher         => $cipher,
                      identity_files => $id_files,
                      interactive    => 0,
                      options        => ['UserKnownHostsFile '. $known_hosts_file]
                      )
                  );

    $ssh->login($user);

    return $ssh;
}

sub get_staging_ssh_handle :Export(:DEFAULT) {
    return get_ssh_handle('StagingFCP');
}

1;
