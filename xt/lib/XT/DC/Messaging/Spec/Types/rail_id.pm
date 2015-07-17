package XT::DC::Messaging::Spec::Types::rail_id;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';
use Try::Tiny;
use NAP::DC::Barcode::Container::Rail;

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'rail_id' };

sub assert_valid {
    my ( $self, $value ) = @_;

    return try {
        NAP::DC::Barcode::Container::Rail->new_from_id($value);
        return 1;
    } catch {
        return $self->fail({
            error   => [$self->subname],
            message => 'invalid rail id',
            value   => $value,
        });
    };
}

1;
