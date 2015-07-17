package Test::XTracker::Schema::Result::Public::Reservation;

use NAP::policy 'test';
use parent 'NAP::Test::Class';


=head1 Reservation commission_cut_off_date

Currently testing:

    * Reservation commission_cut_off_date is set when reservation is purchased.
    * also commission_cut_off_date is set when reservation is cancelled.

=cut


use Test::XTracker::Data;
use XTracker::Constants::FromDB qw ( :reservation_status );
use XTracker::Database::Reservation qw( cancel_reservation );

sub start_tests: Tests( startup ) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema();
    isa_ok( $self->{schema}, 'XTracker::Schema',"Schema Created" );

    # start a transaction
    $self->{schema}->txn_begin;
}

sub rollback : Test( shutdown ) {
    my $self = shift;

    $self->{schema}->txn_rollback;

}

=head2 test__set_commission_cut_off_date

Tests commission_cut_off_date is set when a reservation is purchased or cancelled

=cut

sub test__set_commission_cut_off_date: Tests() {
    my $self = shift;


    my $schema          = $self->{schema};
    my $reservation_rs  = $schema->resultset('Public::Reservation');

    my($channel, $pids) = Test::XTracker::Data->grab_products( {how_many => 1} );
    my $variant         = $pids->[0]{variant};

    # delete any reservations linked
    Test::XTracker::Data->delete_reservations( { variant => $variant } );

    my $customer = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );

    #create reservation
    my $reservation = $customer->create_related( 'reservations', {
        channel_id  => $channel->id,
        variant_id  => $pids->[0]->{variant_id},
        ordering_id => 1,
        operator_id => 1,
        status_id   => $RESERVATION_STATUS__UPLOADED,
        reservation_source_id => $schema->resultset('Public::ReservationSource')->search->first->id,
        reservation_type_id => $schema->resultset('Public::ReservationType')->search->first->id,
    });

    # set the config values for commission_cut_off date
    $self->_set_commission_cut_date( $channel, {
        set_commission => [
            { setting => 'sale_commission_value', value => '1'},
            { setting => 'sale_commission_unit', value => 'DAYS'},
            { setting => 'commission_use_end_of_day', value => 1 }

        ],
    });

    is( $reservation->commission_cut_off_date, undef, "Commission cut off date is Empty" );
    # mark as purchased
    ok( $reservation->set_purchased, 'Set reservation as purchased' );


    # check reservation is marked as purchased
    cmp_ok( $reservation->status_id, '==', $RESERVATION_STATUS__PURCHASED, "Reservation is marked as Purchased" );
    # check commission_cut_off_date
    my $reservation_ccutoff =  $reservation->discard_changes->commission_cut_off_date->set_nanosecond(0);
    my $date_result         = DateTime->compare( $self->_get_date(1,1), $reservation_ccutoff );
    cmp_ok( $date_result, '==', 0, "Commission cut off date is set correctly - Purchased" );

    # make the commission_cut_off date undef
    $reservation->update({
        commission_cut_off_date => undef,
        status_id               => $RESERVATION_STATUS__UPLOADED
    });

    # check date is undef
    is( $reservation->discard_changes->commission_cut_off_date,
        undef,
        "Commission cut off date is undef"
    );

    my $stock_manager   = XTracker::WebContent::StockManagement->new_stock_manager({
        schema      => $schema,
        channel_id  => $channel->id,
    });

    my $dbh = $schema->storage->dbh;
    my $operator = Test::XTracker::Data->get_application_operator();

    # cancel reservation
    cancel_reservation( $dbh, $stock_manager,{
        reservation_id  => $reservation->id,
        variant_id      => $reservation->variant_id,
        status_id       => $reservation->status_id,
        customer_nr     => $reservation->customer->is_customer_number,
        operator_id     => $operator->id,
    });

    $reservation->discard_changes;
    cmp_ok( $reservation->status_id, '==', $RESERVATION_STATUS__CANCELLED, "Reservation is marked as Cancelled" );

    # check commission date is set correctly.
    $reservation_ccutoff = $reservation->discard_changes->commission_cut_off_date->set_nanosecond(0);
    $date_result         = DateTime->compare( $self->_get_date(1,1), $reservation_ccutoff );
    cmp_ok( $date_result, '==', 0, "Commission cut off date is set correctly at Cancellation" );

}


#------------private methods

=head2 _get_date

Helper method to calculate date

=cut

sub _get_date {
    my $self = shift;
    my $days = shift // 1;
    my $flag = shift // 1;

   my $date = $self->{schema}->db_now()->add( days => $days );

    if ( $flag ) {
        $date->set( hour => 23, minute => 59, second => 59 );
    }

    #Make sure the dates are same
    $date->set_nanosecond(0);
    return $date;
}


=head2 _set_commission_cut_date

    __PACKAGE__->_set_commission_cut_date( $channel, {
        set_commission => [
            { setting => sale_commission_value , value => '21'},
            { setting => sale_commission_value , value => 'DAYS'},
            { setting => commission_use_end_of_day, value => 1 }
            ]
        }
         or
        # this will remove the 'commission related' values completely
        set_commission => undef,

    } );

Sets the various settings required for Reservation commission for given Sales Channel.

=cut

sub _set_commission_cut_date {
    my $self    = shift;
    my $channel = shift;
    my $args    = shift;

    Test::XTracker::Data->remove_config_group('Reservation');
    Test::XTracker::Data->create_config_group('Reservation',
    {
        channel => $channel,
        settings => $args->{set_commission},
    });


}
