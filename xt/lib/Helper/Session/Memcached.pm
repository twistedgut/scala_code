package Helper::Session::Memcached;

use strict;
use warnings;
use Cache::Memcached::Managed;
use Data::Dumper;


use base qw/ Helper::Class /;

use Class::Std;

{
    my %cache_of  :ATTR( get => 'cache', set => 'cache' );
    my %server_of :ATTR( get => 'server', );

    sub START {
        my($self) = @_;

        return;
    }

    sub set_server {
        my($self, $val) = @_;

        return if (not defined $val);

        if (ref($val) ne 'ARRAY') {
            $val = [ $val ];
        }

        $server_of{ident $self} = $val;

        $self->initiate_cache;

        return;
    }

    sub add_server {
        my($self, $val) = @_;

        return if (not defined $val);

        push @{$self->get_cache}, $val;

        $self->initiate_cache;

        return;
    }

    sub initiate_cache {
        my($self) = @_;

        $self->set_cache(
            Cache::Memcached::Managed->new( data => $self->get_server )
        );

        return;
    }

    sub freeze {
        my($self, $key, $fudge, $value) = @_;
        my $cache = $self->get_cache;

        print STDERR "===> $key,". Dumper($value) ."\n";

# Taken from Catalyst::Plugin::Session::Store::Memcached
# catalyst
#    $c->_session_memcached_storage->set(
#        @{ $c->_session_memcached_arg_fudge },
#        (
#            $key =~ /^(?:expires|session|flash)/
#              ? ( expiration => $c->session_expires )
#              : ()
#        ),
#        id    => $key,
#        value => $data,
#      )

        return $cache->set(
            value   => $value,
            key     => $key,
        );
    }

    sub thaw {
        my($self,$key, $fudge) = @_;
        my $cache = $self->get_cache;

# Taken from Catalyst::Plugin::Session::Store::Memcached
# catalyst
# $c->_session_memcached_storage->get( @{ $c->_session_memcached_arg_fudge },
#    id => $key, );

        #return $cache->get( @{ $fudge }, key => $key );
        return $cache->get( @{ $fudge }, id => $key );
    }

}

1;

__END__

=pod

=head1 NAME

Helper::Session::Memcached - wrapper class for Cache::Memcached::Managed

=head1 SYNOPSIS

use Help::Session::Memcached;

my $cache = Helper::Session::Memcached->new();

$cache->set_server( );

$cache->freeze( $key, $fudge, $value );

$cache->thaw( $key, $fudge );

=head1 SEE ALSO

XTracker::Session - example of usage

=head1 AUTHOR

Jason Tang C<< <jason.tang@net-a-porter.com> >>

=cut

