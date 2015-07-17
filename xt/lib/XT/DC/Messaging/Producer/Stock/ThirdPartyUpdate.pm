package XT::DC::Messaging::Producer::Stock::ThirdPartyUpdate;
use NAP::policy "tt", 'class';

with 'XT::DC::Messaging::Role::Producer';

use Carp;
use Scalar::Util qw/blessed/;

sub message_spec {
    return {
        type => '//rec',

        required => {
            stock_product => {
                type => '//rec',
                required => {
                    stock => {
                        type => '//rec',
                        required => {
                            status => '//str',
                            location => '//str',
                            quantity => '//int',
                        },
                    },
                    SKU => '//str',
                }
            }
        }
    }
}

has '+type' => ( default => 'ThirdPartyStockUpdate' );
has '+set_at_type' => ( default => 0 );

=head2 transform

    $handler->msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::Stock::ThirdPartyUpdate',
        {
            business => $business,
            status   => ('On Order'|'In Transit'|'Quarantined'|'Sellable'),
            # FIXME: Ensure this code works with all DC's, not just specific ones (if uncommented) - Consider using XT::Rules!
            location => ('DC1'|'DC2'),
            quantity => $quantity,
            sku      => $variant.third_party_sku,
        },
    );

Create a message to send stock updates to a third party via our
internal integration service.

=cut
sub transform {
    my ($self, $header, $data ) = @_;

    foreach (qw[status location quantity sku]) {
        croak "$_ element required in data hash" unless defined $data->{$_};
    }
    croak "business object required in data hash"
        unless defined $data->{business} && blessed $data->{business};

    my $status   = delete $data->{status};
    my $location = delete $data->{location};
    my $quantity = delete $data->{quantity};
    my $sku      = delete $data->{sku};
    my $business = delete $data->{business};

    $data->{'stock_product'} = {
        stock => {
            status   => $status,
            location => $location,
            quantity => $quantity,
        },
        SKU => $sku,
    };

    return ( $header, $data );

}

1;
