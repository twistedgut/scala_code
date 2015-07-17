package Test::Timing;
use NAP::policy "tt", qw(class);

use Time::HiRes qw(time);

has description => (
    isa         => 'Str',
    is          => 'ro',
    default     => 'Timings',
    required    => 1,
);

has timing_list => (
    isa         => 'ArrayRef',
    is          => 'rw',
    default     => sub { [ { label => '000: Init', time => time() } ] },
    required    => 1,
);

has index => (
    isa         => 'Int',
    is          => 'rw',
    default     => 0,
    required    => 1,
);

no Moose;

sub add_timing {
    my ($self,$label) = @_;
    return unless $ENV{TEST_SHOWTIMINGS};

    push @{$self->timing_list}, {
        label   => sprintf('%03d: %s', $self->index($self->index+1), $label),
        time    => time(),
    }
}

sub dump_timings {
    my $self = shift;
    return unless $ENV{TEST_SHOWTIMINGS};
    my $timing_list = $self->timing_list;
    diag '== ' . $self->description . ' ==';
    diag sprintf('%-40s : %10.3fs', $timing_list->[0]{label}, 0);
    for my $i (1 .. $#$timing_list) {
        diag sprintf('%-40s : %10.3fs',
            $timing_list->[$i]{label},
            $timing_list->[$i]{time} - $timing_list->[$i-1]{time}
        );
    }
    return;
}
