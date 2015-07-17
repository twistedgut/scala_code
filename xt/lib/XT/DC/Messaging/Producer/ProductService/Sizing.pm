package XT::DC::Messaging::Producer::ProductService::Sizing;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer',
    # these are to appease XT's message queue "custom accessors"
    'XTracker::Role::WithIWSRolloutPhase',
    'XTracker::Role::WithPRLs',
    'XTracker::Role::WithSchema';

use XTracker::Config::Local 'config_var';
use Carp qw( croak );

=head1 NAME

XT::DC::Messaging::Producer::ProductService::Sizing - send all sizing details

=head1 METHODS

=head2 C<message_spec>

L<Data::Rx> spec for the product sizing messages.

=cut

sub message_spec {
    return {
        type => '//rec',
        required => {
            product_id => '//int',
            channel_id => '//int',
            size_scheme_variant_size => {
                type => '//arr',
                contents => {
                    type => '//rec',
                    required => {
                        variant_id => '//int',
                        size_id => '//int',
                        sku => '//str',
                        position => '//int',
                    },
                    optional => {
                        third_party_sku => '//str',
                        designer_size => '//str',
                        designer_size_id => '//int',
                        std_size => {
                            type => '//rec',
                            required => {
                                name => '//str',
                                rank => '//int',
                            },
                        },
                        size => '//str',
                        measurements => {
                            type => '//arr',
                            contents => {
                                type => '//rec',
                                required => {
                                    measurement_id => '//int',
                                    measurement_name => '//str',
                                },
                                optional => {
                                    visible => '//bool',
                                    value => '//str'
                                },
                            },
                        },
                    },
                },
            },
        },
        optional => {
            size_scheme => '//str',
            size_scheme_short_name => '//str',
        },
    };
}

has '+type' => ( default => 'product_sizes' );

=head2 C<transform>

    $amq->transform_and_send( 'XT::DC::Messaging::Producer::ProductService::Sizing', {
        product => $product,
        channel_id => $channel_id,
    } );

Given a product object, sends a message with all sizing information.

=cut

sub transform {
    my ($self,$header,$data) = @_;

    # Very basic argument validation
    my $chid = $data->{channel_id} // croak "Channel ID required";
    my $product = $data->{product} // croak "Product required";

    my $payload = $product->sizing_payload($chid);
    $payload->{product_id} = $product->id;
    $payload->{channel_id} = $chid;

    # message groups, to help partition consumers
    $header->{JMSXGroupID} = $product->id;

    return ($header,$payload);
}
