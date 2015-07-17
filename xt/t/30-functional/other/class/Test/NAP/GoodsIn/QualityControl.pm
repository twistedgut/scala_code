package Test::NAP::GoodsIn::QualityControl;

use NAP::policy qw/test/;

=head1 NAME

Test::NAP::GoodsIn::QualityControl - Test the Quality Control page

=head1 DESCRIPTION

Test the Quality Control page.

#TAGS goodsin qualitycontrol http loops

=head1 METHODS

=cut

use FindBin::libs;

use Test::XT::Flow;
use Test::XTracker::Data;
use Test::XTracker::PrintDocs;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants qw/:application :conversions/;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :delivery_action
    :delivery_item_status
    :delivery_status
    :stock_process_status
    :stock_process_type
);

use File::Basename;
use IO::All;
use Clone 'clone';

use parent 'NAP::Test::Class';

sub startup :Test(startup) {
    my $self = shift;

    $self->{storage_type} = Test::XTracker::Data->get_schema
        ->resultset('Product::StorageType')
        ->search({},{rows=>1})
        ->single;
}

sub setup : Test(setup) {
    my ( $self ) = @_;

    $self->SUPER::setup;

    $self->{flow} = Test::XT::Flow->new_with_traits(
        traits => [qw(
            Test::XT::Flow::GoodsIn
            Test::XT::Flow::PrintStation
        )],
    );
}

=head2 quality_control_submission

Test several scenarios using the following procedure.

Firstly:

=over

=item Ceate a new product

=item Login as I<Distribution>, give the user manager-level access to the
I<Goods In/Quality Control> page

=item Make sure a printer station is selected

=back

For each scenario:

=over

=item Create a delivery directly in the db that's ready for quality control

=item Get to the quality control process item page

=item Submit the inputs and check for the appropriate pass/fail user message

=back

Scenarios tested:

=over

=item A valid submission with no dimensions set

=item A valid submission with all dimensions set

=item A failed submission due to one unset dimension

=item A failed submission due to a negative value for the weight field

=item A failed submission due to a 0 value for the weight field

=item A failed submission due to a non-numeric value for the weight field

=back

=cut

sub test_quality_control_submission : Tests {
    my $self = shift;

    my $flow = $self->{flow};

    my $product = (Test::XTracker::Data->grab_products({force_create => 1}))[1]->[0]{product};

    my $shipping_attribute = $self->schema
        ->resultset('Public::ShippingAttribute')
        ->find({product_id => $product->id});

    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => ['Goods In/Quality Control'], },
        dept => 'Distribution',
    });

    $flow->flow_mech__select_printer_station({
        section    => 'GoodsIn', subsection => 'QualityControl',
    })->flow_mech__select_printer_station_submit;

    foreach my $case (
        {
            name  => 'Valid (positive) weight value, (submitted dimensions should not result in a db update)',
            input => { qc => { weight => 1, length => 1, width => 1, height => 1 } },
        },
        {
            name   => 'Try negative value for product "weight"',
            input  => { qc => { weight => -1 } },
            error  => 'Product weight should be a positive number',
        },
        {
            name   => 'Try zero (0) value for product "weight"',
            input  => { qc => { weight => 0 } },
            error  => 'Product weight should be a positive number',
        },
        {
            name   => 'Try some non numeric values product "weight"',
            input  => { qc => { weight => 'blabla' } },
            error  => 'Product weight should be a positive number',
        },
    ) {
        subtest $case->{name} => sub {

            # Reset the shipping-attributes to 0.000 to overwrite any other value these might have been
            # set to elsewhere
            $shipping_attribute->update({
                length => '0.000',
                width  => '0.000',
                height => '0.000',
            });

            my $delivery = $self->stock_process_for_qc($product)->delivery_item->delivery;

            $flow->flow_mech__goodsin__qualitycontrol_deliveryid($delivery->id);

            if ( $case->{error} ) {
                $flow->catch_error(
                    qr{$case->{error}}, $case->{error},
                    flow_mech__goodsin__qualitycontrol_processitem_submit => $case->{input},
                );
            }
            else {
                $flow->flow_mech__goodsin__qualitycontrol_processitem_submit(
                    # We need to clone the parameter hash we pass to this method, because it deletes the contents
                    clone($case->{input})
                )->mech->has_feedback_success_ok(qr{Quality control successful});

                # This end-point no longer allows updates to length, width or height. So the values should
                # not have changed from 0 as they were set to above
                $shipping_attribute->discard_changes();
                for my $dimension ( sort grep { m{^(length|width|height)$} } keys %{$case->{input}->{qc}} ) {
                    is( $shipping_attribute->$dimension, '0.000', "$dimension has not changed as a result of this call");
                }
             }
        };
    }
}

sub stock_process_for_qc {
    my ( $self, $product ) = @_;
    my $po = Test::XTracker::Data->setup_purchase_order($product->id);
    my ($delivery) = Test::XTracker::Data->create_delivery_for_po($po->id, 'qc');
    my ($sp) = Test::XTracker::Data->create_stock_process_for_delivery($delivery);

    return $sp;
}

=head2 test_product_qc

Test getting a regular product through QC. The test performs the following
steps:

=over

=item Create a delivery with an item that has a quantity of 10

=item Hack the stock process to say we've counted 15 (i.e. we have 5 surplus)

=item Get that delivery's QC process page

=item Open a new tab with the same location

=item Submit values of 15 for checked, and 3 for faulty

=item Check we print putaway sheets for main, surplus and faulty PGIDs

=item Check the documents have the right type for each PGID and the file has a
size greater than 0

=item Submit the same on the other tab and check that we error

=item Check that the delivery is now C<Processing>, its item is C<Processing>
and the main stock process is C<Approved>

=item Check we have three stock processes: 10 for main, 3 for faulty, 2 for
surplus

=item Check the stock processes: 10 C<Approved>, 3 C<Bagged and Tagged>, 2
C<New>

=item Check none of the stock processes are complete

=item Expect two delivery log entries for the main stock process - C<Check> -
15, C<Approve> 10

=item For faulty we expect C<Create> - 3

=item For surplus we expect C<Create> - 2

=back

=cut

sub test_product_qc : Tests {
    my $self = shift;

    my $variant = (Test::XTracker::Data->grab_products({how_many=>1,force_create=>1}))[1][0]{variant};
    my $sp = $self->stock_process_for_qc($variant->product);
    my $delivery = $sp->delivery_item->delivery;

    # Sanity check
    $self->check_stock_process_quantity(
        $sp->delivery_item_id, { type => { Main => [ 10 ] } }
    );

    # fix the stock process to generate a surplus by upping the counted value
    # to greate than ordered (10)
    $sp->update({ quantity => 15 });

    my $flow = $self->{flow};
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => ['Goods In/Quality Control'], },
        dept => 'Distribution',
    });

    $flow->flow_mech__select_printer_station({
        section    => 'GoodsIn', subsection => 'QualityControl',
    })->flow_mech__select_printer_station_submit;

    # get qc delivery page
    $flow->flow_mech__goodsin__qualitycontrol_deliveryid($delivery->id);

    # Clone the current tab to test submitting the same delivery again
    my $other_tab_name = 'Double submit';
    $flow->open_tab($other_tab_name);
    $flow->switch_tab('Default');

    # Reduce scope of printdocs and related variables
    {
    my $print_directory = Test::XTracker::PrintDocs->new;
    # update total checked
    $flow->flow_mech__goodsin__qualitycontrol_processitem_submit({
        qc => { $variant->sku => { checked => 15, faulty => 3 } },
    })->mech->has_feedback_success_ok(qr{Quality control successful});

    my @expected_doctypes = (qw/main faulty surplus/);
    my %new_docs = map {
        $_->file_type => $_
    } $print_directory->wait_for_new_files( files => scalar @expected_doctypes );

    $self->check_printout( \%new_docs, \@expected_doctypes );
    }

    # Submit delivery again and ensure we error
    $flow->switch_tab($other_tab_name);
    $flow->catch_error(
        qr{This delivery has already been submitted, please contact your supervisor.},
        'should error when QCing same delivery twice',
        flow_mech__goodsin__qualitycontrol_processitem_submit => {
            qc => { $sp->variant->sku => { checked => 15, faulty => 3 } },
        },
    );
    $flow->close_tab;

    # Check our submit updated the database
    $self->check_delivery_item_status($delivery,$DELIVERY_STATUS__PROCESSING);
    $self->check_delivery_status($delivery,$DELIVERY_ITEM_STATUS__PROCESSING);
    $self->check_stock_process_status($sp, $STOCK_PROCESS_STATUS__APPROVED);
    $self->check_stock_process_quantity($delivery->delivery_items->first->id, {
        type => {
            Main    => [ 10 ],
            Faulty  => [ 3 ],
            Surplus => [ 2 ],
        },
        status => {
            'Approved'          => [ 10 ],
            'Bagged and Tagged' => [ 3 ],
            'New'               => [ 2 ],
        },
        complete => { 0 => [ 10, 3, 2 ], },
    });

    # Check delivery logs
    $self->check_delivery_log($delivery, $_) for (
        {
            type     => $STOCK_PROCESS_TYPE__MAIN,
            expected => [
                { action  => $DELIVERY_ACTION__CHECK, qty => 15, },
                { action  => $DELIVERY_ACTION__APPROVE, qty => 10, },
            ],
        },
        {
            type     => $STOCK_PROCESS_TYPE__FAULTY,
            expected => [ { action => $DELIVERY_ACTION__CREATE, qty => 3, }, ],
        },
        {
            type     => $STOCK_PROCESS_TYPE__SURPLUS,
            expected => [ { action => $DELIVERY_ACTION__CREATE, qty => 2, }, ],
        },
    );
}

=head2 test_voucher_qc

Test getting a voucher through QC. The test performs the following steps:

=over

=item Create a delivery item expecting 10, count 15 items

=item Assign codes for the voucher

=item Get the QC process item page for the delivery

=item Check we don't have the string I<No voucher codes> on the page

=item Check we voucher codes in the Javascript on the page

=item Submit the page with values of 15 for checked, and 4 for faulty

=item Expect main and surplus putaway sheets to be printed

=item Check the documents have the right type for each PGID and the file has a
size greater than 0

=item Check that the delivery is now C<Processing>, its item is C<Processing>
and the main stock process is C<Bagged and Tagged>

=item Check we have three stock processes: 10 for main, 4 for faulty, 1 for
surplus

=item Check the stock processes: 10, 1 C<Bagged and Tagged>, 4 C<Dead>

=item Check that only the C<Dead> stock process is complete

=item Expect two delivery log entries for the main stock process - C<Check> -
15, C<Approve> 10

=item For faulty we expect C<Create> - 4

=item For surplus we expect C<Create> - 1

=back

=cut

sub test_voucher_qc : Tests {
    my $self = shift;

    my $voucher = Test::XTracker::Data->create_voucher;
    my $sp = $self->stock_process_for_qc($voucher);
    my $delivery = $sp->delivery_item->delivery;

    # fix the stock process to generate a surplus by upping the counted value
    # to greate than ordered (10)
    $sp->update({ quantity => 15 });

    # generate codes
    ok(
        Test::XTracker::Data->generate_voucher_code_for_delivery($delivery),
        'codes were generated'
    );

    my $flow = $self->{flow};
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => ['Goods In/Quality Control'], },
        dept => 'Distribution',
    });

    $flow->flow_mech__select_printer_station({
        section    => 'GoodsIn', subsection => 'QualityControl',
    })->flow_mech__select_printer_station_submit;

    # get qc delivery page
    $flow->flow_mech__goodsin__qualitycontrol_deliveryid($delivery->id);

    # These could do with porting to Test::XTracker::Client or at least xpath...
    my $mech = $flow->mech;
    $mech->content_unlike(qr/No\s+voucher\s+codes/i, 'contains voucher codes');

    # Check that the JS in the page has the right list of voucher codes.
    $mech->content_like(qr/(\bdelivery_code\s*=\s*{\s*"[^"])/s, 'contains voucher codes')
        or diag $mech->content =~ /(\bdelivery_code\s*=\s*{\s*.*?;)/s;

    # Reduce scope of printdocs and related variables
    {
    my $print_directory = Test::XTracker::PrintDocs->new;

    $flow->flow_mech__goodsin__qualitycontrol_processitem_submit({
        qc => { $voucher->name => { checked => 15, faulty => 4 } },
    })->mech->has_feedback_success_ok(qr{Quality control successful});

    my @expected_doctypes = (qw/main surplus/);
    my %new_docs = map {
        $_->file_type => $_
    } $print_directory->wait_for_new_files( files => scalar @expected_doctypes );

    $self->check_printout( \%new_docs, \@expected_doctypes );
    }

    # Check everythings left in the right state
    $self->check_delivery_item_status($delivery,$DELIVERY_STATUS__PROCESSING);
    $self->check_delivery_status($delivery,$DELIVERY_ITEM_STATUS__PROCESSING);
    # Since we skip Bag & Tag for vouchers we set the stock process status to
    # that so that they can be putaway.
    $self->check_stock_process_status($sp, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED);
    $self->check_stock_process_quantity($delivery->delivery_items->first->id, {
        type => {
            Main    => [ 10 ],
            Faulty  => [ 4 ],
            Surplus => [ 1 ],
        },
        status => {
            'Bagged and Tagged' => [ 10, 1 ],
            Dead                => [ 4 ],
        },
        complete => {
            0 => [ 10, 1 ],
            1 => [ 4 ],
        },
    });

    # check delivery logs
    $self->check_delivery_log($delivery, $_) for (
        {
            type => $STOCK_PROCESS_TYPE__MAIN,
            expected => [
                { action  => $DELIVERY_ACTION__CHECK, qty => 15, },
                { action  => $DELIVERY_ACTION__APPROVE, qty => 10, },
            ],
        },
        {
            type => $STOCK_PROCESS_TYPE__FAULTY,
            expected => [ { action  => $DELIVERY_ACTION__CREATE, qty => 4, }, ],
        },
        {
            type => $STOCK_PROCESS_TYPE__SURPLUS,
            expected => [ { action  => $DELIVERY_ACTION__CREATE, qty => 1, }, ],
        },
    );
}

sub check_delivery_status {
    my ($self, $delivery, $status) = @_;
    $delivery->discard_changes;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is($delivery->status_id, $status, 'delivery status for '.$delivery->id);
}

sub check_delivery_item_status {
    my ($self, $delivery, $status) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $delivery->discard_changes;

    for my $di ($delivery->delivery_items) {
        is($di->status_id, $status, 'delivery item status for '.$di->id);
    }
}

sub check_delivery_log {
    my ($self, $delivery, $wanted) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $delivery->discard_changes;
    my $dlv_log_rs = $delivery->log_deliveries
        ->search({ type_id => $wanted->{type} }, { order_by => 'id' });
    # check actually got something
    cmp_ok( $dlv_log_rs->count(), '==', scalar @{ $wanted->{expected} },
            'delivery logs for type: '.$wanted->{type}.' found' );

    while ( my $di = $dlv_log_rs->next ) {
        my $expected    = shift @{ $wanted->{expected} };
        cmp_ok($di->delivery_action_id, '==', $expected->{action},
            'delivery log action is '.$di->delivery_action_id);
        cmp_ok($di->quantity, '==', $expected->{qty},
            'delivery log qty is '.$di->quantity);
    }
}

sub check_stock_process_status {
    my ($self, $stock_process, $status) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $stock_process->discard_changes;
    is($stock_process->status_id, $status,
        'stock_process status for '.$stock_process->id);
}

# check for new stock_process for faulty and surplus
sub check_stock_process_quantity {
    my ($self, $di_id, $wanted) = @_;
    my $schema = Test::XTracker::Data->get_schema;

    my $sp = $schema->resultset('Public::StockProcess')->search({delivery_item_id=>$di_id},{order_by => 'id'});
    ok ($sp->count);

    my $spc = {};       # complete flags
    my $sps = {};       # statuses
    my $spt = {};       # types
    while (my $r = $sp->next) {
        push @{ $spt->{$r->type->type} }, $r->quantity;
        push @{ $sps->{$r->status->status} }, $r->quantity;
        push @{ $spc->{$r->complete} }, $r->quantity;
    }

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    cmp_deeply( $sps, $wanted->{status}, 'Status as expected' )             if ( exists $wanted->{status} );
    cmp_deeply( $spt, $wanted->{type}, 'Type as expected' )                 if ( exists $wanted->{type} );
    cmp_deeply( $spc, $wanted->{complete}, 'Complete Flag as expected' )    if ( exists $wanted->{complete} );
}

sub check_printout {
    my ($self, $got, $expected) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    foreach my $group ( sort @$expected ) {
        my $file = $got->{$group}{full_path};
        # if not defined qty then assume file shouldn't have been created and
        # check it hasn't
        ok( -e $file, "$group file ($file) exists and > 0 bytes" );
        my $content;
        ok( io($file) > $content, "file contents read in" );
        my $group_content = ucfirst $group;
        like( $content, qr/\b$group_content\b/, "contains '$group_content' heading" );
    }
}

=head2 test_quality_control_sock_process_group_deletion:

There was issue with db schema that when one of the records for a particular
stock process group was deleted, it deleted all the rows for that group

=cut

sub test_quality_control_sock_process_group_deletion: Tests {
    my $self = shift;

    my $variant = (Test::XTracker::Data->grab_products({how_many=>1,force_create=>1}))[1][0]{variant};
    my $sp = $self->stock_process_for_qc($variant->product);

    my $schema = Test::XTracker::Data->get_schema;

    my $variant2 = (Test::XTracker::Data->grab_products({how_many=>1,force_create=>1}))[1][0]{variant};
    my $po = Test::XTracker::Data->setup_purchase_order($variant2->product->id);
    my ($delivery) = Test::XTracker::Data->create_delivery_for_po($po->id, 'qc');

    # add another delivery item for the same group
    $schema->resultset('Public::StockProcess')->create({
        delivery_item_id => $delivery->delivery_items->first->id,
        quantity  => 1,
        group_id  => $sp->group_id,
        type_id   => $sp->type_id,
        status_id => $sp->status_id
    });

    #total items should be 2 for this stock process group
    my $sp_group = $schema->resultset('Public::StockProcess')->search({ group_id => $sp->group_id });
    cmp_ok($sp_group->count, '==', 2, 'We have 2 delivery items for this group');

    # we delete one of the delivery items from above stock process group
    $sp_group->search({ delivery_item_id => $delivery->delivery_items->first->id })->delete;

    #total items should be 1 for this stock process group
    $sp_group = $schema->resultset('Public::StockProcess')->search({ group_id => $sp->group_id });
    cmp_ok($sp_group->count, '==', 1, 'We have 1 delivery item for this group');
}
