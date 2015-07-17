package XTracker::Script::Feature::CSV;

=head1 NAME

XTracker::Script::Feature::CSV - enables dealing with CSV files.

=head1 DESCRIPTION

This role provides consumer with utilities to deal with CSV file.
Consumer gets:

B<csv> attribute which by default contains instance of B<Text::CSV_XS>.

B<csv_directory> that has the name of directory where all CSV files live. Note
that this is parameterized attribute, it is possible to change its name at
consuming declaration. Please look at synopsis for example.

B<open_file> - method that return file handler for passed file name. It should be in
directory specified in B<csv_directory>.

B<close_file> - method that tries to close provided file handler. Throws an error if
any problems occurred.

=head1 SYNOPSIS

# Simple usage:

    package Foo;

    use NAP::policy "tt", qw/class/;
    with 'XTracker::Script::Feature::CSV';

    ...

    pachage Bar;
    use Foo;

    sub foo_bar {
        my $can_deal_with_csv = Foo->new({
            csv_directory => '/tmp/foobar',
        });
        my $fh = $self->open_file( 'some_file_name_from_csv_foobar' );
        $can_deal_with_csv->csv->print( $fh, [ ... ] );
        $can_deal_with_csv->close_file;
    }


OR

# Advanced usage (parameterized role consuming):

    package Foo;

    use NAP::policy "tt", qw/class/;

    with 'XTracker::Script::Feature::CSV' => {
        # introduce "dump_directory" to be replacment for "csv_directory"
        csv_directory => 'dump_directory'
    };

    ...

    pachage Bar;
    use Foo;

    sub foo_bar {
        my $can_deal_with_csv = Foo->new({
            dump_directory => '/tmp/foobar',
        });
        my $fh = $self->open_file( 'some_file_name_from_tmp_foobar' );
        $can_deal_with_csv->csv->print( $fh, [ @columns ] );
        $can_deal_with_csv->close_file;
    }

=cut

use NAP::policy "tt";
use MooseX::Role::Parameterized;

# declare Role's parameters
parameter csv_directory => (
    isa     => 'Str',
    default => 'csv_directory',
);

# because this is parameterized role - special treatment is required
role {

# handle role's parameters
my $role_params = shift;
my $CSV_DIRECTORY_METHOD = $role_params->csv_directory;

=head2 csv

CSV parser. This is an instance of B<Text::CSV_XS>.

=cut

has 'csv' => (is => 'rw', lazy_build =>1,);
sub _build_csv { Text::CSV_XS->new({binary => 1, eol => "\n"}) }

=head2 csv_directory

Determines the directory where result files are dumped.

By default it is B</tmp>.

Make sure this directory exists, otherwise an error is returned.

=cut

has $CSV_DIRECTORY_METHOD => ( is => 'rw', lazy_build => 1,);
method "_build_$CSV_DIRECTORY_METHOD" => sub {
    my ($self) = @_;

    return '/tmp';
};

=head2 open_file

Returns file handler for specified filename in B<csv_directory>.

In case of failure, throws exception.

=cut

method 'open_file' => sub {
    my ($self, $filename) = @_;

    unless (-d $self->$CSV_DIRECTORY_METHOD) {
        die 'Directory ', $self->$CSV_DIRECTORY_METHOD, ' does not exists! ',
            'Please create such or specify another one.'
    }

    my $fh;
    open $fh, '>:encoding(UTF-8)', $self->$CSV_DIRECTORY_METHOD . '/' . $filename
        or die 'Failed to open ', $filename, ' in ', $self->$CSV_DIRECTORY_METHOD,
            ". Got error: $!";
    return $fh;
};

=head2 close_file

Close passed file handler. In case of failure throws an exception.

=cut

sub close_file {
    my ($self, $fh) = @_;

    close $fh or die "Failed to close file. Got error: $!";
}

} # end of the "role"
