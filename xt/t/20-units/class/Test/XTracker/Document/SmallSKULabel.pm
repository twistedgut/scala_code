package Test::XTracker::Document::SmallSKULabel;

use NAP::policy qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
}

use XTracker::Document::SmallSKULabel;

=head1 NAME

Test::XTracker::Document::SmallSKULabel

=cut

sub test_basic : Tests {
    my $self = shift;

    my $size = 'MySize';
    my $sku = '10000-100';
    my $expected_type = 'small_label';

    my $label
        = XTracker::Document::SmallSKULabel->new( size => $size, sku => $sku );

    is( $label->printer_type, $expected_type,
        'small sku label uses correct printer type' );

    lives_ok( sub {
        $label->print_at_location($self->location_with_type($expected_type)->name);
    }, "didn't die printing label" );
}
