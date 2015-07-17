package Test::XTracker::Document::ReturnDeliveryForm;

use NAP::policy qw( class test );

use File::Basename;
use Test::Fatal;
use Test::File;

use Test::XT::Data;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
};

use XTracker::Document::ReturnDeliveryForm;
use XTracker::Printers::Populator;

=head1 NAME

Test::XTracker::Document::ReturnDeliveryForm;

=head1 TESTS

=cut

sub startup : Tests(startup) {
    my $self = shift;

    $self->{framework} = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Order',
            'Test::XT::Data::Return',
        ]
    );

    XTracker::Printers::Populator->new->populate_if_updated;
}

=head2 test_basic

For a return, it tries to print the return delivery form

=cut

sub test_basic : Tests {
    my $self = shift;

    my $expected_type = 'document';

    my $return   = $self->create_return;
    my $delivery = $self->get_delivery_for_return($return);

    my $document = XTracker::Document::ReturnDeliveryForm
        ->new( delivery_id => $delivery->id );

    is( $document->printer_type, $expected_type,
        'Document uses correct printer type' );

    lives_ok( sub {
        $document->print_at_location( $self->location_with_type($expected_type)->name );
    }, "Print document works ok" );

    my ($basename, $dirs) = fileparse($document->filename, qr{\.[^.]*});
    my @expected_files = (
        (map { "${basename}.${_}" } qw/html pdf/), # docs
        sprintf('delivery-%i.png', $delivery->id),
    );

    for my $file (map { $dirs . $_ } @expected_files) {
        file_exists_ok($file);
        file_not_empty_ok($file);
    }
}

=head2 test_failures

=cut

sub test_failures : Tests {
    my $self = shift;

    like(
        exception { XTracker::Document::ReturnDeliveryForm->new },
        qr{Attribute \(delivery\) is required at constructor},
        q{Can't build object without the delivery_id argument}
    );

    like(
        exception { XTracker::Document::ReturnDeliveryForm->new(
            delivery_id => 1+($self->schema->resultset('Public::Delivery')->get_column('id')->max||0)
        )},
        qr{Couldn't find delivery with id},
        q{Can't build document object with an nonexistent delivery_id}
    );

    my $delivery = $self->create_delivery_with_no_reuturn;

    like(
        exception { XTracker::Document::ReturnDeliveryForm->new(
            delivery_id => 1111,
            delivery    => $delivery,
        )},
        qr{Please define your object using only one},
        q{Can't build document object with two delivery arguments}
    );

    like(
        exception {
            XTracker::Document::ReturnDeliveryForm->new(
                delivery => $delivery,
            )
        },
        qr{No return associated with delivery id},
        q{Fails ok if no return is associated with the current delivery}
    )
}

sub create_delivery_with_no_reuturn {
    my $self = shift;

    my $product = (Test::XTracker::Data->grab_products({
        how_many => 1,
    }))[1][0]->{product};

    my $purchase_order = Test::XTracker::Data->setup_purchase_order($product->id);

    my ($delivery) = Test::XTracker::Data->create_delivery_for_po(
        $purchase_order->id,
        "qc", # doesn't really matter, we just need a delivery with no return associated
    );

    ok( $delivery, 'created delivery: %d' . $delivery->id );

    return $delivery;
}

sub create_return {
    my $self = shift;

    my $order_data = $self->{framework}->dispatched_order();

    my $return = $self->{framework}->booked_in_return( {
        shipment_id => $order_data->{shipment_id}
    });

    $return;
}

sub get_delivery_for_return {
    my ( $self, $return ) = @_;

    return $return->deliveries->single;
}