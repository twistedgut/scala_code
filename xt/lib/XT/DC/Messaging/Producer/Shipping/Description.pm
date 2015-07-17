package XT::DC::Messaging::Producer::Shipping::Description;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

=head1 NAME

XT::DC::Messaging::Producer::Shipping::Description - Producer for Shipping::Description data

=head1 DESCRIPTION

Producer for broadcasting L<XTracker::Schema::Result::Shipping::Description> information.

=head1 METHODS

=head2 C<message_spec>

The L<Data::Rx> message validation.

=cut

sub message_spec {
    return {
        type => '//rec',
        required => {
            name => '//str',
            public_name => '//str',
            title => '//str',
            public_title => '//str',
            product_id => '//int',
            size_id => '//int',
            business_id => '//int',
            business_name => '//str',
            channel_id => '//int',
            channel_name => '//str',
            default_price => '//num',
            default_currency => '//str',
            sku => '//str',
        },
        optional => {
            short_delivery_description => '//str',
            long_delivery_description => '//str',
            estimated_delivery => '//str',
            delivery_confirmation => '//str',
            country_charges => {
                type     => '//arr',
                contents => {
                    type     => '//rec',
                    required => {
                        price    => '//num',
                        currency => '//str',
                        country  => '//str',
                    },
                },
            },
            region_charges => {
                type     => '//arr',
                contents => {
                    type     => '//rec',
                    required => {
                        price    => '//num',
                        currency => '//str',
                        region   => '//str',
                    },
                },
            },
        },
    };
}

has '+type' => ( default => 'ShippingDescription' );

=head2 transform

Takes a L<XTracker::Schema::Result::Shipping::Description> object and transforms
it into a broadcast message for any interested clients.

=cut

sub transform {
    my ($self, $header, $data) = @_;

    my $shipping_description = $data->{shipping_description}
        // croak "Missing shipping_description argument";

    croak "Expects a Shipping::Description object"
        unless $shipping_description->isa('XTracker::Schema::Result::Shipping::Description');

    my $body;

    # If we're passed env variables, use those
    if ( $data->{envs} ) {
        $header->{live}    = $data->{envs}->{live}//0;
        $header->{staging} = $data->{envs}->{staging}//0;
    }
    # Or default to staging and live
    else {
        $header->{live} = $header->{staging} = 1;
    }

    $header->{business_id}   = $body->{business_id}
        = $shipping_description->business->id;
    $header->{business_name} = $body->{business_name}
        = $shipping_description->business->name;
    $header->{channel_id}    = $body->{channel_id}
        = $shipping_description->channel->id;
    $header->{channel_name}  = $body->{channel_name}
        = $shipping_description->channel->web_name;

    $body->{name}          = $shipping_description->name;
    $body->{public_name}   = $shipping_description->public_name;
    $body->{title}         = $shipping_description->title;
    $body->{public_title}  = $shipping_description->public_title;
    $body->{product_id}    = $shipping_description->shipping_charge->product_id;
    $body->{size_id}       = $shipping_description->shipping_charge->size_id;
    $body->{sku}           = $shipping_description->shipping_charge->sku;
    $body->{default_price} = $shipping_description->shipping_charge->charge;
    $body->{default_currency}
        = $shipping_description->shipping_charge->currency->currency;

    _add_if_true($body,$shipping_description,'short_delivery_description');
    _add_if_true($body,$shipping_description,'long_delivery_description');
    _add_if_true($body,$shipping_description,'estimated_delivery');
    _add_if_true($body,$shipping_description,'delivery_confirmation');

    $body->{country_charges} = $shipping_description->country_charges_payload
        if $shipping_description->has_country_charges;
    $body->{region_charges} = $shipping_description->region_charges_payload
        if $shipping_description->has_region_charges;

    return ($header,$body);

}

sub _add_if_true {
    my ( $body, $obj, $field ) = @_;

    if ( $obj->$field ) {
        $body->{$field} = $obj->$field;
    }

    return;
}
