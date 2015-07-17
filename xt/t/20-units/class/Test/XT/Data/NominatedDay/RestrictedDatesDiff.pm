package Test::XT::Data::NominatedDay::RestrictedDatesDiff;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN {
    extends "NAP::Test::Class";
    with "Test::Role::NominatedDay::WithRestrictedDates";
}

use Storable qw/ dclone /;

use XT::Data::NominatedDay::RestrictedDatesDiff;
use Test::XTracker::MessageQueue;

use XTracker::Config::Local "config_var";
use XT::DC::Messaging::Producer::Shipping::DeliveryDateRestriction;


sub setup_diff {
    my ($self, $date_count) = @_;
    $date_count //= 9;

    my $begin_date = "2012-02-05";
    my $begin_datestamp = XT::Data::DateStamp->from_string($begin_date);

    my $current_dates = [
        map {
            $self->restricted_date({
                date => $begin_datestamp->clone->add(days => $_),
            });
        }
        (0..$date_count)
    ];
    my $end_date = $current_dates->[-1]->date . "";
    my $new_dates = dclone($current_dates);

    my $amq_message_factory = Test::XTracker::MessageQueue->new;
    my $restricted_dates_diff = XT::Data::NominatedDay::RestrictedDatesDiff->new({
        current_restricted_dates => $current_dates,
        new_restricted_dates     => $new_dates,
        begin_date               => $begin_date,
        end_date                 => $end_date,
        change_reason            => "Blah-blah blah",
        operator                 => $self->operator,
        msg_factory              => $amq_message_factory,
    });
    return ($restricted_dates_diff, $new_dates, $current_dates);
}

sub test_is_no_diff {
    my ($self, $restricted_dates_diff) = @_;
    eq_or_diff(
        $restricted_dates_diff->dates_to_restrict(),
        [ ],
        "dates_to_restrict is empty",
    );
    eq_or_diff(
        $restricted_dates_diff->dates_to_unrestrict(),
        [ ],
        "dates_to_unrestrict is empty",
    );
}

sub dates_to_restrict__empty__no_diff : Tests() {
    my $self = shift;
    my ($restricted_dates_diff, $new_dates) = $self->setup_diff(0);
    $self->test_is_no_diff($restricted_dates_diff);
}

sub dates_to_restrict__same__no_diff : Tests() {
    my $self = shift;
    my ($restricted_dates_diff, $new_dates) = $self->setup_diff(9);
    $self->test_is_no_diff($restricted_dates_diff);
}

sub setup_diff_with_added_deleted {
    my $self = shift;

    my ($restricted_dates_diff, $new_dates) = $self->setup_diff(9);
    my $deleted_date = pop(@$new_dates);
    my $added_dates = $restricted_dates_diff->sorted([
        map { $self->restricted_date({ date => $_ }) }
        ("1998-11-12", "1989-09-15", "2032-02-01")
    ]);
    push(@$new_dates, @$added_dates);

    return ($restricted_dates_diff, $added_dates, $deleted_date);
}

sub dates_to_restrict__add_delete__no_diff : Tests() {
    my $self = shift;

    my ($restricted_dates_diff, $added_dates, $deleted_date)
        = $self->setup_diff_with_added_deleted();

    eq_or_diff(
        $restricted_dates_diff->dates_to_restrict(),
        $added_dates,
        "dates_to_restrict contains the aded date",
    );
    eq_or_diff(
        $restricted_dates_diff->dates_to_unrestrict(),
        [ $deleted_date ],
        "dates_to_unrestrict contains the deleted date",
    );
}

sub test_restriction_and_log {
    my ($self, $restricted_date, $operation, $expected_id_restricted) = @_;

    note $restricted_date->date . " - $operation - restriction";
    my $restricted_row = $self->restriction_rs->search({
        date => $restricted_date->date,
    })->first;
    ok($restricted_row, "Found $operation row for (" . $restricted_date->date . ")");
    is(
        $restricted_row->shipping_charge_id => $restricted_date->shipping_charge_id,
        "    with the correct shipping_charge_id",
    );
    is(
        $restricted_row->restriction_type->token => $restricted_date->restriction_type,
        "    with the correct restriction_type",
    );
    is(
        $restricted_row->is_restricted => $expected_id_restricted,
        "    with the correct is_restricted ($expected_id_restricted, it's $operation-ed from being restricted)",
    );

    note ucfirst($operation) . " - restriction log";
    my $restricted_log_row = $self->restriction_log_rs->search({
        delivery_date_restriction_id => $restricted_row->id,
    })->first;
    ok($restricted_log_row, "Found $operation log row for (" . $restricted_date->date . ")");
    is(
        $restricted_log_row->new_is_restricted => $expected_id_restricted,
        "    with the correct new_is_restricted",
    );
    is(
        $restricted_log_row->operator_id => $self->operator_id,
        "    with the correct operator_id",
    );
    is(
        $restricted_log_row->change_reason => "Blah-blah blah",
        "    with the correct change_reason",
    );
}

sub save_to_database__saves_and_logs : Tests() {
    my $self = shift;

    my ($restricted_dates_diff, $added_dates, $deleted_date)
        = $self->setup_diff_with_added_deleted();

    $self->delete_all_restrictions();
    $restricted_dates_diff->save_to_database();
    is(
        scalar $self->restriction_rs->all,
        3 + 1,
        "Got restrictions for all changed dates",
    );
    is(
        scalar $self->restriction_log_rs->all,
        3 + 1,
        "Got restrictions log entries for all changed dates",
    );


    note "*** Test sample rows";
    note "** Test DELETE";
    $self->test_restriction_and_log($deleted_date, "Delete", 0);

    note "** Test ADD";
    for my $added_date (@$added_dates) {
        $self->test_restriction_and_log($added_date, "Add", 1);
    }
}

sub save_to_database__throws_db_exception : Tests() {
    my $self = shift;

    my ($restricted_dates_diff, $added_dates, $deleted_date)
        = $self->setup_diff_with_added_deleted();

    # Use this one because it's in the class under test, and just
    # inside the eval
    no warnings "redefine";
    local *XT::Data::NominatedDay::RestrictedDatesDiff::dates_to_restrict = sub {
        die("Fake dbi error\n");
    };
    throws_ok(
        sub { $restricted_dates_diff->save_to_database() },
        qr/^A Database error occurred, please contact Service Desk/,
        "The error is replace with a user friendly one",
    );
}

sub channel_rows_with_changes__empty : Tests() {
    my $self = shift;
    my ($restricted_dates_diff, $new_dates) = $self->setup_diff(0);
    eq_or_diff(
        $restricted_dates_diff->channel_rows_with_changes,
        [],
        "No diff: empty list of channels",
    );
}

sub channel_rows_with_changes__returns_correct_channels : Tests() {
    my $self = shift;
    my ($restricted_dates_diff, $added_dates, $deleted_date)
        = $self->setup_diff_with_added_deleted();
    eq_or_diff(
        [
            map { $_->name }
                @{$restricted_dates_diff->channel_rows_with_changes}
        ],
        [qw/ NET-A-PORTER.COM /],
        "Diff with dates: correct list of channels",
    );
}

sub publish_to_web_sites__sends_correct_messages : Tests() {
    my $self = shift;

    my ($restricted_dates_diff, $added_dates, $deleted_date)
        = $self->setup_diff_with_added_deleted();

    my $destination = config_var('Producer::Shipping::DeliveryDateRestriction','destination');
    my $amq = $restricted_dates_diff->msg_factory();

    $amq->clear_destination($destination);

    $restricted_dates_diff->publish_to_web_sites();

    my $channel_row = $restricted_dates_diff->dates_to_restrict->[0]->channel_row;

    $amq->assert_messages(
        {
            destination  => $destination,
            assert_body => superhashof({
                channel          => $channel_row->website_name,
                window           => {
                    begin_date => $restricted_dates_diff->begin_date . "",
                    end_date   => $restricted_dates_diff->end_date . "",
                },
                # restricted_dates => [], # Don't check this key, it's tested elsewhere
            }),
        },
        "Publish to web sites sends all messages",
    );
}

1;
