package XT::Data::Fulfilment::InductToPacking::Question;
use NAP::policy "tt", "class";

=head1 NAME

XT::Data::Fulfilment::InductToPacking::Question - A User question and valid answers

=cut

use NAP::XT::Exception::Internal;


has is_container_in_cage => (
    is      => "rw",
    isa     => "Bool",
    default => 0,
);

has is_multi_tote => (
    is      => "rw",
    isa     => "Bool",
    default => 0,
);

has answer => (
    is      => "rw",
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->maybe_default_answer();
    },
);
before answer => sub {
    my $self = shift;
    @_ or return; # Only validate setter
    $self->validate_answer(@_);
};

=head validate_answer($answer?) : | die

Die if $answer isn't one of the valid ->answers.

=cut

sub validate_answer {
    my ($self,$answer) = @_;
    defined($answer) or return; # "no answer" is a valid answer

    my $value_found = {
        map { $_->{value} => 1 }
        @{$self->answers}
    };

    $value_found->{ $answer } or NAP::XT::Exception::Internal->throw({
        message => "Invalid answer ($answer)",
    });
}

=head2 answers() : $answers

Return array ref with hashrefs (keys: value, text, is_default), which
are the possible answers to the question "Can this Tote be conveyed?".

This depends on ->is_multi_tote and ->is_container_in_cage.

=cut

sub answers {
    my $self = shift;

    my $yes = {
        value      => "yes",
        text       => "Yes - all items fit in tote",
        is_default => 1,
    };

    my @maybe_no_all_totes_not_present;
    if($self->is_multi_tote) {
        @maybe_no_all_totes_not_present = {
            value      => "no_all_totes_not_present",
            text       => "No - all totes not present",
            is_default => 0,
        };

        $yes->{text} .= ", all totes present";
    }

    $self->is_container_in_cage or return [
        $yes,
        {
            value      => "no_over_height",
            text       => "No - over height items present",
            is_default => 0,
        },
        @maybe_no_all_totes_not_present,
    ];

    return [
        {
            value      => "no_caged_items",
            text       => "No - contains caged items",
            is_default => 1,
        },
        @maybe_no_all_totes_not_present,
    ];
}

=head2 maybe_default_answer() : $answer | undef

If there is only one answer, return that ->{value}, else return undef.

=cut

sub maybe_default_answer {
    my $self = shift;
    my $answers = $self->answers;
    @$answers == 1 or return undef;
    return $answers->[0]->{value};
}

=head2 should_be_inducted_at_all() : Bool

Return true if the user has answered, and it's not a deal breaker
(i.e. that there are totes still remaining to be picked), meaning that
yes this tote should be inducted in some way.

Otherwise return false.

=cut

sub should_be_inducted_at_all {
    my $self = shift;
    my $answer = $self->answer or return 0;

    return 0 if $answer eq "no_all_totes_not_present";
    return 1;
}

=head2 can_be_conveyed() : Bool

Return true if the user has answered that the tote can be conveyed,
else false.

=cut

sub can_be_conveyed {
    my $self = shift;
    my $answer = $self->answer // "";
    $answer =~ /^yes/ or return 0;
    return 1;
}
