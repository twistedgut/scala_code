package XT::DC::Messaging::Spec::Types::dc_name;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'dc_name' };

sub assert_valid {
    my ( $self, $value ) = @_;

    return 1    if ( $value && $value =~ m/^DC\d+$/ );

    $self->fail({
        error   => [$self->subname],
        message => 'invalid DC name',
        value   => $value,
    });

    return 0;
}

1;
