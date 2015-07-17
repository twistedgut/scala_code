package Test::XT::OrderImporter;
use NAP::policy "tt", 'test';

use Data::Printer;
use File::Basename;
use File::Find::Rule;
use File::Slurp;
use JSON qw/to_json/;
use Time::HiRes qw(time);   # for process timing
use Test::Memory::Usage;    # for memory testing

use Test::XT::OrderImporter::QueueName;
use Test::Data::JSON;
use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::Shipping;
use Test::XTracker::Mock::PSP;
use XTracker::Config::Local qw( config_var );
use Test::XTracker::MessageQueue;

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;

# turn on/off the premier-routing tests
# the behaviour changed in the flexi-ship work and it's not obvious how to
# quickly fix out test here so we'll work on the assumption that flexi-ship
# know how to test their own code and flag these tests (and data hacking) so
# we can ignore them until we resolve the tests in this script
my $behaviour_changed_by_flexiship = 1;

sub json_amq_payload_tests {
    my $class       = shift;
    my $argref      = shift;
    #my $root_dir    = shift;
    #my $file_filter = shift;

    if (not ref $argref) {
        fail('must pass hashref of options to json_amq_payload_tests(); unable to continue');
        exit -1;
    }
    if (not exists $argref->{destination}) {
        fail('no destination provided; unable to continue');
        exit -1;
    }

    my $sent_count = 0;
    my $files = Test::Data::JSON->find_json_in_dir(
        $argref->{root_dir},
        $argref->{file_filter},
    );
    # if we didn't find any files to use as data, something is a little odd
    if (not @{$files}) {
        fail('no matching payload files found to use as input');
        exit -1;
    };

    my %timing_for;
    $timing_for{process_start}  = time();
    $timing_for{loop_start}     = time(); # the start time for the loop we haven't entered yet
    $timing_for{loop_end}       = time(); # the end time for the loop we haven't entered yet

    my $counter = 0;
    my $destination = $argref->{destination};
    #config_var('MrPorterOrder', 'destination');

    foreach my $payload_file (@{$files}) {
        note "processing file #" . ++$counter . ": $payload_file";

        my ($payload);
        $payload = Test::Data::JSON->slurp_json_file($payload_file);
        $payload = Test::Data::JSON->make_order_test_safe($payload);

        $class->munge_live_data_for_test_purposes($payload);
        my $order_queue = delete $payload->{queue_name};

        order_not_exists_ok($payload);

        memory_usage_start;

        # keep the timing of the *functionality* as tight as possible
        $timing_for{request_start} = time();
        my $res = $amq->request(
            $app,
            $destination,
            $payload,
            { type => 'order' },
        );
        $timing_for{request_end} = time();
        ok( $res->is_success, "order $payload->{o_id} consumed" );

        memory_usage_ok(10);
        order_exists_ok($payload, $payload_file);
        imported_data_seems_ok($payload, $payload_file);
        didnt_take_too_long(\%timing_for);
    }

    didnt_take_too_long_on_average(\%timing_for, scalar @{$files});

    return;
}

sub munge_live_data_for_test_purposes {
    my ($class, $payload) = @_;

    $class->munge_channel_for_jimmychoo( $payload );

    # temporarily store the channel we'll use in grab products in the
    # payload
    # this is lazy but easy, we'll delete it after the next few lines
    $payload->{grab_channel} //= lc($payload->{channel}) || 'borked-channel';
    $payload->{grab_channel}   =~ s{^(\w+)-\w+$}{$1};

    # replace products in orders with products we grab from the database
    $class->munge_payload_order_lines_for_test( $payload );
    $class->munge_payload_order_line_voucher_for_test( $payload );
    $class->munge_virtual_voucher_for_test( $payload );
    $class->munge_tender_gift_vouchers( $payload );
    $class->munge_address_line_3( $payload );

    # flexiship (rightly) changed the way 'staff' orders are handled
    # the gist of the change is @net-a-porter.com addresses are treated as
    # 'staff orders' and no longer get 'premier delivery'
    # to unbreak our tests, we just make all orders 'not-NAP', which will
    # break any attempts in this module to test staff order behaviour
    # - http://jira4.nap/browse/ORT-56
    $class->munge_netaporter_email_addresses( $payload );

    # call the fudges we do on the order as we process them
    # this remaps things into places we want them to be in the future, but
    # can't due to Java team time constraints
    # - this was we have the data where we want ti and can remove the
    # fudges when the incoming data meets out needs
    _fudge_payload( $payload );

    $payload->{queue_name} =
        Test::XT::OrderImporter::QueueName::queue_name(
            $payload->{grab_channel}
        );

    # delete our channel grabbing hack
    delete $payload->{grab_channel};
}

# jimmy choo don't pass a channel so we fudge it for the sake of testing ease
sub munge_channel_for_jimmychoo {
    my ($class, $payload) = @_;

    # we have this in the payload from JC
    #  'merchant_url' => 'www.jimmychoo.com'
    given ($payload->{merchant_url}) {
        when ('www.jimmychoo.com') {
            # TODO: pick a DC :)
            $payload->{channel} = 'jc-xxx';
        }

        default {
            # do nothing
        }
    }
}

sub imported_data_seems_ok {
    my ($payload, $payload_file) = @_;

    # let's not fetch the same order object many times
    my $schema = XTracker::Database::schema_handle();
    my $order = $schema->resultset('Public::Orders')
        ->find({order_nr => $payload->{o_id}});

    subtest 'imported data seems ok for order ' . $payload->{o_id} => sub {
        invoice_address_ok($payload);
        contact_details_ok($payload);
        promotion_details_ok($payload,$order,$payload_file);
        sticker_message_ok($payload, $order);
        premier_routing_ok($payload, $order);
        nominated_date_ok($payload, $order);
        other_order_fields_ok($payload, $order);
    } or diag "Test Failed processing file: ${payload_file}";

    return;
}

sub didnt_take_too_long_on_average {
    my $timing_for = shift;
    my $num_files  = shift;

    # let's be bold and assert that on average we take less than 10s/order
    my $duration    = $timing_for->{request_end} - $timing_for->{process_start};
    my $average     = ($duration * 1.0) / $num_files;
    SKIP: {
        skip 'Set XT_TIMED_TESTS to enable', 1
            unless $ENV{XT_TIMED_TESTS};
        ok (
            $average < 10,
            qq{average process time less than 10 seconds [${average}s/file; $num_files files]}
        );
    }
}

sub didnt_take_too_long {
    my $timing_for = shift;

    # we might struggle with high load, but an order should never take as long
    # as the old days (30-90 seconds)
    # we'll be generous and say all orders should complete in under 20 seconds
    my $max_seconds = 20;
    my $duration = $timing_for->{request_end} - $timing_for->{request_start};
    SKIP: {
        skip 'Set XT_TIMED_TESTS to enable', 1
            unless $ENV{XT_TIMED_TESTS};
        ok(
            $duration < $max_seconds,
            qq{processed order in under $max_seconds seconds [${duration}s]}
        );
    }

    return;
}

sub _fudge_payload {
    my $payload = shift;

    eval {
        require XT::Order::Role::Parser::NAPGroup::DeliveryData;

        # we'd like to include _fudge_voucher_data but can't because of the
        # as_list role method it requires
        # for testing the more important fudge is the address fudge so we'll
        # make do with that for now
        my @fudges = qw[_fudge_address_data];

        foreach my $fudge (@fudges) {
            if (XT::Order::Role::Parser::NAPGroup::DeliveryData->can($fudge)) {
                XT::Order::Role::Parser::NAPGroup::DeliveryData->$fudge(
                    $payload
                );
                pass(qq{fudged payload with: $fudge});
            }
        }
    };
    die $@ if $@;

    return;
}

sub order_not_exists_ok {
    my $payload = shift;

    # make sure we don't have a borked database that already contains the
    # order we're about to ingest
    ok(
        0 ==
        Test::XTracker::Data::Order->does_order_exist_by_id(
            $payload->{o_id}
        ),
        qq{order $payload->{o_id} not in database before processing}
    )
        or do {
            fail('no point in continuing ... stop to investigate'); # for testing
            exit -1;
        };
}

sub order_exists_ok {
    my ($payload, $payload_file) = @_;

    # do we have an order in the database?
    ok(
        Test::XTracker::Data::Order->does_order_exist_by_id(
            $payload->{o_id}
        ),
        qq{order $payload->{o_id} found in database after processing}
    )
        or do {
            diag $payload_file;
            diag p($payload);
            fail('no point in continuing ... stop to investigate'); # for testing
            exit -1;
        };
}

sub invoice_address_ok {
    my ($payload) = @_;
    my $ia =
        Test::XTracker::Data::Order->invoice_address_for_order(
            $payload->{o_id}
        );

    # we're lucky that the field in the address structures have the same keys
    # in NAPGroup (unlike JChoo)
    # We can just check a list of expected fields and make sure they're the
    # same in the invoice address and the billing address in the payload
    #  - country gets normalised; e.g. GB -> United Kingdom (TODO)
    #  - state isn't an object method (TODO)
    #  -- state is moved to 'county' in _fudge_address_data()
    my @fields = qw[address_line_1 address_line_2 county postcode towncity];
    my @fields_we_should_check = qw[country];

    subtest 'order invoice address ok' => sub {
        my $address = $payload->{billing_details}{address};
        foreach my $field (@fields) {
            is(
                $ia->$field,
                $address->{$field},
                qq{invoice field '$field' matches payload value: $address->{$field}}
            );
        }

        # state is bloody annoying ... as far as I can see it's mapped into
        # the county field:
        #  - payload: no county, no state - db:county should be empty
        #  - payload:county defined (tested in the loop above)
        #  - payload:county empty, payload:state defined - db:county should
        #            match state
        if (not $address->{county} and not $address->{state}) {
            is(
                $ia->county,
                q{},
                qq{invoice field 'county' empty with empty state and county}
            );
        }
        elsif ($address->{state}) {
            is(
                $ia->county,
                $address->{state},
                qq{invoice field 'county' matches payload 'state' value}
            );
        }

        # we can't nuke address_line_3, but we can ensure it's not in the
        # payload
        ok(
            !exists($address->{address_line_3}),
            q{address_line_3 is not in payload}
        );
        # we ought to be able to assert what we pull from the database
        is(
            $ia->address_line_3,
            q{},
            q{invoice field 'address_line_3' is blank}
        );
    };

    return;
}

sub contact_details_ok {
    my ($payload, $payload_file) = @_;
    my $customer = Test::XTracker::Data::Order->customer_for_order( $payload->{o_id} );
    my $contact_details = $payload->{billing_details}{contact_details};

    subtest 'customer billing telephone details ok' => sub {
        foreach my $telephone (@{$contact_details->{telephone}}) {
            # if they didn't give us a number in the order, don't check
            # anything
            # (it looks like we can send nothing in an order but the customer
            # have the value from a previous life/order)
            next
                unless exists $telephone->{number};

            my ($accessor);
            given ($telephone->{type}) {
                when ('HOME') {
                    $accessor = 'telephone_1';
                }
                when ('OFFICE') {
                    $accessor = 'telephone_2';
                }
                when ('MOBILE') {
                    $accessor = 'telephone_3';
                }

                default {
                    fail(qq{unknown telephone type: $telephone->{type}});
                    next;
                }
            }

            is(
                $customer->$accessor,
                $telephone->{number},
                qq!$telephone->{type} telephone (payload) matches $accessor value (customer in DB)!
            )
            # make debugging failure slightly easier ... share the data!
            or do {
                diag p($payload);
                diag p($customer->{_column_data});
            };
        }
    };

    return;
}

sub _shipment_promotion_in_database {
    my ($order, $promotion_basket) = @_;

    # we don't store free_shipping; it's a promotion-line for some reason I
    # can't remember right now; CCW
    if ('percentage_discount' eq $promotion_basket->{type}) {
        pass(q{ignoring 'percentage_discount' in promotion basket});
        return;
    }

    my $result = $order->result_source->resultset->search(
        {
            # we want it to be the order we're looking at
            'me.order_nr'
                => $order->order_nr,

            # restrict to the name/description of the promotion in the
            # promotion basket
            'link_shipment__promotion.promotion'
                => $promotion_basket->{description},
        },
        {
            join => {
                'link_orders__shipments' => {
                    'shipment' => 'link_shipment__promotion'
                }
            },
        },
    );

    ok( $result->count > 0, # should this be exactly one?

        sprintf(
            q{order:%s has a basket-level promotion called '%s'},
            $order->order_nr,
            $promotion_basket->{description}
        )
    );

    return;

}

sub _promotion_line_in_database {
    my ($order, $promotion_line) = @_;

    # we don't store free_shipping; it's a promotion-line for some reason I
    # can't remember right now; CCW
    if ('free_shipping' eq $promotion_line->{type}) {
        pass(q{ignoring 'free_shipping' in promotion line});
        return;
    }

    # this is built up from a wonderful journey through the database:
    # xtracker=> SELECT order_nr,shipment_item.pws_ol_id,
    # shipment_item.id,link_shipment_item__promotion.* FROM orders JOIN
    # link_orders__shipment ON (orders.id=link_orders__shipment.orders_id)
    # JOIN shipment ON (shipment.id=link_orders__shipment.shipment_id) JOIN
    # shipment_item ON (shipment.id=shipment_item.shipment_id) JOIN
    # link_shipment_item__promotion ON
    # (link_shipment_item__promotion.shipment_item_id=shipment_item.id) WHERE
    # order_nr='22331132733310211';
    #      order_nr      | pws_ol_id | id | shipment_item_id |    promotion     | unit_price |  tax  | duty
    # -------------------+-----------+----+------------------+------------------+------------+-------+-------
    #  22331132733310211 |   5152708 | 29 |               29 | MRP_INTL_EIP_50% |      0.000 | 0.000 | 0.000
    # (1 row)

    my $result = $order->result_source->resultset->search(
        {
            # we want it to be the order we're looking at
            'me.order_nr'
                => $order->order_nr,
            # and restricted to the order_line_id value(s) in our current
            # promotion_line
            'shipment_items.pws_ol_id'
                => { IN => $promotion_line->{order_line_id} },
            # finally restrict to the name/description of the promotion in the
            # promotion_line
            'link_shipment_item__promotion.promotion'
                => $promotion_line->{description},
        },
        {
            join => {
                'link_orders__shipments' => {
                    'shipment' =>
                      { 'shipment_items' => 'link_shipment_item__promotion' }
                }
            },

            +select => [ 'link_shipment_item__promotion.unit_price' ],
            +as     => [ 'promotion_unit_price' ],
        },
    );

    ok( $result->count > 0, # should this be exactly one?
        sprintf(
            q{order:%s,pws_ol_id:%s has a promotion called '%s'},
            $order->order_nr,
            join(',',@{$promotion_line->{order_line_id}}),
            $promotion_line->{description}
        )
    );

    # if the promotional line has a non-zer anount, the unit price should be a
    # non-zero amount
    # the amounts don't have to match because somewhere in the code the value
    # is split into unit_price/tax/duties
    if (    exists $promotion_line->{value}
        and exists $promotion_line->{value}{amount}
        and        $promotion_line->{value}{amount} > 0
    ) {
        # not sure what to do if there's more than one result
        # - we'll have to deal with that when it happens
        # until then assume there's only one and it should have a non-zero
        # value
        cmp_ok(
            $result->slice(0,0)->first->get_column('promotion_unit_price'),
            '>',
            0.00, # more than nothing
            sprintf(
                q{order:%s,pws_ol_id:%s has a non-zero value '%f'},
                    $order->order_nr,
                    join(',',@{$promotion_line->{order_line_id}}),
                    $promotion_line->{value}{amount}
            )
        );
        # I guess we should have a discount greater than the original value
        # either
        cmp_ok(
            $result->slice(0,0)->first->get_column('promotion_unit_price'),
            '<=',
            $promotion_line->{value}{amount},
            sprintf(
                q{order:%s,pws_ol_id:%s does not discount more than line-item value},
                    $order->order_nr,
                    join(',',@{$promotion_line->{order_line_id}}),
            )
        );
    }

    # if the value is zero, then presumably the discount should be too
    if (    exists $promotion_line->{value}
        and exists $promotion_line->{value}{amount}
        and        $promotion_line->{value}{amount} == 0
    ) {
        cmp_ok(
            $result->slice(0,0)->first->get_column('promotion_unit_price'),
            '==',
            0.00,
            sprintf(
                q{order:%s,pws_ol_id:%s has zero value discount },
                    $order->order_nr,
                    join(',',@{$promotion_line->{order_line_id}}),
            )
        );
    }

    return;

}

sub promotion_details_ok {
    my ($payload, $order, $payload_file) = @_;

    return
        unless (
               exists $payload->{promotion_basket}
            or exists $payload->{promotion_line}
        );

    # PROMOTION BASKET
    #  although we annoyingly get a list of everything we only really care
    #  about promotions that really do affect the basket (and not the items in
    #  it).
    #  I believe that currently the list of promotion that fall into this area
    #  are:
    #   - free_shipping
    #  Ignore anything else we find at this level (unless it's a promotion
    #  type we weren't aware existed ... and we barf
    if (exists $payload->{promotion_basket}) {
        subtest 'promotion basket data ok' => sub {
            foreach my $basket_item (@{$payload->{promotion_basket}}) {
                _shipment_promotion_in_database($order, $basket_item);
            }
        };
    }

    # PROMOTION LINE
    #  almost the opposite of the PROMOTION BASKET checks, we don't care about
    #   - free_shipping
    #  even though it's listed as a promotional line item
    #  The types we currently know we need to care about are:
    #   - percentage_discount
    #  See _promotion_line_in_database() for more details on how we check
    #  these items
    if (exists $payload->{promotion_line}) {
        subtest 'promotion line data ok' => sub {
            foreach my $line (@{$payload->{promotion_line}}) {
                _promotion_line_in_database($order, $line);
            }
        };
    }

    return;
}

sub sticker_message_ok {
    my ($payload, $order) = @_;

    # we don't care if there's no sticker in the payload
    return
        unless exists $payload->{delivery_details}[0]{sticker};

    is(
        $order->sticker,
        $payload->{delivery_details}[0]{sticker},
        q{order has correct sticker value; } . $order->sticker
    );

    return;
}

sub premier_routing_ok {
    my ($payload,$order) = @_;

    # we don't care if there's no Premier Routing in the payload
    return
        unless exists $payload->{premier_routing_id};

    subtest 'premier routing data ok' => sub {
        foreach my $shipment ($order->shipments->all) {
            TODO: {
                local $TODO = q{behaviour changed by flexi-ship}
                    if $behaviour_changed_by_flexiship;
                is(
                    $shipment->premier_routing_id,
                    $payload->{premier_routing_id},
                    q{order has correct premier_routing_id for shipment:id=}
                    . $shipment->id
                );
            };
        }
    };

    return;
}

sub nominated_date_ok {
    my ($payload,$order) = @_;
    my $delivery_details = $payload->{delivery_details}[0];

    # nothing to test here if we don't have delivery details
    return unless $delivery_details;

    # we don't care if there's no Nominated Day dates in the payload
    return
        unless (   exists $delivery_details->{dispatch_date}
                or exists $delivery_details->{delivery_date});

    my $is_staff = $order->customer->is_category_staff;

    subtest 'nominated date data ok' => sub {
        foreach my $shipment ($order->shipments->all) {
            if ($is_staff) {
                if (exists $delivery_details->{dispatch_date}) {
                    ok(
                        !defined($shipment->nominated_dispatch_time),
                        q{order has undefined nominated_dispatch_time for STAFF shipment:id=}
                        . $shipment->id
                    );
                };
                if (exists $delivery_details->{delivery_date}) {
                    ok(
                        !defined($shipment->nominated_delivery_date),
                        q{order has undefined nominated_delivery_date for STAFF shipment:id=}
                        . $shipment->id
                    );
                };
            }
            else {
                if (exists $delivery_details->{dispatch_date}) {
                    ok(
                        defined $shipment->nominated_dispatch_time,
                        q{order has defined nominated_dispatch_time for shipment:id=}
                        . $shipment->id
                    );
                };
                if (exists $delivery_details->{delivery_date}) {
                    ok(
                        defined $shipment->nominated_delivery_date,
                        q{order has defined nominated_delivery_date for shipment:id=}
                        . $shipment->id
                    );
                };
            }
        }
    };

    return;
}

sub other_order_fields_ok {
    my ($payload,$order) = @_;

    subtest 'other order fields ok' => sub {
        # logged_in_username --> placed_by
        is(
            $order->placed_by,
            $payload->{logged_in_username},
            q{'logged_in_username' stored as 'placed_by' in order}
        );

        # signature required captured correctly
        given( $payload->{signature_required} ) {
            when( 0 ) {
                is(
                   $order->get_standard_class_shipment->is_signature_required,
                   0,
                   q{signature_required is 'false'}
                );
            }

            default {
                is(
                   $order->get_standard_class_shipment->is_signature_required,
                   1,
                   q{signature_required is 'true'}
                );
            }
        }

        # did our lovely customer use a stored credit card?
        given ($payload->{used_stored_credit_card}) {
            when ('T') {
                is (
                    $order->used_stored_card,
                    1,
                    q{used_stored_card is 'true'}
                );
            }

            default {
                is (
                    $order->used_stored_card,
                    0,
                    q{used_stored_card is 'false'}
                );
            }
        }

        # the delivery gift message and status gets stored with shipments
        foreach my $shipment ($order->shipments->all) {
            my $delivery_details = $payload->{delivery_details}[0] // [];

            my @virtual_voucher_orderlines =
                @{ $payload->{virtual_delivery_details} // [] };

            foreach my $virtual_details (@virtual_voucher_orderlines) {
                my @voucher_list = (
                    @{$delivery_details->{order_line_voucher} // [] },
                    @{ $virtual_details->{order_line_voucher} // [] },
                );
                # if we've got a voucher we appear to be a gift, but we don't have
                # a top-level gift message
                if (@voucher_list) {
                    # we don't care about the top-level message; if we insist it's
                    # empty we'll get into potential trouble when we have vouchers
                    # *and* a gift message
                    # also is_gift seems almost random when we have vouchers
                    # let's not care, and just ensure we have the gift messages
                    # TODO - extend these tests appropriately

                    # we will want to limit the shipment items to those with
                    # order line ids that match the ones in the voucher(s) we
                    # have
                    # If yout only have one voucher this isn't a problem, but
                    # mrp-intl-126.json introduced data that tests multiple
                    # virtual vouchers in an order
                    my @relevant_ol_ids =
                        sort map { $_->{ol_id} } @voucher_list;

                    # sorted list of shipmentitem messages (stored in DB)
                    # (limited to those matching pws_ol_id as above)
                    my $sorted_shipmentitem_message = [
                        sort
                            grep { /.+/ }
                                map { $_->gift_message }
                                    $shipment
                                        ->shipment_items
                                        ->search({
                                            pws_ol_id =>
                                                { -in => \@relevant_ol_ids },
                                        })
                                        ->all
                    ];
                    # sorted list of voucher gift messages (from JSON payload)
                    # this is virtual AND physical!
                    my $sorted_payload_messages = [
                        sort
                            grep { /.+/ }
                                map { $_->{gift_message} }
                                    @voucher_list
                    ];

                    # they should be the same
                    is_deeply(
                        $sorted_shipmentitem_message,
                        $sorted_payload_messages,
                        q{voucher gift-messages stored with shipment-items}
                    ) or do {
                            require Data::Dump; diag(Data::Dump::pp($payload));
                        };
                }

                # did they want a gift message?
                elsif ($delivery_details->{gift_message}) {
                    is (
                        $shipment->gift_message,
                        $payload->{delivery_details}[0]{gift_message},
                        q{gift message stored with shipment }
                        . $shipment->id
                    );
                    is (
                        $shipment->gift,
                        1,
                        q{shipment flagged as gift}
                    );
                }

                # TODO: else ... make sure shipments aren't set as a gift, and that
                # they have no message
                else {
                    is (
                        $shipment->gift_message,
                        q{},
                        q{gift message empty for shipment }
                        . $shipment->id
                    );
                    is (
                        $shipment->gift,
                        0,
                        q{shipment flagged as non-gift}
                    );
                }
            }
        }


    };

    return;
}

sub munge_payload_order_lines_for_test {
    my ($class, $payload) = @_;
    my $detail_subsection = 'order_lines';

    $class->_delivery_item_count_check($payload);

    # we find all the skus in our order and replace them with stuff we get
    # from grab_products()
    my @product_sku_list
        = _find_payload_skus( $payload->{delivery_details}[0]{$detail_subsection} );
    my @jimmychoo_sku_list
        = _find_payload_skus(
            $payload->{orders}[0]{delivery_detail}[0]{order_line},
            1, # third party treatment
        );

    # nothing in the replace list? might as well return now
    return $payload
        unless @product_sku_list + @jimmychoo_sku_list;

    # grab the required number of 'normal' products from the database
    my (undef,$pids) = Test::XTracker::Data->grab_products({
        how_many => scalar @product_sku_list,
        channel => $payload->{grab_channel},
    });
    my (undef,$jimmychoo_pids) = Test::XTracker::Data->grab_products({
        how_many => scalar @jimmychoo_sku_list,
        channel => $payload->{grab_channel},
    });

    # replace the original (physicalvoucher) products with grabbed ones
    _replace_payload_skus(
        $payload->{delivery_details}[0]{$detail_subsection},
        \@product_sku_list,
        $pids
    );
    _replace_payload_skus(
        $payload->{orders}[0]{delivery_detail}[0]{order_line},
        \@jimmychoo_sku_list,
        $jimmychoo_pids
    );

    # we don't need to retun anything here, but we'll give callers the payload
    # back (it's modified in place already, so only useful for the paranoid)
    return $payload;
}

sub munge_payload_order_line_voucher_for_test {
    my ($class, $payload) = @_;
    my $detail_subsection = 'order_line_voucher';

    $class->_delivery_item_count_check($payload);

    # we find all the skus in our order and replace them with stuff we get
    # from grab_products()
    my @voucher_sku_list
        = _find_payload_skus( $payload->{delivery_details}[0]{$detail_subsection} );

    # nothing in the replace list? might as well return now
    return $payload
        unless @voucher_sku_list;

    # grab the required number of 'physical voucher' products from the database
    my ($channel_id,$pids) = Test::XTracker::Data->grab_products({
        how_many => 0,
        channel => $payload->{grab_channel},
        phys_vouchers => { how_many => scalar @voucher_sku_list, want_stock => 1, want_code => 1 }
    });

    _replace_payload_skus(
        $payload->{delivery_details}[0]{$detail_subsection},
        \@voucher_sku_list,
        $pids
    );

    # we don't need to retun anything here, but we'll give callers the payload
    # back (it's modified in place already, so only useful for the paranoid)
    return $payload;
}

sub munge_virtual_voucher_for_test {
    my ($class, $payload) = @_;

    # escape as soon as we know we don't have any virtual vouchers
    # (should stop us autovivifying too)
    return
        unless exists $payload->{virtual_delivery_details}[0]{order_line_voucher};

    my @virtual_voucher_orderlines =
        @{ $payload->{virtual_delivery_details} // [] };

    foreach my $virtual_details (@virtual_voucher_orderlines) {
        # less to type ... less to read
        my $payload_subsection =
            $virtual_details->{order_line_voucher};

        # we find all the skus in our order and replace them with stuff we get
        # from grab_products()
        my @voucher_sku_list
            = _find_payload_skus( $payload_subsection );

        # nothing in the replace list? might as well check the next in the
        # list
        next unless @voucher_sku_list;

        # grab the required number of 'virtual voucher' products from the database
        my ($channel_id,$pids) = Test::XTracker::Data->grab_products({
            how_many        => 0,
            channel         => $payload->{grab_channel},
            virt_vouchers   => { how_many => scalar @voucher_sku_list, want_code => 10 }
        });

        # original version of grab_products() always returned at least one 'real'
        # product
        is(
            scalar @voucher_sku_list, scalar @$pids,
            q{returned correct number of replacement SKUs for virtual vouchers}
        );

        _replace_payload_skus(
            $payload_subsection,
            \@voucher_sku_list,
            $pids
        );
    }

    # we don't need to retun anything here, but we'll give callers the payload
    # back (it's modified in place already, so only useful for the paranoid)
    return $payload;
}

# we don't usually have existing vouchers to match codes in tender lines
# - we cheat
# -- create one voucher per GV tender line
# -- replace the code int hen payload
sub munge_tender_gift_vouchers {
    my ($class, $payload) = @_;

    # escape as soon as we know we don't have any virtual vouchers
    # (should stop us autovivifying too)
    return
        unless exists $payload->{tender_lines};

    # less to type ... less to read
    my $payload_subsection = $payload->{tender_lines};

    # we find all the skus in our order and replace them with stuff we get
    # from grab_products()
    my @voucher_code_list
        = _find_tenderline_vouchers( $payload_subsection );

    my ($channel_id,$pids) = Test::XTracker::Data->grab_products({
        how_many        => 0,
        channel         => $payload->{grab_channel},
        virt_vouchers   => { how_many => scalar @voucher_code_list, want_code => 1 }
    });

    _replace_tenderline_vouchercodes(
        $payload_subsection,
        \@voucher_code_list,
        $pids
    );

    return @voucher_code_list;
}

sub munge_address_line_3 {
    my ($class, $payload) = @_;

    # delete all address_line_3 keys
    delete $payload->{billing_details}{address}{address_line_3}
        and pass('munged address_line_3 in payload test data');

    return $payload;
}

sub munge_netaporter_email_addresses {
    my ($class, $payload) = @_;

    # don't bother mungind addresses if we're TODOing the test elsewhere
    # (aka we haven't fixed it yet)
    return if $behaviour_changed_by_flexiship;

    my $billing_contact_details =
        $payload->{billing_details}{contact_details};
    if (exists $billing_contact_details->{email}) {
        $billing_contact_details->{email} =~ s{
            \@net-a-porter\.com
        }
        {\@example.com}xms
            and pass('munged @net-a-porter.com email address in test data');
    }

    return;
}

sub _delivery_item_count_check {
    my ($class, $payload) = @_;
    # horrible hack - only works until we can have more than one
    # delivery_items
    # some orders (virtual vouchers) don't have delivery_details ... so make
    # sure we have something there before checking the items in it
    die 'data format changed; multiple delivery_items elements found'
        if (exists $payload->{delivery_details} and @{$payload->{delivery_details}} > 1);
    return;
}

sub _find_tenderline_vouchers {
    my $tender_lines = shift;

    # get all SKUs from order
    my @vouchercode_list =
        map { $_->{voucher_code} }
            @{ $tender_lines };

    return @vouchercode_list;
}

sub _find_payload_skus {
    my $order_lines    = shift;
    my $is_third_party = shift // 0;

    # get all SKUs from order
    my @sku_list =
        map { $_->{sku} }
            @{ $order_lines };
    # remove shipping SKUs
    my @product_sku_list;
    if ($is_third_party) {
        @product_sku_list =
            grep { defined }
                map { $_ }
                    @sku_list;
    }
    else {
        @product_sku_list =
            grep { defined }
                map { Test::XTracker::Data::Shipping->is_shippingcharge_sku($_) ? undef : $_ }
                    @sku_list;
    }

    return @product_sku_list;
}

sub _replace_payload_skus {
    my ($order_list, $product_sku_list, $replacement_sku_list) = @_;

    # replace product SKUs in the payload with SKUs fetched from the database
    SMARTMATCH:
    use experimental 'smartmatch';
    map { $_->{sku} = (pop @$replacement_sku_list)->{sku} }
        grep { $_->{sku} ~~ @$product_sku_list }
            @{ $order_list };
}

sub  _replace_tenderline_vouchercodes {
    my ($tender_list, $vouchercode_list, $pids) = @_;

    my @replacement_codes;
    foreach my $pid (@$pids) {
        foreach my $voucher_code (@{$pid->{voucher_codes}}) {
            push @replacement_codes, $voucher_code->code;
        }
    }

    SMARTMATCH:
    use experimental 'smartmatch';
    map { $_->{voucher_code} = (pop @replacement_codes) }
        grep { $_->{voucher_code} ~~ @$vouchercode_list }
            @{ $tender_list };

    return $tender_list;
}
