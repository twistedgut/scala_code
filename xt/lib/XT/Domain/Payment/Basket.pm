package XT::Domain::Payment::Basket;
use NAP::policy 'class';

use XT::Domain::Payment;
use XTracker::Constants::FromDB qw(
    :renumeration_type
);
use XTracker::Utilities qw( find_in_AoH find_in_hash);
use List::Util qw ( sum );
use XTracker::Config::Local qw( :DEFAULT config_var  get_namespace_names_for_psp );

=head1 NAME

XT::Domain::Payment::Basket

=head1 DESCRIPTION

Handles constructing basket and interactions with the PSP

=head1 SYNOPSIS

 use XT::Domain::Payment::Basket;

 my $object =  XT::Domain::Payment::Basket->new(
    shipment => $shipment_obj,
 );

$object->send_basket_to_psp;

or

$object->get_balance

=head1 ATTRIBUTES


=head2 shipment

Required:   Yes
Read Only:  Yes
Type:       XTracker::Schema::Result::Public::Shipment

=cut

has shipment => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Shipment',
    required    => 1,
);

=head2 domain_payment

Required:   No
Read Only:  Yes
Type:       XT::Domain::Payment

Defaults to a new XT::Domain::Payment object.

=cut

has domain_payment => (
    is          => 'ro',
    isa         => 'XT::Domain::Payment',
    default     => sub { XT::Domain::Payment->new },
);

=head2 log

Required:   No
Read Only:  Yes
Type:       Log::Log4perl::Logger

The logger to use. Defaults to the C<domain_payment> logger:

    $self->domain_payment->logger;

=cut

has log => (
    is          => 'ro',
    isa         => 'Log::Log4perl::Logger',
    lazy        => 1,
    default     => sub { shift->domain_payment->logger },
);

=head2 shipment_items

Required:   No
Read Only:  No
Type:       Array of Hashes

This contains consolidated Shipment Items having format:
[
    {
        amount     10000, # this is price of one item
        name       "Name",
        quantity   3,
        sku        "2748-863",
        tax        0, #tax of one item
        vat        0 # vat of one item
    },
    {
        amount     -2000,
        name       "XYZ",
        quantity   1,
        sku        "2891-010",
        tax        10.00,
        vat        10.00
    },
    ........
]

=cut

has shipment_items => (
    is          => 'rw',
    traits      => ['Array'],
    isa         => 'ArrayRef[HashRef]',
    required    => 0,
    lazy_build  => 1,
    handles => {
        all_shipment_items => 'elements',
    }

);

=head2 shipping

Required:   No
Read Only:  No
Type:       Hash

contains 'Shipping Charge' and 'Shipping Tax' for shipment
having format:

{
    amount     1000, #shipping_charge
    name       "Shipping",
    quantity   1,
    sku        "shipping",
    tax        0
    vat        167, #shipping_tax

}

=cut

has shipping => (
    is          => 'rw',
    isa         => 'HashRef',
    required    => 0,
    lazy_build  => 1,
);

=head2 store_credit

Required:   No
Read Only:  No
Type:       Hash

contains 'Store Credit' details having format:

{
    amount     -5000,
    name       "Store Credit",
    quantity   1,
    sku        "store_credit",
    tax        0,
    vat        0,
}

=cut

has store_credit => (
    is          => 'rw',
    isa         => 'HashRef|Undef',
    required    => 0,
    lazy_build  => 1,
);

=head2 gift_voucher

Required:   No
Read Only:  No
Type:       Hash

contains 'Gift Voucher' details having format:

{
    amount     -5000,
    name       "Gift Voucher",
    quantity   1,
    sku        "gift_voucher",
    tax        0,
    vat        0,
}

=cut

has gift_voucher => (
    is          => 'rw',
    isa         => 'HashRef|Undef',
    required    => 0,
    lazy_build  => 1,

);

=head2 shipping_tax

Required:   No
Read Only:  No
Type:       Num

contains value of shipping_tax paid for shipment.

=cut

has shipping_tax => (
    is          => 'rw',
    isa         => 'Num',
    lazy_build  => 1,
);

=head2 order

Required:   No
Read Only:  Yes
Type:       XTracker::Schema::Result::Public::Orders

Returns Order object.

=cut

has order => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Orders',
    lazy_build  => 1,
);

=head2 psp_name_config

Required:   No
Read Only:  Yes
Type:       HashRef

Returs hash ref containing all names used for PSP calls.

=cut

has psp_name_config => (
    is          => 'ro',
    isa         => 'HashRef',
    lazy_build  => 1,
);

=head2 schema

Required:   No
Read Only:  Yes
Type:       DBIx::Class::Schema|XTracker::Schema

Returns Schema object.

=cut


has schema => (
    is          => 'ro',
    isa         => 'DBIx::Class::Schema|XTracker::Schema',
    lazy_build  => 1,
);


=head2 shipment_items_for_order

Required:   No
Read Only:  No
Type:       HashRef

Returns HashRef of all shipment_items of order. The format is:
{   shipment_item_id => shipment_item_object,
    .....
}

=cut

has shipment_items_for_order => (
    is          => 'rw',
    traits      => ['Hash'],
    isa         => 'HashRef',
    required    => 0,
    lazy_build  => 1,
    handles     => {
        'shipment_item_exists_for_order' => 'exists',
        'get_shipment_item_for_order' => 'get',
    },
);


sub _build_shipment_items_for_order {
    my $self = shift;

    # Get all shipments for this order
    my $shipments = $self->shipment->order->shipments;


    # create a hash of all shipment_items for the order.
    my %shipment_items =
        map { $_->id => $_ }
        map { $_->shipment_items->all }
        $shipments->all;

    return \%shipment_items;

}

sub _build_psp_name_config {
    my $self = shift;

    return ( get_namespace_names_for_psp ($self->schema) );

}
sub _build_order {
    my $self = shift;

    return $self->shipment->order;
}


sub _build_schema {
    my $self= shift;

    return $self->shipment->result_source->schema;
}

=head2 get_shipment_item_data

Returns shipment item HashRef to be used for PSP basket construction of following format:
{
    "sku":"5432156",
    "name":"Shawl-collar knitted cardigan",
    "amount":36000,#in pence
    "vat": 6000, #in pence
    "tax": 1000, #in pence
    "quantity":1
}

=cut

sub get_shipment_item_data {
    my $self            = shift;
    my $shipment_item   = shift;


    my $variant = $shipment_item->get_true_variant;
    my $product = $variant->product;

    # amount, tax & duty is in pence
    my $amt = $shipment_item->unit_price +
        $shipment_item->tax +
        $shipment_item->duty;

    return {} if ($amt <=0);
    my $data = {
        sku  => $variant->sku,
        name => $product->name,
        amount => _format_in_pence( $amt ),
        vat     => _format_in_pence( $shipment_item->tax ),
        tax     => _format_in_pence( $shipment_item->duty ),
        quantity => 1,
    };

    return $data;
}

sub _build_shipment_items {
    my $self = shift;

    my @shipment_items = $self->shipment->non_cancelled_items->all;

    my @shipment_line_items;

    foreach my $item ( @shipment_items ) {
        my $line_item =  $self->get_shipment_item_data($item);
        my $hash_to_compare = {
            sku     => $line_item->{sku},
            name    => $line_item->{name},
            amount  => $line_item->{amount},
            vat     => $line_item->{vat},
            tax     => $line_item->{tax},
        };
        if( my $item_ref = find_in_AoH(\@shipment_line_items, $hash_to_compare) ) {
            $item_ref->{quantity} +=1;
        } else {
            push (@shipment_line_items, $line_item);
        }
    }

    # Sort result by SKU and Quantity
    my $result = [ sort { $a->{sku} cmp $b->{sku} || $a->{quantity} <=> $b->{quantity} } @shipment_line_items];
    return( $result);

}

=head2 total_item_value

 my $total = $self->total_item_value;

 Returns total cost of 'Shipment Items' including tax and duties.

=cut

sub total_item_value {
    my $self = shift;

    my $total = sum (
        map {
            $_->{amount} * $_->{quantity}
        } $self->all_shipment_items
    ) // 0;

    return $total;

}

=head2 grand_total

 my $grand_total  = $self->grand_total;

 Return total of Shipment_items + shipping_charge

=cut

sub grand_total {
    my $self = shift;

    my $total  = $self->total_item_value
        + ( _format_in_pence( $self->shipment->shipping_charge ) || 0 );

    return $total;
}

sub _build_shipping {
    my $self = shift;

    my $tax = $self->shipment->calculate_shipping_tax( $self->grand_total );
    $self->shipping_tax ( $tax );

    # amount, tax & duty is in pence
    my $data = {
        sku     => $self->psp_name_config->{shipping_sku},
        name    => $self->psp_name_config->{shipping_name},
        amount  => _format_in_pence( $self->shipment->shipping_charge ),
        vat     => _format_in_pence( $self->shipping_tax ),
        # tax in this instance represent duties and so is zero for Shipping charge
        tax     => 0,
        quantity => 1,
    };

    return $data;
}

sub _build_gift_voucher {
    my $self = shift;

    my @vouchers = $self->shipment->order->voucher_tenders->all;

    my $sum= 0;
    $sum += $_->value for @vouchers;

    return undef if ( $sum <= 0);

    return ( {
        sku         => $self->psp_name_config->{giftvoucher_sku},
        name        => $self->psp_name_config->{giftvoucher_name},
        amount      => "-"._format_in_pence( $sum),
        vat         => 0,
        tax         => 0,
        quantity    => 1
    });

}

sub _build_store_credit {
    my $self = shift;

    my $tender = $self->shipment->order->store_credit_tender;

    return undef if ( !$tender || $tender->value <= 0);

    return ( {
        sku         => $self->psp_name_config->{storecredit_sku},
        name        => $self->psp_name_config->{storecredit_name},
        amount      => "-"._format_in_pence( $tender->value ),
        vat         => 0,
        tax         => 0,
        quantity    => 1

    });
}


=head2 get_balance

Returns total amount paid for order. It removes
Store credit and  gift voucher to calculate it.

=cut

sub get_balance {
    my $self = shift;

    my $balance = $self->grand_total;
    $balance += $self->gift_voucher->{amount} if ( $self->gift_voucher);
    $balance += $self->store_credit->{amount} if ( $self->store_credit);

    return $balance;

}

=head2 construct_basket_for_psp

  $AoH = $self->construct_basket_for_psp

Returns ArrayofHash containing all shipment_items,
shipping, store_credit and gift voucher.

=cut

sub construct_basket_for_psp {
    my $self = shift;

    my @basket;
    #push items in order - shipment_items, shipping, store credit and gift voucher
    push(@basket, $self->all_shipment_items );
    push(@basket, $self->shipping);
    push(@basket, $self->store_credit) if $self->store_credit;
    push(@basket, $self->gift_voucher) if $self->gift_voucher;

    return \@basket;
}

=head2 send_basket_to_psp

    $return = $self->send_basket_to_psp;

Does a call to PSP for updating basket. Return Success or error
response back.

=cut

sub send_basket_to_psp {
    my $self = shift;

    my $result = {};
    my $data = {
        reference   => $self->order->payments->first->preauth_ref,
        orderNumber => $self->order->order_nr,
        orderItems  => $self->construct_basket_for_psp,
    };
    my $response =  $self->domain_payment->payment_amendment($data);

    if( exists $response->{returnCodeResult} && $response->{returnCodeResult} == 1 ) {
        return 1;
    } else {
        my $extraReason = $response->{extraReason} // 'undef';
        my $psp_ref     = $response->{reference}   // 'undef';
        my $message = "Unable to update PSP with Basket for Order Number : ". $self->order->order_nr. " & reference: $psp_ref  due to reason : $extraReason ";
        $self->log->error( $message);
        die $message ;
    }

}

=head2 update_psp_with_item_changes

    $return = $self->update_psp_with_item_changes(
        [
            {orig_item_id => '123', new_item_id => '156'},
            {orig_item_id => '23', new_item_id => '6'},
            {orig_item_id => '3', new_item_id => '56'},
            ........
        ]
    );

Make a call to PSP with Exchange items data to update Basket changes.
Returns Success or error response back.

=cut

sub update_psp_with_item_changes {
    my $self        = shift;
    my $change_list = shift;

    die "No ARGS Array Ref passed to ". __PACKAGE__ ."::update_psp_with_item_changes"
        if ( ref($change_list) ne 'ARRAY');

    # if list is empty
    return 1 if @$change_list <= 0;

    my $replacement_data = $self->construct_item_replacement_data_for_psp( $change_list);

    # if nothing to send
    return 1 unless ( @$replacement_data > 0 );

    my $data = {
        reference    => $self->order->payments->first->settle_ref,
        orderNumber  => $self->order->order_nr,
        replacements => $replacement_data,
    };

    my $response =  $self->domain_payment->payment_replacement($data);

    if( exists $response->{returnCodeResult} && $response->{returnCodeResult} == 1 ) {
        return 1;
    } else {
        my $extraReason = $response->{extraReason} // 'undef';
        my $psp_ref     = $response->{reference}   // 'undef';
        my $message = "Unable to update PSP with Item changes for Order Number : ". $self->order->order_nr. " & reference: $psp_ref  due to reason : $extraReason ";
        $self->log->error( $message);
        croak $message ;
    }
}

=head2 construct_item_replacement_data_for_psp

Helper method to construct data struture for method
"update_psp_with_item_changes"

=cut

sub construct_item_replacement_data_for_psp {

    my $self = shift;
    my $change_list = shift;

    my @replacement_items;
    foreach my $list (@{ $change_list }) {
        my $original_si_id = $list->{orig_item_id};
        my $new_si_id      = $list->{new_item_id};
        if (!$self->shipment_item_exists_for_order($original_si_id)  || !$self->shipment_item_exists_for_order($new_si_id) ) {
            croak "Shipment item provided does not belong to same order";
        }

        my $original    = $self->get_shipment_item_data($self->get_shipment_item_for_order( $original_si_id) );
        my $replacement = $self->get_shipment_item_data($self->get_shipment_item_for_order( $new_si_id ));

        #delete quantity field
        delete($original->{quantity});
        delete($replacement->{quantity});

        # compare hash, if they are same, skip it.
        next if ( find_in_hash( $original,
            {
                sku     => $replacement->{sku},
                amount  => $replacement->{amount},
                vat     => $replacement->{vat},
                tax     => $replacement->{tax},
            }
        ));

        push(@replacement_items, {
            returnItem      => $original,
            replacementItem => $replacement,
        });

    }

    return \@replacement_items;
}

=head2 _format_in_pence

Helper method to return amount in pence.

    $amount  = _format_in_pence (10);

returns 1000.

=cut

sub _format_in_pence {
    my $amount  = shift;

    return sprintf( '%d', ( $amount * 100 ) );

}
