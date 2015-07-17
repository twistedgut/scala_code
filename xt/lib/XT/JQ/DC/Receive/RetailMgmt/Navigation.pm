package XT::JQ::DC::Receive::RetailMgmt::Navigation;

use Moose;

use Data::Dump qw/pp/;

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose                qw( Str Int ArrayRef Bool);
use MooseX::Types::Structured           qw( Dict Optional );


use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :product_attribute_type );
use XTracker::DB::Factory::ProductAttribute;


has payload => (
    is  => 'ro',
    isa => ArrayRef[
        Dict[
            action      => enum([qw/add delete update/]),
            channel_id  => Int,
            name        => Str,
            level       => Int,
            is_tag      => Optional[Bool],    # message consumer should default to 0
            classification => Optional[Str],  # But required at level 2 or 3
            product_type   => Optional[Str],  # But required at level 3
            update_name    => Optional[Str],  # for updates only
            visible        => Optional[Bool], # Default true on addition
            sort_order     => Optional[Int],
        ],
    ],
    required => 1,
);

sub check_job_payload {
    my ($self, $job) = @_;

    my $payload = $self->payload;

    my $errors;
    foreach my $item (@$payload){
        # checks that we can have sufficient info to locate the category
        if ($item->{level} > 3 || $item->{level} < 1){
            push @$errors, 'Unknown level specified for ' . $item->{name};
        }
        if ($item->{level} >=2 && !$item->{classification}){
            push @$errors, 'No parent classification specified for ' . $item->{name};
        }
        if (($item->{level} == 3 || $item->{is_tag}) && !$item->{product_type}){
            push @$errors, 'No parent product type specified for ' . $item->{name};
        }

        # if updating, check we have enough info
        my $update_field = defined $item->{update_name} || defined $item->{visible} || defined $item->{sort_order};
        if ($item->{action} eq 'update' && !$update_field){
            push @$errors, 'No update attribute defined for ' . $item->{name} . ' on channel ' . $item->{channel_id};
        }

    }
    return (join(', ', @$errors)) if $errors;
    return ();
}

sub do_the_task {
    my ($self, $job)    = @_;

    my $schema       = $self->schema;
    my $channels     = $schema->resultset('Public::Channel')->get_channels({ fulfilment_only => 0 });
    my $nav_factory  = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });
    my $tree_factory = XTracker::DB::Factory::ProductNavigation->new({ schema => $schema });

    my %web_dbhs;
    my $cant_talk_to_web = 0;

    eval {
        my $guard = $schema->txn_scope_guard;
        foreach my $set ( @{ $self->payload } ) {
            my $cid = $set->{channel_id};
            next unless $channels->{$cid};

            # still need this because it is used by some functions
            $web_dbhs{$cid}->{dbh_source} = $self->dbh unless $web_dbhs{$cid};

            my $attribute_type_id = ($set->{level} == 1) ? $PRODUCT_ATTRIBUTE_TYPE__CLASSIFICATION :
                                    ($set->{level} == 2) ? $PRODUCT_ATTRIBUTE_TYPE__PRODUCT_TYPE :
                                    ($set->{level} == 3 && $set->{is_tag}) ? $PRODUCT_ATTRIBUTE_TYPE__HIERARCHY
                                                         : $PRODUCT_ATTRIBUTE_TYPE__SUB_DASH_TYPE;
            # find parent node within tree
            my $join = 'attribute';
            my $cond = { 'attribute.channel_id' => $cid };
            if ($set->{level} == 1){
                $cond->{'attribute.attribute_type_id'} = $PRODUCT_ATTRIBUTE_TYPE__NONE;
            } elsif ($set->{level} == 2){
                $join = ['attribute', {'parent_tree' => 'attribute'}];
                $cond->{'attribute.attribute_type_id'} = $PRODUCT_ATTRIBUTE_TYPE__CLASSIFICATION;
                $cond->{'attribute.name'} = $set->{classification};
                $cond->{'attribute_2.attribute_type_id'} = $PRODUCT_ATTRIBUTE_TYPE__NONE;
            } elsif ($set->{level} == 3){
                $join = ['attribute', {'parent_tree' => ['attribute', {parent_tree => 'attribute'}]}];
                $cond->{'attribute.attribute_type_id'} = $PRODUCT_ATTRIBUTE_TYPE__PRODUCT_TYPE;
                $cond->{'attribute.name'} = $set->{product_type};
                $cond->{'attribute_2.attribute_type_id'} = $PRODUCT_ATTRIBUTE_TYPE__CLASSIFICATION;
                $cond->{'attribute_2.name'} = $set->{classification};
                $cond->{'attribute_3.attribute_type_id'} = $PRODUCT_ATTRIBUTE_TYPE__NONE;
            }

            my ($parentnode, $attribute_id, $node, $node_id);

            if (!($parentnode = $schema->resultset('Product::NavigationTree')->search($cond, {join => $join})->first)) {
                # Ignore these errors has XT can no longer be kept in sync
                warn "Cannot find parent node for '" .$set->{name}. "' on channel $cid";
                next;
            }

            if ($set->{action} eq 'update' || $set->{action} eq 'delete'){
                # get the attribute and node
                if ( $node = $schema->resultset('Product::NavigationTree')->search({
                              'attribute.channel_id'    => $cid,
                              'attribute.name'          => $set->{name},
                              'me.parent_id'            => $parentnode->id,
                            },
                            { join => [ 'attribute' ] }
                        )->first ) {
                    $node_id = $node->id;
                    $attribute_id = $node->attribute_id;
                } else {
                    # Ignore these errors has XT can no longer be kept in sync
                    warn "Cannot find node for '" .$set->{name}. "' on channel $cid with parent node id " . $parentnode->id;
                    next;
                }
            }


            if ($set->{action} eq 'add'){
                # create node (and push to website)
                # wrap in eval as cteate attribute might die if attribute exists
                eval {
                    $attribute_id = $nav_factory->create_attribute( $set->{name},
                                                                    $attribute_type_id,
                                                                    $cid,
                                                                    $web_dbhs{$cid} );
                };
                if (my $err = $@){
                    my $attribute = $nav_factory->get_attribute({ attribute_name => $set->{name},
                                                                  channel_id => $cid,
                                                                  attribute_type_id => $attribute_type_id,
                                                                });
                    $attribute_id = $attribute->id if $attribute;
                    die "Couldn't create or find attribute " . $set->{name} . ": $err" unless $attribute_id;
                }

                # add node to tree (and push to website)
                eval {
                    $node_id = $tree_factory->create_node( {
                                             'attribute_id'      => $attribute_id,
                                             'parent_id'         => $parentnode->id,
                                             'transfer_dbh_ref'  => $web_dbhs{$cid},
                                             'operator_id'       => $APPLICATION_OPERATOR_ID,
                                           } );
                };
                if (my $err = $@){
                    die "Failed to create node in tree for attribute id $attribute_id (" . $set->{name} . ") " .
                        "with parent node id " . $parentnode->id . " (" . $parentnode->attribute->name . "): $err";
                }
            } elsif ($set->{action} eq 'update' && $set->{update_name}){
                # update node name, ids may change due to hack
                ($attribute_id, $node_id) = $nav_factory->update_attribute(
                                                $attribute_id,
                                                $node,
                                                $set->{update_name},
                                                $attribute_type_id,
                                                $web_dbhs{$cid},
                                                $cid,
                                                $APPLICATION_OPERATOR_ID );
            } elsif ($set->{action} eq 'delete'){
                $tree_factory->delete_node( {
                                'node_id'           => $node_id,
                                'transfer_dbh_ref'  => $web_dbhs{$cid},
                                'operator_id'       => $APPLICATION_OPERATOR_ID
                } );
            }


            if ($set->{action} eq 'add' || $set->{action} eq 'update'){
                # if we're adding or updating and have sort_order/visibility data, use it
                $tree_factory->set_sort_order({
                                        'node_id'           => $node_id,
                                        'sort_order'        => $set->{sort_order},
                                        'transfer_dbh_ref'  => $web_dbhs{$cid} })
                    if defined $set->{sort_order};
                $tree_factory->set_node_visibility({
                                        'node_id'           => $node_id,
                                        'visible'           => $set->{visible},
                                        'transfer_dbh_ref'  => $web_dbhs{$cid},
                                        'operator_id'       => $APPLICATION_OPERATOR_ID })
                    if defined $set->{visible};
            }

        }
        $guard->commit();
    };
    if (my $err = $@){
        my %exceptions  = (
            'Deadlock'      => 'retry'
        );

        my $action  = "die";
        foreach my $exception ( keys %exceptions ) {
            $action = $exceptions{$exception} if ( $err =~ /$exception/ )
        }
        if ( $action eq "retry" || $cant_talk_to_web ) {
            $job->failed( $err );
        }
        else {
            die $err;
        }
    }
}

1;


=head1 NAME

XT::JQ::DC::Receive::RetailMgmt::Navigation - Add/remove/edit navigation categories/tags

=head1 DESCRIPTION

This message is sent via the Fulcrum Send::RetailMgmt::Navigation navigation categories/tags are added/removed/edited

Expected Payload should look like:

ArrayRef[
    Dict[
        action      => enum([qw/add delete update/]),
        channel_id  => Int,
        name        => Str,
        level       => Int,
        is_tag      => Optional[Bool],    # message consumer should default to 0
        classification => Optional[Str],  # But required at level 2 or 3
        product_type   => Optional[Str],  # But required at level 3
        update_name    => Optional[Str],  # for updates only
        visible        => Optional[Bool], # Default true on addition
        sort_order     => Optional[Int],
    ],
],
