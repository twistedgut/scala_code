package Test::XTracker::Order::Printing::PickingList;

use FindBin::libs;
use NAP::policy "tt", 'test';

use Test::XTracker::RunCondition iws_phase => 0, prl_phase => 0;

use parent 'NAP::Test::Class';

use Test::XTracker::Data;;
use Test::XTracker::PrintDocs;

use XTracker::Constants::FromDB ':flow_status';
use XTracker::Order::Printing::PickingList;

=head1 NAME

Test::XTracker::Order::Printing::PickingList

=head1 METHODS

=cut

sub startup : Tests {
    my $self = shift;
    $self->{order_factory} = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ]
    );
}

=head2 test_one_item_one_quantity_in_one_location

=cut

sub test_one_item_one_quantity_in_one_location : Tests {
    my $self = shift;

    my $product = (Test::XTracker::Data
        ->grab_products({ force_create => 1, how_many_variants => 1})
        )[1][0]{product};

    my $shipment = $self->create_shipment([$product]);

    my $quantities = $self->add_quantities($product->variants->first, 1);

    my $pick_sheet = $self->get_pick_sheet($shipment->id);

    for my $picked_row (@{$pick_sheet->as_data->{item_list}}) {
        is( $picked_row->{Location}, $quantities->[0]->location->location,
            'should match expected pick sheet location' );
    }
}

=head2 test_two_items_one_quantity

=cut

sub test_two_items_one_quantity : Tests {
    my $self = shift;

    my $product = (Test::XTracker::Data
        ->grab_products({ force_create => 1, how_many_variants => 1})
        )[1][0]{product};

    my $shipment = $self->create_shipment([($product) x 2]);

    my $quantities = $self->add_quantities($product->variants->single, 1);

    my $pick_sheet = $self->get_pick_sheet($shipment->id);

    for my $picked_row (@{$pick_sheet->as_data->{item_list}}) {
        is( $picked_row->{Location}, $quantities->[0]->location->location,
            'should match expected pick sheet location' );
    }
}

=head2 test_one_item_one_quantity_already_selected

=cut

sub test_one_item_one_quantity_already_selected : Tests {
    my $self = shift;

    my $product = (Test::XTracker::Data
        ->grab_products({ force_create => 1, how_many_variants => 1})
        )[1][0]{product};

    # Make sure we have a selected item for the given sku
    $self->{order_factory}->selected_order(products => [$product]);

    # Select our shipment, and make sure we have just one quantity (which is
    # already selected)
    my $shipment = $self->create_shipment([$product]);

    my $quantities = $self->add_quantities($product->variants->single, 1);

    my $pick_sheet = $self->get_pick_sheet($shipment->id);

    for my $picked_row (@{$pick_sheet->as_data->{item_list}}) {
        is( $picked_row->{Location}, 'Unknown',
            'should get Unknown as our only item is already selected' );
    }
}

=head2 test_one_item_two_quantities_one_already_selected

=cut

sub test_one_item_two_quantities_one_already_selected : Tests {
    my $self = shift;

    my $product = (Test::XTracker::Data
        ->grab_products({ force_create => 1, how_many_variants => 1})
        )[1][0]{product};

    # Make sure we have a selected item for the given sku
    $self->{order_factory}->selected_order(products => [$product]);

    # Select our shipment, and make sure we have just one quantity (which is
    # already selected)
    my $shipment = $self->create_shipment([$product]);

    my $quantities = $self->add_quantities($product->variants->single, 2);

    my $pick_sheet = $self->get_pick_sheet($shipment->id);

    for my $picked_row (@{$pick_sheet->as_data->{item_list}}) {
        is( $picked_row->{Location}, $quantities->[0]->location->location,
            'should match expected pick sheet location' );
    }
}

=head2 test_one_item_two_quantities_two_locations_one_already_selected

=cut

sub test_one_item_two_quantities_two_locations_one_already_selected : Tests {
    my $self = shift;

    my $product = (Test::XTracker::Data
        ->grab_products({ force_create => 1, how_many_variants => 1})
        )[1][0]{product};

    # Make sure we have a selected item for the given sku
    $self->{order_factory}->selected_order(products => [$product]);

    # Select our shipment, and make sure we have just one quantity (which is
    # already selected)
    my $shipment = $self->create_shipment([$product]);

    my $quantities = $self->add_quantities($product->variants->single, 1, 1);

    my $pick_sheet = $self->get_pick_sheet($shipment->id);

    for my $picked_row (@{$pick_sheet->as_data->{item_list}}) {
        is( $picked_row->{Location}, $quantities->[1]->location->location,
            'should match expected pick sheet location' );
    }
}

=head2 test_one_item_no_quantity

=cut

sub test_one_item_no_quantity : Tests {
    my $self = shift;

    my $product = (Test::XTracker::Data
        ->grab_products({ force_create => 1, how_many_variants => 1})
        )[1][0]{product};

    my $shipment = $self->create_shipment([$product]);

    $product->variants->related_resultset('quantities')->delete;

    my $pick_sheet = $self->get_pick_sheet($shipment->id);

    for my $picked_row (@{$pick_sheet->as_data->{item_list}}) {
        is( $picked_row->{Location}, 'Unknown',
            'should get Unknown as we have no quantity' );
    }
}

=head2 get_pick_sheet

=cut

sub get_pick_sheet {
    my ( $self, $shipment_id ) = @_;
    my $monitor = Test::XTracker::PrintDocs->new;
    XTracker::Order::Printing::PickingList::generate_picking_list(
        $self->schema, $shipment_id
    );

    my @files = $monitor->new_files;
    is( @files, 1, 'found 1 file' );
    my $file = $files[0];
    is( $file->file_type, 'pickinglist', 'file type is pickinglist' );
    return $file;
}

=head2 create_shipment(products) : shipment_row

Create a shipment with the given C<products>.

=cut

sub create_shipment {
    my ( $self, $products ) = @_;
    $self->{order_factory}->new_order(products => $products)->{order_object}
        ->get_standard_class_shipment;
}

=head2 add_quantities(variant_row, quantities) : [quantity_rows]

Add quantities for the given variant, each element in C<quantities> represent
one location.

=cut

sub add_quantities {
    my ( $self, $variant, @quantities ) = @_;

    # Make sure we have no quantities!
    ok( $variant->quantities->delete, 'delete all quantities for variant ' . $variant->id );

    # Get an ordered 'regular' location rs
    my @locations = $self->schema->resultset('Public::Location')->search(
        {
            'me.location' => { ilike => '0%' },
            'location_allowed_statuses.status_id' => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
        },
        {
            join => 'location_allowed_statuses',
            order_by => 'location',
            rows => scalar @quantities,
        }
    )->all;

    return [map {
        ok(
            my $quantity = $locations[$_]->create_related('quantities', {
                variant_id => $variant->id,
                quantity   => $quantities[$_],
                channel_id => 9, # TODO: named constant
                status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            }),
            sprintf( 'create %d quantit%s for variant %d in location %s',
                $quantities[$_], ($quantities[$_] == 1 ? q{y} : q{ies}), $variant->id, $locations[$_]->location
            )
        );
        $quantity;
    } 0..$#quantities];

}
