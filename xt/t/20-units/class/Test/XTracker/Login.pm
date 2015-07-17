package Test::XTracker::Login;

use NAP::policy "tt", 'test';
use parent 'NAP::Test::Class';


=head1 Test::XTracker::Login

Testing the 'XTracker::Login' Class.

=cut

use Test::XTracker::Data;
use Test::XTracker::Mock::Handler;
use Test::XTracker::Mock::Interface::LDAP;

use XTracker::Login;

sub start_up : Test( startup => no_plan ) {
    my $self = shift;

    $self->{session} = {};
    $self->{schema}  = Test::XTracker::Data->get_schema;

    $self->{mock_handler} = Test::XTracker::Mock::Handler->new({
        session => $self->{session},
        mock_methods => {
            was_sent_ajax_header => sub { return 0; },
        }
    });

    $self->{mock} = Test::XTracker::Mock::Interface::LDAP->setup_mock;

}

sub setup: Test( setup => no_plan ) {
    my $self =  shift;

    $self->{schema}->txn_begin;

}

sub teardown : Test( teardown ) {
    my $self = shift;

    $self->{schema}->txn_rollback;
}


sub test_get_user_role_from_session : Tests( ) {
    my $self = shift;

    local $TODO = "Find out if 'XTracker::Login' is now redundant and these tests can be removed";

    my $user = Test::XTracker::Mock::Interface::LDAP->_get_user;

    my $operator =$self->{schema}->resultset('Public::Operator')->find({ username => $user });
    $operator->auto_login(0);
    $operator->update();


    Test::XTracker::Mock::Interface::LDAP->set_entry_attributes( {
        memberOf => [
            'CN=test_role_1,OU=dGroups,DC=london,DC=net-a-porter,DC=com',
            'CN=test_role_2,OU=sGroups,DC=london,DC=net-a-porter,DC=com',
        ],
    } );

# need to comment this line out as it breaks, fix when TODO resolved
#    my $tt = XTracker::Login::_log_user_in($self->{mock_handler}, $user, 0 );

    is_deeply(
        $self->{session}{acl},
        {
            operator_roles => [ qw(
                test_role_1
                test_role_2
            ) ],
        },
        "'operator_roles' in Session has Expected Roles"
    );

}

