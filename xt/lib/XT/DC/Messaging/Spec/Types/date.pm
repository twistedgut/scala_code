package XT::DC::Messaging::Spec::Types::date;
use NAP::policy "tt", 'class';
use parent 'Data::Rx::CommonType::EasyNew';

sub type_uri {
    sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'date' };

sub assert_valid {
    my ($self, $value) = @_;

    # Naive validation, extend to proper parsing if you need it to be
    # solid
    return 1 if $value =~ /^\d{4}-\d{2}-\d{2}$/;

    $self->fail({
        error   => [ $self->subname ],
        message => 'invalid Date',
        value   => $value,
    });
}

1;
