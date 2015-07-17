package XT::DC::Messaging::Spec::Types::preorder_item_status;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
    return 'http://net-a-porter.com/'.(shift->subname);
}

sub subname { return 'preorder_item_status'; }

my %valid_types=(
    completed => 1,           # deprecated
    complete  => 1,
    exported  => 1,
    cancelled => 1,
);

sub assert_valid {
    my ( $self, $value ) = @_;

    return 1 if exists $valid_types{lc $value};

    $self->fail({
        error   => [ $self->subname ],
        message => 'invalid pre-order item status',
        value   => $value,
    });
}

1;
