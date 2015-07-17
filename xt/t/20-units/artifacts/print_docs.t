#!/usr/bin/env perl

# Simple acceptance tests for Test::XTracker::PrintDocs.

use NAP::policy "tt", 'test';
use FindBin::libs;
use File::Temp qw/tempdir/;
use String::Random qw(random_regex);

use Test::Exception;
use Test::XTracker::LoadTestConfig;
use XTracker::Config::Local qw(config_var);
use Test::XTracker::Client;
use XTracker::PrintFunctions;
use File::Basename;

use_ok('Test::XTracker::PrintDocs');

my $print_directory = Test::XTracker::PrintDocs->new();

# Basic test of a new file found
{
    note "TEST: Basic test of a new file found";
    my $file_data = create_file();

    my (@files) = $print_directory->new_files();
    is( scalar @files, 1, "One new file found" );

    check_file( $files[0], $file_data );
}

# Wait for new files ... found required number
{
    note "TEST: Wait for new files - required files found";
    my (@files_data) = sort { $a->{'path'} cmp $b->{'path'} }
        (create_file(), create_file());

    my (@files) = sort { $a->filename cmp $b->filename }
        $print_directory->wait_for_new_files( files => 2 );
    is( scalar @files, 2, "Two new files found" );

    check_file( $files[0], $files_data[0] );
    check_file( $files[1], $files_data[1] );
}

# Wait for new files ... time out non-fatal
{
    note "TEST: Wait for new files - time out - no_die";
    my $file_data = create_file();

    my (@files) = $print_directory->wait_for_new_files(
        files => 2, seconds => 1, no_die => 1, no_time_warning => 1 );
    is( scalar @files, 1, "One new file found" );

    check_file( $files[0], $file_data );
}

# Wait for new files ... time out fatal
{
    note "TEST: Wait for new files - time out - fatal";
    my $file_data = create_file();

    throws_ok {
        $print_directory->wait_for_new_files(
            files => 2, seconds => 1, no_time_warning => 1 )
    } qr/not found in allowable time/, 'Fatal timeout';

}

# Check it doesn't find the wrong type of file
{
    note "TEST: Making sure file find regex works";
    create_file('txt');

    my (@files) = $print_directory->new_files();

    ok(! @files, "No files returned" );
}

# Check we can specify a directory
{
    note "TEST: Making sure we can specify a custom directory";
    my $dir = tempdir( CLEANUP => 1 );

    my $new_print_directory = Test::XTracker::PrintDocs->new(
        read_directory => $dir
    );
    my $file_data = create_file('html', $dir);

    my (@files) = $new_print_directory->new_files();
    is( scalar @files, 1, "One new file found" );

    check_file( $files[0], $file_data );
}


done_testing;

sub check_file {
    my ( $rec, $ref ) = @_;

    # Check it's the right type
    ok( $rec->isa('Test::XTracker::PrintDocs::File'),
        'Received item isa Test::XTracker::PrintDocs::File' );

    # Check the simple data is correct
    is( $rec->filename,  $ref->{'rel_path'}, "Filename correct"  );
    is( $rec->file_type, $ref->{'type'},     "File type correct" );
    is( $rec->file_id,   $ref->{'number'},   "File ID correct"   );

    # r00t h4x
    my $identifier = 'printdoc/' . $ref->{'type'};
    $Test::XTracker::Client::page_definitions{$identifier} = {
        auto_match => qr!^$identifier!,
        specification => {
            testdata => {
                location  => '/html/body',
                transform => 'parse_cell',
            }
        }
    };

    # Test the content that comes back is ok.
    is_deeply( $rec->as_data, { testdata => $ref->{'data'} },
        "Content via as_data() correct" );
}

sub create_file {
    my $ext = shift || 'html';
    my $path = shift;

    my $type   = 'test' . random_regex('[a-z]{6}');
    my $number = random_regex('[0-9]{6}');
    my $data   = random_regex('[a-z]{6}');

    $path = XTracker::PrintFunctions::path_for_print_document({
        ( $path ? ( path => $path ) : () ),
        document_type => $type,
        id => $number,
        ( $ext ? ( extension => $ext ) : () ),
        ensure_directory_exists => 1,
    });

    my $rel_path = basename( $path );

    open my $test_fh, ">", $path || die "Can't open [$path]: $!";
    print $test_fh "<html><body>$data</body></html>\n";
    close $test_fh;

    note "Created: $path";
    return { type => $type, number => $number, data => $data, path => $path, rel_path => $rel_path };
}
