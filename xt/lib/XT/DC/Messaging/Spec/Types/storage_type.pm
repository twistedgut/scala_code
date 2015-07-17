package XT::DC::Messaging::Spec::Types::storage_type;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'storage_type' };

my %valid_types=(
    'flat' => 1,
    'hanging' => 1,
    'oversize' => 1,
    'awkward' => 1,
    'cage' => 1,
    # 'Dematic_Flat' is intended to be a temporary measure, while stock is transferred
    # from the Full warehouse PRL to Dematic.
    # After all Flat stock is in Dematic, we plan to change the storage type
    # of all 'Dematic_Flat' stock to just 'Flat'.
    'dematic_flat' => 1,
);

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if exists $valid_types{lc $value};
    $self->fail({
        error   => [$self->subname],
        message => 'invalid storage type',
        value   => $value,
    });
}

1;
