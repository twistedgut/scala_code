package XTracker::Order::Utils::StatusChange;

use NAP::policy "tt", 'class';
with qw/XTracker::Role::WithAMQMessageFactory/;

use XTracker::Database::Shipment qw/update_shipment_status
                                    log_shipment_status
                                    get_shipment_ddu_status
                                    get_shipment_preorder_status/;
use XTracker::Database::Customer qw/set_customer_credit_check/;
use XTracker::Database::Channel qw/get_channel_details/;
use XTracker::Constants::FromDB qw/:shipment_status
                                   :order_status/;
use XTracker::Database::Order qw/update_order_status
                                 log_order_status/;
use XTracker::EmailFunctions qw/send_email/;
use XTracker::Config::Local qw/config_var
                               xtracker_email
                               customercare_email/;
use XTracker::Error qw(xt_success);

=head1 NAME

XTracker::Order::Utils::StatusChange

=head1 DESCRIPTION

Change order and shipment statuses

=head1 ATTRIBUTES

=head2 schema

=cut

has schema => (
    is          => 'ro',
    isa         => 'DBIx::Class::Schema|XTracker::Schema|XT::DC::Messaging::Model::Schema',
    required    => 1,
   );

=head1 METHODS

=head2 change_order_status

=cut

sub change_order_status {
    my ($self, $order_id, $new_status_id, $operator_id, $bulk_action_log_id) = @_;

    # Get the current order status and die if the current status is CANCELLED
    # as it makes no sense to try and change status from cancelled.
    my $order = $self->schema->resultset('Public::Orders')->find( $order_id );
    die "Cannot find order with id $order_id" unless $order;
    if ( $order->order_status_id == $ORDER_STATUS__CANCELLED ) {
        die "Cannot change the status of order id $order_id with current status of CANCELLED";
    }

    my $dbh = $self->schema->storage->dbh;

    # Order status update & log
    update_order_status( $dbh, $order_id, $new_status_id );
    log_order_status( $dbh,
                      $order_id,
                      $new_status_id,
                      $operator_id,
                      $bulk_action_log_id);

    return 1;
}

=head2 accept_order

=cut

sub accept_order {
    my ($self, $order_ref, $shipments_ref, $order_id, $operator_id, $flags_ref) = @_;

    my $dbh = $self->schema->storage->dbh;

    # set a new status for website
    my $new_website_status = "PROCESSING";

    # update status of all shipments
    my $vvouch_only_dispatched
      = $self->update_shipments_status($shipments_ref,
                                       $SHIPMENT_STATUS__PROCESSING,
                                       $operator_id,
                                       $flags_ref);

    # if accepted from credit check then set credit check date against customer
    if ($order_ref->{order_status_id} == $ORDER_STATUS__CREDIT_CHECK){
        set_customer_credit_check($dbh,
                                  $order_ref->{customer_id});
    }

    # if order placed on incorrect website email Customer Care
    $self->check_incorrect_website($order_ref);

    if ( $vvouch_only_dispatched ) {
        # if a Virtual Voucher order was dispatched then no need to update the PWS
        $new_website_status = "";
        xt_success( "Virtual Voucher Only Order was Dispatched" );
    }

    return $new_website_status;
}

=head2 update_shipments_status

=cut

sub update_shipments_status {
    my ( $self, $shipment_ref, $status_id, $operator_id, $args ) = @_;

    my $dbh = $self->schema->storage->dbh;

    # set up a flag to see if a Virtual Voucher order has been Dispatched
    my $vvouch_only_dispatched   = 0;

    foreach my $shipment_id ( keys %{$shipment_ref} ) {

        my $update_status_id = $status_id;
        my $shipment = $self->schema->resultset('Public::Shipment')->find($shipment_id);

        if( $args && $args->{update_shipment_status_from_log} ) {
            # get the last shipment_status from shipment_status_log
            if( my $shipment_status_log = $shipment->get_previous_non_hold_shipment_status_log_entry ) {
                $update_status_id = $shipment_status_log->shipment_status_id;
            }
        }

        # check for releasing shipments - extra checks required
        if ( $update_status_id == $SHIPMENT_STATUS__PROCESSING ) {

            # only update if status is currently finance hold
            if ($shipment_ref->{$shipment_id}->{shipment_status_id} == $SHIPMENT_STATUS__FINANCE_HOLD) {

                # check if shipment needs to go on DDU Hold first
                if( get_shipment_ddu_status( $dbh, $shipment_id ) > 0 ) {
                    $update_status_id = $SHIPMENT_STATUS__DDU_HOLD;
                };

                # check if shipment needs to go on Pre-Order Hold first
                my $preorder_pending = get_shipment_preorder_status($dbh, $shipment_id);

                if ($preorder_pending > 0){
                    $update_status_id = $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD;
                }

            } else {

                $update_status_id = $shipment_ref->{$shipment_id}->{shipment_status_id};
            }
        }

        # Do nothing else if there's no status update to do
        next if $shipment_ref->{$shipment_id}{shipment_status_id} == $update_status_id;

        if ( update_shipment_status( $dbh, $shipment_id, $update_status_id, $operator_id ) ) {
            $vvouch_only_dispatched = 1;
        }
        $self->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::ShipmentWMSPause', $shipment,
        ) if $shipment->discard_changes->does_iws_know_about_me;
    }

    return $vvouch_only_dispatched;
}

=head2 check_incorrect_website

=cut

sub check_incorrect_website {
    my ($self, $order_ref) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $channel = get_channel_details( $dbh, $order_ref->{sales_channel} );
    my $xtracker_email = xtracker_email( $channel->{config_section} );
    my $customercare_email = customercare_email( $channel->{config_section} );

    # To unit test this method, we need return value to check against it
    my $return_status = 0;

    foreach my $shipment_id ( keys %{$order_ref->{shipments}} ) {

        my $shipment = $self->schema->resultset('Public::Shipment')
            ->find({ id => $shipment_id });

        if ( $shipment->is_incorrect_website ) {
            # get instance of XT (INTL or AM or APAC)
            my $instance = config_var('XTracker', 'instance');
            # prepare email content
            my $msg = "Order ". $order_ref->{order_nr}." was bought on $instance with shipping destination: ".
                     $shipment->shipment_address->country;
            # set return_status (used in unit test)
            $return_status = send_email(
                $xtracker_email,
                $xtracker_email,
                $customercare_email,
                "Order $order_ref->{order_nr} - placed on the incorrect website",
                $msg
            );
        }
    }

    return $return_status;
}
