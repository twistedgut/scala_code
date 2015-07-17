package XT::Net::Seaview::Representation::Address;

use NAP::policy "tt", 'class';
extends 'XT::Net::Seaview::Representation';

=head1 NAME

XT::Net::Seaview::Representation::Address

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head2 data_obj_class

The XT::Data:: class

=cut

has data_obj_class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'XT::Data::Address',
);

=head2 data_obj_xtra_params

If the XT::Data object needs something extra (like a schema for instance) it
can be placed in this attribute and this will be folded into the construction

=cut

has data_obj_xtra_params => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { { schema => $_[0]->schema } },
);

=head2 schema

XT Schema

=cut

has schema => (
    is       => 'ro',
    isa         => 'DBIx::Class::Schema|XTracker::Schema|XT::DC::Messaging::Model::Schema',
    required => 1,
);
