package XTracker::Order::Actions::CancelReturn;

use strict;
use warnings;

use URI;

use XTracker::Handler;

use XTracker::Utilities qw( parse_url );
use XTracker::Error;
use XT::Warehouse;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    # set up vars and get form data
    my $data = {
        return_id     => $handler->clean_param('return_id'),
        send_email    => $handler->clean_param('send_email'),
        email_to      => $handler->clean_param('email_to'),
        email_from    => $handler->clean_param('email_from'),
        email_replyto => $handler->clean_param('email_replyto'),
        email_subject => $handler->clean_param('email_subject'),
        email_body    => $handler->clean_param('email_body'),
        operator_id   => $handler->operator_id,
    };

    my $uri = URI->new("$short_url/Returns/View");

    # process the cancellation
    my $stock_manager;
    eval {
        # we need at least a return id
        if ( !$data->{return_id} ) {
            die "No return id defined";
        }

        delete $data->{send_email} unless $data->{send_email} eq 'yes';

        my $schema = $handler->schema;
        my $return = $schema->resultset('Public::Return')->find($data->{return_id});
        $stock_manager = $return->shipment->get_channel->stock_manager;

        my $warehouse = XT::Warehouse->instance;
        my $exchange = $return->exchange_shipment;
        my $does_iws_know_about_exchange = $exchange
            && ($warehouse->has_iws || $warehouse->has_ravni)
            && $exchange->does_iws_know_about_me;

        $schema->txn_do(sub{
            $handler->domain('Returns')->cancel({
                %$data, stock_manager => $stock_manager
            });
            $stock_manager->commit;
        });
        # Do this outside the transaction (see
        # XTracker::Schema::Result::Public::Shipment::cancel)
        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::ShipmentCancel',
            { shipment_id => $exchange->id }
        ) if $does_iws_know_about_exchange;

        xt_success('Return cancelled successfully.');
    };
    if ($@) {
        $stock_manager->rollback if $stock_manager;
        xt_warn("An error occured whilst trying to cancel the return: $@");
        $uri = URI->new("$short_url/Returns/Cancel");
    }

    $uri->query_form(
        map { $_ => $handler->clean_param($_) } qw/order_id shipment_id return_id/
    );
    return $handler->redirect_to( $uri );
}

1;
