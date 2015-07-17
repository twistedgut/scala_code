package Test::XTracker::OrderImporter;

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Mock::DHL::XMLRequest;
use Catalyst::Utils;
use Module::Runtime 'use_module';

my $channel_parser_test_cases = {
    DC1 => [
        {
            channel_name      => "NAP",
            parser_class_name => "PublicWebsiteXML",
        },
        {
            channel_name      => "JC",
            parser_class_name => "IntegrationServiceJSON",
        },
    ],
    DC2 => [
        {
            channel_name      => "NAP",
            parser_class_name => "PublicWebsiteXML",
        },
        {
            channel_name      => "JC",
            parser_class_name => "IntegrationServiceJSON",
        },
    ],
    DC3 => [
        {
            channel_name      => "NAP",
            parser_class_name => "PublicWebsiteXML",
        }
    ]
};

sub channel_parser_test_cases {
    return $channel_parser_test_cases;
}

sub run_tests {
    my($self,$test_cases,$sub) = @_;
    my $dc = Test::XTracker::Data->whatami;
    my $channel_parser_test_cases = $self->channel_parser_test_cases->{$dc};

    foreach my $test (@{$test_cases}) {
        note "  [Case: $test->{name}]";

        for my $channel_parser_case (@$channel_parser_test_cases) {
            note "  [DC: $dc]";
            note "  [Parser: $channel_parser_case->{parser_class_name}]";
            my $channel_name = $channel_parser_case->{channel_name};
            my $channel = Test::XTracker::Data->channel_for_business(
                name => $channel_name);
            my $parser_class = $channel_parser_case->{parser_class_name};



            my $orders = Test::XTracker::OrderImporter->import_order(
                $parser_class,
                $channel_name,
                $test->{setup}->{$dc},
            );

            is(@$orders, 1, "Got the one order");
            my $order = $orders->[0];
            my $mock = Test::XTracker::Mock::DHL::XMLRequest->setup_mock(
                [ { service_code => 'LON' } ],
            );
            my $order_row = $order->digest();



            # call the sub that tests with its relevant test case info
            my $expected = $test->{expected}->{$dc}->{$parser_class};
            &$sub($order_row,$expected);
        }
    }
}


sub import_order {
    my($self,$parser_class, $channel_name, $test_args) = @_;
    my $test_order_args = $test_args->{order} // { };
    my $test_customer_args = $test_args->{customer} // { };

    my $order_args = $self->prepare_order(
        $channel_name, $test_order_args, $test_customer_args);

    die "No parser class defined" if (!defined $parser_class);


    # Create and Parse all Order Files
    my $class = "Test::XTracker::Data::Order::Parser::$parser_class";
    my $parser = use_module($class)->new;
    my @data_orders = $parser->create_and_parse_order(
        [ $order_args ],
    );

    return \@data_orders;
}

sub prepare_order {
    my ($self,$channel_name, $test_order_args, $test_customer_args) = @_;
    $test_order_args //= { };
    $test_customer_args //= { };


    my $channel = Test::XTracker::Data->channel_for_business(name => $channel_name);
    my ($dummy, $pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
        channel  => $channel,
        # use so that Third Party SKUs are definitely
        # assigned for Fulfiment Only Channels
        force_create => 1,
    });
    my $unit_price = 691.30;
    my $tax = 48.39;
    my $item_args = [
        {
            sku         => $pids->[0]{sku},
            unit_price  => $unit_price,
            tax         => $tax,
            duty        => 0.00
        },
    ];

    $test_customer_args = Catalyst::Utils::merge_hashes(
        { id => 1234, email => 'nobody@example.com' },
        $test_customer_args,
    );

    return my $order_args = $self->uniquify_known_fields({
        channel  => $channel,
        customer => $test_customer_args,
        order    => {
            items          => $item_args,
            channel_prefix => $channel->business->config_section,
            tender_amount  => $unit_price + $tax,
            %$test_order_args,
        },
    });
}

sub uniquify_known_fields {
    my($self,$hash) = @_;
    my $unique = sprintf('%d%d%d', $$, time(), int(rand(1234)));

    $hash->{customer}->{email} =~ s/\[UNIQUEME\]/$unique/
        if (defined $hash->{customer}->{email});

    # making sure we get a customer that doesn't exist
    my $schema = Test::XTracker::Data->get_schema;
    my $new_customer_id = $schema->resultset('Public::Customer')
        ->search()->get_column('id')->max();
    $new_customer_id = $new_customer_id ? $new_customer_id + 1 : 1;

    $hash->{customer}->{id} =~ s/\[UNIQUEME\]/$new_customer_id/
        if (defined $hash->{customer}->{id});


    note "CUSTOMER EMAIL: " .$hash->{customer}->{email};
    return $hash;
}

sub read_test {
    my($self,$file) = @_;
    my $test = Test::XTracker::Utils->slurp_json_file($file);

    # test for keys we expect
    foreach my $key (qw/name input expected/) {
        is(exists $test->{$key}, 1, "[File-based Test] has '$key'");
    }

    return $test;
}

1;
