package XTracker::Order::Functions::Email::SendEmail;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Database::Shipment qw( :DEFAULT create_shipment_hold );
use XTracker::Database::Address;
use XTracker::Database::Invoice;
use XTracker::Database::OrderPayment qw( get_order_payment );
use XTracker::Database::Customer;
use XTracker::Database::Channel qw(get_channel_details);
use XT::Domain::Payment;
use XT::Domain::Returns::Email qw( get_order_address_customer_name );
use XTracker::Utilities qw( parse_url );
use XTracker::EmailFunctions;
use XTracker::Constants::FromDB qw( :department :order_status :shipment_status :shipment_item_status :correspondence_templates );
use XTracker::Config::Local qw( customercare_email localreturns_email );
use XTracker::Error qw( xt_warn );


### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    ## no critic(ProhibitDeepNests)

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Send Email';
    $handler->{data}{content}       = 'ordertracker/shared/sendemail.tt';


    # get id of order we're working on and order data for display
    $handler->{data}{order_id}          = $handler->{param_of}{'order_id'};
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};
    $handler->{data}{channel}           = get_channel_details( $handler->{dbh}, $handler->{data}{order}{sales_channel} );
    $handler->{data}{invoice_address}   = get_address_info( $handler->{dbh}, $handler->{data}{order}{invoice_address_id} );
    $handler->{data}{shipments}         = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{customer}          = get_customer_info( $handler->{dbh}, $handler->{data}{order}{customer_id} );
    $handler->{data}{business}          = $handler->{data}{channel}{config_section} eq 'OUTNET' ? 'THE OUTNET' : $handler->{data}{channel}{business};

    my $order  = $handler->schema->resultset('Public::Orders' )->find( $handler->{data}{order_id} );

    $handler->{data}{branded_salutation}= $order->branded_salutation;

    # get the date of last customer email - used in some email templates
    $handler->{data}{last_email_date}   = _get_last_email( $handler->{dbh}, $handler->{data}{order_id} );

    # get shipping address for the order
    foreach my $ship_id ( keys %{ $handler->{data}{shipments} } ) {
        $handler->{data}{shipping_address} = get_address_info( $handler->{dbh}, $handler->{data}{shipments}{$ship_id}{shipment_address_id} );
    }

    # format the order date a bit for display in emails
    ($handler->{data}{order}{date1}, $handler->{data}{order}{date2}) = split(/ /, $handler->{data}{order}{date});
    ($handler->{data}{order}{year}, $handler->{data}{order}{month}, $handler->{data}{order}{day}) = split(/-/, $handler->{data}{order}{date1});
    $handler->{data}{order}{date} = $handler->{data}{order}{day}."-".$handler->{data}{order}{month}."-".$handler->{data}{order}{year};

    # get payment details
    # and map back to old values to save re-writing templates
    $handler->{data}{order_payment} = get_order_payment($handler->{dbh}, $handler->{data}{order_id});

    if ( $handler->{data}{order_payment} ) {
        my $payment_ws = XT::Domain::Payment->new();
        my $payment_info = $payment_ws->getinfo_payment({
            reference => $handler->{data}{order_payment}{preauth_ref},
        });
        if ( my $card_info = $payment_info->{cardInfo} ) {
            $handler->{data}{payment}{type} = uc( $card_info->{cardType} );
            if ( $handler->{data}{payment}{type} eq 'AMEX' ) {
                $handler->{data}{payment}{number} = $card_info->{cardNumberFirstDigit} .'xxxxxxxxxx'. $card_info->{cardNumberLastFourDigits};
            }
            else {
                $handler->{data}{payment}{number} = $card_info->{cardNumberFirstDigit} .'xxxxxxxxxxx'. $card_info->{cardNumberLastFourDigits};
            }
        }
    }

    # where to submit form to
    $handler->{data}{form_submit}       = "$short_url/SendEmail?order_id=$handler->{data}{order_id}";

    # from email addresses out of config file
    $handler->{data}{customercare_email}    = customercare_email( $handler->{data}{channel}{config_section}, {
        # get localised version of Customer Care address
        schema  => $handler->schema,
        locale  => $order->customer->locale,
    } );
    $handler->{data}{premier_email}         = localreturns_email( $handler->{data}{channel}{config_section}, {
        # get localised version of Local Returns address
        schema  => $handler->schema,
        locale  => $order->customer->locale,
    } );

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );




    my $action  = $handler->{param_of}{'action'} // '';
    # email form submitted - send email
    if ( $action eq 'send_email' ){

        if (
            defined $handler->{param_of}{'email_from'}    && $handler->{param_of}{'email_from'}     ne '' &&
            defined $handler->{param_of}{'email_replyto'} && $handler->{param_of}{'email_replyto'}  ne '' &&
            defined $handler->{param_of}{'email_to'}      && $handler->{param_of}{'email_to'}       ne '' &&
            defined $handler->{param_of}{'email_subject'} && $handler->{param_of}{'email_subject'}  ne '' &&
            defined $handler->{param_of}{'email_body'}    && $handler->{param_of}{'email_body'}     ne ''
        ) {

            # send email to customer
            $handler->{data}{email_sent} = send_customer_email( {
                to          => $handler->{param_of}{'email_to'},
                from        => $handler->{param_of}{'email_from'},
                reply_to    => $handler->{param_of}{'email_replyto'},
                subject     => $handler->{param_of}{'email_subject'},
                content     => $handler->{param_of}{'email_body'},
                content_type => $handler->{param_of}{'email_content_type'},
            } );

            # log it if successful
            if ($handler->{data}{email_sent} == 1){
                log_order_email( $handler->{dbh}, $handler->{data}{order_id}, $handler->{param_of}{'template_id'}, $handler->{data}{operator_id} );
            }

            # place shipments on hold for 24 hours automatically for this template
            if ( $handler->{param_of}{'template_id'} == $CORRESPONDENCE_TEMPLATES__ORDERING_FROM_THE_OTHER_SITE_NOTIFICATION_EMAIL__5 ) {

                # loop through each shipment for the order
                foreach my $shipment_id ( keys %{ $handler->{data}{shipments} } ) {

                    # only put it on hold if the status is Processing
                    if ($handler->{data}{shipments}{$shipment_id}{shipment_status_id} == $SHIPMENT_STATUS__PROCESSING){

                        # update shipment status and log it
                        update_shipment_status( $handler->{dbh}, $shipment_id, $SHIPMENT_STATUS__HOLD, $handler->{data}->{operator_id} );

                        # create shipment hold entry
                        create_shipment_hold( $handler->schema,
                                                {   'shipment_id'       => $shipment_id,
                                                    'reason'            => 'Order placed on incorrect website',
                                                    'release_interval'  => '24 hours',
                                                    'comment'           => '',
                                                    'operator_id'       => $handler->{data}{operator_id}
                                                }
                        );
                        my $shipment = $handler->schema->resultset('Public::Shipment')
                            ->find({ id => $shipment_id });
                        if ($shipment->does_iws_know_about_me) {
                            $handler->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentWMSPause', $shipment );
                        }
                    }
                }
            }

        } else {

            xt_warn( 'All fields are required, please check and try again.' );

            $handler->{data}{email}{template_id}    = $handler->{param_of}{'template_id'};
            $handler->{data}{order}{email}          = $handler->{param_of}{'email_to'};
            $handler->{data}{email}{from}           = $handler->{param_of}{'email_from'};
            $handler->{data}{email}{replyto}        = $handler->{param_of}{'email_replyto'};
            $handler->{data}{email}{subject}        = $handler->{param_of}{'email_subject'};
            $handler->{data}{email_info}{content}   = $handler->{param_of}{'email_body'};
            $handler->{data}{email_info}{content_type} = $handler->{param_of}{'email_content_type'};

        }

    }
    # email template selected from list - get template info
    elsif ( $action eq 'preview_email' ){

        # email template id from the form
        $handler->{data}{email}{template_id} = $handler->{param_of}{'template_id'};

        # get the from and reply to address from the config, and set the subject line
        $handler->{data}{email}{from}       = $handler->{data}{customercare_email};
        $handler->{data}{email}{replyto}    = $handler->{data}{customercare_email};

        # get/populate email template
        $handler->{data}{order_number}      = $order->order_nr;     # use a standard placeholder for the Order Number
        $handler->{data}{email_info}        = get_and_parse_correspondence_template(
            $handler->schema,
            $handler->{data}{email}{template_id},
            {
                channel     => $order->channel,
                data        => $handler->{data},
                base_rec    => $order,
            }
        );
        $handler->{data}{email}{subject}    = $handler->{data}{email_info}{subject}                         # use the one from the DB/CMS
                                                || 'Your order - ' . $handler->{data}{order}{order_nr};     # or use the catchall default

        # list of email templates which are related to Premier service - need to switch from address for these
        my %premier_templates = (
            "Premier - Arrange Colection"   => 1,
            "Premier - Arrange Delivery"    => 1,
            "Premier - Collection Arranged" => 1,
            "Premier - Delivery Arranged"   => 1
        );

        # switch from address to premier email address for premier emails
        if ( $premier_templates{ $handler->{data}{email_info}{template_obj}->name } ) {
            $handler->{data}{email}{from}       = $handler->{data}{premier_email};
            $handler->{data}{email}{replyto}    = $handler->{data}{premier_email};
        }

    }
    # no form data - just get list of email templates for the relevant department
    else {

        $handler->{data}{email}{template_id} = 0;

        # switch 'customer care manager' to 'customer care' to get correct email templates
        if ($handler->{data}{department_id} == $DEPARTMENT__CUSTOMER_CARE_MANAGER){
            $handler->{data}{department_id} = $DEPARTMENT__CUSTOMER_CARE;
        }

        # switch 'shipping manager' to 'shipping' to get correct email templates
        if ($handler->{data}{department_id} == $DEPARTMENT__SHIPPING_MANAGER){
            $handler->{data}{department_id} = $DEPARTMENT__SHIPPING;
        }

        # get template list
        $handler->{data}{templates} = list_templates( $handler->{dbh}, $handler->{data}{department_id} );
    }


    return $handler->process_template( undef );
}


### Subroutine : _get_last_email                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _get_last_email {

    my ( $dbh, $id ) = @_;

    my $qry = "SELECT to_char(date, 'DD/MM/YYYY') as date FROM order_email_log WHERE orders_id = ? ORDER BY date DESC LIMIT 1";

    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

     my $row = $sth->fetchrow_hashref();

    return $$row{date};

}

1;
