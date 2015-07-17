package XT::Data::Printer;

use NAP::policy 'class';
extends 'XT::Data';

use Const::Fast;
use Moose::Util::TypeConstraints;

=head1 NAME

XT::Data::Printer - A class for preliminary printer config validation

=head1 ATTRIBUTES

=head2 location

=head2 lp_name

=cut

has [qw/location lp_name/] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 type

=cut

const our %type_name => (
    carrier_label => 'Carrier Label',
    document      => 'Document',
    large_label   => 'Large Label',
    mrp_card      => 'MRP Card',
    nap_card      => 'NAP Card',
    small_label   => 'Small Label',
    sticker       => 'Sticker', # i.e. Mr P sticker
    ups_label     => 'UPS Label',
);
has type => (
    is => 'ro',
    isa => enum([keys %type_name]),
);

=head2 section

=cut

const our $sections => [qw{
    airwaybill
    goods_in_qc
    item_count
    packing
    personalised_sticker
    premier_shipping
    recode
    returns_in
    returns_qc
    rtv_workstation
    stock_in
    surplus
}];
has section => (
    is => 'ro',
    isa => enum($sections),
    required => 1,
);
