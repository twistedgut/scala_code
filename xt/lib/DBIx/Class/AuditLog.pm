=head1 NAME

    DBIx::Class::AuditLog - DBIx::Class Component for adding auditing

=head1 SYNOPSIS

    use base qw( DBIx::Class );
    __PACKAGE__->load_components(qw/ AuditLog /);
    __PACKAGE__->add_audit_recents_rel;

    # set the columns you want to keep track of
    __PACKAGE__->audit_columns(qw/ price
                                   currency_id
                                 /);
    # or
    __PACKAGE__->audit_columns({ price => 'price',
                                 currency_id => 'currency.id'
                               });

    __PACKAGE__->audit_id_relationship('product_channel.id');
    __PACKAGE__->audit_descriptor('Region');
    __PACKAGE__->audit_descriptor_relationship('region.name');

=cut

package DBIx::Class::AuditLog;
use NAP::policy;
use strict;

use base 'DBIx::Class';
use Data::Dump qw/pp/;

__PACKAGE__->mk_classdata('columns');
__PACKAGE__->mk_classdata('id_relationship');
__PACKAGE__->mk_classdata('descriptor');
__PACKAGE__->mk_classdata('descriptor_relationship');

=head1 METHODS

=head2 audit_columns

getter/setter for audit columns.
Pass in a list or a hashref of columns you want to be audit logged
if a hashref is passed, the key should be the column name, and the
value should be a relationship descriptor to the actual value to store
e.g. the column name may be currency_id but the value to store would
most likely be currency.name

=cut

sub audit_columns {
    my ($class, @cols) = @_;

    if (ref $cols[0] eq 'HASH'){
        $class->columns($cols[0]);
    } elsif (scalar @cols) {
        my $audit_cols;
        $audit_cols->{$_} = $_ foreach @cols;
        $class->columns($audit_cols);
    }
    return $class->columns || {};
}

=head2 audit_id_relationship

get/set audit_id_relationship.
By default the 'id' column value will be used as an identifier in
the audit table. if you want to use an alternative column, or a
value from a related table, you need to set this
__PACKAGE__->audit_id_relationship('product_channel.id')

=cut

sub audit_id_relationship {
    my ($class, $rel) = @_;

    if ($rel || !$class->id_relationship){
        # set id_relationship
        $rel ||= 'id';
        $class->id_relationship([split(/\./, $rel)]);
    }
    return $class->id_relationship;
}

=head2 audit_descriptor

get/set audit descriptor.
if you're logging changes on a row based on a value in a
related table (which could well be a 1:many relationship)
you'll probably want to be able to identify the row too somehow.
This is used in conjunction with audit_descriptor_relationship,
and is just a description of what data is stored in
audit_descriptor_relationship.

=cut

sub audit_descriptor {
    my ($class, $desc) = @_;
    $class->descriptor($desc) if $desc;
    return $class->descriptor();
}

=head2 audit_descriptor_relationship

get/set audit descriptor relationship value
See audit_descriptor.
This defines a relationship to a value which should be stored
along with the audit data, to describe what the row represents
in the case where the audit_id_relationship is a reference to
another table and is not sufficient.

=cut

sub audit_descriptor_relationship {
    my ($class, $rel) = @_;
    $class->descriptor_relationship([split(/\./, $rel)]) if $rel;
    return $class->descriptor_relationship;
}

=head2 insert

Override DBIx::Class::Row 's insert method in order to add
rows to audit table

=cut

sub insert {
    my ($self, $upd, @rest) = @_;

    my $ar_rs            = $self->_get_auditlog_rs;
    my ($table_schema, $table) = $self->_get_schema_table;

    # need to use transaction scope_guard or next::method will die
    my $schema = $self->result_source->schema;

    my $operator_id
        = exists $upd->{operator_id} ? $upd->{operator_id} : $schema->operator_id;

    my $guard = $schema->txn_scope_guard;

    # insert the row
    my $row = $self->next::method($upd, @rest);

    my $audit_id         = $self->_get_audit_id;
    my $descriptor_value = $self->_get_descriptor_value;

    foreach my $field (keys %{$self->audit_columns()}){

        my $col_type = $self->_get_col_type($field);
        my $new_val = $self->_get_val_from($field);

        $ar_rs->create({
            table_schema     => $table_schema,
            table_name       => $table,
            col_name         => $field,
            col_type         => $col_type,
            audit_id         => $audit_id,
            descriptor       => $self->audit_descriptor,
            descriptor_value => $descriptor_value,
            old_val          => '',
            new_val          => $new_val,
            operator_id      => $operator_id,
        });
    }

    $guard->commit;
    return $row;
}


=head2 update

Override DBIx::Class::Row 's update method in order to add
rows to audit table

=cut

sub update {
    my ($self, $upd, @rest) = @_;

    my $schema = $self->result_source->schema;
    my $operator_id
        = exists $upd->{operator_id} ? $upd->{operator_id} : $schema->operator_id;

    # set cols on object so we can properly get dirty cols
    $self->set_inflated_columns($upd);
    my %dirty = $self->get_dirty_columns;

    my $ac = $self->audit_columns();

    # don't want to populate these unless necessary.
    # and then make sure we only do so once
    my ($ar_rs, $clean, $audit_id, $descriptor_value);

    # need to use transaction scope_guard or next::method will die
    my $guard = $schema->txn_scope_guard;

    foreach my $field (keys %dirty){
        if ($ac->{$field}){

            unless ($clean) {
                # get a clean copy from db to compare against
                $clean = $self->get_from_storage();
                $ar_rs = $self->_get_auditlog_rs;
                $audit_id = $self->_get_audit_id;
                $descriptor_value = $self->_get_descriptor_value;
            }

            my ($table_schema, $table) = $self->_get_schema_table;
            my $col_type = $self->_get_col_type($field);
            my $old_val = $self->_get_val_from($field, $clean);
            my $new_val = $self->_get_val_from($field);
            $ar_rs->create({
                table_schema     => $table_schema,
                table_name       => $table,
                col_name         => $field,
                col_type         => $col_type,
                audit_id         => $audit_id,
                descriptor       => $self->audit_descriptor,
                descriptor_value => $descriptor_value,
                old_val          => $old_val,
                new_val          => $new_val,
                operator_id      => $operator_id,
            });
        }
    }
    my $ret = $self->next::method($upd, @rest);
    $guard->commit;
    return $ret;
}

=head2 delete

Override DBIx::Class::Row 's delete method in order to add
rows to audit table

=cut

sub delete {
    my ($self, $upd, @rest) = @_;

    my $ar_rs            = $self->_get_auditlog_rs;
    my ($table_schema, $table) = $self->_get_schema_table;

    my $audit_id         = $self->_get_audit_id;
    my $descriptor_value = $self->_get_descriptor_value;

    # need to use transaction scope_guard or next::method will die
    my $schema = $self->result_source->schema;
    my $guard = $schema->txn_scope_guard;

    # just in case there's changes on the object which aren't in the DB.
    my $clean = $self->get_from_storage();

    foreach my $field (keys %{$self->audit_columns()}){

        my $col_type = $self->_get_col_type($field);
        my $old_val = $self->_get_val_from($field, $clean);

        $ar_rs->create({
            table_schema     => $table_schema,
            table_name       => $table,
            col_name         => $field,
            col_type         => $col_type,
            audit_id         => $audit_id,
            descriptor       => $self->audit_descriptor,
            descriptor_value => $descriptor_value,
            old_val          => $old_val,
            new_val          => 'DELETED',
            operator_id      => exists $upd->{operator_id}
                              ? $upd->{operator_id} : $schema->operator_id,
        });
    }


    $self->next::method($upd, @rest);
    $guard->commit;
}

# private methods

sub _get_auditlog_rs {
    return shift->result_source->schema->resultset('Audit::Recent');
}

sub _get_schema_table {
    my $self = shift;

    # It appears schema loader doesn't prefix tables with 'public.' when
    # they're in the 'public' namespace, so let's add it when we don't appear
    # to have a fully qualified table name
    my $table = $self->table;
    my $fully_qualified_table = $table =~ m{\.} ? $table : "public.$table";
    return split(m{\.}, $fully_qualified_table);
}

sub _get_col_type {
    my ($self, $field) = @_;
    my $col_type = $self->column_info($field)->{data_type};
    unless ($col_type){
        my ($schema, $table) = $self->_get_schema_table;
        warn("No col type for $schema.$table $field") unless $col_type;
    }
    return $col_type;
}

sub _get_audit_id {
    my $self = shift;
    my $audit_id = $self;
    $audit_id = $audit_id->$_
        foreach @{$self->audit_id_relationship};
    return $audit_id;
}

sub _get_descriptor_value{
    my $self = shift;
    return unless $self->audit_descriptor_relationship;

    my $descriptor_value = $self;
    $descriptor_value = $descriptor_value->$_
        foreach @{$self->audit_descriptor_relationship};
    return $descriptor_value;
}

sub _get_val_from {
    my ($self, $field, $val) = @_;
    $val ||= $self;
    my $ac = $self->audit_columns();
    for my $col ( split(/\./, $ac->{$field}) ) {

        next unless (defined $val); # it'll die if there's no $val

        if ($val == $self && $self->result_source->has_relationship($col) && exists $self->{_relationship_data}{$col} ) {
            # When you do ->update({status_id => 2}) the ->status object doesn't change. Force it to update
            delete $self->{_relationship_data}{$col};
            delete $self->{related_resultsets}{$col};
        }

        # If the result has a bespoke method for producing audit values for
        # this field, use that method
        my $overridden_method_name = "get_audit_value_for_$col";


        if ($val->can($overridden_method_name)) {
            $val = $val->$overridden_method_name;
        } else {
            $val = eval { $val->$col };
        }

        return undef if !defined $val;
    }
    return $val;
}

=head2 add_audit_recents_rel($self_rel_id=id) : audit_recent_rs

Add a has_many accessor for audit_recent to your consuming class. You can
optionally pass C<$self_rel_id>, specifying which column to join to
C<audit.recent>'s C<id> column.

=cut

sub add_audit_recents_rel {
    my ( $class, $self_rel_id ) = @_;
    $self_rel_id //= 'id';
    $class->has_many(
        # TODO: Un-hardcode this namespace
        'audit_recents' => 'XTracker::Schema::Result::Audit::Recent',
        sub {
            my $args = shift;
            my ( $schema, $table ) = $class->_get_schema_table;
            my %cond = (
                "$args->{foreign_alias}.table_schema" => $schema,
                "$args->{foreign_alias}.table_name"   => $table,
            );
            return (
                {
                    "$args->{foreign_alias}.audit_id" => { -ident => "$args->{self_alias}.$self_rel_id" },
                    %cond,
                },
                $args->{self_rowobj} && {
                    "$args->{foreign_alias}.audit_id" => $args->{self_rowobj}->$self_rel_id,
                    %cond,
                },
            );
        },
    );
}

1;
