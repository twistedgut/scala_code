package Test::XTracker::Handler;

use NAP::policy "tt", qw/test class/;
BEGIN {
    extends 'NAP::Test::Class';
};

=head1 NAME

Test::XTracker::Handler

=head1 DESCRIPTION

Tests the 'XTracker::Handler' Class.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::AccessControls;
use Test::XTracker::Mock::WebServerLayer;

use XTracker::Handler;

use XTracker::Constants::FromDB     qw( :authorisation_level );


sub startup : Tests( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    $self->{mock_web_layer} = Test::XTracker::Mock::WebServerLayer->setup_mock;
}

sub setup : Tests( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup;

    # make sure the SESSION is empty
    $XTracker::Session::SESSION = { };
}


=head1 TESTS

=head2 test_acl_is_assigned_to_schema

Test that when instantiating 'XTracker::Handler' that the Schema connection
has an instance of 'XT::AccessControls' assigned to it.

=cut

sub test_acl_is_assigned_to_schema : Tests() {
    my $self    = shift;

    # get an Operator to use in the Session
    my $operator    = $self->rs('Public::Operator')->search->first;

    # test when No Operator in Session - such as when not Logged In
    my $handler = XTracker::Handler->new( $self->{mock_web_layer} );
    my $acl     = $handler->schema->acl;
    ok( !defined $acl, "No 'XT::AccessControls' assigned to Schema when NO Operator is in the Session" );

    $XTracker::Session::SESSION = {
        operator_id => $operator->id,
    };

    # test when there is an Operator in the Session
    $handler    = XTracker::Handler->new( $self->{mock_web_layer} );
    $acl        = $handler->schema->acl;
    isa_ok( $acl, 'XT::AccessControls', "'XT::AccessControls' assigned to Schema when an Operator IS in the Session" );
}

=head2 test_acl_is_assigned_to_the_handler

Test that an instance of 'XTracker::Handler' has an instance
of 'XT::AccessControls' assigned to it.

=cut

sub test_acl_is_assigned_to_the_handler : Tests() {
    my $self    = shift;

    # get an Operator to use in the Session
    my $operator    = $self->rs('Public::Operator')->search->first;

    # test when No Operator in Session - such as when not Logged In
    my $handler = XTracker::Handler->new( $self->{mock_web_layer} );
    my $acl     = $handler->acl;
    ok( !defined $acl, "No 'XT::AccessControls' assigned to XTracker::Handler when NO Operator is in the Session" );
    ok( !defined $handler->{data}{acl_obj}, "also is NOT in the 'data' Hash Ref" );

    $XTracker::Session::SESSION = {
        operator_id => $operator->id,
    };

    # test when there is an Operator in the Session
    $handler    = XTracker::Handler->new( $self->{mock_web_layer} );
    $acl        = $handler->acl;
    isa_ok( $acl, 'XT::AccessControls', "'XT::AccessControls' assigned to XTracker::Handler when an Operator IS in the Session" );
    isa_ok( $handler->{data}{acl_obj}, 'XT::AccessControls', "also is IN the 'data' Hash Ref" );
}

=head2 test_operator_authorised

Tests the 'operator_authorised' method that checks to see if the current Operator
can access a Main Nav option. Will test it works with & without using Roles.

=cut

sub test_operator_authorised : Tests() {
    my $self    = shift;

    my $schema  = $self->schema;

    $schema->txn_begin;

    # override the function the Handler uses to get
    # the Schema to make sure it uses the Test's Schema
    no warnings 'redefine';
    my $orig_function = \&XTracker::Datbase::get_database_handle;
    local *XTracker::Database::get_database_handle = sub {
        note "======================= IN RE-DEFINED FUNCTION 'get_database_handle' =======================";
        return $schema;
    };
    use warnings 'redefine';

    my $operator    = $self->rs('Public::Operator')->search->first;

    # make sure Main Nav options can use ACL system wide
    Test::XTracker::Data::AccessControls->set_build_main_nav_setting( 'On' );

    Test::XTracker::Data::AccessControls->set_main_nav_options( {
        # setup for ACL
        acl => {
            app_has_superpowers => [
                'Fulfilment/Packing',
            ],
        },
        # setup for the old non ACL way
        non_acl => {
            operator   => $operator,
            department => 'Customer Care',
            $AUTHORISATION_LEVEL__OPERATOR => [
                'Fulfilment/Dispatch',
            ],
        },
        delete_existing_acl_options => 1,
    } );

    $XTracker::Session::SESSION = {};
    my $handler = XTracker::Handler->new( $self->{mock_web_layer} );
    my $got;
    lives_ok {
        $got = $handler->operator_authorised( { section => 'Fulfilment', sub_section => 'Dispatch' } );
    } "'operator_authorised' called when there is NO Operator doesn't DIE";
    cmp_ok( $got, '==', 0, "and returns FALSE" );

    # to stop the DB connection from being destroyed
    # when the Handler's DESTROY method is called
    delete $handler->{dbh};
    delete $handler->{schema};

    $XTracker::Session::SESSION = {
        operator_id => $operator->id,
        acl => {
            operator_roles => Test::XTracker::Data::AccessControls->roles_for_tests,
        }
    };

    note "call 'operator_authorised' when the Operator is setup to use the NON-ACL way";
    $operator->update( { use_acl_for_main_nav => 0 } );
    $handler = XTracker::Handler->new( $self->{mock_web_layer} );

    $got = $handler->operator_authorised( { section => 'Fulfilment', sub_section => 'Dispatch' } );
    cmp_ok( $got, '==', 1, "requesting authorisation for a NON-ACL section returns TRUE" );
    $got = $handler->operator_authorised( { section => 'Fulfilment', sub_section => 'Packing' } );
    cmp_ok( $got, '==', 0, "requesting authorisation for an ACL section returns FALSE" );

    # to stop the DB connection from being destroyed
    # when the Handler's DESTROY method is called
    delete $handler->{dbh};
    delete $handler->{schema};

    note "call 'operator_authorised' when the Operator is setup to use ACL way";
    $operator->update( { use_acl_for_main_nav => 1 } );
    $handler = XTracker::Handler->new( $self->{mock_web_layer} );

    $got = $handler->operator_authorised( { section => 'Fulfilment', sub_section => 'Packing' } );
    cmp_ok( $got, '==', 1, "requesting authorisation for an ACL section returns TRUE" );
    $got = $handler->operator_authorised( { section => 'Fulfilment', sub_section => 'Dispatch' } );
    cmp_ok( $got, '==', 0, "requesting authorisation for a NON-ACL section returns FALSE" );

    # to stop the DB connection from being destroyed
    # when the Handler's DESTROY method is called
    delete $handler->{dbh};
    delete $handler->{schema};

    $schema->txn_rollback;

    # restore the Handler's Original Schema getting function
    no warnings 'redefine';
    local *XTracker::Database::get_database_handle = $orig_function;
    use warnings 'redefine';
}

=head2 test_referer_split_up

Tests the 'parse_referer_url' method on the Handler to make
sure it splits everything up ok.

=cut

sub test_referer_split_up : Tests() {
    my $self = shift;

    my %tests = (
        "No Referer" => {
            setup => undef,
            expect => {
                section => undef,
                sub_section => undef,
                levels => [],
                short_url => undef,
            },
        },
        "With Referer" => {
            setup => 'http://www.xtracker.com/CustomerCare/OrderSearch',
            expect => {
                section => 'Customer Care',
                sub_section => 'Order Search',
                levels => [ qw( CustomerCare OrderSearch) ],
                short_url => '/CustomerCare/OrderSearch',
            },
        },
        "Referer with just a Domain" => {
            setup => 'http://www.xtracker.com',
            expect => {
                section => undef,
                sub_section => undef,
                levels => [],
                short_url => undef,
            },
        },
        "Referer with Query String" => {
            setup => 'http://www.xtracker.com/CustomerCare/OrderSearch/NextBit?order_id=32435',
            expect => {
                section => 'Customer Care',
                sub_section => 'Order Search',
                levels => [ qw( CustomerCare OrderSearch NextBit ) ],
                short_url => '/CustomerCare/OrderSearch',
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        # set-up own mock web layer to customise the environment
        my $mock_web_layer = Test::XTracker::Mock::WebServerLayer->setup_mock( {
            env => {
                HTTP_REFERER => $test->{setup},
            },
        } );
        my $handler = XTracker::Handler->new( $mock_web_layer );

        my $got = $handler->parse_referer_url;
        cmp_deeply( $got, $test->{expect}, "'parse_referer_url' returned as expected" );
    }
}

