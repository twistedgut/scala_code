package Test::XTracker::Mock::Net::UPS;

use strict;
use warnings;

use FindBin::libs;


use Test::MockModule;

use Moose;

has 'addresses' => (
    is => 'rw',
    isa => 'ArrayRef',
);
has 'shipping' => (
    is => 'rw',
    isa => 'ArrayRef',
);

has 'iterator_index' => (
    is => 'rw',
    isa => 'HashRef',
);

sub mock {
    my $self = shift,
    my @methods = @_;
    my $mocked = Test::MockModule->new( 'Net::UPS' );
    foreach my $method (@methods){
        $mocked->mock( $method => sub { $self->$method } );
    }
    return $mocked
}

# mock methods

sub post {
    my $self = shift;
    my $sh = $self->get_next('shipping');

    my $response = '';
    if (my $e = $sh->{error}){
        $sh->{status_code} ||= 0;
        $sh->{desc} ||= 'Failure';
        $sh->{error_severity} ||= 'Die';
        $sh->{error_code} ||= 0;
        $response = <<________EOF
            <Response>
                <ResponseStatusCode>$sh->{status_code}</ResponseStatusCode>
                <ResponseStatusDescription>$sh->{desc}</ResponseStatusDescription>
                <Error>
                    <ErrorSeverity>$sh->{error_severity}</ErrorSeverity>
                    <ErrorCode>$sh->{error_code}</ErrorCode>
                    <ErrorDescription>$e</ErrorDescription>
                </Error>
            </Response>
________EOF
    }
    elsif (my $s = $sh->{success}) {
        $sh->{status_code}      ||= 1;
        $sh->{desc}             ||= 'Success';
        $sh->{customer_context} ||= 'OUTBOUND-465595';
        $sh->{shipment_digest}  ||= '';
        $sh->{boxes}            ||= [{}];
        my $boxes = "";
        foreach my $box (0..scalar @{$sh->{boxes}}){
            my $tn = $sh->{boxes}->[$box]->{tracking_number} || 1;
            my $gi = $sh->{boxes}->[$box]->{graphic_image} || 'random';
            $boxes .= <<____________EOF
                <PackageResults>
                    <TrackingNumber>$tn</TrackingNumber>
                    <LabelImage>
                        <GraphicImage>$gi</GraphicImage>
                    </LabelImage>
                </PackageResults>
____________EOF
        }
        $response = <<________EOF
            <Response>
                <ResponseStatusCode>$sh->{status_code}</ResponseStatusCode>
                <ResponseStatusDescription>$sh->{desc}</ResponseStatusDescription>
                <TransactionReference>
                    <CustomerContext>$sh->{customer_context}</CustomerContext>
                    <XpciVersion>1.0001</XpciVersion>
                </TransactionReference>
            </Response>
            <ShipmentResults wtf="wtf">
                <ShipmentIdentificationNumber>$s</ShipmentIdentificationNumber>
                $boxes
            </ShipmentResults>
            <ShipmentDigest>$sh->{shipment_digest}</ShipmentDigest>
________EOF
    }

    return <<____EOF
    <envelope>
        $response
    </envelope>
____EOF
}

sub validate_address {
    my $self = shift;

    my $ad = $self->get_next('addresses');
    return "The XML document is well formed but the document is not valid" if defined $ad->{invalid};
    return "No Address Candidate Found" if defined $ad->{nowhere};
    $ad->{quality}        ||= "1.0";
    $ad->{postal_code}    ||= 10001;
    $ad->{city}           ||= 'NEW YORK';
    $ad->{state}          ||= 'NY';
    $ad->{country_code}   ||= 'US';

    my $return = [];
    my $length = delete $ad->{length} || 1;
    foreach (1..$length){
        push @$return, Net::UPS::Address->new(%$ad);
        $ad->{postal_code}++;
    }
    return $return;
}

# mock data access methods
sub get_next {
    my ($self, $what) = @_;

    my $index = $self->iterator_index;
    $index->{$what} ||= 0; # create if it doesn't exist yet

    #warn("DATA INDEX '$what' : ". $index->{$what});

    $index->{$what} = 0 unless $self->$what->[ $index->{$what} ];
    my $ad = $self->$what->[$index->{$what}] || {};

    $index->{$what}++;
    $self->iterator_index($index);

    return $ad;
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
