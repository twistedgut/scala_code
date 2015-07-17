package XT::Net::UPS;
use Moose;
use MooseX::NonMoose;
extends 'Net::UPS';
with 'XTracker::Role::WithXTLogger';
with 'XTracker::Role::AccessConfig';

use MooseX::Params::Validate;
use Carp qw<cluck>;
use Data::Dump qw(pp);
use XML::Simple qw<XMLin XMLout>;
use Storable 'dclone';

has error => (
    is      => 'rw',
    isa     => 'Str|Undef',
    writer  => 'set_error',
);

has proxy => (
    is      => 'rw',
    isa     => 'Str',
    writer  => 'set_proxy',
);

has config => (
    is          => 'ro',
    isa         => 'NAP::Carrier::UPS::Config',
    required    => 1,
    lazy        => 0,
);

has raw_xml => (
    is          => 'rw',
    isa         => 'Str',
    writer      => '_set_raw_xml',
    init_arg    => undef, # stop people setting it with new()
);

has xml_response => (
    is          => 'rw',
    isa         => 'HashRef|Undef',
    writer      => 'set_xml_response',
);

has shipping_accept_proxy => (
    is          => 'ro',
    isa         => 'Str',
    lazy        => 1,
    default     => sub {
        my $config = shift->config;
        $config->base_url . $config->shipaccept_service;
    }
);

has shipping_confirm_proxy => (
    is          => 'ro',
    isa         => 'Str',
    lazy        => 1,
    default     => sub {
        my $config = shift->config;
        $config->base_url . $config->shipconfirm_service;
    }
);

# As the AV (Address Validation) endpoints are hard-coded in Net::UPS we need
# to override these here until they get update upstream, or even better -
# create a Net::UPS object that accepts base_url as an argument (WHM-2493)
override AV_LIVE_PROXY => sub {
    my $self = shift;
    my $config = $self->config;
    return $config->base_url . $config->av_service;
};
# We don't actually use this UPS service, but let's keep its server up-to-date
# too
override RATE_LIVE_PROXY => sub {
    return shift->config->base_url . '/Rate';
};

no Moose;

sub FOREIGNBUILDARGS {
    my ($self,$args) = @_;
    my $config = $args->{config};

    # see if we are pointing to the live UPS servers
    if ( $config->base_url !~ /wwwcie/ ) {
        # make Net::UPS use the LIVE URL
        Net::UPS->live(1);
    }

    # we need to pass the crappy list args out to Net::UPS
    return (
        $config->username,
        $config->password,
        $config->xml_access_key,
    );
}

# this is sub calls xml_request to make the call
# and then deals with errors & transient errors
# and then decides if the call has been successful or not
sub process_xml_request {
    # The shipment parameter here is only necessary because of the nasty, hacky test code.
    # If someone is brave enough to clear up that test code feel free to remove it!
    my ($self, $shipment, $data, $extra_attr) = validated_list(\@_,
        shipment    => { isa => 'Maybe[XTracker::Schema::Result::Public::Shipment]', optional => 1 },
        xml_data    => { isa => 'HashRef' },
        options     => { isa => 'Maybe[HashRef]', optional => 1 }
    );

    # default the return result to 0
    my $result  = 0;

    # set the retry counter, default to 1
    my $retry_counter   = $self->config->max_retries || 1;

    # loop round making requests
    while ( $retry_counter > 0 ) {

        # make the request to the UPS API
        $self->xml_request( $shipment, $data, $extra_attr );

        # was it successful or not
        if ( $self->xml_response->{Response}{ResponseStatusCode} eq "1" ) {
            # success
            $result = 1;
        }

        # do we have an error?
        # even if successful we might have warnings (which are a type of Error)
        # which we might want to still fail on
        if ( defined $self->error ) {
            # get the error section out of the response
            my $error   = $self->xml_response->{Response}{Error};

            # dump stuff to the logs
            $self->xtlogger->info( ( $shipment ? 'SID:' . $shipment->id : 'NO_SID' ) . " - " .
                                 ( exists( $data->{ShipmentConfirmRequest} ) ? $data->{ShipmentConfirmRequest}{Shipment}{Service}{Code} . " - " : '' ) .
                                 $self->proxy . " - " .
                                 $self->xml_response->{Response}{ResponseStatusCode} . " - " .
                                 $error->{ErrorSeverity} . " - " .
                                 $error->{ErrorCode} . " - " .
                                 $self->error . " - " .
                                 $retry_counter );

            if ( $error->{ErrorSeverity} =~ qr/Transient/i ) {
                # if the error is Transient then see if we should retry
                if ( defined $error->{MinimumRetrySeconds} ) {
                    # if it's not too long to wait
                    if ( $error->{MinimumRetrySeconds} <= $self->config->max_retry_wait_time ) {
                        # sleep the appropriate amount
                        sleep( $error->{MinimumRetrySeconds} )      if ( $error->{MinimumRetrySeconds} );
                    }
                    else {
                        # can't wait that long so lets just quit
                        last;
                    }
                }
                # lets go round again
                $retry_counter--;
                next;
            }

            # this next bit checks the error code against a list of warning error codes that we
            # have decided to fail a request upon even though UPS consider the request a success.
            # even if the error returned is 'Hard' meaning the request was a failure there's no
            # harm in going through this list anyway as the $result will be set to 0 no matter what.

            if ( grep { $error->{ErrorCode} eq $_ } @{ $self->config->fail_warnings } ) {
                # if an error code matches the fail_warnings list then
                # request is still a fail even if it had been returned Successful
                $result = 0;
            }
        }

        # break out of the loop if we've got this far
        last;
    }

    return $result;
}

# stolen in part from Net::UPS::request_rate()
# this is the generic route to making more custom requests
sub xml_request {
    my $self        = shift;
    my $shipment    = shift;
    my $data        = shift;
    my $extra_attr  = shift;
    my ($attr, $response);

    # default attributes - these can be overwritten with $extra_attr values
    $attr = {
        KeepRoot   => 0,
        NoAttr     => 1,
        KeyAttr    => [],
    };

    # extra XML::Simple options for the markup we send to the remote service
    if (not defined $extra_attr->{XMLout}) {
        $extra_attr->{XMLout} = {};
    }
    # extra XML::Simple options for the markup we receive from the remote service
    if (not defined $extra_attr->{XMLin}) {
        $extra_attr->{XMLin} = {};
    }

    # build the request, make request, get response
    eval {
        # build the request
        $self->xtlogger->trace("building request with ".pp( $data ));
        $self->_set_raw_xml(
              $self->access_as_xml
            . XMLout(
                $data,
                %{ $attr },
                XMLDecl     => 0,
                KeepRoot    => 1,
                %{ $extra_attr->{XMLout} },
            )
        );
        $self->xtlogger->trace("built request");

        # clear any previous responses
        $self->set_xml_response(undef);
        # clear any previous errors
        $self->set_error(undef);

    my $response_from_ups = $self->post( $self->proxy, $self->raw_xml );
        $self->xtlogger->trace("building response with $response_from_ups");
        # make the request to the UPS service
        $response = XMLin(
            $response_from_ups,
            %{ $attr },
            %{ $extra_attr->{XMLin} },
        );
        $self->xtlogger->trace("built response");
    };

    # deal with utter failure
    if (my $e = $@) {
        # we need to mock up a fake response otherwise things won't work
        my $error_string;
        if (ref($e)) {
            $self->xtlogger->info("UPS error: ".ref($e));
            if (ref($e) eq 'XML::LibXML::Error') {
                $error_string = $e->dump();
            } else {
                $error_string = "UPS error: ".ref($e);
            }
        } else {
            $self->xtlogger->info("UPS error: $e");
            $error_string = $e;
        }
        $self->set_xml_response({
            Response    => {
                ResponseStatusCode          => 0,
                ResponseStatusDescription   => 'Failure',
                Error   => {
                    ErrorSeverity   => 'Die',                   # custom severity
                    ErrorCode       => '101',                   # custom error code
                    ErrorDescription=> "xml_request DIED: $error_string",  # custom error description
                },
            },
        });
        $self->set_error( $error_string );
        return;
    }

    # store the whole response, even if it's an error it's useful to have access to it
    $self->set_xml_response( $response );

    # deal with errors (if any)
    if (my $error = $response->{Response}{Error}) {
        return $self->set_error( $error->{ErrorDescription} );
    }

    return;
}

sub _shipment_address_details {
    my $self = shift;
    my $shipment = shift;
    my $is_return   = shift || 0;
    my (%data, $shipper, $shipto, $shipfrom);

    my $shipper_number;

    # get shipFrom/shipTo wrt. return status
    # (return makes customer the shipFrom)
    if ( $is_return ) {
        # coming back to us
        $shipfrom       = $shipment->customer_details;
        $shipto         = $shipment->shipper_details;
        $shipper_number = $shipment->shipping_account->return_account_number;
    }
    else {
        # going out to the customer
        $shipfrom       = $shipment->shipper_details;
        $shipto         = $shipment->customer_details;
        $shipper_number = $shipment->shipping_account->shipping_number;
    }

    # shipFrom shouldn't/doesn't have/require email address
    if (exists $shipfrom->{EMailAddress}) {
        delete $shipfrom->{EMailAddress};
    }
    # shipper is always "us", needs some extra information
    $shipper = $shipment->shipper_details;

    # shipper is always "us", needs some extra information
    # needs a ShipperNumber
    $shipper->{ShipperNumber}   = $shipper_number;
    # doesn't need a company name
    delete $shipper->{CompanyName};

    return {
        shipper     => $shipper,
        shipfrom    => $shipfrom,
        shipto      => $shipto,
    };
}

sub prepare_shipping_accept_xml {
    my $self        = shift;
    my $attr        = shift;

    # this may never be needed but might be good for debugging or in the future
    my $is_return   = $attr->{is_return} || 0;

    my %data;

    # if we don't have an xml_response then we couldn't have called ShipConfirm
    # first so we don't have the info needed to populate the ShipAccept request
    if ( not defined $self->xml_response ) {
        cluck "no xml_response set for call to prepare_shipping_accept_xml()";
        return;
    }

    # point to the right place
    $self->set_proxy( $self->shipping_accept_proxy() );

    # build the request up for ShipAccept, it's not that much really
    $data{ShipmentAcceptRequest} = {
        Request => {
            RequestAction           => 'ShipAccept',
            TransactionReference    => $self->xml_response->{Response}{TransactionReference},
        },
        ShipmentDigest  => $self->xml_response->{ShipmentDigest},
    };

    # return the data so it can be used
    return \%data;
}

=head2 request_shipping_confirm

Will iterate through a list of supplied services and in order, request a
shipment be delivered by this service by UPS. On receiving a success, the
method will immediately return.

    param - shipment : DBIC Shipment object that we want to ship
    param - available_services : An arrayref of DBIc UpsService objects that
            represent the services that should be attempted
    param - is_return : (Default=0) Set to 1 if we are requesting a return
            delivery

    return - $success : 1 if a service was accepted, 0 if not
    return - $service_errors : An arrayref error data from rejected services.
            One hashref per service. This will be populated even if $success = 1

=cut

sub request_shipping_confirm {
    my ($self, $shipment, $available_services, $is_return) = validated_list(\@_,
        shipment            => { isa => 'XTracker::Schema::Result::Public::Shipment' },
        available_services  => { isa => 'ArrayRef[XTracker::Schema::Result::Public::UpsService]' },
        is_return           => { isa => 'Bool', default => 0, optional => 1 }
    );

    # make sure we go to the right place
    $self->set_proxy( $self->shipping_confirm_proxy() );

    # The xml will always be the same except for the specific service code
    # (added below)
    my $shipment_confirm_xml = $self->_prepare_shipping_confirm_xml($shipment, $is_return);

    my @service_errors;

    foreach my $shipment_service (@$available_services) {

        # See if this service is available
        $shipment_confirm_xml->{ShipmentConfirmRequest}{Shipment}{Service} = {
            Code        => $shipment_service->code(),
            Description => $shipment_service->description(),
        };

        # make the UPS-API call
        my $success = $self->process_xml_request({
            shipment    => $shipment,
            xml_data    => $shipment_confirm_xml,
        });

        # if it was a successful call!
        return (1, \@service_errors) if $success;

        # we've got an error ... frak
        # still, we probably have other services to try
        if ( defined $self->error ) {
            push @service_errors, {
                error       => $self->error,
                errcode     => $self->xml_response->{Response}{Error}{ErrorCode},
                proxy       => $self->proxy,
                request     => dclone($shipment_confirm_xml),
                response    => dclone($self->xml_response()),
                service     => {
                    code        => $shipment_service->code(),
                    description => $shipment_service->description(),
                },
                xml         => $self->raw_xml,
            };
        }
    }

    # If we get here, that means none of the services were available :(
    return (0, \@service_errors);
}

sub _prepare_shipping_confirm_xml {
    my ($self, $shipment, $is_return) = @_;

    my (%data, $shipping_address_details);

    # get details about Shipper/shipFrom/shipTo
    $shipping_address_details = $self->_shipment_address_details($shipment, $is_return);

    # build the data for the request
    $data{ShipmentConfirmRequest}{Request} = {
        TransactionReference    => {
            # help to ID the shipment. 'RETURN-' when a return
            CustomerContext =>
                  ($is_return ? 'RETURN-' : 'OUTBOUND-')
                . $shipment->id(),
            XpciVersion     => '1.0001',
        },
        RequestAction   => 'ShipConfirm',
        RequestOption   => 'validate', # this will mean request will fail if address problems
    };

    # add basic shipment details
    $data{ShipmentConfirmRequest}{Shipment}{Description} = q{Apparel};
    if ($is_return) {
        $data{ShipmentConfirmRequest}{Shipment}{ReturnService} = {
            Code => '9' # UPS Print Return Label
        }
    }
    # add details about Shipper/shipFrom/shipTo
    # (these are "the right way round" thanks to _shipment_address_details())
    $data{ShipmentConfirmRequest}{Shipment}{Shipper}
        = $shipping_address_details->{shipper};
    $data{ShipmentConfirmRequest}{Shipment}{ShipTo}
        = $shipping_address_details->{shipto};
    $data{ShipmentConfirmRequest}{Shipment}{ShipFrom}
        = $shipping_address_details->{shipfrom};

    # more data for the request
    $data{ShipmentConfirmRequest}{Shipment}{PaymentInformation} = {
        Prepaid => {
            BillShipper => {
                # this should ALWAYS be the same as the Shipper->ShipperNumber shown above
                # base on the shipping account id used for the shipment
                AccountNumber => $shipping_address_details->{shipper}{ShipperNumber},
            },
        },
    };

    $data{ShipmentConfirmRequest}{LabelSpecification} = {
        LabelPrintMethod => {
            Code => 'EPL',           # Out of 'EPL' || 'SPL' || 'ZPL' || 'STAR' || 'GIF'
        },
        # may be able to not have this section if labels default to a particular size
        LabelStockSize => {
            Height  => '4',         # Only valid value if EPL2, ZPL, STARPL or SPL formats
            Width   => '6' || '8',  # Only valid values if EPL2, ZPL, STARPL or SPL formats
        },
    };

    # $data{ShipmentConfirmRequest}{Service} will be prepared/added
    # in request_shipping_confirm when we loop through the available services

    # we need to loop through the shipment_boxes ...
    my @boxes   = $shipment->shipment_boxes->search( undef, { order_by => 'id ASC' } )->all;
    foreach my $box ( @boxes ) {
        my $box_data = {
            Description => "Apparel",
            PackagingType => {
                Code        => '02',
                Description => 'Customer Supplied Package',
            },
            Dimensions => {
                UnitOfMeasurement => {
                    Code => uc($self->get_config_var('Units','dimensions')),
                },
                Length => $box->outer_box->length,
                Width  => $box->outer_box->width,
                Height => $box->outer_box->height,
            },
            PackageWeight => {
                UnitOfMeasurement => {
                    Code => uc($self->get_config_var('Units','weight')),
                },
                Weight => $box->threshold_package_weight,
            },
        };
        if ( !$is_return ) {
            if ( $shipment->is_signature_required ) {
                # Delivery Confirmation Signature Required
                $box_data->{PackageServiceOptions}{DeliveryConfirmation}{DCISType}  = 2;
            }
        }
        push @{ $data{ShipmentConfirmRequest}{Shipment}{Package} }, $box_data;
    }

    # return everything we've prepared
    return \%data;
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
__END__

=pod

=head1 NAME

XT::Net::UPS - (thin) wrapper around Net::UPS

=head1 DESCRIPTION

This module allows us to use the existing features of Net::UPS and slowly
extend it to meet our additional requirements.

=head1 SYNOPSIS

You should never be creating this module directly - it's automatically created
in L<NAP::Carrier::UPS>.

  use XT::Net::UPS;

  my $xnu = XT::Net::UPS->new(
    {
        # required
        config => $config,

        # optional
        shipment => $something->shipment,
    }
  );

=head1 EXAMPLE USAGE

This might be useful for test scripts:

  use XT::Net::UPS;

  # get the config for UPS
  use XTracker::Config::Local qw<config_var config_section_exists>;
  my $business = 'NAP';
  my $blob = config_section_exists(qq{UPS_API_Integration_${business}});
  my $config = NAP::Carrier::UPS::Config->new($blob);

  my $xnu = XT::Net::UPS->new(
    { config => $config }
  );

See C<t/dc2ca/xt.net.ups.t> for more detailed usage.

=head1 METHODS

This module supports all methods available through L<Net::UPS>.

=head2 Additional Methods

The following methods are NAP extensions to the L<Net::UPS> module:

=head3 error

This method gives access to the error descriptopn, as a String, from the most
recent UPS-API call.

Any previous errors are deleted at the start of a new request cycle.

If you require more details about the error, the full XML respose is
accessible via xml_response():

  use Data::Dump qw(pp);

  # UPS call made earlier
  if ($xnu->error) {
    pp $xnu->xml_response;
  }

=head3 process_xml_request($xml_data,$extra_xml_simple_options)

This function is a general helper for making requests to the UPS API. B<You
won't usually call this directly:> instead you will use implemented methods
like L<xml_shipping_accept> and L<xml_shipping_confirm>. It will call the
method L<xml_request> to actually communicate with UPS and then will handle
the response such as transient errors which need retries. It will then
return 1 or 0 to indicate the call was successful.

When implementing methods that call this method the general format is:

    my %data = ( hash => representing, xml => data );
    $self->set_proxy( $self->XXX_proxy() );
    $self->xml_request( \%data );

You can query xml_response() and error() for information about the response.

=head3 xml_request($xml_data,$extra_xml_simple_options)

This function is a general helper for making requests to the UPS API. B<You
won't usually call this directly:> instead it will be called from L<process_xml_request>.

When implementing methods that call this method the general format is:

    my %data = ( hash => representing, xml => data );
    $self->set_proxy( $self->XXX_proxy() );
    $self->xml_request( \%data );

You can query xml_response() and error() for information about the response:

=head3 xml_response

This method gives access to the XML response data, as a HashRef, from the most
recent UPS-API call.

Any previous responses are deleted at the start of a new request cycle.

  # UPS call made earlier
  pp $xnu->xml_response;

=head1 SEE ALSO

L<Net::UPS>

=head1 AUTHOR

Chisel Wright C<< <chisel.wright@net-a-porter.com> >>, Initial release

=cut
