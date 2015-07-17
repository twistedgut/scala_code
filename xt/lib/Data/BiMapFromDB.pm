package Data::BiMapFromDB;
use NAP::policy "tt", 'class';

has ['_from_id','_from_name'] => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { { } },
);

has _inited => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

sub load {
    my ($self,$schema,$class,$id_col,$name_col) = @_;

    return if $self->_inited;

    my $rs = $schema->resultset($class)->search();
    while (my $row=$rs->next) {
        $self->_from_id->{$row->$id_col} = $row->$name_col;
        $self->_from_name->{$row->$name_col} = $row->$id_col;
    }

    $self->_inited(1);

    return;
}

sub clear {
    my ($self) = @_;

    $self->_inited(0);

    return;
}

sub name_for {
    my ($self,$id) = @_;

    return $self->_from_id->{$id};
}

sub id_for {
    my ($self,$name) = @_;

    return $self->_from_name->{$name};
}
