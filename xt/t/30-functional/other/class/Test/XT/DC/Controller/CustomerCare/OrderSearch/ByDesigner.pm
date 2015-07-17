package Test::XT::DC::Controller::CustomerCare::OrderSearch::ByDesigner;

use NAP::policy     qw( test );
use parent 'NAP::Test::Class';

=head1 NAME

Test::NAP::CustomerCare::OrderSearch::ByDesigner

=head1 DESCRIPTION

Tests the 'Customer Care -> Order Search by Designer' pages.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::SearchOrderByDesigner;
use Test::XT::Flow;
use Test::XT::DC::JQ;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :authorisation_level );


sub startup : Test( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    Test::XTracker::Data::SearchOrderByDesigner->purge_search_result_dir();

    $self->{framework}  = Test::XT::Flow->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
            'Test::XT::Flow::OrderSearch::ByDesigner',
        ],
    } );

    $self->framework->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Customer Care/Order Search by Designer',
                'Customer Care/Customer Search',
                'Customer Care/Order Search',
            ],
        },
    } );
    $self->{operator} = $self->mech->logged_in_as_object;

    $self->{designers} = [
        $self->rs('Public::Designer')->search( {
            id => { '!=' => 0 },
        } )->all
    ];
    $self->{channel}   = Test::XTracker::Data->channel_for_nap();

    # store the Job Queue interface
    $self->{jq} = Test::XT::DC::JQ->new;
    $self->{jq}->clear_ok();
}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self    = shift;

    $self->SUPER::shutdown;
}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup;
}

sub teardown : Test( teardown => no_plan ) {
    my $self    = shift;

    $self->SUPER::teardown;

    Test::XTracker::Data::SearchOrderByDesigner->purge_search_result_dir();
    $self->{jq}->clear_ok();
}


=head1 TESTS

=head2 test_search_invalid_args

Test when making a search using Invalid Params.

=cut

sub test_search_invalid_args : Tests {
    my $self = shift;

    my $framework = $self->framework;

    # get the maxium Designer & Channel Ids
    my $max_channel_id = $self->rs('Public::Channel')
                                ->get_column('id')
                                    ->max() // 0;
    my $max_designer_id = $self->rs('Public::Designer')
                                ->get_column('id')
                                    ->max() // 0;

    my %tests = (
        "No Designer Id" => {
            args => {
                designer_id => undef,
            },
            expect => qr/Invalid.*Designer Id/i,
        },
        "Invalid Channel Id" => {
            args => {
                channel_id  => 'alpha',
                designer_id => $max_designer_id,
            },
            expect => qr/Invalid Channel Id/i,
        },
        "Invalid Designer Id" => {
            args => {
                designer_id => 'alpha',
            },
            expect => qr/Invalid.*Designer Id/i,
        },
        "Unknown Channel" => {
            args => {
                channel_id  => ( $max_channel_id + 1 ),
                designer_id => $max_designer_id,
            },
            expect => qr/Unknown Channel/i,
        },
        "Unknown Designer" => {
            args => {
                designer_id => ( $max_designer_id + 1 ),
            },
            expect => qr/Unknown Designer/i,
        },
        "Invalid Channel Id & Invalid Designer Id" => {
            args => {
                channel_id  => 'alpha',
                designer_id => 'alpha',
            },
            expect => qr/Invalid.*Designer.*Invalid Channel/i,
        }
    );

    $framework->flow_mech__customercare__ordersearch__by_designer();

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        $framework->catch_error(
            $test->{expect},
            "Check - ${label}",
            flow_mech__customercare__ordersearch__by_designer__search => (
                $test->{args}->{designer_id},
                $test->{args}->{channel_id},
            ),
        );
    }
}

=head2 test_search

Test making a Search that the Job appears on the Job Queue
and the correct Search Result files are created.

=cut

sub test_search : Tests() {
    my $self = shift;

    my $channel   = $self->{channel};
    my $designer  = $self->{designers}->[0];

    my $framework = $self->framework;
    my $jq        = $self->{jq};

    my %tests = (
        "Search with a Sales Channel" => {
            args => {
                channel  => $channel,
                designer => $designer,
            },
        },
        "Search without a Sales Channel" => {
            args => {
                designer => $designer,
            },
        },
    );

    $framework->flow_mech__customercare__ordersearch__by_designer();

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };
        my $args = $test->{args};

        $framework->flow_mech__customercare__ordersearch__by_designer__search(
            $args->{designer}->id,
            ( $args->{channel} ? $args->{channel}->id : undef ),
        );

        my $found_file = Test::XTracker::Data::SearchOrderByDesigner->check_if_search_result_file_exists_for_search_criteria( {
            designer => $args->{designer},
            channel  => $args->{channel},
            operator => $self->{operator},
            state    => 'pending',
        } );

        ok( $found_file, "'pending' Search Results file created: '${found_file}'" );

        $jq->has_job_ok( {
            funcname => 'XT::JQ::DC::Receive::Search::OrdersByDesigner',
            payload  => {
                results_file_name => $found_file,
            },
        }, "Job to do actual Search has been created and put on the Job Queue" );
    }
}

=head2 test_search_results_list

Test on the Search page the Search Results list is shown correctly.

=cut

sub test_search_results_list : Tests {
    my $self = shift;

    my %state_description = (
        pending   => 'Pending',
        searching => 'Searching',
        completed => 'Completed',
    );

    my $framework = $self->framework;

    my @operators = $self->rs('Public::Operator')->search( {
        id                => { '!=' => $APPLICATION_OPERATOR_ID },
        'LOWER(username)' => { '!=' => 'it.god' },
    }, { rows => 5 } )->all;

    # create some files to simulate a list of search results
    my $file_names = Test::XTracker::Data::SearchOrderByDesigner
                        ->create_search_result_files( 5, [
        { operator => $operators[0], state => 'pending', channel => $self->{channel} },
        { operator => $operators[1], state => 'pending' },
        { operator => $operators[2], state => 'searching' },
        { operator => $operators[3], state => 'completed', number_of_records => 0, channel => $self->{channel} },
        { operator => $operators[4], state => 'completed', number_of_records => 216 },
    ] );

    my $file_details  = Test::XTracker::Data::SearchOrderByDesigner->parse_search_result_file_names( $file_names );
    my @expected_list = (
        map {
            {
                'Operator'      => $_->{operator}->name,
                'Designer'      => $_->{designer}->designer,
                'Sales Channel' => ( $_->{channel} ? $_->{channel}->name : 'All' ),
                'Status'        => $state_description{ $_->{state} },
                'Records'       => $_->{number_of_records} // '',
                'Search Date'   => $_->{datetime}->format_cldr( "yyyy-MM-dd '\@' HH:mm" ),
            }
        } @{ $file_details }
    );

    $framework->flow_mech__customercare__ordersearch__by_designer();
    my $pg_data = $self->pg_data();
    cmp_deeply( $pg_data->{search_result_list}, bag( @expected_list ), "Search Result List shown correctly on page" );
}

=head2 test_search_results

Test that you can click on a Search Result from the list on the Search page
and show the Results of that Search.

=cut

sub test_search_results : Tests() {
    my $self = shift;

    my $framework = $self->framework;

    # grab a Designer to test with
    my $designer = $self->{designers}[0];

    my ( undef, $products ) = Test::XTracker::Data->grab_products( {
        how_many => 2,
        channel  => $self->{channel},
    } );

    # make all of the Products be for the Same Designer
    foreach my $pid ( @{ $products } ) {
        $pid->{product}->discard_changes->update( { designer_id => $designer->id } );
    }

    # create 5 Orders
    my @orders;
    foreach ( 1..5 ) {
        my $customer = Test::XTracker::Data->create_dbic_customer( { channel_id => $self->{channel}->id } );
        my $order_data = $framework->new_order(
            customer => $customer,
            channel  => $self->{channel},
            products => $products,
        );
        push @orders, $order_data->{order_object}->discard_changes;
    }

    my $file_name = Test::XTracker::Data::SearchOrderByDesigner->create_and_populate_search_result_file( {
        designer => $designer,
        orders   => \@orders,
    } );

    # as the results are drawn on the page using the jTable jQuery plug-in a check
    # can't be done that they are shown (other tests check that what is returned
    # is what is wanted) so just check that the page can be reached ok
    $framework->flow_mech__customercare__ordersearch__by_designer()
                ->flow_mech__customercare__ordersearch__by_designer__show_results( $file_name );
}

#----------------------------------------------------------------------------------

sub framework {
    my $self    = shift;
    return $self->{framework};
}

sub mech {
    my $self    = shift;
    return $self->framework->mech;
}

sub pg_data {
    my $self    = shift;
    return $self->mech->as_data;
}
