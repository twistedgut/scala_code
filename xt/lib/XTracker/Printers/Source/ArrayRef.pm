package XTracker::Printers::Source::ArrayRef;

use NAP::policy qw/tt class/;

extends 'XTracker::Printers::Source';

=head1 NAME

XTracker::Printers::Source::ArrayRef - ArrayRef source for printers

=head1 DESCRIPTION

Pass this class an arrayref of hashrefs with the printer information. Useful
for testing.

=head1 SYNOPSIS

use XTracker::Printers::Source::ArrayRef;

my $xpp = XTracker::Printers::Source::ArrayRef->new(
    source => [{
        lp_name  => 'lp_name',
        location => 'location',
        section  => 'packing',
        type     => 'document',
    }],
);

=cut

has source => (
    is => 'ro',
    isa => 'ArrayRef[HashRef]',
    required => 1,
);

=head1 METHODS

=head2 parse_source

A method to return what was passed for C<source> in object creation

=cut

sub parse_source { shift->source; }
