package Test::XTracker::Printers::Source::CUPS;

use NAP::policy "tt", 'test';

use parent "NAP::Test::Class";

use XTracker::Printers::Source::CUPS;

=head1 NAME

Test::XTracker::Printers::Source::CUPS

=cut

sub test_basic_parse : Tests() {
    my $self = shift;

    my $plugin = XTracker::Printers::Source::CUPS->new(
        source_file => 't/data/printers/cups/printers.conf'
    );
    lives_ok( sub { $plugin->parse_source }, 'file parsed successfully');
    is( @{$plugin->printers}, 2, 'two printers picked up' );
    isa_ok( $plugin->printers->[0], 'XT::Data::Printer' );
}
