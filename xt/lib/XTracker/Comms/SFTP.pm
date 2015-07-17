package XTracker::Comms::SFTP;

use strict;
use warnings;

use Perl6::Export::Attrs;
use Net::SFTP;

use XTracker::Config::Local qw( ssh_known_hosts_file
                staging_ssh_host
                staging_ssh_user
                staging_ssh_port
                staging_ssh_identity_file
                staging_ssh_protocol
                staging_ssh_cipher
                config_section_exists
                config_var );

### Subroutine : sftp_ls                        ###
# usage        : @files = sftp_ls($sftp, $path)   #
# description  : Returns a list of file names for #
#              : a given path using an open SFTP  #
#              : connection.                      #
# parameters   : $sftp : Net::SFTP object         #
#              : $path : full filesystem path     #
# returns      : list                             #

sub sftp_ls :Export(:DEFAULT) {
    my ($sftp_handle,$path) = @_;

    my @files       = $sftp_handle->ls($path);
    my @file_names  = ();

    foreach my $file (@files) {
    push(@file_names, $file->{filename});
    }
    return @file_names;
}

### Subroutine : sftp_delete                    ###
# usage        : sftp_delete($sftp, $path)        #
# description  : Deletes a remote file using an   #
#              : open SFTP connection.            #
# parameters   : $sftp : Net::SFTP object         #
#              : $path : full filesystem path     #
# returns      : N/A                              #

sub sftp_delete :Export(:DEFAULT) {
    my ($sftp_handle,$path) = @_;

    $sftp_handle->do_remove($path);
}

### Subroutine : get_staging_sftp_handle        ###
# usage        : $sftp = get_staging_sftp_handle()#
# description  : Return Net::SFTP object for a    #
#              : connection to the FCP staging    #
#              : server.                          #
# parameters   : N/A                              #
# returns      : Net::SFTP                        #

sub get_staging_sftp_handle :Export(:DEFAULT) {
    return get_sftp_handle('StagingFCP');
}

### Subroutine : get_sftp_handle                ###
# usage        : $sftp = get_sftp_handle($server) #
# description  : Return Net::SFTP object for a    #
#              : connection to a given server. The#
#              : $serv param corresponds to a     #
#              : section in the config file       #
#              : server.                          #
# parameters   : $serv                            #
# returns      : Net::SFTP                        #

sub get_sftp_handle :Export(:DEFAULT) {
    my ($serv) = @_;

    my $section    = "${serv}_SSH";

    if (!config_section_exists($section)) {
    die("get_sftp_handle: Unable to determine SSH connection parameters for $serv: No [$section] entry in config file.");
    }

    my $host       = config_var($section, 'host');
    my $port       = config_var($section, 'port');
    my $user       = config_var($section, 'user');
    my $id_files   = config_var($section, 'identity_file');
    my $cipher     = config_var($section, 'cipher');

    my $known_hosts_file = config_var('SSH', 'known_hosts_file');

    if (! ($user && $host && $known_hosts_file)) {
    die("get_sftp_handle: Unable to determine SSH connection parameters for $serv in get_sftp_handle");
    }


    if (ref($id_files) ne 'ARRAY') {
    $id_files = [$id_files];
    }


    my $sftp = Net::SFTP->new(
                  $host,
                  user     => $user,
                  debug    => 0,
                  ssh_args => {
                  port           => $port,
                  identity_files => $id_files,
                  protocol       => 2, # Net::SFTP requires Net::SSH::Perl::SSH2
                  cipher         => $cipher,
                  options        => ['UserKnownHostsFile '. $known_hosts_file]
                  }
                 );
    return $sftp;
}

1;
