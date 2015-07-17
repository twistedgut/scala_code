package Test::XT::Data::Order::Tender;

use NAP::policy "tt",     'test';

use parent "NAP::Test::Class";

use Test::XTracker::Data;
use Test::XTracker::Mock::PSP;

use XTracker::Config::Local         qw( config_var );

use XT::Data::Order::Tender;
use XT::Data::Money;


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();
    $self->{channel}        = Test::XTracker::Data->channel_for_nap();
    $self->{psp}            = 'Test::XTracker::Mock::PSP';
    $self->{pre_auth_ref}   = '2132423424',
}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;

    # Restore the card history to it's default, so we don't stamp all over
    # other tests.
    $self->{psp}->set_card_history_to_default;
    $self->{psp}->use_all_original_methods();
}

sub card_history_populates_correctly : Tests() {
    my $self = shift;

    my %tests   = (
                'No Card history'   => {
                        set     => [],
                        expected=> [],
                    },
                'One Order'         => {
                        set     => [
                                    { orderNumber => 2900000 },
                                ],
                        expected=> [
                                    { orderNumber => 2900000 },
                                ],
                    },
                'Three Orders'      => {
                        set     => [
                                    { orderNumber => 2900340 },
                                    { orderNumber => 2900000 },
                                    { orderNumber => 123245 },
                                ],
                        expected=> [
                                    { orderNumber => 2900340 },
                                    { orderNumber => 2900000 },
                                    { orderNumber => 123245 },
                                ],
                    },
                'One Pre-Order, Should return nothing'    => {
                        set     => [
                                    { orderNumber => 'pre_order_2323' },
                                ],
                        expected=> [],
                    },
                'Three Pre-Orders, Should return nothing'    => {
                        set     => [
                                    { orderNumber => 'pre_order_2323' },
                                    { orderNumber => 'pre_order_122434' },
                                    { orderNumber => 'pre_order_2900000' },
                                ],
                        expected=> [],
                    },
                'Mixture of Pre-Orders & Orders, Should only return Orders' => {
                        set     => [
                                    { orderNumber => 2900000 },
                                    { orderNumber => 'pre_order_2323' },
                                    { orderNumber => 123245 },
                                    { orderNumber => 'pre_order_122434' },
                                    { orderNumber => 'pre_order_2900000' },
                                ],
                        expected=> [
                                    { orderNumber => 2900000 },
                                    { orderNumber => 123245 },
                                ],
                    },
            );

    foreach my $label ( keys %tests ) {
        note "Testing: $label";
        my $test    = $tests{ $label };

        my $tender  = $self->_new_tender_obj;

        # tell the PSP what to return when asked for Card History
        $self->{psp}->set_card_history( $test->{set} );

        my $value   = $tender->get_payment_value_from_psp;
        isa_ok( $value, 'XT::Data::Money', "'get_payment_value_from_psp' returned as expected" );
        is_deeply( $tender->card_history, $test->{expected}, "'card_history' is set as expected" );
        ok( $tender->card_type, "'card_type' is set with a value" );
        ok( $tender->cv2avs_status, "'cv2avs_status' is set with a value" );
        ok( $tender->card_number, "'card_number' is set with a value" );
    }
}

sub _new_tender_obj {
    my $self    = shift;

    my $args    = {
            schema      => $self->schema,
            id          => 'test_id',
            type        => 'Card Debit',
            rank        => '1',
            value       => XT::Data::Money->new( {
                                    schema      => $self->schema,
                                    currency    => config_var( 'Currency', 'local_currency_code' ),
                                    value       => 123.45,
                                } ),
            payment_pre_auth_ref    => $self->{pre_auth_ref},
        };

    return XT::Data::Order::Tender->new( $args );
}

1;
