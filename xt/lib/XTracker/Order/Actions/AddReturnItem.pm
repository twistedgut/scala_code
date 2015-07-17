package XTracker::Order::Actions::AddReturnItem;
use strict;
use warnings;
use XTracker::Handler;
use XTracker::Utilities qw( url_encode parse_url );
use XTracker::Error qw/:DEFAULT/;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $redirect = '/Home';

    eval {
        # we need at least an order id and shipment id
        if ( !$handler->{param_of}{order_id} ) {
            die "No order id defined";
        }
        if ( !$handler->{param_of}{shipment_id} ) {
            die "No shipment_id defined";
        }
        if ( !$handler->{param_of}{return_id} ) {
            die "No return_id defined";
        }

        # loop over form post and get data for
        # return items into a format we can use
        foreach my $form_key ( %{ $handler->{param_of} } ) {
            if ( $form_key =~ m/selected-/ ) {
                my ($field_name, $shipment_item_id) = split /-/, $form_key;
                $handler->{data}{return_items}{ $shipment_item_id } = {
                    return           => 1,
                    type             => $handler->{param_of}{'type-'.$shipment_item_id},
                    exchange_variant => $handler->{param_of}{'exchange_variant-'.$shipment_item_id},
                    reason_id        => $handler->{param_of}{'reason_id-'.$shipment_item_id},
                    full_refund      => $handler->{param_of}{'full_refund-'.$shipment_item_id},
                    unit_price       => $handler->{param_of}{'unit_price-'.$shipment_item_id},
                    tax              => $handler->{param_of}{'tax-'.$shipment_item_id},
                    duty             => $handler->{param_of}{'duty-'.$shipment_item_id},
                };
            }
        }

        $handler->{data}{$_} = $handler->{param_of}{$_}
        for qw/
        email_from email_replyto email_to email_subject email_body
        return_id refund_type_id shipping_refund shipping_charge
        shipment_id
        /;
        $handler->{data}{send_email} = $handler->{param_of}{send_email} eq 'yes';

        my $guard = $handler->schema->txn_scope_guard;
        $handler->domain('Returns')->add_items($handler->{data});
        $guard->commit();

        xt_success('Items added successfully');
        $redirect = $short_url .'/Returns/View?order_id='.$handler->{param_of}{order_id}.'&shipment_id='.$handler->{param_of}{shipment_id}.'&return_id='.$handler->{param_of}{return_id};
    };
    if ($@) {
        $redirect = $short_url .'/Returns/AddItem?order_id='.$handler->{param_of}{order_id}.'&shipment_id='.$handler->{param_of}{shipment_id}.'&return_id='.$handler->{param_of}{return_id};
        xt_die("An error occurred whilst adding items to the return:<br />'$@");
    }


    return $handler->redirect_to( $redirect );
}

1;
