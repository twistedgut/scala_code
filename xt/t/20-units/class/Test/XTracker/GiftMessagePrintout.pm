package Test::XTracker::GiftMessagePrintout;

use FindBin::libs;
use NAP::policy "tt", 'test';
use Test::XTracker::Data;
use XTracker::Order::Printing::GiftMessage 'generate_gift_messages';
use Test::XTracker::PrintDocs;
use File::Spec::Functions qw/catfile file_name_is_absolute/;
use XTracker::PrintFunctions 'print_documents_root_path';
use Test::XT::Data;

use parent "NAP::Test::Class";

sub startup : Tests(startup) {
    my $self = shift;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Data->new_with_traits(
        traits => ['Test::XT::Data::Order']
    );
}

# it returns different stuff depending on the shipment.
# just check it works without blowing up
sub test_can_automate_gift_message_lives : Tests() {
    my $self = shift;

    my $shipment = $self->_get_new_order_shipment({ has_gift_message => 1 });

    lives_ok {
        $shipment->can_automate_gift_message();
    } 'can_automate_gift_message lives ok';

}

sub test_has_gift_message_works : Tests() {
    my $self = shift;

    my $no_gm_shipment = $self->_get_new_order_shipment({ has_gift_message => 0 });

    ok (
        ! $no_gm_shipment->has_gift_messages(),
        "ensure has_gift_message returns false (shipment_id=". $no_gm_shipment->id . ")"
    );

    # If you're learning about shipments for the first time, you need to understand that they
    # aren't all automated. Only the ones that come out of dematic are.
    my $gm_shipment = $self->_get_new_order_shipment({ has_gift_message => 1 });

    ok(
        $gm_shipment->has_gift_messages(),
        "ensure has_gift_message returns true (shipment_id=". $gm_shipment->id . ")"
    );

}

sub test_has_gift_message_for_voucher_works : Tests() {
    my $self = shift;

    my $no_gm_shipment = $self->_get_new_order_shipment({ has_gift_message => 0 });
    $self->_add_a_voucher_with_a_gift_message($no_gm_shipment);
    $no_gm_shipment->discard_changes;

    ok(
        $no_gm_shipment->has_gift_messages(),
        "ensure has_gift_message returns true for a message on a shipment_item (shipment_id=". $no_gm_shipment->id . ")"
    );

}

sub test_print_gift_message_warnings : Tests() {
    my $self = shift;

    my $new_order_info = $self->_get_new_order({ has_gift_message => 1 });
    my $shipment = $new_order_info->{shipment};

    my $print_directory = Test::XTracker::PrintDocs->new();

    # Force automated system OFF (when a gift message warning is anticipated)
    no warnings "redefine";
    local *XTracker::Schema::Result::Public::Shipment::can_automate_gift_message = sub {
        return 0;
    };
    use warnings "redefine";

    lives_ok {
        $shipment->print_gift_message_warnings($self->_get_any_valid_printer_name());
    } "print_gift_message_warnings doesnt explode (shipment_id=". $shipment->id . ")";

    my ($doc) = $print_directory->wait_for_new_files();
    is( $doc->filename, 'giftmessagewarning-' . $shipment->id . '.html',
        "Correct print document name" );

    # Check the order data is correct
    my $data = $doc->as_data();

    is( $data->{'barcode'}, 'giftmessagewarning' . $new_order_info->{order_nr} . '.png',
        "Barcode filename is correct" );
    is( $data->{'order_nr'}, $new_order_info->{order_nr}, "Printed order number is correct" );
    is( $data->{'message'}, $new_order_info->{gift_msg}, "Gift msg is correct" );

}

sub test_print_gift_messages :Tests() {
    my $self = shift;

    my $new_order_info = $self->_get_new_order({ has_gift_message => 1 });
    my $shipment = $new_order_info->{shipment};

    my $print_directory = Test::XTracker::PrintDocs->new();

    no warnings "redefine";

    # Force automated system ON
    local *XTracker::Schema::Result::Public::Shipment::can_automate_gift_message = sub {
        return 1;
    };

    my $fetch_image_entered = 0;
    my $fetch_image_exited = 0; # ensures no exceptions thrown performing file ops
    my $downloaded_file;

    # Dont make this test dependent on external systems. Replace the download function
    # with a function that just puts a dummy text file in the correct place (as if the
    # download succeeded)
    local *XTracker::Order::Printing::GiftMessage::_fetch_image = sub { ## no critic(ProtectPrivateVars)
        $fetch_image_entered = 1;
        my $self = shift;
        my $expected_file = $self->_get_absolute_image_filename();
        note("writing dummy image file: $expected_file");
        open(my $fh, '>', $expected_file);
        $fh->print("dummy file");
        $fh->close();
        $downloaded_file = $expected_file;
        $fetch_image_exited = 1;
    };

    use warnings "redefine";

    # Generate the document
    lives_ok {
        $shipment->print_gift_messages($self->_get_any_valid_printer_name());
    } "print_gift_messages() invoked and didnt die";

    # check the downloaded image file exists
    ok(-e $downloaded_file, "File representing downloaded image present as expected (file=$downloaded_file)");

    # Check we received it
    my ($doc) = $print_directory->wait_for_new_files();
    is( $doc->filename, 'giftmessage-' . $shipment->id . '.html',
        "Correct print document name" );

    ok($fetch_image_entered, "print_gift_message attempts file downloaded as documented");
    ok($fetch_image_exited, "print_gift_message able to write to the download location ok");
}

sub test_get_gift_messages :Tests() {
    my $self = shift;

    my $new_order_info = $self->_get_new_order({ has_gift_message => 0 });
    my $shipment = $new_order_info->{shipment};

    is(scalar(@{ $shipment->get_gift_messages() }), 0, 'get_gift_messages returns no gift messages if there are no gift messages');

    $new_order_info = $self->_get_new_order({ has_gift_message => 1 });
    $shipment = $new_order_info->{shipment};

    my $gms = $shipment->get_gift_messages();
    my $count = scalar(@$gms);

    is($count, 1, 'get_gift_messages returns array ref of 1 item if gift message present');
    isa_ok($gms->[0], 'XTracker::Order::Printing::GiftMessage', 'get_gift_message returns GiftMessage objects');

    $self->_add_a_voucher_with_a_gift_message($shipment);
    $self->_add_a_voucher_with_a_gift_message($shipment);
    $shipment->discard_changes;

    $gms = $shipment->get_gift_messages();
    $count = scalar(@$gms);

    is($count, 3, 'get_gift_messages returns array ref of 3 items if gift message present on shipment item aswell');

    $new_order_info = $self->_get_new_order({ has_gift_message => 0 });
    $shipment = $new_order_info->{shipment};
    $self->_add_a_voucher_with_a_gift_message($shipment); # this one will be
    $shipment->discard_changes;

    $gms = $shipment->get_gift_messages();
    $count = scalar(@$gms);

    is($count, 1, 'get_gift_messages honors gift messages on vouchers at the shipment level');
}

# customer care can update gift message text, meaning a new image is required.
# we download an image twice
sub test_replace_image_works :Tests() {
    my $self = shift;

    my $new_order_info = $self->_get_new_order({ has_gift_message => 1 });
    my $shipment = $new_order_info->{shipment};

    no warnings "redefine";
    local *XTracker::Order::Printing::GiftMessage::_fetch_image = sub { ## no critic(ProtectPrivateVars)
        my $self = shift;
        my $expected_file = $self->_get_absolute_image_filename();
        note("writing dummy image file: $expected_file");
        open(my $fh, '>', $expected_file);
        $fh->print("dummy file");
        $fh->close();
    };
    use warnings "redefine";

    # shipment->get_gift_message_image_path *promises* to callers to download
    # the file if it isn't present on the disk.
    my $relative_path = $shipment->get_gift_messages->[0]->get_image_path();
    my $print_docs_dir = print_documents_root_path();

    my $expected_file = catfile($print_docs_dir, $relative_path);

    note("expecting file for replace_existing_image to be $expected_file");
    ok(-e $expected_file, "setup for replace_existing_image() ensures file download via get_image_path ok");

    # Check replacing an image works. (Here we empty _fetch_image so we know the original file was deleted.)
    no warnings "redefine";
    local *XTracker::Order::Printing::GiftMessage::_fetch_image = sub {}; ## no critic(ProtectPrivateVars)
    use warnings "redefine";

    lives_ok {
        $shipment->get_gift_messages->[0]->replace_existing_image();
    } "replace_existing_image lived ok";

    ok(! -e $expected_file, "existing file removed as expected");

}

sub test_get_gift_image_image_path :Tests() {
    my $self = shift;

    my $new_order_info = $self->_get_new_order({ has_gift_message => 1 });
    my $shipment = $new_order_info->{shipment};

    no warnings "redefine";
    local *XTracker::Order::Printing::GiftMessage::_fetch_image = sub { ## no critic(ProtectPrivateVars)
        my $self = shift;
        my $expected_file = $self->_get_absolute_image_filename();
        note("writing dummy image file: $expected_file");
        open(my $fh, '>', $expected_file);
        $fh->print("dummy file");
        $fh->close();
    };
    use warnings "redefine";

    my $relative_path;

    lives_ok {
        $relative_path = $shipment->get_gift_messages()->[0]->get_image_path();
    } "get_gift_message_image lives ok";

    my $print_docs_dir = print_documents_root_path();
    my $absolute_file = catfile($print_docs_dir, $relative_path);

    note("expecting file from get_gift_message_image_path() to be $absolute_file");

    ok(! file_name_is_absolute($relative_path), "get_image_path returns relative link");
    ok(-e $absolute_file, "get_image_path performed image download as it advertises it will");
}

sub _get_new_order_shipment {
    my ($self, $has_gift_message) = @_;
    my $retval = $self->_get_new_order($has_gift_message);
    return $retval->{shipment};
}

sub _get_new_order {
    my ($self, $args) = @_;

    my $framework = $self->{framework};

    my ($shipment, $order) = @{ $framework->new_order(
        products => 5,
        channel  => 'NAP'
    )}{'shipment_object', 'order_object'};

    my $gift_msg = "Goodbye Rita :-( order_nr=" . $order->order_nr;

    if ($args->{has_gift_message}) {
        note("order has gift message");
        $shipment->update({ gift => 'true', gift_message => $gift_msg });
    } else {
        note("order does not have gift message");
    }

    $shipment->discard_changes;

    return {
        shipment => $shipment,
        order_nr => $order->order_nr,
        gift_msg => $gift_msg
    };
}

sub _get_any_valid_printer_name {
    return "Finance";
}

sub _add_a_voucher_with_a_gift_message {
    my ($self, $shipment) = @_;

    my ($channel,$products) = Test::XTracker::Data->grab_products( {
            how_many => 1,
            phys_vouchers   => {
                how_many => 1,
                want_stock => 10,
                want_code => 10,
                value => '500.00',
            },
    } );

    my $variant = $products->[0]->{'variant'};

    my $si = Test::XTracker::Data->create_shipment_item({
        shipment_id => $shipment->id,
        variant_id  => $variant->id
    });

    $si->update({ gift_message => 'hello' });
    $si->discard_changes;
}
