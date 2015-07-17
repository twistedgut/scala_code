package Test::XTracker::Document::MeasurementForm;

use NAP::policy qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
}

use Test::Fatal;

use XTracker::Document::MeasurementForm;

use Test::XTracker::Data;

=head1 NAME

Test::XTracker::Document::MeasurementForm

=cut

sub test_basic : Tests {
    my $self = shift;

    my $product = (
        Test::XTracker::Data->grab_products({force_create => 1})
    )[1][0]{product};
    my $expected_type = 'document';

    my $measurement_form
        = XTracker::Document::MeasurementForm->new(product_id => $product->id);

    is( $measurement_form->printer_type, $expected_type,
        'measurement form uses correct printer type' );

    lives_ok( sub {
        $measurement_form->print_at_location(
            $self->location_with_type($expected_type)->name
        );
    }, "didn't die printing measurement form" );
}

sub test_failures : Tests {
    my $self = shift;

    like(
        exception { XTracker::Document::MeasurementForm->new },
        qr{\QAttribute (product_id) is required},
        'instantiating class without product_id should die'
    );
    like(
        exception { XTracker::Document::MeasurementForm->new(product_id => 'foo') },
        qr{\Qfoo},
        'instantiating class with non-integer product_id should die'
    );
    like(
        exception { XTracker::Document::MeasurementForm->new(
            product_id => ($self->schema->resultset('Public::Product')->get_column('id')->max//0)+1
        )},
        qr{\QCouldn't find product},
        'instantiating class with inexistent product_id should die'
    );
}
