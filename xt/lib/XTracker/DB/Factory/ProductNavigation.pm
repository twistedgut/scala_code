package XTracker::DB::Factory::ProductNavigation;

use strict;
use warnings;
use Carp;
use Class::Std;
use Error;

use XTracker::Database::Product qw(product_present);

use XTracker::Comms::DataTransfer   qw(:transfer);

use XTracker::Logfile qw( xt_logger );

my $logger = xt_logger();

use base qw/ Helper::Class::Schema /;

{
    sub get_attribute_nodes {

        my( $self, $attribute_id ) = @_;

        my $schema = $self->get_schema;

        return $schema->resultset('Product::NavigationTree')->search( { 'attribute_id'  => $attribute_id } );

    }

    sub set_sort_order {
        my ($self, $args) = @_;

        if ( !defined( $args->{node_id} ) ) {
            die 'No node id defined';
        }
        if ( !defined( $args->{sort_order} ) ) {
            die 'No sort order defined';
        }
        if ( !defined( $args->{transfer_dbh_ref} ) ) {
            die 'No website db handle defined';
        }

        my $schema = $self->get_schema;

        # get node details
        my $node = $schema->resultset('Product::NavigationTree')->find( $args->{node_id} )
            or die "Node " . $args->{node_id} . " not found";
        my $curr_postion = $node->sort_order;

        return if $curr_postion == $args->{sort_order};

        $node->update({sort_order => $args->{sort_order}});

        # update website
        transfer_navigation_data({
            dbh_ref             => $args->{transfer_dbh_ref},
            transfer_category   => 'navigation_tree',
            ids                 => $args->{node_id},
            sql_action_ref      => { navigation_tree => {'insert' => 1} },
        });
    }


    sub create_node {

        my( $self, $args ) = @_;

        if ( !defined( $args->{attribute_id} ) ) {
            die 'No attribute id defined';
        }

        if ( !defined( $args->{parent_id} ) ) {
            die 'No parent node id defined';
        }

        if ( !defined( $args->{operator_id} ) ) {
            die 'No operator id defined';
        }

        if ( !defined( $args->{transfer_dbh_ref} ) ) {
            die 'No website db handle defined';
        }

        my $schema = $self->get_schema;

        my $node_id;
        my $sort_order = 1;


        # work out next value for sort order within the parent
        my $sort_nodes = $schema->resultset('Product::NavigationTree')->search( { 'parent_id' => $args->{parent_id} }, { 'order_by' => 'sort_order' } );

        while (my $sort_node = $sort_nodes->next) {

            $sort_order = $sort_node->sort_order + 1;

        }

        # check if node already exists - may just be 'deleted'
        my $cur_node;

        my $rs = $schema->resultset('Product::NavigationTree')->search( { 'attribute_id' => $args->{attribute_id}, 'parent_id' => $args->{parent_id} } );

        while (my $node = $rs->next) {
            $cur_node = $node;
        }

        if ( $cur_node ) {

            # use current node id
            $node_id = $cur_node->id;

            # reset the sort order, visiblity and deleted values if currently set to deleted
            if ($cur_node->deleted == 1) {
                $cur_node->sort_order( $sort_order );
                $cur_node->visible( '1' );
                $cur_node->deleted( '0' );

                $cur_node->update;
            }
            elsif ( exists $args->{update_flag} ) {
                ${ $args->{update_flag} }   = 1;
            }
        }

        # no node found we need to create a new one
        if ( !$node_id ) {

            my $node = $schema->resultset('Product::NavigationTree')->create({
                                                                        'attribute_id'  => $args->{attribute_id},
                                                                        'parent_id'     => $args->{parent_id},
                                                                        'sort_order'    => $sort_order,
            });

            $node_id = $node->id;

        }

        # log it
        $schema->resultset('Product::LogNavigationTree')->create( {
                                                                    'navigation_tree_id'    => $node_id,
                                                                    'operator_id'           => $args->{operator_id},
                                                                    'action'                => 'Created',
        } );

        # transfer node to website
        if ($node_id) {
            transfer_navigation_data({
                dbh_ref             => $args->{transfer_dbh_ref},
                transfer_category   => 'navigation_tree',
                ids                 => $node_id,
                sql_action_ref      => { navigation_tree => {'insert' => 1} },
            });
        }

        return $node_id;

    }

    sub delete_node {

        my( $self, $args ) = @_;

        if ( !defined( $args->{node_id} ) ) {
            die 'No node id defined';
        }

        if ( !defined( $args->{operator_id} ) ) {
            die 'No operator id defined';
        }

        if ( !defined( $args->{transfer_dbh_ref} ) ) {
            die 'No website db handle defined';
        }

        my $schema = $self->get_schema;

        # get node info
        my $node        = $schema->resultset('Product::NavigationTree')->find( $args->{node_id} );

        my $parent_id   = $node->parent_id;
        my $sort_order  = $node->sort_order;

        # 'delete' node
        $node->sort_order( '0' );   # set sort order to 0
        $node->visible( '0' );      # set visible to 0
        $node->deleted( '1' );      # set deleted flag to true
        $node->update;

        # log it
        $schema->resultset('Product::LogNavigationTree')->create( {
                                            'navigation_tree_id'    => $node->id,
                                            'operator_id'           => $args->{operator_id},
                                            'action'                => 'Removed',
                                } );

        # delete node on website
        transfer_navigation_data({
            dbh_ref             => $args->{transfer_dbh_ref},
            transfer_category   => 'navigation_tree',
            ids                 => $args->{node_id},
            sql_action_ref      => { navigation_tree => {'delete' => 1} },
        });

        # resort any nodes below the deleted node
        my $sort_nodes = $schema->resultset('Product::NavigationTree')->search( { 'parent_id' => $parent_id, 'sort_order' => { '>' => $sort_order } } );

        $logger->debug("Parent: $parent_id, Sort: $sort_order");

        while (my $sort_node = $sort_nodes->next) {

            my $new_sort_order = $sort_node->sort_order - 1;

            $logger->debug("New Sort: $new_sort_order");

            $sort_node->sort_order( $new_sort_order );
            $sort_node->update;

            # transfer node data to website
            transfer_navigation_data({
                dbh_ref             => $args->{transfer_dbh_ref},
                transfer_category   => 'navigation_tree',
                ids                 => $sort_node->id,
                sql_action_ref      => { navigation_tree => {'update' => 1} },
            });

        }

        return;

    }


    sub set_node_visibility {

        my( $self, $args ) = @_;

        if ( !defined( $args->{node_id} ) ) {
            die 'No node id defined';
        }
        if ( !defined( $args->{operator_id} ) ) {
            die 'No operator id defined';
        }
        if ( !defined( $args->{transfer_dbh_ref} ) ) {
            die 'No website db handle defined';
        }

        my $schema = $self->get_schema;

        # get current node details
        my $node = $schema->resultset('Product::NavigationTree')->find( $args->{node_id} );

        # use visibility as defined in args, or for backward compatility, toggle
        my $new_visibility = (defined $args->{visible}) ? $args->{visible} :
                             ( $node->visible == 0 ) ? 1 : 0;

        return if $new_visibility == $node->visible;

        # update node
        $node->update({visible => $new_visibility});

        # log it
        $schema->resultset('Product::LogNavigationTree')->create( {
            'navigation_tree_id'    => $node->id,
            'operator_id'           => $args->{operator_id},
            'action'                => ($new_visibility) ? 'Visible' : 'Invisible',
        } );

        # transfer node data to website
        transfer_navigation_data({
            dbh_ref             => $args->{transfer_dbh_ref},
            transfer_category   => 'navigation_tree',
            ids                 => $args->{node_id},
            sql_action_ref      => { navigation_tree => {'insert' => 1} },
        });

        return;
    }


    sub set_node_parent {

        my( $self, $args ) = @_;

        if ( !defined( $args->{node_id} ) ) {
            die 'No node id defined';
        }

        if ( !defined( $args->{parent_id} ) ) {
            die 'No parent id defined';
        }

        if ( !defined( $args->{transfer_dbh_ref} ) ) {
            die 'No website db handle defined';
        }

        my $schema = $self->get_schema;

        # get current node details
        my $node = $schema->resultset('Product::NavigationTree')->find( $args->{node_id} );
        $node->parent_id( $args->{parent_id} );
        $node->update;


        # transfer node data to website
        transfer_navigation_data({
            dbh_ref             => $args->{transfer_dbh_ref},
            transfer_category   => 'navigation_tree',
            ids                 => $args->{node_id},
            sql_action_ref      => { navigation_tree => {'update' => 1} },
        });

        return;

    }

}

1;

__END__

=pod

=head1 NAME

XTracker::DB::Factory::ProductNavigation

=head1 DESCRIPTION

=head1 SYNOPSIS


=head1 AUTHOR

Ben Galbraith C<< <ben.galbraith@net-a-porter.com> >>

=cut
