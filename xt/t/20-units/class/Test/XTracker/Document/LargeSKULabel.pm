package Test::XTracker::Document::LargeSKULabel;

use NAP::policy qw/class test/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::Printers';
}

use XTracker::Document::LargeSKULabel;

=head1 NAME

Test::XTracker::Document::LargeSKULabel

=cut

sub test_basic : Tests {
    my $self = shift;

    my $expected_type = 'large_label';

    my $label = XTracker::Document::LargeSKULabel->new(
        $self->default_label_data
    );

    is( $label->printer_type, $expected_type,
        'large sku label uses correct printer type' );

    lives_ok( sub {
        $label->print_at_location($self->location_with_type($expected_type)->name);
    }, "didn't die printing label" );
}

sub default_label_data {
    my ($self, %args) = @_;
    return (
        colour   => ( $args{colour}   // 'MyColour' ),
        designer => ( $args{designer} // 'Designer' ),
        season   => ( $args{season}   // 'Season' ),
        size     => ( $args{size}     // 'MySize' ),
        sku      => ( $args{sku}      // '10000-100' ),
    );
}
