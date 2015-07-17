package XT::DC::Messaging::Spec::Types::client;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';
use NAP::DC::PRL::Tokens;

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'client' };

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if grep { $_ eq $value } (values %{$NAP::DC::PRL::Tokens::dictionary{CLIENT}});
    $self->fail({
        error   => [$self->subname],
        message => 'invalid client',
        value   => $value,
    });
}

1;
