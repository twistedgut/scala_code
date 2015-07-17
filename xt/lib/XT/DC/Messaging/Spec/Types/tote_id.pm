package XT::DC::Messaging::Spec::Types::tote_id;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

use Try::Tiny;
use NAP::DC::Barcode::Container::Tote;

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'tote_id' };

sub assert_valid {
    my ( $self, $value ) = @_;

    return try {
        NAP::DC::Barcode::Container::Tote->new_from_id($value);

        # passed value is valid "Tote" ID!
        return 1;
    } catch {
        # provided value is not correct
        return $self->fail({
            error   => [$self->subname],
            message => 'invalid tote id',
            value   => $value,
        });
    };
}

1;
