package XTracker::Role::CSV::Importer;
use NAP::policy 'role';

use MooseX::Params::Validate;

=head1 NAME

XTracker::Role::CSV::Importer

=head1 DESCRIPTION

Role that provides functionality to import data from a CSV file to a database table

=head1 REQUIRED ATTRIBUTES

=head2 get_import_config

Should return a hashref containing the following keys:
    target_result_set - Name of the DBIX::Class resultset to import data in to
    required_columns - An ArrayRef of columns that must exist in the CSV file for the
        import to be successful (these will be checked for before the import starts)

=cut

requires qw/get_import_config schema/;

=head1 OPTIONAL ATTRIBUTES

=head2 munge_imported_row_data

Given the raw data from a single row from the CSV file, the object can munge this data
 in to a form that can be imported

 param - $raw_row_data : A hashref where: key = name of column | data = column-data

 return - $populate_data: Hashref in same format as $raw_row_data, that will be used
    in a populate() call on the result_set to be imported to

=cut

has 'populate_data' => (
    is  => 'rw',
    isa => 'ArrayRef[HashRef]',
    traits  => ['Array'],
    handles => {
        add_row_data => 'push',
    },
);


=head1 PUBLIC METHODS

=head2 import_to_database

Execute the import process

 param - $file_handle : A file_handle to the CSV file to import from
 param - $columns : (Optional) if present, this should identify which file column
    represents the required columns as specified by required_columns() above.
    If this parameter is not present, the module will assume that the first column of the
    file will contain headers, and identify the required columns from the data found there
 param - csv_args : (Optional) a hashref of options that will be passed to the
  Text::CSV_XS object used to parse the CSV file


=cut
sub import_to_database {
    my ($self, $file_handle, $columns, $csv_args) = validated_list(\@_,
        file_handle         => { },
        columns             => { isa => 'ArrayRef[Str]', optional => 1 },
        csv_args            => { isa => 'HashRef', default => {} },
        MX_PARAMS_VALIDATE_NO_CACHE => 1,
    );

    my $read_columns_from_header = ( defined($columns) ? 0 : 1 );

    my @config_list = ($self->get_import_config());
    my ($target_result_set, $required_columns) = validated_list(\@config_list,
        target_result_set   => { isa => 'Str' },
        required_columns    => { isa => 'ArrayRef[Str]' },
        MX_PARAMS_VALIDATE_NO_CACHE => 1,
    );

    # Make sure the resultset is accessable before going further
    my $result_set = $self->schema->resultset($target_result_set);

    my $csv = Text::CSV_XS->new({
        binary => 1,
        eol => "\n",
        sep_char => ',',
        %$csv_args
    });

    if ($read_columns_from_header) {
        # We should assume that the first row the file will be the headers, that let us
        # know what data each column contains
        $columns = $csv->getline($file_handle);
    }

    for my $required_column (@$required_columns) {
        die(sprintf('Required column missing: %s', $required_column))
            unless grep { $_ eq $required_column } @$columns;
    }

    my $object_can_munge = $self->can('munge_imported_row_data');

    while(my $csv_row = $csv->getline($file_handle)) {
        my $row_data = {};
        my $column_counter = 0;
        for my $column_data (@$csv_row) {
            $row_data->{$columns->[$column_counter]} = $column_data;
            $column_counter++;
        }

        $row_data = $self->munge_imported_row_data($row_data) if $object_can_munge;
        $self->add_row_data($row_data);
    }

    my $populate_data = $self->populate_data();
    $result_set->populate($populate_data);
    return scalar(@$populate_data);
}
