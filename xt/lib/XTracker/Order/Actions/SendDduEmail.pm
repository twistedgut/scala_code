package XTracker::Order::Actions::SendDduEmail;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database            qw( get_schema_using_dbh );
use XTracker::Database::Channel   qw( get_channel_details );
use XTracker::Config::Local       qw( config_var shipping_email );
use XTracker::Constants::FromDB   qw( :correspondence_templates );
use XTracker::Utilities           qw( url_encode );
use XTracker::Database::Shipment;
use XTracker::Database::Order;
use XTracker::EmailFunctions;
use XTracker::Error;


### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new( $r );

    my $ret_url     = "/Fulfilment/DDU";
    my $email_count = 0;

    my $schema  = $handler->schema;

    # Why are we doing this ?
    foreach my $shipment_id ( keys %{ $handler->{param_of} } ) {
        next if( !defined( $shipment_id ) || ( $shipment_id !~ m/^\d+$/ ) );
        next if( !defined( $handler->{param_of}->{ sprintf( 'order_nr-%s', $shipment_id ) } ) );
        next if( !defined( $handler->{param_of}->{ $shipment_id } ) || ( $handler->{param_of}->{ $shipment_id } !~ m/^(notify|followup)$/ ) );

        # get db info for shipment
        $handler->{data}->{shipment}        = get_shipment_info( $handler->{dbh}, $shipment_id );
        $handler->{data}->{order}           = get_order_info( $handler->{dbh}, $handler->{data}->{shipment}->{orders_id} );
        $handler->{data}->{channel}         = get_channel_details( $handler->{dbh}, $handler->{data}->{order}->{sales_channel} );
        $handler->{data}->{shipping_email}  = shipping_email( $handler->{data}->{channel}->{config_section} );

        # get form submit
        $handler->{data}->{notify}          = $handler->{param_of}->{ $shipment_id };
        $handler->{data}->{email_to}        = $handler->{param_of}->{ sprintf( 'email_to-%s', $shipment_id ) };
        $handler->{data}->{first_name}      = $handler->{param_of}->{ sprintf( 'first_name-%s', $shipment_id ) };
        $handler->{data}->{country}         = $handler->{param_of}->{ sprintf( 'country-%s', $shipment_id ) };
        $handler->{data}->{ddu_email_date}  = $handler->{param_of}->{ sprintf( 'last_email-%s', $shipment_id ) };

        $handler->{data}->{shipment_row}    = $schema->resultset('Public::Shipment')->find( $shipment_id );

        $email_count += send_ddu_email( $schema, $handler->{data}->{shipment_row}, $handler->{data}, $handler->{param_of}->{ $shipment_id } );
    }

    if ( $email_count ) {
        xt_success( sprintf( 'Email%s Sent', ( $email_count > 1 ) ? 's' : '' ) );
    }

    return $handler->redirect_to( $ret_url );
}

1;
