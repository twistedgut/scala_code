package Test::NAP::ShippingDocuments;

use NAP::policy "tt", 'test';

use Encode;
use FindBin::libs;
use parent 'NAP::Test::Class';

use XTracker::Constants::FromDB ':branding';
use XTracker::Database::Currency 'get_local_conversion_rate';
use XTracker::Order::Printing::ShippingInputForm 'generate_input_form';

use Test::XT::Data;
use Test::XTracker::PrintDocs;

sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{order_helper} = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ]
    );
    $self->{schema} = Test::XTracker::Data->get_schema;
}

# The aim of this test is to move all document testing from
# t/30-aspects/packing/shipping_docs.t to here (it's a mechanise test!)... if
# you extend this test, consider removing the other one if you feel there's
# enough coverage here. What's currently still missing:
# - Test for physical vouchers
# - Test for virtual vouchers
# - Fish & wildlife
# - Totals
# - Shipment with multiple same sku items
# - ... probably some other stuff too
sub test_shipping_input_form : Tests {
    my $self = shift;

    for (
        [ 'standard shipment', ],
        [ 'shipment with hazmat restriction', ['AEROSOL'] ],
    ) {
        my ( $test_name, $restrictions ) = @$_;

        subtest $test_name => sub {
            isa_ok(
                my $shipment = $self->{order_helper}
                    ->picked_order->{order_object}->get_standard_class_shipment,
                'XTracker::Schema::Result::Public::Shipment'
            );

            # Set restrictions
            my @ship_restrictions
                = $self->{schema}->resultset('Public::ShipRestriction')
                                 ->search({code => $restrictions});
            my $product = $shipment->shipment_items
                                   ->slice(0,0)
                                   ->single
                                   ->get_true_variant
                                   ->product;
            # Would've done an ok here, but it looks like set_$rel returns
            # nothing
            lives_ok(
                sub {
                    $product->set_ship_restrictions( \@ship_restrictions ),
                },
                sprintf 'added %s restriction(s) to pid %i',
                    join( q{, }, map { q{'} . $_->title . q{'} } @ship_restrictions ),
                    $product->id
            ) if @{$restrictions||[]};

            my $monitor = Test::XTracker::PrintDocs->new;
            generate_input_form($shipment->id, 'Shipping');

            my @files = $monitor->new_files;
            is( @files, 1, 'found 1 file' );
            my $file = $files[0];
            is( $file->file_type, 'shippingform', 'file type is shippingform' );

            my $data = $file->as_data;
            subtest 'test shipment details' => sub {
                $self->_test_shipping_input_form_shipment_details( $shipment, $data->{shipment_details} );
            };

            subtest 'test shipment item details' => sub {
                $self->_test_shipping_input_form_shipment_items( $shipment, $data->{shipment_items} );
            };
        };
    }
}

sub _test_shipping_input_form_shipment_details {
    my ( $self, $shipment, $data ) = @_;

    # TODO: Box size/address tests
    my %fields = (
        #'Box Size(s)' => ''
        'Customer Category' => sub {
            my $category = shift->order->customer->category->category;
            $category eq 'None' ? q{-} : $category;
        },
        'Customer Number' => sub { shift->order->customer->is_customer_number; },
        'Mobile Telephone' => sub { shift->mobile_telephone; },
        'Number of Boxes' => sub { shift->shipment_boxes->count; },
        'Order Number' => sub { shift->order->order_nr; },
        'Sales Channel' => sub {
            shift->order->channel->channel_brandings->find({branding_id => $BRANDING__PF_NAME})->value;
        },
        'Shipment Number' => sub { shift->id },
        'Shipping Account' => sub {
            join q{ - }, map { $_->carrier->name, $_->shipping_account->name } shift;
        },
        'Shipping Details' => sub { shift->shipment_address->full_name; },
        'Shipping Type' => sub {
            shift->shipping_charge_table->shipping_charge_class->class;
        },
        'Telephone' => sub { shift->telephone; },
#        'Unknown' => ARRAY(0x2373cc08)
#            0  ''
#            1  '725 Darlington Avenue, Mahwah, NJ'
#            2  'New Jersey'
#            3  'NY'
#            4  'United States'
#            5  11371
    );

    is( decode_utf8($data->{$_}), $fields{$_}($shipment), "$_ ok" )
        for sort keys %fields;
}

sub _test_shipping_input_form_shipment_items {
    my ( $self, $shipment, $data ) = @_;

    my %fields = (
        country_of_origin => sub {
            shift->first->product->shipping_attribute->country->country;
        },
        description => sub {
            my $product = shift->first->product;
            $product->designer->designer . $product->product_attribute->name;
        },
        # TODO: Extend to include fish & wildlife item text
        fabric_content => sub {
            my $product = shift->first->product;
            join q{ },
                $product->shipping_attribute->fabric_content//q{},
                ( $product->has_ship_restriction('HAZMAT') ? 'HAZMAT ITEM' : () );
        },
        hs_code => sub {
            shift->first->product->hs_code->hs_code;
        },
        qty => sub { shift->count; },
        sku => sub { shift->first->get_true_variant->sku; },
        sub_total => sub {
            my $shipment_item_rs = shift;
            # To avoid rounding errors we use the same, slightly awkward,
            # two-call method to sprintf
            sprintf( '%.2f',
                $self->_converted_item_unit_price($shipment_item_rs->first)
              * $shipment_item_rs->count
            );
        },
        unit_price => sub { $self->_converted_item_unit_price(shift->first); },
        weight => sub {
            shift->first->product->shipping_attribute->weight;
        },
    );
    for my $row ( @{$data->{items}} ) {
        # Strictly speaking we should also filter by status (e.g. no cancel
        # pending/cancelled items)... will let someone extend this as required
        my $shipment_item_rs = $shipment->shipment_items->search_by_sku(
            $row->{sku}
        );

        # TODO: We maybe need another ticket so our printdocs get decoded -
        # this line should live doc parser, not here :(
        is( decode_utf8($row->{$_}), $fields{$_}($shipment_item_rs), "$_ ok" )
            for sort keys %fields;
    }

    # TODO: Test totals
}

sub _converted_item_unit_price {
    my ( $self, $shipment_item ) = @_;

    # We need this to work out prices
    my $conversion_rate = get_local_conversion_rate(
        $self->{schema}->storage->dbh, $shipment_item->shipment->order->currency_id
    );
    return sprintf '%.2f', $shipment_item->unit_price * $conversion_rate;
}
