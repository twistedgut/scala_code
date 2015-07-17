package XTracker::Stock::Reservation::Notification;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Navigation;

use XTracker::Config::Local qw( personalshopping_email fashionadvisor_email );
use XTracker::Constants::FromDB qw( :department :correspondence_templates :reservation_status );
use XTracker::Database;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::Database::Customer;
use XTracker::Database::Operator qw( get_operator_by_id );
use XTracker::Database::Product;
use XTracker::Database::Reservation qw( :DEFAULT get_next_upload_variants );
use XTracker::Database::Stock;
use XTracker::EmailFunctions;

use Readonly;

Readonly my $TPL_RESERVATION_NOTIFICATION => 'Reservation Notification';

sub handler {
    my $handler     = XTracker::Handler->new(shift);
    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Upload Notification';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'stocktracker/reservation/notification.tt';

    # customer_id, list type and filter settings from url or set defaults
    $handler->{data}{customer_id}   = $handler->{request}->param('customer_id') || 0;
    $handler->{data}{list_type}     = $handler->{request}->param('list_type') || 'Live';
    $handler->{data}{filter}        = $handler->{request}->param('show') || 'Personal';
    $handler->{data}{channel_id}    = $handler->{request}->param('channel_id') || die 'No channel_id defined';
    $handler->{data}{sales_channel} = $handler->{request}->param('channel') || die 'No channel defined';
    $handler->{data}{channel}       = get_channel_details( $dbh, $handler->{data}{sales_channel} );

    # build side nav
    $handler->{data}{sidenav}   = build_sidenav( {
        navtype     => 'reservations_filter',
        res_list    => $handler->{data}{list_type},
        res_filter  => $handler->{data}{filter},
    } );

    my $channel = $schema->resultset('Public::Channel')->find(
        $handler->{data}{channel_id} );

    # We are going to need a Customer Schema object too
    my $customer_object = $schema->resultset('Public::Customer')->find(
        $handler->{data}{customer_id} );

    # MRP requires a different email subject
    $handler->{data}{email_subject} = $channel->is_on_mrp
                                    ? 'Your MR PORTER reservation'
                                    : 'Your Special Order';

    # get customer and reservation info
    my $customer = get_customer_info( $dbh, $handler->{data}{customer_id} );
    $handler->{data}{customer} = $customer;
    # Mr Porter wants emails to be sent to "Mr. $last_name" or "Ms.
    # $last_name", while NAP(/Outnet) want emails for $first_name
    $handler->{data}{customer}{addressee}
        = $channel->is_on_mrp
        ? ( $customer->{title} eq 'Mr' ? 'Mr' : 'Ms' ) . q{. } . $customer->{last_name}
        : $customer->{first_name};
    $handler->{data}{reservations}  = get_customer_reservation_list( $dbh, $handler->{data}{channel_id}, $handler->{data}{customer_id} );

    # set default 'from' email address for notifications
    $handler->{data}{from_email} = personalshopping_email( $handler->{data}{channel}{config_section}, {
            schema  => $schema,
            locale  => $customer_object->locale,
        });

    # fashion advisors send from a different address
    if ( $handler->{data}{department_id} == $DEPARTMENT__FASHION_ADVISOR ) {
        $handler->{data}{from_email} = fashionadvisor_email(
            $handler->{data}{channel}{config_section}, {
                schema  => $schema,
                locale  => $customer_object->locale,
            } );
    }

    # get list of variants in next upload so we know
    # which reservations to include in email
    # note: this list is now channelised with the first key channel name
    my $next_upload                 = get_next_upload_variants( $dbh );
    $handler->{data}{nextupload}    = $next_upload->{ $handler->{data}{sales_channel} };
    $handler->{data}{nextupload_count} = grep {
        my $r_id = $_;
        grep {
            $_ == $handler->{data}{reservations}{$r_id}{variant_id}
         && $handler->{data}{reservations}{$r_id}{status_id} == $RESERVATION_STATUS__PENDING
        } keys %{$handler->{data}{nextupload}}
    } keys %{$handler->{data}{reservations}};

    # get operator id for reservations
    if ($handler->{data}{reservations}) {
        foreach my $res_id ( keys %{ $handler->{data}{reservations} } ) {
            my $record = $handler->{data}{reservations}{$res_id};
            if ( $record->{status_id} == $RESERVATION_STATUS__PENDING && $handler->{data}{nextupload}{ $record->{variant_id} } ) {
                $handler->{data}{operator_id} = $handler->{data}{reservations}{$res_id}{operator_id};
            }
        }
    }

    # get operator data
    $handler->{data}{operator} = get_operator_by_id( $dbh, $handler->{data}{operator_id} );
    ($handler->{data}{operator}{first_name}, $handler->{data}{operator}{last_name}) = split(/ /, $handler->{data}{operator}{name});


    # MRP always use "Reservation Notification-$channel"
    # On other channels:
    # personal shoppers use "Reservation Notification - Product Advisors-$channel"
    # everyone else uses "Reservation Notification-$channel"
    my $template_name
        = ($handler->{data}{department_id} == $DEPARTMENT__PERSONAL_SHOPPING && !$channel->is_on_mrp)
        ? "$TPL_RESERVATION_NOTIFICATION - Product Advisors-"
        : "$TPL_RESERVATION_NOTIFICATION-";
    $template_name .= $channel->short_name;

    my $email_template = $schema->resultset('Public::CorrespondenceTemplate')
            ->find_by_name( $template_name );

    my $email_template_id = $email_template->id || undef;

    # Generate the email content from the template
    my $email_info = get_and_parse_correspondence_template(
        $schema, $email_template_id, {
            channel     => $channel,
            data        => $handler->{data},
            base_rec    => $customer_object,
        } );

    $handler->{data}{email_body}         = $email_info->{content};
    $handler->{data}{email_content_type} = $email_info->{content_type};
    # If the email returned by the template process contains a subject use that
    if ( exists $email_info->{subject} && $email_info->{subject} ) {
        $handler->{data}{email_subject} = $email_info->{subject};
    }

    # email form submitted
    if ( $handler->{param_of}{email_to} ) {

        # send email
        $handler->{data}{email_sent} = send_customer_email( {
            to          => $handler->{param_of}{email_to},
            from        => $handler->{param_of}{email_from},
            reply_to    => $handler->{param_of}{email_replyto},
            subject     => $handler->{param_of}{email_subject},
            content     => $handler->{param_of}{email_body},
            content_type=> $handler->{param_of}{email_content_type},
        } );

        # update notified date foreach item in email
        foreach my $key ( keys %{ $handler->{param_of} } ) {
            # match reservation products
            if ( $key =~ m/res-/ ) {

                # split out reservation id
                my ($empty, $reservation_id) = split( /-/, $key );

                # set advance contact field for reservation
                update_reservation_advance_contact( $dbh, $reservation_id );

            }
        }

    }

    return $handler->process_template;
}

1;
