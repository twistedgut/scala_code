
package Test::XT::Net::XTrackerAPI::Request::NominatedDay;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "Test::Role::NominatedDay::WithRestrictedDates";
};
# Only because of test data, the funcionality is general across DCs.
use Test::XTracker::RunCondition(
    dc => "DC1",
);


use XT::Net::XTrackerAPI::Request::NominatedDay;
use Test::XTracker::Data;

=head1 CLASS METHODS

=head1 METHODS

=cut

# sub setup : Test(setup) {
#     my $self = shift;
#     $self->SUPER::setup();
#     $self->{channel} = Test::XTracker::Data->channel_for_mrp();
# }

sub type_date_shipping_charge_ids : Tests() {
    my $self = shift;

    note "Create some dates and restrictions";
    $self->delete_all_restrictions();
    my $restrictions = [
        # composite groups ok, same sku across channels
        { date => "1998-10-10", description => "Premier Daytime",            channel => "nap" },
        { date => "1998-10-10", description => "Premier Daytime",            channel => "mrp" },
        { date => "1998-10-10", description => "Premier Evening",            channel => "nap" },
        { date => "1998-10-10", description => "UK Express - Nominated Day", channel => "mrp" },
          # ^^^ Add new ShippingCharges here
        { date => "1998-10-10", all => 1 }, # Since all ShippingCharges are present, add an "all" entry

        { date => "1998-11-11", description => "Premier Daytime", channel => "nap" },

        # same composite sku, to check memoize
        { date => "2001-10-10", description => "Premier Daytime", channel => "nap" },
        { date => "2001-10-10", description => "Premier Daytime", channel => "mrp" },
    ];
    my %expected_date;
    for my $restriction (@$restrictions) {
        if($restriction->{all}) {
            push( @{ $expected_date{ $restriction->{date} }->{all} }, "all");
            next;
        }

        my $channel_id = Test::XTracker::Data->channel_for_business(
            name=> $restriction->{channel},
        )->id;
        my $shipping_charge = $self->rs("ShippingCharge")->search({
            channel_id  => $channel_id,
            description => $restriction->{description},
        })->first;
        push(
            @{$expected_date{ $restriction->{date} }
                  ->{ $restriction->{description} }},
            $shipping_charge->id
        );

        $self->restricted_date({
            date               => $restriction->{date},
            shipping_charge_id => $shipping_charge->id
        })->restrict($self->operator, "Test Change Reason");
    }


    my $request = XT::Net::XTrackerAPI::Request::NominatedDay->new({
        operator => $self->operator,
    });
    my $type_date = $request->type_date_shipping_charge_ids({
        begin_date => "1988-01-01",
        end_date   => "2019-12-19",
    });
    # This will break as new Nominated Day ShippingCharges are added:
    # the "all" key will appear for the date 1998-10-10 when all
    # ShippingCharges are in the list.
    #
    # If the test just broke, there's another ShippingCharge that's
    # now missing for the list to be complete.
    #
    # Fix the test by adding the new ShippingCharge in the test data
    # $restrictions above.
    eq_or_diff(
        $type_date,
        {
          'delivery' => {
              # e.g.
              # '1998-11-11' => [
              #     '61',
              # ],
              # '1998-10-10' => [
              #     '61-63',
              #     '62',
              # ],
              map {
                  my $date = $_;
                  (
                      $date => [
                          map {
                              my $description = $_;
                              join("-", @{$expected_date{$date}{$description}})
                          }
                          sort keys %{$expected_date{$_}}
                      ]
                  )
              }
              keys %expected_date
          },
        },
        "type_date_shipping_charge_ids look ok",
    );
}

sub test_POST_shipping_delivery_date_restriction__access : Tests() {
    my $self = shift;

    my $request = XT::Net::XTrackerAPI::Request::NominatedDay->new({
        operator => $self->operator,
    });

    my $make_request_sub = sub {
        $request->POST_shipping_delivery_date_restriction({
            begin_date                => "2010-10-10",
            end_date                  => "2010-10-10",
            change_reason             => "Change",
            original_restricted_dates => "{ }",
            restricted_dates          => "{ }",
        });
    };
    throws_ok(
        sub { $make_request_sub->() },
        qr/^Unauthorized: Updating Delivery Date Restrictions requires 'manager' level access\./,
        "Authorization check fails because the user is a normal human being",
    );

    $request->authorization->is_manager(1);
    lives_ok(
        sub { $make_request_sub->() },
        "Authorization check passes because the user is an outright superhero",
    );

}

