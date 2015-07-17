package XT::Importer;
use Moose;
use namespace::autoclean;
use XML::LibXML;
use Data::Dump qw/pp/;


has 'debug' => (
    is => 'rw',
    default => 0,
);

has 'parser' => (
    is => 'rw',
);
    # kind of need to abstract this abit
#    isa => 'XML::LibXML',

has 'type' => (
    is => 'rw',
    isa => 'Str',
);

has 'opts' => (
    is => 'rw',
);

has 'dc' => (
    is => 'rw',
);

sub parse {
    my($self) = @_;
    warn "parsing" if ($self->debug);

    if ($self->type eq 'xml') {
        return $self->parse_xml();
    } else {
        die __PACKAGE__ .": Don't know what type";
    }
}

### xml start
sub parse_xml {
    my($self) = @_;
    warn "  parsing xml" if ($self->debug);


    # we get an array of hashrefs
    my $orders = $self->_extract_xml();
    if ( $self->debug ) {
        warn "  extracted from xml".pp($orders)."===> ". $orders->[0]->{_o_id};
    }

    my $mapped = _map_xml_to_order_obj($orders);
    warn "  converted xml to standard order" if ($self->debug);

    return $mapped;
}

# FIXME: to do
sub _map_xml_to_order_obj {
    my($self,$orders) = @_;
    my $out = [];

    foreach my $order (@{$orders}) {
#        my $new = undef;
        # FIXME: will be fine for now
        my $new = $order;

        # loop through and translate it

        push @{$out}, $new;
    }

    return $orders;
}


sub _extract_xml {
    my($self) = @_;
    my $orders = [];
    my $mapping = {
        _o_id => '@O_ID',
        _order_date => '@ORDER_DATE',
        _channel => '@CHANNEL',
        _cust_id => '@CUST_ID',
        _cust_ip => '@CUST_IP',
        _used_stored_credit_card => '@USED_STORED_CREDIT_CARD',
        _type => '@TYPE',
    };
    warn "    _extract_xml" if ($self->debug);

    # global to extract_orders and its kiddies
#    $DC = $args{DC};
#    $dbh ||= $args{dbh};
#    $schema ||= get_schema_using_dbh($dbh,'xtracker_schema');

    ### flag to catch any import errors
#    my $import_error = 0;
    my $parser = XML::LibXML->new();
    $parser->validation(0);
    $self->parser( $parser );

    my $file = $self->opts->{file};
    my $tree = undef;
    eval {
        open my $xml, "<", $file || die "can't open file: $!";
        $tree = $self->parser->parse_fh( $xml );
        close($xml);
    };
    if ($@) {
        die "Failed to parse xml file - $file";
    }

    my $root = $tree->getDocumentElement;

#DEL    my @orders = $root->getElementsByTagName('ORDER');
#DEL    my $order_email_data;
print "Click!\n";
    foreach my $order ($root->findnodes('ORDER')) {
        my $out = $self->_extract_fields_xml($order,$mapping);


        # tender_line
        $out->{tender_line} =
            $self->_extract_tender_line($order);
#        # promotion_basket
        $out->{promotion_basket} =
            $self->_extract_promotion_basket($order,'PROMOTION_BASKET');
#        # promotion_line
#        $out->{promotion_line} =
#            $self->_extract_promotion_line($order,'PROMOTION_LINE');
        # billing_details
        $out->{billing_details} =
            $self->_extract_billing_details($order,'BILLING_DETAILS');
        # delivery_details
        $out->{delivery_details} =
            $self->_extract_delivery_details($order,'DELIVERY_DETAILS');
        # gross_total
        $out->{gross_total} =
            $self->_extract_value_xml($order,'GROSS_TOTAL');
        # postage
        $out->{postage} =
            $self->_extract_value_xml($order,'POSTAGE');

        push @{$orders}, $out;
    }
    return $orders;
}

sub _extract_fields_xml {
    my($self,$node,$mapping) = @_;
    my $out = { };

    foreach my $key (keys %{$mapping}) {
        eval {
            my $field = $node->findnodes($mapping->{ $key });
            $out->{$key} = $field->string_value;
        };
        if ($@) {
            print "FECK $@\n";
        }
    }

    return $out;
}

sub _extract_name_xml {
    my($self,$node,$nodename) = @_;
    my $mapping = {
        title       => "$nodename/TITLE",
        first_name  => "$nodename/FIRST_NAME",
        last_name   => "$nodename/LAST_NAME",
    };
    my $out = $self->_extract_fields_xml($node,$mapping);

    return $out;
}

sub _extract_address_xml {
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

    my $out = $self->_extract_fields_xml($node,$mapping);

    return $out;
}

sub _extract_telephone_xml {
    my($self,$node,$nodename) = @_;
    my $out = { };

    foreach my $telephone ($node->findnodes("$nodename/TELEPHONE")) {
        if ($telephone->findvalue('@TYPE') eq "HOME") {
            $out->{home_telephone} = $telephone->hasChildNodes
                ? $telephone->getFirstChild->getData : "" ;
        }
        elsif ($telephone->findvalue('@TYPE') eq "OFFICE") {
            $out->{work_telephone} = $telephone->hasChildNodes
                ? $telephone->getFirstChild->getData : "" ;
        }
        elsif ($telephone->findvalue('@TYPE') eq "MOBILE") {
            $out->{mobile_telephone} = $telephone->hasChildNodes
                ? $telephone->getFirstChild->getData : "" ;
        }
    }

    $out->{telephone} = ($out->{home_telephone} ne '')
        ? $out->{home_telephone} : $out->{work_telephone};

    return $out;
}

sub _extract_value_xml {
    my($self,$node,$nodename) = @_;
    my $mapping = {
        currency => ($nodename ? $nodename.'/' : ''). 'VALUE/@CURRENCY',
        value => ($nodename ? $nodename.'/' : ''). 'VALUE',
    };

    # value might be 1 or more - cater for this
    my $out = $self->_extract_fields_xml($node,$mapping);

    return $out;
}

sub _extract_tender_line {
    my($self,$order) = @_;
    my $out = [];
    my $mapping = {
        _tl_id => '@TL_ID',
        _type => '@TYPE',
    };

    # FIXME: this may not be a multiline
    foreach my $line ($order->findnodes('TENDER_LINE')) {
        my $b = $self->_extract_fields_xml($line,$mapping);
        $b->{value} = $self->_extract_value_xml($line);

        push @{$out}, $b;
    }

    return $out;
}

sub _extract_promotion_basket {
    my($self,$order) = @_;
    my $out = [];

    # FIXME: this may not be a multiline
    foreach my $basket ($order->findnodes('PROMOTION_BASKET')) {
        my $mapping = {
            _pb_id => '',
            _type => '',
            description => '',
        };
        my $b = $self->_extract_fields_xml($basket,$mapping);
        $b->{value} = $self->_extract_value_xml($basket);

        push @{$out}, $b;
    }

    return $out;
}

sub _extract_promotion_line {
    my($self,$order) = @_;
    my $out = [];

    foreach my $line ($order->findnodes('PROMOTION_LINE')) {
        my $mapping = {
            _pl_id => '',
            _type => '',
            description => '',
            order_line_id => '',
        };
        my $b = $self->_extract_fields_xml($line,$mapping);
        $b->{value} = $self->_extract_value_xml($line);

        push @{$out}, $b;
    }

    return $out;
}

sub _extract_billing_details {
    my($self,$node) = @_;
    my $out = {
        name => $self->_extract_name_xml(
            $node,'BILLING_DETAILS/NAME'),
        address => $self->_extract_address_xml(
            $node,'BILLING_DETAILS/ADDRESS'),
        contact_details => $self->_extract_telephone_xml(
            $node,'BILLING_DETAILS/CONTACT_DETAILS'),
    };
    $out->{contact_details}->{email} =
        $node->findnodes('BILLING_DETAILS/CONTACT_DETAILS/EMAIL')->string_value;

    return $out;
}

sub _extract_delivery_details {
    my($self,$node) = @_;
    my $out = {
        name => $self->_extract_name_xml(
            $node,'DELIVERY_DETAILS/NAME'),
        address => $self->_extract_address_xml(
            $node,'DELIVERY_DETAILS/ADDRESS'),
    };
    $out->{order_line} = 'FIXME';
#$self->_extract_order_line($node);

    return $out;
}

#sub _extract_order_line {
#    my($self,$order) = @_;
#    my $out = [];
#    my $mapping = {
#        _ol_id => '',
#        _description => '',
#        _sku => '',
#        _quantity => '',
#        _ol_seq => '',
#    };
#
##print "Wibble!\n";
#    # FIXME: this may not be a multiline
#    foreach my $line ($order->findnodes('ORDER_LINE')) {
#        my $set = $self->_extract_fields_xml($line,$mapping);
#print "Frak!\n";
##        my $b = $self->_extract_value_xml($line);

#        $out->{unit_net_price} =
#            $self->_extract_value_xml($line,'UNIT_NET_PRICE');
#        $out->{tax} = $self->_extract_value_xml($line,'TAX');
#        $out->{duties} = $self->_extract_value_xml($line,'DUTIES');
#        push @{$out}, $set;
#    }
##
#    return $out;
#}


### xml end

__PACKAGE__->meta->make_immutable;


1;
