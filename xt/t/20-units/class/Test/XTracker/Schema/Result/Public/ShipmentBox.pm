package Test::XTracker::Schema::Result::Public::ShipmentBox;

use FindBin::libs;
use parent "NAP::Test::Class";
use NAP::policy "tt", 'test';

use XTracker::Constants ':application';
use XTracker::Schema::Result::Public::ShipmentBox;

use Test::MockModule;
use Test::XTracker::Data;

sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup;
    $self->{order_factory} = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ]
    );
}

sub test_log_action : Tests() {
    my $self = shift;

    my ($shipment, $shipment_box);
    subtest 'create packed shipment' => sub {
        my @products = Test::XTracker::Data->create_test_products({how_many => 2 });
        my @vouchers = (Test::XTracker::Data->grab_products(
            { phys_vouchers => { how_many => 1, want_stock => 1, } }
        ))[1][1]{product};
        $shipment = $self->create_packed_shipment([@products, @vouchers]);
        # Sanity check - test all expected items are in the box
        $shipment_box = $shipment->shipment_boxes->single;
        ok(
            $_->id ~~ [
                map { $_->get_true_variant->product_id }
                $shipment_box->shipment_items->all
            ],
            sprintf( 'found expected %s (id %i) in box',
                ($_->is_voucher ? 'voucher' : 'product'), $_->id
            )
        ) for @products, @vouchers
    };

    my $action = 'test_action';
    my $operator_id = $APPLICATION_OPERATOR_ID;

    # Check our argument count
    throws_ok(
        sub { $shipment_box->log_action($action) }, qr{but 2 were expected},
        'log_action expects an operator_id'
    );

    # Check our logged data
    my $log = $shipment_box->log_action($action, $operator_id)->discard_changes;
    isa_ok( $log, 'XTracker::Schema::Result::Public::ShipmentBoxLog' );

    is( $log->shipment_box_id, $shipment_box->id, 'shipment_box_id logged ok' );
    is( $log->action, $action, 'action logged ok' );
    is( $log->operator_id, $operator_id, 'operator_id logged ok' );
    isa_ok( $log->timestamp, 'DateTime' );
    isa_ok( $log->skus, 'ARRAY', 'skus logged as array' );
    eq_or_diff(
        $log->skus,
        [
            map { $_->get_true_variant->sku }
            # The order_by clause is just here to provide a predictable order -
            # just make sure it matches the app code
            $shipment_box->search_related('shipment_items', {}, { order_by => 'id' })->all
        ],
        'correct skus logged'
    );
}

# As labelling is now in the model, we should probably move all our mech tests
# that test label printouts here too... pretty sure we'd see some nice
# performance improvements
sub test_label : Tests() {
    my $self = shift;

    my $shipment;
    subtest 'create packed shipment' => sub {
        my @product = Test::XTracker::Data->create_test_products;
        $shipment = $self->create_packed_shipment(\@product);
    };

    my $shipment_box = $shipment->shipment_boxes->single;

    my $operator_id = $APPLICATION_OPERATOR_ID;
    # TODO: Paperwork tests - for the moment just hack a simple return
    {
        # Override print_shipment_documents - note the namespace isn't what
        # you'd expected as the application code doesn't fully qualify the
        # subroutine
        my $module = Test::MockModule->new('XTracker::Schema::Result::Public::ShipmentBox');
        $module->mock('print_shipment_documents', sub { return 1; });
        $shipment_box->label(operator_id => $operator_id);
    }

    # Check we create a log entry....
    isa_ok( (my $log = $shipment_box->shipment_box_logs->single),
        'XTracker::Schema::Result::Public::ShipmentBoxLog' );

    # ... and that the required fields are correct
    is( $log->action, 'Labelled', 'action logged ok' );
    is( $log->operator_id, $operator_id, 'operator_id logged ok' );

}

sub create_packed_shipment {
    my ( $self, $products ) = @_;
    croak '$products has to be an array ref'
        unless ref $products && ref $products eq 'ARRAY';
    isa_ok(
        my $shipment = $self->{order_factory}->packed_order(
            products => $products
        )->{order_object}->get_standard_class_shipment,
        'XTracker::Schema::Result::Public::Shipment'
    );
    return $shipment;
}
