package NAP::Carrier::UPS;
use NAP::policy "tt", 'class';
extends 'NAP::Carrier';
with 'XTracker::Role::WithXTLogger';

=head1 NAME

NAP::Carrier::UPS - UPS specific carrier functionality

=head1 SYNOPSIS

B<DO NOT CREATE THIS OBJECT DIRECTLY>. It's intended to be deduced and
magically returned from NAP::Carrier->new()

  use NAP::Carrier;

  my $shipment = function_returning_shipment_using_ups();
  my $nc = NAP::Carrier->new({
    schema      => $schema,
    shipment_id => $shipment->id,
  });

=head1 DESCRIPTION

This module implements the UPS specific methods for the stubs in
L<NAP::Carrier>

=cut

use MooseX::Params::Validate;
use XTracker::Constants::FromDB qw(
    :business
    :shipping_direction
);

has config => (
    is      => 'rw',
    isa     => 'NAP::Carrier::UPS::Config',
    lazy    => 1,
    default => sub {
        my ($self) = @_;

        my $business;
        $business = $self->shipment->get_business() if $self->shipment();
        return ( $business
            ? NAP::Carrier::UPS::Config->new_for_business($business)
            : NAP::Carrier::UPS::Config->new_for_unknown_business()
        );
    },
);

has net_ups => (
    is      => 'rw',
    isa     => 'XT::Net::UPS',
    builder => '_build_net_ups',
    lazy => 1,
);

# This is implemented as a builder method to allow it to be easily overridden
# in test classes. We want to be able to do that to allow us to simulate responses
# from UPS in a dev environment
sub _build_net_ups {
    my $self = shift;

    return XT::Net::UPS->new({
        config      => $self->config,
        shipment    => $self->shipment,
    });
}

has service_errors => (
    is          => 'rw',
    isa         => 'ArrayRef|Undef',
    init_arg    => undef, # stop it being populated by new()
    writer      => '_set_service_errors',
);

has accept_error => (
    is          => 'rw',
    isa         => 'HashRef|Undef',
    init_arg    => undef, # stop it being populated by new()
    writer      => '_set_accept_error',
);

has manifest_pdf_link => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        # logic from XTracker/Order/Fulfilment/Manifest.pm
        return sprintf('/manifest/pdf/%s.pdf', $self->manifest->filename());
    },
);

has manifest_txt_link => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return sprintf('/manifest/txt/%s.%s',
            $self->manifest->filename(),
            ($self->carrier() eq 'UPS' ? 'csv' : 'txt')
        );
    },
);

has ups_address => (
    is      => 'rw',
    isa     => 'Net::UPS::Address',
    writer  => '_set_ups_address',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->prepare_ups_address;
    },
);

no Moose;

use NAP::Carrier::UPS::Config;
use XT::Net::UPS;
use XTracker::Config::Local         qw<config_var config_section_exists config_section>;
use XTracker::Database::Shipment    qw<:carrier_automation>;
use XTracker::Database::Logging     qw<:carrier_automation>;
use Net::UPS::Address;
use Data::Dump qw( pp );
use Carp qw<cluck croak>;

=head1 PUBLIC METHODS

=head2 prepare_ups_address

This prepares a Net::UPS::Address with the shipment's address

=cut
sub prepare_ups_address {
    my $self    = shift;

    # get the latests shipment everything
    $self->shipment->discard_changes;

    my $ship_addr   = $self->shipment->shipment_address;
    my $ups_addr    = Net::UPS::Address->new();

    $ups_addr->city( $ship_addr->towncity );
    $ups_addr->state( $ship_addr->county );
    $ups_addr->postal_code( $ship_addr->postcode );
    # use 2 character country code
    $ups_addr->country_code( $ship_addr->country_ignore_case->code )        if ( $ship_addr->country );

    # Ben to find out if this should be set for ShipConfirm, so should keep
    # the setting consistant at this point
    #$ups_addr->is_residential(1);

    $self->_set_ups_address( $ups_addr );

    return $ups_addr;
}

=head2 validate_address

Validate shipping address via Net::UPS

=cut
sub validate_address {
    my $self    = shift;

    # We do not validate the address for virtual shipments
    return 1 if $self->is_virtual_shipment;

    # set the context for the call if there is one else default
    # to 'address'
    my $context = shift || { context_is => 'address' };

    my $addresses;
    my $av_validated    = 0;

    $self->prepare_ups_address;
    if (not defined $self->ups_address) {
        die "can't validate nothing in validate_address()";
    }

    # initially set the quality rating
    my $av_quality      = 'NOT_SET';
    # get the threshold for successful validation
    my $av_qrt      = $self->config->quality_rating_threshold;

    my $ups = $self->net_ups;
    # clear error string
    $ups->set_error(undef);

    $self->xtlogger->info("About to validate address: " . pp($self->ups_address));
    my $shipment = $self->shipment;
    eval {
        # We're dealing with UPS, so un-validate any previous DHL validation
        # against the shipment
        $shipment->update({destination_code => undef});
        # tolerance of 1 means let everything come back and we can decide
        $addresses = $ups->validate_address($self->ups_address, { tolerance => 1 } );
    };
    if ( (my $e=$@) || (defined $ups->errstr) ) {
        if ( $e ) {
            $self->xtlogger->warn("Unexpected error on address validation for shipment " .  $self->shipment_id . ": $e");
        }
        else {
            $self->xtlogger->warn("Net::UPS error for shipment " . $self->shipment_id . ": " . $ups->errstr);
        }
    } else {
        if ( ref( $addresses ) ne 'ARRAY' ) {
            $self->xtlogger->info("Non Array Response from UPS for shipment " . $self->shipment_id . ": [$addresses]");
        } else {
            $self->xtlogger->info("Array response from UPS for shipment " . $self->shipment_id . " - first row is:" . pp($addresses->[0]) );
        }
    }

    # decide if the address has been successfuly validated
    CASE: {
        # nothing came back
        if ( !defined $addresses ) {
            $self->xtlogger->info("Response empty for shipment " . $self->shipment_id);
            $av_quality      = 'Response empty';
            last CASE;
        }
        # got an error string?
        if ($addresses eq 'No Address Candidate Found') {
            #cluck('No Address Candidate Found');
            $self->xtlogger->info("No Address Candidate Found for shipment " . $self->shipment_id);
            $av_quality      = 'No Address Candidate Found';
            last CASE;
        }
        # didn't get an ARRAY Ref Back
        if ( ref( $addresses ) ne 'ARRAY' ) {
            $self->xtlogger->info("No ARRAY ref for shipment " . $self->shipment_id . " instead we got - [" . $addresses . "]");
            $av_quality      = 'No ARRAY ref';
            last CASE;
        }
        # no address rows came back
        if ( !@{ $addresses } ) {
            $self->xtlogger->info("No Address Rows for shipment " . $self->shipment_id);
            $av_quality      = 'No Address Rows';
            last CASE;
        }
        # quality of best address is below threshold
        if ( $addresses->[0]->quality < $av_qrt ) {
            $self->xtlogger->info("Quality of best address is below threshold for shipment " . $self->shipment_id);
            $av_quality = $addresses->[0]->quality;
            last CASE;
        }
        # got this far then must have validated
        $av_validated   = 1;
        $av_quality     = $addresses->[0]->quality;
        $self->xtlogger->info("Address validated for shipment " . $self->shipment_id . " with a quality of " . $av_quality);
    };

    # set the shipment's QRT rating
    set_shipment_qrt(
                $self->schema->storage->dbh,
                $self->shipment_id,
                $av_quality
            );

    # see whether the shipment can be automated at all
    if ( !$self->deduce_autoable( $context ) ) {
        return 0;
    }

    # if different then change and log the shipment's RTCB value
    if ( $av_validated xor $shipment->is_carrier_automated ) {
        set_carrier_automated(
                $self->schema->storage->dbh,
                $self->shipment_id,
                $av_validated
            );
        log_shipment_rtcb(
                $self->schema->storage->dbh,
                $self->shipment_id,
                $av_validated,
                $self->operator_id,
                "AUTO: Changed because of an Address Validation check with UPS (AV QR: ".( $av_quality ? $av_quality : 'empty' ).")"
            );
    }

    return $av_validated;
}

=head2 is_autoable() : Bool

Does a call to L<XTracker::Schema::Result::Public::Shipment::can_be_carrier_automated>.

=cut
sub is_autoable {
    # make sure shipment is upto date
    return shift->shipment->discard_changes->can_be_carrier_automated;
}


=head2 deduce_autoable

This sets the RTCB field to true if shipment can be automated

=cut
sub deduce_autoable {
    my $self        = shift;
    my $context_is  = shift;    # context for call that is used to set the log message later on
    my $context;

    # get the context for the call
    $context    = ( defined $context_is ? $context_is->{ context_is } : 0 );

    # check to see if this shipment can be automated
    my $result  = $self->is_autoable() || 0;
    my $current = $self->shipment->is_carrier_automated;        # get the current value of the RTCB field

    # look at whether the Carrier Automation State Switch for the
    # Shipment's Sales Channel is allowing us to do Automation anyway

    # get channel for shipment
    my $channel = $self->shipment->shipping_account->channel;
    # determine the state of Carrier Automation
    if ( ( $channel->carrier_automation_is_off )
        || ( $context =~ /^order_importer$/i
            && $channel->carrier_automation_import_off ) ) {
        $context= 'state';  # change the context to 'state' so will always log reason
                            # even if no change in value.
        $result = 0;        # set to be NOT Autoable
    }

    if ( $result != $current || $context eq 'state' ) {
        # set RTCB field to the result of is_autoable and log
        # if value changed

        # set RTCB value
        set_carrier_automated(
                $self->schema->storage->dbh,
                $self->shipment_id,
                $result
            );

        my $msg = "";
        CASE: {
            if ( !$context ) {
                $msg    = "AUTO: Changed After 'is_autoable' TEST";
                last CASE;
            }
            if ( $context =~ /^(address||order_importer)$/i ) {
                $msg    = "AUTO: Changed After 'is_autoable' TEST via Address Validation Check";
                last CASE;
            }
            if ( $context eq 'state' ) {
                $msg    = "STATE: Carrier Automation State is '".$channel->carrier_automation_state."'";
                last CASE;
            }
        }
        # log the change
        log_shipment_rtcb(
                $self->schema->storage->dbh,
                $self->shipment_id,
                $result,
                $self->operator_id,
                $msg,
            );
    }

    return $result;
}


=head2 book_shipment_for_automation

This is the wrapper that books the shipment for carrier automation making the calls to
ShipConfirm and then ShipAccept for both the OUTWARD AND RETURN requests, it then
updates the appropriate fields for the shipment.

Note that if the shipment is not returnable, for example, if all items are hazmat, then
the RETURN request is not made.

=cut
sub book_shipment_for_automation {
    my $self    = shift;

    # get the latest shipment record changes (if any)
    $self->shipment->discard_changes;

    # capture responses for diff requests
    my $outward_response = $self->shipping_request_response();
    my $have_outward_response = defined $outward_response ? 1 : 0;
    my $return_response = $self->shipment->is_returnable ? $self->shipping_request_response( { is_return => 1 } ) : undef;
    my $have_both_responses = $have_outward_response && defined $return_response ? 1 : 0;
    my $have_required_response = $self->shipment->is_returnable ? $have_both_responses : $have_outward_response;

    # if successful then get the appropriate bits out of the responses
    # and store in the appropriate tables & fields for the shipment
    if ( $have_required_response ) {
        # update shipment fields and tables from $outward_response & $return_response
        $self->xtlogger->info("PID:$$ Successful response on shipment : " . $self->shipment_id);

        # TEST TEST TEST
        # in a transaction so it's all or nothing
        $self->schema->txn_do ( sub {
                # update AWB's
                # in the case of a non-returnable shipment, the $return_response will not be defined,
                # so the update uses the default 'none' for the return AWB
                $self->shipment->update( {
                    outward_airway_bill => $outward_response->{ShipmentResults}{ShipmentIdentificationNumber},
                    return_airway_bill  => $return_response->{ShipmentResults}{ShipmentIdentificationNumber} // 'none',
                } );
                # Log UPS response data to investigate bug DCOP-96
                $self->xtlogger->info(
                    sprintf "PID:$$ Saved oawb '%s' rawb '%s' from UPS response",
                    map { $self->shipment->$_ // q{} } qw{outward_airway_bill return_airway_bill},
                );
                # Let's log all the tracking numbers coming back from the
                # response, as well as what we're mapping to our boxes to
                # double-check that all our response items are being logged (in
                # box loop below)
                for my $package ( @{$outward_response->{ShipmentResults}{PackageResults}} ) {
                    $self->xtlogger->info(
                        sprintf "PID:$$ Received box tracking number '%s'",
                            $package->{TrackingNumber} // q{}
                    );
                }
                # update each shipment box's tracking number and label images
                # boxes in the responses should be in same order as in the database
                # note: for a non-returnable shipment, there will not be a return box label image
                my @boxes   = $self->shipment->shipment_boxes->search( undef, { order_by => 'me.id ASC' } )->all;
                foreach my $idx ( 0..$#boxes ) {
                    $boxes[$idx]->update( {
                        tracking_number         => $outward_response->{ShipmentResults}{PackageResults}[$idx]->{TrackingNumber},
                        outward_box_label_image => $outward_response->{ShipmentResults}{PackageResults}[$idx]->{LabelImage}{GraphicImage},
                        return_box_label_image  => $return_response->{ShipmentResults}{PackageResults}[$idx]->{LabelImage}{GraphicImage} // '',
                    } );
                    $self->xtlogger->info(
                        sprintf "PID:$$ Saved box id '%s' with tracking number '%s'",
                        map { $boxes[$idx]->$_ // q{} } qw{id tracking_number}
                    );
                }
        } );
    }
    else {
        # set the shipment back to being MANUAL
        my $status = 0;
        $self->xtlogger->info("PID:$$ Non-successful response on shipment : " . $self->shipment_id);
        $self->xtlogger->info("PID:$$ Setting back to manual");
        # sort out which error it is
        my $error   = ( (defined $self->service_errors && scalar(@{$self->service_errors}) != 0)
                        ? $self->service_errors->[-1]       # the last error
                        : ( defined $self->accept_error
                            ? $self->accept_error
                            : { error => 'Unknown Error', errcode => '102' }        # custom error message
                          )
                      );

        # set RTCB value to being FALSE
        set_carrier_automated(
                $self->schema->storage->dbh,
                $self->shipment_id,
                $status
            );
        # log the change
        log_shipment_rtcb(
                $self->schema->storage->dbh,
                $self->shipment_id,
                $status,
                $self->operator_id,
                'UPS API: '.$error->{errcode}.' - '.$error->{error},
            );

        # paranoia!
        $self->shipment->discard_changes;
    }

    return $have_required_response;
}

=head2 shipping_confirm_request

This deals with:
 - looping through the service codes
 - handling errors (not just "bad service")

=cut
sub shipping_confirm_request {
    my ($self, $attr) = @_;
    $attr //= {};

    # make sure we remove any previous service_errors
    $self->_set_service_errors(undef);

    my $is_return = ($attr->{is_return} ? 1 : 0);

    # Work out the list of services we can request from UPS for this shipment
    my $services_rs = $self->schema->resultset('Public::UpsService')->filter_for_shipment({
        shipment    => $self->shipment(),
        is_return   => $is_return,
    });
    # We might not want to try all the services available
    $services_rs = $services_rs->search({}, { rows => $attr->{max_services_to_attempt} })
        if defined($attr->{max_services_to_attempt});

    my @services = $services_rs->all();

    my ($success, $service_errors) = $self->net_ups->request_shipping_confirm(
        shipment            => $self->shipment(),
        available_services  => \@services,
        is_return           => $is_return,
    );

    # Set error data if we were not successful
    $self->_set_service_errors($service_errors) unless $success;

    return $success;
}

=head2 shipping_accept_request

Handle the call to /ShipAccept must have made a previous succesful
 call to shipping_confirm_request

=cut
sub shipping_accept_request {
    my $self    = shift;
    my $attr    = shift;        # pass any extra args such as "is_return"
                                # more probably useful for debugging

    # somewhere to store an error
    my $accept_error;

    # get the xml sorted out for the call to /ShipAccept
    my $shipaccept_xml  = $self->net_ups->prepare_shipping_accept_xml( $attr );

    if ( !defined $shipaccept_xml ) {
        # set up custom error
        $accept_error   = {
                error       => "no response back from call to prepare_shipping_accept_xml()",
                errcode     => "103",
            };
        # store error for later use
        $self->_set_accept_error( $accept_error );
        return 0;
    }

    # make sure we remove any previous accept_errors
    $self->_set_accept_error(undef);

    # make the UPS-API call, and force PackageResults to be in an array when it comes back
    my $success = $self->net_ups->process_xml_request(
        shipment    => $self->shipment(),
        xml_data    => $shipaccept_xml,
        options     => {
            XMLin => { ForceArray => [ 'PackageResults' ] }
        },
    );

    # if it was a successful call!
    if ( $success ) {
        return 1;
    }

    # if we got this far then we've got an error
    if ( defined $self->net_ups->error ) {
        $accept_error   = {
                error       => $self->net_ups->error,
                errcode     => $self->net_ups->xml_response->{Response}{Error}{ErrorCode},
                proxy       => $self->net_ups->proxy,
                request     => $shipaccept_xml,
                response    => $self->net_ups->xml_response,
                xml         => $self->net_ups->raw_xml,
            };
        # store error for later use
        $self->_set_accept_error( $accept_error );
    }

    return 0;
}

=head2 shipping_request_response

This calls the requests for outward and return requests, depending on the
is_return attribute

=cut

sub shipping_request_response {
    my $self = shift;
    my $attr = shift;
    $attr //= {};

    my $is_return = $attr->{is_return} ? 1 : 0;

    # call to ShipConfirm
    $self->xtlogger->info("PID:$$ ". $is_return ? 'Return confirm' : 'Confirm' . " request for shipment: " . $self->shipment_id);
    return undef unless $self->shipping_confirm_request( { is_return => $is_return } );
    $self->xtlogger->info("PID:$$ " . $is_return ? 'Return accept' : 'Accept' . " request for shipment: " . $self->shipment_id);
    return undef unless $self->shipping_accept_request( { is_return => $is_return } );
    return $self->net_ups->xml_response;
}

=head2 shipping_service_descriptions

Returns an array of carrier shipping service descriptions for the shipment

=cut


sub shipping_service_descriptions {
    my ($self ) = @_;
    return [ map  {$_->description()} $self->schema->resultset('Public::UpsService')->filter_for_shipment({  shipment => $self->shipment, })->all() ] ;

}
