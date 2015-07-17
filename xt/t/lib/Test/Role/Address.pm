package Test::Role::Address;

use strict;
use warnings;
use utf8;

use Moose::Role;

# FIXME: We require these for some of the subs, but not all... so removing this
# for now as when this is called in t/conf/modperl_extra.pl we don't need to
# provide a schema object. Fix this properly by providing the schema object
# from a separate module, not from the consuming class.
#requires 'get_schema';

use Carp;

use Test::Config;
use XTracker::Config::Local qw/ dc_address /;
use XTracker::Database::Address qw/hash_address/;
use XTracker::Role::WithSchema;

=head2 ca_good_address_data

Return a hashref with data that will be accepted by carrier automation.

=head3 NOTE

When running Apache's test server, due to an override in
t/conf/modperl_startup.pl this is the only address that will pass carrier
automation.

=cut

sub ca_good_address_data {
    return {
        address => {
            first_name      => 'Test',
            last_name       => 'Record',
            address_line_1  => '3790 Las Vegas Boulevard South',
            address_line_2  => '',
            address_line_3  => '',
            towncity        => 'Las Vegas',
            county          => 'NV',
            postcode        => '89109',
            country         => 'United States',
        },
        shipment => {
            email       => 'backend@net-a-porter.com',
            telephone   => '1-800-481-1064',
        },
    };
}

=head2 ca_good_address

    ca_good_address( $shipment );

Pass in a shipment record and this will de-scrub the data and give it
a clean address for Carrier Automation.

=head3 NOTE

See L<ca_good_address_data> for details of the address and CA behaviour in test
mode.

=cut

sub ca_good_address {
    my $class       = shift;
    my $shipment    = shift;

    $shipment->discard_changes;

    order_address( $class, {
            address         => 'update',
            address_id      => $shipment->shipment_address_id,
            %{$class->ca_good_address_data->{address}},
        } );
    $shipment->update( $class->ca_good_address_data->{shipment} );

    return;
}

=head2 ca_bad_address

    ca_bad_address( $shipment );

Pass in a shipment record and this will give it a poor address for Carrier Automation.

=cut

sub ca_bad_address {
    my $class       = shift;
    my $shipment    = shift;

    $shipment->discard_changes;

    order_address( $class, {
            address         => 'update',
            address_id      => $shipment->shipment_address_id,
            first_name     => 'Billy',
            last_name      => 'Bongo',
            address_line_1 => "AAAAAAAAAAAAAAAAAAAAAAA",
            address_line_2 => "BBBBBBBBBBBBBBBBBBBBBBB",
            address_line_3 => "CCCCCCCCCCCCCCCCCCCCCCC",
            towncity       => "DDDDDDDDDDDDDDDDDDDDDDD",
            county         => "CA", # Must be valid or you get:
                                    # UPS API: 120206 - Missing or invalid ship to StateProvinceCode
            country        => "United States", # Must be valid or Shipment->customer_details fails
            postcode       => "GGGGGGGGGGGGGGGGGGGGGGG",
        } );

    return;
}

=head2 valid_address() : \%valid_address

Return a hashref of named addresses that should validate against the mocked DHL service.

=cut

sub valid_address {
    my ($class) = @_;

    # The dc address for any channel is considered valid
    my @channels = XTracker::Role::WithSchema->build_schema->resultset('Public::Channel')->search;
    my %valid_addresses = map {
        my $channel = $_;
        my $dc_address = dc_address($channel);
        my $current_dc_common = {
            address_line_1 => $dc_address->{addr1},
            address_line_2 => $dc_address->{addr2},
            address_line_3 => $dc_address->{addr3},
            towncity       => $dc_address->{city},
            country        => $dc_address->{country},
        };

        # For backwards cmpatibility, we retain names without a postfix as the 'NAP' addresses
        my $postfix = ( $channel->name eq 'NET-A-PORTER.COM' ? '' : '_' . $channel->web_name );
        {
            'current_dc' . $postfix => {
                %$current_dc_common,
                postcode => Test::Config->value( 'OrderAddress::Normal' => 'postcode' ),
                county   => Test::Config->value( 'OrderAddress::Normal' => 'county' ),
            },
            'current_dc_premier' . $postfix => {
                %$current_dc_common,
                postcode => Test::Config->value( 'OrderAddress::Premier' => 'postcode' ),
                county   => Test::Config->value( 'OrderAddress::Premier' => 'county' ),
            },
            'current_dc_other' . $postfix => {
                %$current_dc_common,
                postcode => Test::Config->value( 'OrderAddress::Other' => 'postcode' ),
                county   => Test::Config->value( 'OrderAddress::Other' => 'county' ),

            },
        }
    } @channels;

    return {
        %valid_addresses,
        sample => {
            (map {; $_ => 'Sample' } qw{
                address_line_1
                address_line_2
                address_line_3
                towncity
            }),
            country => (XTracker::Config::Local::samples_addr)[3],
            postcode => 'SA MPLE',
        },
        LondonPremier => {
            address_line_1 => "The Village Offices",
            address_line_2 => "Westfield",
            address_line_3 => "",
            towncity       => "London",
            county         => "",
            country        => "United Kingdom",
            postcode       => "W12 7GF",
        },
        UK => {
            address_line_1 => "3 Swabey Road",
            address_line_2 => "Slough",
            address_line_3 => "",
            towncity       => "London",
            county         => "",
            country        => "United Kingdom",
            postcode       => "SL3 8NP",
        },
        EU => {
            address_line_1 => "Herrn Eberhard Wellhausen",
            address_line_2 => "Schulstrasse 4",
            address_line_3 => "",
            towncity       => "Bad Oyenhausen",
            county         => "",
            country        => "Germany",
            postcode       => "32547",
        },
        Chile => {
            address_line_1 => "Av Libertador Bernardo O`Higgins 3363",
            address_line_2 => "",
            address_line_3 => "",
            towncity       => "Santiago",
            county         => "",
            country        => "Chile",
            postcode       => "",
        },
        Gibraltar => {
            address_line_1 => "32 - 36 Town Range",
            address_line_2 => "",
            address_line_3 => "",
            towncity       => "Gibraltar",
            county         => "",
            country        => "Gibraltar",
            postcode       => "",
        },
        Norway => {
            address_line_1 => "Marit Skognars",
            address_line_2 => "Havnegaten 1-3",
            address_line_3 => "P.O Box 103",
            towncity       => "Trondheim",
            county         => "",
            country        => "Norway",
            postcode       => "7400",
        },
        Thailand => {
            address_line_1 => "14 Wireless Road Lumpini",
            address_line_2 => "Pathum Wan",
            address_line_3 => "",
            towncity       => "Bangkok",
            county         => "",
            country        => "Thailand",
            postcode       => "10330",
        },
        Europe => {
            address_line_1 => "Marit Skognars",
            address_line_2 => "Havnegaten 1-3",
            address_line_3 => "P.O Box 103",
            towncity       => "Trondheim",
            county         => "",
            country        => "Norway",
            postcode       => "7400",
        },
        IntlWorld => {
            address_line_1 => "Sencan",
            address_line_2 => "Fazlipasa Caddesi No. 8",
            address_line_3 => "",
            towncity       => "Topkapi/Istanbul",
            county         => "",
            country        => "Turkey",
            postcode       => "34020",
        },
        US => {
            address_line_1 => "Apartment 221B",
            address_line_2 => "Frump Towers",
            address_line_3 => "100 5th Avenue",
            towncity       => "New York",
            county         => "NY",
            country        => "United States",
            postcode       => "10011",
        },
        US2 => {
            address_line_1 => "Mr Bones",
            address_line_2 => "144 Penn Avenue",
            address_line_3 => "",
            towncity       => "Los Angeles",
            county         => "CA",
            country        => "United States",
            postcode       => "90230",
        },
        US2 => {
            address_line_1 => "Mr Bones",
            address_line_2 => "144 Penn Avenue",
            address_line_3 => "",
            towncity       => "Los Angeles",
            county         => "CA",
            country        => "United States",
            postcode       => "90230",
        },
        US3 => {
            address_line_1 => "Hugh Letpackard Inc",
            address_line_2 => "3710 NE Circle Blvd",
            address_line_3 => "",
            towncity       => "Corvallis",
            county         => "OR",
            country        => "United States",
            postcode       => "97330",
        },
        US4 => {
            address_line_1 => "Bell Labs",
            address_line_2 => "600 Mountain Avenue",
            address_line_3 => "",
            towncity       => "Murray Hill",
            county         => "NJ",
            country        => "United States",
            postcode       => "07974-0636",
        },
        US5 => {
            address_line_1 => "Billy Bongo",
            address_line_2 => "123 Bingo Street",
            address_line_3 => "",
            towncity       => "Los Angeles",
            county         => "CA",
            country        => "United States",
            postcode       => "90230",
        },
        Canada => {
            address_line_1 => "Canadian Nuclear Society",
            address_line_2 => "655 Bay St",
            address_line_3 => "",
            towncity       => "Toronto",
            county         => "ON",
            country        => "Canada",
            postcode       => "M5G 2K4",
        },
        ManhattanPremier => {
            address_line_1 => "Billy Bongo",
            address_line_2 => "34 8th Avenue",
            address_line_3 => "Manhattan",
            towncity       => "New York",
            county         => "NY",
            country        => "United States",
            postcode       => "10014",
        },
        AmWorld => {
            address_line_1 => "Sr. Rodrigo Domínguez",
            address_line_2 => "Av. Bellavista N° 185",
            address_line_3 => "Dep. 609",
            towncity       => "Santiago",
            county         => "",
            country        => "Chile",
            postcode       => "8420507",
        },
        AmWorldDifferentCountry => { # Same DDU status as Chile, i.e. Non DDU
            address_line_1 => "Sr. Rodrigo Domínguez",
            address_line_2 => "Av. Francisco de Miranda",
            address_line_3 => "Los Palos Grandes",
            towncity       => "Caracas",
            county         => "",
            country        => "Venezuela",
            postcode       => "1060",
        },
        HongKongPremier => {
            address_line_1 => "Interlink Building",
            address_line_2 => "10th Floor",
            address_line_3 => "35-47 Tsing Yi Road",
            towncity       => "Tsing Yi",
            county         => "Aberdeen",
            country        => "Hong Kong",
            postcode       => "",
        },
        NonASCIICharacters => {
            address_line_1 => "Les naïfs ægithales",
            address_line_2 => "我能吞下玻璃而不傷身體。",
            address_line_3 => "我能吞下玻璃而不傷身體。",
            towncity       => "Bâcêdîgôrûtèsàkùlëhïç",
            county         => "Düßeldorf",
            country        => "United Kingdom",    # Testing unicode not country restrictions
            postcode       => "SL3 8NP",
        },
        Latin1Characters => {
            address_line_1 => "Les naïfs ægithales",
            address_line_2 => "Liebe Grüße aus UK",
            address_line_3 => "",
            towncity       => "Düßeldorf",
            county         => "",
            country        => "Germany",
            postcode       => "SL3 8NP",
        },
        Ireland_Dublin => {
            address_line_1 => "Alexandra Road",
            address_line_2 => "Ferryport",
            address_line_3 => "",
            towncity       => "Dublin",
            county         => "",
            country        => "Ireland",
            postcode       => "1",
        },
        Ireland_Other => {
            address_line_1 => "Cork Institute of Technology",
            address_line_2 => "Rossa Avenue",
            address_line_3 => "",
            towncity       => "Bishopstown",
            county         => "Cork",
            country        => "Ireland",
            postcode       => "",
        },
        Russia => {
            address_line_1 => "British Consulate",
            address_line_2 => "Pl. Proletarskoy Diktatury, 5",
            address_line_3 => "",
            towncity       => "St Petersburg",
            county         => "",
            country        => "Russia",
            postcode       => "191124",
        },
    };
}

=head2 invalid_address() : \%invalid_address

Return a hashref of named invalid addresses.

=cut

sub invalid_address {
    return {
        US_broken => {
            address_line_1 => "987 Broken Street",
            address_line_2 => "Nowhere at all and probably so long that who knows what will happen?",
            address_line_3 => "",
            towncity       => "New Work",  # check the spelling
            county         => "Whoops!",
            country        => "United States", # keep this right, at least
            postcode       => "XX 987654-EZ1", # three problems in one
        },
    };
}

=head2 create_order_address_in($location, [%$override_args]) : $new_dbic_address_row

Create a typical new address in $location, possibly with details
overriden by %$override_args values.

$location values are e.g.

  DC1
  DC2
  current_dc
  current_dc_premier
  LondonPremier
  UK
  EU
  Europe
  IntlWorld

  US

Note that the current_dc address isn't necessarily _in_ the DC city
outside the Premier zone, it's just a domestic address that the DC
ships to. E.g. the US address is in CA.

=cut

sub create_order_address_in {
    my ($self, $location, $override_args) = @_;
    $override_args //= {};

    # we can just specify a DC if we want to
    if ( $location =~ m{^(DC1|DC2|DC3)$}i ) {
        $location = 'current_dc';
    }

    my %location_name_args = (
        map { %{$self->$_} } qw/valid_address invalid_address/
    );
    my $location_args = $location_name_args{$location}
        or croak(
            "Invalid \$location ($location). Valid locations are:\n"
            . join("\n", ( 'DC1', 'DC2', sort keys %location_name_args ) )
        );

    my $address = $self->order_address({
        address => "create",
        %$location_args,
        %$override_args,
    });
}

=head2 order_address

$addr_rec    = order_address( {
                                address => 'create'|'update',
                                address_id => $address_id (updating only),
                                first_name => 'John',
                                last_name => 'Smith',
                                    etc. etc.
                           } );

Creates or Updates an address in the 'order_address' table.

If creating an address then this gets the first address from the table and copies it to create a new one replacing various fields with any that are passed in to the through an anonymous hash. If updating it updates an address with details passed in.

The new address record is returned.

=cut

sub order_address {
    my ( $class, $args )    = @_;

    my $addr_rs = $class->get_schema->resultset('Public::OrderAddress');

    my $addr_rec;
    my $old_addr;
    my %new_addr;
    my $action  = delete $args->{address};

    if ( $action eq "create" ) {
        %new_addr = (
            first_name     => 'some',
            last_name      => 'one',
            address_line_1 => 'al1',
            address_line_2 => 'al2',
            address_line_3 => 'al3',
            towncity       => 'twn',
            county         => '',
            country        => 'United Kingdom',
            postcode       => 'd6a31',
        );
    } else {
        $old_addr   = $addr_rs->find( delete $args->{address_id} );
        foreach ( $old_addr->columns ) {
            next        if /(id)|(address_hash)/;
            $new_addr{$_}   = $old_addr->get_column($_);
        }
    }


    # overwrite passed in address details
    map { $new_addr{$_} = $args->{$_} } keys %{ $args };

    # work out the new address hash
    $new_addr{address_hash}     = hash_address( undef, \%new_addr );

    if ( $action eq "create" ) {
        $addr_rec   = $addr_rs->create ( \%new_addr );
    } else {
        $old_addr->update( \%new_addr );
        $addr_rec   = $old_addr;
    }

    return $addr_rec;
}

sub create_order_address {
    my ($class, $args) = @_;
    $args //= {};
    my $schema = $class->get_schema;

    my $params = {
        first_name      => 'Test',
        last_name       => 'Tester',
        address_line_1  => 'TestAddress',
        address_line_2  => 'TestAddress',
        address_line_3  => 'TestAddress',
        towncity        => 'TestCity',
        county          => 'TestCounty',
        country         => 'United Kingdom',
        postcode        => 'TestPostCode',
        address_hash    => 'testhash',
        %$args
    };

    return $schema->resultset('Public::OrderAddress')->create($params);
}

=head2 mock_validate_address

Return a mock object which when in scope only validate addresses for DHL given
by L<valid_address> successfully.

=cut

sub mock_validate_address {
    # Mock our calls to DHL
    use XTracker::DHL::XMLRequest;
    use Test::XT::Override::TraitFor::XTracker::DHL::XMLRequest;
    my $orig_dhl = \&XTracker::DHL::XMLRequest::send_xml_request;
    my $mocked_dhl = Test::MockModule->new('XTracker::DHL::XMLRequest');
    $mocked_dhl->mock( send_xml_request => sub {
        my $self = shift;
        Test::XT::Override::TraitFor::XTracker::DHL::XMLRequest::overridden_send_xml_request($self,$orig_dhl,@_);
    });
    return $mocked_dhl;
}

1;
