package XTracker::Schema::Role::RoutingSchedule;
use Moose::Role;


use XTracker::Config::Local             qw( config_section_slurp premier_email );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw(
                                            :branding
                                            :department
                                            :routing_schedule_status
                                            :routing_schedule_type
                                        );
use XTracker::Database::Shipment        qw( get_shipment_item_info );

use XTracker::XTemplate;
use XTracker::EmailFunctions            qw( send_email );

use XT::Correspondence::Method;


=head2 send_routing_schedule_notification

    $boolean    = $self->send_routing_schedule_notification( $amq_msg_factory, $logger );

This will send the Appropriate Notification to the Customer by Email & SMS. Currently used for Premier Deliveries & Collections. If
no AMQ Message Factory is passed in then there will be no SMSs sent.

This won't send a notification to any Customers with a Category of Staff.

This is used by 'Public::Shipment' and 'Public::Return'.

The $logger is optional but must be a 'Log::Log4perl::Logger' class.

=cut

sub send_routing_schedule_notification {
    my ( $self, $msg_factory, $logger ) = @_;

    if ( !$self->_rtschd_can_send_notification ) {
        return 0;
    }

    my $retval  = 0;
    if ( my $what_to_send = $self->_rtschd_decide_what_to_send() ) {

        my $template    = XTracker::XTemplate->template( {
                                PRE_CHOMP  => 0,
                                POST_CHOMP => 1,
                                STRICT => 0,
                            } );

        # loop through each Alert Type and send the Alert
        foreach my $alert_type ( sort keys %{ $what_to_send } ) {
            my $alert           = $what_to_send->{ $alert_type };
            my $alert_content   = $self->_rtschd_build_alert_content( $template, $alert );
            $retval = $self->_rtschd_send_alert( $alert, $alert_content, $msg_factory, $logger );
        }
    }

    return $retval;
}


# determins as to whether a Notification can be sent to a Customer
sub _rtschd_can_send_notification {
    my $self    = shift;

    my $shipment= $self->_rtschd_get_shipment;

    # if the Shipment is NOT for an Order then stop
    if ( !$shipment->order ) {
        return 0;
    }

    # if the Order is for a Staff Member then stop
    if ( $shipment->order->customer->is_category_staff ) {
        return 0;
    }

    # if whatever $self is, is Cancelled then stop
    if ( $self->is_cancelled ) {
        return 0;
    }

    # if $self is a Return then it's fine
    if ( $self->_rtschd_is_return ) {
        return 1;
    }

    # if all of the Items aren't Packed yet then stop
    if ( !$shipment->is_shipment_completely_packed ) {
        return 0;
    }

    return 1;
}

# decides what type of Email/SMS should be sent
# based on the first row of the List of Schedules
sub _rtschd_decide_what_to_send {
    my $self    = shift;

    # get the list of routing schedules
    my $list    = $self->routing_schedules->list_schedules;
    if ( !$list ) {
        # no schedules then nothing to do
        return;
    }

    my $schema  = $self->result_source->schema;

    # get the first row of the schedule list as this is the
    # most current and should form the basis for all decisions
    my $row = $list->[0];

    # if the Task Window is empty
    # or 'TBC' then don't send anything
    if ( !$row->{task_window} || uc( $row->{task_window} ) eq 'TBC' ) {
        return;
    }

    # if there has been any 'Success' rows previously (excluding this row)
    # then don't send any messages regardless of what they are for
    if ( $self->_rtschd_previous_successes( $list ) ) {
        return;
    }

    # if the Row has already had an Alert sent
    # then don't send another one
    if ( $row->{notified} ) {
        return;
    }

    my $channel = $self->_rtschd_get_shipment->get_channel;

    # plain name of the Sales Channel
    my $plain_name  = $channel->branding( $BRANDING__PLAIN_NAME );

    # build up the name of the template to use for the alerts
    my $template_name   = 'Premier - ';
    my $type_name       = $self->_rtschd_type_name( $row );         # Delivery or Collection

    my $email_subject   = "";

    CASE: {
        if ( $row->{success} ) {
            $template_name  .= $type_name . ' Success';
            $email_subject  = "Your $plain_name " . lc( $type_name );
            last CASE;
        }
        if ( $row->{failed} ) {
            # add this to the $row as it will probably be useful at some point
            $row->{number_of_failures}  = $self->_rtschd_number_of_failures( $list );
            $email_subject  = "Your $plain_name " . lc( $type_name );

            if ( $self->_rtschd_is_return ) {
                $template_name  .= $type_name . ' Failed';
                last CASE;
            }

            # decide which type of Delivery Failure Alert to send
            if ( $row->{number_of_failures} >= $self->_rtschd_hold_alert_threshold ) {
                $template_name  .= 'Hold Order ' . $type_name;
            }
            else {
                $template_name  .= $type_name . ' Failed 1st and 2nd Attempt';
            }

            last CASE;
        }

        # just a Schedule Alert
        $template_name  .= 'Order/Exchange Delivery/Collection';
        $email_subject  = "Your $plain_name " . (
                                                $self->_rtschd_is_shipment
                                                ? 'order is on its way'
                                                : 'collection'
                                            );
    };

    my %what_to_send;

    # get the Correspondence Subject & available Correspondence Subject Methods
    my $corr_subject    = $channel->get_correspondence_subject('Premier Delivery');
    my $corr_methods    = $corr_subject->get_enabled_methods;

    # get the Templates for the different Methods of Alert
    # and populate the hash with them, along with the schedule
    my $template_rs = $schema->resultset('Public::CorrespondenceTemplate')->search( { department_id => $DEPARTMENT__SHIPPING } );

    foreach my $corr_method ( values %{ $corr_methods } ) {
        my $method      = uc( $corr_method->{method}->method );     # get the Method's Name
        $method         .= '-PLAIN'     if ( $method eq 'EMAIL' );  # not very nice but might come in useful differing from HTML & PLAIN
        my $template    = $template_rs->search( { name => $template_name . " $method" } )->first;
        if ( $template && $template->content ) {
            $what_to_send{ $method }    = {
                            schedule        => $row,
                            template        => $template,
                            email_subject   => $email_subject,
                            schedule_record => $schema->resultset('Public::RoutingSchedule')->find( $row->{id} ),
                            corr_subject    => $corr_subject,
                            alert_method    => $corr_method->{method},
                            csm_rec         => $corr_method->{csm_rec},
                    };
        }
    }

    return \%what_to_send;
}

# parse an Alert's Template and return the parsed content
sub _rtschd_build_alert_content {
    my ( $self, $template, $alert )     = @_;

    # Build TT Data and then Process the Template requested
    my $tt_data     = $self->_rtschd_build_tt_data_for_alert( $alert );
    my $tt_template = $alert->{template}->content;

    my $tt_out;
    $template->process( \$tt_template, $tt_data, \$tt_out );

    return $tt_out;
}

# send's and logs either an Email or SMS alert
sub _rtschd_send_alert {
    my ( $self, $alert, $content, $msg_factory, $logger )   = @_;

    my $shipment    = $self->_rtschd_get_shipment;
    my $channel     = $shipment->get_channel;

    if ( !$channel->can_premier_send_alert_by( $alert->{alert_method}->method ) ) {
        # Can't send Alerts of this Type System Wide
        return 0;
    }

    if ( $alert->{alert_method}->method eq 'SMS' && !$msg_factory ) {
        # Can't send any SMSs without an AMQ Message Factory
        return 0;
    }

    if ( !$self->can_use_csm( $alert->{corr_subject}, $alert->{alert_method}->id ) ) {
        # Customer has Opted Out of receiving Alerts of this type
        return 0;
    }

    # Based on the Method Type the Correspondence will be sent using the Appropriate Method
    my $corr_method = XT::Correspondence::Method->new( {
                                                    record  => $self,
                                                    csm_rec => $alert->{csm_rec},
                                                    use_to_send => 'Shipment',
                                                    subject => $alert->{email_subject},
                                                    body => $content,
                                                    ( $msg_factory ? ( msg_factory => $msg_factory ) : () ),
                                                    ( $logger ? ( logger => $logger ) : () ),
                                                } );
    if ( $corr_method->send_correspondence() ) {
        $self->log_correspondence( $alert->{template}->id, $APPLICATION_OPERATOR_ID );
        $alert->{schedule_record}->update( { notified => 1 } );
        return 1;
    }
    else {
        return 0;
    }
}

# build up the TT Data used by the TT Documents
sub _rtschd_build_tt_data_for_alert {
    my ( $self, $alert )    = @_;

    my $shipment    = $self->_rtschd_get_shipment;
    my $channel     = $shipment->get_channel;

    my $tt_data = {
            template_type   => 'none',      # so the Template gets parsed properly without anything else being added
            # get the Order Nr. making allowences for Non-Order Shipments
            order_nr        => ( defined $shipment->order ? $shipment->order->order_nr : '' ),
            schedule        => $alert->{schedule},
            schedule_record => $alert->{schedule_record},
            is_return       => $self->_rtschd_is_return,
            is_shipment     => $self->_rtschd_is_shipment,
            base_obj        => $self,
            shipment        => $shipment,
            ship_addr       => $shipment->shipment_address,
            items           => $self->_rtschd_get_shipment_items_for_tt,
            channel         => $channel,
            channel_info    => {
                branding        => $channel->branding,
                salutation      => $shipment->branded_salutation,
                email_address   => config_section_slurp( 'Email_' . $channel->business->config_section ),
                company_detail  => config_section_slurp( 'Company_' . $channel->business->config_section ),
            }
        };

    return $tt_data;
}

# return true if $self is a Return
sub _rtschd_is_return {
    my $self    = shift;
    return ( ref( $self ) =~ /::Public::Return$/ ? 1 : 0 );
}

# return true if $self is a Shipment
sub _rtschd_is_shipment {
    my $self    = shift;
    return ( ref( $self ) =~ /::Public::Shipment$/ ? 1 : 0 );
}

# returns a Shipment object
sub _rtschd_get_shipment {
    my $self    = shift;
    return ( $self->_rtschd_is_shipment ? $self : $self->shipment );
}

# returns the Shipment Items in a manageable way for the TT Documents
sub _rtschd_get_shipment_items_for_tt {
    my $self    = shift;

    my @items;

    my @ship_items;
    if ( $self->_rtschd_is_shipment ) {
        @ship_items = $self->shipment_items
                                ->not_cancelled
                                    ->not_cancel_pending
                                        ->all;
    }
    else {
        # get the Return Items and turn them into Shipment Items
        my @ret_items   = $self->return_items
                                    ->not_cancelled
                                        ->all;
        foreach my $ret_item ( @ret_items ) {
            push @ship_items, $ret_item->shipment_item;
        }
    }

    # get all of the Shipment Items for the Shipment
    my $ship_item_info  = get_shipment_item_info( $self->result_source->schema->storage->dbh, $self->_rtschd_get_shipment->id );

    # get the items into a more manageable format for the TT document
    ITEM:
    foreach my $item ( @ship_items ) {

        # get rid of any Virtual Vouchers
        next ITEM       if ( $item->is_virtual_voucher );

        push @items, {
                    is_voucher  => $item->is_voucher,
                    item_obj    => $item,
                    item_info   => $ship_item_info->{ $item->id },
                };
    }

    return \@items;
}

# return the name of the Type of Schedule: 'Delivery' or 'Collection',
# use this to build up the name of the Email/SMS Template to use
sub _rtschd_type_name {
    my ( $self, $row )  = @_;

    my $type_id     = $row->{routing_schedule_type_id};

    return 'Delivery'       if ( $type_id == $ROUTING_SCHEDULE_TYPE__DELIVERY );
    return 'Collection'     if ( $type_id == $ROUTING_SCHEDULE_TYPE__COLLECTION );

    return '';      # an empty string
}

# returns the Failed Delivery Threshold to then send 'Hold Order' Alert
sub _rtschd_hold_alert_threshold {
    my $self    = shift;
    return $self->_rtschd_get_shipment->get_channel->premier_hold_alert_threshold;
}

# returns the number of 'Failure' outcomes there
# are in the hash returned by '->routing_schedules->list_schedules'
sub _rtschd_number_of_failures {
    my ( $self, $list )     = @_;

    return scalar( grep { $_->{failed} == 1 } @{ $list } );
}

# returns the number of 'Success' outcomes there
# are in the hash returned by '->routing_schedules->list_schedules'
# excluding the current first row should that be a 'Success' one.
sub _rtschd_previous_successes {
    my ( $self, $list )     = @_;

    return 0    if ( !$list );

    my @clone   = @{ $list };       # clone the list because it's going to be changed
    shift @clone;                   # get rid of whatever the first row is
    return scalar( grep { $_->{success} == 1 } @clone );
}


1;
