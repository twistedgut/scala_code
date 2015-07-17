package XT::Net::Seaview::Resource::Address;

use NAP::policy "tt", 'class';
extends 'XT::Net::Seaview::Resource';

use XT::Net::Seaview::Representation::Address::JSONLD;
use XT::Net::Seaview::Representation::Address::JSON;

=head1 NAME

XT::Net::Seaview::Resource::Address

=head1 DESCRIPTION

The remote Seaview Address resource

=head1 ATTRIBUTES

=head2 read_rep_class

The read representation class

=cut

has read_rep_class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'XT::Net::Seaview::Representation::Address::JSONLD',
);

=head2 write_rep_class

The write representation class

=cut

has write_rep_class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'XT::Net::Seaview::Representation::Address::JSON',
);

=head2 schema

XT Schema

=cut

has schema => (
    is       => 'ro',
    isa      => 'XTracker::Schema|XT::DC::Messaging::Model::Schema',
    required => 1,
);

=head2 collection_key

=cut

has collection_key => (
    is       => 'ro',
    isa      => 'Str',
    default  => 'address_collection',
);
