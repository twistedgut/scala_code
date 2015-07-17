package NAP::Carp;

use strict;
use warnings;

# NOTE: Not using NAP::policy because it contains "use Carp",
#       which exports 'confess' by default, which would clash with our confess

use Carp qw/longmess/;
use List::AllUtils 'any';

=head1 NAME

NAP::Carp

=head1 DESCRIPTION

Drop-in replacement for Carp::cluck and Carp::confess, which filters out lines
you don't care about from the stack traces.

Methods in any module which starts with one of the following are currently
filtered out:

    * Plack::
    * Starman::
    * Net::Server::
    * Try::Tiny
    * DBIx::Class::Storage::BlockRunner
    * Context::Preserve
    * eval
    * Test::Class::runtests
    * Test::Class::_run_method
    * NAP::Test::Class::INIT

Feel free to add your own, especially third party.

=head1 SYNOPSIS

    use NAP::Carp qw/cluck confess/;
    cluck("something happened which we'll want to investigate later");
    confess("something unexpected happened and we can't continue");

=head1 SEE ALSO

Explanation of technical decisions in Jira WHM-4312

=cut

use Sub::Exporter -setup => {
  exports => [
    qw(cluck confess),
  ],
};

our @what_to_remove = (
    # Production
    'Plack::',
    'Starman::Server::',
    'Net::Server::',
    'Try::Tiny',
    'DBIx::Class::Storage::BlockRunner',
    'Context::Preserve',
    'eval',
    # Tests
    'Test::Class::runtests',
    'Test::Class::_run_method',
    'NAP::Test::Class::INIT',
);

# Compile regex to avoid looping through @what_to_remove
my $what_to_remove_rx = join ')|(?:',@what_to_remove;
$what_to_remove_rx = qr{(?:$what_to_remove_rx)};

sub cluck {
    my ($user_message) = @_;
    my $trace = longmess($user_message);
    warn _filtered($trace);
}

sub confess {
    my ($user_message) = @_;
    my $trace = longmess($user_message);
    die _filtered($trace);
}

sub _filtered {
    my ($trace) = @_;
    my @rows = split(/\n/, $trace);
    my @filtered_rows = grep { $_ !~ $what_to_remove_rx } @rows;
    # Include a note so the user knows they're not seeing the full thing
    $filtered_rows[0] =~ s/ at (\S+ line \d+\.)/ at (abridged) $1/;
    # Return the filtered stacktrace
    return join("\n", @filtered_rows);
}

1;
