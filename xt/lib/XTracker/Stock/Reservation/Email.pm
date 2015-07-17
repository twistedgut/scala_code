package XTracker::Stock::Reservation::Email;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Navigation;

use XTracker::Database::Reservation qw( :DEFAULT get_notification_reservations :email );
use XTracker::Database::Product;
use XTracker::Database::Customer;
use XTracker::Database::Operator qw( :common );
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::Config::Local qw( personalshopping_email fashionadvisor_email );
use XTracker::Constants::FromDB qw( :department :correspondence_templates );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Customer Notification';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'stocktracker/reservation/email.tt';
    $handler->{data}{css}           = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}            = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    # build side nav
    $handler->{data}{sidenav}   = build_sidenav( { navtype => 'reservations' } );

    # list of operators in same department to build alternative user select box
    $handler->{data}{operators} = get_operator_by_department( $handler->{dbh}, $handler->{data}{department_id} );

    # reset operator id in handler if alternative operator id in URL?
    if ( $handler->{param_of}{'operator_id'} ){
        $handler->{data}{operator_id} = $handler->{param_of}{'operator_id'};
    }

    # get list of reservations to be notified for operator
    my %list;
    my $temp_list = get_notification_reservations( $handler->{dbh}, $handler->{data}{operator_id});

    my $customer_rs = $handler->schema->resultset('Public::Customer');

    foreach my $channel ( keys %{$temp_list} ){

        # get 'from' email address
        my $channel_info = get_channel_details( $handler->{dbh}, $channel );

        foreach my $id ( keys %{ $temp_list->{$channel} } ){

            my $customer_id = $temp_list->{$channel}{$id}{customer_id};
            my $variant_id  = $temp_list->{$channel}{$id}{variant_id};

            # get the Localised From Email Address for the Customer
            my $customer    = $customer_rs->find( $customer_id );
            my $from_email  = get_from_email_address( {
                channel_config  => $channel_info->{config_section},
                department_id   => $handler->{data}{department_id},
                schema          => $handler->schema,
                locale          => $customer->locale,
            } );

            $handler->{data}{list}{ $channel }{ $customer_id }{ $variant_id } = $temp_list->{ $channel }{$id};

            $handler->{data}{customer}{ $channel }{ $customer_id }{channel_id}  = $temp_list->{ $channel }{$id}{channel_id};
            $handler->{data}{customer}{ $channel }{ $customer_id }{title}       = $temp_list->{ $channel }{$id}{title};
            $handler->{data}{customer}{ $channel }{ $customer_id }{first_name}  = $temp_list->{ $channel }{$id}{first_name};
            $handler->{data}{customer}{ $channel }{ $customer_id }{last_name}   = $temp_list->{ $channel }{$id}{last_name};
            $handler->{data}{customer}{ $channel }{ $customer_id }{email}       = $temp_list->{ $channel }{$id}{email};
            $handler->{data}{customer}{ $channel }{ $customer_id }{number}      = $temp_list->{ $channel }{$id}{is_customer_number};
            # Mr Porter wants emails to be sent to "Mr. $last_name" or "Ms.
            # $last_name", while NAP(/Outnet) want emails for $first_name
            $handler->{data}{customer}{ $channel }{ $customer_id }{addressee}
                = $channel_info->{business} eq 'MRPORTER.COM'
                ? ( $temp_list->{$channel}{$id}{title} eq 'Mr' ? 'Mr' : 'Ms' ) . q{. } . $temp_list->{$channel}{$id}{last_name}
                : $temp_list->{$channel}{$id}{first_name};
            $handler->{data}{customer}{ $channel }{ $customer_id }{from_email}  = $from_email;
        }
    }

    return $handler->process_template;
}

1;
