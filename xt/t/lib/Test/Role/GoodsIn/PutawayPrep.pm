package Test::Role::GoodsIn::PutawayPrep;

use NAP::policy "tt", ("test", "role");

with 'NAP::Test::Class::PRLMQ';

use XTracker::Config::Local;
use XTracker::Database::Stock::Recode;
use XTracker::Database::PutawayPrep;
use XTracker::Constants qw/
    $APPLICATION_OPERATOR_ID
    :prl_type
/;
use XTracker::Constants::FromDB qw/
    :authorisation_level
    :storage_type
    :stock_process_status
    :stock_process_type
    :flow_status
/;

use Test::XT::Flow;
use Test::XTracker::Data;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::LocationMigration;
use Test::XTracker::MessageQueue;

=head1 NAME

Test::Role::GoodsIn::PutawayPrep - Contains commonly used code from
C<Test::NAP::GoodsIn::PutawayPrep> and C<Test::NAP::GoodsIn::PutawayPrepRecode>.

=head2 DESCRIPTION

In order to reduce code duplication some commonly used logic from both Putaway and
PutawayRecode mechanized tests was extracted into this role.

=head2 check_prl_specific_answer

With given $flow object drives it through checking if PRL specific
answer is handled correctly

B<Arguments>

$flow - flow object that already at the point where it it is possible to mark container
as completed. Flow object went through these steps: opened putaway prep page,
scanned PGID/RGID, scanned container, scanned SKUs.

=cut

sub check_prl_specific_answer {
    my ($self, $args) = @_;

    my ($flow) = @$args{qw/flow/};

    # all messages being sent with code below are dumped into directory
    my $amq = Test::XTracker::MessageQueue->new;

    # clean up queue dump directory (just in case)
    $amq->clear_destination();


    # try to mark current container as completed, but forget to answer PRL specific
    # question
    $flow->catch_error(
        $self->error_dictionary->{ERR_MARK_AS_COMPLETE_NO_ANSWER_FOR_FULLNESS_QUESTION},
        "Can't complete container without answering tote fullness question",
        mech__goodsin__putaway_prep_complete_container => ()
    );

    # pretend that user crafted POST requst to pass some invalid answers to
    # container fullness question
    $flow->catch_error(
        $self->error_dictionary->{ERR_MARK_AS_COMPLETE_NO_ANSWER_FOR_FULLNESS_QUESTION},
        "Can't complete container with invalid fullness answers",
        mech__goodsin__putaway_prep_complete_container => {
            prl_specific_question__container_fullness => 'blablabla'
        }
    );


    # This one should succeed
    $flow->mech__goodsin__putaway_prep_complete_container({
        prl_specific_question__container_fullness => '.50',
    });

    $amq->assert_messages({
        filter_header => superhashof({
            type => 'advice',
        }),
        assert_body => superhashof({
            container_fullness => '.50',
        }),
    }, '"container_fullness" has the same value which was passed via web interface' );

    # clean up
    $amq->clear_destination();


    # check that after page is reloaded submitted container has gone from page
    is_deeply(
        $flow->mech->as_data,
        {
            form => {},
        },
        'Check page content after container is submitted.'
    );

    # and check that user has correct prompt
    is(
        $flow->mech->app_info_message,
        $self->prompt_dictionary->{PRM_INITIAL_PROMPT}
    );
}

=head2 get_flow

Get flow object ready to be used on Putaway family pages

=cut

sub get_flow {

    my $perms = {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Goods In/Putaway Prep',
            'Goods In/Putaway Prep Admin',
            'Goods In/Putaway Problem Resolution',
            'Goods In/Putaway Prep Packing Exception',
        ],
        $AUTHORISATION_LEVEL__MANAGER => [
            'Goods In/Putaway Prep',
            'Goods In/Putaway Prep Admin',
            'Goods In/Putaway Problem Resolution',
            'Goods In/Putaway Prep Packing Exception',
        ],
    };

    my $flow = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::GoodsIn',
        ],
    );

    $flow->login_with_permissions({
        dept  => 'Distribution Management',
        perms => $perms,
    });

    return $flow;
}

=head2 get_test_pgid

Returns newly created PGID (product group).

<Parameters>

* $how_many_products - number of products in PGID, if omitted - 1 is used;

* hash ref of following structure:

    vouchers: flag that indicates if group should contain vouchers;

    products: optional array ref with product data;

    storage_type_id: storage type of product to be in PGID, if omitted - FLAT is used

=cut

sub get_test_pgid {
    my ( $test, $how_many_products, $args ) = @_;

    $how_many_products ||= 1;

    my $product_args = {
        how_many => $how_many_products,
        channel  => 'nap',
        force_create => 1,
    };
    $product_args->{phys_vouchers} = $args->{vouchers} if $args->{vouchers};
    note("Creating vouchers") if $args->{vouchers};

    my $channel; # not used
    my $product_data;
    if ($args->{products}) {
        # use specific products for the PGID
        $product_data = $args->{products};
    } else {
        # create new products for the PGID
        ($channel, $product_data) = Test::XTracker::Data->grab_products($product_args);

        # ensure all products have a storage type, except vouchers
        unless ($args->{vouchers}) {
            $_->{product}->update({
                storage_type_id => $args->{storage_type_id} || $PRODUCT_STORAGE_TYPE__FLAT
            }) for @{$product_data};
        }
    }

    my $sp_args = {
        status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        type_id   => $STOCK_PROCESS_TYPE__MAIN,
    };

    my $po = Test::XTracker::Data->setup_purchase_order( [map {$_->{pid}} @$product_data] );
    my @deliveries
        = Test::XTracker::Data->create_delivery_for_po( $po->id, 'putaway' );

    Test::XTracker::Data->create_stock_process_for_delivery( $_, $sp_args )
        for @deliveries;

    # Clear log for testing log entry created correctly
    my $operator = Test::XTracker::Data->get_schema
                               ->resultset('Public::Operator')
                               ->search({username=>''})
                               ->slice(0,0)
                               ->single;
    my $schema = Test::XTracker::Data->get_schema;
    $schema->resultset("Public::Log$_")->search({operator_id=>$operator->id})->delete
        for qw{Delivery Stock};


    my $sp_rs = $po->stock_orders
                   ->related_resultset('stock_order_items')
                   ->related_resultset('link_delivery_item__stock_order_items')
                   ->related_resultset('delivery_item')
                   ->related_resultset('stock_processes');

    return 'p' . $sp_rs->slice(0,0)->single->group_id;
}

=head2 fake_advice_response

Sends fake advice_response message with data passed as parameters.

B<Parameters>

* success : boolean, true if response stands for successful one, false - otherwise;

* container_id : container ID for which response relates;

* reason : optional parameter that holds failure reason, if omitted - no reason is specified.

=cut

sub fake_advice_response {
    my ($test, %args) = @_;
    my $may_die = $args{'may_die'};

    note("Process AdviceResponse message");

    # Create message
    my $message = $test->create_message( AdviceResponse => {
        success      => ($args{'response'}     || confess "expected response parameter"),
        container_id => ($args{'container_id'} || confess "expected container_id"),
        reason       => ($args{'reason'}       || ''),
    });

    # Action we want to perform
    my $action = sub { $test->send_message( $message ) };

    if ( $may_die ) {
        $action->();
    } else {
        lives_ok( sub { $action->() }, "AdviceResponse handler returned normally");
    }
}

=head2 fake_stock_adjust

=cut

sub fake_stock_adjust {
    my ($self, $message_args) = @_;

    state $stock_status = $self->schema->resultset("Flow::Status")->find(
        $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
    )->name;

    my $message = {
        prl              => "Full",
        client           => "NAP",
        reason           => "Reason",
        stock_status     => $stock_status,
        stock_correction => $PRL_TYPE__BOOLEAN__TRUE,
        date_time_stamp  => '2012-04-02T13:24:00+0000',
        update_wms       => $PRL_TYPE__BOOLEAN__TRUE,
    };

    $self->send_message(
        $self->create_message(
            "StockAdjust" => {
                %$message,
                %$message_args,
            },
        ),
    );
}

# TODO this method in very raw state and should be finished along the finishing recode
### NOTE: This code has been copied to Test::XT::Data::PutawayPrep and incorporated into that test data setup process.
### The message/consumer/test parts were converted to unit-test versions.

sub get_test_recode {
    my ($test, $args) = @_;

    my $product_storage_type_id = $args->{product_storage_type_id}
        || $PRODUCT_STORAGE_TYPE__FLAT;


    # TODO: Hard-coded PRL name
    my $prl  = XT::Domain::PRLs::get_prl_from_name({
        prl_name => 'Full',
    });

    my $transit_quantity    = 13;
    my $recode_out_quantity = 10;
    my $recode_in_quantity  = 17;

    my $products_4_transit_count = 1;
    my $new_products_count       = 1;

    my $channel     = Test::XTracker::Data->get_local_channel;
    my $channel_id  = $channel->id;
    my $factory     = Test::XTracker::MessageQueue->new();
    my $prl_to_xt   = Test::XTracker::Artifacts::RAVNI->new('prls_to_xt');
    my $schema      = $test->schema;


    my @new_products = Test::XTracker::Data->create_test_products({
        how_many        => $products_4_transit_count,
        channel_id      => $channel_id,
        product_quantity=> 0,
    });

    $_->update({storage_type_id => $product_storage_type_id }) for @new_products;

    my %new_variants = map {$_->id => $_->variants->slice(0,0)->single} @new_products;

    my @transit_products = $test->_products_out_of_prl_into_transit({
        how_many    => $products_4_transit_count,
        quantity    => $transit_quantity,
        channel_id  => $channel_id,
        prl         => $prl,

        prl_to_xt   => $prl_to_xt,
        factory     => $factory,
        channel     => $channel,
    });

    my $recode = XTracker::Database::Stock::Recode->new(
        schema      => $schema,
        operator_id => $APPLICATION_OPERATOR_ID,
        msg_factory => $factory,
    );

    isa_ok($recode,"XTracker::Database::Stock::Recode");


    my @out_quantity_tests = map {
        Test::XTracker::LocationMigration->new( variant_id => $_->{variant_id} ),
    } @transit_products;

    my @in_quantity_tests = map {
        Test::XTracker::LocationMigration->new(
            variant_id => $new_variants{$_->id}->id
        ),
    } @new_products;

    $_->snapshot('before recode') for @out_quantity_tests, @in_quantity_tests;

    # Destroy the stock
    my @stock_to_destroy = map {+{
        variant     => $_->{variant},
        quantity    => $recode_out_quantity,
    }} @transit_products;
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


    # Prepare the monitor so we catch the message
    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

    my @create_data = map {+{
        variant => $new_variants{$_->id},
        quantity=> $recode_in_quantity,
    }} @new_products;

    # Do the recode
    my $recode_objs = $recode->recode({
        to => \@create_data
    });

    return ('r' . $recode_objs->[0]->id(), 'r-' . $recode_objs->[0]->id() );
}


# private method used while generating new recodes
#
sub _products_out_of_prl_into_transit {
    my ($test, $args) = @_;

    my $prl_to_xt = delete $args->{prl_to_xt};
    my $factory = delete $args->{factory};
    my $channel = delete $args->{channel};

    my (undef, $pids) = Test::XTracker::Data->grab_products({
        how_many    => $args->{how_many},
        channel_id  => $args->{channel_id},
        ensure_stock_all_variants => 1,
    });

    my ($status,$reason) = ('Main Stock','STOCK OUT TO XT');

    foreach my $transit_product (@$pids) {
        my ($sku, $product, $variant_id, $variant)
            = @{$transit_product}{ qw(sku product variant_id variant) };

        my $quantity_change = $args->{quantity};
        # notify PRL that certain number of stock is going to be pulled
        $factory->transform_and_send('XT::DC::Messaging::Producer::PRL::StockAdjust',{
            sku             => $sku,
            delta_quantity  => -$quantity_change,
            reason          => $reason,
            stock_status    => $status,
            stock_correction=> $PRL_TYPE__BOOLEAN__FALSE,
            update_wms      => $PRL_TYPE__BOOLEAN__TRUE,
            version         => '1.0',
            total_quantity  => 23, #   This doesn't have any effect
            client          => $channel->business->client->prl_name,
            date_time_stamp => '2012-04-02T13:24:00+0000', # And we don't do anything with this either
            prl             => $args->{prl}->amq_identifier,
        });

        # check that message was fired
        $prl_to_xt->expect_messages({
            messages => [{
                type    => 'stock_adjust',
                path    => qr{/xt_prl$},
                details => {
                    reason  => $reason,
                    sku     => $sku,
                    stock_correction => $PRL_TYPE__BOOLEAN__FALSE,
                    delta_quantity   => -$quantity_change
                }
            }]
        });
    }

    # Return list of products sent into transit
    return @$pids;
}

# Get SKUs from spacial "Cancelled location" with items cancelled during Packing Exception.
# Optional parameters determine:
#   * how many of different SKUs to create
#   * how many of each particular SKU to create
#   * boolean flag that indicates if products to create are vouchers
#
sub create_stock_in_cancelled_location {
    my ($self, $number_of_skus, $args) = @_;

    my $schema   = $self->schema;
    $args->{location} =
        $schema->resultset('Public::Location')->get_cancelled_location;

    return $self->create_stock_in_location($number_of_skus, $args);
}

=head2 @skus = create_stock_in_location($number_of_skus, $args)

Create some test stock in a location.

$number_of_skus : Number of different skus to create
$args           : Hashref containing various arguments.

Keys:

storage_type_id   : ID of storage type (defaults to ID for FLAT)
sku_multiplicator : Number of each sku to create
location          : location for stock (defaults to first location found)

=cut

sub create_stock_in_location {
    my ($self, $number_of_skus, $args) = @_;

    my $storage_type_id   = $args->{storage_type_id};
    my $sku_multiplicator = $args->{sku_multiplicator} || 1;
    $number_of_skus ||= 1;

    my %pgid_params = map { $_ => $args->{$_} }
        grep {$args->{$_}} qw/ storage_type_id vouchers /;

    my $putaway_prep_helper = XTracker::Database::PutawayPrep->new;
    my $schema   = $self->schema;
    my $group_id = $self->get_test_pgid( $number_of_skus, \%pgid_params );
    my $skus     = $putaway_prep_helper->get_skus_for_group_id($group_id);
    my $location_row = $args->{location} || croak "No location given";
    my $quantity_rs  = $schema->resultset('Public::Quantity');
    my $variant_rs   = $schema->resultset('Any::Variant');
    my $channel_row  = $schema->resultset('Public::Channel')->net_a_porter;
    my $operator_row =
        $schema->resultset('Public::Operator')->get_operator($APPLICATION_OPERATOR_ID);

    $skus = [ map {@$skus} 1..$sku_multiplicator ];

    foreach my $sku (@$skus) {
        $quantity_rs->move_stock({
            variant  => $variant_rs->find_by_sku($sku),
            channel  => $channel_row,
            quantity => 1,
            from     => undef,
            to       => {
                location => $location_row,
                status   => $FLOW_STATUS__IN_TRANSIT_TO_PRL__STOCK_STATUS,
            },
            log_location_as => $operator_row,
        });
    }

    return $skus;
}

