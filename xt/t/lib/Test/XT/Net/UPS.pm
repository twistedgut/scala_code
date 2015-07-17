package Test::XT::Net::UPS;

use Moose;
use MooseX::Types::Moose        qw( Str Int ArrayRef HashRef Undef );
use MooseX::Types::Structured   qw( Dict );

use feature 'switch';

use Data::Dump  qw( pp );

=head1

 Test::XT::Net::UPS - Library which extends XT::Net::UPS

This is used to test the method 'process_xml_request' which is in XT::Net::UPS by replacing the 'xml_request' method with one that can simulate a success or failure of a request to the UPS API to help prove that 'process_xml_request' is behaving correctly. 'process_xml_request' is also overloaded and if being called through this package then just calls it's parent, else is used for tests in conjunction with Test::NAP::Carrier::UPS.

=cut

extends 'XT::Net::UPS';

# used to tell 'xml_request' how to behave
has simulate_response => (
    is          => 'rw',
    isa         => Str,
    required    => 1,
);

# used to tell 'xml_request' on which call to fail on
has simulate_fail_onattempt => (
    is          => 'rw',
    isa         => Undef|Int,
    default     => undef,
);

# used to tell the '_response_success' which response to give
# such as 'Success' or 'Failure' etc.
has setup_mass_responses => (
    is          => 'rw',
    isa         => Undef|ArrayRef,
);

# used to tell the '_response_success' method which XML responses to give for
# successive calls, used inconjunction with 'simulate_mass_response'
has setup_mass_xml_responses => (
    is          => 'rw',
    isa         => Undef|ArrayRef,
);

# used to tell which part of the request to store
has test_request_part => (
    is          => 'rw',
    isa         => Str|Undef,
    writer      => 'set_test_request_part',
);

# used to store part of each request made
has test_request => (
    is          => 'rw',
    isa         => 'ArrayRef|Undef',
);

# used to compare what is returned with what should have been returned
# in 'xml_response'
has test_xml_response => (
    is          => 'rw',
    isa         => HashRef|Undef,
    writer      => 'set_test_xml_response',
);

# used to compare what is returned with what should have been returned
# in 'error'
has test_error => (
    is          => 'rw',
    isa         => Str|Undef,
    writer      => 'set_test_error',
);

# a counter that monitors each time a call
# to xml_request has been made
has test_call_counter => (
    is          => 'rw',
    isa         => Int,
    default     => 0,
    writer      => 'set_test_call_counter',
);

# use this to configure what to do when simulating
# Tranisent (retry) errors
has test_when_retry => (
    is          => 'rw',
    isa         => Undef|Dict[
                        on_attempt      => Int,
                        give_response   => Str,
                        retry_seconds   => Int,
                    ],
);

# use this to give a Success response after X amounts
# of attempts
has test_succeed_onattempt => (
    is          => 'rw',
    isa         => Undef|Int,
    default     => undef,
);

# used to supply a useful successfult response
# when you want a call to be Successful
has response_with_success => (
    is          => 'rw',
    isa         => Undef|HashRef,
    writer      => 'set_response_with_success',
    default     => undef,
);

# This is a nasty hack because my brain is beginning to hurt... :( We basically
# flag what XML we're preparing (see XT::Net::UPS::prepare_shipping_accept_xml)
# so we can provide the appropriate XML in our response
has expected_success_response => (
    is => 'rw',
    isa => 'Str',
    clearer => 'clear_expected_success_response',
);
after 'prepare_shipping_accept_xml' => sub {
    my ( $self, $args ) = @_;
    my $expected_response = $args->{is_return} ? 'return' : 'outbound';
    $self->expected_success_response($expected_response);
};

# We use this singleton to generate an integer to create values that need to be
# unique
{
my $sequence = 0;
has sequence => (
    is => 'ro',
    default => sub { ++$sequence; },
);
around 'sequence' => sub { return ++$sequence; };
}

# routine that replaces the one in 'XT::Net::UPS'
override 'xml_request' => sub {
    my $self        = shift;
    my $shipment    = shift;
    my $data        = shift;
    my $extra_attr  = shift;

    my $response    = {};

    if ( defined $self->test_request_part ) {
        # store request
        $self->test_request( [] )       if ( !defined $self->test_request );
        my %store;
        ## no critic(ProhibitStringyEval)
        eval( '%store = %{ $data->'.$self->test_request_part.' };' );
        push @{ $self->test_request }, \%store;
    }

    # clear response and error
    $self->set_xml_response(undef);
    $self->set_error(undef);

    # clear test response and error
    $self->set_test_xml_response(undef);
    $self->set_test_error(undef);
    $self->set_test_call_counter( $self->test_call_counter + 1 );

    # if test_succeed_onattempt is set then set the next response to be
    # successful if we have reached that point yet
    if ( defined $self->test_succeed_onattempt && $self->test_succeed_onattempt > 0
         && $self->test_call_counter >= $self->test_succeed_onattempt ) {
        $self->simulate_response( 'Success' );
    }

    # if setup_mass_responses is defined then set the response to give
    if ( defined $self->setup_mass_responses ) {
        my $response    = shift @{ $self->setup_mass_responses };
        $self->simulate_response( $response );
    }

    # if setup_mass_responses is defined then set-up which additonal success response
    # we should server up
    if ( defined $self->setup_mass_xml_responses ) {
        my $method  = shift @{ $self->setup_mass_xml_responses };
        $self->$method($shipment);
    }

    # if simulate_fail_onattempt is set then set the next response
    # to be failed if we are there yet
    if ( defined $self->simulate_fail_onattempt && $self->simulate_fail_onattempt > 0
         && $self->test_call_counter >= $self->simulate_fail_onattempt ) {
        $self->simulate_response( 'Failure' );
    }

    SMARTMATCH: {
        use experimental 'smartmatch';
        given ( $self->expected_success_response ) {
            when ( 'return' ) { $self->response_success_for_accept_return($shipment); }
            when ( 'outbound' ) { $self->response_success_for_accept_outbound($shipment); }
        }
    }

    CASE: {
        if ( $self->simulate_response eq 'Success' ) {
            $self->_response_success();
            last CASE;
        }
        if ( $self->simulate_response eq 'Failure' ) {
            $self->_response_failure();
            last CASE;
        }
        if ( $self->simulate_response eq 'WarningSuccess' ) {
            $self->_response_warning_success();
            last CASE;
        }
        if ( $self->simulate_response eq 'WarningFailure' ) {
            $self->_response_warning_failure();
            last CASE;
        }
        if ( $self->simulate_response eq 'Die' ) {
            $self->_response_die();
            last CASE;
        }
        if ( $self->simulate_response eq 'Retry' ) {
            $self->_response_retry();
            last CASE;
        }
    };

    return;
};

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

use MIME::Base64;

# --------------------------------------
# helper methods to return the correct response for xml_request

sub _response_success {
    my $self        = shift;

    my %response    = (
        Response    => {
            ResponseStatusCode          => 1,
            ResponseStatusDescription   => 'Success',
        }
    );
    # if we want to simulate a success response with useful test data
    if ( defined $self->response_with_success ) {
        %response   = ( %response, %{ $self->response_with_success } );
    }

    $self->set_xml_response( \%response );
    $self->set_test_xml_response( \%response );

    return;
}

sub _response_failure {
    my $self        = shift;

    my %response    = (
        Response    => {
            ResponseStatusCode          => 0,
            ResponseStatusDescription   => 'Failure',
            Error   => {
                ErrorSeverity   => 'Hard',
                ErrorCode       => '1020' . $self->test_call_counter,
                ErrorDescription=> 'Test Hard Error '.$self->test_call_counter,
            },
        },
    );

    $self->set_xml_response( \%response );
    $self->set_error( $response{Response}{Error}{ErrorDescription} );

    $self->set_test_xml_response( \%response );
    $self->set_test_error( $response{Response}{Error}{ErrorDescription} );

    return;
}

sub _response_warning_success {
    my $self        = shift;

    my %response    = (
        Response    => {
            ResponseStatusCode          => 1,
            ResponseStatusDescription   => 'Success',
            Error   => {
                ErrorSeverity   => 'Warning',
                ErrorCode       => '11111',
                ErrorDescription=> 'Test Warning Error that should Succeed',
            },
        },
    );

    $self->set_xml_response( \%response );
    $self->set_error( $response{Response}{Error}{ErrorDescription} );

    $self->set_test_xml_response( \%response );
    $self->set_test_error( $response{Response}{Error}{ErrorDescription} );

    return;
}

sub _response_warning_failure {
    my $self        = shift;

    my %response    = (
        Response    => {
            ResponseStatusCode          => 1,
            ResponseStatusDescription   => 'Success',
            Error   => {
                ErrorSeverity   => 'Warning',
                ErrorCode       => $self->config->fail_warnings->[0],
                ErrorDescription=> 'Test Warning Error that should NOT Succeed',
            },
        },
    );

    $self->set_xml_response( \%response );
    $self->set_error( $response{Response}{Error}{ErrorDescription} );

    $self->set_test_xml_response( \%response );
    $self->set_test_error( $response{Response}{Error}{ErrorDescription} );

    return;
}

sub _response_die {
    my $self        = shift;

    my %response    = (
        Response    => {
            ResponseStatusCode          => 0,
            ResponseStatusDescription   => 'Failure',
            Error   => {
                ErrorSeverity   => 'Die',
                ErrorCode       => '101',
                ErrorDescription=> 'Test Die Error that should NOT Succeed',
            },
        },
    );

    eval {
        die "DIE ERROR";
    };
    if ( my $e = $@ ) {
        $self->set_xml_response( \%response );
        $self->set_error( $e );

        $self->set_test_xml_response( \%response );
        $self->set_test_error( $e );
        return;
    }

    return;
}

sub _response_retry {
    my $self        = shift;

    my %response    = (
        Response    => {
            ResponseStatusCode          => 0,
            ResponseStatusDescription   => 'Failure',
            Error   => {
                ErrorSeverity   => 'Transient',
                ErrorCode       => '22222',
                ErrorDescription=> 'Test Retry Error',
                MinimumRetrySeconds=> $self->test_when_retry->{retry_seconds},
            },
        },
    );
    # if negative seconds then delete to simulate no Min Retry Seconds passed
    delete $response{Response}{Error}{MinimumRetrySeconds}      if ( $self->test_when_retry->{retry_seconds} < 0 );

    # is the next attempt the one we are looking for
    if ( $self->test_call_counter >= ( $self->test_when_retry->{on_attempt} - 1 ) ) {
        $self->simulate_response( $self->test_when_retry->{give_response} );
    }

    $self->set_xml_response( \%response );
    $self->set_error( $response{Response}{Error}{ErrorDescription} );

    $self->set_test_xml_response( \%response );
    $self->set_test_error( $response{Response}{Error}{ErrorDescription} );

    return;
}

# a useful response simulation for ShipConfirm
sub response_success_for_confirm {
    my $self    = shift;

    my $resp    = {
            ShipmentIdentificationNumber    => 'AWB0123456789',
            ShipmentDigest                  => 'SHIP_DIGEST_KEY',
        };

    $self->set_response_with_success( $resp );
}

# a useful response simulation for ShipAccept
sub response_success_for_accept_outbound {
    my $self        = shift;
    my $shipment    = shift;
    my $num_boxes   = shift || $shipment->shipment_boxes->count();
    my $label_img   = shift || 'OUTWARD_LABEL_IMAGE';
    my $sequence    = $self->sequence;

    my @packages;
    foreach ( 1..$num_boxes ) {
        push @packages, {
                LabelImage  => {
                      GraphicImage     => encode_base64( $label_img.'_'.$_.'_'.$sequence ),
                      LabelImageFormat => { Code => "EPL" },
                    },
                ServiceOptionsCharges   => { CurrencyCode => "USD", MonetaryValue => "0.50" },
                TrackingNumber          => "OUTWARD_TRAK_".$_.'_'.$sequence,
            };
    }

    my $resp    = {
        ShipmentResults => {
            BillingWeight   => {
                  UnitOfMeasurement => { Code => "LBS", Description => "Pounds" },
                  Weight            => "9.0",
                },
            PackageResults  => \@packages,
            ShipmentCharges => {
                  ServiceOptionsCharges => { CurrencyCode => "USD", MonetaryValue => "3.00" },
                  TotalCharges          => { CurrencyCode => "USD", MonetaryValue => "10.55" },
                  TransportationCharges => { CurrencyCode => "USD", MonetaryValue => "7.55" },
                },
            ShipmentIdentificationNumber    => "1234567OUTWARD_AWB_$sequence",
        },
    };

    $self->set_response_with_success( $resp );
}

# a useful response simulation for ShipAccept
sub response_success_for_accept_return {
    my $self        = shift;
    my $shipment    = shift;
    my $num_boxes   = shift || $shipment->shipment_boxes->count();
    my $label_img   = shift || 'RETURN_LABEL_IMAGE';
    my $receipt_img = shift || 'RECEIPT_LABEL_IMAGE';
    my $sequence    = $self->sequence;

    my @packages;
    foreach ( 1..$num_boxes ) {
        push @packages, {
                LabelImage  => {
                      GraphicImage     => encode_base64( $label_img.'_'.$_.'_'.$sequence ),
                      LabelImageFormat => { Code => "EPL" },
                    },
                Receipt     => {
                      Image => {
                            GraphicImage => encode_base64( $receipt_img.'_'.$_.'_'.$sequence ),
                            ImageFormat  => { Code => "HTML", Description => "HTML" },
                          },
                    },
                ServiceOptionsCharges   => { CurrencyCode => "USD", MonetaryValue => "0.50" },
                TrackingNumber          => "RETURN_TRAK_".$_.'_'.$sequence,
            };
    }

    my $resp    = {
        ShipmentResults => {
            BillingWeight   => {
                  UnitOfMeasurement => { Code => "LBS", Description => "Pounds" },
                  Weight            => "11.0",
                },
            PackageResults  => \@packages,
            ShipmentCharges => {
                  ServiceOptionsCharges => { CurrencyCode => "USD", MonetaryValue => "0.50" },
                  TotalCharges          => { CurrencyCode => "USD", MonetaryValue => "23.34" },
                  TransportationCharges => { CurrencyCode => "USD", MonetaryValue => "22.84" },
                },
            ShipmentIdentificationNumber    => "12345678RETURN_AWB_$sequence",
        },
    };

    $self->set_response_with_success( $resp );
}

1;
