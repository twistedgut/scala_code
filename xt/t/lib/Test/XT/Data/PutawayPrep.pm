package Test::XT::Data::PutawayPrep;
use NAP::policy "tt", 'test', 'class';

use NAP::policy "tt", 'test';

=head1 NAME

Test::XT::Data::PutawayPrep - Prepare data for putaway prep tests

=head1 DESCRIPTION

Proposed better way of organising this class:

List of methods:

    * create_product_and_stock_process( how_many => 1 )
    * create_pp_container( how_many => 1 )
    * create_pp_group( how_many => 1 )

=head1 SYNOPSIS

Proposed:

    $test_setup = Test::XT::Data::PutawayPrep->new;

    $stock_processes = $test_setup->create_product_and_stock_process( how_many => 2 );
    $pp_containers = $test_setup->create_pp_container();
    $pp_groups = $test_setup->create_pp_group();

Then work with those objects in the test itself.

=cut

use NAP::policy "tt", 'test', 'class';
use Test::XTracker::LoadTestConfig;
with 'XTracker::Role::WithSchema';
with 'XTracker::Role::WithPRLs';
with 'XTracker::Role::WithIWSRolloutPhase';
with 'Test::XT::Data::Quantity';
with 'Test::XTracker::Data::Quarantine';

use Carp qw/confess/;
use MooseX::Params::Validate qw/validated_list/;
use Test::MockObject;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants qw(
    $APPLICATION_OPERATOR_ID
    :prl_type
);
use XTracker::Constants::FromDB qw(
    :stock_process_status
    :container_status
    :stock_process_type
    :storage_type
    :putaway_prep_group_status
    :flow_status
    :storage_type
);
use XTracker::Database::Stock::Recode qw/dispatched_order qc_passed_return/;
use XTracker::Database::PutawayPrep::RecodeBased;
use XTracker::Database::PutawayPrep::CancelledGroup;
use XTracker::Database::PutawayPrep::MigrationGroup;
use XTracker::Database::PutawayPrep;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::LocationMigration;
use Test::XT::Data qw/new_with_traits/;
use Test::XT::Fixture::PackingException::Shipment;
use Test::XT::Fixture::Common::Product;

=head1 METHODS

=head2 get_user_id

=cut

sub get_user_id { $APPLICATION_OPERATOR_ID }

=head2 create_product_and_stock_process

For simplicity, this assumes the product has only one variant

(however if "$how_many" parameter for "cancelled group" is passed
it creates order with specified number of certain product)

Key "group_type" that has value returned by
XTracker::Database::PutawayPrep::RecodeBased->name class method
This is needed to deal with different group types, not just PGID and recodes

=cut

sub create_product_and_stock_process {
    my ($self, $how_many, $args) = @_;
    # NOTE: $how_many is supported only for "cancelled group" group type
    my $voucher    = $args->{voucher};
    my $return     = $args->{return};
    my $group_type = $args->{group_type};

    confess 'There should not be recode parameter any more! (use group_type instead)'
        if $args->{recode};

    # default group ID is one related to PGID
    $group_type ||= XTracker::Database::PutawayPrep->name;

    if ($group_type eq XTracker::Database::PutawayPrep::CancelledGroup->name) {

        return $self->_create_product_and_process_data_for_cancelled_group({
            how_many => $how_many,
        });
    }

    if ($group_type eq XTracker::Database::PutawayPrep::MigrationGroup->name) {

        return $self->_create_product_and_process_data_for_migration_group({
            how_many => $how_many,
        });
    }

    # TODO: Use Test::XTracker::Data->create_test_products
    #   instead of _get_test_products
    my ($product_data, $stock_process) = $self->_get_test_products({
        how_many   => $how_many,
        group_type => $group_type,
        voucher    => $voucher,
        return     => $return,
    });

    # ensure product has a storage type
    $product_data->{product}->storage_type_id($PRODUCT_STORAGE_TYPE__HANGING);
    $product_data->{product}->update;

    if ($group_type ne XTracker::Database::PutawayPrep::RecodeBased->name) {
        # 'pgid' is an initial key for storing group ID, but just to not opposite
        # "putaway_prep_group" lets call this key - "group_id"
        # (with time when all relied tests are updated - "pgid" could go)
        $product_data->{pgid} = $stock_process->group_id;
        $product_data->{group_id} = $stock_process->group_id;
    }
    note("using test data: ".join(", ",
        map { "$_ = ".($product_data->{$_}?$product_data->{$_}:'n/a') }
        qw/pgid recode_id return_id sku variant_id/
    ));

    note("using product_id: ".$product_data->{product}->id);
    note("using stock_process_id: ".$stock_process->id.", containing ".$stock_process->quantity. " items");

    return ($stock_process, $product_data);
}

sub _create_product_and_process_data_for_cancelled_group {
    my ($self, $how_many) = validated_list(
        \@_,
        how_many => { isa => 'Int',  optional => 1, default => 1 },
    );

    my $fixture = Test::XT::Fixture::PackingException::Shipment
        ->new({
            pids_multiplicator => $how_many,
            pid_count          => 1,
        })
        ->with_logged_in_user
        ->with_picked_shipment
        ->with_cancelled_order;

    is(
        $fixture->shipment_row->variants->count,
        $how_many,
        'We have shipment with one item'
    );

    my $variant = $fixture->shipment_row->variants->first;
    my $pp_helper = XTracker::Database::PutawayPrep::CancelledGroup->new;
    my %product_data = (
        sku                                    => $variant->sku,
        variant_id                             => $variant->id,
        product                                => $variant->product,
        $pp_helper->container_group_field_name => $pp_helper->generate_new_group_id,
        shipment_row                           => $fixture->shipment_row,
    );

    # Putaway prep based on "Cancelled location" does not have "process data"
    # in the way PGIDs or Recodes have, so replace "process data" object with
    # mocked one that supports interface tests rely on
    my $process_data = Test::MockObject->new;

    # quantity is how many was requested
    $process_data->mock(quantity => sub {$how_many});

    # mock up some more methods that are called along the way
    $process_data->mock(discard_changes => sub {});

    return ($process_data, \%product_data);
}

sub _create_product_and_process_data_for_migration_group {
    my ($self, $how_many) = validated_list(
        \@_,
        how_many => { isa => 'Int',  optional => 1, default => 1 },
    );

    my $fixture = Test::XT::Fixture::Common::Product->new({
        pids_multiplicator => $how_many,
        pid_count          => 1,
        storage_type_id    => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
    });

    my $pp_helper = XTracker::Database::PutawayPrep::MigrationGroup->new;
    my %product_data = (
        %{ $fixture->pids->[0] },   # copy product_data across
        $pp_helper->container_group_field_name => $pp_helper->generate_new_group_id,
    );

    # Putaway prep based on migration does not have "process data"
    # in the way PGIDs or Recodes have, so replace "process data" object with
    # mocked one that supports interface tests rely on
    my $process_data = Test::MockObject->new;

    # quantity is how many was requested
    $process_data->mock(quantity => sub {$how_many});

    # mock up some more methods that are called along the way
    $process_data->mock(discard_changes => sub {});

    return ($process_data, \%product_data);
}

=head2 create_pp_group

Create record in "putaway_prep_group" table based on group ID and group type,
where type is string from correspondent XTracker::Database::PutawayPrep class

=cut

sub create_pp_group {
    my ($self, $group_type, $group_id) = validated_list(
        \@_,
        group_type => { isa => 'Str',  optional => 1 },
        group_id   => { isa => 'Int' },
    );

    # by default created group is stock process (PGID) based
    $group_type ||= XTracker::Database::PutawayPrep->name;

    my $class = $group_type eq XTracker::Database::PutawayPrep->name
                ? 'XTracker::Database::PutawayPrep'
                : $group_type eq XTracker::Database::PutawayPrep::RecodeBased->name
                ? 'XTracker::Database::PutawayPrep::RecodeBased'
                : $group_type eq XTracker::Database::PutawayPrep::CancelledGroup->name
                ? 'XTracker::Database::PutawayPrep::CancelledGroup'
                : $group_type eq XTracker::Database::PutawayPrep::MigrationGroup->name
                ? 'XTracker::Database::PutawayPrep::MigrationGroup'
                : undef;

    confess "Failed to figure out correspondent class for group_type '$group_type'"
        unless $class;

    my $return_value = $self->schema->resultset('Public::PutawayPrepGroup')->create({
        $class->container_group_field_name => $group_id,
        status_id                          => $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
    });

    return $return_value;
}

=head2 create_pp_container

=cut

sub create_pp_container {
    my ($self) = @_;

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        how_many => 1,
        status => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
    });

    return $self->schema->resultset('Public::PutawayPrepContainer')->start({
        container_id => $container_id,
        user_id      => $self->get_user_id,
    });
}

=head2 _get_test_products

Create a purchase order and place all related db rows into an appropriate testing state.
Copied from putaway.t and sub 'get_test_pgid'

=cut

sub _get_test_products {
    my ($self, $args) = @_;
    my $how_many   = $args->{how_many};
    my $voucher    = $args->{voucher};
    my $return     = $args->{return};
    my $group_type = $args->{group_type};

    if ($group_type eq XTracker::Database::PutawayPrep::RecodeBased->name) {
        confess "cannot recode vouchers" if $voucher;
        confess "cannot return recodes"  if $return;
    }

    confess "cannot return vouchers" if $return and $voucher;

    my $product_data;
    my $stock_process; # stock_process table
    my $stock_recode;  # stock_recode table, equivalent to stock_process
    if ($group_type eq XTracker::Database::PutawayPrep::RecodeBased->name) {
        # $product_data = {
        #     recode_id => '123',
        #     product => XTracker::Schema::Result::Public::Product,
        #     variant_id => XTracker::Schema::Result::Public::Variant,
        #     sku => '456-321',
        # }
        # $stock_recode = XTracker::Schema::Result::Public::StockRecode

        ($product_data, $stock_recode) = $self->get_test_recode;
    }
    elsif ($return) {
        # $product_data = {
        #     return_id        => '10',
        #     rma_number       => 'U14-8',
        #     pid              => '77828',
        #     sku              => '77828-229',
        #     variant_id       => '385268',
        #     product          => XTracker::Schema::Result::Public::Product,
        # }
        # $stock_process = XTracker::Schema::Result::Public::StockProcess

        my $framework = Test::XT::Data->new_with_traits(
            traits => [
                'Test::XT::Data::Order',
                'Test::XT::Data::Return',
            ],
        );
        my $schema = $framework->schema;
        my $return;

        $schema->txn_do( sub {

            my $order_data = $framework->dispatched_order();
            my $return = $framework->qc_passed_return({
                shipment_id => $order_data->{'shipment_id'}
            });
            ok( $return, 'We have a QC passed return Id/RMA: '.$return->id.'/'.$return->rma_number );

            $stock_process = $return->return_items->first # assuming the simplest case
                ->uncancelled_delivery_item->stock_process;
            my $group_id = $stock_process->group_id;
            my $variant = $stock_process->variant;
            # as in Test::XTracker::Data->find_products:
            $product_data = {
                return_id   => $return->id,
                rma_number  => $return->rma_number,
                pid         => $variant->product_id,
                sku         => $variant->sku,
                variant_id  => $variant->id,
                product     => $variant->product,
            };
        } );
    }
    else {
        # normal product

        # $product_data = {
        #     pid              => '77828',
        #     size_id          => '229', # not used
        #     sku              => '77828-229',
        #     variant_id       => '385268',
        #     product          => XTracker::Schema::Result::Public::Product,
        #     variant          => XTracker::Schema::Result::Public::Variant, # not used
        #     product_channel  => XTracker::Schema::Result::Public::ProductChannel # not used
        # }
        # $stock_process = XTracker::Schema::Result::Public::StockProcess

        my $product_args = {
            how_many => $how_many || 1,
            channel => 'nap',
            force_create => 1,
            # setup_purchase_order() will randomly choose one if there are several,
            # so sanity dictates we'll just use one.
            how_many_variants => 1,
        };
        if ($voucher) {
            $product_args->{phys_vouchers} = { how_many => $voucher };
            $product_args->{how_many} = 0; # don't want any non-voucher variants
            note("Creating voucher");
        }
        my ($channel, $product_data_list) = Test::XTracker::Data->grab_products($product_args);
        $product_data = $product_data_list->[0];

        my $purchase_order = Test::XTracker::Data->setup_purchase_order( $product_data->{pid} );
        my @deliveries = Test::XTracker::Data->create_delivery_for_po( $purchase_order->id, 'putaway' );

        my $stock_process_args = {
            status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            type_id   => $STOCK_PROCESS_TYPE__MAIN,
        };
        my @stock_processes =
            map {
                # Weirdly need to re-search it from the db, discard_changes doesn't work
                $self->schema->resultset('Public::StockProcess')->find($_->id),
            }
            map {
                Test::XTracker::Data->create_stock_process_for_delivery(
                    $_,
                    $stock_process_args,
                );
            } @deliveries;
        $stock_process = $stock_processes[-1];
    }

    if ($group_type eq XTracker::Database::PutawayPrep::RecodeBased->name) {
        return ($product_data, $stock_recode);
    }
    else {
        return ($product_data, $stock_process);
    }
}

# NOTE: get_test_recode... has been taken from Test::NAP::GoodsIn::PutawayPrepRecode
# TODO this method in very raw state and should be finished along the finishing recode
sub get_test_recode {
    my ($self, $args) = @_;

    my $product_storage_type_id = $args->{product_storage_type_id}
        || $PRODUCT_STORAGE_TYPE__FLAT;

    my $recode_out_quantity = 10;
    my $recode_in_quantity  = 17;

    my $channel     = Test::XTracker::Data->get_local_channel;
    my $channel_id  = $channel->id;
    my $factory     = Test::XTracker::MessageQueue->new();
    my $schema      = $self->schema;


    my @new_products = Test::XTracker::Data->create_test_products({
        how_many          => 1,
        channel_id        => $channel_id,
        product_quantity  => 0,
        force_create      => 1,
        how_many_variants => 1,
    });

    # TODO make it configurable via method parameters
    $_->update({storage_type_id => $product_storage_type_id }) for @new_products;

    my %new_variants = map {$_->id => $_->variants->slice(0,0)->single} @new_products;

    # Ensure we create stock for the variant we are about to destroy in the right
    # location
    my $variant_to_destroy = $self->get_pre_quarantine_quantity({
        channel_id  => $channel_id,
        amount      => $recode_out_quantity,
    })->variant();

    # NOTE: At this point we deliberately skip the step of notifying PRLs
    # that a certain number of stock is going to be pulled, because
    # it's not necessary. Tests that create a recode in this way mainly
    # just care that it exists as a row in the stock_recode table.

    my $recode = XTracker::Database::Stock::Recode->new(
        schema      => $schema,
        operator_id => $APPLICATION_OPERATOR_ID,
        msg_factory => $factory,
    );

    isa_ok($recode,"XTracker::Database::Stock::Recode");

    my @out_quantity_tests = (
        Test::XTracker::LocationMigration->new( variant_id => $variant_to_destroy->id() ),
    );

    my @in_quantity_tests = map {
        Test::XTracker::LocationMigration->new(
            variant_id => $new_variants{$_->id}->id
        ),
    } @new_products;

    $_->snapshot('before recode') for @out_quantity_tests, @in_quantity_tests;

    # Destroy the stock
    my @stock_to_destroy = ({
        variant     => $variant_to_destroy,
        quantity    => $recode_out_quantity,
    });
    $recode->recode({
        from    => \@stock_to_destroy,
        force   => 1,
    });

    $_->snapshot('after recode destroy') for @out_quantity_tests,@in_quantity_tests;

    $_->test_delta(
        from    => 'before recode',
        to      => 'after recode destroy',
        stock_status => {
            'In transit from PRL' => -$recode_out_quantity,
        },
    ) for @out_quantity_tests;

    $_->test_delta(
        from    => 'before recode',
        to      => 'after recode destroy',
        stock_status => {},
    ) for @in_quantity_tests;


    my @create_data = map {+{
        variant => $new_variants{$_->id},
        quantity=> $recode_in_quantity,
    }} @new_products;

    # Do the recode
    my $recode_objs = $recode->recode({
        to => \@create_data
    });

    # Prepare the test data to return
    my $product = $new_products[0];
    my $sku = $new_variants{$product->id}->sku;
    my $variant = $self->schema->resultset('Public::Variant')->find_by_sku($sku);
    my $recode_id = $recode_objs->[0]->id(); # equivalent of stock_process->group_id

    my $product_data = {
        recode_id => $recode_id,
        product => $product,
        pid => $product->id,
        variant => $variant,
        variant_id => $variant->id,
        sku => $sku,

        in_quantity_tests => \@in_quantity_tests,
        out_quantity_tests => \@out_quantity_tests,
    };
    my $stock_recode = $self->schema->resultset('Public::StockRecode')
        ->find($recode_id);

    return ($product_data, $stock_recode);
}

1;
