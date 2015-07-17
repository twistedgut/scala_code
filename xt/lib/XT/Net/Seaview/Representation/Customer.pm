package XT::Net::Seaview::Representation::Customer;

use NAP::policy "tt", 'class';
extends 'XT::Net::Seaview::Representation';

=head1 NAME

XT::Net::Seaview::Representation::Customer

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 data_obj_class

The XT::Data:: class

=cut

has data_obj_class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'XT::Data::Customer',
);
