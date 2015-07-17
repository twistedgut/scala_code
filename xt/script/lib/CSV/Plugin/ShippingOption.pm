package CSV::Plugin::ShippingOption;
# vim: ts=8 sts=4 et sw=4 sr sta
use Moose;


with 'CSV::Base';

sub parse_line {
    my($self,$arr) = @_;
    my $result = $self->result;

    $result->{ $arr->[0] } = {
        id => $arr->[0],
        name => $arr->[1],
    };

    if (!defined $self->result) {
        $self->result($result);
    }

}

1;
