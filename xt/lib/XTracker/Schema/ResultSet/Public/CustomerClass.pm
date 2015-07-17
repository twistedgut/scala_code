package XTracker::Schema::ResultSet::Public::CustomerClass;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use XTracker::Utilities             qw( number_in_list );
use XTracker::Constants::FromDB     qw( :customer_class );

### Subroutine : get_classes                    ###
# usage        : get_classes($schema)             #
# description  : Returns visible rows ordered by  #
#                id from the customer_class table #
#                as DBIX::Class::ResultSet objects#
# parameters   : $schema                          #
# returns      : $rs                              #

sub get_classes {

    my $resultset = shift;

    my $classes = $resultset->search(
        { is_visible => 1    },
        { order_by   => 'id' },
    );

    return $classes;
}

=head2 get_finance_high_priority_classes

    get_finance_high_priority_classes( $schema )

This returns a hash of Customer Classes that are regarded as 'High Priority' from a Finance point of view
with the Customer Class Id as the Key.

=cut

sub get_finance_high_priority_classes {
    my $rs  = shift;

    my %high_priority;

    # get all Customer Classes
    my $classes = $rs->search;
    while ( my $class = $classes->next ) {
        if ( $class->is_finance_high_priority ) {
            $high_priority{ $class->id }    = $class;
        }
    }

    return \%high_priority;
}

### Subroutine : add_class                      ###
# usage        : add_class($schema, $class_name)  #
# description  : Adds a row to customer_class     #
# parameters   : $schema, $class_name             #
# returns      : $result no success               #

sub add_class {

    my ( $resultset, $class_name ) = @_;

    my $result;

    my $class = $resultset->find(
        { class => $class_name },
        { key   => 'customer_class_class_key' }
    );

    # If class_name exists and is visible
    if ( $class and $class->is_visible() ) {
        die( "$class_name already exists" );
    }

    # Else update or create with args
    else {
        $result = $resultset->update_or_create(
            {
                class       => $class_name,
                is_visible  => 1,
            },
            {   key         => 'customer_class_class_key'   }
        );
    }
    return $result;
}

### Subroutine : edit_class_name                ###
# usage        : edit_class_name($schema,         #
#                                $class_id,       #
#                                $class_name      #
#                )                                #
# description  : Change the name of a class       #
# parameters   : $schema, $class_id, $class_name  #
# returns      : 1 on success                     #

sub edit_class_name {

    my ( $resultset, $class_id, $class_name ) = @_;

    my $result;

    my $old_class = $resultset->
        find(
            {
                class   => $class_name,
            },
            {
                key     => 'customer_class_class_key'
            }
        );

    my $schema = $resultset->result_source->schema;

    my $tx_ref
        = sub {

            # If class with new name already exists and hidden
            if ( $old_class and not $old_class->is_visible ) {
                $schema->resultset('Public::CustomerCategory')->
                    search(
                        { customer_class_id => $old_class->id }
                    )->update(
                        { customer_class_id => $class_id }
                    );

                $old_class->delete;
            }

            $result = $resultset->
                find($class_id)->
                update(
                    { class => $class_name }
                );
        };

    eval {
        $schema->txn_do($tx_ref);
    };

    if ( $@ ) {
        die( $@ );
    }

    return $result;
}

### Subroutine : hide_class                     ###
# usage        : hide_class($schema, $class_id)   #
# description  : Sets is_visible to false         #
# parameters   : $schema, $class_id               #
# returns      : 1 on success                     #

sub hide_class {

    my ( $resultset, $class_id ) = @_;

    my $schema = $resultset->result_source->schema;
    my $results;
    my $result;

    my $tx_ref
        = sub {
            $result = $resultset->
                find($class_id)->
                update(
                    { is_visible        => 0 }
                );
            $schema->resultset('Public::CustomerCategory')->
                hide_category_by_class( $class_id );
            };

    eval {
        $results = $schema->txn_do($tx_ref);
    };

    if ( $@ ) {
        die( $@ );
    }

    return $result;
}

1;
