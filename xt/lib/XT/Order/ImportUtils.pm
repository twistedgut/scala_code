package XT::Order::ImportUtils;

use Moose;
use namespace::autoclean;
use XML::LibXML;
use Catalyst::Utils;
use XTracker::Logfile qw( xt_logger );


use XTracker::Database qw( get_database_handle get_schema_using_dbh );
use XTracker::Database::Channel qw( get_channel_details );
use XTracker::Database::Customer qw( check_customer );
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw( :customer_category
                                    :flag
                                    :order_status
                                    :pws_action
                                    :shipment_class
                                    :shipment_item_status
                                    :shipment_status
                                    :shipment_type );

has 'parser' => ( is         => 'ro',
                  isa        => 'XML::LibXML',
                  lazy_build => 1 );
#has 'dc' => (
#    is => 'ro',
#    default => 'DC1',
#);

has 'dbh'    => ( is         => 'ro',
                  isa        => 'DBI::db',
                  lazy_build => 1 );

has 'dc'     => ( is         => 'ro',
                  isa        => 'Str',
                  lazy_build => 1 );

sub _build_dc {
    return config_var('DistributionCentre', 'name');
}

sub _build_parser {

    my $parser = XML::LibXML->new();
    $parser->validation(0);

    return $parser;
}

sub _build_dbh {

    return get_database_handle( { name => 'xtracker',
                                  type => 'transaction' } )
      || die print "Error: Unable to connect to DB";
}


sub parse_order_file {

    my ($self, $path) = @_;

    return $self->parser->parse_file($path);
}

sub extract_fields {
    my($self,$node,$mapping) = @_;
    my $out = { };

    foreach my $key (keys %{$mapping}) {
        eval {
            my $field = $node->findvalue($mapping->{ $key });
#            $out->{$key} = $field->string_value;
        };
        if ($@) {
            print "FECK $@\n";
        }
    }

    return $out;
}


sub extract_name {
    my($self,$node,$nodename) = @_;
    my $mapping = {
        title       => "$nodename/TITLE",
        first_name  => "$nodename/FIRST_NAME",
        last_name   => "$nodename/LAST_NAME",
    };
    return $self->_extract_fields($node,$mapping);
}

sub extract_address {
    my($self,$node,$nodename) = @_;
    my $mapping = {
        address_line_1 => "$nodename/ADDRESS_LINE_1",
        address_line_2 => "$nodename/ADDRESS_LINE_2",
        address_line_3 => "$nodename/ADDRESS_LINE_3",
        towncity => "$nodename/TOWNCITY",
        county => "$nodename/COUNTY",
        state => "$nodename/STATE",
        postcode => "$nodename/POSTCODE",
        country => "$nodename/COUNTRY",
    };

    my $data = $self->_extract_fields($node,$mapping);

    # sort out the address do don't need to do this again and again
    if ($self->dc eq 'DC2') {
        $data->{county} = delete $data->{state};
    } else {
        # we shouldn't have this if its not US
        delete $data->{state};
    }

    return $data;
}

sub fraud_data {
    my($self,$onode) = @_;

    my $data = {
        Customer => {
            Email => $onode->findvalue('BILLING_DETAILS/CONTACT_DETAILS/EMAIL'),
# FIXME: ummm which telephone is is deduced from?
#            Telephone => $order->telephone,
        },
    };

    my @addresses;
    # billing details - only one of these
    push @addresses, {
        name => $self->extract_name($onode,'BILLING_DETAILS/NAME'),
        address => $self->extract_address($onode,'BILLING_DETAILS/ADDRESS'),
    };

    # its possible to have multiple deliveries with different addresses
    foreach my $delivery ($onode->findnodes('DELIVERY')) {
        push @addresses, {
            name => $self->extract_name($onode,'NAME'),
            address => $self->extract_address($onode,'ADDRESS'),
        };
    }

    # concatenate all the addresses we have for a regex match later
    my $fraud_address = { };
    foreach my $address (@addresses) {
        $fraud_address->{'Name'} .= ' '.
            $address->{name}->{first_name} ." ". $address->{name}->{last_name};

        $fraud_address->{'Street Address'} .=
            ' '.  $address->{address}->{address_line_1}
            .' '. $address->{address}->{address_line_2};

        $fraud_address->{'Town/City'} .= ' '.  $address->{address}->{towncity};

        $fraud_address->{'County/State'} .=
            ' '.  $address->{address}->{county};

        $fraud_address->{'Postcode/Zipcode'} .=
            ' '.  $address->{address}->{postcode};

        $fraud_address->{'Country'} .=
            ' '.  $address->{address}->{country};
    }

    $data->{Address} = $fraud_address;

#    $data->{"Payment"}{"Card Number"}
#        = $order_data->{payment_info}{card_number};
# FIXME: this is from payment_info which is from after tender_line processing
#    $order_data->{payment_info}{card_number};


    return $data;
}

sub order_elements {

    my ($self, $doc) = @_;

    return $doc->documentElement()->findnodes('ORDER');
}

sub order_data {

    my ($self, $order_node) = @_;

    my $order_data = {};

    $order_data->{order_nr}               = $order_node->findvalue('@O_ID');
    $order_data->{basket_id}              = $order_data->{order_nr};
    $order_data->{session_id}             = "";
    $order_data->{cookie_id}              = "";
    $order_data->{order_status_id}        = $ORDER_STATUS__ACCEPTED;
    $order_data->{customer_nr}            = $order_node->findvalue('@CUST_ID');
    $order_data->{channel}                = $order_node->findvalue('@CHANNEL');
    $order_data->{channel_id}             = _get_channel_id($self->dbh(), $order_data->{channel});
    $order_data->{used_stored_card}       = $order_node->findvalue('@USED_STORED_CREDIT_CARD');
    $order_data->{ip_address}             = $order_node->findvalue('@CUST_IP');
    $order_data->{placed_by}              = $order_node->findvalue('@LOGGED_IN_USERNAME');
    $order_data->{final_calculated_total} = 0;
    $order_data->{transaction_value}      = 0;
    $order_data->{voucher_credit}         = 0;
    $order_data->{store_credit}           = 0;
    $order_data->{gift_credit}            = 0;

    ### legacy card info
    $order_data->{card_number}            = "-";
    $order_data->{card_issuer}            = "-";
    $order_data->{card_scheme}            = "-";
    $order_data->{card_country}           = "-";
    $order_data->{cv2_response}           = "-";
    $order_data->{email}                  = $order_node->findvalue('BILLING_DETAILS/CONTACT_DETAILS/EMAIL');
    $order_data->{home_telephone}         = "";
    $order_data->{work_telephone}         = "";
    $order_data->{mobile_telephone}       = "";
    $order_data->{credit_rating}          = 1;
    $order_data->{address_match}          = 1;
    $order_data->{sticker}                = $order_node->findvalue('DELIVERY_DETAILS/STICKER');

    # Delivery Signature Required (CANDO-216)
    my $signature_required              = lc( $order_node->findvalue('@SIGNATURE_REQUIRED') );
    # Delivery Signature Opt Out, NULL or EMPTY implies TRUE
    $order_data->{signature_required}   = (
                                            !$signature_required
                                                || $signature_required eq 'true'
                                            ? 1     # signature Required
                                            : 0     # signature NOT Required
                                        );

    # DC specific fields
    if ( $self->dc() eq 'DC2' ) {
        $order_data->{order_date}
          = _get_est_date( $order_node->findvalue('@ORDER_DATE') );
        $order_data->{use_external_tax_rate}
          = $order_node->findvalue('@USE_EXTERNAL_SALETAX_RATE') || 0;
    }
    else { # Default to reading value from XML file
        $order_data->{order_date} = $order_node->findvalue('@ORDER_DATE');
    }

    # Premier Routing same for both DC's now (CANDO-78)
    $order_data->{premier_routing_id}
      = $order_node->findvalue('@PREMIER_ROUTING_ID');

    # used stored card flag
    if ($order_data->{used_stored_card} eq 'T'){
        $order_data->{used_stored_card} = 1;
    }
    else {
        $order_data->{used_stored_card} = 0;
    }

    # get telephone numbers from billing contact details
    $order_data
      = Catalyst::Utils::merge_hashes( $order_data,
                                       extract_telephone($order_node,'BILLING_DETAILS/CONTACT_DETAILS'));

    # order totals and currency
    $order_data->{gross_total}    = $order_node->findvalue('GROSS_TOTAL/VALUE');
    $order_data->{gross_shipping} = $order_node->findvalue('POSTAGE/VALUE');
    $order_data->{currency_id}
      = _get_currency_id( $self->dbh(),
                          $order_node->findvalue('GROSS_TOTAL/VALUE/@CURRENCY') );

    # check and update/create customer record
    $order_data->{customer_id}
      = check_customer($self->dbh(),
                       $order_data->{customer_nr},
                       $order_data->{channel_id});

    return $order_data;
}


sub _get_currency_id {
    my ($dbh, $currency) = @_;

    my $id = 0;

    my $qry  = "SELECT id FROM currency WHERE currency = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($currency);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $id = $row->[0];
    }
    return $id;
}

sub _get_channel_id {

    my ($dbh, $channel) = @_;

    my $id  = 0;
    my $qry = "SELECT id FROM channel WHERE web_name = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($channel);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $id = $row->[0];
    }

    return $id;
}

sub _get_est_date {
    my ( $date ) = @_;
    my $fmt = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M', time_zone => 'Europe/London');
    my $date_time_object = $fmt->parse_datetime($date); # '2009-10-28 17:10'
    $date_time_object->set_time_zone('America/New_York');
    return $date_time_object;
}


sub extract_telephone {

    my($order,$node) = @_;
    my $numbers = { };

    foreach my $telephone ($order->findnodes("$node/TELEPHONE")) {
        if ($telephone->findvalue('@TYPE') eq "HOME") {
            $numbers->{home_telephone} = $telephone->hasChildNodes
              ? $telephone->getFirstChild->getData : "";
        }
        elsif ($telephone->findvalue('@TYPE') eq "OFFICE") {
            $numbers->{work_telephone} = $telephone->hasChildNodes
              ? $telephone->getFirstChild->getData : "";
        }
        elsif ($telephone->findvalue('@TYPE') eq "MOBILE") {
            $numbers->{mobile_telephone} = $telephone->hasChildNodes
              ? $telephone->getFirstChild->getData : "";
        }
    }

    $numbers->{telephone} = (defined $numbers->{home_telephone} and $numbers->{home_telephone} eq "")
      ? $numbers->{work_telephone}
        : $numbers->{home_telephone};

    return $numbers;
}

sub bill_data {
    my($self,$onode) = @_;
    my $data = $self->extract_name($onode,'BILLING_DETAILS/NAME');

    $data = Catalyst::Utils::merge_hashes(
        $data, $self->extract_address($onode,'BILLING_DETAILS/ADDRESS')
    );

    #$data->{country} = # _get_country_by_code($dbh, $data->{country})


    return $data;
}

sub customer_data {
    my($self,$onode, $channel_id) = @_;
    my $data = {
        is_customer_number => $onode->findvalue('@CUST_ID'),
#$onode->findvalue('');
        category_id        => $CUSTOMER_CATEGORY__NONE,
# FIXME:
#        email              => $order_data->{email};
#        telephone_1        => $order_data->{home_telephone};
#        telephone_2        => $order_data->{work_telephone};
#        telephone_3        => $order_data->{mobile_telephone};
        channel_id         => $channel_id,
    };

    $data = Catalyst::Utils::merge_hashes(
        $data, $self->extract_name($onode,'BILLING_DETAILS/NAME')
    );

    $data = Catalyst::Utils::merge_hashes(
        $data, $self->extract_address($onode,'BILLING_DETAILS/ADDRESS')
    );

    #$data->{country} = # _get_country_by_code($dbh, $data->{country})


    return $data;
}

__PACKAGE__->meta->make_immutable;

1;

