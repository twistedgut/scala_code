package Test::XTracker::Mock::Handler;
use strict;
use warnings;

=head1 NAME

Test::XTracker::Mock::Handler - A Mock XTracker::Handler

=cut

use XTracker::Constants qw( :application );
use Test::MockObject;
use Test::XTracker::Data::AccessControls;
use Test::XTracker::Mock::WebServerLayer;

use XT::AccessControls;
use Test::XTracker::MessageQueue;
use Digest::MD5 qw( md5_hex );

sub new {
    my ($class, $args) = @_;
    $args //= {};

    my $schema = Test::XTracker::Data->get_schema;
    my $dbh = $schema->storage->dbh;
    my $operator_id = delete $args->{operator_id} // $APPLICATION_OPERATOR_ID;
    my $operator    = $schema->resultset('Public::Operator')->find( $operator_id );
    my $mock_args = {
        schema  => $schema,
        dbh     => $dbh,
        session => {
            _session_id => _build_session_id(),
        },
        %$args,
    };
    $mock_args->{data}{operator_id} = $operator_id;
    my $mock_handler = Test::MockObject->new($mock_args);

    $mock_handler->set_isa('XTracker::Handler');

    # Mock the request object.
    $mock_handler->{request} = Test::XTracker::Mock::WebServerLayer->setup_mock;

    $mock_args->{session}{acl}{operator_roles}  //= Test::XTracker::Data::AccessControls->roles_for_tests;

    # Add a few methods
    my %set_methods = (
        schema            => $schema,
        dbh               => $dbh,
        operator_id       => $operator_id,
        operator          => $operator,
        session           => $mock_args->{session},
        uri               => $mock_args->{data}{uri},
        iws_rollout_phase => $mock_args->{data}{iws_rollout_phase},
        prl_rollout_phase => $mock_args->{data}{prl_rollout_phase},
        acl               => XT::AccessControls->new( {
            operator    => $operator,
            session     => $mock_args->{session},
        } ),
        msg_factory       => Test::XTracker::MessageQueue->new( {
            schema      => $schema,
        } ),
    );
    $mock_handler->set_always($_ => $set_methods{$_}) for keys %set_methods;

    # Mock any Methods
    foreach my $method ( keys %{ $args->{mock_methods} } ) {
        $mock_handler->mock( $method, $args->{mock_methods}{ $method } );
    }

    return $mock_handler;
}

sub _build_session_id {
    # 46414b45 is 'FAKE' in hex.
    return '46414b45' . md5_hex(rand);
}

1;
