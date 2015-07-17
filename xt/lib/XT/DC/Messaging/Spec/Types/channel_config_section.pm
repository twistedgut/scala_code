package XT::DC::Messaging::Spec::Types::channel_config_section;
use strict;
use warnings;
use Carp;
use parent 'Data::Rx::CommonType::EasyNew';

# this is for the internal channel config section
# found on the 'buisness' table

sub type_uri {
    sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'channel_config_section' };

my %valid_names = (
    NAP     => 1,
    OUTNET  => 1,
    MRP     => 1,
    JC      => 1,
);

sub assert_valid {
    my ( $self, $value ) = @_;
    return 1 if exists $valid_names{$value};
    $self->fail({
        error   => [$self->subname],
        message => 'invalid channel config section',
        value   => $value,
    });
}

1;
