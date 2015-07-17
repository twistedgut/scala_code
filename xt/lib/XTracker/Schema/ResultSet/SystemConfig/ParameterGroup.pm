package XTracker::Schema::ResultSet::SystemConfig::ParameterGroup;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub get_parameter_hash {
    my ($self, $path) = @_;

    my $parameter_groups = $self->search(
        ( $path ? [ { 'me.name' => $path }, { 'me.name' => { like => "$path/%" } } ] : undef ),
        {
            prefetch => { parameters => 'parameter_type' },
            order_by => [qw/parameters.sort_order parameters.name/],
        }
    );

    # Organise everything into a hash
    my $params_hash = { };

    for my $parameter_group ( $parameter_groups->all ) {
        $params_hash->{ $parameter_group->name } ||= {
            parameters => [ ],
            map { ; $_ => $parameter_group->$_ } qw{ name description visible }
        };

        for my $parameter ( $parameter_group->parameters ) {
            push @{ $params_hash->{ $parameter_group->name }{parameters} }, {
                type => $parameter->parameter_type->type,
                map { ; $_ => $parameter->$_ } qw{ description id name value }
            };
        }
    }

    return $params_hash;
}

=head2 parameter($group_name, $parameter_name) : $value

Look up the $parameter_name in $group_name and return the config
value.

=cut

sub parameter {
    my ($self, $group, $name) = @_;
    return $self
        ->search({"me.name" => $group})
        ->related_resultset("parameters")
        ->find({ "parameters.name" => $name }, { prefetch => "parameter_type" })
        ->value;
}

1;
