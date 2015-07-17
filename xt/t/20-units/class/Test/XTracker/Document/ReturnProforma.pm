package Test::XTracker::Document::ReturnProforma;

use NAP::policy qw{ class test };

use File::Basename;

use Test::Fatal;
use Test::File;

use Test::XT::Data;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
};

use XTracker::Document::ReturnProforma;

use XTracker::Printers::Populator;


=head1 NAME

Test::XTracker::Document::ReturnProforma

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

Generates the return proforma for a shipment

=cut

sub test_basic : Tests {
    my $self = shift;

    my $expected_type = 'document';

    my $shipment = $self->get_test_shipment;

    my $document = XTracker::Document::ReturnProforma
        ->new( shipment => $shipment );

    is( $document->printer_type, $expected_type,
        'Document uses correct printer type' );

    lives_ok( sub {
        $document->print_at_location( $self->location_with_type($expected_type)->name );
    }, "Print document works ok" );

    my ($basename, $dirs) = fileparse($document->filename, qr{\.[^.]*});
    my @expected_files = (
        (map { "${basename}.${_}" } qw/pdf/),
        sprintf('proOrder%s.png', $shipment->id)
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
        exception { XTracker::Document::ReturnProforma->new() },
        qr{Attribute \(shipment\) is required at constructor},
        q{Can't build object without the shipment attribute}
    );

    like(
        exception {
            XTracker::Document::ReturnProforma->new(
            shipment_id => 1+($self->schema->resultset('Public::Shipment')->get_column('id')->max||0)
        )},
        qr{Couldn't find shipment with id},
        q{Can't build document object for nonexistent shipment id}
    );

    like(
        exception {
            XTracker::Document::ReturnProforma->new(
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

    ok( $shipment, 'We have new shipment: ' . $shipment->id );

    my ( $out_awb, $ret_awb ) = Test::XTracker::Data->generate_air_waybills;

    ok( $ret_awb, 'Return awb generated');

    # Set outward airway bill to the current shipment
    $shipment->update( { return_airway_bill => $ret_awb } );

    return $shipment;
}
