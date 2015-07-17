package XTracker::Stock::Actions::CreateMultipleReservations;

use strict;
use warnings;

use XTracker::Logfile                   qw(xt_logger);
use XTracker::Error;

use XTracker::Constants::FromDB         qw( :reservation_status :pre_order_status :pre_order_item_status );
use XTracker::Constants::Reservations   qw( :reservation_messages :reservation_types );

use XTracker::Database::Reservation     qw( create_reservation );
use XTracker::Database::Utilities       qw( :DEFAULT );

use XTracker::WebContent::StockManagement;

use Try::Tiny;

my $logger = xt_logger(__PACKAGE__);

sub handler {
    __PACKAGE__->new(XTracker::Handler->new(shift(@_), {dbh_type => q{transaction}}))->process();
}

sub new {
    my ($class, $handler) = @_;

    my $self = {
        handler => $handler,
    };

    return bless($self, $class);
}

sub process {
    my ($self) = @_;

    my $handler = $self->{handler};

    my @variants = ();
    my $pre_order;
    my $reservation_source_id;
    my $reservation_type_id;
    my $channel;
    my $customer;
    my $redirect = '/StockControl/Reservation/Customer?';

    if ($handler->{param_of}{pre_order_id}) {
        $logger->debug('A pre_order_id was provided so lets use that');

        my $err;
        try {
            $handler->{data}{pre_order} = $handler->schema->resultset('Public::PreOrder')->find($handler->{param_of}{pre_order_id});
            $pre_order                  = $handler->{data}{pre_order};
            $err = 0;
        }
        catch {
            $logger->warn($_);
            xt_warn($RESERVATION_MESSAGE__PRE_ORDER_NOT_FOUND);
            $err = 1;
        };
        return $handler->redirect_to($redirect) if $err;

        $handler->{data}{sales_channel} = $pre_order->customer->channel->name;
        $handler->{data}{customer}      = $pre_order->customer;
        $customer                       = $pre_order->customer;
        $channel                        = $pre_order->customer->channel;
        $reservation_source_id          = $pre_order->reservation_source_id;
        $reservation_type_id            = $pre_order->reservation_type_id;
        $redirect                      .= 'customer_id='.$pre_order->customer->id; # append, not overwrite
    }
    elsif ($handler->{param_of}{customer_id}) {
        $logger->debug('A customer_id was provided so lets use that');

        my $err;
        try {
            $handler->{data}{customer} = $handler->schema->resultset('Public::Customer')->find($handler->{param_of}{customer_id});
            $customer                  = $handler->{data}{customer};
            $err = 0;
        }
        catch {
            $logger->warn($_);
            xt_warn($RESERVATION_MESSAGE__INVALID_CUSTOMER_ID);
            $err = 1;
        };
        return $handler->redirect_to($redirect) if $err;

        $channel                        = $customer->channel;
        $handler->{data}{sales_channel} = $customer->channel->name;
        $reservation_source_id          = $handler->{param_of}{reservation_source_id};
        $reservation_type_id            = $handler->{param_of}{reservation_type_id};
        $redirect                      .= 'customer_id='.$customer->id; # append, not overwrite
    }
    else {
        xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND);
        return $handler->redirect_to($redirect);
    }

    # Get variants
    if ($pre_order) {
        $logger->debug('Getting variants from pre order');
        my @items = $pre_order->pre_order_items;
        foreach my $item (@items) {
            push(@variants, $item->variant_id);
        }
    }
    elsif ($handler->{param_of}{variants}) {
        $logger->debug('Getting variants from parameter');
        if (ref($handler->{param_of}{variants}) ne 'ARRAY') {
            $handler->{param_of}{variants}  = [$handler->{param_of}{variants}];
        }
        foreach my $variant_id (@{$handler->{param_of}{variants}}) {
            if (is_valid_database_id($variant_id)) {
                push(@variants, $variant_id);
            }
        }
    }
    else {
        xt_warn($RESERVATION_MESSAGE__NOTHING_TO_RESERVE);
        return $handler->redirect_to($redirect);
    }

    my $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
        schema     => $handler->{schema},
        channel_id => $channel->id,
    });

    # Loop through each variant
    foreach my $variant_id (@variants) {

        my $variant;
        my $reservation_id;

        my $skip_next;
        try {
            $variant = $handler->{schema}->resultset('Public::Variant')->find($variant_id);
            $skip_next = 0;
        }
        catch {
            xt_warn(sprintf($RESERVATION_MESSAGE__CANT_FIND_VARIANT_IN_DB, $variant_id));
            $logger->warn($_);
            $skip_next = 1;
        };
        next if $skip_next;

        try {
            $reservation_id = create_reservation(
                $handler->{dbh},
                $stock_manager,
                {
                    customer_id           => $customer->id,
                    customer_nr           => $customer->is_customer_number,
                    first_name            => $customer->first_name,
                    last_name             => $customer->last_name,
                    email                 => $customer->email,
                    channel_id            => $channel->id,
                    channel               => $channel->name,
                    variant_id            => $variant->id,
                    operator_id           => $handler->{data}{operator_id},
                    department_id         => $handler->{data}{department_id},
                    reservation_source_id => $reservation_source_id,
                    reservation_type_id   => $reservation_type_id,
                }
            );

            xt_success(sprintf($RESERVATION_MESSAGE__RESERVATION_SUCCESS, $variant->sku));
            $skip_next = 0;
        }
        catch {
            $stock_manager->rollback();
            $handler->{dbh}->rollback();
            xt_warn(sprintf($RESERVATION_MESSAGE__RESERVATION_FAIL, $variant->id));
            $logger->warn($_);
            $skip_next = 1;
        };
        next if $skip_next;

        if ($pre_order) {
            try {
                my $poi = $handler->{schema}->resultset('Public::PreOrderItem')->search({
                    variant_id   => $variant->id,
                    pre_order_id => $pre_order->id,
                })->first;

                $poi->update({
                    reservation_id           => $reservation_id,
                    pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__COMPLETE
                });

                $logger->debug('Connected reservation item to pre order item');
            }
            catch {
                $logger->warn($_);
            };
        }

        $stock_manager->commit();
        $handler->{dbh}->commit();

    }

    if ($pre_order) {
        return try {
            $pre_order->update({
                pre_order_status_id => $PRE_ORDER_STATUS__COMPLETE,
            });
            $logger->debug('Pre Order status updated');
            return $handler->redirect_to('Complete?pre_order_id='.$pre_order->id);
        }
        catch {
            return $handler->redirect_to($redirect);
        };
    }
    else {
        return $handler->redirect_to($redirect);
    }
}

1;
