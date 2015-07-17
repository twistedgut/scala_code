package Test::XT::DC::Messaging::Consumer::SeaviewNotification;

use NAP::policy 'tt', 'test';
use parent "NAP::Test::Class";
use Test::XTracker::MessageQueue;
use Test::XTracker::Data;

=head1 NAME

Test::XT::DC::Messaging::Consumer::SeaviewNotification

=head1 DESCRIPTION

Test Seaview notification messages can be consumed

=cut

sub startup : Test( startup => 1 ) {
    my $self = shift;
    $self->SUPER::startup;

    ($self->{amq}, $self->{consumer}) = Test::XTracker::MessageQueue->new_with_app;
    $self->{queue}
      = Test::XTracker::Config->messaging_config
                              ->{'Consumer::SeaviewNotification'}{routes_map}{seaview_notification};

}

sub setup: Test(setup) {
    my $self = shift;
    $self->SUPER::setup;
    $self->{amq}->clear_destination( $self->{queue} );
}

sub teardown: Test(teardown) {
    my $self    = shift;
    $self->SUPER::teardown;
    $self->{amq}->clear_destination( $self->{queue} );
}

=head1 TEST METHODS

=head2 test_seaview_notification

=cut

sub test_seaview_notification : Tests() {
    my $self = shift;

    # Data from t/data/seaview/account.json
    my $test_account_urn = 'urn:nap:account:50cfa81bbf8eccc73fcc0448';
    my $channels
      = [ $self->schema->resultset('Public::Channel')->enabled_channels->all ];

    # Create a customer
    foreach my $channel ( @{ $channels } ) {

        # Clear the test db of linked customers
        $self->schema->resultset('Public::Customer')
                     ->search( { account_urn => $test_account_urn })
                     ->update( { account_urn => undef });

        my $customer = Test::XTracker::Data->create_dbic_customer(
                         { channel_id => $channel->id } );

        note 'Customer: ' . $customer->id;

        # Update to link to Seaview test account
        $customer->update({ account_urn => $test_account_urn});

        # Send a seaview notification to the consumer we're testing
        my $result = $self->{amq}->request(
            $self->{consumer},
            $self->{queue},
            { "verb" => "update",
              "object" => { "id" => $test_account_urn },
              "actor" => { "client" => "test-client", "userName" => "test-user" },
              "published" => "1970-01-01T00:00:00.000Z",
            },
            { type => 'CustomerUpdatePublished' }
        );

        # Consume the message
        ok($result->is_success, 'Notification message is consumed');

        # Check the data has been updated
        $customer->discard_changes;
        is( $customer->email, 'cv-test-486@net-a-porter.com', 'Email has been updated' );
        is( $customer->first_name, 'Test First Name 829', 'First name has been updated' );
        is( $customer->last_name, 'Test Last Name 339', 'Last name has been updated' );
        is( $customer->category->category, 'EIP',
            'Customer category has been updated');

        my $result2 = $self->{amq}->request(
            $self->{consumer},
            $self->{queue},
            { "verb" => "update",
              "object" => { "id" => $test_account_urn },
              "actor" => { "client" => "test-client", "userName" => "test-user" },
              "published" => "1970-01-01T00:00:00.000Z",
            },
            { type => 'CustomerUpdatePublished' }
        );

        # Consume the message
        ok($result2->is_success, 'Second notification message is consumed');

        # Check the data is unchanged
        $customer->discard_changes;
        is( $customer->email, 'cv-test-486@net-a-porter.com', 'Email is unchanged' );
        is( $customer->first_name, 'Test First Name 829', 'First name is unchanged' );
        is( $customer->last_name, 'Test Last Name 339', 'Last name is unchanged' );
        is( $customer->category->category, 'EIP', 'Customer category is unchanged');

    }
}

