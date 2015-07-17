package Test::XT::Override::TraitFor::XTracker::DHL::XMLRequest;
use NAP::policy "tt", 'role';

use FindBin::libs;
use XML::LibXML;
use Test::RoleHelper;
use Test::XTracker::Mock::DHL::XMLRequest;
use XTracker::Config::Local qw/config_var/;
use Data::Dump 'pp';

use Test::Role::Address;

requires 'request_xml';

=head1 NAME

Test::XT::Override::TraitFor::XTracker::DHL::XMLRequest - A role with overrides to be
applied to XTracker::DHL::XMLRequest.

=head1 DESCRIPTION

This module is a Moose role with overrides for XTracker::DHL::XMLRequest. You can use
L<Test::XT::Override> to apply these, or just apply them manually yourself.

=head1 METHOD MODIFIERS

=head2 around send_xml_request

A wrapper around L<overridden_send_xml_request>.

=cut

around 'send_xml_request' => sub {
    my $orig = shift;
    my $self = shift;
    return $self->overridden_send_xml_request($orig,@_);
};

=head1 METHODS

=head2 overridden_send_xml_request

This method overrides the call to XTracker::DHL::XMLRequest::send_xml_request.
The XML response returned can be a Service Request response (i.e. labelling),
a Capability Service (i.e. address validation) or Routing Service request
(i.e. address validation in DC2 only), depending upon the XML received as input.

=cut

sub overridden_send_xml_request {
    my $self = shift;
    my $orig = shift;

    return $self->$orig( @_ )      unless ( $ENV{PLACK_ENV} =~ m/(development|unittest)/i );

    my $xml_return_type = get_xml_return_type($self);

    return Test::XTracker::Mock::DHL::XMLRequest->$xml_return_type($self->request_xml);
}

=head2 get_xml_return_type() : $xml_return_type

Works out the C<xml_return_type> for the C<request_xml>.

=cut

sub get_xml_return_type {
    my ( $self ) = @_;

    # Parse the XML that was going to be sent to the API
    my $parser = XML::LibXML->new;
    my $doc = $parser->parse_string($self->request_xml);
    my $root = $doc->getDocumentElement;

    # Check XML for the type of request so the correct response can be
    # returned: if the XML request is not a labelling or capability request, it
    # must be a routing request, which is only used by DC2
    return 'dhl_shipment_validate' if $root->getElementsByTagName('LabelImageFormat');

    # NOTE: We were using this, but we fell back to routing to validate an
    # address as this was inconsistent with the validation that was used to
    # print labels (above), so we had loads of problems at packing.
    if ( $root->getElementsByTagName('GetCapability') ) {
        my $failed_xml = 'dhl_capability_blank';

        my $city_name = $doc->findvalue('p:DCTRequest/GetCapability/To/City')
            or return $failed_xml;

        return $failed_xml unless is_valid_city($city_name);

        return xml_return_type_override()->{$city_name}{capability}
            || default_xml_return_type('capability');
    }

    # Otherwise we fall back to the routing xml request - which is what we
    # currently use to validate addresses
    my $failed_xml = 'dhl_routing_blank';

    my $city_name = $doc->findvalue('ns1:RouteRequest/City')
        or return $failed_xml;

    return $failed_xml unless is_valid_city($city_name);

    return xml_return_type_override()->{$city_name}{routing}
        || default_xml_return_type('routing');
}

=head2 is_valid_city($city_name) : Bool

Return a hashref the keys of which are cities that valid successfully.

=cut

sub is_valid_city {
    my ( $city_name ) = @_;
    return {
        (map { $_ => 1 } keys %{xml_return_type_override()}),
        map { $_->{towncity} => 1 } values %{Test::Role::Address::valid_address()}
    }->{$city_name};
}

=head2 default_xml_return_type($xml_request) : $xml_return_type

Return the default xml for the given C<xml_request>. The only valid
C<xml_request>s are C<capability> and C<routing>.

=cut

sub default_xml_return_type {
    my ( $xml_request_type ) = @_;

    die "Invalid argument '$xml_request_type'"
        if ($xml_request_type//q{}) !~ m{^(?:capability|routing)$};

    my $dc = config_var(qw/DistributionCentre name/);
    return {
        DC1 => { capability => 'dhl_capability',     routing => 'dhl_routing'      },
        DC2 => { capability => 'dhl_capability_nyc', routing => 'dhl_routing_nyc', },
        DC3 => { capability => 'dhl_capability_hkg', routing => 'dhl_routing_hkg', },
    }->{$dc}{$xml_request_type};
}

=head2 xml_return_type_override() : \%xml_return_type_override

Returns a hashref keyed by the cities we want to return custom DHL XML
responses with values for C<capability> and C<routing>.

=cut

sub xml_return_type_override {
    return {
        Glasgow     => { capability => 'dhl_capability_gla', routing => 'dhl_routing_gla' },
        'Hong Kong' => { capability => 'dhl_capability_hkg', routing => 'dhl_routing_hkg' },
        London      => { capability => 'dhl_capability',     routing => 'dhl_routing'     },
        'New York'  => { capability => 'dhl_capability_nyc', routing => 'dhl_routing_nyc' },
        Pittsburgh  => { capability => 'dhl_capability_pit', routing => 'dhl_routing_pit' },
    };
}
