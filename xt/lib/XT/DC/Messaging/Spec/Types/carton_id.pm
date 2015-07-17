package XT::DC::Messaging::Spec::Types::carton_id;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'carton_id' };

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if $value =~ m{^c?\d+(-\d+)?$}i;
    $self->fail({
        error   => [$self->subname],
        message => 'invalid carton id',
        value   => $value,
    });
}

1;
