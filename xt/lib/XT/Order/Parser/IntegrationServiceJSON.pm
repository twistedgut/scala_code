package XT::Order::Parser::IntegrationServiceJSON;

use NAP::policy "tt", 'class';
    with    'XT::Order::Role::Parser',
            'XT::Role::DC',

            # roles that currently behave the same across all incoming data
            'XT::Order::Role::Parser::Common::OrderData',
            'XT::Order::Role::Parser::Common::Dates',
            'XT::Order::Role::Parser::Common::Extract',
            'XT::Order::Role::Parser::Common::AsList',

            # NAPGroup specific roles
            'XT::Order::Role::Parser::IntegrationServiceJSON::CustomerData',
            'XT::Order::Role::Parser::IntegrationServiceJSON::DeliveryData',
            'XT::Order::Role::Parser::IntegrationServiceJSON::LineItemData',
            'XT::Order::Role::Parser::IntegrationServiceJSON::OrderDataMapping',
            'XT::Order::Role::Parser::IntegrationServiceJSON::PostageData',
            'XT::Order::Role::Parser::IntegrationServiceJSON::PromotionData',
            'XT::Order::Role::Parser::IntegrationServiceJSON::TenderData',
    ;
use XT::Data::Money;
use XTracker::Config::Local qw/config_var/;

sub is_parsable {
    my ( $class, $data ) = @_;

    # make sure we have 'distinguishing features' for a jimmy choo order
    # before we offer to parse it; the most obvious check is the merchant url
    my $looks_parsable =
           (ref($data) eq 'HASH')
        && exists $data->{orders}
        && exists $data->{merchant_url}
        && $data->{merchant_url} eq 'www.jimmychoo.com'
    ;

    return $looks_parsable;
}

sub parse {
    my($self) = @_;
    my $data = $self->data;
    my @orders;

    if (not exists $data->{orders}) {
        require Carp;
        Carp::confess('no ->{orders} in data');
    }

    foreach my $order (@{$data->{orders}}) {
        my $order_data          = $self->_get_order_data($order);
        my $customer_data       = $self->_get_customer_data($order);
        my $delivery_data       = $self->_get_delivery_data($order);
        my $tender_data         = $self->_get_tender_data({
            tender_lines    => $order->{tender_lines},
            preauth         => $order->{preauth_response_reference}
        });
        foreach my $tender (@{$tender_data}) {
            if (defined $tender->{cv2_response}) {
                $order_data->{cv2_response} = $tender->{cv2_response};
            }
        }

        my $promotion_data      = $self->_get_promotion_data(
            $order->{promotion_basket},
            $order->{promotion_line}
        );

        my $item_data = $self->_get_item_data(
            $order->{delivery_detail} );

        # below is utilising existing methods to map to objects
        my $gift_message
            = $self->_get_gift_message( $item_data, $delivery_data );

        # convert perl structures into single objects
        my $billing_address     = $self->_get_billing_address( $customer_data->{address} );
        my $delivery_address    = $self->_get_delivery_address( $delivery_data );
        my $customer_name       = $self->_get_name( $customer_data );
        my $delivery_name       = $self->_get_name( $delivery_data->{'name'} );
        my $nominated_day       = $delivery_data->{nominated_day} || {};

        my $gross_total         = $self->_get_gross_total( {
            currency =>  $order->{gross_total}->{value}->{currency},
            gross_total => $order->{gross_total}->{value}->{amount},
        });

        my $gross_shipping      = $self->_get_gross_shipping({
            currency => $order_data->{postage}->{currency},
            gross_shipping => $order_data->{postage}->{amount}
        });

        my $shipping_sku = $order_data->{shipping_sku} || undef;
        if (defined $shipping_sku) {
            $shipping_sku =~ s/\s+//g;
        }

        my $currency            = $order_data->{'currency'};
        my $free_shipping       = $self->_get_free_shipping( $promotion_data );


        # convert perl structures into arrays of objects
        my @tenders             = $self->_get_tenders( $tender_data, $currency );
        my @line_items
            = $self->_get_line_items( $item_data, $order_data, $promotion_data );
        my @telephone_numbers
            = $self->_get_billing_telephone_numbers( $customer_data );

        my $zero = XT::Data::Money->new({
            schema      => $self->schema,
            currency    => $gross_shipping->currency,
            value       => 0,
        });

        my $order = XT::Data::Order->new({
            schema                      => $self->schema,

            order_number                => $order_data->{'order_nr'},
            order_date                  => $order_data->{'order_date'},
            channel_name                => $order_data->{'channel'},
            customer_number             => $order_data->{'customer_nr'},
            customer_ip                 => $order_data->{'ip_address'},
            placed_by                   => $order_data->{'placed_by'},
            used_stored_credit_card     => (
                defined $order_data->{'used_stored_card'}
                && $order_data->{'used_stored_card'} eq 'T' ? 1 : 0),

            billing_name                => $customer_name,
            billing_address             => $billing_address,
            billing_email               => $customer_data->{'email'},

            customer_name               => $customer_name,
            delivery_name               => $delivery_name,
            delivery_address            => $delivery_address,

            nominated_delivery_date     => $nominated_day->{nominated_delivery_date},
            nominated_dispatch_date     => $nominated_day->{nominated_dispatch_date},

            line_items                  => \@line_items,
            tenders                     => \@tenders,
            billing_telephone_numbers   => \@telephone_numbers,

            is_free_shipping            => ( defined $free_shipping ? 1 : 0 ),
            free_shipping               => $free_shipping,
            shipping_sku                => $shipping_sku,

            gross_total                 => $gross_total,

            shipping_net_price          => $gross_shipping,
            shipping_tax                => $zero,
            shipping_duties             => $zero,

            gift_message                => $gift_message,
            is_gift_order               => (defined $gift_message ? 1 : 0),
            sticker                     => $order_data->{sticker},
            source_app_name             => $order_data->{source_app_name},
            source_app_version          => $order_data->{source_app_version},
            language_preference         => $order_data->{language_preference},
        });

        push @orders, $order;

    }

    return wantarray ? @orders : \@orders;
}

sub _get_order_data {
    my($self,$node) = @_;
    my %keys = %{ $self->_order_data_key_mapping };
=for posterity
    my %keys = (
        'o_id' => 'order_nr',
        'cust_id' => 'customer_nr',
        'channel' => 'channel',
        'customer_ip' => 'ip_address',
        'placed_by' => 'placed_by',
        'order_date' => 'order_date',
        'shipping_method' => 'shipping_sku',
    );
=cut

#    my $data = $self->_extract_fields($node,\%keys);
    my $data = $self->_extract(\%keys,$node);#,\%keys);
    $data->{postage}->{currency} = $node->{postage}->{value}->{currency};
    $data->{postage}->{amount} = $node->{postage}->{value}->{amount};

    $data->{currency} = $node->{gross_total}->{value}->{currency};


    $data->{order_date} =
        $self->_get_timezoned_date(
            $data->{order_date},
            config_var("DistributionCentre", "timezone"),
        );


    # cos the people generating the payload have no sense of pride in their
    # work I'm going to tie this down
    # (cos the people complaining about lack of pride have no pride
    # themselves, changing this to something cleaner ;-) CCW)
    $data->{channel} =~ s{\AJCHOO\.(INTL|AM)\z}{JC-\U$1\E}i
        if defined $data->{channel};

# FIXME:
#        basket_id              = $order_data->{order_nr};
#        ip_address             = $node->findvalue('@CUST_IP');
#        placed_by              = $node->findvalue('@LOGGED_IN_USERNAME');
#    $order_data->{used_stored_card}       = $node->findvalue('@USED_STORED_CREDIT_CARD');

#    ### legacy card info
#    $order_data->{sticker}
#        = $node->findvalue('DELIVERY_DETAILS/STICKER');
#
#    # DC specific fields
#    # FIXME how best to incorporate this?
#    if ( $self->dc() eq 'DC2' ) {
#        $order_data->{order_date}
#            = _get_est_date( $node->findvalue('@ORDER_DATE') );
#        $order_data->{use_external_tax_rate}
#            = $node->findvalue('@USE_EXTERNAL_SALETAX_RATE') || 0;
#    }
#    else { # Default to reading value from XML file
#        $order_data->{order_date} = $node->findvalue('@ORDER_DATE');
#    }
#
#    print "Processing Order: ".$order_data->{order_nr}."\n";
#
#    # order totals and currency
#    $order_data->{gross_total}    = $node->findvalue('GROSS_TOTAL/VALUE');
#    $order_data->{gross_shipping} = $node->findvalue('POSTAGE/VALUE');
#    $order_data->{currency}       = $node->findvalue('GROSS_TOTAL/VALUE/@CURRENCY');
#

    return $data;
}



sub _get_delivery_data {
    my($self,$order) = @_;
    my $shipments;
    my $node = $order->{delivery_detail};

    if (defined $node && ref($node) ne 'ARRAY') {
        $shipments = [ $node ];
    } else {
        $shipments = $node;
    }

    my $out = [];
    foreach my $del (@{$shipments}) {
        my $data = {
            name            => $self->_extract_name($del->{name}),
            address         => $self->_extract_address($del->{address}),
            gift_message    => $del->{gift_message},
            nominated_day => {
                nominated_delivery_date => $del->{nominated_day}->{delivery_date},
                nominated_dispatch_date => $del->{nominated_day}->{dispatch_date},
            },
        };
        push @{$out}, $data;
    }

    if (scalar @{$out} > 1) {
        die "We don't handle multiple deliveries - we'd have to change "
            ."the base method to deal with it which will break xml";
    }

    $out = shift @{$out};
    return $out;
}

sub _get_tender_data {
    my($self,$rh_args) = @_;

    my $node                    = $rh_args->{tender_lines};
    my $payment_pre_auth_ref    = $rh_args->{preauth};

    my @tenders;
    my $count;
    foreach my $tender (@{$node}) {
        my $tender_data = {};
        # get tender type (card or credit)
        $tender_data->{type}    = $tender->{type};
        $tender_data->{rank}    = ++$count;


        # has to have a type!
        if (!$tender_data->{type}) {
            # FIXME exception
            die "No Tender Line type present";
        }

        # get tender value
        $tender_data->{value}   = $tender->{value}->{amount};

        if (defined $tender_data->{type}) {
            if ($tender_data->{type} =~ /^card$/i) {
                $tender_data->{type} = 'Card Debit';
                $tender_data->{payment_pre_auth_ref} = $payment_pre_auth_ref;
                $tender_data->{number} =
                    $tender->{card_details}->{number};
                $tender_data->{cv2_response} =
                    $tender->{card_details}->{fraud_score};
            }
        }

# FIXME: need to decide what to do with this for integration service
#        if ($tender_data->{type} eq "Gift Voucher") {
#            $tender_data->{type}    = "Voucher Credit";
#            $tender_data->{voucher_code} = $tender->findvalue('@VOUCHER_CODE');
#            # FIXME throw exception
#            die "Voucher code missing"
#                unless defined $tender_data->{voucher_code}
#                    and length $tender_data->{voucher_code};
#        }
#        elsif ($tender_data->{type} eq "Card") {
#            $tender_data->{type} = 'Card Debit';
#            $tender_data->{payment_pre_auth_ref} =
#                $tender->findvalue('PAYMENT_DETAILS/PRE_AUTH_CODE');
#
## FIXME: card_type  number expire_date threed_secure fraud_score
## FIXME: transaction_reference
#            $tender_data = $tender->{auth_code};
#        }

        push @tenders, $tender_data;
    }
    return \@tenders;

}


sub _extract_common_item_data {
    my $self = shift;
    my $item = shift;

    my %mapping = (
        'ol_id' => 'sequence',
        'description' => 'description',
        'sku' => 'third_party_sku',
        'quantity' => 'quantity',
        'gift_to' => 'gift_to',
        'gift_from' => 'gift_from',
        'gift_message' => 'gift_message',
        'sale' => 'sale',
    );
    my $out = $self->_extract(\%mapping,$item);
    $out->{third_party_sku} =~ s/\s+//g;
    $out->{unit_price} = $item->{unit_net_price}->{value}->{amount} || 0;
    $out->{tax} = $item->{tax}->{value}->{amount} || 0;
    $out->{duty} = $item->{duties}->{value}->{amount} || 0;

    #($out->{product_id}, $out->{size_id}) = split(/-/, $out->{sku});

    return wantarray ? %{$out} : $out;
}

sub _extract_telephone {
    my($self,$order,$node) = @_;

    my $numbers = { };

    foreach my $telephone ($order->findnodes("$node/TELEPHONE")) {
        if ($telephone->findvalue('@TYPE') eq "HOME") {
            $numbers->{home_telephone} = $telephone->hasChildNodes
              ? $telephone->getFirstChild->getData : "";
        }
        elsif ($telephone->findvalue('@TYPE') eq "OFFICE") {
            $numbers->{work_telephone} = $telephone->hasChildNodes
              ? $telephone->getFirstChild->getData : "";
        }
        elsif ($telephone->findvalue('@TYPE') eq "MOBILE") {
            $numbers->{mobile_telephone} = $telephone->hasChildNodes
              ? $telephone->getFirstChild->getData : "";
        }
    }

    $numbers->{telephone} = (defined $numbers->{home_telephone} and $numbers->{home_telephone} eq "")
      ? $numbers->{work_telephone}
        : $numbers->{home_telephone};

    return $numbers;
}





__PACKAGE__->meta->make_immutable;

1;
