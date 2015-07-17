
use strict;
use warnings;
package Test::XTracker::Config;

use Path::Class;
use Log::Log4perl ':easy';

sub import {
  my ($class, $root_dir) = @_;

  die '$root_dir undefined in import() - did you forget to source the .env file?'
    unless defined $root_dir;

  $root_dir = dir($root_dir)->absolute->resolve;

# Thinking of backward compatibility
# we're not thinking of running this on a live env, still, it would be nice to be able
# test it as if we were on one

  my $CONFIG_FILE_PATH = '';

  if ( defined $ENV{XTDC_CONFIG_FILE} ) {
      $CONFIG_FILE_PATH ||= $ENV{XTDC_CONFIG_FILE};
  }
  elsif ( -e "/etc/xtdc/xtracker.conf" ) {
      $CONFIG_FILE_PATH = "/etc/xtdc/xtracker.conf";
  }
  else {
      LOGCONFESS "Test::XTracker::Config->import called with invalid root_dir:"
        . " no env-conf found under $root_dir"
        . "Perhaps you forgot to source your xtdc.env file ?";
  }

  my $env_conf = file( $CONFIG_FILE_PATH )->dir;

  $XTracker::Config::Local::APP_ROOT_DIR = $root_dir->stringify . "/";
  $XTracker::Config::Local::CONFIG_FILE_PATH ||= "$env_conf/xtracker.conf";
  $XTracker::Config::Local::MESSAGING_CONFIG_FILE_PATH ||= "$env_conf/xt_dc_messaging.conf";
  $XTracker::Config::Local::PSP_MESSAGING_CONFIG_FILE_PATH ||= "$env_conf/xt_dc_psp_messaging.conf";

  $ENV{XTRACKER_ROOT} = "$root_dir";

    # check to see if XTracker::Config::Local has loaded before us
    # as this causes unexpected side-effects, e.g. test config data "going
    # missing"
    if (
        keys %XTracker::Config::Local::config
            and
        not $XTracker::Config::Local::config{(my $package_name = __PACKAGE__)}
    ) {
        LOGCONFESS
              'XTracker::Config::Local has been loaded somewhere before '
            .  __PACKAGE__
            . ' - this will cause unexpected problems;'
            . ' Load the Test::XTracker::LoadTestConfig module to get around this.'
            . ' Also see http://confluence.net-a-porter.com/display/BAK/ConfigLocalClash'
            . ' for a longer explanation.'
    }


  require XTracker::Config::Local;
  # flag in the config that we've been loaded through Test::XTracker::Config
  # this will help us catch the annoying case where something uses
  # XTracker::Config::Local
  # before Test::XTracker::Config and triggers unexpected problems due to
  # ordering
  $XTracker::Config::Local::config{(my $package_name = __PACKAGE__)}++;

  return 1;
}

sub messaging_config {
    return XTracker::Config::Local::load_arbitrary_config($ENV{XT_DC_MESSAGING_CONFIG}//$XTracker::Config::Local::MESSAGING_CONFIG_FILE_PATH);
}

sub psp_messaging_config {
    return XTracker::Config::Local::load_arbitrary_config($ENV{XT_DC_PSP_MESSAGING_CONFIG}//$XTracker::Config::Local::PSP_MESSAGING_CONFIG_FILE_PATH);
}

1;
