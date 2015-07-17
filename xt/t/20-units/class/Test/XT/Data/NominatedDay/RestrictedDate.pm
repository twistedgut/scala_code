package Test::XT::Data::NominatedDay::RestrictedDate;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "Test::Role::NominatedDay::WithRestrictedDates";
};

use XT::Data::NominatedDay::RestrictedDate;
use XT::Data::DateStamp;

sub create_or_update_with : Tests() {
    my $self = shift;

    $self->delete_all_restrictions();

    my $begin_date = "2012-02-05";
    my $begin_datestamp = XT::Data::DateStamp->from_string($begin_date);

    my $restricted_date = $self->restricted_date({
        date => $begin_datestamp,
    });

    my ($date_restriction_row, $date_restriction_log_row)
        = $restricted_date->create_or_update_with(
            $self->operator,
            "Change Reason",
            1, # is_restricted
        );
    $_->discard_changes for($date_restriction_row, $date_restriction_log_row);

    ok($date_restriction_row, "Got restriction dbic row");
    is($date_restriction_row->is_restricted, 1, "  is_restricted ok");
    is($date_restriction_row->date->ymd, $begin_date, "  date ok");
    is(
        $date_restriction_row->shipping_charge_id,
        $restricted_date->shipping_charge_id,
        "  shipping_charge_id ok",
    );
    is(
        $date_restriction_row->restriction_type->token,
        $restricted_date->restriction_type,
        "  restriction_type ok",
    );


    note "Save same date again";
    my ($date_restriction_row2, $date_restriction_log_row2)
        = $restricted_date->create_or_update_with(
            $self->operator,
            "Change Reason 2",
            0, # is_restricted
        );
    $_->discard_changes for($date_restriction_row2, $date_restriction_log_row2);
    is(
        $date_restriction_row->id,
        $date_restriction_row2->id,
        "Same row id, i.e. it was updated"
    );
    is($date_restriction_row2->is_restricted, 0, "  is_restricted ok");
}

1;
