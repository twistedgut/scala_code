package XT::DC::Messaging::Spec::Types::shipment_type;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'shipment_type' };

my %valid_types=(
    'customer' => 1,
    'sample' => 1,
    'rtv' => 1,
);

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if exists $valid_types{lc $value};
    $self->fail({
        error   => [$self->subname],
        message => 'invalid shipment type',
        value   => $value,
    });
}

1;
