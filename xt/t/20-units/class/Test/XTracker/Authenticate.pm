package Test::XTracker::Authenticate;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1

Test::XTracker::Authenticate

=head1 DESCRIPTION

Tests the 'XTracker::Authenticate' module.

=cut

use Test::XTracker::Data;
use Test::XTracker::Mock::WebServerLayer;

use XTracker::Constants::FromDB     qw( :authorisation_level );


sub startup : Tests( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup();

    use_ok( 'XTracker::Authenticate' );
    use_ok( 'XTracker::Session' );

    can_ok( 'XTracker::Authenticate', 'handler' );

    # need to re-define the 'read_handle' function so that the
    # Database connection used by the Test is used by the code
    no warnings 'redefine';

    my $read_handle_func = sub {
        my @caller  = caller(1);
        note "========= IN REDEFINED 'XTracker::Database::read_handle', called from: '$caller[3]' =========";
        return $self->dbh;
    };

    # both of the following modules import 'read_handle' and so need it re-defined
    $self->{redefine}{read_handle}{'XTracker::Authenticate'}        = \&XTracker::Authenticate::read_handle;
    $self->{redefine}{read_handle}{'XTracker::Database::Profile'}   = \&XTracker::Database::Profile::read_handle;
    *XTracker::Authenticate::read_handle                            = $read_handle_func;
    *XTracker::Database::Profile::read_handle                       = $read_handle_func;

    use warnings 'redefine';

    $self->{mock_web_layer} = Test::XTracker::Mock::WebServerLayer->setup_mock;
}

sub setup : Tests( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup();

    $self->schema->txn_begin;
}

sub teardown : Tests( teardown => no_plan ) {
    my $self    = shift;

    $self->schema->txn_rollback;

    $self->SUPER::teardown();
}

sub shutdown_tests : Tests( shutdown => no_plan ) {
    my $self    = shift;

    no warnings 'redefine';

    # restore functions that were Re-Defined, so they don't ruin the rest of the Class tests
    *XTracker::Authenticate::read_handle        = $self->{redefine}{read_handle}{'XTracker::Authenticate'};
    *XTracker::Database::Profile::read_handle   = $self->{redefine}{read_handle}{'XTracker::Database::Profile'};

    use warnings 'redefine';

    $self->SUPER::shutdown();
}

=head1 TESTS

=head2 test_case_insensitive_log_in

Tests that when a User Name is passed to 'XTracker::Authenticate'
it will be dealt with in a Case-Insensitve manner and the correct
Operator's details will be populated in the Session.

=cut

sub test_case_insensitive_log_in : Tests() {
    my $self = shift;

    my $operator = $self->schema->resultset('Public::Operator')
                                 ->create( {
        name        => 'Test User Name',
        username    => 'Test.Uname',
        password    => 'new',
    } );

    # all of the following should be in
    # the 'session' after every test
    my %expect  = (
        operator_id         => $operator->id,
        operator_name       => $operator->name,
        operator_username   => $operator->username,
    );

    my %tests   = (
        "using a User Name that matches the case on the 'operator' record" => {
            user_name   => 'Test.Uname',
        },
        "using an all Upper Cased User Name" => {
            user_name   => 'TEST.UNAME',
        },
        "using an all Lower Cased User Name" => {
            user_name   => 'test.uname',
        },
        "using a Mixed Cased User Name" => {
            user_name   => 'tEsT.UnAmE',
        },
    );

    # setting this to '/Home' will cause the usual 'XT::AccessControls'
    # authorisation to be skipped because '/Home' is a special case
    Test::XTracker::Mock::WebServerLayer->set_url_to_use( '/Home' );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        $XTracker::Session::SESSION = {
            user_id     => $test->{user_name},
            # setting this means that '_store_opprefs_in_session' isn't called which is
            # not being tested here and causes issues as it disconnects the DB connection
            op_prefs    => {},
        };

        my $response = XTracker::Authenticate::handler( $self->{mock_web_layer} );

        my $got = $XTracker::Session::SESSION;
        cmp_deeply(
            $got,
            superhashof( \%expect ),
            "Session has the Expected Values in it for User Name: '" . $test->{user_name} . "'"
        );
    }
}

=head2 test__current_section_info

=cut

sub test__current_section_info : Tests() {
    my $self    = shift;

    my @tests = (
        {
            url     => '/StockControl/PurchaseOrder',
            expect  => {
                url_path    => '/StockControl/PurchaseOrder',
                section     => 'Stock Control',
                sub_section => 'Purchase Order',
            },
        },
        {
            url     => '/Admin/UserAdmin?some=param&another=param',
            expect  => {
                url_path    => '/Admin/UserAdmin',
                section     => 'Admin',
                sub_section => 'User Admin',
            },
        },
        {
            url     => '/Home',
            expect  => {
                url_path    => '/Home',
                section     => undef,
                sub_section => undef,
            },
        },
        {
            url     => '/GoodsIn/VendorSampleIn?foo=bar',
            expect  => {
                url_path    => '/GoodsIn/VendorSampleIn',
                section     => 'Goods In',
                sub_section => 'Vendor Sample In',
            },
        },
        {
            url     => 'http://xtracker.net-a-porter.com/GoodsIn/VendorSampleIn?foo=bar',
            expect  => {
                url_path    => '/GoodsIn/VendorSampleIn',
                section     => 'Goods In',
                sub_section => 'Vendor Sample In',
            },
        },
        {
            url     => '/Fulfilment/DDU',
            expect  => {
                url_path    => '/Fulfilment/DDU',
                section     => 'Fulfilment',
                sub_section => 'DDU',
            },
        },
        {
            url     => '/My/Messages',
            expect  => {
                url_path    => '/My/Messages',
                section     => 'My',
                sub_section => 'Messages',
            },
        },
        {
            url     => '/NAPEvents/InTheBox',
            expect  => {
                url_path    => '/NAPEvents/InTheBox',
                section     => 'NAP Events',
                sub_section => 'In The Box',
            },
        },
    );

    note "run some tests to make sure the Sections, Sub Sections, URL Paths are returned as expected";

    my $web_layer = $self->{mock_web_layer};
    foreach my $test ( @tests ) {
        my $url = $test->{url};
        Test::XTracker::Mock::WebServerLayer->set_url_to_use( $url );
        my @got = XTracker::Authenticate::_current_section_info( $web_layer );
        is_deeply(
            {
                url_path    => $got[0],
                section     => $got[1],
                sub_section => $got[2],
            },
            $test->{expect},
            "'_current_section_info' returned as expected for '${url}'"
        );
    }
}

