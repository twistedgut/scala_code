package XT::DC::Messaging::Producer::ProductService::UpdateProductTags;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

use XTracker::Config::Local 'config_var';
use Carp qw( croak );

=head1 NAME

XT::DC::Messaging::Producer::ProductService::UpdateProductTags - add or remove product tags

=head1 METHODS

=head2 C<message_spec>

L<Data::Rx> spec for the update_product_tags message

=cut

sub message_spec {
    return {
        type => '//rec',
        required => {
            products => {
                type => '//arr',
                length => { min => 1 },
                contents => {
                    type => '//rec',
                    required => {
                        product_id => '//int',
                        channel_id => '//int',
                    },
                },
            },
        },
        optional => {
            add_product_tags => {
                type => '//arr',
                contents => '//str',
            },
            remove_product_tags => {
                type => '//arr',
                contents => '//str',
            },
        }
    };
}

has '+type' => ( default => 'update_product_tags' );

=head2 C<transform>

    $amq->transform_and_send( 'XT::DC::Messaging::Producer::ProductService::UpdateProductTags', {
        channel_id  => $self->payload->{channel_id},
        pids        => $self->data->{pids_touse},
        add_product_tags => [ 'foobar' ],
        remove_product_tags => [ 'boohoo', 'yoohoo' ],
    } );

Given a set of PIDs and a channel_id, will send a command to the product service
add or remove the specified product tags from thoses products.

=cut

sub transform {
    my ($self,$header,$data) = @_;

    # Very basic argument validation
    my $chid = $data->{channel_id} // croak "Channel ID required";
    my $pids = $data->{pids} // croak "PIDs required";
    my $add_product_tags = $data->{add_product_tags} // [];
    my $remove_product_tags = $data->{remove_product_tags} // [];

    # Transform the data into expected format
    my @products;
    foreach ( @{$data->{pids}} ) {
        push @products, {
            product_id => $_,
            channel_id => $chid,
        };
    }

    my $payload;
    $payload->{products}   = \@products;

    $payload->{add_product_tags} = $add_product_tags;
    $payload->{remove_product_tags} = $remove_product_tags;

    return ($header,$payload);
}
