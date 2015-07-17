package XTracker::Reporting::Shipping::AJAX::ShippingRestrictedDeliveryDate;
use NAP::policy "tt";

use XT::Net::XTrackerAPI::Server;

sub handler {
    my $apache_request = shift;
    return XT::Net::XTrackerAPI::Server->new->serve_request({
        apache_request      => $apache_request,
        request_class       => "XT::Net::XTrackerAPI::Request::NominatedDay",
        request_method_base => "shipping_delivery_date_restriction", # GET / POST
    });
}

1;