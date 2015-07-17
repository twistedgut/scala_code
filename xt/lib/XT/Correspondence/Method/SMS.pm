package XT::Correspondence::Method::SMS;

use NAP::policy "tt",     'class';

extends 'XT::Correspondence::Method';

=head1 XT::Correspondence::Method::SMS

This is the Class used to send SMS Messages, it extends 'XT::Correspondence::Method'.

    my $corr_sms_obj    = XT::Correspondence::Method->new( {
                                                    # see 'XT::Correspondence::Method' for details of the
                                                    # arguments required for all 'X::C::Method' Classes
                                                    csm_rec     => $correspondence_subject_method record
                                                    record      => The record used as a basis for sending the Correspondence
                                                    use_to_send => The Class such as 'Shipment' or 'Order' to use as a basis to find
                                                                   the correct Email or Mobile number to send the Correspondence to
                                                    body        => The body of the Message that will be sent
                                            } );

Without passing the 'mobile_number' in directly it will use the 'use_to_send' Class to get it.


First done for CANDO-576.

=cut

use MooseX::Types::Moose qw( Object );
use XT::Data::Types;

use XTracker::Constants::FromDB     qw( :branding :sms_correspondence_status );
use XTracker::Config::Local         qw( config_var );


=head1 ATTRIBUTES

This Class has the following Attributes.

=cut

=head2 mobile_number

The Mobile Number the SMS will be sent to.

Will be derived from 'use_to_send' record unless it is passed in directly to 'new()'.

=cut

has mobile_number => (
    is          => 'rw',
    isa         => 'Str',
    init_arg    => 'mobile_number',
    lazy_build  => 1,
);

=head2 sender_id

The Sender Id of the SMS Message, this is what should appear in the Customer's phone as who the Message is From.

Will be derived from the Sales Channel unless passed in directly to 'new()'.

=cut

has sender_id => (
    is          => 'rw',
    isa         => 'Str',
    init_arg    => 'sender_id',
    lazy_build  => 1,
);


# do some validation for some of the Args.
sub BUILD {
    my ( $self, $args ) = @_;

    # if the 'mobile_number' has not been
    # explicitly passed in then check that
    # the 'send_record' can call 'get_phone_number'
    if ( !$args->{mobile_number} ) {
        if ( !$self->send_record->can('get_phone_number') ) {
            croak "'send_record/use_to_send' passed in '" . ref( $self->send_record ) . "' can't call method 'get_phone_number' for '" . __PACKAGE__ . "'";
        }
    }

    return $self;
};

=head1 METHODS

Here are the Methods for this Class.

=cut

=head2 send_correspondence

    $boolean    = $self->send_correspondence();

Will Send an SMS request to the SMS Proxy.

Will return TRUE or FALSE if it succeeded in doing this.

=cut

sub send_correspondence {
    my $self    = shift;

    my $result  = 0;
    my $err_code;

    # create an 'sms_correspondence' record
    # which will be updated later if any errors
    my $sms_rec = $self->_create_sms_correspondence_rec;

    # check if everything is ok to send
    if ( $self->_ok_to_send ) {
        # send using AMQ
        eval {
            $self->msg_factory->transform_and_send( 'XT::DC::Messaging::Producer::Correspondence::SMS', {
                                                    message_id  => 'CSM-' . $sms_rec->id,
                                                    channel     => $self->channel,
                                                    message     => $self->body,
                                                    phone       => $self->mobile_number,
                                                    from        => $self->sender_id,
                                                } );
            $result = 1;
            if ( $self->need_to_copy_to_crm ) {
                $self->copy_to_crm;
            }
        };
        if ( my $err = $@ ) {
            $self->_failure_code('COULD_NOT_SEND_TO_AMQ');
            $self->logger->warn( "Failed to Send an SMS to '" . $self->mobile_number . "' in '" . __PACKAGE__ . "' with the following error:\n$err" );
        }
    }

    # if any errors then update the 'sms_rec'
    if ( !$result ) {
        $sms_rec->update( {
                        failure_code => $self->_failure_code,
                        sms_correspondence_status_id => $SMS_CORRESPONDENCE_STATUS__NOT_SENT_TO_PROXY,
                    } );
        eval {
            $sms_rec->discard_changes->send_failure_alert;
        };
        if ( my $err = $@ ) {
            $self->logger->warn( "Couldn't Send SMS Failure Alert for '" . $self->mobile_number . "' in '"  . __PACKAGE__ . "' with the following error:\n$err" );
        }
    }

    return $result;
}

=head2 copy_to_crm

    $self->copy_to_crm();

This method is a 'before' in Moose terms and will populate the parental '_copy_to_crm_data' attribute
before the parents 'copy_to_crm' is called.

=cut

before copy_to_crm => sub {
    my $self    = shift;

    # make up the from address;
    my $email_from  = $self->mobile_number;
    $email_from     =~ s/[^\d]//g;
    my $crm_suffix  = config_var( 'DistributionCentre', 'crm_sms_suffix' );

    my $data    = {
            order       => $self->base_record->next_in_hierarchy_from_class( 'Orders', { stop_if_me => 1 } ),
            customer    => $self->base_record->next_in_hierarchy_from_class( 'Customer', { stop_if_me => 1 } ),
            shipment    => $self->base_record->next_in_hierarchy_from_class( 'Shipment', { stop_if_me => 1 } ),
            email_from  => ( $email_from && $crm_suffix ? "${email_from}\@${crm_suffix}" : "" ),
            template    => 'crm_sms.tt',
        };

    $self->_copy_to_crm_data( $data );

    return;
};


# Get a Mobile Number
sub _build_mobile_number {
    my $self    = shift;

    my $mobile;

    # if shipment is 'Premier' then get a mobile for that type
    if ( $self->_class_isa( $self->send_record, 'Shipment' ) && $self->send_record->is_premier ) {
        $mobile = $self->send_record->premier_mobile_number_for_SMS();
    }
    else {
        # get a mobile number
        $mobile  = $self->send_record->get_phone_number( { start_with => 'mobile' } );
    }

    return $mobile || "";
}

# get the Sender Id for the Sales Channel
sub _build_sender_id {
    my $self    = shift;
    return $self->channel->branding( $BRANDING__SMS_SENDER_ID );
}

# create an 'sms_correspondence' record and link
# it to the 'base_record'
sub _create_sms_correspondence_rec {
    my $self    = shift;

    # get a link relationship to the 'base_record'
    my ( $link_relation )   = grep { /^link_sms_correspondence__/ } $self->base_record->result_source->relationships;
    if ( !$link_relation ) {
        croak "Can't find a Relationship to the 'sms_correspondence' table, expected 'link_sms_correspondence__*' for '" . ref( $self->base_record ) . "' in '" . __PACKAGE__ . "->_create_sms_correspondence_rec'";
    }

    my $sms_rec = $self->csm_rec->create_related( 'sms_correspondences', {
                                        mobile_number   => $self->mobile_number || "",
                                        message         => $self->body,
                                        sms_correspondence_status_id => $SMS_CORRESPONDENCE_STATUS__PENDING,
                                    } );
    $self->base_record->$link_relation->create( { sms_correspondence_id => $sms_rec->id } );

    return $sms_rec;
}

# check whether it is ok to send an SMS
around _ok_to_send => sub {
    my ( $orig, $self ) = @_;

    if ( !$self->mobile_number ) {
        $self->_failure_code('NO_MOBILE_NUMBER');
        return 0;
    }

    if ( !$self->body ) {
        $self->_failure_code('NO_MESSAGE_BODY');
        return 0;
    }

    return $self->$orig();
};

1;
