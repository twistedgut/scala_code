package XT::DC::Messaging::Spec::Types::procid;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'procid' };

sub assert_valid {
    my ( $self, $value ) = @_;
    # I'm not using \w \d because these are character strings (see perlunicode)
    return 1 if $value =~ m{^[a-z_]+-[0-9]+$}i;
    $self->fail({
        error   => [$self->subname],
        message => 'invalid process id',
        value   => $value,
    });
}

1;
