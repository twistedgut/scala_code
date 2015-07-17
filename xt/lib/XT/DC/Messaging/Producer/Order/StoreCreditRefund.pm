package XT::DC::Messaging::Producer::Order::StoreCreditRefund;
use NAP::policy "tt", 'class';
use Scalar::Util qw/blessed/;
use Carp;

use XTracker::Constants::FromDB qw( :renumeration_type :renumeration_class );
use XTracker::Constants         qw( :application );

with 'XT::DC::Messaging::Role::Producer';

use vars qw<$RENUMERATION_TYPE__VOUCHER_CREDIT>;

has '+type' => ( default => 'RefundRequestMessage' );
has '+destination' => ( default => 'overwritten_later' );

# Take a XT::Central::Schema::Public::PurchaseOrder
sub transform {
    my ($self, $header, $data )   = @_;

    my $renumeration    = $data->{renumeration};
    my $operator_id     = $data->{operator_id};

    confess __PACKAGE__ . "::transform needs a Public::Renumeration row"
        unless (blessed($renumeration) && $renumeration->isa('XTracker::Schema::Result::Public::Renumeration'));

    confess __PACKAGE__ . "::transform - renumeration must be store credit"
        unless $renumeration->renumeration_type_id == $RENUMERATION_TYPE__STORE_CREDIT;

    if ( !$operator_id ) {
        $operator_id    = $APPLICATION_OPERATOR_ID;
    }

    my @tenders;
    if ( $renumeration->renumeration_class_id != $RENUMERATION_CLASS__GRATUITY ) {

        # get the total invoice value for the store credit
        my $total_store_credit  = $renumeration->shipping +
                                  $renumeration->misc_refund +
                                  $renumeration->gift_credit +
                                  $renumeration->store_credit +
                                  $renumeration->total_value;

        my $renum_total     = 0;
        my $voucher_count   = 0;        # used to see if there are any vouchers used
        my $storecred_count = 0;        # used to count all types of credit
        my @voucher_codes;              # store the voucher codes used

        # if the Renumeration is not a Gratuity then look for 'renumeration_tenders'
        foreach ( $renumeration->renumeration_tenders->all ) {
            $renum_total    += $_->value;
            $storecred_count++;

            push @tenders, {
                '@type' => 'CustomerCreditRefundValueRequestDTO',
                refundValue => $_->value,
            };
            my $tender = $_->tender;
            if ( $tender->type_id == $RENUMERATION_TYPE__VOUCHER_CREDIT ) {
                $voucher_count++;
                push @voucher_codes, $tender->voucher_code->code;
                $tenders[-1]->{voucherCode} = $tender->voucher_code->code;
            }
        }

        # if there weren't any @tenders found then just get the total
        # from the renumeration and use that
        if ( !@tenders ) {
            push @tenders, {
                    '@type' => 'CustomerCreditRefundValueRequestDTO',
                    refundValue => $total_store_credit,
                };
        }
        elsif ( $renum_total > $total_store_credit ) {
            # if the renumeration tender value is greater than the invoice value
            # then use the store credit value. This shouldn't happen but does and
            # acts as a safety net.

            # Having spoken to James Witter about this if there are multiple Vouchers
            # or Mixed Voucher & Store Credit then make everything plain Store Credit
            # else if there is a single voucher only then use that Voucher. This is a
            # catch all scenario to help prevent excessive store credit being given
            # back to the customer

            carp "WARN StoreCreditRefund: Renumeration Tender gtr than Invoice: ".$renumeration->id.", $renum_total > $total_store_credit";

            # re-do the tenders
            @tenders    = (
                    {
                        '@type' => 'CustomerCreditRefundValueRequestDTO',
                        refundValue => $total_store_credit,
                    },
                );
            # we've only got one voucher and it is the only form of store credit used
            if ( ( $voucher_count == 1 ) && ( $storecred_count == 1 ) ) {
                $tenders[0]->{voucherCode}  = $voucher_codes[0];
            }
        }
    }
    else {
        # there won't be any 'renumeration_tenders' for 'Gratuity' Store Credits
        # so just mock up one '@tenders' with the total amount requested
        my $total_store_credit  = 0;
        # add 'shipping' and 'misc_refund' to total
        $total_store_credit = $renumeration->shipping +
                              $renumeration->misc_refund;
        # add all the 'renumeration_items' to the total
        $total_store_credit += $renumeration->total_value;

        # set up the 'tender' for the PWS
        push @tenders, {
                '@type' => 'CustomerCreditRefundValueRequestDTO',
                refundValue => $total_store_credit,
            };
    }

    my $order = $renumeration->shipment->order;

    my $cust_id = $order->customer->is_customer_number;
    if ( $renumeration->alt_customer_nr ) {
        $cust_id    = $renumeration->alt_customer_nr;
    }

    my $msg = {
        '@type' => 'CustomerCreditRefundRequestDTO',
        orderId      => $order->order_nr,
        customerId   => $cust_id,
        createdBy    => 'xt-'.$operator_id,
        refundCurrency=> $renumeration->currency->currency,
        refundValues => \@tenders,
    };
    if ( $renumeration->renumeration_class_id == $RENUMERATION_CLASS__GRATUITY ) {
        $msg->{notes}   = "Gratuity";
    }
    $header->{destination} = $order->channel->web_name;

    return (
        $header,
        $msg
    );
}

1;
