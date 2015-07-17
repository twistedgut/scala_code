package Test::XTracker::Schema::ResultSet::Public::Location;
use NAP::policy "tt", qw/test class/;
BEGIN {
    extends 'NAP::Test::Class';
    with qw/Test::Role::WithSchema/;
};
use FindBin::libs;

sub test__get_cancelled_location :Tests() {
    my ($self) = @_;

    my $location_row = $self->schema
        ->resultset("Public::Location")->get_cancelled_location;

    ok($location_row, "Got Cancelled Location row");
    like(
        $location_row->location,
        qr/Cancelled/,
        "   and the location looks alright",
    );
}

