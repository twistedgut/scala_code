use utf8;
package XTracker::Schema::Result::SystemConfig::Parameter;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("system_config.parameter");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "system_config.parameter_id_seq",
  },
  "parameter_group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "parameter_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 0 },
  "sort_order",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "parameter_parameter_group_id_name_key",
  ["parameter_group_id", "name"],
);
__PACKAGE__->belongs_to(
  "parameter_group",
  "XTracker::Schema::Result::SystemConfig::ParameterGroup",
  { id => "parameter_group_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "parameter_type",
  "XTracker::Schema::Result::SystemConfig::ParameterType",
  { id => "parameter_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cvckC7K+uGOcqNPQU90dNg

use feature 'switch';
use XTracker::Constants qw(
    $APPLICATION_OPERATOR_ID
);
use XTracker::Logfile qw(
    xt_logger
);
use List::AllUtils 'uniq';
use Const::Fast;
use Try::Tiny;

__PACKAGE__->load_components('FilterColumn');

my $validate_integer = sub {
    my ($value, $row) = @_;
    if ($value !~ /\A\s*\d+\s*\z/) {
        die sprintf("Bad %s %s: '%s' is not a valid integer\n",
                    $row->parameter_group->description,
                    $row->description,
                    $value,
                );
    }
    return $value;
};

const my $DATETIME_WITH_TIMEZONE_FMT => '%F %R %z';
my $dt_parser;

sub _get_datetime_with_timezone_parser {

    if (!defined($dt_parser)) {
        $dt_parser = DateTime::Format::Strptime->new(
            pattern => $DATETIME_WITH_TIMEZONE_FMT,
            on_error => 'croak',
        );
    }
    return $dt_parser;

}

my $validate_datetime_string = sub {
    my ($value, $row) = @_;
    my $parser = _get_datetime_with_timezone_parser;

    try {
        $parser->parse_datetime($value);
    } catch {
        die(sprintf("%s is not a valid DateTime for field: %s. want %s",
            $value,
            $row->name,
            $DATETIME_WITH_TIMEZONE_FMT
        ));
    };
};

__PACKAGE__->filter_column('value',{
    filter_from_storage => my $inflater = sub {
        my ($row, $raw_db_value) = @_;
        SMARTMATCH: {
            use experimental 'smartmatch';
            given ($row->parameter_type->type ) {
                when ( 'boolean' ) {
                    return $raw_db_value ? 1 : 0;
                }

                when ( 'integer' ) {
                    return 0+$validate_integer->($raw_db_value, $row);
                }

                when ( 'string' ) {
                    return "$raw_db_value";
                }

                when ( 'integer-set' ) {
                    # this is a set, not a list! we always return unique
                    # sorted values
                    return [
                        uniq
                            sort { $a<=>$b }
                                map { 0+$_ }
                                    map { $validate_integer->($_, $row) }
                                        grep { length($_)>0 }
                                            split(/,/, $raw_db_value)
                                        ];
                }

                when ('nullable_datetime_with_timezone') {
                    return undef
                        unless (defined($raw_db_value) && $raw_db_value ne '');

                    return _get_datetime_with_timezone_parser
                           ->parse_datetime($raw_db_value);
                }

                default {
                    return $raw_db_value;
                }
            }
        }
    },
    filter_to_storage => my $deflater = sub {
        my ($row, $cooked_value) = @_;
        SMARTMATCH: {
            use experimental 'smartmatch';
            given ($row->parameter_type->type ) {
                when ( 'boolean' ) {
                    return $cooked_value ? 1 : 0;
                }

                when ( 'integer' ) {
                    return 0+$validate_integer->($cooked_value, $row);
                }

                when ( 'string' ) {
                    return "$cooked_value";
                }

                when ( 'integer-set' ) {
                    # we accept either an array-ref, or a comma-separated
                    # list of integers in a string
                    if (ref($cooked_value) ne 'ARRAY') {
                        $cooked_value = [ split /,/, $cooked_value ];
                    }
                    # this is a set, not a list! we always store unique
                    # sorted values
                    return join ',',
                        uniq
                            sort { $a <=> $b }
                                map { 0+$_ }
                                    map { $validate_integer->($_, $row) }
                                        @$cooked_value;
                }

                # We accept both string values and datetime objects for
                # serialisation since strings is what the config pages
                # provide.
                when ('nullable_datetime_with_timezone') {
                    return '' unless defined($cooked_value);

                    if (ref($cooked_value) eq 'DateTime') {
                        return _get_datetime_with_timezone_parser
                               ->format_datetime($cooked_value);
                    } else {
                        return '' if ($cooked_value eq '');
                        $validate_datetime_string->($cooked_value, $row);
                        return "$cooked_value";
                    }
                }

                default {
                    return $cooked_value;
                }
            }
        }
    },
});

sub _eq_column_values {
    my ($self,$col,$old,$new) = @_;

    return $self->next::method($col,$old,$new)
        unless $col eq 'value';

    if (defined $new && defined $old) {
        return $self->$deflater($old) eq $self->$deflater($new);
    }
    # handle undef cases
    return $self->next::method($col,$old,$new);
}
sub set_filtered_column {
    my ($self,$col,$filtered) = @_;
    my $ret = $self->next::method($col,$filtered);
    if ($col eq 'value') {
        $ret=$self->$inflater($self->$deflater($ret));
        return $self->{_filtered_column}{$col} = $ret;
    }
    return $ret;
}

sub update_if_necessary {
    my ( $self, $args ) = @_;

    my $new_value = $args->{value};
    my $operator_id = $args->{operator_id} // $APPLICATION_OPERATOR_ID;
    my $old_value = $self->value;

    my %already_dirty = $self->get_dirty_columns;
    # this validates (dieing if there's an invalid value), deflates,
    # and sets the column dirty if the deflated value is different
    # than the existing one
    $self->value($new_value);
    my %newly_dirty = $self->get_dirty_columns;

    # update to new value if necessary, and add a log line saying so
    if (exists $newly_dirty{value} and not exists $already_dirty{value}) {
        xt_logger->info(sprintf(
                "System parameter %s %s updated from %s to %s by operator id %i",
                $self->parameter_group->description,
                $self->description,
                $self->$deflater($old_value),
                $self->$deflater($new_value),
                $operator_id
        ));
        $self->update();
    }
}

1;
