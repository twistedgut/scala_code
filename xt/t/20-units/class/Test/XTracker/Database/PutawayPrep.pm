package Test::XTracker::Database::PutawayPrep;

use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";
use Test::XTracker::RunCondition prl_phase => 'prl';

sub startup :Test(startup => 1) {
    my ($test) = @_;
    use_ok('XTracker::Database::PutawayPrep');
    $test->{pp} = XTracker::Database::PutawayPrep->new({ schema => $test->schema });
}

sub is_group_id_valid :Tests {
    my ($test) = @_;
    foreach my $id (qw/
        p123456
        p-123456
        p1
        1234
        1234567890
    /) {
        ok( $test->{pp}->is_group_id_valid($id), "ID $id is valid" );
    }

    foreach my $id (qw/
        p
        p123456a
        pr123456
        1234p
        1234567890r
    /) {
        ok( ! $test->{pp}->is_group_id_valid($id), "ID $id is not valid" );
    }
}

