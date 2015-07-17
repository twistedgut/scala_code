package CSV::Plugin::ShippingMethod;
# vim: ts=8 sts=4 et sw=4 sr sta
use Moose;


with 'CSV::Base';

sub parse_line {
    my($self,$arr) = @_;
    my $result = $self->result;

    $result->{ $arr->[1] } = {
        id => $arr->[0],
        sku => $arr->[1],
        type => $arr->[2],
        is_additive => $arr->[3],
        is_for_preorder => $arr->[4],
        region => $arr->[5],
        country => $arr->[6],
        state => $arr->[7],
        post_code_zone_id => $arr->[8],
        sort_order => $arr->[9],
        exclude => $arr->[10],
    };

    if (!defined $self->result) {
        $self->result($result);
    }
}

1;
