package Test::XT::Rules::Hash;

use strict;
use warnings;

require Tie::Hash;
our @ISA = qw(Tie::StdHash); ## no critic(ProhibitExplicitISA)

use Carp qw/croak/;
use Storable qw/dclone/;

# A special kind of read-only hash for situations and configs
# Constraints

sub TIEHASH {
    my ( $class, $hashref ) = @_;

    # We want our own copy!

    # FIXME: Commenting this out for now, as it destroys the reference to a Schema
    # when using DBIx::Class objects, resulting in the following error:
    #
    # Unable to perform storage-dependent operations with a detached result source
    # (source 'xxx' is not associated with a schema). You need to use $schema->thaw()
    # or manually set $DBIx::Class::ResultSourceHandle::thaw_schema while thawing.
    #
    #$hashref = dclone( $hashref );

    # Here is where we check we haven't been passed in any blessed values
    # TODO

    return bless $hashref, $class;
}

sub FETCH {
    my ( $self, $key ) = @_;
    croak "Key [$key] does not exist" unless exists $self->{$key};
    return $self->{$key};
}

sub STORE  { croak "Test::XT::Rules::Hash hashes are read-only" }
sub DELETE { croak "Test::XT::Rules::Hash hashes are read-only" }
sub CLEAR  { croak "Test::XT::Rules::Hash hashes are read-only" }

1;
