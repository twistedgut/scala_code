package XTracker::Config::Parameters;

use NAP::policy "tt", 'exporter';
use Perl6::Export::Attrs;

use XTracker::Database;

# Get or set the value of a system parameter.
sub sys_param :Export(:common) {
    my ( $param_path, $value ) = @_;

    # test/param -> test, param
    # test/test/param -> test/test, param
    (my ($param_group, $param_name)) = ( $param_path =~ m{^(?:(.*)/)([^/]+)$} );

    my $param = schema_handle->resultset('SystemConfig::Parameter')->search(
        { 'parameter_group.name'  => $param_group, 'me.name' => $param_name },
        { 'join'     => [ 'parameter_group', 'parameter_type' ],
          '+columns' => [ 'value' ] }
    );

    croak "Unknown system parameter '$param_path'" unless $param->count;

    my $row = $param->slice(0,0)->single;

    if (defined($value)) {
      $row->update_if_necessary({ value => $value });
    }

    return $value // $row->value;
}

1;
