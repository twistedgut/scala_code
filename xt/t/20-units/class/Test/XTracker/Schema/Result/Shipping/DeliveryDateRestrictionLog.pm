
package Test::XTracker::Schema::Result::Shipping::DeliveryDateRestrictionLog;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "Test::Role::NominatedDay::WithRestrictedDates";
};

use XTracker::Schema::Result::Shipping::DeliveryDateRestrictionLog;

sub as_data : Tests() {
    my $self = shift;

    $self->delete_all_restrictions();

    my $date = "2012-02-01";
    my $restricted_date = $self->restricted_date({ date => $date });
    $restricted_date->restrict($self->operator, "Near warehouse capacity");
    ok(
        my $restriction_log_row = $self->restriction_log_rs->first(),
        "Got log row",
    );
    my $restriction_log_data = $restriction_log_row->as_data();
    note "Test the as_data attributes";
    $self->test_hashref_values(
        $restriction_log_data,
        {
            change_reason    => "Near warehouse capacity",
            change_time      => qr/\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d/,
            is_restricted    => "Yes",
            operator         => "Application",
            restricted_date  => $date,
            restriction_type => "Delivery",
            shipping_charge  => qr/\w+-[\w,\- ]+-\d+-\d+/, # e.g. "NAP-Premier Daytime-9000210-001",
        },
    );

}

1;
