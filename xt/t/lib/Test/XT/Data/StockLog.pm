package Test::XT::Data::StockLog;

use NAP::policy "tt",     qw( test role );

requires 'dbh';
requires 'schema';

#
# Data for Stock Logging
#
use XTracker::Config::Local;
use XTracker::Database::Logging qw(log_delivery log_rtv_stock);
use Test::XTracker::Data;

use Log::Log4perl ':easy';
Log::Log4perl->easy_init({ level => $INFO });

use XTracker::Constants::FromDB qw(
    :delivery_action
    :stock_process_type
    :rtv_action
    :pws_action
);

# Inject data into the log_delivery table
#
sub set_log_delivery {
    my ($self, $args) = @_;

    my $delivery    = $self->purchase_order->stock_orders->first->deliveries->first;

    my $god = $self->schema->resultset('Public::Operator')->search({username => 'it.god'})->first;

    my $delivery_id             = defined $args->{delivery_id}              ? $args->{delivery_id}              : $delivery->id;
    my $delivery_action_check   = defined $args->{delivery_action_check}    ? $args->{delivery_action_check}    : $DELIVERY_ACTION__CHECK;
    my $quantity                = defined $args->{quantity}                 ? $args->{quantity}                 : 1;
    my $operator_id             = defined $args->{operator_id}              ? $args->{operator_id}              : $god->id;
    my $type_id                 = defined $args->{type_id}                  ? $args->{type_id}                  : $STOCK_PROCESS_TYPE__MAIN;

    log_delivery( $self->dbh, {
        delivery_id => $delivery_id,
        action      => $delivery_action_check,
        quantity    => $quantity,
        operator    => $operator_id,
        type_id     => $type_id,
    } );

    return $self;
}

# Inject data into the log_rtv_stock table
#
sub set_log_rtv_stock {
    my ($self, $args) = @_;

    my $channel_id      = $self->channel->id;
    my $god             = $self->schema->resultset('Public::Operator')->search({username => 'it.god'})->first;
    my $variant_id      = $self->stock_order->stock_order_items->first->variant_id;

    $args->{operator_id}    = $god->id      if ! defined $args->{operator_id};
    $args->{channel_id}     = $channel_id   if ! defined $args->{channel_id};
    $args->{quantity}       = 1             if ! defined $args->{quantity};
    $args->{notes}          = 'A Note'      if ! defined $args->{notes};
    $args->{variant_id}     = $variant_id   if ! defined $args->{variant_id};
    $args->{rtv_action_id}  = $RTV_ACTION__QUARANTINE_RTV if ! defined $args->{rtv_action_id};
    $args->{dbh}            = $self->dbh;

    log_rtv_stock( $args );

    return $self;
}

# Inject data into the log_pws_stock table
#
sub set_log_pws_stock {
    my ($self, $args) = @_;

    my $channel_id      = $self->channel->id;
    my $god             = $self->schema->resultset('Public::Operator')->search({username => 'it.god'})->first;
    my $variant_id      = $self->stock_order->stock_order_items->first->variant_id;

    $args->{variant_id}     = $variant_id   if ! defined $args->{variant_id};

    $args->{quantity}       = 1             if ! defined $args->{quantity};
    $args->{operator_id}    = $god->id      if ! defined $args->{operator_id};
    $args->{notes}          = 'A Note'      if ! defined $args->{notes};
    $args->{channel_id}     = $channel_id   if ! defined $args->{channel_id};
    $args->{pws_action_id}         = $PWS_ACTION__QUARANTINED if ! defined $args->{action};

    $self->schema->resultset('Public::LogPwsStock')->log_stock_change($args);

    return $self;
}

1;
