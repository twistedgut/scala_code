package XT::DC::Messaging::Spec::Types::place;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'place' };

my %valid_names=(
    'main' => 1,
    'sample' => 1,
    'faulty' => 1,
    'packing exception' => 1,
    'commissioner' => 1,
    'lost' => 1,
);

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if exists $valid_names{lc $value};
    $self->fail({
        error   => [$self->subname],
        message => 'invalid place name',
        value   => $value,
    });
}

1;
