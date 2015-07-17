package Test::XTracker::Document::Invoice;

use NAP::policy qw{ class test };

use File::Basename;

use Test::Fatal;
use Test::File;

use Test::XT::Flow;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
};

use XTracker::Constants::FromDB  qw(
    :renumeration_type
    :renumeration_class
    :renumeration_status
);

use XTracker::Document::Invoice;

use XTracker::Printers::Populator;


=head1 NAME

Test::XTracker::Document::Invoice

=head1 TESTS

=cut

sub startup : Tests(startup) {
    my $self = shift;

    $self->{framework} = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Order',
        ]
    );

    XTracker::Printers::Populator->new->populate_if_updated;
}

=head2 test_basic

Generates the invoice for a shipment

=cut

sub test_basic : Tests {
    my $self = shift;

    my $expected_type = 'document';

    my $shipment = $self->get_test_shipment;
    $self->set_shipment_renumeration($shipment);

    my $document = XTracker::Document::Invoice
        ->new( shipment => $shipment );

    is( $document->printer_type, $expected_type,
        'Document uses correct printer type' );

    lives_ok( sub {
        $document->print_at_location( $self->location_with_type($expected_type)->name );
    }, "Print document works ok" );

    my ($basename, $dirs) = fileparse($document->filename, qr{\.[^.]*});
    my @expected_files = (
        (map { "${basename}.${_}" } qw/pdf/), # docs
    );

    for my $file (map { $dirs . $_ } @expected_files) {
        file_exists_ok($file);
        file_not_empty_ok($file);
    }
}

=head2 test_failures

Test if we try and print with a nonexistent
shipment id

=cut

sub test_failures : Tests {
    my $self = shift;

    like(
        exception { XTracker::Document::Invoice->new() },
        qr{Attribute \(shipment\) is required at constructor},
        q{Can't build object without the shipment attribute}
    );

    like(
        exception {
            XTracker::Document::Invoice->new(
            shipment_id => 1+($self->schema->resultset('Public::Shipment')->get_column('id')->max||0)
        )},
        qr{Couldn't find shipment with id},
        q{Can't build document object for nonexistent shipment id}
    );

    like(
        exception {
            XTracker::Document::Invoice->new(
            shipment_id => 1,
            shipment    => $self->get_test_shipment,
        )},
        qr{Please define your object using only one of the .* arguments},
        q{Can't build document object with both arguments shipment/shipment_id defined}
    );
}

sub get_test_shipment {
    my $self = shift;

    my $order_data  = $self->{framework}->dispatched_order();
    my $shipment    = $order_data->{shipment_object};

    ok( $shipment, 'We have new shipment: ' . $shipment );

    return $shipment;
}


sub set_shipment_renumeration {
    my ( $self, $shipment ) = @_;

    # Create renumeration for the shipment
    my $num_invoices = $shipment->discard_changes
        ->renumerations
        ->count // 0;

    $num_invoices++;

    my $renumeration = $shipment->create_related( 'renumerations', {
        invoice_nr              => '',
        renumeration_type_id    => $RENUMERATION_TYPE__STORE_CREDIT,
        renumeration_class_id   => $RENUMERATION_CLASS__ORDER,
        renumeration_status_id  => $RENUMERATION_STATUS__PENDING,
        misc_refund             => 10 + $num_invoices,
        currency_id             => $shipment->order->currency_id,
    } );

    ok( $renumeration, 'Shipment renumeration created succesfully' );
}
