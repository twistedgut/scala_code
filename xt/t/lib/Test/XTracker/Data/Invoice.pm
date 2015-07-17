package Test::XTracker::Data::Invoice;

use NAP::policy "tt",     qw( class test );

=head1 NAME

Test::XTracker::Data::Invoice

=head1 SYNOPSIS

Helpers in relation to Invoices or Renumerations which ever you refer to them as.

=cut

use Test::XTracker::Data;

use XTracker::Constants::FromDB     qw(
                                        :renumeration_type
                                        :renumeration_class
                                        :renumeration_status
                                    );


=head1 METHODS

=head2 create_invoice

    my $renumeration_obj = __PACKAGE__->create_invoice( {
        shipment        => $dbic_shipment_obj,
        type_id         => $renumeration_type_id,       # defaults to 'Store Credit'
        class_id        => $renumeration_class_id,      # defaults to 'Gratuity'
        status_id       => $renumeration_status_id,     # defaults to 'Pending'
        reason_id       => $renumeration_reason_id,     # optional
    } );

Will create a Renumeration record or Invoice for a Shipment, it will assign a value
to the 'misc_refund' field of 10 + ( number for shipment invoices + 1 ).

At the moment it won't create any Renumeration Items, please feel free to add this.

=cut

sub create_invoice {
    my ( $self, $args ) = @_;

    my $shipment    = $args->{shipment};

    my $num_invoices    = $shipment->discard_changes
                                    ->renumerations
                                        ->count // 0;
    $num_invoices++;

    my $renumeration = $shipment->create_related( 'renumerations', {
        invoice_nr              => '',
        renumeration_type_id    => $args->{type_id}     || $RENUMERATION_TYPE__STORE_CREDIT,
        renumeration_class_id   => $args->{class_id}    || $RENUMERATION_CLASS__GRATUITY,
        renumeration_status_id  => $args->{status_id}   || $RENUMERATION_STATUS__PENDING,
        misc_refund             => 10 + $num_invoices,
        currency_id             => $shipment->order->currency_id,
        renumeration_reason_id  => $args->{reason_id},
    } );

    return $renumeration->discard_changes;
}

1;
