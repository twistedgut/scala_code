package XT::DC::Messaging::Consumer::Reimbursement;
use NAP::policy "tt", 'class';
use XTracker::Config::Local;
use XTracker::Constants::FromDB qw( :bulk_reimbursement_status :renumeration_type :renumeration_class :renumeration_status :note_type );
use XTracker::Constants qw( :application );
use XTracker::Database::Invoice qw( generate_invoice_number );
use XTracker::EmailFunctions;
use Scalar::Util qw( looks_like_number );
use Carp;
use DateTime;
use Text::Wrap;
use XT::DC::Messaging::Spec::Reimbursement;

extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';

=head1 NAME

XT::DC::Messaging::Consumer::Reimbursement

=head1 DESCRIPTION

Consumer for bulk reimbursement updates.

=over

=item B<bulk>

Consumer action for /bulk.

Takes a given reimbursement_id and goes through each associated pending order, doing the following:

* Applies a renumeration.
* If successful, send the customer an email (if requested).
* Update the bulk_reimbursement tables to reflect the results.

=cut

sub routes {
    return {
        destination => {
            bulk => {
                code => \&bulk,
                spec => XT::DC::Messaging::Spec::Reimbursement->bulk(),
            },
        },
    };
}

sub bulk {
    ## no critic(ProhibitDeepNests)
    my ($self, $message, $header) = @_;

    # If we've been given an ID.
    if ( my $reimbursement_id = $message->{'reimbursement_id'} ) {

        # If it exists in the table bulk_reimbursement.
        if ( my $reimbursement = $self->model('Schema::Public::BulkReimbursement')->find( $reimbursement_id ) ) {

            # If it's status is set to 'Pending'.
            if ( $reimbursement->bulk_reimbursement_status_id == $BULK_REIMBURSEMENT_STATUS__PENDING ) {

                my @success;
                my @failure;
                my %email = ();

                # %email = (
                #    <CUSTOMER.ID> => {
                #        customer => XTracker::Schema::Result::Public::Customer,
                #        currency => {
                #            <CURRENCY> => { # GBP, USD, etc.
                #                value = <TOTAL>, # Total for the currency.
                #                orders => [
                #                    XTracker::Schema::Result::Public::Orders,
                #                    XTracker::Schema::Result::Public::Orders,
                #                    ...
                #                ],
                #            },
                #        },
                #    },
                # );

                # ===== Process orders.

                foreach my $reimbursement_order ( $reimbursement->link_bulk_reimbursement__orders->all ) {

                    my $order = $reimbursement_order->order;
                    my $result = $self->_process_order( $order, $reimbursement );

                    # If the reimbursement was succesful.
                    if ( $result ) {

                        if ( $reimbursement->send_email ) {

                            # Set the customer object if it hasn't already been set.
                            $email{ $order->customer_id }
                                ->{ 'customer' } ||= $order->customer;

                            # Increment the total credited value for the currency.
                            $email{ $order->customer_id }
                                ->{ 'currency' }
                                ->{ $order->currency->currency }
                                ->{ 'value' } += $reimbursement->credit_amount;

                            # Add the order object to the list of orders for this currency.
                            push (
                                @{
                                    $email{ $order->customer_id }
                                        ->{ 'currency' }
                                        ->{ $order->currency->currency }
                                        ->{ 'orders' }
                                },
                                $order
                            );

                        } else {

                            push @success, { 'order' => $order };

                        }

                    } else {

                        # If reimbursement was not succesful, add the order to list of failures.
                        push @failure, {
                            'order'     => $order,
                            'reason'    => 'Unable to process reimbursement'
                        };

                    }

                }

                # ===== Send emails to customers.

                foreach my $customer ( values %email ) {

                    while ( my ( $currency, $currency_data ) = each %{ $customer->{'currency'} } ) {

                        my $email_sent;

                        eval {

                            # Prepare the data for the template.
                            my $data = {
                                'plural'        => \&_plural,
                                'order_count'   => scalar @{ $currency_data->{'orders'} },
                                'orders'        => $currency_data->{'orders'},
                                'content'       => $reimbursement->email_message,
                                'credit'        => {
                                    'amount'        => $currency_data->{'value'},
                                    'currency'      => $currency,
                                },
                                'customer'      => {
                                    'first_name'    => $customer->{'customer'}->first_name,
                                    'last_name'     => $customer->{'customer'}->last_name,
                                    'title'         => $customer->{'customer'}->title,
                                },
                            };

                            # Lookup the required correspondence template.
                            my $correspondence_template = $self->model('Schema::Public::CorrespondenceTemplate')->find(
                                {
                                    'name' => 'Reimbursement-' . $reimbursement->channel->web_name,
                                }
                            );

                            # Parse the template.
                            my $email_info = get_email_template(
                                $self->model('Schema')->schema->storage->dbh,
                                $correspondence_template->id,
                                $data
                            );

                            # Get the from address from the configuration.
                            my $from_address = config_var(
                                'Email_' . $reimbursement->channel->business->config_section,
                                'customercare_email'
                            );

                            # Send the email.
                            $email_sent = send_email(
                                $from_address, # from
                                $from_address, # reply_to
                                $customer->{'customer'}->email,
                                $reimbursement->email_subject,
                                $$email_info{content}
                            );

                        };

                        my $error = $@;

                        # If the email failed to send or any other errors occurred.
                        if ( !$email_sent || $error ) {

                            carp "ERROR: $error \n";

                            # Add all the orders associated with this currency to the list of failures.
                            push @failure, {
                                'order'     => $_,
                                'reason'    => 'Unable to send email'
                            } foreach @{ $currency_data->{'orders'} };


                        } else {

                            # Otherwise add it to the list of successes.
                            push @success, { 'order' => $_ } foreach @{ $currency_data->{'orders'} };

                        }

                    }

                }

                # ===== Update order status.

                _update_reimbursement_order_status( $reimbursement, 1, \@success );
                _update_reimbursement_order_status( $reimbursement, 0, \@failure );

                # ===== Update reimbursement status.

                $reimbursement->bulk_reimbursement_status_id(
                    @failure
                        ? $BULK_REIMBURSEMENT_STATUS__ERROR
                        : $BULK_REIMBURSEMENT_STATUS__DONE
                );

                $reimbursement->update;

                # ===== Sort the sucesses/failures.

                @success = sort { $a->{'order'}->order_nr <=> $b->{'order'}->order_nr } @success;
                @failure = sort { $a->{'order'}->order_nr <=> $b->{'order'}->order_nr } @failure;

                # ===== Send message to XTracker user.

                my $message_success = @success
                    ? join( ', ', map { $_->{'order'}->order_nr } ( @success, ) ) . '<br />'
                    : '';

                my $message_failure = @failure
                    ? join( ', ', map { $_->{'order'}->order_nr . ' - ' .  $_->{'reason'} } ( @failure, ) ) . '<br />'
                    : '';

                # Configure Text:Wrap.
                $Text::Wrap::separator = '<br />';
                $Text::Wrap::unexpand = 0;

                # Send the message.
                $self->model('Schema::Public::Operator')
                     -> find( $reimbursement->operator_id )
                     -> send_message(
                        {
                            'subject'   => 'Bulk Reimbursement Results',
                            'message'   => sprintf(
                                'Failure (%u):<br />%s<br />Success (%u):<br />%s',
                                scalar( @failure ),
                                wrap( '', '', $message_failure ),
                                scalar( @success ),
                                wrap( '', '', $message_success )
                            ),
                            'sender'    => $APPLICATION_OPERATOR_ID, # TODO: Better operator ID to use?
                        }
                    );

            }

        }

    }

}

=item B<_process_order($order, $value)>

Private method to apply a renumeration to the specified $order of the value $value.

It first populates the renumeration table and then sends a message to the Order::StoreCreditRefund Queue.

  my $order = $self->model('Schema::Public::Orders')->search( ... );

  $self->_process_order( $order, 25 );

=cut

sub _process_order {
    my ($self, $order, $reimbursement) = @_;

    eval {

        my $schema = $self->model('Schema')->schema;

        $schema->txn_do( sub {

            # Create an entry in the renumeration table.
            my $renumeration = $self->model('Schema::Public::Renumeration')->create( {
                shipment_id             => $order->get_standard_class_shipment->id,
                invoice_nr              => generate_invoice_number( $schema->storage->dbh ),
                renumeration_type_id    => $RENUMERATION_TYPE__STORE_CREDIT,
                renumeration_class_id   => $RENUMERATION_CLASS__GRATUITY,
                renumeration_status_id  => $RENUMERATION_STATUS__COMPLETED,
                shipping                => 0,
                misc_refund             => $reimbursement->credit_amount,
                alt_customer_nr         => 0,
                gift_credit             => 0,
                store_credit            => 0,
                currency_id             => $order->currency_id,
                gift_voucher            => 0,
                renumeration_reason_id  => $reimbursement->renumeration_reason_id,
            } );

            # Add to renumeration_status_log.
            $renumeration->update_status( $renumeration->renumeration_status_id, $APPLICATION_OPERATOR_ID );

            # Add order note.
            $self->model('Schema::Public::OrderNote')->create( {
                orders_id       => $order->id,
                note            => sprintf(
                                    'Store Credit Applied - %0d %s %s',
                                    $reimbursement->credit_amount,
                                    $order->currency->currency,
                                    (
                                      $reimbursement->renumeration_reason_id
                                      ? $reimbursement->renumeration_reason->reason . ' - ' . $reimbursement->reason
                                      : $reimbursement->reason
                                    )
                                ),
                note_type_id    => $NOTE_TYPE__FINANCE,
                operator_id     => $reimbursement->operator_id,
                date            => DateTime->now( time_zone => 'local' ),
            } );

            # uncomment to force commit in dev env where amq is not working
            # $schema->txn_commit();

            # Send a message to the website queue.
            $self->model('MessageQueue')->transform_and_send(
                'XT::DC::Messaging::Producer::Order::StoreCreditRefund',
                {
                    renumeration => $renumeration
                }
            );

        });

    };

    if ( my $error = $@ ) {

        carp "ERROR: $error \n";
        return 0;

    } else {

        return 1;

    }

}

=item B<_update_reimbursement_order_status($reimbursement_orders, $status, $orders)>

Updates the column 'completed' to $status for all the orders in the $reimbursement ResultSet.

  my $reimbursement =  $self->model('Schema::Public::BulkReimbursement')->find( ... );

  my @success = ( { 'order' => XTracker::Schema::Result::Public::Orders } );

  _update_reimbursement_order_status( $reimbursement, 1, \@success );

=cut

sub _update_reimbursement_order_status {
    my ($reimbursement, $status, $orders) = @_;

    if ( @$orders ) {

        my $update = $reimbursement->link_bulk_reimbursement__orders->search(
            {
                'order_id' => {
                    '-in' => [ map { $_->{'order'}->id } @$orders ]
                }
            }
        );

        $update->update( { 'completed' => $status } );

    }

}

=item B<_plural($test, $singular, $plural)>

Returns either $singular or $plural, depending on whether $test is singular or plural.

  my $text = _plural( 1, 'singular', 'plural' );

  $text = 'singular';

  my $text = _plural( 2, 'singular', 'plural' );

  $text = 'plural';

=cut

sub _plural {
    my ( $test, $singular, $plural ) = @_;

    # If defined ...
    if ( defined $test ) {

        # ... is a number ...
        if ( looks_like_number $test ) {

            # ... and is one.
            if ( abs( $test ) == 1 ) {

                return $singular;

            # ... otherwise.
            } else {

               return $plural;

            }

        }

    }

    return '';

}
