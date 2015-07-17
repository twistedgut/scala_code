package XTracker::Script::Feature::Verbose;

=head1 NAME

XTracker::Script::Feature::Verbose - provides "verbose" mode.

=head1 DESCRIPTION

This role provides consumer with "verbose" mode and "inform" method that depending on
value of "verbose" write or do not to the STDOUT.

=head1 SYNOPSIS

    package Foo;

    use NAP::policy "tt", qw/class/;

    with 'XTracker::Script::Feature::Verbose';


    package Bar;

    my $report = Foo->new({verbose => 0});

    # does not come to STDOUT
    $report->inform('Hello world!');

    $report->verbose(1);

    # goes to STDOUT
    $report->inform('Hello tere!');

=cut

use NAP::policy "tt", qw/role/;

=head1 ATTRIBUTES

=head2 verbose

Flag that determines if user is going to be informed about work progress.

By default this is ON.

=cut

has 'verbose' => (
    is      => 'rw',
    isa     => 'Int', # Used by e.g. MooseX::Getopt
    default => 1,
);

=head1 METHODS

=head2 inform(@print_arguments) :

If called in verbose mode, prints passed arguments to standard output.
Otherwise - does nothing.

=cut

sub inform {
    my ($self,@message) = @_;

    if ($self->verbose and @message) {
        print STDOUT @message;
    }

    return;
}
