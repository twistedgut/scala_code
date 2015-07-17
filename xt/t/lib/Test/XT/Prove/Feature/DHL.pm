package Test::XT::Prove::Feature::DHL;
use NAP::policy "tt", 'class', 'test';

sub test_dhl_label_content {
    my($self,$content,$test) = @_;
    my $total_value = $test->{total_value} || '';
    my $currency = $test->{currency} || '';
    my $shipping_option_code = $test->{shipping_option_code} || '';
    my $routing_number = $test->{routing_number} || '';

    if (exists $test->{total_value}) {
        like(
            $content,
            qr/\^FDCustom Val: $total_value $currency\^FS/s,
            "Label File: Customs Value is correct with correct currency: "
                . "$total_value $currency"
        );
    }

    if (exists $test->{shipping_option_code}) {
        like(
            $content,
            qr/\^FD$test->{shipping_option_code}\^FS/ms,
            "Label File: ShippingOption code ($test->{shipping_option_code}) is correct",
        );
    }

    if (exists $test->{routing_number}) {
        like(
            $content,
            qr/\^FD2L(.+?)\+$test->{routing_number}\d{6}\^FS/ms,
            "Label File: Routing number ($test->{routing_number}) is correct",
        );
    }

    if (exists $test->{delivery_option}) {
        like(
            $content,
            qr/\^FD2L(.+?)\+\d{2}$test->{delivery_option}\d{4}\^FS/ms,
            "Label File: Delivery option ($test->{delivery_option}) is correct",
        );
    }

    if (exists $test->{service_description}) {
        like(
            $content,
            qr/\^FD$test->{service_description}\^FS/ms,
            "Label File: Service description ($test->{service_description}) is correct",
        );
    }
}


