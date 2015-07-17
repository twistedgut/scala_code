package XTracker::Role::AccessConfig;
use NAP::policy qw/role/;

use XTracker::Config::Local qw/config_var/;

sub get_config_var {
    my $self = shift;
    return config_var(@_);
}
