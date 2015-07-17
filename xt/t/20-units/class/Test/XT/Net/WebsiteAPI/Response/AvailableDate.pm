
package Test::XT::Net::WebsiteAPI::Response::AvailableDate;
use FindBin::libs;
use parent "NAP::Test::Class";
use NAP::policy "tt", 'test';

use XT::Net::WebsiteAPI::Response::AvailableDate;
use XT::Data::DateStamp;

sub test_new_coerce : Tests() {
    my $self = shift;
    isa_ok(
        my $date = XT::Net::WebsiteAPI::Response::AvailableDate->new({
            delivery_date => "2011-02-23",
            dispatch_date => "2011-02-22",
        }),
        "XT::Net::WebsiteAPI::Response::AvailableDate",
    );
    isa_ok($date->delivery_date, "XT::Data::DateStamp", "delivery_date is a XT::Data::DateStamp");
    isa_ok($date->dispatch_date, "XT::Data::DateStamp", "dispatch_date is a XT::Data::DateStamp");

    is($date->delivery_date->ymd, "2011-02-23", "DateStamp is correct");
}

sub test_as_data : Tests() {
    my $self = shift;

    my $date = XT::Net::WebsiteAPI::Response::AvailableDate->new({
        delivery_date => "2011-02-23",
        dispatch_date => "2011-02-22",
    });

    eq_or_diff(
        $date->as_data,
        {
            delivery_date       => "2011-02-23",
            delivery_date_human => "23/02/2011",
            dispatch_date       => "2011-02-22",
            dispatch_date_human => "22/02/2011",
        },
        "as_data looks ok",
    );

    $date = XT::Net::WebsiteAPI::Response::AvailableDate->new({
        delivery_date => "2011-02-23",
    });

    eq_or_diff(
        $date->as_data,
        {
            delivery_date       => "2011-02-23",
            delivery_date_human => "23/02/2011",
            dispatch_date       => undef,
            dispatch_date_human => undef,
        },
        "as_data looks ok with undef values",
    );

}
