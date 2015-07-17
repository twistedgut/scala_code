package XT::Net::Seaview::Resource::Customer;

use NAP::policy "tt", 'class';
extends 'XT::Net::Seaview::Resource';

use XT::Net::Seaview::Representation::Customer::JSONLD;
use XT::Net::Seaview::Representation::Customer::JSON;

=head1 NAME

XT::Net::Seaview::Resource::Customer

=head1 DESCRIPTION

The remote Seaview Customer resource

=head1 ATTRIBUTES

=head2 read_rep_class

The read representation class

=cut

has read_rep_class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'XT::Net::Seaview::Representation::Customer::JSONLD',
);

=head2 write_rep_class

The write representation class

=cut

has write_rep_class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'XT::Net::Seaview::Representation::Customer::JSON',
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
    default  => 'customer_collection',
);
