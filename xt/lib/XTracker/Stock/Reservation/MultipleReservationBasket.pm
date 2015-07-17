package XTracker::Stock::Reservation::MultipleReservationBasket;

use strict;
use warnings;

use XTracker::Logfile                   qw( xt_logger );
use XTracker::Navigation                qw( build_sidenav );
use XTracker::Image;
use XTracker::Error;
use XTracker::Config::Local;

use XTracker::Database::Reservation     qw( :DEFAULT get_reservation_variants );
use XTracker::Database::Product         qw( :DEFAULT );
use XTracker::Database::Utilities       qw( :DEFAULT );
use XTracker::Database::Customer        qw( get_customer_from_pws );
use XTracker::Database::Stock           qw( :DEFAULT get_saleable_item_quantity get_ordered_item_quantity get_reserved_item_quantity );

use XTracker::Constants::FromDB         qw( :variant_type :reservation_status :reservation_source );
use XTracker::Constants::Reservations   qw( :reservation_messages :reservation_types :pre_order_packaging_types );

use URI::Escape;
use Try::Tiny;

my $logger = xt_logger(__PACKAGE__);

sub handler {
    __PACKAGE__->new(XTracker::Handler->new(shift))->process();
}

sub new {
    my ($class, $handler, $config) = @_;

    my $self = {
        handler => $handler
    };

    $handler->{data}{section}            = 'Reservation';
    $handler->{data}{subsection}         = 'Customer';
    $handler->{data}{subsubsection}      = 'Multiple Reservation Basket';
    $handler->{data}{content}            = 'stocktracker/reservation/multiple_reservation_basket.tt';
    $handler->{data}{js}                 = '/javascript/reservations.js';
    $handler->{data}{css}                = '/css/reservations.css';
    $handler->{data}{sidenav}            = build_sidenav({
        navtype    => 'reservations',
        res_filter => 'Personal'
    });

    return bless($self, $class);
}

sub process {
    my ($self) = @_;

    my $handler    = $self->{handler};
    my $customer   = undef;
    my $channel    = undef;
    my $pre_order  = undef;
    my $variant    = undef;
    my $rtn_url    = 'SelectProducts?pids='.( $handler->{data}{param_of}{pids} ? uri_escape($handler->{data}{param_of}{pids}) : '' );

    # Get customer data
    if ($handler->{param_of}{customer_id}) {
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
        return $handler->redirect_to('/StockControl/Reservation/Customer') if $err;

        $handler->{data}{sales_channel} = $handler->{data}{customer}->channel->name;
        $channel                        = $customer->channel;
        $rtn_url                       .= '&customer_id='.$customer->id;
    }
    else {
        xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND);
        return $handler->redirect_to('/StockControl/Reservation/Customer');
    }

    # Variants
    my @variants = ();
    if ($handler->{param_of}{variants}) {
        if (ref($handler->{param_of}{variants}) eq 'ARRAY') {
            @variants = @{$handler->{param_of}{variants}};
        }
        else {
            push(@variants, $handler->{param_of}{variants});
        }
        $rtn_url .= '&variants='.join('&variants=', @variants);
    }
    else {
        xt_warn($RESERVATION_MESSAGE__NO_PRODUCTS_SELECTED);
        return $handler->redirect_to($rtn_url);
    }

    # Check for reservation source id
    unless ($handler->{param_of}{reservation_source_id}) {
        xt_warn($RESERVATION_MESSAGE__NO_RSV_SRC_SELECTED);
        return $handler->redirect_to($rtn_url);
    }

     unless ($handler->{param_of}{reservation_type_id}) {
            xt_warn($RESERVATION_MESSAGE__NO_RSV_TYPE_SELECTED);
            return $handler->redirect_to($rtn_url);
     }


    # Loop through each variant
    foreach my $variant_id (@variants) {

        # Get variant data
        try {
            $logger->debug('Looking for variant #'.$variant_id);
            $variant = $handler->{schema}->resultset('Public::Variant')->find({id => $variant_id});

            $handler->{data}{variants}{$variant->id}{images} = get_images({
                product_id  => $variant->product_id,
                live        => 1,
                schema      => $handler->{schema},
                business_id => $channel->business_id,
            });

            $handler->{data}{variants}{$variant->id}{data} = {
                variant_id    => $variant->id,
                sku           => $variant->sku,
                id            => $variant->id,
                size          => $variant->size->size,
                designer_size => $variant->designer_size->size,
                designer      => $variant->product->designer->designer,
                name          => $variant->product->name,
            };
        }
        catch {
            delete($handler->{data}{variants}{$variant_id});
            xt_warn(sprintf($RESERVATION_MESSAGE__CANT_FIND_VARIANT, $variant_id));
            $logger->warn($_);
        };

    }

    # Drag the parameters across
    $handler->{data}{params} = $handler->{param_of};

    return $handler->process_template;
}

1;
