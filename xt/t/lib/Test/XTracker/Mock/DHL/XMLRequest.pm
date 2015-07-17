package Test::XTracker::Mock::DHL::XMLRequest;

use strict;
use warnings;

use FindBin::libs;

use Test::MockModule;
use Moose;

has 'data' => (
    is => 'rw',
    isa => 'ArrayRef',
);
has 'iterator_index' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

sub setup_mock {
    my ($class, $data) = @_;

    my $xmlreq = Test::MockModule->new( 'XTracker::DHL::XMLRequest' );

    my $mock_data = $class->new(data => $data);
    if ( ref($data) eq 'HASH' && defined $data->{dhl_label} ) {
        $xmlreq->mock( send_xml_request => sub { return $mock_data->$data->{dhl_label} } );
    }
    else {
        $xmlreq->mock( send_xml_request => sub { $mock_data->xml } );
    }

    return $xmlreq;
}

sub get_data {
    my $self = shift;
    my $index = $self->iterator_index;
    $index = 0 unless $self->data->[$index];
    $self->iterator_index($index + 1);
    return $self->data->[$index++] || {};
}

sub xml {
    my $self = shift;

    my $data = $self->get_data;
    my $service_code = defined $data->{service_code} ? $data->{service_code} : 'LON';

    return <<____EOF
<?xml version="1.0" encoding="UTF-8"?><res:RoutingResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com routing-res.xsd'>
    <Response>
    <ServiceHeader>
    <MessageTime>2010-04-30T05:22:37-05:00</MessageTime>
    <MessageReference>1222333444566677777778888899999</MessageReference>
    <SiteID>NetAPorter</SiteID>
    </ServiceHeader>
    </Response>
    <GMTNegativeIndicator>N</GMTNegativeIndicator>
    <GMTOffset>01:00</GMTOffset>
    <RegionCode>EA</RegionCode>
    <ServiceArea>
    <ServiceAreaCode>$service_code</ServiceAreaCode>
    <Description>LHR|0|GMT0:00|LONDON-HEATHROW - UNITED KINGDOM|GB</Description>
    </ServiceArea></res:RoutingResponse>
____EOF
}

sub dhl_routing {
    my $self = shift;

    return q{<?xml version="1.0" encoding="UTF-8"?>
    <res:RoutingResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com routing-res.xsd'>
        <Response>
            <ServiceHeader>
                <MessageTime>2014-02-17T12:40:03.302+00:00</MessageTime>
                <MessageReference>1222333444566677777778888899999</MessageReference>
                <SiteID>NetAPorter</SiteID>
            </ServiceHeader>
        </Response>
        <GMTNegativeIndicator>N</GMTNegativeIndicator>
        <GMTOffset>00:00</GMTOffset>
        <RegionCode>EA</RegionCode>
        <ServiceArea>
            <ServiceAreaCode>LCY</ServiceAreaCode>
            <Description>LHR|0|GMT0:00|LONDON-HEATHROW - UNITED KINGDOM|GB</Description>
        </ServiceArea>
    </res:RoutingResponse>};
}

sub dhl_routing_gla {
    my $self = shift;

    return q{<?xml version="1.0" encoding="UTF-8"?>
    <res:RoutingResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com routing-res.xsd'>
        <Response>
            <ServiceHeader>
                <MessageTime>2014-02-17T12:40:03.302+00:00</MessageTime>
                <MessageReference>1222333444566677777778888899999</MessageReference>
                <SiteID>NetAPorter</SiteID>
            </ServiceHeader>
        </Response>
        <GMTNegativeIndicator>N</GMTNegativeIndicator>
        <GMTOffset>00:00</GMTOffset>
        <RegionCode>EA</RegionCode>
        <ServiceArea>
            <ServiceAreaCode>GLA</ServiceAreaCode>
            <Description>GLA|0|GMT0:00|GLASGOW - UNITED KINGDOM|GB</Description>
        </ServiceArea>
    </res:RoutingResponse>};
}

sub dhl_routing_hkg {
    return <<EOR
<?xml version="1.0" encoding="UTF-8"?>
<res:RouteResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com routing-res.xsd'>
    <Response>
        <ServiceHeader>
            <MessageTime>2014-11-04T12:46:48+01:00</MessageTime>
            <MessageReference>1234567890123456789012345678901</MessageReference>
            <SiteID>CIMGBTest</SiteID>
        </ServiceHeader>
    </Response>
    <GMTNegativeIndicator>N</GMTNegativeIndicator>
    <GMTOffset>08:00</GMTOffset>
    <RegionCode>AP</RegionCode>
    <ServiceArea>
        <ServiceAreaCode>HKG</ServiceAreaCode>
        <Description>HKG|0|GMT8:00|HONG KONG - HONG KONG|HK</Description>
    </ServiceArea></res:RouteResponse>
EOR
;
}

sub dhl_routing_pit {
    my $self = shift;

    return q{<?xml version="1.0" encoding="UTF-8"?>
    <res:RoutingResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com routing-res.xsd'>
        <Response>
            <ServiceHeader>
                <MessageTime>2014-02-17T12:40:03.302+00:00</MessageTime>
                <MessageReference>1222333444566677777778888899999</MessageReference>
                <SiteID>NetAPorter</SiteID>
            </ServiceHeader>
        </Response>
        <GMTNegativeIndicator>Y</GMTNegativeIndicator>
        <GMTOffset>04:00</GMTOffset>
        <RegionCode>EA</RegionCode>
        <ServiceArea>
            <ServiceAreaCode>PIT</ServiceAreaCode>
            <Description>PIT|0|GMT-5:00|PITTSBURGH,PA-USA|US</Description>
        </ServiceArea>
    </res:RoutingResponse>};
}

sub dhl_routing_nyc {
    my $self = shift;

    return q{<?xml version="1.0" encoding="UTF-8"?>
    <res:RoutingResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com routing-res.xsd'>
        <Response>
            <ServiceHeader>
                <MessageTime>2014-02-17T12:40:03.302+00:00</MessageTime>
                <MessageReference>1222333444566677777778888899999</MessageReference>
                <SiteID>NetAPorter</SiteID>
            </ServiceHeader>
        </Response>
        <GMTNegativeIndicator>N</GMTNegativeIndicator>
        <GMTOffset>01:00</GMTOffset>
        <RegionCode>EA</RegionCode>
        <ServiceArea>
            <ServiceAreaCode>LGA</ServiceAreaCode>
            <Description>LGA|0|GMT-5:00|WOODSIDE,NY-USA|US</Description>
        </ServiceArea>
    </res:RoutingResponse>};
}

sub dhl_routing_blank {
    my $self = shift;

    return q{<?xml version="1.0" encoding="UTF-8"?>
    <res:RoutingResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com routing-res.xsd'>
        <Response>
            <ServiceHeader>
                <MessageTime>2014-02-17T12:40:03.302+00:00</MessageTime>
                <MessageReference>1222333444566677777778888899999</MessageReference>
                <SiteID>NetAPorter</SiteID>
            </ServiceHeader>
        </Response>
        <GMTNegativeIndicator>N</GMTNegativeIndicator>
        <GMTOffset>01:00</GMTOffset>
        <RegionCode>EA</RegionCode>
        <ServiceArea>
            <ServiceAreaCode></ServiceAreaCode>
            <Description></Description>
        </ServiceArea>
    </res:RoutingResponse>};
}

sub dhl_capability {
    my $self = shift;
    return q{<?xml version="1.0" encoding="UTF-8"?>
    <res:DCTResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com DCT-Response.xsd'>
        <GetCapabilityResponse>
            <Response>
                <ServiceHeader>
                    <MessageTime>2014-02-17T12:40:03.302+00:00</MessageTime>
                    <MessageReference>1222333444566677777778888899999</MessageReference>
                    <SiteID>NetAPorter</SiteID>
                </ServiceHeader>
            </Response>
            <BkgDetails>
                <OriginServiceArea>
                    <FacilityCode>LCY</FacilityCode>
                    <ServiceAreaCode>LCY</ServiceAreaCode>
                </OriginServiceArea>
                <DestinationServiceArea>
                    <FacilityCode>LCY</FacilityCode>
                    <ServiceAreaCode>LCY</ServiceAreaCode>
                </DestinationServiceArea>
            </BkgDetails>
        </GetCapabilityResponse>
    </res:DCTResponse>};
}

sub dhl_capability_gla {
    my $self = shift;
    return q{<?xml version="1.0" encoding="UTF-8"?>
    <res:DCTResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com DCT-Response.xsd'>
        <GetCapabilityResponse>
            <Response>
                <ServiceHeader>
                    <MessageTime>2014-02-17T12:40:03.302+00:00</MessageTime>
                    <MessageReference>1222333444566677777778888899999</MessageReference>
                    <SiteID>NetAPorter</SiteID>
                </ServiceHeader>
            </Response>
            <BkgDetails>
                <OriginServiceArea>
                    <FacilityCode>LCY</FacilityCode>
                    <ServiceAreaCode>LCY</ServiceAreaCode>
                </OriginServiceArea>
                <DestinationServiceArea>
                    <FacilityCode>GLA</FacilityCode>
                    <ServiceAreaCode>GLA</ServiceAreaCode>
                </DestinationServiceArea>
            </BkgDetails>
        </GetCapabilityResponse>
    </res:DCTResponse>};
}

sub dhl_capability_hkg {
    return <<EOR
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<res:DCTResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com DCT-Response.xsd'>
    <GetCapabilityResponse>
        <Response>
            <ServiceHeader>
                <MessageTime>2014-11-04T12:34:11.229+01:00</MessageTime>
                <MessageReference>1234567890123456789012345678901</MessageReference>
                <SiteID>CIMGBTest</SiteID>
            </ServiceHeader>
        </Response>
        <BkgDetails>
            <OriginServiceArea>
                <FacilityCode>HKC</FacilityCode>
                <ServiceAreaCode>HKG</ServiceAreaCode>
            </OriginServiceArea>
            <DestinationServiceArea>
                <FacilityCode>HKC</FacilityCode>
                <ServiceAreaCode>HKG</ServiceAreaCode>
            </DestinationServiceArea>
        </BkgDetails>
    </GetCapabilityResponse>
</res:DCTResponse>
EOR
;
}

sub dhl_capability_pit {
    my $self = shift;
    return q{<?xml version="1.0" encoding="UTF-8"?>
    <res:DCTResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com DCT-Response.xsd'>
        <GetCapabilityResponse>
            <Response>
                <ServiceHeader>
                    <MessageTime>2014-02-17T12:40:03.302+00:00</MessageTime>
                    <MessageReference>1222333444566677777778888899999</MessageReference>
                    <SiteID>NetAPorter</SiteID>
                </ServiceHeader>
            </Response>
            <BkgDetails>
                <OriginServiceArea>
                    <FacilityCode>LCY</FacilityCode>
                    <ServiceAreaCode>LCY</ServiceAreaCode>
                </OriginServiceArea>
                <DestinationServiceArea>
                    <FacilityCode>PIT</FacilityCode>
                    <ServiceAreaCode>PIT</ServiceAreaCode>
                </DestinationServiceArea>
            </BkgDetails>
        </GetCapabilityResponse>
    </res:DCTResponse>};
}

sub dhl_capability_nyc {
    my $self = shift;
    return q{<?xml version="1.0" encoding="UTF-8"?>
    <res:DCTResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com DCT-Response.xsd'>
        <GetCapabilityResponse>
            <Response>
                <ServiceHeader>
                    <MessageTime>2014-02-17T12:40:03.302+00:00</MessageTime>
                    <MessageReference>1222333444566677777778888899999</MessageReference>
                    <SiteID>NetAPorter</SiteID>
                </ServiceHeader>
            </Response>
            <BkgDetails>
                <OriginServiceArea>
                    <FacilityCode>LCY</FacilityCode>
                    <ServiceAreaCode>LCY</ServiceAreaCode>
                </OriginServiceArea>
                    <FacilityCode>JR3</FacilityCode>
                    <ServiceAreaCode>ZYP</ServiceAreaCode>
                </DestinationServiceArea>
            </BkgDetails>
        </GetCapabilityResponse>
    </res:DCTResponse>};
}

sub dhl_capability_blank {
    my $self = shift;
    return q{<?xml version="1.0" encoding="UTF-8"?>
    <res:DCTResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com DCT-Response.xsd'>
        <GetCapabilityResponse>
            <Response>
                <ServiceHeader>
                    <MessageTime>2014-02-17T12:40:03.302+00:00</MessageTime>
                    <MessageReference>1222333444566677777778888899999</MessageReference>
                    <SiteID>NetAPorter</SiteID>
                </ServiceHeader>
            </Response>
            <BkgDetails>
                <OriginServiceArea>
                    <FacilityCode>LCY</FacilityCode>
                    <ServiceAreaCode>LCY</ServiceAreaCode>
                </OriginServiceArea>
                <DestinationServiceArea>
                    <FacilityCode></FacilityCode>
                    <ServiceAreaCode></ServiceAreaCode>
                </DestinationServiceArea>
            </BkgDetails>
        </GetCapabilityResponse>
    </res:DCTResponse>};
}

sub dhl_shipment_validate {
    my ($self, $xml) = @_;

    my $number_of_boxes = 1;
    if($xml =~ /<NumberOfPieces>(\d+)<\/NumberOfPieces>/) {
        $number_of_boxes = $1
    }

    my $pieces_xml;
    for my $count (1 .. $number_of_boxes) {
        $pieces_xml .= sprintf(q{<Piece>
            <PieceNumber>%s</PieceNumber>
            <Depth>43</Depth>
            <Width>34</Width>
            <Height>17</Height>
            <Weight>1.33</Weight>
            <PackageType>CP</PackageType>
            <DimWeight>4.970800</DimWeight>
            <DataIdentifier>J</DataIdentifier>
            <LicensePlate>JD01460000034487969%s</LicensePlate>
        </Piece>}, $count, $count);
    }

    return sprintf(q{<?xml version="1.0" encoding="UTF-8"?><res:ShipmentResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com ship-val-res.xsd'>
    <Response>
        <ServiceHeader>
            <MessageTime>2014-04-30T16:14:12+01:00</MessageTime>
            <MessageReference>1234567123456712345671234567</MessageReference>
            <SiteID>CIMGBTest</SiteID>
        </ServiceHeader>
    </Response>
    <Note>
        <ActionNote>Success</ActionNote>
    </Note>
    <AirwayBillNumber>9150905632</AirwayBillNumber>
    <ShipmentDate>2014-05-01</ShipmentDate>
    <DHLRoutingCode>GI:GIBGIB+46000001</DHLRoutingCode>
    <DHLRoutingDataId>2L</DHLRoutingDataId>
    <ProductContentCode>WPX</ProductContentCode>
    <ProductShortName>EXPRESS WORLDWIDE</ProductShortName>
    <InternalServiceCode>C</InternalServiceCode>
    <InternalServiceCode>DDP</InternalServiceCode>
    <Pieces>
        %s
    </Pieces>
    <LabelImage>
        <OutputFormat>ZPL2</OutputFormat>
        <OutputImage>XlhBCl5GVDE3LDQxCl5BME4sLDMyCl5GREVYUFJFU1MgV09STERXSURFXkZTCl5GVDE2LDQxCl5BME4sLDMyCl5GREVYUFJFU1MgV09STERXSURFXkZTCl5GVDExMSw3MApeQTBOLCwxNQpeRkRYTUxQSSA1LjAgLyAqMDMtMTIxMSpeRlMKXkZPMzg2LDAKXkdCMTUwLDc5LDc5LEJeRlMKXkZUMzg4LDU1Cl5BME4sLDYyCl5GUl5GRFdQWF5GUwpeRk81NDMsMjMKXklNUjpkaGxsZzEuR1JGXkZTCl5GTzAsNzgKXkdCNzgwLDAsMixCXkZTCl5GVDE5LDEwMgpeQTBOLCwxNgpeRkRGcm9tIDpeRlMKXkZUMTksMTAyCl5BME4sLDE2Cl5GREZyb20gOl5GUwpeRlQ4NywxMDIKXkEwTiwsMjQKXkZETkVULUEtUE9SVEVSLkNPTV5GUwpeRlQ4NywxMjkKXkEwTiwsMjQKXkZERGlzcGF0Y2ggRGVwYXJ0bWVudF5GUwpeRlQ4NywxNTMKXkEwTiwsMjAKXkZEVW5pdCAzLCBDaGFybHRvbiBHYXRlIEJ1c2luZXNzIFBhcmteRlMKXkZUODcsMTgyCl5BME4sLDI0Cl5GRFNFNyA3UlUgTG9uZG9uXkZTCl5GVDg3LDIwOQpeQTBOLCwyNApeRkRVbml0ZWQgS2luZ2RvbV5GUwpeRlQ1MDgsMjA3Cl5BME4sLDE5Cl5GRENvbnRhY3Q6ICs0NCAoMCkgMjAgMzQ3MSA0NTEwXkZTCl5GVDY5MywxMDIKXkEwTiwsMjEKXkZET3JpZ2luOl5GUwpeRlQ2OTQsMTQwCl5BME4sLDM5Cl5GRExDWV5GUwpeRlQ2OTMsMTQwCl5BME4sLDM5Cl5GRExDWV5GUwpeRk8wLDIyMApeR0I3ODAsMCwyLEJeRlMKXkZUMzUsMjUyCl5BME4sLDE2Cl5GRFRvIDpeRlMKXkZUMzUsMjUyCl5BME4sLDE2Cl5GRFRvIDpeRlMKXkZPMjUsMjI2Cl5HQjAsMzEsNSxCXkZTCl5GTzI4LDIyNApeR0IzMSwwLDUsQl5GUwpeRk83NTAsMjI2Cl5HQjAsMzEsNSxCXkZTCl5GTzcyMCwyMjQKXkdCMzEsMCw1LEJeRlMKXkZPMjUsNDA5Cl5HQjAsMzEsNSxCXkZTCl5GTzI4LDQzOQpeR0IzMSwwLDUsQl5GUwpeRk83NTAsNDA5Cl5HQjAsMzEsNSxCXkZTCl5GTzcyMCw0MzkKXkdCMzEsMCw1LEJeRlMKXkZUODcsMjUyCl5BME4sLDMyCl5GRHNvbWUgb25lXkZTCl5GVDg3LDI5MQpeQTBOLCwzMgpeRkRzb21lIG9uZV5GUwpeRlQ4NywzMzAKXkEwTiwsMzIKXkZEMzIgLSAzNiBUb3duIFJhbmdlXkZTCl5GVDg3LDM3NwpeQTBOLCw0NApeRkRHaWJyYWx0YXJeRlMKXkZUODcsMzc3Cl5BME4sLDQ0Cl5GREdpYnJhbHRhcl5GUwpeRlQ4Nyw0MjkKXkEwTiwsNDQKXkZER2licmFsdGFyXkZTCl5GVDg3LDQyOQpeQTBOLCw0NApeRkRHaWJyYWx0YXJeRlMKXkZUNTc1LDI0NApeQTBOLCwxOQpeRkRDb250YWN0Ol5GUwpeRlQ1NzUsMjY0Cl5BME4sLDE5Cl5GRHRlbGVwaG9uZV5GUwpeRk8wLDQ0OApeR0I3ODAsMCwyLEJeRlMKXkZUOSw1MDgKXkEwTiwsNTMKXkZELl5GUwpeRlQ4LDUwOApeQTBOLCw1MwpeRkQuXkZTCl5GVDE5NSw1MTMKXkEwTiwsNzIKXkZER0ktR0lCLUdJQl5GUwpeRlQxOTQsNTEzCl5BME4sLDcyCl5GREdJLUdJQi1HSUJeRlMKXkZUNzYxLDUwOApeQTBOLCw1MwpeRkQuXkZTCl5GVDc2MCw1MDgKXkEwTiwsNTMKXkZELl5GUwpeRk8wLDUzNQpeR0I3ODAsMCwyLEJeRlMKXkZPMCw1MzUKXkdGQiwxOTIsMTkyLDMs//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8A//8AAAAAXkZTCl5GTzE2LDUzNQpeR0I1NTEsNjMsNjMsQl5GUwpeRlQxOSw1NzgKXkEwTiwsNDYKXkZSXkZEQy1EVFBeRlMKXkZUNzAxLDU1MQpeQTBOLCwxNgpeRkRUaW1lXkZTCl5GVDYyNiw1NTEKXkEwTiwsMTYKXkZERGF5XkZTCl5GTzAsNTk4Cl5HQjc4MCwwLDIsQl5GUwpeRlQxMiw2MjIKXkEwTiwsMjEKXkZEUmVmOiAxMDAwMDAyMjI5XkZTCl5GVDQwMiw2MTcKXkEwTiwsMTYKXkZERGF0ZTpeRlMKXkZUNDAyLDYzOQpeQTBOLCwxOQpeRkQyMDE0LTA1LTAxXkZTCl5GVDUzNSw2MTcKXkEwTiwsMTYKXkZEUGNlL1NocHQgV2VpZ2h0XkZTCl5GVDUzNiw2NTMKXkEwTiwsMzcKXkZEMS4zIGtnXkZTCl5GVDUzNSw2NTMKXkEwTiwsMzcKXkZEMS4zIGtnXkZTCl5GVDcxMyw2MTcKXkEwTiwsMTYKXkZEUGllY2VeRlMKXkZUNzA1LDY1MwpeQTBOLCwzOQpeRkQxLzFeRlMKXkZUNzA1LDY1MwpeQTBOLCwzOQpeRkQxLzFeRlMKXkZPMCw3NDcKXkdCNzgwLDAsMixCXkZTCl5GTzUxLDc3NgpeQlkzLDIuNywyMDUKXkIzTixOLDIwNSxOLE4KXkZEOTE1MDkwNTYzMl5GUwpeRlQxODYsMTAwMwpeQTBOLCwyNQpeRkRXQVlCSUxMIDkxIDUwOTAgNTYzMl5GUwpeRlQ2NDIsNzk0Cl5BME4sLDE5Cl5GRENvbnRlbnRzIDpeRlMKXkZUNjQyLDgxNQpeQTBOLCwxOQpeRkRVbnNldCwgTm90IHJlc3ReRlMKXkZUNjQyLDgzNgpeQTBOLCwxOQpeRkRyaWN0ZWQgZm9yIHRyYW5eRlMKXkZUNjQyLDg1NwpeQTBOLCwxOQpeRkRzcG9ydF5GUwpeRk8xNjgsMTA4NwpeQlkyLDMuMCwyMDUKXkJDTiwyMDUsTixOLE4sQQpeRkQyTEdJOkdJQkdJQis0NjAwMDAwMV5GUwpeRlQyNzgsMTMxMgpeQTBOLCwxOQpeRkQoMkwpR0k6R0lCR0lCKzQ2MDAwMDAxXkZTCl5GTzEyMywxMzE5Cl5CWTMsMy4wLDIwNQpeQkNOLDIwNSxOLE4sTixBCl5GREpKRDAxNDYwMDAwMDM0NDg3OTY5M15GUwpeRlQyMTQsMTU0OApeQTBOLCwyNQpeRkQoSikgSkQwMSA0NjAwIDAwMDMgNDQ4NyA5NjkzXkZTCl5YWgpeWEEKXkZUNTQsMzcKXkEwTiwsMzMKXkZEKiBBUkNISVZFIERPQyAqXkZTCl5GVDUzLDM3Cl5BME4sLDMzCl5GRCogQVJDSElWRSBET0MgKl5GUwpeRlQ0NSw2OApeQTBOLCwyMQpeRkROb3QgdG8gYmUgYXR0YWNoZWQgdG8gcGFja2FnZV5GUwpeRk8zODYsMApeR0IxNTAsNzksNzksQl5GUwpeRlQzODgsNTUKXkEwTiwsNjIKXkZSXkZEV1BYXkZTCl5GTzU0MywyMwpeSU1SOmRobGxnMS5HUkZeRlMKXkZPMCw3OApeR0I3ODAsMCwyLEJeRlMKXkZUMjAsMTAyCl5BME4sLDE2Cl5GREZyb20gOl5GUwpeRlQyMCwxMDIKXkEwTiwsMTYKXkZERnJvbSA6XkZTCl5GVDg3LDEwMgpeQTBOLCwyNApeRkRORVQtQS1QT1JURVIuQ09NXkZTCl5GVDg3LDEyOQpeQTBOLCwyNApeRkREaXNwYXRjaCBEZXBhcnRtZW50XkZTCl5GVDg3LDE1MwpeQTBOLCwyMApeRkRVbml0IDMsIENoYXJsdG9uIEdhdGUgQnVzaW5lc3MgUGFya15GUwpeRlQ4NywxODIKXkEwTiwsMjQKXkZEU0U3IDdSVSBMb25kb25eRlMKXkZUODcsMjA5Cl5BME4sLDI0Cl5GRFVuaXRlZCBLaW5nZG9tXkZTCl5GVDUwOCwyMDcKXkEwTiwsMTkKXkZEQ29udGFjdDogKzQ0ICgwKSAyMCAzNDcxIDQ1MTBeRlMKXkZUNjkzLDEwMgpeQTBOLCwyMQpeRkRPcmlnaW46XkZTCl5GVDY5NCwxNDAKXkEwTiwsMzkKXkZETENZXkZTCl5GVDY5MywxNDAKXkEwTiwsMzkKXkZETENZXkZTCl5GTzAsMjIwCl5HQjc4MCwwLDIsQl5GUwpeRlQzNiwyNTIKXkEwTiwsMTYKXkZEVG8gOl5GUwpeRlQzNSwyNTIKXkEwTiwsMTYKXkZEVG8gOl5GUwpeRk8yNSwyMjYKXkdCMCwzMSw1LEJeRlMKXkZPMjgsMjI0Cl5HQjMxLDAsNSxCXkZTCl5GTzc1MCwyMjYKXkdCMCwzMSw1LEJeRlMKXkZPNzIwLDIyNApeR0IzMSwwLDUsQl5GUwpeRk8yNSw0MDkKXkdCMCwzMSw1LEJeRlMKXkZPMjgsNDM5Cl5HQjMxLDAsNSxCXkZTCl5GTzc1MCw0MDkKXkdCMCwzMSw1LEJeRlMKXkZPNzIwLDQzOQpeR0IzMSwwLDUsQl5GUwpeRlQ4NywyNTIKXkEwTiwsMzIKXkZEc29tZSBvbmVeRlMKXkZUODcsMjkxCl5BME4sLDMyCl5GRHNvbWUgb25lXkZTCl5GVDg3LDMzMApeQTBOLCwzMgpeRkQzMiAtIDM2IFRvd24gUmFuZ2VeRlMKXkZUODcsMzc3Cl5BME4sLDQ0Cl5GREdpYnJhbHRhcl5GUwpeRlQ4NywzNzcKXkEwTiwsNDQKXkZER2licmFsdGFyXkZTCl5GVDg3LDQyOQpeQTBOLCw0NApeRkRHaWJyYWx0YXJeRlMKXkZUODcsNDI5Cl5BME4sLDQ0Cl5GREdpYnJhbHRhcl5GUwpeRlQ1ODMsMjQ0Cl5BME4sLDE5Cl5GRENvbnRhY3Q6XkZTCl5GVDU4MywyNjQKXkEwTiwsMTkKXkZEdGVsZXBob25lXkZTCl5GTzAsNDQ4Cl5HQjc4MCwwLDIsQl5GUwpeRlQxNyw1MDgKXkEwTiwsNTMKXkZELl5GUwpeRlQxNiw1MDgKXkEwTiwsNTMKXkZELl5GUwpeRlQxOTUsNTEzCl5BME4sLDcyCl5GREdJLUdJQi1HSUJeRlMKXkZUMTk0LDUxMwpeQTBOLCw3MgpeRkRHSS1HSUItR0lCXkZTCl5GVDc1Myw1MDgKXkEwTiwsNTMKXkZELl5GUwpeRlQ3NTIsNTA4Cl5BME4sLDUzCl5GRC5eRlMKXkZPMCw1MzUKXkdCNzgwLDAsMixCXkZTCl5GVDgsNTU3Cl5BME4sLDE5Cl5GRFByb2R1Y3Q6XkZTCl5GVDgsNTgyCl5BME4sLDI1Cl5GRFtQXSBFWFBSRVNTIFdPUkxEV0lERSAoNDgpXkZTCl5GVDgsNTgyCl5BME4sLDI1Cl5GRFtQXSBFWFBSRVNTIFdPUkxEV0lERSAoNDgpXkZTCl5GVDgsNjA0Cl5BME4sLDE5Cl5GRFBheW1lbnQgY29kZTpeRlMKXkZUOCw2MjQKXkEwTiwsMTkKXkZERlJUIEEvQzogMTM1MTA0NzE2XkZTCl5GVDgsNjQ0Cl5BME4sLDE5Cl5GRFRlcm1zIG9mIFRyYWRlOiBEVFBeRlMKXkZUOCw2NjMKXkEwTiwsMTkKXkZERFRQIEEvQzogMTM1MTA0NzE2XkZTCl5GVDQ0OSw1NTcKXkEwTiwsMTkKXkZERmVhdHVyZXMgLyBTZXJ2aWNlczpeRlMKXkZUNDQ5LDU3NApeQTBOLCwxNQpeRkQoREQpXkZTCl5GTzAsNjg0Cl5HQjc4MCwwLDIsQl5GUwpeRlQxMiw3MDQKXkEwTiwsMjEKXkZEUmVmOiAxMDAwMDAyMjI5XkZTCl5GVDEyLDc1MQpeQTBOLCwyMQpeRkRDdXN0b20gVmFsOiAxNjAuMDAgR0JQXkZTCl5GVDQzMyw3MDEKXkEwTiwsMTkKXkZEU2hwdCBXZ2h0Ol5GUwpeRlQ1MzIsNzE4Cl5BME4sLDM3Cl5GRDEuMyBrZ15GUwpeRlQ1MzEsNzE4Cl5BME4sLDM3Cl5GRDEuMyBrZ15GUwpeRlQzNzAsNzUxCl5BME4sLDIxCl5GRFNoaXBtZW50IERhdGU6XkZTCl5GVDUzMiw3NTEKXkEwTiwsMTkKXkZEMjAxNC0wNS0wMV5GUwpeRlQ1MzEsNzUxCl5BME4sLDE5Cl5GRDIwMTQtMDUtMDFeRlMKXkZUNjU5LDcwNApeQTBOLCwyMQpeRkQjIG9mIFBpZWNlc15GUwpeRlQ3NDQsNzQ0Cl5BME4sLDM5Cl5GRDFeRlMKXkZUNzQzLDc0NApeQTBOLCwzOQpeRkQxXkZTCl5GTzAsODU3Cl5HQjc4MCwwLDIsQl5GUwpeRk81MSw5MDIKXkJZMywyLjcsMjA1Cl5CM04sTiwyMDUsTixOCl5GRDkxNTA5MDU2MzJeRlMKXkZUMTc5LDExMjkKXkEwTiwsMjUKXkZEV0FZQklMTCA5MSA1MDkwIDU2MzJeRlMKXkZUNjQyLDkwNgpeQTBOLCwxOQpeRkRDb250ZW50cyA6XkZTCl5GVDY0Miw5MjcKXkEwTiwsMTkKXkZEVW5zZXQsIE5vdCByZXN0XkZTCl5GVDY0Miw5NDgKXkEwTiwsMTkKXkZEcmljdGVkIGZvciB0cmFuXkZTCl5GVDY0Miw5NjkKXkEwTiwsMTkKXkZEc3BvcnReRlMKXkZPMCwxMTQ5Cl5HQjc4MCwwLDIsQl5GUwpeRlQ4LDExNjcKXkEwTiwsMjEKXkZETGljZW5zZSBQbGF0ZXMgb2YgcGllY2VzIGluIHNoaXBtZW50XkZTCl5GVDgsMTE4NgpeQTBOLCwxOQpeRkRKRDAxNDYwMDAwMDM0NDg3OTY5M15GUwpeRlQzNTQsMTUyNgpeQTBOLCwxOQpeRkQtIHBhZ2UgMSBvZiAxIC1eRlMKXlhaCg==</OutputImage>
    </LabelImage></res:ShipmentResponse>}, $pieces_xml);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
