package Test::NAP::Carrier::UPS;
use NAP::policy "tt", 'class';

extends 'NAP::Carrier::UPS';

=head1

 Test::NAP::Carrier::UPS - Library which extends NAP::Carrier::UPS

This is used to test the methods 'book_shipment_for_automation',
'shipping_confirm_request' & 'shipping_accept_request'
which are in NAP::Carrier::UPS which rely on the 'xml_request' method in XT::Net::UPS.
This will work in conjunction with Test::XT::Net::UPS.

=cut

use Test::XT::Net::UPS;

# rountine that replaces the one in NAP::Carrier::UPS
override '_build_net_ups' => sub {
    my $self = shift;

    # use the other test library to simulate responses
    return Test::XT::Net::UPS->new({
        simulate_response   => 'Success',
        config              => $self->config,
        shipment            => $self->shipment,
    });
};
