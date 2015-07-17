package Test::XT::Flow::MultipleReservations;

use NAP::policy "tt",     qw( test role );

use Data::Dump qw(pp);

use Test::XT::Flow;

with 'Test::XT::Flow::AutoMethods';

__PACKAGE__->create_fetch_method(
    method_name      => 'mech__multiple_reservation_create',
    page_description => 'Reservation Summary',
    page_url         => '/StockControl/Reservation/MultipleReservations/Create',
    params           => [],
);

__PACKAGE__->create_fetch_method(
    method_name      => 'mech__multiple_reservation_confirm',
    page_description => 'Confirm Multiple Reservations',
    page_url         => '/StockControl/Reservation/MultipleReservations/Basket',
    params           => [],
);

__PACKAGE__->create_fetch_method(
    method_name      => 'mech__multiple_reservation_select',
    page_description => 'Select Multiple Reservations',
    page_url         => '/StockControl/Reservation/MultipleReservations/SelectProducts',
    params           => [],
);


__PACKAGE__->create_form_method(
    method_name      => 'mech__multiple_reservation_confirm_goback',
    form_name        => 'edit_multiple_reservations',
    form_description => 'Edit Multiple Reservations',
    form_button      => 'button',
    assert_location  => qr{/StockControl/Reservation/MultipleReservations/Basket},
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__multiple_reservation_confirm_reserve',
    form_name        => 'confirm_item_selection',
    form_description => 'Confirm Multiple Reservations',
    #form_button      => 'button',
    assert_location  => qr{/StockControl/Reservation/MultipleReservations/Basket},
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__multiple_reservation_select_search',
    form_name        => 'pid_search',
    form_description => 'Search for pids',
    form_button      => 'button',
    assert_location  => qr{/StockControl/Reservation/MultipleReservations/SelectProducts},
    transform_fields => sub {
        my ($mech, $args)  = @_;
        return $args;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'mech__multiple_reservation_select_reserve',
    form_name        => 'variant_select_products',
    form_description => 'Submit variant selection',
    form_button      => 'button',
    assert_location  => qr{/StockControl/Reservation/MultipleReservations/SelectProducts},
    transform_fields => sub {
        my ($self, $args) = @_;
        my $mech = $self->mech;

        $mech->form_name('variant_select_products');

        foreach my $token (@{$args->{variants}}) {
            $mech->tick('variants', $token, 1);
        }

        $mech->select('reservation_source_id', $args->{reservation_source_id});
        $mech->select('reservation_type_id', $args->{reservation_type_id});

        return;
    },
);

1;
