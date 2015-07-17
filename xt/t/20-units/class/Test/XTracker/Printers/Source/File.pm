package Test::XTracker::Printers::Source::File;

use NAP::policy 'test';

use parent "NAP::Test::Class";

use XTracker::Printers::Source::File;

=head1 NAME

Test::XTracker::Printers::Source::File

=cut

sub test_parse_multiple_valid : Tests() {
    my $self = shift;

    my $source = XTracker::Printers::Source::File->new(
        source_file => 't/data/printers/multiple_valid.conf'
    );
    $self->test_parse_source($source);
    is( @{$source->printers}, 4, 'found all expected printers in config' );
}

sub test_parse_single_valid : Tests() {
    my $self = shift;

    my $source = XTracker::Printers::Source::File->new(
        source_file => 't/data/printers/single_valid.conf'
    );
    $self->test_parse_source($source);
}

sub test_parse_invalid : Tests() {
    my $self = shift;

    my $source = XTracker::Printers::Source::File->new(
        source_file => 't/data/printers/invalid_section.conf'
    );
    isa_ok( $source->parse_source, 'ARRAY', 'parse_source return value');
    dies_ok( sub { $source->printers }, 'printers fail to build' );
}

sub test_inheritance : Tests() {
    my $self = shift;

    my $source = XTracker::Printers::Source::File->new(
        source_file => 't/data/printers/child.conf'
    );
    $self->test_parse_source($source);
}

sub test_parse_source {
    my ($self, $source) = @_;
    isa_ok( $source->parse_source, 'ARRAY', 'parse_source return value');
    isa_ok( $_, 'XT::Data::Printer' ) for @{$source->printers};
}
