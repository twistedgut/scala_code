package Test::NAP::GoodsIn::PutawayPrep;

=head1 NAME

Test::NAP::GoodsIn::PutawayPrep - Integration tests for Putaway Prep handler

=head1 DESCRIPTION

Test the Putaway Prep handler running on the webserver.
Incorporates the model, database and handler logic.

NOTE: Some of the test logic depends on the fact that:

    (a) test products are created in a specific order, with new sequential SKUs
    (b) products' SKUs are sorted in the template

#TAGS goodsin putawayprep

=cut

use NAP::policy "tt", qw/class test/;

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "Test::Role::GoodsIn::PutawayPrep";
};

use FindBin::libs;

use Test::XTracker::Mechanize::GoodsIn;
use XTracker::Constants::FromDB qw(
    :storage_type
    :container_status
    :stock_process_type
);
use XTracker::Database::Container qw(:utils);

use Test::XTracker::RunCondition prl_phase => 'prl', export => qw/$prl_rollout_phase/;

use XT::Domain::PRLs;
use XTracker::Stock::GoodsIn::PutawayPrep;

sub startup : Tests(startup => 2) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    use_ok 'XTracker::Stock::GoodsIn::PutawayPrep';

    $self->{pp} = XTracker::Database::PutawayPrep->new({ schema => $self->schema });

    $self->{flow} = $self->get_flow; # we only need to log in once
}

# Return data structure with error keys and templates
#
sub error_dictionary {
    my ($test) = @_;

    return $test->{__error_dictionary} ||= XTracker::Stock::GoodsIn::PutawayPrep->error_dictionary;
}

# Return data structure with prompt keys and teplates
#
sub prompt_dictionary {
    my ($test) = @_;

    return $test->{__prompt_dictionary} ||=
        XTracker::Stock::GoodsIn::PutawayPrep->prompt_dictionary;
}

=head2 check_toggling_scan_mode

Check if toggling scanning mode works as expected, please see comments in test
for further details.

=cut

sub check_toggling_scan_mode :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # get PGID with one products in it
    my $pgid = $test->get_test_pgid(1);
    ok $pgid, 'Got PGID';
    my $pgid_nr = $pgid;
    $pgid_nr =~ s/p//;
    my $pgid_list = XTracker::Stock::GoodsIn::PutawayPrep::get_pgid_lists($test->schema);
    ok ($pgid_list->{process_groups}->{'NET-A-PORTER.COM'}->{'delivery'}->{$pgid_nr}, "This process group is in the list ");

    # get SKU
    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($pgid) };

    # Initiate Putaway Prep process and scan two items of SKU
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    $pgid_list = XTracker::Stock::GoodsIn::PutawayPrep::get_pgid_lists($test->schema);
    ok (!$pgid_list->{process_groups}->{'NET-A-PORTER.COM'}->{'delivery'}->{$pgid_nr},"This process group already started PP and should not appear in the Putaway Prep list");

    # make sure page has correct content
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id          => $pgid,
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $pgid,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'Two SKUs are in container.'
    );

    # toggle scan mode to "reverse" and scan out SKU
    $flow->mech__goodsin__putaway_prep_change_scan_mode;

    # check that user is prompted with correct message
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN_REMOVE_SKU},
        'User prompt is correct after switching to reverse scan mode.'
    );

    $flow->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    # check that one SKU was removed
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id              => $pgid,
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'One SKU is left.'
    );

    # check that after SKU is removed - scan mode is set to default one automatically
    # by scanning SKU, which should be added to container
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    # check that one SKU was removed
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id              => $pgid,
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $pgid,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'Two SKUs again.'
    );


    # check that canceling "reverse" scan mode works, so toggle scan mode
    # twice and scan SKU - it should be added to container
    $flow->mech__goodsin__putaway_prep_change_scan_mode
         ->mech__goodsin__putaway_prep_change_scan_mode;

    # check that user is prompted with correct message
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN},
        'User prompt is correct after canceling SKU removing mode.'
    );

    $flow->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id          => $pgid,
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '3',
                       'PGID' => $pgid,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'And now three SKUs are left.'
    );
}

=head2 check_quantity_values

Check quantity fields in container table.

Consider both screens: ordinary container screen and resume container.

=cut

sub check_quantity_values :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # get PGID with 2 products in it
    my $pgid = $test->get_test_pgid(2);
    ok $pgid, 'Got PGID';

    # get all SKUs
    my @skus = sort @{ $test->{pp}->get_skus_for_group_id($pgid) };

    # Initiate Putaway Prep process and scan two items of same SKU
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $skus[0])
         ->mech__goodsin__putaway_prep_submit(scan_value => $skus[0]);

    # Check that page content has one record for scanned SKUs but correspondent
    # quantity is 2
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id              => $pgid,
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $pgid,
                       'SKU'  => $skus[0],
                     },
                   ],
            },
        },
        'Have quantity "2" for scanned SKU.'
    );

    # scan another SKU
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $skus[1]);

    # and check number of records and their quantity field
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id              => $pgid,
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $pgid,
                       'SKU'  => $skus[0],
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => '',
                       'SKU'  => $skus[1],
                     },
                   ],
            },
        },
        'Correct quantity for both records.'
    );

    # pretend that current container was given up but then resumed
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    # check that resume container screen has correct quantity for each number
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $pgid,
                       'SKU'  => $skus[0],
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => '',
                       'SKU'  => $skus[1],
                     },
                   ],
            },
        },
        'Quantity persists over container resuming.'
    );
}

=head2 after_container_is_resumed_pgid_is_validated

Here we try to resume existing container with some nonsense as PGID.

=cut

sub after_container_is_resumed_pgid_is_validated :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # get PGID with 2 products in it
    my $pgid = $test->get_test_pgid(2);
    ok $pgid, 'Got PGID';

    # get all skus
    my @skus = sort @{ $test->{pp}->get_skus_for_group_id($pgid) };

    $flow->mech__goodsin__putaway_prep
         # init PGID
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $skus[0]);

    # resume container
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    my $error_msg = sprintf(
        $test->error_dictionary->{ERR_START_PGID_GENERAL_FAILURE},
        'blablabla',
        'PGID/Recode group ID is invalid. Please scan a valid PGID/Recode group ID'
    );

    # try to submit nonsense as a PGID
    $flow->catch_error(
        $error_msg,
        'Submitting wrong PGID while resuming container is handled correctly.',
        mech__goodsin__putaway_prep_submit => (scan_value => 'blablabla')
    );
}

=head2 try_to_scan_nonsense_into_container

Check situation if there is an attempt to scan some nonsense into container,
instead of SKU or new PGID.

=cut

sub try_to_scan_nonsense_into_container :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # get PGID with 2 products in it
    my $pgid = $test->get_test_pgid(2);
    ok $pgid, 'Got PGID';

    # get all skus
    my @skus = sort @{ $test->{pp}->get_skus_for_group_id($pgid) };

    my $error_msg = sprintf $test->error_dictionary->{ERR_START_PGID_GENERAL_FAILURE},
        "blablabla", 'PGID/Recode group ID is invalid. Please scan a valid PGID/Recode group ID';

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init PGID
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $skus[0]);
    # scan something completely irrelevant, so it is niether SKU nor PGID
    $flow->catch_error(
        $error_msg,
        'Correct error message is shown to end user after attempt to scan some invalid PGID or SKU.',
        mech__goodsin__putaway_prep_submit => (scan_value => 'blablabla')
    );

    # check that user is prompted with correct message
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN},
        'User prompt is correct'
    );
}

=head2 resume_container_with_another_pgid

Start container with one PGID and then resume with another one.

=cut

sub resume_container_with_another_pgid :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # get PGID with 2 products in it
    my $pgid = $test->get_test_pgid(2);
    ok $pgid, 'Got PGID';

    # get all skus
    my @skus = sort @{ $test->{pp}->get_skus_for_group_id($pgid) };

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init PGID
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $skus[0])
         # scan second sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $skus[1]);


    # open PutawayPrep page once again,
    # so we have contained uncomplete
    $flow->mech__goodsin__putaway_prep;

    # scan container ID, so it is resumed
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    # check that user is prompted with right message
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_RESUME_CONTAINER_ASK_FOR_GROUP},
        'User is asked to enter PGID when resuming container'
    );


    # check page content, there shoul not be PGID yet
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid,
                       'SKU'  => $skus[0],
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => '',
                       'SKU'  => $skus[1],
                     }
                   ],
            },
        },
        'Check page content. PGID is undefined.'
    );

    my $pgid2 = $test->get_test_pgid(1);
    my ($sku3) = sort @{ $test->{pp}->get_skus_for_group_id($pgid2) };

    # try to resume container with the second PGID
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $pgid2);

    # check that correct user prompt is shown
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN},
        'User is advised to begin scaning SKUs from second PGID.'
    );

    # check that page now contains second PGID as active one
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid,
                       'SKU'  => $skus[0],
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => '',
                       'SKU'  => $skus[1],
                     }
                   ],
                group_id => $pgid2,
            },
        },
        'Check page content. Second PGID is active.'
    );

    # scan SKU from second PGIS into container
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $sku3);

    # correct prompt is in place
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN},
        'User is advised to continue scaning SKUs from second PGID.'
    );

    # check that page has corrent data that reflect two SKUs from
    # first PGID and one from second PGID. And active current PGID
    # is second one
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid,
                       'SKU'  => $skus[0],
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => '',
                       'SKU'  => $skus[1],
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid2,
                       'SKU'  => $sku3,
                     },
                   ],
                group_id => $pgid2,
            },
        },
        'Check page content. Container has SKUs from different PGIDs'
    );
}

=head2 try_to_add_pgid_of_wrong_storage_type

Start container with one PGID and try to add a PGID that needs a different
container type.

=cut

sub try_to_add_pgid_of_wrong_storage_type :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};

    # we'll use a tote
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # get PGID with flat product in it
    # flat items can go in totes
    my $pgid = $test->get_test_pgid(1, {storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT});
    ok $pgid, 'Got PGID';

    # get all skus
    my @skus = sort @{ $test->{pp}->get_skus_for_group_id($pgid) };

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init PGID
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $skus[0]);

    # now get a pgid with oversized items, which can't go in totes in DC2/DC3
    my $pgid2 = $test->get_test_pgid(1, {storage_type_id => $PRODUCT_STORAGE_TYPE__OVERSIZED});
    my ($sku2) = @{ $test->{pp}->get_skus_for_group_id($pgid2) };

    my $error_msg = sprintf $test->error_dictionary->{ERR_START_PGID_BAD_CONTAINER_TYPE},
        $pgid2, $container_id->as_id, "Invalid container."
        ." Container '".$container_id->as_id."' is for storage type.+";
    $flow->catch_error(
        qr/$error_msg/,
        'Correct error message is shown',
        mech__goodsin__putaway_prep_submit => (scan_value => $pgid2)
    );
}

=head2 mark_container_as_completed

=cut

sub mark_container_as_completed :Tests {
    my ($test, $args) = @_;

    my $flow = $test->{flow};

    # get PGID to use in test (it has two SKUs)
    my $pgid = $test->get_test_pgid(2);
    ok $pgid, 'Got PGID';

    # get SKUs from PGID
    my ($sku1, $sku2) = sort @{ $test->{pp}->get_skus_for_group_id($pgid) };

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init PGID
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1)
         # scan second sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku2);


    # check if page contains all required info
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid,
                       'SKU'  => $sku1,
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => '',
                       'SKU'  => $sku2,
                     }
                   ],
                group_id => $pgid,
            },
        },
        'Check page content'
    );

    # complete container, assume PRL specific questions have NOT been asked
    $flow->mech__goodsin__putaway_prep_complete_container;
}

=head2 mark_dematic_flat_container_as_completed

=cut

sub mark_dematic_flat_container_as_completed :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};

    # get PGID to use in test
    my $pgid = $test->get_test_pgid(1, {storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT});
    ok $pgid, 'Got PGID';

    # get SKUs from PGID
    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($pgid) };

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init PGID
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku);


    # check if page contains all required info
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid,
                       'SKU'  => $sku,
                     },
                   ],
                group_id => $pgid,
            },
        },
        'Check page content'
    );

    # check handling of PRL specific question while marking container as completed
    $test->check_prl_specific_answer({
        flow => $flow,
    });
}

=head2 try_to_scan_sku_that_is_not_associated_with_current_pgid

=cut

sub try_to_scan_sku_that_is_not_associated_with_current_pgid :Tests {
    my ($test) = @_;

    # get PGID to use in test
    my $pgid = $test->get_test_pgid;
    ok $pgid, 'Got PGID';

    # get SKU from first PGID
    my ($sku1) = @{ $test->{pp}->get_skus_for_group_id($pgid) };

    # get SKU that relates to different PGID
    my ($sku2) = @{ $test->{pp}->get_skus_for_group_id($test->get_test_pgid(1)) };

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init new PGID (scan first PGID)
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan new container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan SKU from first PGID into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1);

    my $error_msg = sprintf $test->error_dictionary->{ERR_SKU_NOT_FROM_PGID},
            $sku2, $pgid;

    # try to scan SKU that does not relate to first (active) PGID
    $flow->catch_error(
        $error_msg,
        'Correct error message is shown',
        mech__goodsin__putaway_prep_submit => (scan_value => $sku2)
    );

    # check that user has correct prompt
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN}
    );
}

=head2 scan_three_items_from_two_pgid_into_container

=cut

sub scan_three_items_from_two_pgid_into_container :Tests {
    my ($test) = @_;

    # get PGID that contains two products
    my $pgid = $test->get_test_pgid( 2 );
    ok $pgid, 'Got PGID';


    my ($sku1, $sku2) = sort @{ $test->{pp}->get_skus_for_group_id($pgid) };


    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });


    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init new PGID
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan new container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1)
         # scan second sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku2);

    # check user prompt
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN}
    );

    # check if page contains all required info
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid,
                       'SKU'  => $sku1,
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => '', # PGID is shown only in first row
                       'SKU'  => $sku2,
                     }
                   ],
                group_id => $pgid,
            },
        },
        'Check page content'
    );

    # get new PGID with new SKU
    my $second_pgid = $test->get_test_pgid(1);

    my ($sku3) = @{ $test->{pp}->get_skus_for_group_id($second_pgid) };

    # scan second PGID
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $second_pgid);

    # check that new PGID was initiated
    is(
        $flow->mech->app_info_message,
        sprintf($test->prompt_dictionary->{PRM_START_ANOTHER_PGID_FOR_CONTAINER}, $second_pgid)
            . $test->prompt_dictionary->{PRM_CONTAINER_SCREEN}
    );

    # check if current PGID was switched to newly passed one
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid,
                       'SKU'  => $sku1,
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => '', # PGID is shown only in first row
                       'SKU'  => $sku2,
                     }
                   ],
                group_id => $second_pgid,
            },
        },
        'Active PGID changed to be new one'
    );


    # scan SKU from second PGID
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $sku3);

    is( $flow->mech->app_info_message, $test->prompt_dictionary->{PRM_CONTAINER_SCREEN});

    # check that third sku was added into appropriate place
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid,
                       'SKU'  => $sku1,
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => '',
                       'SKU'  => $sku2,
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => $second_pgid,
                       'SKU'  => $sku3,
                     }
                   ],
                group_id => $second_pgid,
            },
        },
        'Third SKU is in right place'
    );
}

=head2 scan_correct_container

Check case when correct container was scanned.

Test for different storage types.

=cut

sub scan_correct_container :Tests  {
    my ($test) = @_;


    my $flow = $test->{flow};

    # flat things go in totes, oversized things in oversize containers
    foreach my $combination (
        {
            'container_type'  => 'Tote With Orientation',
            'prefix'          => 'T1',
            'storage_type_id' => $PRODUCT_STORAGE_TYPE__FLAT,
        },
        {
            'container_type' => 'Oversize Container',
            'prefix' => 'V111',
            'storage_type_id' => $PRODUCT_STORAGE_TYPE__OVERSIZED,
        },
    ) {
        my $pgid = $test->get_test_pgid(1,{storage_type_id => $combination->{storage_type_id}});
        ok $pgid, 'Got PGID';

        my ($container_id) = Test::XT::Data::Container->create_new_containers({
            prefix => $combination->{prefix},
        });

        $flow->mech__goodsin__putaway_prep
             ->mech__goodsin__putaway_prep_submit(scan_value => $pgid);

        is( $flow->mech->app_info_message,
            sprintf($test->prompt_dictionary->{'PRM_PGID_PAGE_GENERAL'},$combination->{container_type}));

        $flow->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

        is_deeply($flow->mech->as_data,
            {
                form => {
                    group_id     => $pgid,
                    container_id => $container_id,
                    container_content => [],
                },
            },
            'Form has all necessary data.'
        );

        # comment is correct
        is( $flow->mech->app_info_message, $test->prompt_dictionary->{PRM_CONTAINER_SCREEN});

    }
}

=head2 scan_incorrect_container

Check case when some incorrect container ID is scanned.

=cut

sub scan_incorrect_container :Tests {
    my ($test) = @_;

    my $pgid = $test->get_test_pgid;
    ok $pgid, 'Got PGID';

    my $flow = $test->{flow};

    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid);

    my $error_msg = sprintf $test->error_dictionary->{ERR_START_CONTAINER_INVALID},
        'bla bla bla';

    $flow->catch_error(
        $error_msg,
        "Scan some nonsense instead of real container ID.",
        mech__goodsin__putaway_prep_submit => ('scan_value' => 'bla bla bla')
    );

    is_deeply($flow->mech->as_data,
        {
            form => {
                group_id => $pgid,
            },
        },
        'Product group ID was passed from previous screen.'
    );
}

=head2 scan_correct_pgid

Check case when user successfully scan Product process ID.

=cut

sub scan_correct_pgid :Tests {
    my ($test) = @_;

    my $pgid = $test->get_test_pgid;
    ok $pgid, 'Got PGID';

    my $flow = $test->{flow};

    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid);

    is_deeply($flow->mech->as_data,
        {
            form => {
                group_id => $pgid,
            },
        },
        'Product group ID was passed from previous screen.'
    );

    # user prompt is correct
    is( $flow->mech->app_info_message, sprintf($test->prompt_dictionary->{'PRM_PGID_PAGE_GENERAL'},'Tote With Orientation'));
}

=head2 submit_empty_pgid

Check case when PGID is empty.

=cut

sub submit_empty_pgid :Tests  {
    my ($test) = @_;

    my $flow = $test->{flow};

    $flow->mech__goodsin__putaway_prep;
    $flow->catch_error(
        sprintf($test->error_dictionary->{ERR_START_PGID_NO_PGID}),
        "Case when passed Product group is unknown.",
        mech__goodsin__putaway_prep_submit => ('scan_value' => '  ')
    );

    is_deeply($flow->mech->as_data,
        {
            form => {},
        },
        'Unknown product was not carried over submition.'
    );
}

=head2 check_unknown_pgid

Check if page handles correctly the case when some unknown Process group is
scanned.

=cut

sub check_unknown_pgid :Tests  {
    my ($test) = @_;

    my $flow = $test->{flow};

    $flow->mech__goodsin__putaway_prep;

    my $error = $test->error_dictionary->{ERR_PGID_SCAN_GENERAL_FAILURE};

    $flow->catch_error(
        $error,
        "Case when passed Product group is unknown.",
        mech__goodsin__putaway_prep_submit => ('scan_value' => '1bla')
    );

    is_deeply($flow->mech->as_data,
        {
            form => {},
        },
        'Unknown product was not carried over submition.'
    );
}

=head2 try_to_scan_container_in_wrong_status

Check if correct error is displayed if scanned container has incorrect status.

=cut

sub try_to_scan_container_in_wrong_status :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};

    # we'll use a tote
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    my $container = $test->schema->resultset('Public::Container')->find($container_id);
    ok $container, 'Container object was fetched.';

    # make current container to have invalid status
    $container->update({status_id => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS});

    my $pgid = $test->get_test_pgid(1);
    ok $pgid, 'Got PGID';

    # init new putaway prep page and scan PGID
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid);

    # get container's status name
    my $container_status = $test->schema->resultset('Public::ContainerStatus')
        ->find($container->status_id);
    $container_status = $container_status->name;

    # compose error message
    my $error_msg = sprintf $test->error_dictionary->{ERR_START_CONTAINER_FAILURE},
        $container_id,
        qq!Container '$container_id' is not available for put away prep,!
        . qq! it is currently being used for '$container_status'. Please scan another container!;

    $flow->catch_error(
        $error_msg,
        'Correct error message is shown',
        mech__goodsin__putaway_prep_submit => (scan_value => $container_id->as_barcode)
    );
}

=head2 scan_unknown_sku_into_container

Check scenario when non existing SKU is scanned into container.

=cut

sub scan_unknown_sku_into_container :Tests {
    my ($test) = @_;

    my $pgid = $test->get_test_pgid(1);
    ok $pgid, 'Got PGID';

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix      => 'T0',
        orientation => 'A',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init new PGID
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan new container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    my $error_msg = sprintf $test->error_dictionary->{ERR_SKU_UNKNOWN}, '000000-000';

    $flow->catch_error(
        $error_msg,
        'Correct error message is shown',
        mech__goodsin__putaway_prep_submit => (scan_value => '000000-000')
    );
}

=head2 scan_two_pgids_containing_same_sku

=cut

sub scan_two_pgids_containing_same_sku :Tests {
    my ($test) = @_;

    # get PGID
    my $pgid = $test->get_test_pgid(1);
    ok $pgid, 'Got PGID';

    my @variants = map { $_->variant if defined $_->variant }
        $test->schema->resultset('Public::StockProcess')
        ->search({group_id => $test->{pp}->extract_group_number($pgid)})->all;
    my $sku1 = $variants[0]->sku;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init new PGID
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan new container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1)
    ;

    # check user prompt
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN}
    );

    # get new PGID, but with same SKU as in first PGID
    my $second_pgid = $test->get_test_pgid(1, {
        products => [ { pid => $variants[0]->product_id } ]
    });
    ok $second_pgid, 'Got second PGID';

    $_= $test->{pp}->extract_group_number($_) foreach $second_pgid, $pgid;

    my $error_msg = sprintf($test->error_dictionary->{ERR_START_PGID_GENERAL_FAILURE},
        $second_pgid, "PGID '" . $test->{pp}->get_canonical_group_id($second_pgid)
            . "' cannot be added to container"
            ." '$container_id' because it contains the same SKU with"
            ." PGID/Recode group ID '" . $test->{pp}->get_canonical_group_id($pgid)
            . "'. Please start new container for this PGID"
    );

    # scan second PGID
    $flow->catch_error(
        $error_msg,
        'Submitting different PGID with same SKU is correctly disallowed.',
        mech__goodsin__putaway_prep_submit => (scan_value => $second_pgid)
    );
}

=head2 resume_vouchers

Resume a PGID containing vouchers.

=cut

sub resume_vouchers :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'M0',
    });

    # get PGID with 2 products in it
    my $pgid = $test->get_test_pgid(2, { vouchers => { how_many => 1 } } );
    ok $pgid, 'Got PGID';

    # get all skus
    my @skus = sort @{ $test->{pp}->get_skus_for_group_id($pgid) };

    $flow->mech__goodsin__putaway_prep
        # init PGID
        ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
        # scan container
        ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
        # scan first sku into container
        ->mech__goodsin__putaway_prep_submit(scan_value => $skus[0]);

    # the putaway prep container is now 'in progress'

    # resume container
    $flow->mech__goodsin__putaway_prep
        # scan container: it should be resumed
        ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
        # scan a PGID, happens to be the same one as earlier
        ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
        # scan a sku into the container, happens to be the same one as before
        # it will just increase the quantity
        ->mech__goodsin__putaway_prep_submit(scan_value => $skus[0])
        # complete container
        ->mech__goodsin__putaway_prep_complete_container({
            prl_specific_question__container_fullness => '.50',
        });
}

=head2 container_only_marked_in_progress_after_sku_scanned

=cut

sub container_only_marked_in_progress_after_sku_scanned :Tests {
    my ($test) = @_;

    my $pgid = $test->get_test_pgid(1);
    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($pgid) };

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
        # init PGID
        ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
        # scan container
        ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    my $putaway_prep_container = $test->schema
        ->resultset('Public::PutawayPrepContainer')->find_in_progress({
            container_id => $container_id
        });

    ok( ! $putaway_prep_container, 'container is not in progress yet' );

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
        # init PGID
        ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
        # scan container
        ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
        # scan sku into container
        ->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    $putaway_prep_container = $test->schema
        ->resultset('Public::PutawayPrepContainer')->find_in_progress({
            container_id => $container_id
        });

    isa_ok( $putaway_prep_container,
        'XTracker::Schema::Result::Public::PutawayPrepContainer',
        'container is in progress now' );
}

=head2 container_is_already_in_progress

=cut

sub container_is_already_in_progress :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    my $pgid = $test->get_test_pgid(1);
    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($pgid) };

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
        # init PGID
        ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
        # scan container
        ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
        # scan sku into container
        ->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    note('container should now be in progress');

    # resume container
    $flow->mech__goodsin__putaway_prep
        # scan same PGID as before
        ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
        # scan same container as before - should not be allowed at this stage
        ->catch_error(
            sprintf( $test->error_dictionary->{ERR_START_CONTAINER_FAILURE},
                $container_id, 'Container "'.$container_id.'" is already in progress' ),
            'Container cannot be used as it is still in progress',
            mech__goodsin__putaway_prep_submit => (scan_value => $container_id->as_barcode)
        );
}

=head2 container_can_be_resumed

=cut

sub container_can_be_resumed :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    my $pgid = $test->get_test_pgid(1);
    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($pgid) };

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
        # init PGID
        ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
        # scan container
        ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
        # scan sku into container
        ->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    note('container should now be in progress');

    # resume container
    $flow->mech__goodsin__putaway_prep
        # scan container - should be resumed with an info message
        ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    my $info_p = $flow->mech->findnodes('//p[@class="info"]/text()');

    like( $info_p->string_value, qr/Container resumed/, 'Container is resumed' );
}

=head2 try_to_resume_conatiner_started_at_putaway_prep_for_packing_exception

=cut

sub try_to_resume_conatiner_started_at_putaway_prep_for_packing_exception :Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;

    note 'Generate SKU that comes from cancelled location';
    my ($sku) = @{ $self->create_stock_in_cancelled_location };
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'Start container at Putaway prep for Packing exception';
    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku
        });

    note 'Try to resume container on Putaway prep from Packing Exception';
    $flow->mech__goodsin__putaway_prep;
    $flow->catch_error(
        sprintf( $self->error_dictionary->{ERR_RESUME_CONTAINER_USE_PPPE}, $container_id),
        'Attempt to resume container is correctly rejected',
        mech__goodsin__putaway_prep_submit => (scan_value => $container_id->as_barcode),
    );
}

=head2 different_storage_types_in_same_container

=cut

sub different_storage_types_in_same_container :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};

    # get PGID to use in test
    my $pgid1 = $test->get_test_pgid(1, {storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT});
    ok $pgid1, 'Got PGID 1';

    my $pgid2 = $test->get_test_pgid(1, {storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT});
    ok $pgid2, 'Got PGID 2';

    # get SKUs from PGID
    my ($sku1) = @{ $test->{pp}->get_skus_for_group_id($pgid1) };
    my ($sku2) = @{ $test->{pp}->get_skus_for_group_id($pgid2) };

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init PGID 1
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid1)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1);

    my $error_msg = sprintf $test->error_dictionary->{ERR_START_PGID_GENERAL_FAILURE},
        $pgid2, "PGID cannot be scanned into container '".$container_id->as_id."'"
        ." because it contains items of type 'Dematic_Flat' and stock status 'Main Stock', this PGID contains"
        ." items of type 'Flat' and stock status 'Main Stock', hence must be sent to a different PRL."
        ." Please start a new container for this PGID";

    $flow->catch_error(
        $error_msg,
        'Submitting PGID with different storage type',
        mech__goodsin__putaway_prep_submit => (scan_value => $pgid2)
    );

    # check if page contains all required info, and not the wrong info
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid1,
                       'SKU'  => $sku1,
                     },
                   ],
                group_id => $pgid1,
            },
        },
        'Check page content'
    );

    # pretend that current container was given up but then resumed
    # no errors should occur
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    # check that resume container screen has correct quantity for each number
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid1,
                       'SKU'  => $sku1,
                     },
                   ],
            },
        },
        'Container could be resumed'
    );
}

sub same_storage_types_but_different_stock_status :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};

    # get PGID to use in test
    my $pgid1 = $test->get_test_pgid(1, {storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT});
    ok $pgid1, 'Got PGID 1';

    my $pgid2 = $test->get_test_pgid(1, {storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT});
    ok $pgid2, 'Got PGID 2';

    my $stock_process_row = $test->schema->resultset('Public::StockProcess')
        ->search({group_id => $test->{pp}->extract_group_number($pgid2)})->first;

    ok($stock_process_row, 'Got stockprocess row for second PGID');

    note 'Update second PGID to be DEAD stock';
    $stock_process_row->update({
        type_id => $STOCK_PROCESS_TYPE__DEAD,
    });

    # get SKUs from PGID
    my ($sku1) = @{ $test->{pp}->get_skus_for_group_id($pgid1) };
    my ($sku2) = @{ $test->{pp}->get_skus_for_group_id($pgid2) };

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init PGID 1
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid1)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1);

    my $error_msg = sprintf $test->error_dictionary->{ERR_START_PGID_GENERAL_FAILURE},
        $pgid2, "PGID cannot be scanned into container '".$container_id->as_id."'"
        ." because it contains items of type 'Dematic_Flat' and stock status 'Main Stock', this PGID contains"
        ." items of type 'Dematic_Flat' and stock status 'Dead Stock', hence must be sent to a different PRL."
        ." Please start a new container for this PGID";
    $flow->catch_error(
        $error_msg,
        'Submitting PGID with different storage type',
        mech__goodsin__putaway_prep_submit => (scan_value => $pgid2)
    );

    # check if page contains all required info, and not the wrong info
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid1,
                       'SKU'  => $sku1,
                     },
                   ],
                group_id => $pgid1,
            },
        },
        'Check page content'
    );

    # pretend that current container was given up but then resumed
    # no errors should occur
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    # check that resume container screen has correct quantity for each number
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $pgid1,
                       'SKU'  => $sku1,
                     },
                   ],
            },
        },
        'Container could be resumed'
    );
}

=head2 hanging_with_goh_trolley

Use a GOH trolley for a Hanging pid.

Check that the advice is sent to the expected prl according to the current
prl rollout phase.

=cut

sub hanging_with_goh_trolley :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};

    # we now use goh trolleys for hanging items
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix             => 'KT',
        final_digit_length => 4,
    });

    # get PGID with hanging product in it
    my $pgid = $test->get_test_pgid(1, {storage_type_id => $PRODUCT_STORAGE_TYPE__HANGING});
    ok $pgid, 'Got PGID';

    # get all skus in this pgid
    my @skus = sort @{ $test->{pp}->get_skus_for_group_id($pgid) };

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init PGID
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $skus[0]);


    # set up message monitoring
    my $amq = Test::XTracker::MessageQueue->new;
    $amq->clear_destination();

    note "Complete the container";
    $flow->mech__goodsin__putaway_prep_complete_container;

    note "Check the advice message";
    $amq->assert_messages({
        filter_header => superhashof({
            type => 'advice',
        }),
        assert_count => 1,
    }, 'one Advice message was sent' );

    my $prl_for_hanging;
    if ($prl_rollout_phase == 1) {
        # In phase 1, hanging goods are still stored in Full PRL
        $prl_for_hanging = 'Full';
    } else {
        # But from phase 2 onwards they belong in the GOH PRL
        $prl_for_hanging = 'GOH';
    }
    my $expected_destination = XT::Domain::PRLs::get_amq_queue_from_prl_name({
        prl_name => $prl_for_hanging,
    });
    $amq->assert_messages({
        destination   => $expected_destination,
        filter_header => superhashof({
            type => 'advice',
        }),
        assert_count  => 1,
    }, "and the Advice message was sent to the correct destination ($expected_destination)" );

    $amq->clear_destination();
}

1;
