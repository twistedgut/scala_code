package XTracker::DHL;

use Moose;
use MooseX::Types::Structured qw(Dict Optional);
use MooseX::Types::Moose qw(Str Int ArrayRef Undef Maybe);

use XTracker::DHL::XMLDocument;
use XTracker::DHL::XMLRequest;


has error => (
    is          => 'rw',
    isa         => Maybe[Str],
    default     => undef,
);

has xmlpi_info => (
    is      => 'ro',
    isa     => Dict,
    required    => 1,
);

no Moose;
__PACKAGE__->meta->make_immutable;

sub do_routing_request {
    my($self,$address) = @_;
    $self->error(undef);
    my $data = Catalyst::Utils::merge_hashes( $self->xmlpi_info, $address );
    my $request_xml = undef;
    my $response_xml = undef;

    # create and send the request
    eval {
        $request_xml = XTracker::DHL::XMLDocument::build_routing_xml( $data );

        my $xml_request = XTracker::DHL::XMLRequest->new(client_host => $self->xmlpi_info->{address},
                                                         request_xml => $request_xml);
        $response_xml = $xml_request->send_xml_request;
    };

    if ($@) {
        $self->error("Failed to create/send request: $@");
        return;
    }

    # try parsing the response
    eval {
        $data = XTracker::DHL::XMLDocument::parse_routing_response(
            $response_xml
        );
    };

    if ($@) {
        $self->error("Failed to parse response: $@");
        return;
    }

    return $data;
}





1;
__END__

=pod

=head1 NAME

XTracker::DHL - Wrapper for the XTracker::DHL::* mess and awful error handling

=head1 SYNOPSIS

  my $dhl = XTracker::DHL->new({
      xmlpi_info => {
        address     => 'xmlpi-ea.dhl.com',
        username    => 'NetAPorter',
        password    => 'WrIephi8qo',
        date        => "2006-01-01T01:00:00.000-00:00",
      },
  });

  my $response = $dhl->do_routing_request({
    address_line_1  => "THE FORGE, LANGFORD ROAD,",
    address_line_2  => "LOWER LANGFORD",
    postcode        => "BS40 5HU",
    towncity        => "BRISTOL",
    country_code    => "GB",
    country         => "United Kingdom",
  })

  if (not defined $response) {
    die "DHL CALL FAILED: ". $dhl->error;
  }

=head1 TO DO

Need to implement the other DHL methods. Only the one(s) documented here are
available through this interface


=head1 AUTHOR

Jason Tang << <jason.tang@net-a-porter.com> >>

=cut

