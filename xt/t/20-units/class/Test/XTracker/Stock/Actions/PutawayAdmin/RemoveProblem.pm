package Test::XTracker::Stock::Actions::PutawayAdmin::RemoveProblem;

# See also: Unit tests for AdviceResponse message

use NAP::policy "tt", "test", "class";
use FindBin::libs;

BEGIN {
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
}

use MooseX::Params::Validate 'validated_list';
use Test::XTracker::RunCondition prl_phase => 'prl', export => [qw/$iws_rollout_phase $prl_rollout_phase/];


use Test::MockObject;
use Test::Exception; # lives_ok

use XTracker::Constants::FromDB qw(
    :putaway_prep_group_status
    :putaway_prep_container_status
    :stock_process_status
);
use XTracker::Constants ':prl_type';
use Test::XT::Data::PutawayPrep;
use XTracker::Database::PutawayPrep;
use XTracker::Database::PutawayPrep::RecodeBased;
use XTracker::Stock::Actions::PutawayAdmin::RemoveProblem;
use XTracker::Database::StockProcess 'putaway_completed';
use XTracker::Role::WithAMQMessageFactory;

sub startup :Test(startup) {
    my ($self) = @_;
    $self->SUPER::startup();
    $self->{setup} = Test::XT::Data::PutawayPrep->new;
    $self->{class} = 'XTracker::Stock::Actions::PutawayAdmin::RemoveProblem';

    $self->{mock_handler} = Test::MockObject->new;
    $self->{mock_handler}->mock('redirect_to', sub { 1 });
    $self->{mock_handler}->mock('msg_factory', sub {
        my $msg_factory =
            XTracker::Role::WithAMQMessageFactory->build_msg_factory;
        $msg_factory->transformer_args->{schema} = $self->{schema};
        return $msg_factory;
    });

    $self->{mock_handler}->set_isa('XTracker::Handler');
    $self->{pp_container_rs}  = $self->schema->resultset('Public::PutawayPrepContainer');
    $self->{pp_helper}        = XTracker::Database::PutawayPrep->new({schema => $self->schema});
    $self->{pp_recode_helper} = XTracker::Database::PutawayPrep::RecodeBased->new({schema => $self->schema});
}

sub remove_stock_process :Tests {
    my ($self) = @_;

    # test both overscan and underscan, both discrepancies should be logged
    foreach my $type_of_discrepancy ('overscan', 'underscan') {
        $self->remove_group({
            test_type           => 'stock process',
            group_id_field_name => 'pgid',
            pp_helper           => $self->{pp_helper},
            type_of_discrepancy => $type_of_discrepancy,
            log_discrepancies   => 1,
        });
    }
}

sub remove_stock_process_extra_surplus :Tests {
    my ($self) = @_;

    # test overscan with one extra sku, then scan a second extra sku as well
    # at least the first discrepancy should be logged
    $self->remove_group({
        test_type           => 'stock process',
        group_id_field_name => 'pgid',
        pp_helper           => $self->{pp_helper},
        type_of_discrepancy => 'overscan',
        extra_surplus       => 1, # a second *extra sku*
        log_discrepancies   => 1,
    });
}

sub remove_stock_recode :Tests {
    my ($self, $args) = @_;

    # test both overscan and underscan, discrepancies are not logged
    foreach my $type_of_discrepancy ('overscan', 'underscan') {
        $self->remove_group({
            test_type           => 'stock recode',
            group_id_field_name => 'recode_id',
            pp_helper           => $self->{pp_recode_helper},
            recode              => 1,
            type_of_discrepancy => $type_of_discrepancy,
            log_discrepancies   => 0,
        });
    }
}

sub remove_voucher :Tests {
    my ($self, $args) = @_;

    # test both overscan and underscan, discrepancies are not logged
    foreach my $type_of_discrepancy ('overscan', 'underscan') {
        $self->remove_group({
            test_type           => 'voucher',
            group_id_field_name => 'pgid',
            pp_helper           => $self->{pp_helper},
            voucher             => 1,
            type_of_discrepancy => $type_of_discrepancy,
            log_discrepancies   => 0,
        });
    }
}

sub remove_return :Tests {
    my ($self) = @_;

    # test overscan only, discrepancies should be logged
    # can't scan less than one item, for a return
    $self->remove_group({
        test_type           => 'return',
        group_id_field_name => 'pgid',
        pp_helper           => $self->{pp_helper},
        return              => 1,
        type_of_discrepancy => 'overscan',
        log_discrepancies   => 1,
    });
}

# Utilities

sub remove_group {
    my ($self, $config) = @_;

    note(sprintf("    Set up %s, testing %s",
        $config->{test_type}, $config->{type_of_discrepancy}));

    # Setup
    my ($stock_process, $product_data)
        = $self->{setup}->create_product_and_stock_process( 1, {
            voucher    => $config->{voucher},
            return     => $config->{return},
            group_type => (
                $config->{recode}
                    ? XTracker::Database::PutawayPrep::RecodeBased->name
                    : XTracker::Database::PutawayPrep->name
            ),
        });

    my $group_id   = $product_data->{ $config->{group_id_field_name} };
    my $sku        = $product_data->{sku};
    my $variant_id = $product_data->{variant_id};
    my $pp_group   = $self->{setup}->create_pp_group({
        group_id   => $group_id,
        group_type => (
            $config->{recode}
                ? XTracker::Database::PutawayPrep::RecodeBased->name
                : XTracker::Database::PutawayPrep->name
        ),
    });
    my $pp_container = $self->{setup}->create_pp_container;

    # Scan items, resulting in either overscan or underscan
    my $quantity_to_scan;
    if    ($config->{type_of_discrepancy} eq 'overscan')  { $quantity_to_scan = $stock_process->quantity + 1; }
    elsif ($config->{type_of_discrepancy} eq 'underscan') { $quantity_to_scan = $stock_process->quantity - 1; }
    else { die 'unrecognised type of discrepancy'; }

    note("Scanning $quantity_to_scan items for the ".$config->{test_type});
    $self->{pp_container_rs}->add_sku({
        container_id => $pp_container->container_id,
        group_id     => $group_id,
        sku          => $sku,
        putaway_prep => $config->{pp_helper},
    }) for 1 .. $quantity_to_scan;

    # Finish the container (and send to a PRL)
    $self->{pp_container_rs}->finish({ container_id => $pp_container->container_id });

    # Check group's scanned quantity
    is( $pp_group->inventory_quantity, $quantity_to_scan, 'group quantity is correct' );

    # Send a successful AdviceResponse message for first container
    note("Send the AdviceResponse");
    my $msg = $self->create_message( AdviceResponse => {
        success      => $PRL_TYPE__BOOLEAN__TRUE,
        container_id => $pp_container->container_id,
        reason       => 'The Reason',
    });

    $self->send_message( $msg ); # this line creates extra line in LogPutawayDiscrepancy

    # Try putaway prepping with a second extra item
    if ($config->{extra_surplus}) {
        my $pp_container2 = $self->{setup}->create_pp_container;

        note("Scanning a second extra item for the ".$config->{test_type});
        $self->{pp_container_rs}->add_sku({
            container_id => $pp_container2->container_id,
            group_id     => $group_id,
            sku          => $sku,
            putaway_prep => $config->{pp_helper},
        });
        # Finish the second container (and send to a PRL)
        $self->{pp_container_rs}->finish({ container_id => $pp_container2->container_id });

        # Group's scanned quantity should include second extra item
        is( $pp_group->inventory_quantity, $stock_process->quantity + 2, 'group quantity is updated with second extra item' );

        # Send a successful AdviceResponse message for second container
        note("Send the AdviceResponse");
        my $msg = $self->create_message( AdviceResponse => {
            success      => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container2->container_id,
            reason       => 'The Other Reason',
        });
        $self->send_message( $msg );
    }

    my $amq_check = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

    my $initial_log_entries_count = $self->schema
        ->resultset('Public::LogPutawayDiscrepancy')
        ->search({
            variant_id       => $variant_id,
            stock_process_id => $stock_process->id,
        })->count;

    # Resolve the group
    note("Calling RemoveProblem handler");
    my $error_message;

    lives_ok(
        sub {
            $error_message = XTracker::Stock::Actions::PutawayAdmin::RemoveProblem::remove({
                schema   => $self->schema,
                handler  => $self->{mock_handler},
                group_id => $pp_group->canonical_group_id,
            })
        },
        'handler could remove a ' . $config->{test_type}
    );

    is( $error_message, 0, 'remove handler returned success' );

    $pp_group->discard_changes;

    is( $pp_group->status_id, $PUTAWAY_PREP_GROUP_STATUS__RESOLVED, 'group is resolved' );


    $self->_check_discrepancy({
        initial_log_entries_count => $initial_log_entries_count,
        variant_id                => $variant_id,
        stock_process             => $stock_process,
        pp_group                  => $pp_group,
        %$config
    });

    # Check if stock was correctly putaway
    $self->is_putaway({
        recode            => $config->{recode},
        product_details   => $product_data,
        stock_process     => $stock_process,
        quantity_expected => ($config->{extra_surplus}
                                ? $quantity_to_scan + 1
                                : $quantity_to_scan),
    });

    # Check if stock check message has been sent
    $amq_check->expect_messages({
        messages => [{
            type    => 'stock_check',
            details => {
                client => $pp_group->client,
                pgid   => $pp_group->canonical_group_id,
            }
        }]
    });
}

# Checks if discrepancy has been logged
#
sub _check_discrepancy {
    my ($self, $config) = @_;

    return unless $config->{log_discrepancies};

    my ($variant_id, $stock_process, $initial_log_entries_count, $pp_group) =
        @$config{qw/ variant_id stock_process initial_log_entries_count pp_group/};


    my $log_entries = $self->schema->resultset('Public::LogPutawayDiscrepancy')
        ->search(
            {
                variant_id       => $variant_id,
                stock_process_id => $stock_process->id,
            },
            {
                order_by => { -desc => 'recorded' }
            }
        );

    if ($config->{type_of_discrepancy} eq 'underscan') {
        note 'In case of underscan - expect new Putaway Log Discrepancy record';
        is(
            $log_entries->count,
            $initial_log_entries_count + 1,
            'Putaway discrepancy log was updated'
        );

        is(
            $log_entries->first->quantity,
            $pp_group->expected_quantity,
            'putaway discrepancy "expected quantity" logged correctly'
        );

        is(
            $log_entries->first->ext_quantity,
            $pp_group->inventory_quantity,
            'putaway discrepancy "expected quantity" logged correctly'
        );

    } else {
        note 'In case of overscan - nothing new goes to Putaway Log Discrepancy. '
            .'It was logged when consuming AdviceResponse message.';
        is(
            $log_entries->count,
            $initial_log_entries_count,
            'Putaway discrepancy log stays the same'
        );
    }

    local $TODO;
    $TODO = 'Waiting on decision. See DCA-1132' if $config->{extra_surplus};
}

sub is_putaway {
    my ($self, $recode, $product_details, $stock_process, $quantity_expected ) = validated_list(
        \@_,
        recode            => { isa => 'Bool' },
        product_details   => { isa => 'HashRef' },
        stock_process     => { isa => 'Any' }, # less than ideal, should allow: StockRecode|StockProcess
        quantity_expected => { isa => 'Maybe[Int]' },
    );

    $_->discard_changes for ($stock_process, $product_details->{product});

    if ($recode) {
        # Stock recode status
        ok( $stock_process->complete, 'Stock Recode is complete' );
        like( $stock_process->notes, qr/^Putaway/, 'stock recode was putaway' );

        # copied and pasted from recode_iws.t
        # see also AdviceResponse test
        # the first snapshot was taken in Test::XT::Data::PutawayPrep
        # this takes another snapshot and compares with the first
        my @in_quantity_tests  = @{$product_details->{in_quantity_tests}};
        my @out_quantity_tests = @{$product_details->{out_quantity_tests}};

        $_->snapshot('after recode putaway') for @out_quantity_tests,@in_quantity_tests;

        $_->test_delta(
            from         => 'after recode destroy',
            to           => 'after recode putaway',
            stock_status => {
                'Main Stock' => $stock_process->quantity,
            },
        ) for @in_quantity_tests;

        $_->test_delta(
            from         => 'after recode destroy',
            to           => 'after recode putaway',
            stock_status => {},
        ) for @out_quantity_tests;

    } else {
        # Stock process status
        is(
            $stock_process->status_id,
            $STOCK_PROCESS_STATUS__PUTAWAY,
            'Stock process status is Putaway'
        );

        # Putaway complete?
        is(
            putaway_completed( $self->schema->storage->dbh, $stock_process->id),
            1,
            'Putaway is completed'
        );

        is(
            $self->schema->resultset('Public::Putaway')->find({
                stock_process_id => $stock_process->id
            })->quantity,
            $quantity_expected,
            'correct quantity was putaway'
        );
    }
}

1;
