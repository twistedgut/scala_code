#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

reservation_auto_uploads.t - Auto Upload Pending Reservations

=head1 DESCRIPTION

This will test that when Uploaded Reservations are Cancelled then the next
in-line Pending Reservations are Automatically Uploaded.

This touches pages from the 'Stock Control->Reservation' Main Nav Option & does
the following actions:

    * Product Search
        * Edit Reservation page
            -> Uploading a Reservation
            -> Cancelling a Reservation
            -> Editing a Reservation
            -> Changing the Size for a Reservation
    * Live Reservations
        -> Edit Reservation Expiry Date
        -> Cancel Reservations
    * Pending Reservations
        -> Cancel a Reservation

#TAGS inventory reservation inline cando

=cut



use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :reservation_status
                                        );
use Data::Dump  qw( pp );


my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Reservations',
    ],
);

my $operator= Test::XTracker::Data->set_department( 'it.god', 'Personal Shopping' );

# set the Sales Channel for NaP
$framework->mech->channel( Test::XTracker::Data->get_local_channel_or_nap );

my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
                                                    how_many => 1,
                                                    how_many_variants => 3,
                                                    channel => $framework->mech->channel,
                                                    ensure_stock_all_variants => 1,
                                                } );
my $variant = $pids->[0]{variant};

# get an alternative Variant to use in the tests
my %alt_variants    = map { $_->sku => $_ } grep { $_->size_id != $variant->size_id } $pids->[0]{product}->variants->all;
my ( $alt_variant1, $alt_variant2 ) = values %alt_variants;
note "Variant              : ".$variant->sku;
note "Alternative Variant 1: ".$alt_variant1->sku;
note "Alternative Variant 2: ".$alt_variant2->sku;

# cancel any existing Reservations for the Variants or Operator
$variant->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED, ordering_id => 0 } );
$alt_variant1->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED, ordering_id => 0 } );
$alt_variant2->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED, ordering_id => 0 } );
$operator->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED, ordering_id => 0 } );

# create some reservations
my @reservs = create_reservations( 4, $channel, $variant, $operator );

$framework->login_with_permissions( {
    perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Reservation',
            ]
        }
    } );

# go to Product Page which should have the above Reservations on it
$framework->mech__reservation__summary
                ->mech__reservation__product_search
                    ->mech__reservation__product_search_submit(
                                { product_id => $variant->product_id, }
                            );

note "Upload the First Reservation";
$framework->mech__reservation__upload_reservation( $reservs[0]->id );
discard_changes( @reservs );
cmp_ok( $reservs[0]->status_id, '==', $RESERVATION_STATUS__UPLOADED, "First Reservation Uploaded" );

note "Delete/Cancel the First Reservation";
$framework->mech__reservation__cancel_reservation( $reservs[0]->id );
discard_changes( @reservs );
cmp_ok( $reservs[0]->status_id, '==', $RESERVATION_STATUS__CANCELLED, "First Reservation Cancelled" );
TODO: {
    local $TODO = "CANDO-400: Can't test this until it is possible to Mock an MySQL call when going through the App.";
    cmp_ok( $reservs[1]->status_id, '==', $RESERVATION_STATUS__UPLOADED, "Second Reservation Uploaded" );
};

note "Re-Order the Second Reservation should Swap with the Third";
$framework->mech__reservation__edit_reservation( $reservs[1]->id, { ordering => $reservs[1]->ordering_id + 1 } );
discard_changes( @reservs );
# remember Cancelling the First Reservation moves all Ordering Up by One
cmp_ok( $reservs[1]->ordering_id, '==', 2, "Second Reservation's Ordering Id is now 2" );
cmp_ok( $reservs[2]->ordering_id, '==', 1, "Third Reservation's Ordering Id is now 1" );

note "Edit Second Reservation to change it's Size (use another SKU in other words)";
$framework->mech__reservation__edit_reservation( $reservs[1]->id, { changeSize => $alt_variant1->id } );
discard_changes( @reservs );
cmp_ok( $reservs[1]->status_id, '==', $RESERVATION_STATUS__CANCELLED, "Second Reservation Now Cancelled" );
TODO: {
    local $TODO = "CANDO-400: Can't test this until it is possible to Mock an MySQL call when going through the App.";
    cmp_ok( $reservs[2]->status_id, '==', $RESERVATION_STATUS__UPLOADED, "Third Reservation Uploaded" );
};
my $new_res = $alt_variant1->reservations->search( {}, { order_by => 'id DESC' } )->first;
isa_ok( $new_res, 'XTracker::Schema::Result::Public::Reservation', "Found a New Reservation for the Other SKU" );
cmp_ok( $new_res->customer_id, '==', $reservs[1]->customer_id, "New Reservation is for the Same Customer as the Cancelled One" );
# because stock was ensured when grabbing the products then the new reservation should be automatically uploaded
cmp_ok( $new_res->status_id, '==', $RESERVATION_STATUS__UPLOADED, "New Reservation Status is 'Uploaded'" );


note "Go to the 'Live Reservations' Page and Edit the Reservations There";

# create some new reservations for the Same Customer for the Alternative Variants
my @same_cust_res   = create_reservations( 1, $channel, $alt_variant1, $operator, $reservs[2]->customer );
push @same_cust_res, create_reservations( 1, $channel, $alt_variant2, $operator, $reservs[2]->customer );
# create some new reservations for the Alternative Variants for Different Customers
my @alt_cust_res    = create_reservations( 1, $channel, $alt_variant1, $operator );
push @alt_cust_res, create_reservations( 1, $channel, $alt_variant2, $operator );

# Upload both of the Same Customer Reservations, so they appear in Live Reservations
$same_cust_res[0]->update( { status_id => $RESERVATION_STATUS__UPLOADED, date_expired => \"now()" } );
$same_cust_res[1]->update( { status_id => $RESERVATION_STATUS__UPLOADED, date_expired => \"now()" } );

note "On 'Live Reservations' Edit one Reservation's Expiry Date and Delete Two Other Reservations";
$framework->mech__reservation__summary_click_live
            ->mech__reservation__listing_reservations__edit( $reservs[2]->customer->id, {
                                                    edit_expiry => [
                                                            { $reservs[2]->id => '23-01-2100' },
                                                        ],
                                                    delete_res  => [
                                                            $same_cust_res[0]->id,
                                                            $same_cust_res[1]->id,
                                                        ],
                                            } );
discard_changes( @reservs, @same_cust_res, @alt_cust_res );
is( $reservs[2]->date_expired->dmy('-'), '23-01-2100', "Reservation's Expiry Date as Expected: 23-01-2100" );
cmp_ok( $reservs[3]->status_id, '==', $RESERVATION_STATUS__PENDING,
                        "Original Fourth Reservation for Same Variant that had the Expiry Date Edited Still 'Pending'" );
cmp_ok( $same_cust_res[0]->status_id, '==', $RESERVATION_STATUS__CANCELLED,
                        "First of the Same Customer Reservations is Cancelled" );
TODO: {
    local $TODO = "CANDO-400: Can't test this until it is possible to Mock an MySQL call when going through the App.";
    cmp_ok( $alt_cust_res[0]->status_id, '==', $RESERVATION_STATUS__UPLOADED,
                            "First of the Alternative Customer Reservations is Uploaded" );
};
cmp_ok( $same_cust_res[1]->status_id, '==', $RESERVATION_STATUS__CANCELLED,
                        "Second of the Same Customer Reservations is Cancelled" );
TODO: {
    local $TODO = "CANDO-400: Can't test this until it is possible to Mock an MySQL call when going through the App.";
    cmp_ok( $alt_cust_res[1]->status_id, '==', $RESERVATION_STATUS__UPLOADED,
                            "Second of the Alternative Customer Reservations is Uploaded" );
};

# go to the 'Pending Reservations' page and check that there is a
# 'Now Instock' section as the Ensuring of Stock when Grabbing the
# products should have made sure there is

note "Go to the 'Pending Reservations' page, check 'Now Instock' Section exists and Delete last Reservation";
$framework->mech__reservation__summary_click_pending;
$framework->mech->has_tag_like( 'span', qr/Pending Reservations Now Instock/, "Found 'Now Instock' Section" );
$framework->mech__reservation__listing_reservations__edit( $reservs[3]->customer_id, {
                                                    delete_res  => [
                                                            $reservs[3]->id,
                                                        ],
                                            } );
discard_changes( @reservs );
cmp_ok( $reservs[3]->status_id, '==', $RESERVATION_STATUS__CANCELLED, "Last Remaining Pending Reservation Cancelled" );


done_testing();

#---------------------------------------------------------------------------

=head2 discard_changes

    discard_changes( @dbic_records );

Helper to re-load various DBIC records

=cut

sub discard_changes {
    my @records = @_;
    foreach my $record ( @records ) {
        $record->discard_changes;
    }
    return;
}

=head2 create_reservations

    @reservations = create_reservations(
        $number_to_create,
        $dbic_channel,
        $dbic_variant,
        $dbic_operator,
        $dbic_customer,
    );

Helper to create X number of reservations.

=cut

sub create_reservations {
    my ( $number, $channel, $variant, $operator, $customer )    = @_;

    my @reservations;

    # get the Current Max Ordering Id for this Variant's Reservations
    my $current_max_ordering    = $variant->reservations->get_column('ordering_id')->max() || 0;

    foreach my $counter ( 1..$number ) {
        my $data = Test::XT::Flow->new_with_traits(
                        traits => [
                            'Test::XT::Data::ReservationSimple',
                        ],
                    );

        $data->customer( $customer )        if ( defined $customer );       # use the same Customer if asked to
        $data->operator( $operator );
        $data->channel( $channel );
        $data->variant( $variant );                             # make sure all reservations are for the same SKU

        my $reservation = $data->reservation;
        $reservation->update( { ordering_id => $current_max_ordering + $counter } );    # prioritise each reservation

        # make sure the Customer has a different Email
        # Address than every other Reservation's Customer
        $reservation->customer->update( { email => $reservation->customer->is_customer_number . '.test@net-a-porter.com' } );
        note "Customer Id/Nr: ".$reservation->customer->id."/".$reservation->customer->is_customer_number;

        push @reservations, $reservation;
    }

    return @reservations;
}
