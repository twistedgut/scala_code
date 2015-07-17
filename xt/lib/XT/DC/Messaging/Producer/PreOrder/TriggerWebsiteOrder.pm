package XT::DC::Messaging::Producer::PreOrder::TriggerWebsiteOrder;
use NAP::policy "tt", 'class';
use XTracker::Logfile qw( xt_logger );
use NAP::Messaging::Validator;

NAP::Messaging::Validator->add_type_plugins(
    map {"XT::DC::Messaging::Spec::Types::$_"}
        qw(channel_website_name)
    );

with 'XT::DC::Messaging::Role::Producer',
    'XTracker::Role::WithIWSRolloutPhase',
    'XTracker::Role::WithSchema';

=head1 NAME

XT::DC::Messaging::Producer::PreOrder::TriggerWebsiteOrder

=head1 DESCRIPTION

In the initial incarnation of preorder we are using the web sites to generate
actual orders for preordered items once they are delivered. This producer
notifies the web site of preorders with available items so an order can be
generated and exported back to XT for processing and dispatch. Yes you did
just read that correctly.

=cut

has logger => (
    is      => 'ro',
    isa     => 'Log::Log4perl::Logger',
    default => sub { xt_logger('XTracker') },
);

=head1 METHODS

=over 4

=item B<message_spec>

L<Data::Rx> specification for the messages.

=back

=cut

sub message_spec {
    return {
        type => '//rec',
        required => {
            channel           => '/nap/channel_website_name',
            preorder_number   => '//str',
            customer_number   => '//str',
            payment => {
                type  => '//rec',
                required => {
                    psp_reference     => '//str',
                    preauth_reference => '//str',
                    billing_address => {
                        type  => '//rec',
                        required => {
                            first_name      => '//str',
                            last_name       => '//str',
                            line1           => '//str',
                            line2           => '//str',
                            line3           => '//str',
                            towncity        => '//str',
                            county          => '//str',
                            country_iso     => '//str',
                            postcode        => '//str',
                            comparison_hash => '//str',
                        },
                    },
                },
            },
            shipping_info => {
                type  => '//rec',
                required => {
                    shipping_address => {
                        type  => '//rec',
                        required => {
                            first_name      => '//str',
                            last_name       => '//str',
                            line1           => '//str',
                            line2           => '//str',
                            line3           => '//str',
                            towncity        => '//str',
                            county          => '//str',
                            country_iso     => '//str',
                            postcode        => '//str',
                            comparison_hash => '//str',
                        },
                    },
                    shipping_items => {
                        type => '//arr',
                        contents => {
                            type => '//rec',
                            required => {
                                sku   => '/nap/sku',
                                price => '//num',
                                tax   => '//num',
                                duty  => '//num',
                            },
                        },
                    },
                },
            },
            items => {
                type => '//arr',
                contents => {
                    type => '//rec',
                    required => {
                        sku   => '/nap/sku',
                        price => '//num',
                        tax   => '//num',
                        duty  => '//num',
                    },
                },
            },
        },
        optional => {
            comment => '//str',
        },
    };
}

=over 4

=item B<transform>

Create the message header with the correct queue and type information. Collect
the preorder and item data and create the message data structure.

=back

=cut

has '+type' => ( default => 'PreOrderTriggerWebsiteOrder' );
has '+set_at_type' => ( default => 0 );

sub transform {
    my ($self, $header, $data) = @_;

    my $preorder = delete $data->{preorder};
    die "Need a preorder, but didn't get one" unless $preorder;

    my $channel = $preorder->channel->web_name;

    # if the config does not map the destination, we don't have to send anything
    return unless $self->routes_map->{$channel};

    $header->{destination} = $channel;

    my $items    = delete $data->{items};

    die "Need items to export, but didn't get any" unless $items;

    $self->logger->debug('Transforming preorder ' . $preorder->id );

    # Pre-order info
    $self->logger->debug('Adding preorder information');

    $data->{channel}           = $preorder->channel->website_name;
    $data->{preorder_number}   = $preorder->pre_order_number;
    $data->{customer_number}   = $preorder->customer->is_customer_number;

    # Payment
    $data->{payment}->{psp_reference}     = $preorder->get_payment->psp_ref;
    $data->{payment}->{preauth_reference} = $preorder->get_payment->preauth_ref;

    my $billing_add = {};

    $billing_add->{first_name}      = $preorder->invoice_address->first_name;
    $billing_add->{last_name}       = $preorder->invoice_address->last_name;
    $billing_add->{line1}           = $preorder->invoice_address->address_line_1;
    $billing_add->{line2}           = $preorder->invoice_address->address_line_2;
    $billing_add->{line3}           = $preorder->invoice_address->address_line_3;
    $billing_add->{towncity}        = $preorder->invoice_address->towncity;
    $billing_add->{county}          = $preorder->invoice_address->county;
    # $billing_add->{country}       = $preorder->invoice_address->country;
    $billing_add->{country_iso}
      = $preorder->invoice_address->country_ignore_case->code;
    $billing_add->{postcode}        = $preorder->invoice_address->postcode;
    $billing_add->{comparison_hash}
      = $self->md5_b64_pad($preorder->invoice_address->address_hash);

    # 'towncity' is required on the frontend
    # side so populate with 'county' if empty
    $billing_add->{towncity} ||= $billing_add->{county};

    $data->{payment}->{billing_address} = $billing_add;

    # Shipping information
    $self->logger->debug('Adding shipping information');

    my $shipping_add = {};

    $shipping_add->{first_name}      = $preorder->shipment_address->first_name;
    $shipping_add->{last_name}       = $preorder->shipment_address->last_name;
    $shipping_add->{line1}           = $preorder->shipment_address->address_line_1;
    $shipping_add->{line2}           = $preorder->shipment_address->address_line_2;
    $shipping_add->{line3}           = $preorder->shipment_address->address_line_3;
    $shipping_add->{towncity}        = $preorder->shipment_address->towncity;
    $shipping_add->{county}          = $preorder->shipment_address->county;
    # $shipping_add->{country}         = $preorder->shipment_address->country;
    $shipping_add->{country_iso}
      = $preorder->shipment_address->country_ignore_case->code;
    $shipping_add->{postcode}        = $preorder->shipment_address->postcode;
    $shipping_add->{comparison_hash}
      = $self->md5_b64_pad($preorder->shipment_address->address_hash);

    # 'towncity' is required on the frontend
    # side so populate with 'county' if empty
    $shipping_add->{towncity} ||= $shipping_add->{county};

    $data->{shipping_info}->{shipping_address} = $shipping_add;

    # Shipping and packaging are always free
    foreach my $sku ($preorder->shipping_charge->sku,
                     $preorder->packaging_type->sku   ) {
        push @{$data->{shipping_info}
                    ->{shipping_items}}, { sku    => $sku,
                                           price  => 0,
                                           tax    => 0,
                                           duty   => 0,
                                         };
    }

    # Items to export
    foreach my $item ( @$items ) {

        if( $preorder->contains_item($item) ){

            $self->logger->debug('Adding preorder item ' . $item->variant->sku );

            push @{$data->{items}}, { sku    => $item->variant->sku,
                                      price  => $item->unit_price,
                                      tax    => $item->tax,
                                      duty   => $item->duty,
                                  };
        }
        else{
            my $err_str = q{Can't export non-existent preorder item: }
                          . $item->variant->sku ;
            $self->logger->error($err_str);
            die $err_str;
        }
    }

    # Whatever's left - anything?
    $self->logger->debug('Adding miscellaneous info');

    # No use for the optional comment at the moment
    # $data->{comment} = '';

    # We're done
    $self->logger->debug('Transform complete');

    return ($header, $data);
}

=over 4

=item B<md5_b64_pad>

Digest::MD5 does not pad the base64 encoded string to a multiple of 4
bytes so we add it here. See the Digest::MD5 documentation for details.

=back

=cut

sub md5_b64_pad {
    my $self = shift;
    return shift . '==';
}

1;
__END__
