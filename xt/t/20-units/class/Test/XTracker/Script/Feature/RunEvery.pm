package Test::XTracker::Script::Feature::RunEvery;

use NAP::policy "tt", 'test';

use XTracker::Script;

use parent 'NAP::Test::Class';

sub startup : Test(startup => 3) {
    my ( $self ) = @_;

    use XTracker::Script;
    use XTracker::Script::Feature::RunEvery;
    use Moose::Meta::Class;

    my $feature_role = 'XTracker::Script::Feature::RunEvery';

    ok my $mop_class = Moose::Meta::Class->create('Tester::RunEvery', superclasses => ['XTracker::Script']), 'should create feature test metaclass';
    ok $mop_class->add_method( invoke => sub { 1 } ), 'should override default invoke sub';
    ok $feature_role->meta->apply( $mop_class ), 'should apply RunEvery role';

    $self->{tester_class} = $mop_class;
}

sub setup : Test(setup) {
    my ( $self ) = @_;
    # create a fresh script object for each test
    $self->{script} = $self->{tester_class}->new_object;
    $self->SUPER::setup;
}

sub teardown : Test(teardown) {
    my ( $self ) = @_;
    $self->SUPER::teardown;
}

sub test_feature_basics : Tests(2) {
    my ( $self ) = @_;

    ok my $script = $self->{script}, 'should instantiate script with RunEvery feature';
    is $script->interval, 1, 'default interval should be 1 minute';
}

sub test_runevery_behaviour : Tests(30) {
    my ( $self ) = @_;

    $self->_test_interval( 3 );
    $self->_test_interval( 4 );
    $self->_test_interval( 7 );
}

sub _test_interval {
    my ( $self, $interval ) = @_;

    note "Testing EveryRun behaviour for interval=$interval";
    my $fake_script_class = $self->{tester_class};

    # get epoch time at a minute boundary
    my $base_epoch_minute = int(time/60);
    # adjust epoch time backwards to an exact script invocation time
    $base_epoch_minute -= ($base_epoch_minute/60) % $interval;

    # fake elapsed epoch time
    my $epoch_elapsed_minutes;

    # override script epoch_time
    $fake_script_class->add_method(epoch_time => sub { ($base_epoch_minute + $epoch_elapsed_minutes) * 60 });

    for my $invocation_minute (0..9) {
        $epoch_elapsed_minutes = $invocation_minute;

        # check current minute to see if it should run or not
        my $should_fail = !!(($base_epoch_minute + $epoch_elapsed_minutes) % $interval);
        # instantiate new script with offset
        my $fake_script = $fake_script_class->new_object(
            interval => $interval,
        );
        my $message = sprintf('at BASE+%i minutes with interval=%i, script should %s', $epoch_elapsed_minutes, $interval, ($should_fail ? 'FAIL' : 'run'));
        is !!$fake_script->invoke(), !$should_fail, $message;
    }
}

1;
