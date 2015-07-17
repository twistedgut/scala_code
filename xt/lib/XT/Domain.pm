package XT::Domain;

use strict;
use warnings;
use Class::Std;
use Cache::Memcached::Managed;

use XTracker::Config::Local qw/config_var/;

use base qw/ Helper::Class::Schema /;

{
    my %memcached_of :ATTR( get => 'memcached', set => 'memcached' );

    sub START {
        my($self) = @_;

        if ($self->_using_memcached) {
            $self->set_memcached( $self->_create_memcached );
        }

    }

    sub _using_memcached {
        my($self) = @_;

        my $memcached_enabled = config_var('Memcached', 'enabled');

        return 1
            if (defined $memcached_enabled and $memcached_enabled =~ /^(yes|y)/i);

        return 0;
    }

    sub _create_memcached {
        my($self) = @_;
        my $servers = config_var('Memcached', 'servers');

        my $cache = Cache::Memcached::Managed->new(
            data    => $servers,
        );

        return $cache;
    }
}
1;
