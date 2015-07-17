package Test::XTracker::Schema::Result::Public::Country;
use NAP::policy 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XTracker::Schema::Result::Public::Country

=head1 DESCRIPTION

Test the L<XTracker::Schema::Result::Public::Country> class.

=cut

use Mock::Quick;

=head1 TESTS

=head2 startup

Test the L<XTracker::Schema::Result::Public::Country> class can be loaded OK.

=cut

sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    use_ok('XTracker::Schema::Result::Public::Country');

}

=head2 test_address_formatting_messages

We just need to test that this method is a wrapper for calling
C<address_formatting_messages_for_country> in L<XTracker::Config::Local>, by
mocking that method after it's been imported into the
L<XTracker::Schema::Result::Public::Country> namespace.

=cut

sub test_address_formatting_messages : Tests() {
    my $self = shift;

    my $data = {
        some_address_field      => 'Some Address Field',
        another_address_field   => 'Another Address Field',
    };

    my $config_local = qtakeover('XTracker::Schema::Result::Public::Country');
    $config_local->override( address_formatting_messages_for_country =>
        sub { return $data } );

    my $result = $self->schema->resultset('Public::Country')
        ->first
        ->address_formatting_messages;

    cmp_deeply( $result, $data,
        'The method returns the result of address_formatting_messages_for_country' );

}
