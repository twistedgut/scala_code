package XTracker::Stock::Reservation::PreOrderSearch;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Error;
use XTracker::Constants::Reservations   qw( :reservation_messages );
use XTracker::Database::Customer        qw( search_customers );
use XTracker::Database::Utilities       qw( :DEFAULT );
use XTracker::Database::PreOrder        qw( :utils :validation );
use XTracker::Constants::FromDB         qw( :pre_order_status );
use XTracker::Navigation;
use XTracker::Utilities                 qw( :string );

sub handler {
    __PACKAGE__->new(XTracker::Handler->new(shift))->process();
}

sub new {
    my ($class, $handler) = @_;

    my $self = {
        handler => $handler
    };

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Pre-Order';
    $handler->{data}{subsubsection} = 'Search';
    $handler->{data}{content}       = 'stocktracker/reservation/preordersearch.tt';
    $handler->{data}{css}           = ['/yui/tabview/assets/skins/sam/tabview.css','/css/preorder.css'];
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

    if ($handler->{param_of}{search}) {

        my ( $search_customer_number, $search_preorder_number )
            = strip( @{$handler->{param_of}}{ qw( customer_number preorder_number ) } );

        if ( $search_customer_number ) {

            if( !is_valid_database_id($search_customer_number)) {
                xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND);
                return $handler->process_template;
            } else {

                # FCW
                #
                # can't we have the same customer number in different channels?
                # in which case, should we return them all?

                $handler->{data}{customer}      = $schema->resultset('Public::Customer')->search(
                                                      { is_customer_number => $search_customer_number }
                                                  )->first;
                if( $handler->{data}{customer}) {
                    $handler->{data}{sales_channel} =   $handler->{data}{customer}->channel->name;
                    $handler->{data}{preorders}     = [ $handler->{data}{customer}->pre_orders->order_by_created_desc->all ];
                } else {
                    xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND);
                    return $handler->process_template;
                }

            }
        }
        elsif( $search_preorder_number ){
            my $preorder_id = get_pre_order_id_from_number_or_id( $search_preorder_number );

            if( $preorder_id ) {
                my $pre_order = $schema->resultset('Public::PreOrder')->find( $preorder_id );

                if ( $pre_order ){
                    $handler->{data}{preorders}     = [ $pre_order ];
                    $handler->{data}{customer}      =   $pre_order->customer;
                    $handler->{data}{sales_channel} =   $pre_order->channel->name;
                } else {
                    $handler->{data}{no_preorder} = 1;
                }
            } else {
                xt_warn($RESERVATION_MESSAGE__INVALID_PREORDER_NUMBER);
                return $handler->process_template;
            }
        }
    }

    return $handler->process_template;
}

1;
