#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

my $DEBUG = 0;

{
    package Net::UPS::NAP::Debug;

    use Carp ('croak');
    use LWP::UserAgent;
    use XML::Simple qw<XMLin XMLout>;  
    use base 'Net::UPS';

    my $payload_debug = '';

    sub CONFIRM_TEST_PROXY   () { 'https://wwwcie.ups.com/ups.app/xml/ShipConfirm'    }
    sub CONFIRM_LIVE_PROXY   () { 'https://www.ups.com/ups.app/xml/ShipConfirm'       }
    sub confirm_proxy    { $Net::UPS::LIVE ? CONFIRM_LIVE_PROXY   : CONFIRM_TEST_PROXY     }

    sub post {
        my ($self, $url, $content) = @_;

        unless ( $url && $content ) {
            croak "post(): usage error";
        }

        my $user_agent  = LWP::UserAgent->new();
        $user_agent->add_handler("request_send",  sub { $payload_debug .= "*******\nREQUEST\n*******\n" . shift->dump(maxlength => 0); return });
        $user_agent->add_handler("response_done", sub { $payload_debug .= "*******\nRESPONSE\n*******\n" .shift->dump(maxlength => 0); return });

        my $request     = HTTP::Request->new('POST', $url);
        $request->content( $content );
        my $response    = $user_agent->request( $request );
        if ( $response->is_error ) {
            die $response->status_line();
        }
        return $response->content;
    }

    sub validate_address {
        my $self = shift;
        my $addresses = $self->SUPER::validate_address(@_);
        if (defined $addresses && @$addresses){
            print localtime() . " Address validation OK!\n";

            if (0){ # Shh for now
                if ( $addresses->[0]->is_match ) {
                     print "Address Matches Exactly!\n";
                } else {
                    print "Your address didn't match exactly. Following are some valid suggestions\n";
                    for (@$addresses ) {
                        printf("%s, %s %s\n", $_->city, $_->state, $_->postal_code);
                    }
                }
                print "quality was " . $addresses->[0]->quality . "\n";
            }
        } else {
            print localtime() . " SOMETHING FAILED!\n";
            print $self->errstr unless defined $addresses;
            print "Address is not correct, nor are there any suggestions\n";
            print $payload_debug;
        }
        $payload_debug = ''; # reset
        return $addresses;
    }
    sub shipping_confirm {
        my $self = shift;
        my $request_data = shift;

        my $xml_response = $self->post($self->confirm_proxy,
            $self->access_as_xml . 
            XMLout(
                $request_data,
                NoAttr     => 1,
                KeyAttr    => [],
                XMLDecl     => 0,
                KeepRoot    => 1,
            )
        );
        my $response_data = eval {
            XMLin($xml_response,
                  KeepRoot=>0, NoAttr=>1,
                  KeyAttr=>[], ForceArray=>["ShipmentConfirmResponse"]);
        };
        if ($response_data && $response_data->{Response}->{ResponseStatusDescription} eq 'Success'){
            print localtime() . " Shipping Confirm OK!\n";
        } else {
            print localtime() . " SOMETHING FAILED!\n";
            print "Couldn't parse XML\n" if !$response_data;
            print $payload_debug;
        }
        print $payload_debug if $DEBUG;
        $payload_debug = ''; #reset
    }
}

package main; ## no critic(ProhibitMultiplePackages)

Net::UPS::NAP::Debug->live(1);

#my $userid = 'u';
#my $password = 'p';
#my $accesskey = 'CC49F0003007FCA8';
my $userid = 'nap_dc2ca_live';
my $password = 'Toosh9GieR';
my $accesskey = 'FC4EDDED86DDDF68';

my $ups = Net::UPS::NAP::Debug->new($userid, $password, $accesskey);

$ups->validate_address(
    {
        city            => 'Las Vegas',
        state           => 'NV',
        postal_code     => '989109',
        country_code    => 'United States',
        is_residential  => 1,
    },
    { tolerance => 1 }
);
$ups->shipping_confirm( # not really confirming anything
    {
      ShipmentConfirmRequest => {
        Request => {
          RequestAction        => "ShipConfirm",
          RequestOption        => "validate",
          TransactionReference => { CustomerContext => "testnumber", XpciVersion => 1.0001 },
        },
        Shipment => {
          Shipper            => {
                                  Name => "NET-A-PORTER.COM",
                                  AttentionName => "IT Department",
                                  PhoneNumber => "1-800-481-1064",
                                  ShipperNumber => "X248F0",
                                  #ShipperNumber => "TESTACC",
                                  EMailAddress => "upstest\@net-a-porter.com",
                                  Address => {
                                    AddressLine1 => "DC2, 725 Darlington Avenue",
                                    City => "Mahwah",
                                    CountryCode => "US",
                                    PostalCode => "07430",
                                    StateProvinceCode => "NJ",
                                  },
                                },
          ShipTo             => {
                                  Address => {
                                    AddressLine1      => "DC2, 725 Darlington Avenue",
                                    AddressLine2      => "",
                                    AddressLine3      => "",
                                    City              => "Mahwah",
                                    CountryCode       => "US",
                                    PostalCode        => '07430',
                                    StateProvinceCode => "NJ",
                                  },
                                  AttentionName => "IT Department",
                                  CompanyName => "NET-A-PORTER.COM",
                                  EMailAddress => "upstest\@net-a-porter.com",
                                  Name => "NET-A-PORTER.COM",
                                  PhoneNumber => "1-800-481-1064",
                                },
          Package            => [
                                  {
                                    Description   => "Apparel",
                                    Dimensions    => {
                                                       Height => "5.50",
                                                       Length => 13.87,
                                                       UnitOfMeasurement => { Code => "IN" },
                                                       Width => 10.87,
                                                     },
                                    PackageWeight => { UnitOfMeasurement => { Code => "LBS" }, Weight => 3.312 },
                                    PackagingType => { Code => "02", Description => "Customer Supplied Package" },
                                  },
                                ],
          PaymentInformation => {
                                  Prepaid => {
                                               BillShipper => {
                                                 AccountNumber => "X248F0"
                                                 #AccountNumber => "TESTACC"
                                               }
                                  }
                                },
          Service            => { Code => "03", Description => "UPS Ground" },
        },
        LabelSpecification => {
          LabelPrintMethod => { Code => "EPL" },
          LabelStockSize   => { Height => 4, Width => 6 },
        },
      },
    }
);


