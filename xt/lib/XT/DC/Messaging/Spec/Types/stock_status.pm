package XT::DC::Messaging::Spec::Types::stock_status;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'stock_status' };

my %valid_types=(
    'main' => 1,
    'sample' => 1,
    'faulty' => 1,
    'rtv' => 1,
    'dead' => 1,
);

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if exists $valid_types{lc $value};
    $self->fail({
        error   => [$self->subname],
        message => 'invalid stock status',
        value   => $value,
    });
}

1;
