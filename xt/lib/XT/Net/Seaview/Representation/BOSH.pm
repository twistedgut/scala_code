package XT::Net::Seaview::Representation::BOSH;

use NAP::policy "tt", 'class';
extends 'XT::Net::Seaview::Representation';

=head1 NAME

XT::Net::Seaview::Representation::BOSH

=head1 DESCRIPTION

A BOSH representation for Seaview.

=head1 ATTRIBUTES

=head2 data_obj_class

The XT::Data:: class

=cut

has data_obj_class => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);
