#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

reservation_multi_submit.t - Tests the Live/Pending Reservations Pages

=head1 DESCRIPTION

This test does the following:

    * on Live Reservation page
        * checks if Upload Date column exists
        * checks if multiple edit of Expiry Date across customer works
        * checks multiple edit of expiry date for same pid for same customer
        * Also checks if multiple delete of reservation across customer works

    * on Pending page
        * checks if multiple delete of reservation across customer works

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

# create some reservations
my @reservs = _create_reservations( 4, $channel, $variant, $operator );

$framework->login_with_permissions( {
    perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Reservation',
            ]
        }
    } );

note "Go to the 'Live Reservations' Page and Edit the Reservations There";

# create some new reservations for the Same Customer for the Alternative Variants
my @same_cust_res   = _create_reservations( 2, $channel, $alt_variant1, $operator, $reservs[2]->customer );
push @same_cust_res, _create_reservations( 1, $channel, $alt_variant2, $operator, $reservs[2]->customer );
# create some new reservations for the Alternative Variants for Different Customers
my @alt_cust_res    = _create_reservations( 1, $channel, $alt_variant1, $operator );
push @alt_cust_res, _create_reservations( 1, $channel, $alt_variant2, $operator );


# Upload both of the Same Customer Reservations, so they appear in Live Reservations
$same_cust_res[0]->update( { status_id => $RESERVATION_STATUS__UPLOADED, date_expired => \"now()" } );
$same_cust_res[1]->update( { status_id => $RESERVATION_STATUS__UPLOADED, date_expired => \"now()" } );
$same_cust_res[2]->update( { status_id => $RESERVATION_STATUS__UPLOADED, date_expired => \"now()" } );

note "********** Testing for Upload Date Column ";
$framework->mech__reservation__summary
            ->mech__reservation__summary_click_live;
$framework->mech->content_contains( 'Upload Date', "Reservation Live Page has 'Upload Date' column" );

note "On 'Live Reservations' Edit  Reservation's Expiry Date/ Delete Reservations for Same and Different customer under one operator ";
$framework->mech__reservation__summary
            ->mech__reservation__summary_click_live
            ->mech__reservation__listing_reservations__edit( $reservs[2]->customer->id, {
                                                    edit_expiry => [
                                                            { $reservs[2]->id => '23-01-2010' }, #same customer
                                                            { $same_cust_res[0]->id => '24-01-2010'}, #same customer as above
                                                            { $alt_cust_res[0]->id => '30-01-2012'}, # different customer
                                                            { $same_cust_res[1]->id => '22-01-2013'}, #same customer
                                                        ],
                                                    delete_res  => [
                                                            $same_cust_res[2]->id,
                                                            $alt_cust_res[1]->id,
                                                        ],
                                            } );

_discard_changes( @reservs, @same_cust_res, @alt_cust_res );
note "***** Testing Submit Button - for multiple customer edit functionality ";
is( $reservs[2]->date_expired->dmy('-'), '23-01-2010', "Reservation's Expiry Date as Expected: 23-01-2010 for same customer with alternative variant" );
is( $same_cust_res[0]->date_expired->dmy('-'), '24-01-2010', "Reservation's Expiry Date as Expected: 24-01-2010 for same customer with alternative variant" );
is( $alt_cust_res[0]->date_expired->dmy('-'), '30-01-2012', "Reservation's Expiry Date as Expected: 30-01-2012 for different customer with same variant" );
is( $same_cust_res[1]->date_expired->dmy('-'),'22-01-2013',"Reservation's for same pid for a customer is listed on page");

cmp_ok( $same_cust_res[2]->status_id, '==', $RESERVATION_STATUS__CANCELLED,
                        "One of the Same Customer Reservations is Cancelled" );
cmp_ok( $alt_cust_res[1]->status_id, '==', $RESERVATION_STATUS__CANCELLED,
                        "One of the Different Customer Reservations is Cancelled" );


 # for pending page
note "Go to the 'Pending Reservations' page, check Delete functionalty works across customer under one operator";
$framework->mech__reservation__summary_click_pending;
$framework->mech__reservation__listing_reservations__edit( $reservs[3]->customer_id, {
                                                    delete_res  => [
                                                            $reservs[3]->id,
                                                            $alt_cust_res[0]->id
                                                        ],
                                            } );
_discard_changes( @reservs, @alt_cust_res );

note " ******** Testing Delete functionality on Pending Reservation page";
cmp_ok( $reservs[3]->status_id, '==', $RESERVATION_STATUS__CANCELLED,
             "Pending Reservation Cancelled for customer id = " . $reservs[3]->customer->id);
cmp_ok( $alt_cust_res[0]->status_id, '==', $RESERVATION_STATUS__CANCELLED,
             "Pending Reservation Cancelled for customer id = ". $alt_cust_res[0]->customer->id);

done_testing();

#---------------------------------------------------------------------------

=head2 _discard_changes

    _discard_changes( @array_of_dbic_records );

Helper to re-load various DBIC records

=cut

sub _discard_changes {
    my @records = @_;
    foreach my $record ( @records ) {
        $record->discard_changes;
    }
    return;
}

=head2 _create_reservations

    @reservation_dbic_recs = _create_reservations(
        $number_to_get,
        $channel_dbic,
        $variant_dbic,
        $operator_dbic,
        $customer_dbic,
    );

Helper to create X number of reservations.

=cut

sub _create_reservations {
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
