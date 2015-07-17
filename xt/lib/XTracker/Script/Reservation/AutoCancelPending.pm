package XTracker::Script::Reservation::AutoCancelPending;

use NAP::policy "tt", 'class';
extends 'XT::Common::Script';

with map { "XTracker::Script::Feature::$_" } qw(
    SingleInstance
    Schema
    Logger
);

sub log4perl_category { return 'AutoCancelReservations' }

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw(
                                            :reservation_status
                                            :season
                                        );
use XTracker::Database::Reservation     qw( cancel_reservation );
use XTracker::WebContent::StockManagement;


=head1 NAME

  XTracker::Script::Reservation::AutoCancelPending

=head1 SYNOPSIS

  XTracker::Script::Reservation::AutoCancelPending->invoke();

=head1 DESCRIPTION

  Gather all preorders with available items, generate a message to inform the
  web site of these and update the item and preorder statuses to reflect the
  exported status.

=cut

has reservations_for_cancellation => (
    is          => 'rw',
    isa         => 'XTracker::Schema::ResultSet::Public::Reservation',
    lazy_build  => 1,
);

has verbose => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has dryrun => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

=head1 METHODS

=cut

sub _build_reservations_for_cancellation {
    my $self = shift;

    my @args;

    # get the date boundary to check against per Sales Channel
    my $conf_groups = $self->schema->resultset('SystemConfig::ConfigGroup')
                                        ->get_groups( qr/^Reservation$/ );

    GROUP:
    foreach my $group ( @{ $conf_groups } ) {
        # only want Channelised Groups
        next GROUP      if ( !$group->{channel_id} );

        my $boundary    = $self->schema->resultset('SystemConfig::ConfigGroupSetting')
                                        ->config_var( 'Reservation', 'expire_pending_after', $group->{channel_id} );

        push @args, {
                channel_id  => $group->{channel_id},
                date_created=> { '<=' => \"now() - interval '${boundary}'" },
            };
    }

    # if NO Sales Channels have been set then can't run
    if ( !@args ) {
        $self->log_error("No Sales Channels have been Configured for the 'expire_pending_after' setting for 'Reservation' Group");
        return;
    }

    return $self->schema->resultset('Public::Reservation')
                            ->search( \@args )      # specify the Sales Channels to query
                                ->search( {
                                        'me.status_id'      => $RESERVATION_STATUS__PENDING,
                                        'product.season_id' => { '!=' => $SEASON__CONTINUITY },
                                        'pre_order_items.id'=> undef,       # Exclude Reservations for Pre-Orders
                                    },
                                    {
                                        join => [ 'pre_order_items', { variant => 'product' } ],
                                    }
                                );
}

=over 4

=item B<invoke>

Script entry point

=back

=cut

sub invoke {
    my ( $self )        = @_;

    my $counter = 0;

    my %stockmanager_for_channel;

    $self->log_info("Script Started");

    my $reservations_to_cancel  = $self->reservations_for_cancellation;

    while ( my $reservation = $reservations_to_cancel->next ) {

        my $channel_id  = $reservation->channel_id;

        try {
            # set-up a Block so that the code can skip to the
            # end of it without using 'next' for the 'while'
            # loop which causes an 'Exiting eval via next' error
            CANCEL: {
                if ( $self->verbose ) {
                    $self->log_info(
                                        "Reservation Id: " . $reservation->id .
                                        ", Channel Id: " . $channel_id .
                                        ", Customer Nr: " . $reservation->customer->is_customer_number .
                                        ", Status: " . $reservation->status->status .
                                        ", Created Date: " . $reservation->date_created->datetime .
                                        ", SKU: " . $reservation->variant->sku
                                   );
                }

                if ( $reservation->discard_changes->status_id != $RESERVATION_STATUS__PENDING ) {
                    $self->log_error( "Reservation Id: " . $reservation->id . ", NOT in 'Pending' Status but in '" . $reservation->status->status . "'" );
                    last CANCEL;
                }

                if ( $self->dryrun ) {
                    say "DRY-RUN: Would Have Cancelled Reservation Id: " . $reservation->id;
                    $counter++;
                    last CANCEL;
                }

                my $stockmanager    = $stockmanager_for_channel{ $channel_id };
                if ( !$stockmanager ) {
                    $stockmanager   = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                        schema      => $self->schema,
                                                                        channel_id  => $channel_id,
                                                                } );
                    $stockmanager_for_channel{ $channel_id }    = $stockmanager;
                }

                my $current_status_id   = $reservation->status_id;

                $self->schema->txn_do( sub {
                    cancel_reservation(
                                        $self->dbh,
                                        $stockmanager,
                                        {
                                            reservation_id  => $reservation->id,
                                            variant_id      => $reservation->variant_id,
                                            status_id       => $current_status_id,
                                            customer_nr     => $reservation->customer->is_customer_number,
                                            operator_id     => $APPLICATION_OPERATOR_ID,
                                        },
                                      );

                    # now log the Auto-Cancellation
                    $reservation->create_related( 'reservation_auto_change_logs', {
                                                            pre_status_id       => $current_status_id,
                                                            post_status_id      => $RESERVATION_STATUS__CANCELLED,
                                                            operator_id         => $APPLICATION_OPERATOR_ID,
                                                    } );

                    $stockmanager_for_channel{ $channel_id }->commit;
                } );

                $counter++;
            };
        }
        catch {
            $self->log_error( "Error Encountered trying to Cancel Reservation Id: " . $reservation->id . "\n" . $_ );

            my $stockmanager    = $stockmanager_for_channel{ $channel_id };
            $stockmanager->rollback         if ( $stockmanager );
        };
    }

    # disconnect any Stock Manager Objects
    foreach my $stockmanager ( values %stockmanager_for_channel ) {
        $stockmanager->disconnect       if ( $stockmanager );
    }

    $self->log_info( "Reservations Cancelled: ${counter}" );

    return 0;
}

1;
