package XT::Order::Role::Parser;
use Moose::Role;

use XT::Data::Types;
use DateTime::Format::Strptime;
use Data::Dump qw/pp/;

requires 'is_parsable';
requires 'parse';

has data => (
    required    => 1,
    is          => 'ro',
);

has schema => (
    is          => 'ro',
    isa         => 'DBIx::Class::Schema|XTracker::Schema|XT::DC::Messaging::Model::Schema',  # when testing locally
    required    => 1,
);


sub _get_gift_message {
    my ( $self, $item_data, $delivery_data ) = @_;

    die '"item_data" requires a hash reference containing item data (_get_gift_message)'
        unless $item_data and ref( $item_data ) eq 'HASH';
    die '"delivery_data" requires a hash reference containing order data (_get_gift_message)'
        unless $delivery_data and ref( $delivery_data ) eq 'HASH';

    # check in delivery data...
    return $delivery_data->{gift_message} if ($delivery_data->{gift_message});

    return;
}

sub _get_billing_address {
    my ( $self, $customer_data ) = @_;

    die 'Requires a hash reference containing customer data'
        unless $customer_data and ref( $customer_data ) eq 'HASH';

    my $billing_address = XT::Data::Address->new({
        schema      => $self->schema,

        line_1      => $customer_data->{'address_line_1'},
        line_2      => $customer_data->{'address_line_2'} || '',
        line_3      => '', # TODO: remove address_line_3 from code
        town        => $customer_data->{'towncity'},
        country_code=> $customer_data->{'country'},
        postcode    => $customer_data->{'postcode'},
    });

    if ( defined $customer_data->{'addr_urn'} ) {
        $billing_address->urn( $customer_data->{'addr_urn'} )
    }
    if ( defined $customer_data->{'addr_last_modified'} ) {
        $billing_address->last_modified( $customer_data->{'addr_last_modified'} )
    }

    if ( defined $customer_data->{'county'} ) {
        $billing_address->county( $customer_data->{'county'} )
    }
    elsif ( defined $customer_data->{'state'} ) {
        $billing_address->state( $customer_data->{'state'} )
    }
    else {
        # FIXME exception
        die 'Customer address contains neither state nor county';
    }

    return $billing_address;
}

sub _get_delivery_address {
    my ( $self, $delivery_data ) = @_;

    die 'Requires a hash reference containing delivery data'
        unless $delivery_data and ref( $delivery_data ) eq 'HASH';

    my $delivery_address = XT::Data::Address->new({
            schema      => $self->schema,
            first_name  => $delivery_data->{'name'}{'first_name'},
            last_name   => $delivery_data->{'name'}{'last_name'},

            line_1      => $delivery_data->{'address'}{'address_line_1'},
            line_2      => $delivery_data->{'address'}{'address_line_2'},
            line_3      => '',
            town        => $delivery_data->{'address'}{'towncity'},
            county      => $delivery_data->{'address'}{'county'},
            postcode    => $delivery_data->{'address'}{'postcode'},
            country_code=> $delivery_data->{'address'}{'country'},
    });

    if ( defined $delivery_data->{'address'}{'addr_urn'} ) {
        $delivery_address->urn( $delivery_data->{'address'}{'addr_urn'} )
    }
    if ( defined $delivery_data->{'address'}{'addr_last_modified'} ) {
        $delivery_address->last_modified( $delivery_data->{'address'}{'addr_last_modified'} )
    }

    return $delivery_address;
}

sub _get_gross_total {
    my ( $self, $order_data ) = @_;

    die 'Requires a hash reference containing order data'
        unless $order_data and ref( $order_data ) eq 'HASH';

    my $gross_total = XT::Data::Money->new({
        schema      => $self->schema,

        currency    => $order_data->{'currency'},
        value       => $order_data->{'gross_total'},
    });

    return $gross_total;
}

sub _get_gross_shipping {
    my ( $self, $order_data ) = @_;

    die 'Requires a hash reference containing order data'
        unless $order_data and ref( $order_data ) eq 'HASH';

    my $gross_shipping = XT::Data::Money->new({
        schema      => $self->schema,

        currency    => $order_data->{'currency'},
        value       => $order_data->{'gross_shipping'},
    });

    return $gross_shipping;
}

sub _get_free_shipping {
    my ( $self, $promotion_data ) = @_;

    if ( defined $promotion_data->{promotion_basket} ) {
        my $basket = $promotion_data->{promotion_basket};
        foreach my $promo_id ( keys %{$basket} ) {
            # overloading of the data block means we can get 'items' in our
            # basket hash - grr!
            next if ($promo_id eq 'items');
            if ( $basket->{$promo_id}{type} eq 'free_shipping' ) {
                # This is slightly overkill as most of these are
                # not required but we do need a few attributes later
                return XT::Data::Order::CostReduction->new({
                    id          => $promo_id,
                    type        => $basket->{$promo_id}{class},
                    description => $basket->{$promo_id}{description},
                    value       => 0,
                    unit_price  => 0,
                    tax         => 0,
                    duty        => 0,
                });
            }
        }
    }

    return;
}

sub _get_tenders {
    my ( $self, $tender_data, $currency ) = @_;

    die 'Requires an array reference of tender data hashes'
        unless $tender_data and ref( $tender_data ) eq 'ARRAY';
    die 'Requires a currency value' unless $currency;

    my @tenders;
    foreach ( @{$tender_data} ) {
        my $value = XT::Data::Money->new({
            schema      => $self->schema,

            currency    => $currency,
            value       => $_->{'value'},
        });
        my $rh_tender = {
            schema  => $self->schema,
            id      => 'foo',
            type    => $_->{'type'},
            rank    => $_->{'rank'},
            value   => $value,
        };

        if ($_->{type} eq 'Card Debit') {
            $rh_tender->{payment_pre_auth_ref} = $_->{payment_pre_auth_ref}
        };
        if ( $_->{type} eq 'Voucher Credit' ) {
            $rh_tender->{voucher_code} = $_->{voucher_code};
        }
        # FIXME: what is id and payment_pre_auth_ref?
        push @tenders, XT::Data::Order::Tender->new($rh_tender);
    }

    return @tenders;
}

sub _get_line_items {
    my ( $self, $item_data, $order_data, $promotion_data ) = @_;

    die 'Requires a hash reference containing item data'
        unless $item_data and ref( $item_data ) eq 'HASH';
    die 'Requires a hash reference containing order data'
        unless $order_data and ref( $order_data ) eq 'HASH';
    die 'Requires a hash reference containing promotion data'
        unless $promotion_data and ref( $promotion_data ) eq 'HASH';

    my @line_items;
    foreach my $item_id ( keys %{$item_data} ) {
        my $current_item = $item_data->{$item_id};

        my $unit_net_price = XT::Data::Money->new({
            schema      => $self->schema,
            currency    => $order_data->{currency},
            value       => $current_item->{unit_price},
        });
        my $tax = XT::Data::Money->new({
            schema      => $self->schema,
            currency    => $order_data->{currency},
            value       => $current_item->{tax},
        });
        my $duties = XT::Data::Money->new({
            schema      => $self->schema,
            currency    => $order_data->{currency},
            value       => $current_item->{duty},
        });

        my %line_item_args = (
            schema               => $self->schema,

            id                   => $item_id,
            sequence             => $current_item->{'sequence'},
            description          => $current_item->{'description'},
            quantity             => $current_item->{'quantity'},
            unit_net_price       => $unit_net_price,
            tax                  => $tax,
            duties               => $duties,

            gift_to              => $current_item->{'gift_to'},
            gift_from            => $current_item->{'gift_from'},
            gift_message         => $current_item->{'gift_message'},
            gift_recipient_email => $current_item->{'gift_recipient_email'},

            returnable_state     => $current_item->{returnable_state},
            on_sale_flag         => $current_item->{sale},
        );

        $line_item_args{sku} = $current_item->{sku}
            if $current_item->{sku};

        $line_item_args{third_party_sku} = $current_item->{third_party_sku}
            if $current_item->{third_party_sku};

        $line_item_args{is_voucher} = $current_item->{is_voucher}
            if $current_item->{is_voucher};

        $line_item_args{is_gift} = $current_item->{is_gift}
            if $current_item->{is_gift};

        my $cost_reduction =
            $self->_add_cost_reduction($item_id, $promotion_data);
        $line_item_args{cost_reduction} = $cost_reduction
            if defined $cost_reduction;

        my $line_item = XT::Data::Order::LineItem->new(%line_item_args);

        push @line_items, $line_item;
    }

    return @line_items;
}

sub _add_cost_reduction {
    my ($self, $item_id, $promotion_data) = @_;
    my $cost_reduction;

    foreach my $promo_id ( keys %{$promotion_data} ) {
        my $current_promo = $promotion_data->{$promo_id};
        # escape early and don't confusingly auto-vivify {items}
        next unless exists $current_promo->{items};
        if ( exists $current_promo->{items}{$item_id} ) {

            # free_shipping - should be ignored when processing lineitems
            next
                if 'free_shipping' eq $current_promo->{type};

            $cost_reduction = XT::Data::Order::CostReduction->new({
                id          => $promo_id,
                type        => $current_promo->{type},
                description => $current_promo->{description},
                value       => $current_promo->{value},
            });

            #$line_item_args{cost_reduction} = $promotion;
            last;

            # we found what we were looking for; return it back up the stack
        }
    }
    return $cost_reduction;
}

sub _get_billing_telephone_numbers {
    my ( $self, $customer_data ) = @_;

    die 'Requires a hash reference containing customer data'
        unless $customer_data and ref( $customer_data ) eq 'HASH';

    my @billing_telephone_numbers;
    foreach ( qw[home_telephone work_telephone mobile_telephone] ) {
        if ( defined $customer_data->{$_} ) {
            push (@billing_telephone_numbers, XT::Data::Telephone->new({
                type    => $_,
                number  => $customer_data->{$_},
            }));
        }
    }

    return @billing_telephone_numbers;
}


sub _get_shipping_telephone_numbers {
    my ( $self, $shipping_data ) = @_;

    my @telephones  = $self->_get_billing_telephone_numbers($shipping_data);

    return @telephones;

}

# CANDO-326: used to get the Gift Line Items
sub _get_gift_line_items {
    my ( $self, $gift_item_data, $order_data )  = @_;

    my @gift_item_data;

    foreach my $seq ( sort { $a <=> $b } keys %{ $gift_item_data } ) {
        my $item    = $gift_item_data->{ $seq };

        push @gift_item_data, XT::Data::Order::GiftLineItem->new( {
                                            schema      => $self->schema,

                                            sequence    => $seq,
                                            sku         => $item->{sku},
                                            description => $item->{description},
                                            quantity    => $item->{qty} || 1,
                                            opted_out   => ( uc( $item->{opted_out} ) eq 'Y' ? 1 : 0 ),
                                    } );
    }

    return @gift_item_data;
}

1;

__END__

=head1 NAME

XT::Order::Role::Parser

=head1 DESCRIPTION

Role providing an abstract interface that all XT::Order::Parser::* objects
must comply with.

=head1 METHODS

=head2 is_parsable

Given a data reference, returns a boolean representing whether the parser can
parse the given data.

=head2 parse

Given a chunk of data, returns an L<XT::Data::Order> object representing the
order data.

=head1 ATTRIBUTES

=head2 data

Required, read only attribute to hold the data passed to the parser at
construction time.

=head1 SEE ALSO

L<XT::Order::ParserFactory>,
L<XT::Order::Parser::JSON>,
L<XT::Order::Parser::XML>

=head1 AUTHOR

Adam Taylor <adam.taylor@net-a-porter.com>
