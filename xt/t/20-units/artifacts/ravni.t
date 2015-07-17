#!/usr/bin/env perl

# Simple acceptance tests for Test::XTracker::Artifacts::RAVNI

use NAP::policy "tt", 'test';
use FindBin::libs;
use File::Temp qw/tempdir/;
use String::Random qw(random_regex);

use Test::Differences;
use JSON;

use_ok('Test::XTracker::Artifacts::RAVNI');

my $dir = tempdir( CLEANUP => 1 );
my $receipt_directory = Test::XTracker::Artifacts::RAVNI->new(
    read_directory => $dir
);

# Basic test of a new file found
{
    note "TEST: Basic test of a new file found";
    my $file_data = create_file();

    my (@files) = $receipt_directory->new_files();
    is( scalar @files, 1, "One new file found" );

    check_file( $files[0], $file_data );
}

# Wait for new files ... found required number
{
    note "TEST: Wait for new files - required files found";
    my (@files_data) = sort { $a->{'filename'} cmp $b->{'filename'} }
        (create_file(), create_file());
    my (@files) = sort { $a->filename cmp $b->filename }
        $receipt_directory->wait_for_new_files( files => 2 );

    is( scalar @files, 2, "Two new files found" );

    check_file( $files[0], $files_data[0] );
    check_file( $files[1], $files_data[1] );
}

# Wait for new files ... time out
{
    note "TEST: Wait for new files - time out";
    my $file_data = create_file();

    my (@files) = $receipt_directory->wait_for_new_files(
        files => 2, seconds => 1, no_die => 1, no_time_warning => 1 );
    is( scalar @files, 1, "One new file found" );

    check_file( $files[0], $file_data );
}

done_testing;

sub check_file {
    my ( $rec, $ref ) = @_;

    # Check it's the right type
    ok( $rec->isa('Test::XTracker::Artifacts::RAVNI::Receipt'),
        'Received item isa Test::XTracker::Artifacts::RAVNI::Receipt' );

    # Check the data is correct
    is( $rec->path,    $ref->{'path'},    "Destination path correct"   );
    is_deeply( $rec->payload, $ref->{'payload'}, "Payload correct (as JSON)"  );
    eq_or_diff( $rec->payload_parsed, $ref->{'payload_parsed'},
        "Payload correct (when parsed)" );
}

sub create_file {
    my $file_suffix = shift || '_wms';
    my $filename_atom = '_test_' . random_regex('[a-z]{6}') . $file_suffix;

    my $payload_parsed = {
        test => random_regex('[a-z]{6}')
    };
    my $path    = '/queue/'.random_regex('[a-z]{6}');
    my $headers = { type => 'foo', destination => $path };
    my $payload = {
        destination => $path,
        body => $payload_parsed,
        headers => $headers,
        response_status => 200,
    };
    my $filename = $dir . '/' . $filename_atom;

    open( my $TEST_FILE, '>', $filename ) || die "Can't open [$filename]: $!";
    my $frame = Net::Stomp::Frame->new({
        command => 'MESSAGE',
        headers => $headers,
        body => NAP::Messaging::Serialiser->serialise($payload),
    });
    print $TEST_FILE $frame->as_string;
    close $TEST_FILE;

    note $filename;
    return {
        filename       => $filename,
        filename_atom  => $filename_atom,
        payload        => $payload,
        payload_parsed => $payload_parsed,
        path           => $path,
    };
}
