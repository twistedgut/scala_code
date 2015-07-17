package XT::DC::Messaging::Spec::Types::pigeonhole_id;
use strict;
use warnings;

use parent 'Data::Rx::CommonType::EasyNew';

use Try::Tiny;
use Smart::Match instance_of => { -as => 'match_instance_of' };
use NAP::DC::Barcode::Container;
use NAP::DC::Exception::Barcode;

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'pigeonhole_id' };

sub assert_valid {
    my ( $self, $value ) = @_;

    return try {

        # make sure passed value is "pigeon hole" barcode: first check if
        # it is container's barcode and if so - if it is "pigeon hole"
        $value = NAP::DC::Barcode::Container->new_from_id($value);

        NAP::DC::Exception::Barcode->throw({
            error => 'Scanned barcode is ' . $value->name
        }) unless $value->is_type('pigeon_hole');

        return 1;
    } catch {
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('NAP::DC::Exception::Barcode')) {
            return $self->fail({
                error   => [$self->subname],
                message => 'invalid pigeonhole id, reason: ' . $_,
                value   => $value,
            });
        }
        # propagate any unknown error further
        else {
            die $_;
        };
    };
}

1;
