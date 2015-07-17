package XT::Rules::Hash;

use strict;
use warnings;
use parent 'Tie::Hash';

use Carp qw/croak/;
use Storable qw/dclone/;

# A special kind of read-only hash for situations and configs
# Constraints

sub TIEHASH {
    my ( $class, $hashref ) = @_;

    # We want our own copy!
    $hashref = dclone( $hashref );

    # Here is where we check we haven't been passed in any blessed values
    # TODO

    return bless $hashref, $class;
}

sub FETCH {
    my ( $self, $key ) = @_;
    croak "Key [$key] does not exist" unless exists $self->{$key};
    return $self->{$key};
}

sub STORE  { croak "XT::Rules::Hash hashes are read-only" }
sub DELETE { croak "XT::Rules::Hash hashes are read-only" }
sub CLEAR  { croak "XT::Rules::Hash hashes are read-only" }

1;
