package XT::Order::Parser::NAPGroupJSON;
use NAP::policy "tt", 'class';
    with    'XT::Order::Role::Parser',
            'XT::Role::DC',

            # roles that currently behave the same across all incoming data
            'XT::Order::Role::Parser::Common::OrderData',
            'XT::Order::Role::Parser::Common::Dates',
            'XT::Order::Role::Parser::Common::Extract',
            'XT::Order::Role::Parser::Common::AsList',

            # NAPGroup specific roles
            'XT::Order::Role::Parser::NAPGroup::CustomerData',
            'XT::Order::Role::Parser::NAPGroup::DeliveryData',
            'XT::Order::Role::Parser::NAPGroup::LineItemData',
            'XT::Order::Role::Parser::NAPGroup::OrderDataMapping',
            'XT::Order::Role::Parser::NAPGroup::PostageData',
            'XT::Order::Role::Parser::NAPGroup::PromotionData',
            'XT::Order::Role::Parser::NAPGroup::TenderData',
    ;
use XT::Data::Money;
use XTracker::Utilities qw( :string );

sub is_parsable {
    my ($class, $data) = @_;

    # we need to try to distinguish ourselves from a random JSON order, or
    # more specifically a jimmy-choo JSON order
    #
    # slightly annoyingly MRP is one order per message; but there appear to be
    # other differences from JimmyChoo, so it's probably better to deal with
    # separately for now, and investigate how to bring the two back in line
    # with each other
    my $looks_parsable =
           (ref($data) eq 'HASH')
        && (exists $data->{channel})
        && ($data->{channel} =~ m{\Amrp-})
    ;

    return $looks_parsable;
}
# this sanity checks for a few things that caught me out, or wasted my time
# during dev
# Some of these issues are only because there's old data floating around, but
# it doesn't harm us to catch these things for a little while longer
#
# Sone of these issues to be coded to resolve themselves, but for the moment
# we're being harsh/strict about what we allow and dying horribly when people
# meander off the one true path
#
#   CCW 2011-10-31
sub _sanity_check {
    my ($self, $data) = @_;

    # REASON: NAPGroup sends one order at a time
    #   jchoo send through a list of orders in a message; the MRP work decided
    #   that we would only ever send one order per message; this means that we
    #   should always find $data to be a hashref, never an arrayref
    if ('HASH' ne ref($data)) {
        die q{NAP-Group order data should be a hashref not a list};
    }

    # REASON: content --> amount
    #   amount was deemed to be more meaningful, but some test data still has
    #   {content} nodes
    my $gross_total_node = $data->{gross_total};
    if (not exists $gross_total_node->{amount}) {
        # this is the old format - oops
        if (exists $gross_total_node->{content}) {
            die q{old payload format using 'content' keys for gross_total};
        }
        # we just mysteriously have no amount value - mega-whoops
        die q{no amount in 'gross_total' node};
    }

    # REASON: plural names for keys to lists
    #    initial data had 'tender_line' and 'order_line' with a list of
    #    multiple entries
    #    Annoyingly they appear at slightly different level in the structure,
    #    so we have to repeat ourselves
    #    - please rewrite this in a less crappy fashion!
    foreach my $singular (qw/tender_line/) {
        if (not exists $data->{$singular . q{s}}) {
            # have we accidentally received old format data?
            if (exists $data->{$singular}) {
                die qq{old format data '$singular' found; should be '${singular}s'};
            }
            # this is really bad!
            die qq{'${singular}s' data missing from order data};
        }
    }
    foreach my $singular (qw/order_line/) {
        # although it's always (as far as we've seen) a one item list, we do
        # have a list of 'delivery_details'; let's be thorough and loop
        # through them all
        foreach my $delivery_details (@{$data->{delivery_details}}) {
            if (not exists $delivery_details->{$singular . q{s}}) {
                # have we accidentally received old format data?
                if (exists $delivery_details->{$singular}) {
                    die qq[old format data '$singular' found; should be '${singular}s'];
                }
                # this is really bad!
                # ... unless we have some virtual_delivery_details
                # sheesh! this JSON format blows!
                if (not exists $data->{virtual_delivery_details}) {
                    die qq['${singular}s' data missing from order datar];
                }
            }
        }
    }

    return;
}

sub parse {
    my $self = shift;
    my $data = $self->data;

    # this is to catch old style data and to ensure we don't have it ... ever
    $self->_sanity_check($data);

    my $order_data          = $self->_get_order_data($data);
    my $customer_data       = $self->_get_customer_data($data);
    my $delivery_data       = $self->_get_delivery_data($data);

    my $gross_total = $self->_get_gross_total( {
        currency            => $data->{gross_total}{currency},
        gross_total         => $data->{gross_total}{amount},
    });

    my $gross_shipping = $self->_get_gross_shipping({
            currency       => $order_data->{postage}{currency},
            gross_shipping => $order_data->{postage}{amount}
    });

    my $zero = XT::Data::Money->new({
        schema      => $self->schema,
        currency    => $gross_shipping->currency,
        value       => 0,
    });

    my $tender_data = $self->_get_tender_data({
        tender_lines    => $data->{tender_lines},
        preauth         => $data->{preauth_response_reference}
    });

    my $promotion_data = $self->_get_promotion_data(
        $data->{promotion_basket},
        $data->{promotion_line}
    );

    my $item_data = $self->_get_item_data( $data->{delivery_details} );

    # we use this more than once in the call to new()
    my $customer_name = $self->_get_name( $customer_data );

    # create a new order object with the bare minimum we can get away with
    my $order = XT::Data::Order->new({
        schema                      => $self->schema,
        # channel_name should be 'web_name' from public.channel
        # as this is all caps and we don't want to mess about with
        # find_by_web_name() we'll just uc() the channel we're passed
        channel_name                => uc($order_data->{'channel'}),
        placed_by                   => $data->{logged_in_username},

        customer_ip                 => $order_data->{'ip_address'},
        customer_name               => $customer_name,
        customer_number             => $order_data->{'customer_nr'},

        billing_address             => $self->_get_billing_address( $customer_data->{address} ),
        billing_email               => $customer_data->{email},
        billing_name                => $customer_name,

        delivery_address            => $self->_get_delivery_address( $delivery_data ),
        delivery_name               => $self->_get_name( $delivery_data->{'name'} ),

        order_date                  => $order_data->{'order_date'},
        order_number                => $order_data->{'order_nr'},
        preorder_number             => $order_data->{'preorder_number'},

        language_preference         => $order_data->{language_preference},

        gross_total                 => $gross_total,

        tenders                     => [$self->_get_tenders( $tender_data, $order_data->{'currency'} )],
        line_items                  => [$self->_get_line_items( $item_data, $order_data, $promotion_data )],
        source_app_name             => $order_data->{source_app_name},
        source_app_version          => $order_data->{source_app_version},
    });

    # signature required for order?
    $order->signature_required( string_to_boolean( $order_data->{signature_required} ) )
        if exists $order_data->{signature_required};

    # set the billing (telephone) numbers
    my @telephone_numbers
        = $self->_get_billing_telephone_numbers( $customer_data );
    $order->add_billing_telephone_number(@telephone_numbers);

    # add shipping information
    $order->shipping_sku( $order_data->{shipping_sku} )
        if $order_data->{shipping_sku}; # seems to be empty-string sometimes
    $order->shipping_net_price( $gross_shipping );
    $order->shipping_tax( $zero );
    $order->shipping_duties( $zero );

    # do we have free shipping? seems we need to specify this ourself ...
    my $free_shipping = $self->_get_free_shipping( $promotion_data );
    if ($free_shipping) {
        $order->is_free_shipping(1);
        $order->free_shipping($free_shipping);
    }

    # what's the option for premier routing?
    $order->premier_routing_id( $data->{premier_routing_id} );

    # add data that we have in $delivery_data
    # 'luckily' methods match hash-keys...
    # - nominated-day (ORT-65)
    # - sticker (value)
    my @delivery_fields = qw[
        nominated_delivery_date
        nominated_dispatch_date
        sticker
    ];
    foreach my $field (@delivery_fields) {
        if (exists $delivery_data->{$field}) {
            $order->$field( $delivery_data->{$field} );
        }
    }

    # did our lovely customer use a stored credit card?
    given ($data->{used_stored_credit_card}) {
        when ('T') {
            $order->used_stored_credit_card(1)
        }

        # the attribute defaults to false, so we don't do anything except the
        # case where we *are* using a stored card
    }

    my $gift_message
        = $self->_get_gift_message( $item_data, $delivery_data );
    if ($gift_message) {
        $order->gift_message($gift_message);
        $order->is_gift_order(1);
    }

    # yeah, we only get one, but upstream annoying takes a list, or maybe a
    # listref....
    my @orders = ( $order );
    return wantarray ? @orders : \@orders;
}

1;
