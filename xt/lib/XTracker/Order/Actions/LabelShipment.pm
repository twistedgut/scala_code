package XTracker::Order::Actions::LabelShipment;

use strict;
use warnings;

use URI;

use XTracker::Handler;
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $box_number       = $handler->{param_of}{box_number};
    my $document_printer = $handler->{param_of}{document_printer};
    my $label_printer    = $handler->{param_of}{label_printer};
    my $premier_printer  = $handler->{param_of}{premier_printer};
    my $card_printer     = $handler->{param_of}{card_printer};

    my $redirect         = URI->new('/Fulfilment/Labelling');

    # let's be helpful and remember their printer choices even if they forget to
    # enter a box number
    if ( $document_printer && $label_printer && $premier_printer && $card_printer ) {
        $redirect->query_form(
            document_printer => $document_printer,
            label_printer    => $label_printer,
            premier_printer  => $premier_printer,
            card_printer     => $card_printer,
        );
    }

    # form submitted without box number NOTE: Shouldn't we error?
    return $handler->redirect_to( $redirect ) unless $box_number;

    my $schema = $handler->schema;

    my ($box_id, $box_size_id) = split /-/, $box_number;
    my $box = $schema->resultset('Public::ShipmentBox')->find($box_id);
    if (!$box) {
        xt_warn( "Unknown box id $box_number" );
        return $handler->redirect_to( $redirect );
    }

    eval {
        $box->label({
            premier_printer  => $premier_printer,
            card_printer     => $card_printer,
            document_printer => $document_printer,
            label_printer    => $label_printer,
            operator_id      => $handler->operator_id,
        });
        $redirect->query_form(
            shipment_id      => $box->shipment_id,
            document_printer => $document_printer,
            label_printer    => $label_printer,
            premier_printer  => $premier_printer,
            card_printer     => $card_printer,
        );
    };
    if ($@) {
        xt_warn("An error occured whilst trying to label this shipment: $@");
    }

    return $handler->redirect_to( $redirect);
}

1;
