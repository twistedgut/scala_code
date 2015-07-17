package XT::Net::Seaview::Role::Representation::JSONLD;

use NAP::policy "tt", 'role';

=head1 NAME

XT::Net::Seaview::Role::Representation::JSONLD

=head1 DESCRIPTION

JSON-LD

=head1 ATTRIBUTES

=head2 identity

Resource identity for JSON-LD representations is the value of the "@id" field

=cut

sub _build_identity {
    return shift->data->{'@id'};
}

=head2 media_type

This representation's media type

=cut

sub media_type {
    return 'application/ld+json';
}

=head2 data

Build HashRef of account data from a source. This can be either an XT::Data
object or a JSON string.

=cut

has data => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_data',
);

sub _build_data {
    my $self = shift;
    my $data = undef;

    # Hashref from a JSON string
    $data = JSON->new->utf8->decode($self->src);

    # Extract context
    my $context = delete $data->{'@context'};

    # Extract linked items
    foreach my $linked_item (keys %{$context//{}}){
        if(my $ctr_type = $context->{$linked_item}->{'@container'}){

            # Item is a container. Just flatten it out into a top level
            # array of @ids for the moment
            my $container = delete $data->{$linked_item};

            my @id_set = ();
            foreach my $item (@$container){
                push @id_set, map { $item->{$_}->{'@id'} } keys %{$item//{}};
            }

            $data->{$linked_item} = \@id_set;
        }
        elsif(my $link = delete $data->{$linked_item}){
            # Item is a single value
            # TODO: Added a workaround to make this work with card tokens,
            # TODO: as $link is not a HashRef an that instance.

            given ( ref $link ) {
                when ( 'ARRAY' ) {
                    $data = $link->[0];
                }
                when ( 'HASH' ) {
                    $data->{$linked_item} = $link->{'@id'};
                }
                default {
                    $data->{$linked_item} = $link;
                }
            }

        }
    }

    return $data;
}
