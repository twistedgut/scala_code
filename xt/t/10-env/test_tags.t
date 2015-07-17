#!/opt/xt/xt-perl/bin perl

=head1 NAME

test_tags.t - Ensure functional tests are tagged correctly

=head1 DESCRIPTION

Every test file (.t and .pm) in the t/30-functional/ directory must have
at least one of the required tags, and no duplicate tags.

=head1 METHODS

=cut

use Const::Fast;
use File::Find::Rule;
use List::MoreUtils 'part';
use NAP::policy "tt", qw/test/;

const my $test_files_re  => qr{\.(t|pm)$};
const my $test_tag_re    => qr{^\#TAGS};
const my @required_tags  => qw{cando whm};
const my $test_files_dir => 't/30-functional';

test_tags();
done_testing;

=head2 test_tags

Main caller to execute tests for mechanise test tags

=cut

sub test_tags {
    my @all_files = all_test_files($test_files_dir);
    my @tagged_files = tagged_test_files($test_files_dir);

    TODO: {
        local $TODO = "CANDO-2966: Disabled until CANDO finish writing their POD";
        eq_or_diff( \@tagged_files, \@all_files, 'all files tagged' );
    }

    # Create a hash with a filename pointing to an arrayref of tags
    my %file_tag = map { $_ => [file_tags($_)] } @tagged_files;

    subtest 'test required tags' => sub {
        for my $filename ( sort keys %file_tag ) {
            my @found = grep {
                my $required = $_;
                grep { $_ eq $required } @{$file_tag{$filename}};
            } @required_tags;
            TODO: {
                local $TODO = "CANDO-2966: Disabled until CANDO finish writing their POD";
                ok(@found, "$filename has required tags");
            }
        }
    };

    subtest 'test duplicate tags' => sub {
        # Create a hash with a filename pointing to a hashref with $tag => $count structure
        my %file_tag_count
            = map { $_ => _hash_count($file_tag{$_}) } keys %file_tag;

        for my $filename ( sort keys %file_tag_count ) {
            my ($duplicates) = part {
                $file_tag_count{$filename}{$_} < 2
            } keys %{$file_tag_count{$filename}};
            ok( !@{$duplicates||[]}, "No duplicate tags found for $filename" )
                or diag sprintf 'The following duplicate tags were found: %s',
                    join qq{\n}, sort @$duplicates;
        }
    };
}

# This will return a hashref with a $tag => $count structure
sub _hash_count {
    my $tags = shift;
    my $count;
    $count->{$_}++ for @{$tags||[]};
    return $count;
}

=head2 all_test_files( $dir ) : @test_files

Returns all test files in the given dir.

=cut

sub all_test_files {
    my $dir = shift;
    return File::Find::Rule->file->name( $test_files_re )->in($dir);
}

=head2 tagged_test_files( $dir ) : @tagged_test_files

Returns all test files with tags in the given dir.

=cut

sub tagged_test_files {
    my $dir = shift;
    return File::Find::Rule->file->name( $test_files_re )->grep($test_tag_re)->in($dir);
}

=head2 file_tags( $filename ) : @tags

Returns a list of tags for the given C<$filename>. Croaks if no tags line is
found.

=cut

sub file_tags {
    my $filename = shift;
    open my $fh, q{<}, $filename or die "Couldn't open $filename: $!";
    while ( my $line = <$fh> ) {
        chomp $line;
        next unless $line =~ $test_tag_re;
        close $fh;
        # We currently only allow one tags line per file, so we can return
        # immediately once we find it
        # The splice is there to remove the list's head (the tag line marker)
        return (splice @{[split m{ }, $line]}, 1);
    }
    close $fh;
    croak "Couldn't find tags for $filename";;
}
