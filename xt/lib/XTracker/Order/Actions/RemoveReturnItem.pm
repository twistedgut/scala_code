package XTracker::Order::Actions::RemoveReturnItem;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Error qw(:DEFAULT);
use XTracker::Utilities qw( url_encode parse_url );

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $redirect = '/Home';

    # Remember whether IWS knows about shipment now, before we start cancelling shipment items
    my $schema = $handler->schema;
    my $return = $schema->resultset('Public::Return')->find( $handler->{param_of}->{return_id} );
    my $exchange_shipment = $return && $return->exchange_shipment;
    my $iws_knows = $exchange_shipment && $exchange_shipment->does_iws_know_about_me();

    my $stock_manager;
    my $cancel_exchange;
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
            if ( $form_key =~ m/selected-(\d+)/ ) {
                $handler->{data}{return_items}{ $1 }{ remove } = 1;
            }
        }

        $handler->{data}{$_} = $handler->{param_of}{$_}
            for qw/
                email_from email_replyto email_to email_subject email_body
                return_id refund_type_id
            /;
        $handler->{data}{send_email} = $handler->{param_of}{send_email} eq 'yes';

        $stock_manager = $schema->resultset('Public::Orders')
                                ->find($handler->{param_of}{order_id})
                                ->channel
                                ->stock_manager;

        $schema->txn_do(sub{
            $cancel_exchange = $handler->domain('Returns')->remove_items({
                %{$handler->{data}}, stock_manager => $stock_manager,
            });
            $stock_manager->commit;
        });
    };

    if ($@) {
        $stock_manager->rollback;

        $redirect = $short_url .'/Returns/RemoveItem?order_id='.$handler->{param_of}{order_id}.'&shipment_id='.$handler->{param_of}{shipment_id}.'&return_id='.$handler->{param_of}{return_id};

        xt_die("An error occurred whilst removing items from the return:<br />$@");

    }

    # Send messages to IWS now that we have committed transaction
    $handler->domain('Returns')->send_msgs_for_exchange_items( $exchange_shipment )
        if $cancel_exchange && $iws_knows;

    xt_success('Items removed successfully');
    $redirect = $short_url .'/Returns/View?order_id='.$handler->{param_of}{order_id}.'&shipment_id='.$handler->{param_of}{shipment_id}.'&return_id='.$handler->{param_of}{return_id};

    return $handler->redirect_to( $redirect );
}

1;
