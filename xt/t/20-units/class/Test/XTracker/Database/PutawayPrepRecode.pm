package Test::XTracker::Database::PutawayPrepRecode;

use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";
use Test::XTracker::RunCondition prl_phase => 'prl';

sub startup :Test(startup => 1) {
    my ($test) = @_;
    use_ok('XTracker::Database::PutawayPrep::RecodeBased');
    $test->{pp} = XTracker::Database::PutawayPrep::RecodeBased->new({ schema => $test->schema });
}

sub is_group_id_valid :Tests {
    my ($test) = @_;
    foreach my $id (qw/
        r123456
        r-123456
        r1
    /) {
        ok( $test->{pp}->is_group_id_valid($id), "ID $id is valid" );
    }

    foreach my $id (qw/
        p
        r
        p123456a
        pr123456
        1234p
        1234567890r
    /) {
        ok( ! $test->{pp}->is_group_id_valid($id), "ID $id is not valid" );
    }
}

