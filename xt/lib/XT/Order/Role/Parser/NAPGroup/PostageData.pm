package XT::Order::Role::Parser::NAPGroup::PostageData;

use Moose::Role;
use XT::Data::Types;
use DateTime::Format::Strptime;
use Data::Dump qw/pp/;

requires 'is_parsable';
requires 'parse';

sub _set_order_postage {
    my ($self, $node, $data) = @_;
    $data->{postage}{currency}  = $node->{postage}{currency};
    $data->{postage}{amount}    = $node->{postage}{amount};
    $data->{currency}           = $node->{gross_total}{currency};
}

1;
