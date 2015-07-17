package XTracker::Schema::ResultSet::Public::CustomerCategory;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

### Subroutine : get_categories                 ###
# usage        : get_categories( $schema )        #
# description  : Returns visible rows ordered by  #
#                category from the                #
#                customer_category table as       #
#                DBIx::Class::ResultSet objects   #
# parameters   : $schema                          #
# returns      : $rs                       #

sub get_categories {

    my $resultset = shift;

    my $categories = $resultset->search(
        { is_visible => 1        },
        { order_by   => 'category' }
    );
    return $categories;
}

### Subroutine : add_category                   ###
# usage        : add_category( $schema,           #
#                              $category,         #
#                              $customer_class_id #
#                )                                #
# description  : Adds a category to the           #
#                customer_category table.         #
#                $discount is currently not in    #
#                use (always set to 0).           #
# parameters   : $schema, $category,              #
#                $customer_class_id               #
# returns      : 1 on success                     #

sub add_category {

    my ( $resultset, $category_name, $customer_class_id, $discount ) = @_;

    #$discount = $discount ? $discount : '0.000';

    $discount = 0;

    my $result;

    my $category = $resultset->find(
        { category  => $category_name },
        { key       => 'customer_category_category_key' }
    );

    # If category_name exists and is visible
    if ( $category and $category->is_visible() ) {
        die "Category exists\n";
    }
    # Else update or create
    else {
        $result = $resultset->update_or_create(
            {
                category            => $category_name,
                is_visible          => 1,
                customer_class_id   => $customer_class_id,
                discount            => $discount,
            },
            {   key                 => 'customer_category_category_key' }
        );
    }

    return $result;
}

### Subroutine : edit_category_name             ###
# usage        : edit_category_name(              #
#                               $schema,          #
#                               $category_id,     #
#                               $category_name    #
#                )                                #
# description  : Change the name of a category    #
# parameters   : $schema, $category_id,           #
#                $category_name                   #
# returns      : 1 on success                     #

sub edit_category_name {

    my ( $resultset, $category_id, $category_name ) = @_;

    my $schema = $resultset->result_source->schema;

    my $result;

    my $to_category = $resultset->find(
        { category => $category_name },
        { key => 'customer_category_category_key' }
    );

    my $tx_ref
        = sub {

            # If name of category to change exists but is hidden
            if ( $to_category and not $to_category->is_visible ) {
                $to_category->delete;
            }

            $result = $resultset->
            find($category_id)->
            update(
                { category => $category_name }
            );
        };

    eval {
        $schema->txn_do($tx_ref);
    };

    if ( $@ ) {
        die $@;
    }

    return $result ;
}

### Subroutine : change_class                   ###
# usage        : change_class($schema,            #
#                             $category_id,       #
#                             $class_id           #
#                )                                #
# description  : Change the class of a category   #
# parameters   : $schema, $category_id, $class_id #
# returns      : 1 on success                     #

sub change_class {

    my ( $resultset, $category_id, $class_id ) = @_;

    my $result = $resultset->
        find($category_id)->
        update(
            { customer_class_id => $class_id, }
        );

    return $result;
}

### Subroutine : hide_category                  ###
# usage        : hide_category( $schema,          #
#                               $category_id)     #
# description  : Sets is_visible to false         #
# parameters   : $schema, $category_id            #
# returns      : 1 on success                     #

sub hide_category {

    my ( $resultset, $category_id ) = @_;

    my $result = $resultset->
        find($category_id)->
        update(
            { is_visible => 0, }
        );

    return $result;
}

### Subroutine : hide_category_by_class         ###
# usage        : hide_category_by_class(          #
#                   $schema,                      #
#                   $class_id)                    #
# description  : Sets is_visible to false by      #
#                $class_id                        #
# parameters   : $schema, $category_id            #
# returns      :                                  #

sub hide_category_by_class {

    my ( $resultset, $class_id ) = @_;

    my $result = $resultset->search(
        { customer_class_id => $class_id }
    )->
    update(
        { is_visible        => 0 }
    );

    return $result;
}


### Subroutine : get_category_by_id             ###
# usage        : get_category_by_id(              #
#                   $schema, $category_id         #
#                )                                #
# description  : Returns a                        #
#                DBIx::Class:ResultSet object from#
#                the customer_category table with #
#                the given category_id            #
# parameters   : $schema, $category_id            #
# returns      : $category                        #

sub get_category_by_id {

    my ( $resultset, $category_id ) = @_;

    my $category = $resultset->find($category_id);

    return $category;
}

1;
