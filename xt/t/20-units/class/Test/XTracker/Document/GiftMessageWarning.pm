package Test::XTracker::Document::GiftMessageWarning;

use NAP::policy qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
}

use Test::Fatal;

use Test::XT::Data;

use XTracker::Document::GiftMessageWarning;

=head1 NAME

Test::XTracker::Document::GiftMessageWarning

=head1 TESTS

=head2 test_initialisation_and_printing

A high-level test that intitialises our gift message warning objects with
different combinations and tests success/failures.

=cut

sub test_initialisation_and_printing : Tests {
    my $self = shift;

    my $shipment = $self->create_shipment;
    my $shipment_item = $shipment->shipment_items->single;

    # A few tests to check we behave correctly. Note that we *don't* test the
    # contents of the document.
    for my $test_args (
        {
            test_name => 'no gift messages',
            init_args => { shipment_id => $shipment->id },
            error     => qr{\QAttribute (gift_message},
        },
        {
            test_name             => 'shipment gift message warning',
            init_args             => { shipment_id => $shipment->id },
            shipment_gift_message => 'foo',
        },
        {
            test_name                  => 'shipment item gift message warning',
            init_args                  => { shipment_item_id => $shipment_item->id },
            shipment_item_gift_message => 'foo',
        },
        {
            test_name => 'both gift messages',
            init_args => {
                shipment_id      => $shipment->id,
                shipment_item_id => $shipment_item->id,
            },
            error => qr{One of shipment_id or shipment_item_id},
        },
    ) {
        $self->set_gift_message(@$_)
            for [$shipment,      $test_args->{shipment_gift_message}],
                [$shipment_item, $test_args->{shipment_item_gift_message}];

        # A better test might check *when* the failures occur too... but this
        # is probably ok for now
        my $exception = exception {
            my $gmw = XTracker::Document::GiftMessageWarning->new(
                %{$test_args->{init_args}}
            );
            $gmw->print_at_location(
                $self->location_with_type(expected_printer_type())->name
            );
        };
        if ( my $error = $test_args->{error} ) {
            like( $exception, $error, "should die printing $test_args->{test_name}" );
        }
        else {
            is( $exception, undef, "should live printing $test_args->{test_name}" );
        }
    }
}

=head2 test_printer_type

Test the printer_type for this document object.

=cut

sub test_printer_type : Tests {
    is(
        XTracker::Document::GiftMessageWarning::build_printer_type(),
        expected_printer_type(),
        'gift message warning printer type ok'
    );
}

sub expected_printer_type { 'document' }

sub create_shipment {
    my $self = shift;

    return Test::XT::Data->new_with_traits(traits => 'Test::XT::Data::Order')
        ->packed_order->{shipment_object};
}

# $object needs to have a column called gift_message (i.e. it can be a shipment
# or a shipment_item DBIC row)
sub set_gift_message {
    my ( $self, $object, $gift_message ) = @_;
    $object->update({gift_message => $gift_message});
}
