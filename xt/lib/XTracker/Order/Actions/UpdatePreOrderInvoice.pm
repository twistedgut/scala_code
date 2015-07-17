package XTracker::Order::Actions::UpdatePreOrderInvoice;

use strict;
use warnings;
use XTracker::Handler;

use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :renumeration_class :renumeration_status :renumeration_type :shipment_status );
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $schema      = $handler->{schema};

    # set up vars and get query string data
    my $invalid_msg     = '';
    my $renum_id        = 0;
    my $total_renum     = 0;
    my $preorder_id     = $handler->{param_of}{preorder_id};
    my $invoice_id      = $handler->{param_of}{invoice_id};
    my $redirect_url    = $short_url.'/PreOrderInvoice?invoice_id='.$invoice_id.'&preorder_id='.$preorder_id;
    my $status_id       = $handler->{param_of}{status_id};


    if( $status_id =~ /novalue/ ) {
        xt_error ('Choose Status' );
        $redirect_url .= '&action=Edit';
    }

    my $preorder_refund = $schema->resultset('Public::PreOrderRefund')
                                  ->find($invoice_id);

    eval {
        $schema->txn_do ( sub {
            $preorder_refund->update_status($status_id, $handler->{data}{operator_id});
        });
    };

        if (my $err = $@) {
        xt_warn($err);
        $redirect_url .= '&action=Edit';
    }
    else {
        xt_success('Invoice updated successfully.');
        $redirect_url .= '&action=View';
    }


    return $handler->redirect_to( $redirect_url );
}

1;

