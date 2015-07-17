package NAP::Test::Class::PRLMQ::Messages;
use NAP::policy "tt", "role";
with "XTracker::Role::WithSchema";
requires ("send_message", "create_message");

=head1 NAME

NAP::Test::Class::PRLMQ::Messages - Specific PRL messages send and received

=cut

use XTracker::Constants::FromDB qw(
    :flow_status
);
use XTracker::Constants qw(
    :prl_type
);



=head1 METHODS

=head2 send_stock_adjust( %$message_args? ) :

Sent a stock_adjust message with good defaults, overridden by
$message_args.

=cut

sub send_stock_adjust {
    my ($self, $message_args) = @_;

    state $stock_status = $self->schema->resultset("Flow::Status")->find(
        $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
    )->name;

    my $message = {
        prl              => "Full",
        client           => "NAP",
        reason           => "Reason",
        stock_status     => $stock_status,
        stock_correction => $PRL_TYPE__BOOLEAN__TRUE,
        date_time_stamp  => '2012-04-02T13:24:00+0000',
        update_wms       => $PRL_TYPE__BOOLEAN__TRUE,
    };
    $self->send_message(
        $self->create_message(
            "StockAdjust" => {
                %$message,
                %$message_args,
            },
        ),
    );
}

=head2 send_stock_adjust( %$message_args? ) :

Send a stock_adjust message with good defaults, overridden by
$message_args.

=cut

sub send_migration_stock_adjust {
    my ($self, $message_args) = @_;
    $self->send_stock_adjust({
        reason => "MIGRATION",
        %$message_args,
    });
}

=head2 receive_adjust_response( %$message_args? ) :

Receive a stock_adjust message with good defaults, overridden by
$message_args.

=cut

sub receive_adjust_response {
    my ($self, $message_args) = @_;

    $self->send_message(
        $self->create_message(
            AdviceResponse => {
                success      => $message_args->{success} || $PRL_TYPE__BOOLEAN__TRUE,
                container_id => $message_args->{container_id},
                reason       => $message_args->{reason} || "",
            }),
    );
}

