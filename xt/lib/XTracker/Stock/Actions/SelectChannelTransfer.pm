package XTracker::Stock::Actions::SelectChannelTransfer;

use List::MoreUtils qw(uniq);

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Database::ChannelTransfer qw( select_transfer );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema = $handler->schema;
    my @transfers;
    # loop over form post and 'select' transfers for picking
    foreach my $field ( keys %{$handler->{param_of}} ) {
        if ( $field =~ m/select_(\d+)/ && $handler->{param_of}{$field} == 1) {
            my $transfer_id = $1;
            eval {
                my ( $product_id, $errors ) =
                    select_transfer({
                        operator_id => $handler->{data}{operator_id},
                        transfer_id => $transfer_id,
                        schema => $schema,
                        iws_rollout_phase => $handler->iws_rollout_phase,
                        prl_rollout_phase => $handler->prl_rollout_phase,
                        msg_factory => $handler->msg_factory,
                    });
                if ( $product_id ) {
                    push @transfers, $product_id;
                }
                else {
                    xt_warn( $_ ) for uniq @$errors;
                }
            };

            # Something died unxepectedly (we xt_warn and return without dying
            # for several cases)
            if (my $e = $@) {
                # Prepend a friendlier error message if amq is down
                $e = join( q{ },
                    q{The request was not completed as the message could not},
                    q{be sent. Please contact Service Desk and include the},
                    q{following error:},
                    $e
                ) if $e =~ m{Connection refused};
                xt_warn($e);
            }
        }
    }

    # Only display success message if we have any successful transfers
    xt_success(sprintf(
        'PID%s %s successfully selected for channel transfer',
        @transfers != 1 ? q{s} : q{},
        join( q{, }, sort { $a <=> $b } @transfers )
    )) if @transfers;
    return $handler->redirect_to( '/StockControl/ChannelTransfer' );
}
