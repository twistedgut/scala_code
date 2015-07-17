package Test::XT::Data::Fulfilment::InductToPacking::Question;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { extends "NAP::Test::Class" }

use XT::Data::Fulfilment::InductToPacking::Question;

sub basic : Tests() {
    my $self = shift;
    my $question = XT::Data::Fulfilment::InductToPacking::Question->new();

}

sub answers__is_not_in_cage : Tests() {
    my $self = shift;
    my $question = XT::Data::Fulfilment::InductToPacking::Question->new({
        is_container_in_cage => 0,
    });
    eq_or_diff(
        $question->answers,
        [
            {
                value      => "yes",
                text       => "Yes - all items fit in tote",
                is_default => 1,
            },
            {
                value      => "no_over_height",
                text       => "No - over height items present",
                is_default => 0,
            },
        ],
        "Not in cage, no multi tote",
    );
    is(
        $question->maybe_default_answer,
        undef,
        "    and there are multiple choises, no default answer",
    );

    $question->is_multi_tote(1);
    eq_or_diff(
        $question->answers,
        [
            {
                value      => "yes",
                text       => "Yes - all items fit in tote, all totes present",
                is_default => 1,
            },
            {
                value      => "no_over_height",
                text       => "No - over height items present",
                is_default => 0,
            },
            {
                value      => "no_all_totes_not_present",
                text       => "No - all totes not present",
                is_default => 0,
            },
        ],
        "Not in cage, multi tote",
    );
    is(
        $question->maybe_default_answer,
        undef,
        "    and there are multiple choises, no default answer",
    );
}

sub answers__is_in_cage : Tests() {
    my $self = shift;
    my $question = XT::Data::Fulfilment::InductToPacking::Question->new({
        is_container_in_cage => 1,
    });
    eq_or_diff(
        $question->answers,
        [
            {
                value      => "no_caged_items",
                text       => "No - contains caged items",
                is_default => 1,
            },
        ],
        "In cage, no multi tote",
    );
    is(
        $question->maybe_default_answer,
        "no_caged_items",
        "   and there is a single choise, there is a default answer",
    );

    $question->is_multi_tote(1);
    eq_or_diff(
        $question->answers,
        [
            {
                value      => "no_caged_items",
                text       => "No - contains caged items",
                is_default => 1,
            },
            {
                value      => "no_all_totes_not_present",
                text       => "No - all totes not present",
                is_default => 0,
            },
        ],
        "In cage, multi tote",
    );
    is(
        $question->maybe_default_answer,
        undef,
        "    and there are multiple choises, no default answer",
    );
}

sub validate_answer : Tests() {
    my $self = shift;
    my $question = XT::Data::Fulfilment::InductToPacking::Question->new({
        is_container_in_cage => 0,
    });

    note "Validation itself";
    throws_ok(
        sub { $question->validate_answer("THIS IS INVALID") },
        qr/\QInternal error: Invalid answer (THIS IS INVALID)/,
        "Completely Invalid answer dies ok",
    );
    throws_ok(
        sub { $question->validate_answer("no_all_totes_not_present") },
        qr/\QInternal error: Invalid answer (no_all_totes_not_present)/,
        "Sometimes valid, but currently invalid answer dies ok",
    );
    lives_ok(
        sub { $question->validate_answer("yes") },
        "Valid answer lives ok",
    );

    note "Setter";
    throws_ok(
        sub { $question->answer("THIS IS INVALID") },
        qr/\QInternal error: Invalid answer (THIS IS INVALID)/,
        "Setting answer to invalid answer dies ok",
    );
    lives_ok(
        sub { $question->answer("yes") },
        "Valid answer lives ok",
    );
    is($question->answer(), "yes", "    and the setter works");

}


