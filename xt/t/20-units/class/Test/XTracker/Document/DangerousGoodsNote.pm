package Test::XTracker::Document::DangerousGoodsNote;

use NAP::policy qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
}

use Test::Fatal;

use Test::XT::Data;

use XTracker::Constants::FromDB ':ship_restriction';
use XTracker::Document::DangerousGoodsNote;

=head1 NAME

Test::XTracker::Document::DangerousGoodsNote

=cut

sub test_basic : Tests {
    my $self = shift;

    my $expected_type = 'document';

    my $shipment = $self->create_shipment;
    $self->make_product_hazmat_lq(
        $shipment->shipment_items->first->variant->product
    );
    my $dgn = XTracker::Document::DangerousGoodsNote->new(
        shipment_id   => $shipment->id,
        operator_name => 'Bobby Tables',
    );

    is( $dgn->printer_type, $expected_type,
        'dangerous goods note uses correct printer type' );

    lives_ok( sub {
        $dgn->print_at_location($self->location_with_type($expected_type)->name);
    }, "didn't die printing dangerous goods note" );
}

sub create_shipment {
    my $self = shift;

    return Test::XT::Data->new_with_traits(traits => 'Test::XT::Data::Order')
        ->packed_order->{shipment_object};
}

sub make_product_hazmat_lq {
    my ( $self, $product ) = @_;
    $product->create_related( link_product__ship_restrictions => {
        ship_restriction_id => $SHIP_RESTRICTION__HZMT_LQ
    });
}

sub test_failures : Tests {
    my $self = shift;

    like(
        exception {
            XTracker::Document::DangerousGoodsNote->new(operator_name => 'Little Bobby')
        },
        qr{\QAttribute (shipment) is required},
        'should die if shipment_id not provided'
    );

    my $shipment = $self->create_shipment;
    like(
        exception {
            XTracker::Document::DangerousGoodsNote->new(shipment_id => $shipment->id)
        },
        qr{operator_name},
        'should die if operator_name not provided'
    );
    like(
        exception { XTracker::Document::DangerousGoodsNote->new(
            shipment_id   => $shipment->id,
            shipment      => $shipment,
            operator_name => 'Big Bobby',
        ) },
        qr{Please define your object},
        'should die if both shipment and shipment_id passed'
    );
    like(
        exception { XTracker::Document::DangerousGoodsNote->new(
            shipment_id => ($shipment->result_source->resultset->get_column('id')->max//0)+1,
            operator_name => 'Big Bobby',
        ) },
        qr{\QCouldn't find shipment with id},
        'should die if inexistent shipment_id passed'
    );
}
