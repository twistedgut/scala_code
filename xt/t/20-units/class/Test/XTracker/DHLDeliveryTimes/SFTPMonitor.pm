package Test::XTracker::DHLDeliveryTimes::SFTPMonitor;

use FindBin::libs;

use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

use Test::XTracker::Data;
use Test::MockModule;
use Net::SFTP::Attributes;
use XTracker::Config::Local 'config_var';
use File::Spec::Functions 'catfile';

sub startup : Tests(startup) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{dhl_rs} = $self->{schema}->resultset('Public::DHLDeliveryFile');

}

sub setup : Tests(setup) {
    my $self = shift;
    $self->SUPER::setup;
    $self->{dhl_rs}->search()->delete();
}

sub check_directory_test :Tests() {
    my $self = shift;

    my $test_data = {
        '.'  => 1,
        '..' => 2,
        'a'  => 3,
        'b'  => 4,
        'c'  => 5
    };

    my $mock_sftp = Test::MockModule->new('Net::SFTP');

    # we mock this internal function to prevent Net::SFTP connecting to
    # the live server during tests
    $mock_sftp->mock('init', sub { return shift });

    $mock_sftp->mock('ls', sub {
        my ($self, $directory, $callback) = @_;

        foreach my $filename (keys %$test_data) {
            my $mock_fake_attr = Test::MockModule->new('Net::SFTP::Attributes');
            $mock_fake_attr->mock('mtime', sub { return $test_data->{$filename}; });

            my $fake_attr = Net::SFTP::Attributes->new();

            $callback->({ filename => $filename, a => $fake_attr });
        }
    });

    my $calls = 0;
    my $mock_check_file = Test::MockModule->new('XTracker::DHLDeliveryTimes::SFTPMonitor');
    $mock_check_file->mock('check_file', sub {
        my ($self, $filename, $mtime_epoch) = @_;

        ok(exists($test_data->{$filename}), "check_file invoked with new data: $filename");
        is($test_data->{$filename}, $mtime_epoch, "check_file passed correct mtime_epoch (filename=$filename)");
        $calls++;
    });

    # this starts the test now everything is mocked
    my $sftp_monitor = XTracker::DHLDeliveryTimes::SFTPMonitor->new();
    $sftp_monitor->check_directory();

    is($calls, 3, 'check_file invoked 3 times (. and .. filenames ignored)');
}

sub check_file_inserts_new_records :Tests() {
    my $self = shift;
    my $dhl_rs = $self->{dhl_rs};

    my $sftp_monitor = XTracker::DHLDeliveryTimes::SFTPMonitor->new();
    $sftp_monitor->check_file('test_1', 54);

    my $result = $dhl_rs->find({ filename => 'test_1' });
    ok($result, 'new files detected get written into the database');
    is($result->processed, 0, 'new files are unproccessed');
    is($result->failures, 0, 'new files havent failed');
    is($result->remote_modification_epoch, 54, 'remote epoch stored');

}

sub check_file_updates_for_mtime_changes :Tests() {
    my $self = shift;
    my $dhl_rs = $self->{dhl_rs};

    my $sftp_monitor = XTracker::DHLDeliveryTimes::SFTPMonitor->new();
    $sftp_monitor->check_file('test_2', 54);

    my $result = $dhl_rs->find({ filename => 'test_2' });
    $result->mark_as_processed_ok();
    $result->discard_changes;

    ok($result->processed, 'File marked as completed');

    # recheck file with a different epoch!
    $sftp_monitor->check_file('test_2', 76);

    # check it needs processing again
    $result->discard_changes;
    is($result->processed, 0, 'File marked to be reprocessed');

}

sub check_file_ignores_files_already_processed :Tests() {
    my $self = shift;
    my $dhl_rs = $self->{dhl_rs};

    my $sftp_monitor = XTracker::DHLDeliveryTimes::SFTPMonitor->new();
    $sftp_monitor->check_file('test_3', 54);

    my $result = $dhl_rs->find({ filename => 'test_3' });
    $result->mark_as_processed_ok();
    $result->discard_changes;

    ok($result->processed, 'File marked as completed');

    # recheck file with the same epoch!
    $sftp_monitor->check_file('test_3', 54);

    # check it needs processing again
    $result->discard_changes;
    ok($result->processed, 'File not marked to be reprocessed again');
}

sub check_get_filesize_works :Tests() {
    my $self = shift;
    my $dhl_rs = $self->{dhl_rs};

    my $mock_sftp = Test::MockModule->new('Net::SFTP');

    # we mock this internal function to prevent Net::SFTP connecting to
    # the live server during tests
    $mock_sftp->mock('init', sub { return shift });

    $mock_sftp->mock('ls', sub {
        my ($self, $directory, $callback) = @_;

        my $mock_fake_attr = Test::MockModule->new('Net::SFTP::Attributes');
        $mock_fake_attr->mock('size', sub { return 12345 });

        my $fake_attr = Net::SFTP::Attributes->new();

        $callback->({ filename => 'test_4', a => $fake_attr });

    });

    my $sftp_monitor = XTracker::DHLDeliveryTimes::SFTPMonitor->new();
    $sftp_monitor->check_file('test_4', 542);

    my $dhl_delivery_file = $dhl_rs->find({ filename => 'test_4' });

    my $file_size = $sftp_monitor->get_filesize($dhl_delivery_file);
    is($file_size, 12345, 'get_filesize returns the correct value');

}

sub check_download_works :Tests() {
    my $self = shift;
    my $dhl_rs = $self->{dhl_rs};
    my $directory   = config_var('DHLDeliverySFTPServer', 'directory');

    my $mock_sftp = Test::MockModule->new('Net::SFTP');

    # we mock this internal function to prevent Net::SFTP connecting to
    # the live server during tests
    $mock_sftp->mock('init', sub { return shift });

    $mock_sftp->mock('ls', sub {
        my ($self, $directory, $callback) = @_;

        my $mock_fake_attr = Test::MockModule->new('Net::SFTP::Attributes');
        $mock_fake_attr->mock('size', sub { return 12345 });

        my $fake_attr = Net::SFTP::Attributes->new();

        $callback->({ filename => 'test_5', a => $fake_attr });

    });

    my $calls = 0;
    $mock_sftp->mock('get', sub {
        my ($self, $server_filename, $abs_local_file) = @_;

        $calls++;

        is ($server_filename, catfile($directory, 'test_5'), 'correct download location specified');
        return $server_filename;
    });

    my $sftp_monitor = XTracker::DHLDeliveryTimes::SFTPMonitor->new();
    $sftp_monitor->check_file('test_5', 542);

    my $dhl_delivery_file = $dhl_rs->find({ filename => 'test_5' });
    my $result = $sftp_monitor->download_file($dhl_delivery_file);

    is($result, catfile($directory, 'test_5'), 'File download works');
    is($calls, 1, 'SFTP download function was invoked');
}

