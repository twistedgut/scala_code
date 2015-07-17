package Test::XTracker::Data::Locale;
use NAP::policy "tt";

use Test::XTracker::Data;
use NAP::Locale;

=head1 NAME

Test::XTracker::Data::Locale - Creates helper methods for Locale class

=cut

=head1 METHODS
=head2 get_locale_object

=cut
sub get_locale_object {
    my $self    = shift;
    my $locale  = shift;
    my $channel = shift;

    unless ( defined $locale ) {
        $locale = 'en_US';
    }

    # Get local channel if no channel passed in
    $channel //= Test::XTracker::Data->get_local_channel;

    # Create customer
    my $customer_id = Test::XTracker::Data->create_test_customer(
        channel_id => $channel->id,
    );

    my $schema = Test::XTracker::Data->get_schema();
    my $customer = $schema->resultset("Public::Customer")->find($customer_id);

    my $loc = NAP::Locale->new(
        locale   => $locale,
        customer => $customer,
    );

    return $loc;

}


1;
