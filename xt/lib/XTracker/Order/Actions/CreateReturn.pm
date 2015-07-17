package XTracker::Order::Actions::CreateReturn;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Error;
use XTracker::Utilities qw(
  url_encode parse_url
);

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $redirect = '/Home';
    my $return_id;

    my $param_of = $handler->{param_of};
    eval {

        # we need at least an order id and shipment id
        die "No order id defined" unless $param_of->{order_id};
        die "No shipment_id defined" unless $param_of->{shipment_id};

        $handler->{data}{$_} = $param_of->{$_}
            for qw/
                email_from email_replyto email_to email_subject email_body
                rma_number refund_type_id notes shipping_refund shipping_charge
                shipment_id alt_customer_nr
            /;

        $handler->{data}{send_email} = $param_of->{send_email} eq 'yes' if (exists $param_of->{send_email} );

        # loop over form post and get data for
        # return items into a format we can use
        foreach my $form_key ( %{ $param_of } ) {
            if ( $form_key =~ m/selected-/ ) {
                my ($field_name, $shipment_item_id) = split /-/, $form_key;
                $handler->{data}{return_items}{$shipment_item_id} = {
                    return           => 1,
                    type             => $param_of->{'type-'.$shipment_item_id},
                    exchange_variant => $param_of->{'exchange_variant-'.$shipment_item_id},
                    reason_id        => $param_of->{'reason_id-'.$shipment_item_id},
                    full_refund      => $param_of->{'full_refund-'.$shipment_item_id},
                    #unit_price       => $param_of->{'unit_price-'.$shipment_item_id},
                    #tax              => $param_of->{'tax-'.$shipment_item_id},
                    #duty             => $param_of->{'duty-'.$shipment_item_id},
                };
            }
        }
        $handler->{data}{pickup} = $param_of->{pickup} || 'false';

        my $return;
        $handler->schema->txn_do( sub {
            my $return_domain = $handler->domain('Returns');
            $return = $return_domain->create($handler->{data});
        });

        # Note: We allocate the shipment outside the transaction because
        # we need to ensure that the allocation will be available to the
        # amq consumer when it receives an allocate_response message.
        # See DCA-1458 for a better future plan.
        if ($return && $return->exchange_shipment) {
            $return->exchange_shipment->allocate({
                factory => $handler->msg_factory,
                operator_id => $handler->{data}{operator_id}
            });
        }

    };
    if (my $e = $@) {
        xt_warn("An error occurred whilst creating the return:\n$e");
        $redirect = "$short_url/Returns/View"
                  . "?order_id=$param_of->{order_id}"
                  . "&shipment_id=$param_of->{shipment_id}";
    }
    else {
        xt_success('Return created successfully');
        $redirect = "$short_url/Returns/View"
                  . "?order_id=".($param_of->{order_id}||"")
                  . "&shipment_id=".($param_of->{shipment_id}||"")
                  . "&return_id=".($return_id||"");
    }
    return $handler->redirect_to( $redirect );
}

1;
