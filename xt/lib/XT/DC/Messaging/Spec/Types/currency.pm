package XT::DC::Messaging::Spec::Types::currency;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'currency' };

# we should get these from, say, a database at some point
#
# at present, this list matches the names in the currency table, other
# than 'unk'

my %valid_types=(
    'gbp' => 1,
    'eur' => 1,
    'usd' => 1,
    'aud' => 1,
    'yen' => 1,
    'hkd' => 1,
);

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if exists $valid_types{lc $value};
    $self->fail({
        error   => [$self->subname],
        message => 'invalid currency',
        value   => $value,
    });
}

1;
