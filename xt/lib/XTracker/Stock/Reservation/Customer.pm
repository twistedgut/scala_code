package XTracker::Stock::Reservation::Customer;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Error;
use XTracker::Constants::Reservations   qw( :reservation_messages );
use XTracker::Database::Customer        qw( search_customers );
use XTracker::Database::Utilities       qw( :DEFAULT );
use XTracker::Constants::FromDB         qw( :pre_order_status );
use XTracker::Navigation;

sub handler {
    __PACKAGE__->new(XTracker::Handler->new(shift))->process();
}

sub new {
    my ($class, $handler) = @_;

    my $self = {
        handler => $handler
    };

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Customer';
    $handler->{data}{subsubsection} = 'Search';
    $handler->{data}{content}       = 'stocktracker/reservation/customer.tt';
    $handler->{data}{css}           = ['/yui/tabview/assets/skins/sam/tabview.css','/css/reservations.css'];
    $handler->{data}{js}            = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];
    $handler->{data}{sidenav}       = build_sidenav({
        navtype => 'reservations',
        res_filter => 'Personal'
    });

    return bless($self, $class);
}

sub process {
    my ($self) = @_;

    my $handler = $self->{handler};
    my $schema  = $handler->schema;
    my $dbh     = $schema->storage->dbh;

    if ($handler->{param_of}{search}) {
        if ($handler->{param_of}{customer_number} && !is_valid_database_id($handler->{param_of}{customer_number})) {
            xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND);
            return $handler->process_template;
        }

        # TODO: use dbix to find customer?
        $handler->{data}{customers} = search_customers(
            $dbh,
            $handler->{param_of}{customer_number},
            $handler->{param_of}{first_name},
            $handler->{param_of}{last_name},
            $handler->{param_of}{email},
        );
    }
    elsif ($handler->{param_of}{customer_id}) {

        $handler->{data}{customer}      = $schema->resultset('Public::Customer')->find($handler->{param_of}{customer_id});
        $handler->{data}{order_count}   = $handler->{data}{customer}->orders->count();
        $handler->{data}{sales_channel} = $handler->{data}{customer}->channel->name;

        my @reservation_preorder = $handler->{data}{customer}->reservations->search({}, {order_by => {-desc => 'date_created'}})->all;

        #exclude pre-order reservations for reservation tab
        my @clean_reservationlist;
        foreach ( @reservation_preorder) {
            push(@clean_reservationlist, $_) if ( !$_->pre_order_items->count > 0 );
        }
       $handler->{data}{reservations} = [ @clean_reservationlist ];


        $handler->{data}{is_pre_order_active} = $handler->{data}{customer}->channel->is_pre_order_active();

        if ($handler->{data}{customer}->channel->is_pre_order_active()) {
            $handler->{data}{preorders}
                = [$handler->{data}{customer}->pre_orders->search({},
                    {order_by            => {-desc => 'created'}}
                )->all];
        }

        # Pass an aray of reservation statuses that have not been uploaded yet
        # to the template
        $handler->{data}{reservation_statuses}
            = [$schema->resultset('Public::ReservationStatus')->non_uploaded->all];
    }

    return $handler->process_template;
}

1;
