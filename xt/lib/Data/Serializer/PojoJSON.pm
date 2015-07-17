package Data::Serializer::PojoJSON;
use Moose;

extends 'Data::Serializer::JSON';

around deserialize => sub {
    my ($orig, $self, $data) = @_;

    my $dict = $self->$orig($data);

    my ($type, @overflow) = keys %$dict;

    die "expected just a single key at top level: $type,@overflow"
        if @overflow || !$type;

    $dict = $dict->{$type};
    $type =~ s/^com\.netaporter\.//;
    $dict->{__method} ||= $type;

    return $dict;
};

1;
