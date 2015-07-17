package XT::Order::Role::Parser::PostageData;

use Moose::Role;
use XT::Data::Types;
use DateTime::Format::Strptime;
use Data::Dump qw/pp/;

requires 'is_parsable';
requires 'parse';

sub _set_order_postage {
    my ($self, $node, $data) = @_;
    $data->{postage}{currency}  = $node->{postage}{value}{currency};
    $data->{postage}{amount}    = $node->{postage}{value}{amount};
    $data->{currency}           = $node->{gross_total}{value}{currency};
}

1;
