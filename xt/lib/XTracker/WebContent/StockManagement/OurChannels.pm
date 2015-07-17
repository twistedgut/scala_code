package XTracker::WebContent::StockManagement::OurChannels;

use Moose;

with 'XTracker::WebContent::Roles::ContentManager',
    'XTracker::WebContent::Roles::StockManager',
    'XTracker::WebContent::Roles::ReservationManager',
    'XTracker::WebContent::Roles::StockManagerBroadcast',
    'XTracker::Role::WithAMQMessageFactory';
with 'XTracker::WebContent::Roles::StockManagerThatLogs';

use XTracker::Database::Product qw( get_fcp_sku product_present );
use XTracker::Database qw ( get_database_handle );
use XTracker::Database::Utilities qw ( sth_execute_with_error_handling );
use XTracker::Comms::FCP qw ( check_and_update_variant_visibility );
use XTracker::Constants qw( :application :database );
use XTracker::Constants::FromDB qw( :product_channel_transfer_status );
use XTracker::EmailFunctions    qw( send_customer_email );
use XTracker::Config::Local qw( config_var config_section config_section_slurp );
use XTracker::Logfile qw( xt_logger );

use Carp qw( croak );

=head1 NAME

XTracker::WebContent::StockManagement::OurChannels

=head1 DESCRIPTION

Class to update stock on website databases

=cut

# used to store up emails that will be sent when 'commit' is called
has _emails => (
    is          => 'ro',
    isa         => 'ArrayRef[HashRef]',
    init_arg    => undef, # not settable in constructor
    default     => sub {[]},
    traits      => ['Array'],
    handles     => {
        add_to_emails    => 'push',
        get_next_email   => 'shift',
        _clear_emails    => 'clear',
    },
);

has _messages => (
    is          => 'ro',
    isa         => 'ArrayRef[HashRef]',
    init_arg    => undef, # not settable in constructor
    default     => sub {[]},
    traits      => ['Array'],
    handles     => {
        _add_to_messages    => 'push',
        _get_next_message   => 'shift',
        _clear_messages     => 'clear',
    },
);

has _web_dbh => (
    is          => 'ro',
    isa         => 'Object',
    init_arg    => undef, # not settable in constructor
    lazy_build  => 1,
    # we will use the auto-generated predicate '_has_web_dbh'
    # later on to tell if '_web_dbh' was ever actually used
);

sub _build__web_dbh {
    my $self = shift;

    return get_database_handle({
        name => "Web_Live_" .
            $self->schema->resultset('Public::Channel')
                ->find($self->channel_id)->business->config_section,
        type => 'transaction',
    });
}

sub DEMOLISH {
    my ($self, $demolished) = @_;

    return if $demolished; # do nothing if we've already been called
    $self->disconnect;     # Call ->disconnect when our object falls out of scope
}

=head1 METHODS

=head2 is_mychannel

Returns true if this module can handle the channel

=cut

sub is_mychannel {
    my ($class, $channel) = @_;

    # In principle - NAP, Outnet and MrP
    return not $channel->business->fulfilment_only;
}

=head2 stock_update

Update the stock on the web DB (this will be in a transaction)

=cut

sub stock_update {
    my $self = shift;
    my $args = {
        quantity_change => undef,
        variant_id      => undef,
        operator_id     => $APPLICATION_OPERATOR_ID,
        skip_non_live   => 0, # Flag used to only update if product is "live"
        skip_upload_reservations => 0, # Flag used to NOT Auto Upload Reservations
        product_reservation_upload => 0, # Flag to indicate whether this is a reservation upload
        @_
    };

    # Some stock updates are only meant to be sent to the website if the product
    # is live. If the skip_non_live flag is passed in true, we won't send the update
    # unless the product is live.
    if ( $args->{skip_non_live} ) {
        # XXX This really should use DBIC
        my $dbh = $self->schema->storage->dbh;
        return unless product_present($dbh, {
            type       => 'variant_id',
            id         => $args->{variant_id},
            channel_id => $self->{channel_id}
        });
    }

    my $dbh_xt = $self->schema->storage->dbh;
    my $dbh_web = $self->_web_dbh;

    my $variant_id      = $args->{variant_id};
    my $quantity_change = $args->{quantity_change};
    my $updated_by      = $args->{updated_by} || 'XTRACKER - OurChannels::stock_update';

    my $sku = get_fcp_sku( $dbh_xt, { type => 'variant_id', id => $variant_id } );
    my $qry = "UPDATE stock_location SET no_in_stock = no_in_stock + ?, last_updated_by = ? WHERE sku = ?";
    # Update the stock in the remote web-DB,
    # but try twice if it didn't update because the web-DB disconnected
    for (1..2) {
        my $retry;
        # check whether we are expected to die on errors
        my $raise_error = $self->_web_dbh->{RaiseError};
        my $sth = $self->_web_dbh->prepare($qry);
        # does $sth->execute, but also catches timeouts & errors
        sth_execute_with_error_handling(
            # Our error handler prompts another try for disconnections
            # but for other errors we will do as the RaiseError property dictates
            sub {
                shift;
                for (@_) {
                    $retry = 1 if $_ =~ /^$DB_DISCONNECTED_STRING/;
                    xt_logger->logwarn($_);
                }
                # the existing behaviour was to die on the first error
                xt_logger->logdie( $_[0] ) if $raise_error && ! $retry;
            },
            $dbh_web,
            $sth => $quantity_change, $updated_by, $sku,
        );
        last unless $retry;
    }
    # update variant visibility based on SKU stock level
    # unless it's a product resveration upload because, well, it didn't
    # previously in Comms::DataTransfer so it probably shouldn't now
    check_and_update_variant_visibility( $dbh_xt, $dbh_web, $variant_id, $sku )
        unless $args->{product_reservation_upload};

    my $variant = $self->schema->resultset('Public::Variant')->find( $variant_id );
    return      if ( !$variant );       # can't find variant then it's probably a Voucher
                                        # and the below is not relevant

    # get the product's 'product_channel' record to decide
    # if a Channel Transfer has been requested
    my $prod_channel    = $self->channel
                                    ->product_channels->search( { product_id  => $variant->product_id } )
                                        ->first;
    # if that product_channel doesn't exist, don't do anything else.
    die sprintf("sku %s (variant id $variant_id) doesn't exist on channel '%s'. Halting update here.\n", $variant->sku, $self->channel->name) unless $prod_channel;
    # if a Transfer has been requested then don't do anything else
    return if ( $prod_channel->transfer_status_id != $PRODUCT_CHANNEL_TRANSFER_STATUS__NONE );

    # get XT & Web stock levels
    my $xt_stock_level  = $variant->product->get_saleable_item_quantity()
                                                 ->{$self->channel->name}->{$variant_id};
    my $web_stock_level = $self->get_web_stock_level( $sku );

    # work out which is smaller the amount of stock in XT
    # or the amount of Stock on the Website, and use this
    # to find out exactly how much real stock there is
    $quantity_change    = $self->_get_true_qty_change( $quantity_change, $xt_stock_level, $web_stock_level );

    my $stock_used_for_reservations = 0;
    if ( $quantity_change > 0 && !$args->{skip_upload_reservations} ) {
        # only update reservations if Stock went Up
        # and haven't been specifically told not to
        $stock_used_for_reservations    = $self->_auto_upload_pending_reservations( $variant_id, $quantity_change, $args->{operator_id} );
    }

    my $actual_stock_change = $quantity_change - $stock_used_for_reservations;

    if ( $actual_stock_change != 0 ) {
        $self->_add_to_messages( { current => $xt_stock_level,
                                   sku => $sku,
                                   delta => $actual_stock_change,
                                   channel => $self->channel,
                                   type  => 'XT::DC::Messaging::Producer::Stock::LevelChange'
                               }
                             );
    }

    return;
}

=head2 reservation_upload

    $stock_manager->reservation_upload({
        customer_nr => 12345,
        variant_id => 12345,
        pre_order_flag => 1 or 0,
    });

Create or update a reservation on the website for a customer/SKU pair.

=cut

sub reservation_upload {
    my $self = shift;
    my $args = shift || croak 'Argument hashref required';

    for ('customer_nr','variant_id','pre_order_flag') {
        croak "$_ argument required" unless defined $args->{$_};
    }

    my $dbh = $self->schema->storage->dbh;
    my $sku = get_fcp_sku($dbh, { type => 'variant_id', id => $args->{variant_id} });

    # indicates if the Reservation is for a Pre-Order or not
    my $pre_order_flag  = $args->{pre_order_flag};

    # Check if any reservations already exist for this customer/SKU
    my $got = 0;
    my $qry =
        "SELECT reserved_quantity " .
        "FROM simple_reservation " .
        "WHERE customer_id = ? " .
        "AND sku = ?";

    my $sth = $self->_web_dbh->prepare($qry);
    $sth->execute($args->{customer_nr}, $sku);

    while(my $row = $sth->fetchrow_arrayref){
        $got = 1;
    }

    # Reservation already exists, so update the quantity reserved
    if ($got == 1){
        # if it's a Pre-Order then update the Redeemed Quantity by the same
        # amount as the Reserved so it doesn't show up in the Customer's Account
        my $redeemed_str    = ( $pre_order_flag ? 'redeemed_quantity = redeemed_quantity + 1,' : '' );

        my $qry = qq{
            UPDATE simple_reservation
            SET reserved_quantity = reserved_quantity + 1,
                ${redeemed_str}
                status = 'PENDING',
                last_updated_by = 'XTRACKER'
            WHERE customer_id = ?
            AND sku = ?
        };
        my $sth = $self->_web_dbh->prepare($qry);
        $sth->execute($args->{customer_nr}, $sku);
    }
    # Reservation did not exist, this is a new reservation
    else {
        # if it's a Pre-Order then insert the Redeemed Quantity with the same
        # amount as the Reserved so it doesn't show up in the Customer's Account
        my $redeemed_qty    = ( $pre_order_flag ? 1 : 0 );

        my $qry = qq{
            INSERT INTO simple_reservation (
                customer_id,
                sku,
                reserved_quantity,
                redeemed_quantity,
                created_dts,
                last_updated_dts,
                created_by,
                last_updated_by,
                status
            ) VALUES (
                ?,
                ?,
                1,
                ${redeemed_qty},
                current_timestamp,
                current_timestamp,
                'XTRACKER',
                'XTRACKER',
                'PENDING'
            )
        };
        my $sth = $self->_web_dbh->prepare($qry);
        $sth->execute($args->{customer_nr}, $sku);
    }

}

=head2 reservation_cancel

    $stock_manager->reservation_cancel({
        customer_nr => 12345,
        variant_id => 12345,
        pre_order_flag => 1 or 0,
    });

Deletes a reservation on the website for a customer/SKU pair.

=cut

sub reservation_cancel {
    my $self = shift;
    my $args = shift || croak 'Argument hashref required';

    for ( 'customer_nr', 'variant_id', 'pre_order_flag' ) {
        croak "$_ argument required" unless defined $args->{$_};
    }

    my $dbh = $self->schema->storage->dbh;
    my $sku = get_fcp_sku($dbh, { type => 'variant_id', id => $args->{variant_id} });

    # indicates if the Reservation is for a Pre-Order or not
    my $pre_order_flag = $args->{pre_order_flag};

    # if it's a Pre-Order then update the Redeemed Quantity by the same amount as the Reserved
    my $redeemed_str = ( $pre_order_flag ? ', redeemed_quantity = redeemed_quantity - 1' : '' );

    my $qry = qq{
        UPDATE simple_reservation
        SET reserved_quantity = reserved_quantity - 1
            $redeemed_str
        WHERE customer_id = ?
        AND sku = ?
        AND reserved_quantity > 0
    };
    my $sth = $self->_web_dbh->prepare($qry);
    $sth->execute($args->{customer_nr}, $sku);

}

=head2 reservation_update_expiry

    $stock_manager->reservatopm_update_expiry( $reservation );

Given an L<XTracker::Schema::Result::Public::Reservation> update the expiry date for
the reservation on the website.

=cut

sub reservation_update_expiry {
    my $self = shift;
    my $reservation = shift || croak 'Reservation argument required';

    croak "Reservation should be an XTracker::Schema::Result::Public::Reservation row"
        unless ref ( $reservation ) =~ /Public::Reservation/;

    my $sku = $reservation->variant->sku;
    my $is_customer_number = $reservation->customer->is_customer_number;

    # Check that there is a reservation to update
    my $qry =
        "SELECT reserved_quantity " .
        "FROM simple_reservation " .
        "WHERE customer_id = ? " .
        "AND sku = ?";

    my $sth = $self->_web_dbh->prepare($qry);
    $sth->execute($is_customer_number, $sku);

    # Only update web db if we found a reservation
    if ( $sth->fetchrow_arrayref ) {
        $qry = qq{
            UPDATE simple_reservation
            SET expiry_date = ?
            WHERE customer_id = ?
            AND sku = ?
        };
        $sth = $self->_web_dbh->prepare($qry);
        my $expiry_str = $reservation->date_expired->strftime('%F %R');
        $sth->execute($expiry_str, $is_customer_number, $sku);
    }

}

=head2 update_reservation_quantity( $sku, $pws_customer_id, $delta )

Update the reservation quantity for the given reservation.

=cut

sub update_reservation_quantity {
    my ( $self, $sku, $pws_customer_id, $delta ) = @_;

    my $qry = 'UPDATE simple_reservation SET reserved_quantity = reserved_quantity + ? WHERE customer_id = ? AND sku = ?';
    my $sth = $self->_web_dbh->prepare($qry);
    return $sth->execute($delta, $pws_customer_id, $sku);
}

=head2 get_outstanding_reservations_by_sku : { sku => { $customer_id => $quantity } }

Returns the outstanding reservations for this channel.

=cut

sub get_outstanding_reservations_by_sku {
    my ( $self ) = @_;
    my $qry = qq{
        SELECT customer_id,
               sku,
               CAST(reserved_quantity - redeemed_quantity AS signed) AS quantity
          FROM simple_reservation
    };
    my %reservation;
    $reservation{$_->{sku}}{$_->{customer_id}} = $_->{quantity}
        for @{$self->_web_dbh->selectall_arrayref($qry, { Slice => {} })};
    return \%reservation;
}

=head2 get_web_stock_level

    $integer    = $self->get_web_stock_level( $sku );

Returns the Web Stock Level for a SKU.

=cut

sub get_web_stock_level {
    my ( $self, $sku )  = @_;

    my $stock_level = 0;

    my $qry = "SELECT no_in_stock FROM stock_location WHERE sku = ?";
    my $sth = $self->_web_dbh->prepare( $qry );
    $sth->execute( $sku );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $stock_level    = $row->{no_in_stock};
    }

    return $stock_level;
}

=head2 get_all_stock_levels : { sku => $quantity }

Return a hashref with pws stock levels for all skus.

=cut

sub get_all_stock_levels {
    my ( $self ) = @_;

    my $qry = 'SELECT sku, no_in_stock FROM stock_location';
    return { map {
        $_->{sku} => $_->{no_in_stock} || 0,
    } @{$self->_web_dbh->selectall_arrayref($qry, { Slice => {} })} };
}

=head2 _get_true_qty_change

    $integer    = $self->_get_true_qty_change( $qty_change, $xt_stock_level, $web_stock_level );

Work out the True level of stock that can be used to Auto Upload Reservations. Pass in the Original Quantity Change along with the XT & Web Stock Levels.
Then calculate the true amount of stock that can be used by figuring out which stock level (XT or Web) is the lowest and then how much greater than zero
that lowest is. If this value is less than the original quantity change then use this figure instead else use the original quantity. If the true figure
is less than zero the just report zero as there was no change in real stock.

=cut

sub _get_true_qty_change {
    my ( $self, $qty_change, $xt_stock, $web_stock )    = @_;

    # just in case of 'undefs'
    $qty_change //= 0;
    $xt_stock   //= 0;
    $web_stock  //= 0;

    my $lowest_stock= (
                        $xt_stock <= $web_stock
                        ? $xt_stock
                        : $web_stock
                      );
    $lowest_stock   = 0         if ( $lowest_stock < 0 );

    return  (
                $lowest_stock < $qty_change
                ? $lowest_stock
                : $qty_change
            );
}

=head2 _auto_upload_pending_reservations

    $integer    = _auto_upload_pending_reservations( $variant_id, $stock_qty, $operator_id );

This will call the 'XTracker::Schema::ResultSet::Public::Reservation->auto_upload_pending' method to Auto Upload any Reservations with the Stock Increase that has been made.

=cut

sub _auto_upload_pending_reservations {
    my ( $self, $variant_id, $stock_qty, $operator_id ) = @_;

    my $reserv_rs   = $self->schema->resultset('Public::Reservation');
    # will return an integer
    my $stock_used  = $reserv_rs->auto_upload_pending( {
                                                stock_quantity  => $stock_qty,
                                                variant_id      => $variant_id,
                                                operator_id     => $operator_id,
                                                channel         => $self->channel,
                                                stock_manager   => $self,
                                            } );

    return $stock_used;
}


=head2 commit

Commits stock updates to database, and send any corresponding stock level-change messages to the front end.

=cut

sub commit {
    my $self = shift;

    my $rc  = 1;
    $rc = $self->_web_dbh->commit       if ( $self->_has_web_dbh );

    # do post commit stuff;
    $self->_post_commit;

    return $rc;
}

=head2 disconnect

Disconnect from database

=cut

sub disconnect {
    my $self = shift;

    $self->_web_dbh->disconnect         if ( $self->_has_web_dbh );
    $self->_clear_web_dbh;
    $self->_clear_emails;
    $self->_clear_messages;
}

=head2 rollback

Rollback database transaction

=cut

sub rollback {
    my $self = shift;

    my $rc  = 1;
    $rc = $self->_web_dbh->rollback     if ( $self->_has_web_dbh );

    $self->_clear_emails;
    $self->_clear_messages;

    return $rc;
}

=head2 _post_commit

    $self->_post_commit;

Performs what ever needs to happen after '$self->commit' has been called.

Currently:
* Sends Customer Emails about Reservations being Uploaded
* Sends Stock::LevelChange messages to configured topics

=cut

sub _post_commit {
    my $self    = shift;

    # send emails
    $self->_send_emails;
    $self->_send_messages;

    return;
}

=head2 _send_emails

    $self->_send_emails;

Sends each email in the '$self->_emails' array. Each one is done within an 'eval' so failure to send does not crash.

=cut

sub _send_emails {
    my ( $self )    = shift;

    while ( my $email = $self->get_next_email ) {
        eval {
            send_customer_email( $email->{email_params} );
        };
    }

    return;
}


=head2 _send_messages

    $self->_send_messages;

Sends each message in the '$self->_messages' array. Each one is done within an 'eval' so failure to send does not crash.

=cut

sub _send_messages {
    my ( $self )    = shift;

    my $amq = $self->msg_factory;

    while (my $message = $self->_get_next_message) {
        eval {
            my $msg_type = delete $message->{type} || 'XT::DC::Messaging::Producer::Stock::LevelChange';

            $amq->transform_and_send( $msg_type, $message);
        };
    }

    return;
}

=head1 SEE ALSO

L<XTracker::WebContent::StockManagment>,
L<XTracker::WebContent::Roles::StockManager>

=head1 AUTHORS

Andrew Solomon <andrew.solomon@net-a-porter.com>,
Pete Smith <pete.smith@net-a-porter.com>,
Adam Taylor <adam.taylor@net-a-porter.com>,

=cut

1;
