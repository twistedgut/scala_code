#!/usr/bin/env perl

use NAP::policy "tt",     'test';

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::CMS;
use Test::XTracker::Data::Email;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :shipment_status
                                        :renumeration_status
                                        :renumeration_class
                                        :return_status
                                        :renumeration_type
                                        :correspondence_templates
                                        :shipment_class
                                    );
use XTracker::Config::Local         qw( config_var get_picking_printer );
use XTracker::Database::Return;
use XTracker::PrintFunctions;
use Test::XTracker::MessageQueue;
use Test::XTracker::Mock::PSP;
use Test::XTracker::PrintDocs;


# store what gets sent to the
# redefined 'send_email' function
my %send_email_args;
my $DIE_IN_SEND_EMAIL   = 0;

BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');
    use_ok('XTracker::Schema::Result::Public::Renumeration');
    use_ok('XTracker::Schema::ResultSet::Public::Renumeration');
    can_ok('XTracker::Schema::Result::Public::Renumeration', qw(
                                            generate_invoice
                                    ) );

    # redefine 'send_email'
    no warnings 'redefine';
    *XTracker::EmailFunctions::send_email   = \&_redefined_send_email;
    use warnings 'redefine';
}


# get a schema to query
my $schema = get_database_handle(
    {
        name    => 'xtracker_schema',
    }
);
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my ( $channel, $order, $r_rec ) = new_renumeration();

Test::XTracker::Data::CMS->set_ifnull_cms_id_for_template( $CORRESPONDENCE_TEMPLATES__CREDIT_FSLASH_DEBIT_COMPLETED );
my $local_cc_email  = Test::XTracker::Data::Email->create_localised_email_for_config_setting( $channel, 'customercare_email', 'fr_FR' );

my $printdocs = Test::XTracker::PrintDocs->new;

$schema->txn_do( sub {
        my $prnlog  = $r_rec->shipment->shipment_print_logs_rs->search( { 'me.document' => 'Invoice' },{ order_by => 'me.id DESC' } );

        # get the existing log id of any previous invoices that have been printed
        # for comparison later
        my $prev_inv_id = 0;
        $prev_inv_id = $prnlog->first->id       if ( defined $prnlog->first );

        # set-up the conditions for the test
        $order->update( { use_external_tax_rate => 1 } );
        $r_rec->renumeration_items->update( { unit_price => 0, duty => 0 } );

        # just need any printer
        my $printer = get_picking_printer( 'regular_customer', $channel->business->config_section );

        # delete any existing invoice file on disk
        my $invoice_path = XTracker::PrintFunctions::path_for_print_document({
            document_type => 'invoice',
            id => $r_rec->id,
            extension => 'html',
        });
        $printdocs->delete_file( 'invoice-'.$r_rec->id );

        $r_rec->generate_invoice( { printer => $printer, copies => 1 } );

        # check a new invoice document has been generated
        my ($invoice_doc) = grep { $_->file_type eq 'invoice' } $printdocs->wait_for_new_files( files => 1);
        ok $invoice_doc, 'should generate a new invoice';
        is $invoice_doc->file_id, $r_rec->id, '  generated document should have correct id';

        # check for a new entry in the print log
        $prnlog->reset;
        cmp_ok( $prnlog->first->id, '>', $prev_inv_id, 'Printed Invoice Document Logged in Print Log' );

        $schema->txn_rollback;
    } );

############################
# Test: refund_to_customer #
############################

# ----- Setup

my $guard = $schema->txn_scope_guard;
isa_ok( $guard, 'DBIx::Class::Storage::TxnScopeGuard', 'Transaction Scope Guard' );

# overwrite email content so we can test the
# correct params were getting through to it
Test::XTracker::Data::Email->overwrite_correspondence_template_content( {
    template_id  => $CORRESPONDENCE_TEMPLATES__CREDIT_FSLASH_DEBIT_COMPLETED,
    placeholders => {
        was_paid_using_credit_card => 'payment_info.was_paid_using_credit_card',
    }
} );

my $message_factory = Test::XTracker::MessageQueue->new( {
    schema  => $schema,
} );
isa_ok( $message_factory, 'Test::XTracker::MessageQueue', 'Test Message Queue' );

my $rtc_params = {
    refund_and_complete => 1,
    message_factory     => $message_factory,
    dbh_override        => get_database_handle(
                               {
                                   name    => 'xtracker',
                                   type    => 'readonly',
                               }
                           ),
};

# ----- The Tests

# --- RENUMERATION_STATUS__COMPLETED should Fail.

( $channel, $order, $r_rec ) = new_renumeration();

$r_rec->update( { sent_to_psp => 1 } )->discard_changes;
is(
    $r_rec->refund_to_customer( $rtc_params ),
    undef,
    'refund_to_customer returned undef as expected, when Sent to PSP already TRUE'
);
$r_rec->update( { sent_to_psp => 0 } )->discard_changes;

$r_rec->update( { renumeration_status_id => $RENUMERATION_STATUS__COMPLETED } )->discard_changes;

is(
    $r_rec->refund_to_customer( $rtc_params ),
    undef,
    'refund_to_customer returned undef as expected, for Completed Status'
);

# --- RENUMERATION_STATUS__CANCELLED should fail.

$r_rec->update( { renumeration_status_id => $RENUMERATION_STATUS__CANCELLED } )->discard_changes;

is(
    $r_rec->refund_to_customer( $rtc_params ),
    undef,
    'refund_to_customer returned undef as expected, for Cancelled Status'
);

# --- Check 'Card Debit' returns 'undef'

# will get a new Renumeration which is for a 'Card Debit'
( $channel, $order, $r_rec ) = new_renumeration();

$r_rec->update( {
    renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
} )->discard_changes;

is(
    $r_rec->refund_to_customer( $rtc_params ),
    undef,
    'refund_to_customer returned undef as expected, for Card Debit'
);

# --- Unexpected Invoice Type

$r_rec->update( {
    renumeration_type_id  => $RENUMERATION_TYPE__VOUCHER_CREDIT,
} )->discard_changes;

throws_ok
    { $r_rec->refund_to_customer( $rtc_params ) }
    qr{Unexpected invoice type: $RENUMERATION_TYPE__VOUCHER_CREDIT},
    'refund_to_customer died as expected for an unexpected invoice type';

rtc_ok( $r_rec, {
    check_other => 0,
    message     => 'Unexpected invoice type',
} );

# --- Invoice Type: STORE_CREDIT (Message Received on Queue)

( $channel, $order, $r_rec ) = new_renumeration();

$r_rec->update( {
    renumeration_type_id => $RENUMERATION_TYPE__STORE_CREDIT,
} )->discard_changes;

my $queue = '/queue/refund-integration-' . $order->channel->web_queue_name_part;
$message_factory->clear_destination($queue);

lives_ok { $r_rec->refund_to_customer( $rtc_params ) } 'refund_to_customer success for STORE_CREDIT';

$message_factory->assert_messages({
    destination => $queue,
    assert_header => superhashof({
        type => 'RefundRequestMessage',
    }),
    assert_body => superhashof({
        '@type'         => 'CustomerCreditRefundRequestDTO',
        orderId         => $order->order_nr,
        customerId      => $order->customer->is_customer_number,
        createdBy       => 'xt-' . $APPLICATION_OPERATOR_ID,
        refundCurrency  => $r_rec->currency->currency,
        refundValues    => bag(
            superhashof({
                '@type'     => 'CustomerCreditRefundValueRequestDTO',
                refundValue => ( $r_rec->shipping + $r_rec->misc_refund + $r_rec->gift_credit + $r_rec->store_credit + $r_rec->total_value ),
            }),
        ),
    }),
}, 'Message contains the correct data and is going in the correct queue' );

rtc_ok( $r_rec, {
    check_other => 1,
    message     => 'Invoice type - STORE_CREDIT',
} );

# --- Invoice Type: CARD_REFUND

( $channel, $order, $r_rec ) = new_renumeration();

$r_rec->update( {
    renumeration_type_id => $RENUMERATION_TYPE__CARD_REFUND,
} )->discard_changes;

Test::XTracker::Mock::PSP->refund_action( 'PASS' );

lives_ok { $r_rec->refund_to_customer( $rtc_params ) } 'refund_to_customer success for CARD_REFUND';

rtc_ok( $r_rec, {
    check_other => 1,
    message     => 'Invoice type - CARD_REFUND',
} );

my $last_psp_refund = Test::XTracker::Mock::PSP->get_refund_data_in;
isa_ok( $last_psp_refund->{refundItems}, 'ARRAY' );
cmp_ok( scalar @{ $last_psp_refund->{refundItems} }, '>=', 0, 'There are some refundItems present in the request to the PSP' );

# --- CARD_REFUND with zero amount, renumeration is cancelled

( $channel, $order, $r_rec) = new_renumeration();
$r_rec->update({
    renumeration_type_id => $RENUMERATION_TYPE__CARD_REFUND,
    shipping             => 0,
    misc_refund          => 0,
    store_credit         => 0
} )->discard_changes;

lives_ok { $r_rec->refund_to_customer( { %$rtc_params } ) } 'refund_to_customer success for zero refund amount';

#test that renumeration is cancelled

cmp_ok( $r_rec->renumeration_status_id, '==', $RENUMERATION_STATUS__CANCELLED, 'RENUMERATION_STATUS is set to CANCELLED' );

# --- Already Set 'sent_to_psp'

( $channel, $order, $r_rec ) = new_renumeration();

$r_rec->update( {
    sent_to_psp             => 1,
    renumeration_type_id    => $RENUMERATION_TYPE__CARD_REFUND,
} );

lives_ok { $r_rec->refund_to_customer( { %$rtc_params, no_reset_psp_update => 1 } ) } 'refund_to_customer success for NO_RESET_PSP_UPDATE';

rtc_ok( $r_rec, {
    check_other => 1,
    message     => 'NO_RESET_PSP_UPDATE',
} );

# --- SHIPMENT_STATUS__EXCHANGE_HOLD

( $channel, $order, $r_rec ) = new_renumeration();

$r_rec->update( {
    renumeration_type_id => $RENUMERATION_TYPE__STORE_CREDIT,
} );

my $shipment = Test::XTracker::Data->create_shipment({
    shipment_status_id => $SHIPMENT_STATUS__EXCHANGE_HOLD,
    shipment_class_id => $SHIPMENT_CLASS__EXCHANGE
});

Test::XTracker::Data::Order->link_shipment_to_order({
    order => $order,
    shipment => $shipment
});

# Create related return.
my $return = $r_rec->shipment->create_related( 'returns', {
    rma_number              => generate_RMA( $schema->storage->dbh, $r_rec->shipment->id ),
    return_status_id        => $RETURN_STATUS__AWAITING_RETURN,
    exchange_shipment_id    => $shipment->id,
} )->discard_changes;

$return->create_related( 'return_status_logs', {
    return_status_id    => $return->return_status_id,
    operator_id         => $APPLICATION_OPERATOR_ID,
} );

$return->create_related( 'link_return_renumerations', {
    renumeration_id => $r_rec->id
} );

lives_ok { $r_rec->refund_to_customer( $rtc_params ) } 'refund_to_customer success for SHIPMENT_STATUS__EXCHANGE_HOLD';

rtc_ok( $r_rec, {
    check_other => 1,
    message     => 'SHIPMENT_STATUS__EXCHANGE_HOLD',
} );

cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, 'SHIPMENT_STATUS changed from EXCHANGE_HOLD to PROCESSING' );


# --- Test when Customer Email Fails the Refund is STILL Completed

$DIE_IN_SEND_EMAIL  = 1;

( $channel, $order, $r_rec ) = new_renumeration();
$r_rec->update( {
    renumeration_type_id => $RENUMERATION_TYPE__CARD_REFUND,
} )->discard_changes;

lives_ok { $r_rec->refund_to_customer( $rtc_params ) } 'refund_to_customer success when Customer Email FAILS';

rtc_ok( $r_rec, {
    check_other     => 1,
    message         => 'Invoice Completed when Customer Email FAILS',
    no_email_check  => 1,
} );

$DIE_IN_SEND_EMAIL  = 0;

# --- Should die if return is cancelled.

( $channel, $order, $r_rec ) = new_renumeration();

# Create related return.
$return = $r_rec->shipment->create_related( 'returns', {
                                rma_number       => generate_RMA( $schema->storage->dbh, $r_rec->shipment->id ),
                                return_status_id => $RETURN_STATUS__CANCELLED,
                            } );

$return->create_related( 'link_return_renumerations', { renumeration_id => $r_rec->id } );

# Update renumeration.
$r_rec->update( {
    renumeration_type_id    => $RENUMERATION_TYPE__CARD_REFUND,
    renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
    renumeration_class_id   => $RENUMERATION_CLASS__RETURN,
} )->discard_changes;

cmp_ok( $r_rec->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_ACTION, 'Renuneration Status ID Updated to RENUMERATION_STATUS__AWAITING_ACTION' );
cmp_ok( $r_rec->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, 'Renuneration Class ID Updated to RENUMERATION_CLASS__RETURN' );

my $rma_number = $r_rec->return->rma_number;

Test::XTracker::Data::Email->restore_correspondence_template_content();

$guard->commit;

throws_ok
    { $r_rec->refund_to_customer( $rtc_params ) }
    qr{RMA \($rma_number\) linked to the invoice has been Cancelled, please investigate and then manually Complete or Cancel the Invoice},
    'refund_to_customer died as expected for a cancelled return';

Test::XTracker::Data::Email->cleanup_localised_email_addresses();
Test::XTracker::Data::CMS->restore_cms_id_for_template( $CORRESPONDENCE_TEMPLATES__CREDIT_FSLASH_DEBIT_COMPLETED );

done_testing;

sub new_renumeration {
    # clear hash used to store params passed
    # to redefined 'send_email' function
    %send_email_args = ();

    # Grab product.
    my( $channel, $pids ) = Test::XTracker::Data->grab_products( { how_many => 1 } );
    isa_ok( $channel, 'XTracker::Schema::Result::Public::Channel', 'New renumeration channel' );
    isa_ok( $pids, 'ARRAY', 'New renumeration pids' );

    # Create the order with related renumeration.
    my ( $order ) = Test::XTracker::Data->create_db_order( {
        pids => $pids,
        base => { create_renumerations => 1 }
    } );
    isa_ok( $order, 'XTracker::Schema::Result::Public::Orders', 'New renumeration order' );

    # set the language for the Customer to be
    # French to test for localised Email Addresses
    $order->customer->set_language_preference('fr');

    # Create related order payment.
    my $next_preauth = Test::XTracker::Data->get_next_preauth( $schema->storage->dbh );
    my $order_payment = Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
        settle_ref  => $next_preauth,
    } );
    isa_ok( $order_payment, 'XTracker::Schema::Result::Orders::Payment', 'New renumeration order payment' );

    # Get the renumeration.
    my $renumeration = $order->renumerations->first;
    isa_ok( $renumeration, "XTracker::Schema::Result::Public::Renumeration" );

    # Update the renumeration to expected values.
    $renumeration->update( {
        sent_to_psp             => 0,
        renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
    } )->discard_changes;

    note 'Created new renumeration (Order ID: ' . $order->id . ', Renumeration ID: ' . $renumeration->id . ')';

    # Clear email log for this shipment.
    $renumeration->shipment->shipment_email_logs->delete;

    return ( $channel, $order, $renumeration );

}

sub rtc_ok {
    my ( $renumeration, $args ) = @_;

    my $check_other = $args->{check_other};
    my $message     = $args->{message};
    my $check_email = !$args->{no_email_check};

    # Check sent_to_psp has been set to true.
    cmp_ok( $renumeration->sent_to_psp, '==', 1, "$message, renumeration has been sent to PSP" );

    if ( $check_other ) {
        if ( $check_email ) {
            # Check email has been sent by looking at the log.
            cmp_ok( $renumeration->shipment->shipment_email_logs->count, '==', 1,
                        "$message, shipment email log has been populated with one record" );
            cmp_ok(
                $renumeration->shipment->shipment_email_logs->first->correspondence_templates_id,
                '==', $CORRESPONDENCE_TEMPLATES__CREDIT_FSLASH_DEBIT_COMPLETED,
                "$message, shipment email log entry is for the correct template CREDIT_FSLASH_DEBIT_COMPLETED"
            );
            is( $send_email_args{from}, $local_cc_email->localised_email_address,
                        "From Address used when sending the Email was the Localised version: '" . $send_email_args{from} . "'" );
            like( $send_email_args{content}, qr/was_paid_using_credit_card:[01]/,
                                "'payment_info' is available to the email TT document" );
        }
        else {
            # Check email has NOT been sent by looking at the log.
            cmp_ok( $renumeration->shipment->shipment_email_logs->count, '==', 0,
                        "$message, No Customer Email was Logged against the Shipment" );
        }

        # Check status has been updated and log populated.
        cmp_ok( $renumeration->renumeration_status_id, '==', $RENUMERATION_STATUS__COMPLETED, "$message, Renumeration status is correct (COMPLETED)" );
        cmp_ok( $renumeration->renumeration_status_logs->count, '==', 1, "$message, renumeration status log has been populated" );

        # Check the invoice number has changed.
        isnt( $renumeration->invoice_nr, 'Renumeration for test order', "$message, renumeration invoice number has changed" );
    }
}

#-----------------------------------------------------------------

sub _redefined_send_email {
    my @params  = @_;

    note "========> IN REDEFINED 'send_email' FUNCTION";

    %send_email_args    = (
                from        => $params[0],
                reply_to    => $params[1],
                to          => $params[2],
                subject     => $params[3],
                content     => $params[4],
                type        => $params[5],
                attachments => $params[6],
                other_args  => $params[7],
            );

    die "TEST TOLD ME TO DIE"   if ( $DIE_IN_SEND_EMAIL );

    return 1;
}
