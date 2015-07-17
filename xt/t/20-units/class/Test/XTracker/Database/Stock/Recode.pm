package Test::XTracker::Database::Stock::Recode;
use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::XT::Data::Quantity';
    with 'Test::XTracker::Data::Quarantine';

    has 'message_sent' => (
        is => 'rw',
        default => 0,
    );
};

use XTracker::Database::Stock::Recode;
use Test::XTracker::Data;
use Test::Exception;
use Test::MockObject;
use Test::MockModule;

sub test__destroy :Tests {
    my ($self) = @_;

    my $tests = [
        {
            note                => 'destroy() no auto',
            iws_rollout_phase   => 0,
            prl_rollout_phase   => 0,
            live                => 0,
            exception           => qr/Cannot destroy stock unless in IWS or PRL phase/,
        },
        {
            note                => 'destroy() PRL',
            iws_rollout_phase   => 0,
            prl_rollout_phase   => 1,
            live                => 1,
        },
        {
            note                => 'destroy() IWS',
            iws_rollout_phase   => 1,
            prl_rollout_phase   => 0,
            live                => 1,
        }
    ];

    for my $test (@$tests) {
        subtest $test->{note} => sub {

            note('Running test: ' . $test->{note});

            my ($recoder, $sku_data, $quantity) = $self->_test_setup({
                iws_rollout_phase => $test->{iws_rollout_phase},
                prl_rollout_phase => $test->{prl_rollout_phase},
            });

            if ($test->{live}) {
                lives_ok { $recoder->_destroy($sku_data) } 'destroy() lives';
                $quantity->discard_changes();
                is($quantity->quantity(), 2, 'stock has been destroyed');
            } else {
                throws_ok { $recoder->_destroy($sku_data) } $test->{exception},
                    'destroy() dies';
            }
        };
    }
}

sub test__create :Tests {
    my ($self) = @_;

    my $tests = [
        {
            note                => 'create() no auto',
            iws_rollout_phase   => 0,
            prl_rollout_phase   => 0,
            send_message        => 0,
        },
        {
            note                => 'create() PRL',
            iws_rollout_phase   => 0,
            prl_rollout_phase   => 1,
            send_message        => 0,
        },
        {
            note                => 'create() IWS',
            iws_rollout_phase   => 1,
            prl_rollout_phase   => 0,
            send_message        => 1,
        }
    ];

    for my $test (@$tests) {
        subtest $test->{note} => sub {
            note('Running test: ' . $test->{note});

            my ($recoder, $sku_data, $quantity) = $self->_test_setup({
                iws_rollout_phase   => $test->{iws_rollout_phase},
                prl_rollout_phase   => $test->{prl_rollout_phase},
            });

            my $recode_obj;
            lives_ok { $recode_obj = $recoder->_create($sku_data) } 'create() lives';
            isa_ok($recode_obj, 'XTracker::Schema::Result::Public::StockRecode',
                "Got a recode object back");

            is($recode_obj->variant_id(), $sku_data->{variant}->id(),
               'Stock recode object exists for correct variant');

            is($self->message_sent(), $test->{send_message}, ( $test->{send_message}
               ? 'Message was sent'
               : 'No message was sent'
            ));
        };
    }
}

sub test__recode :Tests {
    my ($self) = @_;

    my $mocked_recoder = Test::MockModule->new('XTracker::Database::Stock::Recode');

    # We're only testing the bit that compares the client and for third_party_skus
    # so just mock over the rest of it
    $mocked_recoder->mock('_create', sub { return 1 });
    $mocked_recoder->mock('_destroy', sub { return 1 });
    $mocked_recoder->mock('get_transit_stock_for_variant_id', sub { 1 });

    my $recoder = XTracker::Database::Stock::Recode->new(
        operator_id => Test::XTracker::Data->get_application_operator_id(),
    );

    my $mock_channel_1 = Test::MockObject->new();
    $mock_channel_1->set_isa('XTracker::Schema::Result::Public::Channel');
    $mock_channel_1->mock('id', sub { 1 });
    $mock_channel_1->mock('name', sub { 'Channel 1' });
    $mock_channel_1->mock('is_fulfilment_only', sub { 0 });

    my $mock_channel_2 = Test::MockObject->new();
    $mock_channel_2->set_isa('XTracker::Schema::Result::Public::Channel');
    $mock_channel_2->mock('id', sub { 2 });
    $mock_channel_2->mock('name', sub { 'Channel 2' });
    $mock_channel_2->mock('is_fulfilment_only', sub { 0 });

    # Variant 1 and 3 are of the same channel, and are therefore compatible for
    # recoding.
    # Variant 2 is of another channel, and is therefore incompatible for recoding
    # with variants 1 and 3

    my $mock_variant_1 = Test::MockObject->new();
    $mock_variant_1->set_isa('XTracker::Schema::Result::Public::Variant');
    $mock_variant_1->mock('id', sub { 1 });
    $mock_variant_1->mock('current_channel', sub { return $mock_channel_1; } );
    $mock_variant_1->mock('get_third_party_sku', sub { return undef; } );

    my $mock_variant_2 = Test::MockObject->new();
    $mock_variant_2->set_isa('XTracker::Schema::Result::Public::Variant');
    $mock_variant_2->mock('id', sub { 2 });
    $mock_variant_2->mock('current_channel', sub { return $mock_channel_2; } );
    $mock_variant_2->mock('get_third_party_sku', sub { return undef; } );

    my $mock_variant_3 = Test::MockObject->new();
    $mock_variant_3->set_isa('XTracker::Schema::Result::Public::Variant');
    $mock_variant_3->mock('id', sub { 3 });
    $mock_variant_3->mock('current_channel', sub { return $mock_channel_1; } );
    $mock_variant_3->mock('get_third_party_sku', sub { return undef; } );

    # 'sku' gets called in error messages from *::ToChannelMismatch, so let's
    # mock it to prevent warnings
    $_->mock('sku', sub { shift->id . '-001' })
        for $mock_variant_1, $mock_variant_2, $mock_variant_3;

    throws_ok {
        $recoder->recode({
            from    => [{
                variant     => $mock_variant_1,
                quantity    => 1,
            }, {
                variant     => $mock_variant_2,
                quantity    => 1,
            }],
            to      => [{
                variant     => $mock_variant_3,
                quantity    => 1,
            }],
            notes   => 'wibble',
        });
    } 'NAP::XT::Exception::Recode::FromChannelMismatch',
        'recode() dies when the "from" variant channels do not match';

    throws_ok {
        $recoder->recode({
            from    => [{
                variant     => $mock_variant_1,
                quantity    => 1,
            }],
            to      => [{
                variant     => $mock_variant_3,
                quantity    => 1,
            }, {
                variant     => $mock_variant_2,
                quantity    => 1,
            }],
            notes   => 'wibble',
        });
    } 'NAP::XT::Exception::Recode::ToChannelMismatch',
        'recode() dies when the "to" variant channels do not match';

    lives_ok {
        $recoder->recode({
            from    => [{
                variant     => $mock_variant_1,
                quantity    => 1,
            }],
            to      => [{
                variant     => $mock_variant_3,
                quantity    => 1,
            }],
            notes   => 'wibble',
        });
    } 'recode() with valid params lives';

    # The channel for variants 1 and 3 will now be made 'fulfilment_only'.
    # Under this condition, the variants must both have 'third_party_skus' assigned
    # or the recode can not go ahead
    $mock_channel_1->mock('is_fulfilment_only', sub { 1 });

    throws_ok {
        $recoder->recode({
            from => [{
                variant     => $mock_variant_1,
                quantity    => 1,
            }],
            to => [{
                variant     => $mock_variant_3,
                quantity    => 1,
            }],
            notes => 'wibble',
        });
    } 'NAP::XT::Exception::Recode::ThirdPartySkuRequired',
        'recode() dies when a variant with a "fulfilment_only" channel'
        . ' has no third-party-sku';

    $mock_variant_3->mock('get_third_party_sku', sub { return '123'; } );

    lives_ok {
        $recoder->recode({
            from => [{
                variant     => $mock_variant_1,
                quantity    => 1,
            }],
            to => [{
                variant     => $mock_variant_3,
                quantity    => 1,
            }],
            notes => 'wibble',
        });
    } 'recode() lives when a variant with a "fulfilment_only" channel'
        . ' has a third-party-sku';

}

sub _test_setup {
    my ($self, $args) = @_;
    $args //= {};
    my $iws_rollout_phase = $args->{iws_rollout_phase} // 0;
    my $prl_rollout_phase = $args->{prl_rollout_phase} // 0;

    $self->iws_rollout_phase($iws_rollout_phase);
    $self->prl_rollout_phase($prl_rollout_phase);
    $self->message_sent(0);

    my $mock_message_factory = Test::MockObject->new();
    $mock_message_factory->mock('transform_and_send', sub {
        $self->message_sent(1),
    });

    my $recoder = XTracker::Database::Stock::Recode->new(
        operator_id         => Test::XTracker::Data->get_application_operator_id(),
        iws_rollout_phase   => $iws_rollout_phase,
        prl_rollout_phase   => $prl_rollout_phase,
        msg_factory         => $mock_message_factory,
    );

    my $quantity = $self->get_pre_quarantine_quantity({ amount => 5 });
    my $sku_data = {
        variant     => $quantity->variant(),
        quantity    => 3,
    };

    return ($recoder, $sku_data, $quantity);
}
