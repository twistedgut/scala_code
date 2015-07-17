package XT::DC::Model::GenerateXml;

use NAP::policy qw/class/;

use XTracker::Config::Local qw/config_var/;

use MooseX::Params::Validate qw( validated_hash );

use XML::Writer;


has xml_writer => (
    is      => 'rw',
    handles => {
        startTag        => 'startTag',
        emptyTag        => 'emptyTag',
        endTag          => 'endTag',
        dataElement     => 'dataElement',
        get_xml_string  => 'to_string',
    },
    builder => 'init_writer',
);

sub init_writer {
    my ($self) = @_;

    $self->xml_writer(XML::Writer->new(
        OUTPUT      => 'self',
        DATA_MODE   => 'true',
        DATA_INDENT => 4,
        ENCODING    => 'utf-8',
    ));
}

sub write_to_file{
    my ( $self, %parameters ) = validated_hash (
        \@_,
        order_id                => {isa =>'Str'},
        order_date              => {isa =>'Str'},
        channel                 => {isa =>'Str'},
        customer_id             => {isa =>'Str'},
        account_urn             => {isa =>'Str'},
        customer_ip             => {isa =>'Str', optional => 1},
        language                => {isa =>'Str', optional => 1},
        user_agent              => {isa =>'Str', optional => 1},
        accept_language         => {isa =>'Str', optional => 1},
        logged_in_username      => {isa =>'Str', optional => 1},
        tender                  => {isa =>'HashRef'},
        billing                 => {isa =>'HashRef'},
        shipping                => {isa =>'HashRef'},
        delivery                => {isa =>'HashRef'},
        gross_total             => {isa =>'HashRef'},
        postage                 => {isa =>'HashRef'},
        used_stored_credit_card => {isa => 'Str'},
        is_signature_required   => {isa => 'Bool', optional => 1},
        order_lines             => {isa => 'ArrayRef'},
        basket_promotions       => {isa => 'ArrayRef'},
        promotion_lines         => {isa => 'ArrayRef'}
    );
    my $xml_string = $self->_generate_xml_string(\%parameters);
    my $order_file_full_path = $self->_generate_file_name(\%parameters);

    open(my $file_handle, ">:encoding(UTF-8)", $order_file_full_path)
        || die "can't open $order_file_full_path for writing: $!";
    print $file_handle $xml_string;
    close($file_handle);

    return ($xml_string, $order_file_full_path);
}

sub _generate_xml_string {
    my ($self, $parameters) = @_;
    my ($xml_string, $error);

    $self->startTag('ORDERS');
        $self->startTag('ORDER',
            'O_ID'                    => $parameters->{order_id},
            'ORDER_DATE'              => $parameters->{order_date},
            'CHANNEL'                 => $parameters->{channel},
            'CUST_ID'                 => $parameters->{customer_id},
            'ACCOUNT_URN'             => $parameters->{account_urn},
            'CUST_IP'                 => $parameters->{customer_ip} // '10.3.32.186',
            'LANGUAGE'                => $parameters->{language} // 'en',
            'USED_STORED_CREDIT_CARD' => ($parameters->{used_stored_credit_card} ? 'T' : 'F' ),
            'SIGNATURE_REQUIRED'      => ($parameters->{is_signature_required} ? 'true' : 'false' ),
            'USER_AGENT'              => $parameters->{user_agent} // "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:30.0) Gecko/20100101 Firefox/30.0",
            'ACCEPT_LANGUAGE'         => $parameters->{accept_language} // 'en-gb',
            'LOGGED_IN_USERNAME'      => $parameters->{logged_in_username} // 'mytestaccount@net-a-porter.com',
            );
        $self->_generate_tender_line($parameters);
        $self->_generate_promotions($parameters);
        $self->_generate_billing_details($parameters);
        $self->_generate_delivery_details($parameters);
        $self->_generate_gross_total($parameters);
        $self->_generate_postage($parameters);
        $self->endTag('ORDER');
    $self->endTag('ORDERS');

    return $self->get_xml_string();
}

sub _create_order_line {
    my ($self, $order_line_counter, $line_data) = @_;

    return unless $line_data->{sku};

    $self->startTag('ORDER_LINE',
        OL_ID       => "$order_line_counter",
        DESCRIPTION => $line_data->{description},
        SKU         => $line_data->{sku},
        QUANTITY    => $line_data->{quantity},
        OL_SEQ      => "$order_line_counter"
    );
        $self->dataElement('SALE', $line_data->{sale} ? 'YES' : 'NO');
        $self->startTag('UNIT_NET_PRICE');
            $self->dataElement('VALUE', $line_data->{unit_net_price}->{amount},
                CURRENCY => $line_data->{unit_net_price}->{currency},
                );
        $self->endTag('UNIT_NET_PRICE');

        $self->startTag('TAX');
        $self->dataElement('VALUE', $line_data->{tax}{amount},
            CURRENCY => $line_data->{tax}{currency},
        );
        $self->endTag('TAX');

        $self->startTag('DUTIES');
        $self->dataElement('VALUE', $line_data->{duties}{amount},
            CURRENCY => $line_data->{duties}{currency},
        );
        $self->endTag('DUTIES');

        $self->dataElement('RETURNABLE', ($line_data->{is_returnable} ? 'YES' : 'NO'));
    $self->endTag('ORDER_LINE');
}

sub _generate_file_name{
    my($self, $parameters) = @_;

    my ($business,$region) = split(/-/, $parameters->{channel});

    # Format date
    my $expected_format = DateTime::Format::Strptime->new(
        pattern => '%Y-%m-%d %H:%M:%S',
        on_error => 'croak',
    );
    my $date_time = $expected_format->parse_datetime($parameters->{order_date});
    my $dt_pattern = DateTime::Format::Strptime->new(
        pattern => '%Y%d%m_%H%M%S',
        on_error => 'croak',
    );

    my $dt_formatted = $dt_pattern->format_datetime($date_time);
    my $order_file_name = sprintf('%s_%s_orders_%s.xml', $business, $region,
        $dt_formatted);
    my $order_file_full_path = File::Spec->catfile(
        config_var('SystemPaths', 'xmlwaiting_dir') , $order_file_name
    );

    return $order_file_full_path;
}

sub _generate_tender_line{
    my ($self, $parameters) = @_;

    $self->startTag('TENDER_LINE',
        TL_ID   => $parameters->{tender}{id},
        TYPE    => $parameters->{tender}{type},
        RANK => $parameters->{tender}{rank},
    );
    $self->dataElement('VALUE', $parameters->{tender}{amount},
        CURRENCY => $parameters->{tender}{currency},
    );
    if ($parameters->{tender}{pre_auth_code}){
        $self->startTag('PAYMENT_DETAILS');
        $self->dataElement('PRE_AUTH_CODE', $parameters->{tender}{pre_auth_code} );
        $self->endTag('PAYMENT_DETAILS');
    }
    $self->endTag('TENDER_LINE');
}

sub _generate_billing_details{
    my ($self, $parameters, $address_type) = @_;
    my $name = $parameters->{billing}{name};
    my $address = $parameters->{billing}{address};
    my $contact = $parameters->{billing}{contact};
    $self->startTag('BILLING_DETAILS');
        $self->startTag('NAME');
            $self->dataElement( TITLE => $name->{title});
            $self->dataElement( FIRST_NAME => $name->{firstname});
            $self->dataElement( LAST_NAME => $name->{last_name});
        $self->endTag('NAME');

        $self->startTag('ADDRESS','URN' => $address->{urn});
            $self->dataElement( ADDRESS_LINE_1 => $address->{line_1});
            $self->dataElement( ADDRESS_LINE_2 => $address->{line_2});
            $self->dataElement( ADDRESS_LINE_3 => $address->{line_3});
            $self->dataElement( TOWNCITY => $address->{towncity});
            $self->dataElement( COUNTY => $address->{county});
            $self->dataElement( STATE => $address->{state});
            $self->dataElement( POSTCODE => $address->{postcode});
            $self->dataElement( COUNTRY => $address->{country_code});
        $self->endTag('ADDRESS');

        $self->startTag('CONTACT_DETAILS');
            $self->dataElement('TELEPHONE', $contact->{home},
                TYPE => 'HOME',
            );
            $self->dataElement('TELEPHONE', $contact->{mobile},
                TYPE => 'MOBILE',
            );
            $self->dataElement('TELEPHONE', $contact->{office},
                TYPE => 'OFFICE',
            );
            $self->dataElement('EMAIL', $contact->{email});
        $self->endTag('CONTACT_DETAILS');
    $self->endTag('BILLING_DETAILS');
}

sub _generate_delivery_details{
    my ($self, $parameters) = @_;
    my $name = $parameters->{delivery}{name};
    my $address = $parameters->{delivery}{address};
    my $contact = $parameters->{delivery}{contact};

    $self->startTag('DELIVERY_DETAILS');
        $self->startTag('NAME');
            $self->dataElement( TITLE => $name->{title});
            $self->dataElement( FIRST_NAME => $name->{firstname});
            $self->dataElement( LAST_NAME => $name->{last_name});
        $self->endTag('NAME');

        my $delivery_address_urn = $address->{urn};
         $self->startTag(
            'ADDRESS',
            # ADD urn key only if we have value for it
            ( 'URN' => $delivery_address_urn )x!! $delivery_address_urn
            );
            $self->dataElement( ADDRESS_LINE_1 => $address->{line_1});
            $self->dataElement( ADDRESS_LINE_2 => $address->{line_2});
            $self->dataElement( ADDRESS_LINE_3 => $address->{line_3});
            $self->dataElement( TOWNCITY => $address->{towncity});
            $self->dataElement( COUNTY => $address->{county});
            $self->dataElement( STATE => $address->{state});
            $self->dataElement( POSTCODE => $address->{postcode});
            $self->dataElement( COUNTRY => $address->{country_code});
        $self->endTag('ADDRESS');

        $self->startTag('CONTACT_DETAILS');
            $self->dataElement('TELEPHONE', $contact->{home},
                TYPE => 'HOME',
            );
            $self->dataElement('TELEPHONE', $contact->{mobile},
                TYPE => 'MOBILE',
            );
            $self->dataElement('TELEPHONE', $contact->{office},
                TYPE => 'OFFICE',
            );
            $self->dataElement('EMAIL', $contact->{email});
        $self->endTag('CONTACT_DETAILS');

        my $order_line_counter = 1;
        if ($parameters->{shipping}{sku}) {
            $self->_create_order_line($order_line_counter, $parameters->{shipping});
            $order_line_counter++;
        }

        for my $order_line (@{$parameters->{order_lines}}) {
            $self->_create_order_line($order_line_counter, $order_line);
            $order_line_counter++;
        }
    $self->endTag('DELIVERY_DETAILS');
}

sub _generate_gross_total{
    my ($self, $parameters) = @_;

    $self->startTag('GROSS_TOTAL');
        $self->dataElement(
            'VALUE',
            $parameters->{gross_total}{amount},
            CURRENCY => $parameters->{gross_total}{currency},
        );
    $self->endTag('GROSS_TOTAL');
}

sub _generate_postage{
    my ($self, $parameters) = @_;
    $self->startTag('POSTAGE');
            $self->dataElement(
                'VALUE',
                $parameters->{postage}{amount},
                CURRENCY => $parameters->{postage}{currency},
            );
    $self->endTag('POSTAGE');
}

sub _generate_promotions{
    my ($self, $parameters) = @_;
    my $promotion_counter = 1;

    for my $promotion_basket (@{$parameters->{basket_promotions}}) {
        $self->_create_promotion_basket_details(
            $promotion_counter++,
            $promotion_basket);
    }

    $promotion_counter = 1;
    for my $promotion_line (@{$parameters->{promotion_lines}}) {
        $self->_create_promotion_line_details(
            $promotion_counter++,
            $promotion_line);
    }
}
sub _create_promotion_line_details{
    my ($self, $order_line_counter, $line_data) = @_;

    return unless $line_data->{type};

    $self->startTag('PROMOTION_LINE',
        PL_ID       => "$order_line_counter",
        TYPE        => $line_data->{type},
        DESCRIPTION => $line_data->{description}
    );
        $self->dataElement(
            'VALUE',
            $line_data->{value},
            CURRENCY => $line_data->{currency}
        );

        $self->dataElement('ORDER_LINE_ID', "$order_line_counter");

    $self->endTag('PROMOTION_LINE');
}
sub _create_promotion_basket_details{
    my ($self, $order_line_counter, $line_data) = @_;

    return unless $line_data->{type};

    $self->startTag('PROMOTION_BASKET',
        PB_ID       => "$order_line_counter",
        TYPE        => $line_data->{type},
        DESCRIPTION => $line_data->{description}
    );
        $self->dataElement(
            'VALUE',
            $line_data->{value},
            CURRENCY => $line_data->{currency}
        );

    $self->endTag('PROMOTION_BASKET');
}

__END__

=head1 NAME

XT::DC::Model::GenerateXml - generate XML order file

=head1 DESCRIPTION

This module can be used to generate and save order XML documents to
I</var/data/xml/xmlwaiting>.
Input parameters are to be in the form of a hashref.

=head1 ATTRIBUTES

=head2 xml_writer

XML::Writer object

=head1 METHODS

=head2 write_to_file

Converts parameters passed into an order XML document, and writes this to the
xmlwaiting directory.

Takes order data hash as input.



