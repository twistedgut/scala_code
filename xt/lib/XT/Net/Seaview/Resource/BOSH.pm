package XT::Net::Seaview::Resource::BOSH;

use NAP::policy "tt", 'class';
extends 'XT::Net::Seaview::Resource';

use XT::Net::Seaview::Representation::BOSH::Text;

=head1 NAME

XT::Net::Seaview::Resource::BOSH

=head1 DESCRIPTION

The remote Seaview BOSH resource.

=head1 ATTRIBUTES

=head2 read_rep_class

The read representation class.

=cut

has read_rep_class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'XT::Net::Seaview::Representation::BOSH::Text',
);

=head2 write_rep_class

The write representation class.

=cut

has write_rep_class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'XT::Net::Seaview::Representation::BOSH::Text',
);

=head2 schema

XT Schema.

=cut

has schema => (
    is       => 'ro',
    isa      => 'XTracker::Schema|XT::DC::Messaging::Model::Schema',
    required => 1,
);

=head2 collection_key

This is not yet implemented for BOSH.

=cut

has collection_key => (
    is       => 'ro',
    isa      => 'Str',
    default  => 'bosh_collection',
);
