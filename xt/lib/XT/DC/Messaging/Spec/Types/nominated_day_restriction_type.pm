package XT::DC::Messaging::Spec::Types::nominated_day_restriction_type;
use NAP::policy "tt", 'class';
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
    sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'nominated_day_restriction_type' };

my %valid_types=(
    'delivery' => 1,
    'transit'  => 1,
    'dispatch' => 1,
);

sub assert_valid {
    my ($self, $value) = @_;

    return 1 if $valid_types{ $value };

    $self->fail({
        error   => [ $self->subname ],
        message => 'invalid Rescriction Type',
        value   => $value,
    });
}

1;
