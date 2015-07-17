package Test::XTracker::Artifacts::Labels::MrPSticker;

=head1 NAME

Test::XTracker::Artifacts::Labels::MrPSticker

=head2 DESCRIPTION

Monitor the Mr P Sticker output (.txt) and return documents found

Extends C<Test::XTracker::Artifacts::Labels>, see there for usage.

=cut

use NAP::policy 'class';

extends 'Test::XTracker::Artifacts::Labels';

# Configuration

has '+filter_regex' => (
    required => 0,
    default => sub { qr/\.txt$/ },
);

1;
