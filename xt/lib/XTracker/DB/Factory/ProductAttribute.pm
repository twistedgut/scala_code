package XTracker::DB::Factory::ProductAttribute;
# vim: ts=8 sts=4 et sw=4 sr sta

use strict;
use warnings;
use Carp;
use Class::Std;
use Error;

use XTracker::Database::Product qw(product_present);
use XTracker::DB::Factory::ProductNavigation;

use XTracker::Comms::DataTransfer   qw(:transfer);

use XTracker::Logfile qw( xt_logger );
use XTracker::Constants::FromDB qw( :product_attribute_type );

my $logger = xt_logger();

use base qw/ Helper::Class::Schema /;

{

    # returns resultset
    sub get_attribute_types {

                my($self, $cond, $attr) = @_;

                my $schema = $self->get_schema;

                $cond = { } if (not defined $cond);
                $attr = { } if (not defined $attr);

        return $schema->resultset('Product::AttributeType')->search($cond, $attr);
    }

        sub get_attributes {

                my($self,$cond, $attr) = @_;

                my $schema = $self->get_schema;

                $cond = { } if (not defined $cond);
                $attr = { } if (not defined $attr);

                $attr->{join}           = [ qw/ type / ],
                $attr->{'+select'}      = [ qw/ type.name / ];
                $attr->{'+as'}          = [ qw/ type / ];
                $attr->{'order_by'}     = [ qw/ me.name / ];

        return $schema->resultset('Product::Attribute')->search($cond, $attr);
    }

        sub create_attribute {

                my( $self, $attribute_name, $attribute_type_id, $channel_id, $transfer_dbh_ref )        = @_;

                my $schema = $self->get_schema;
                my $attribute_id;

                # tidy up name
                $attribute_name =~ s/[^\w\s\,\.\-\']//gi;       # strip out anything funny
                $attribute_name =~ s/\s/_/g;            # replace spaces with an underscore

        # get the group the attribute type is in: CUSTOM_LIST, WHATS_NEW, NAV_LEVEL3 etc.
        # can be a bit more relaxed with the NAV_LEVEL3 now they're not managed by DC
        my $type_grp= $schema->resultset('Product::AttributeType')->find($attribute_type_id);
        unless ($type_grp->web_attribute eq 'NAV_LEVEL3'){
            # check if there is an attribute (not deleted) that is in the same group as the Attribute Type provided
            # eg. if Type is a CUSTOM_LIST check any other CUSTOM_LIST doesn't have the new attribute in it's list

            # search for attributes of the same group
            my $chk_rs  = $schema->resultset('Product::Attribute')->search( {
                                                        'UPPER(me.name)'                => uc($attribute_name),
                                                        'me.channel_id'                 => $channel_id,
                                                        'me.deleted'                    => 0,
                                                        'me.attribute_type_id'  => { '!=' => $attribute_type_id },
                                                        'type.web_attribute'    => $type_grp->web_attribute
                                                    },
                                                    {
                                                        'join'                                  => [ qw( type ) ],
                                                        '+select'                               => [ 'type.name' ],
                                                        '+as'                                   => [ 'attribute_type_list_name' ]
                                                    } );
            my $chk_rec = $chk_rs->first();
            # do we have a match
            if ( defined $chk_rec ) {
                die "Attribute $attribute_name already Exists in: ".$chk_rec->get_column('attribute_type_list_name')."\n";
            }
        }

                # check if attribute already exists in same type - may just be 'deleted'
                my $cur_attr;

                my $rs          = $schema->resultset('Product::Attribute')->search( {
                                                                                                        'UPPER(name)'           => uc $attribute_name,
                                                                                                        'attribute_type_id'     => $attribute_type_id,
                                                                                                        'channel_id'            => $channel_id
                                                                                                } );

                while (my $attr = $rs->next) {
                        $cur_attr = $attr;
                }

                if ( $cur_attr ) {

                        # use current attribute id
                        $attribute_id = $cur_attr->id;

                        # reset deleted flag if set
                        if ( $cur_attr->deleted == 1 ) {
                                $cur_attr->deleted( '0' );
                                $cur_attr->update;
                        }

                }

                # no existing attribute we need to create it
                if ( !$attribute_id ) {

                        my $attribute = $schema->resultset('Product::Attribute')->create({
                                                                                                                                                'name'                          => $attribute_name,
                                                                                                                                                'attribute_type_id'     => $attribute_type_id,
                                                                                                                                                'channel_id'            => $channel_id
                        });

                        $attribute_id = $attribute->id;
                }

                # transfer attribute to website
                if ($attribute_id) {
                        transfer_navigation_data({
                                dbh_ref             => $transfer_dbh_ref,
                                transfer_category   => 'navigation_category',
                                ids                 => $attribute_id,
                                sql_action_ref      => { navigation_category => {'insert' => 1} },
                        });
                }

                return $attribute_id;
        }


        sub update_attribute {

                my( $self, $attribute_id, $node, $attribute_name, $attribute_type_id, $transfer_dbh_ref, $channel_id, $operator_id )    = @_;

                my $schema = $self->get_schema;
        my $node_id = $node->id;
                # get the attribute record
                my $attr = $schema->resultset('Product::Attribute')->find( $attribute_id );

                if ( $attr ) {

                        # check if attribute already exists with same name
                        my $match_attr = $schema->resultset('Product::Attribute')->search( {
                'UPPER(name)' => uc($attribute_name),
                'attribute_type_id' => $attribute_type_id,
                'channel_id' => $channel_id,
                'id' => {'!=' => $attribute_id},
            })->first;

            if ($match_attr) {
                # Crap! Name already used elsewhere in tree.
                # Due to crazee DC design, going to have to be a bit nasty here and reuse the attribute which already exists

                # remove this attribute from any products
                my $av_rs = $schema->resultset('Product::AttributeValue')->search({attribute_id => $attribute_id});
                my %pids;
                while (my $av = $av_rs->next){
                    $pids{$av->product_id} = 1;
                    $self->remove_product_attribute({
                        attribute_id        => $attribute_id,
                        product_id          => $av->product_id,
                        transfer_dbh_ref    => $transfer_dbh_ref,
                        operator_id         => $operator_id,
                        channel_id          => $channel_id
                    });
                }

                # remove this attribute from the tree
                my $tree_factory = XTracker::DB::Factory::ProductNavigation->new({ schema => $schema });
                $tree_factory->delete_node( {
                                'node_id'           => $node->id,
                                'transfer_dbh_ref'  => $transfer_dbh_ref,
                                'operator_id'       => $operator_id
                } );

                # henceforth the match is the attribute we care about
                $attribute_id = $match_attr->id;

                # add matching attribute into tree in it's place
                $node_id = $tree_factory->create_node( {
                                             'attribute_id'      => $attribute_id,
                                             'parent_id'         => $node->parent_tree->id,
                                             'transfer_dbh_ref'  => $transfer_dbh_ref,
                                             'operator_id'       => $operator_id,
                                           } );

                # Add products to matching attribute
                foreach my $pid (keys %pids){
                    $self->create_product_attribute( {
                        attribute_id        => $attribute_id,
                        product_id          => $pid,
                        transfer_dbh_ref    => $transfer_dbh_ref,
                        operator_id         => $operator_id,
                        channel_id          => $channel_id
                    });
                }

            } else {
                # now it's okay to update the attribute name, phew
                $attr->name( $attribute_name );
                $attr->update;

                # update website
                transfer_navigation_data({
                    dbh_ref             => $transfer_dbh_ref,
                    transfer_category   => 'navigation_category',
                    ids                 => $attribute_id,
                    sql_action_ref      => { navigation_category => {'insert' => 0, 'update' => 1} },
                });
            }
                }
                else {
                        die "Could not find record for id $attribute_id\n";
                }

                return ($attribute_id, $node_id);

        }

    # This is different to the above in that it should only be used when we don't care about the navigation category ( and don't know the node )
    sub update_attribute_simple {
        my( $self, $attribute_id, $attribute_name, $attribute_type_id, $channel_id, $transfer_dbh_ref ) = @_;
        my $schema = $self->get_schema;

        $attribute_name =~ s/\s/_/g;
        # check if exists
        my $match_attr = $schema->resultset('Product::Attribute')->search( {
            'UPPER(name)' => uc( $attribute_name ),
            'attribute_type_id' => $attribute_type_id,
            'channel_id' => $channel_id,
            'id' => { '!=' => $attribute_id },
        } )->slice(0,0)->single;

        # return error if it does
        die "Can't change name to existing Attribute, please try another" if $match_attr;


        # get the attribute record and update it
        my $attr = $schema->resultset('Product::Attribute')->find( $attribute_id );

        $attr->name( $attribute_name );
        $attr->update;

        # update website
                transfer_navigation_data({
                        dbh_ref             => $transfer_dbh_ref,
                        transfer_category   => 'navigation_category',
                        ids                 => $attribute_id,
                        sql_action_ref      => { navigation_category => {'insert' => 1} },
                });

                return $attribute_id;
    }


        sub delete_attribute {

                my( $self, $attribute_id, $channel_id, $transfer_dbh_ref, $operator_id ) = @_;

                my $schema      = $self->get_schema;

                # get attribute db record
                my $attr        = $schema->resultset('Product::Attribute')->find( $attribute_id, { 'join' => 'type' } );

                if ( $attr ) {

                        # get type record for attribute
                        my $attr_type   = $attr->type->web_attribute;

                        # firstly we may need to 'delete' any navigation tree nodes using this attribute
                        if ( $attr_type eq 'NAV_LEVEL3' ) {

                                my $nav_factory = XTracker::DB::Factory::ProductNavigation->new({ schema => $schema });

                                # get nodes
                                my $nodes = $nav_factory->get_attribute_nodes($attribute_id);

                                # set nodes as deleted
                                while (my $node = $nodes->next) {
                                        $nav_factory->delete_node( {
                                                                        node_id                         => $node->id,
                                                                        transfer_dbh_ref        => $transfer_dbh_ref,
                                                                        operator_id                     => $operator_id
                                                        } );
                                }

                        }

                        # finally we can 'delete' the attribute
                        $attr->deleted( 1 );
                        $attr->update;

                        # update website
                        transfer_navigation_data({
                                dbh_ref             => $transfer_dbh_ref,
                                transfer_category   => 'navigation_category',
                                ids                 => $attribute_id,
                                sql_action_ref      => { navigation_category => {'insert' => 1} },
                        });

                }

                return;

        }


        sub get_attribute {

                my( $self, $args ) = @_;

                my $schema = $self->get_schema;

        my $conds =  {
                    'me.name'       => $args->{attribute_name},
                    'me.channel_id' => $args->{channel_id},
                };
        if ($args->{attribute_type}){
            $conds->{'type.name'} = $args->{attribute_type};
        } else {
            $conds->{'me.attribute_type_id'} = $args->{attribute_type_id};
        }

                my $attr = $schema->resultset('Product::Attribute')->search(
                                $conds,
                                {
                                        'select'    => [ qw( me.id me.name me.attribute_type_id me.deleted me.synonyms me.manual_sort me.page_id ) ],
                                        'join'      => [ qw( type ) ],
                                        '+select'   => [ qw( type.name ) ],
                                        '+as'       => [ qw( type ) ],
                                        'prefetch'  => [ qw( type ) ],
                                }
                );

                return $attr->first;

        }


        sub get_attribute_products {

                my( $self, $args ) = @_;

                my $schema = $self->get_schema;

                # conidtions
                my $cond;

                $cond->{'attribute_value.attribute_id'} = $args->{attribute_id};
                $cond->{'attribute_value.deleted'}              = 0;

                # live & visible flags if provided
                if ( defined( $args->{live} ) ) {
                        $cond->{'product_channel.live'} = $args->{live};
                }

                if ( defined( $args->{visible} ) ) {
                        $cond->{'product_channel.visible'} = $args->{visible};
                }

                if ( defined( $args->{channel_id} ) ) {
                        $cond->{'product_channel.channel_id'}   = $args->{channel_id};
                }
#                                       'prefetch'      => [ qw( attribute designer colour season price_default attribute_value product_channel )],
                return $schema->resultset('Public::Product')->search(
                                $cond,
                                {
                                        'join'          => [ qw( attribute designer colour season price_default attribute_value product_channel ) ],
                                        '+select'       => [ qw( attribute.name designer.designer colour.colour season.season price_default.price attribute_value.sort_order product_channel.live product_channel.visible ) ],
                                        '+as'           => [ qw( name designer colour season price sort_order live visible ) ],
                                        'order_by'      => [ qw( attribute_value.sort_order )],
                                }
                );

        }


        sub get_product_attribute {

                my( $self, $args ) = @_;

                my $schema = $self->get_schema;

                if ( !defined( $args->{product_id} ) ) {
                        die "No product id defined\n";
                }

                if ( !defined( $args->{attribute_type} ) ) {
                        die "No attribute type\n";
                }

        if ( !defined( $args->{channel_id} ) ) {
                        die "No channel id defined\n";
                }

                my $cur_attr;

                my $rs = $schema->resultset('Public::Product')->search(
                                                                                                                                {
                                                                                                                                        'me.id'                                         => $args->{product_id},
                                                                                                                                        'attribute_value.deleted'       => 0,
                                                                                                                                        'type.name'                                     => $args->{attribute_type},
                                                                    'attribute.channel_id'      => $args->{channel_id},

                                                                                                                                },
                                                                                                                                {
                                                                                                                                        'join'          => [ { 'attribute_value' => { 'attribute' => 'type' } } ],
                                                                                                                                        '+select'       => [ 'attribute_value.attribute_id' ],
                                                                                                                                        '+as'           => [ 'attribute_id' ],
                                                                                                                                        'prefetch'      => [ { 'attribute_value' => { 'attribute' => 'type' } } ],
                                                                                                                                }
                );

                while (my $attr = $rs->next) {
                        $cur_attr = $attr;
                }

                if ($cur_attr) {
                        return $cur_attr->get_column('attribute_id');
                }
                else {
                        return 0;
                }

        }


        sub create_product_attribute {

                my( $self, $args ) = @_;

                if ( !defined( $args->{product_id} ) ) {
                        die "No product id defined\n";
                }

                if ( !defined( $args->{attribute_id} ) ) {
                        die "No attribute id defined\n";
                }

                if ( !defined( $args->{operator_id} ) ) {
                        die "No operator id defined\n";
                }

                if ( !defined( $args->{transfer_dbh_ref} ) ) {
                        die "No website db handles defined\n";
                }

                if ( !defined( $args->{channel_id} ) ) {
                        die "No channel id defined\n";
                }

                my $schema = $self->get_schema;

        # check the product has a record in the product_channel table for the passed in channel_id (doesn't need to be live just exist)
                my $channel_count       = $schema->resultset('Public::ProductChannel')->count( { 'product_id' => $args->{product_id}, 'channel_id' => $args->{channel_id} } );
                if (!$channel_count) {
                        return  0;              # if no record then can't add product to attribute
                }

                # work out next value for sort order within the attribute
                my $sort_order = 0;
                my $product_sort_preference = $args->{product_sort_preference} || 'bottom';

                if($product_sort_preference eq 'top'){
                        # find all pids in the list
                        my $pid_list_rs = $schema->resultset('Product::AttributeValue')->search( {
                            attribute_id => $args->{attribute_id}
                        });

                        # increase sort_order by 1, ensures new pid is always 0 (top)
                        $pid_list_rs->update({sort_order => \'sort_order + 1'});
                } else {
                        # user wants the product at bottom of list
                        my $sort_nodes = $schema->resultset('Product::AttributeValue')->search( { 'attribute_id' => $args->{attribute_id} }, { 'order_by' => 'sort_order'});

                        while (my $sort_node = $sort_nodes->next) {
                            $sort_order = $sort_node->sort_order + 1;
                        }
                }
                # check if attribute value already exists for product
                my $cur_attr;

                my $rs = $schema->resultset('Product::AttributeValue')->search( { 'product_id' => $args->{product_id}, 'attribute_id' => $args->{attribute_id} } );

                while (my $attr = $rs->next) {
                        $cur_attr = $attr;
                }

                # record already exists - may need to reset deleted flag
                if ( $cur_attr ) {

                        # reset deleted flag if set
                        if ( $cur_attr->deleted == 1 ) {
                                $cur_attr->sort_order( $sort_order );
                                $cur_attr->deleted( '0' );
                                $cur_attr->update;
                        }

                }
                # create attribute value if it doesn't exist already
                else {

                        $cur_attr = $schema->resultset('Product::AttributeValue')->create({
                                                                                                                                                'product_id'    => $args->{product_id},
                                                                                                                                                'attribute_id'  => $args->{attribute_id},
                                                                                                                                                'sort_order'    => $sort_order,
                        });

                }

                # log change
                $schema->resultset('Product::LogAttributeValue')->create( {
                                                                                                                                        'attribute_value_id'    => $cur_attr->id,
                                                                                                                                        'operator_id'                   => $args->{operator_id},
                                                                                                                                        'action'                                => 'Added',
                } );


                ## check if product is live for website updates
                if ( product_present( $args->{transfer_dbh_ref}->{dbh_source}, { type => 'product_id', id => $args->{product_id}, environment => 'live', channel_id => $args->{channel_id} } ) ) {

                        # get attribute db record
                        my $attr = $schema->resultset('Product::Attribute')->find( $args->{attribute_id} );

                        # get type record for attribute
                        my $attr_type = $schema->resultset('Product::AttributeType')->find( $attr->attribute_type_id );

                        # update website
                        if ( $attr_type->web_attribute eq 'NAV_LEVEL1' || $attr_type->web_attribute eq 'NAV_LEVEL2' ) {

                eval {
                                transfer_product_data({
                                        dbh_ref             => $args->{transfer_dbh_ref},
                                        product_ids         => $args->{product_id},
                                        transfer_categories => 'navigation_attribute',
                                        attributes          => $attr_type->web_attribute,
                                        sql_action_ref      => { navigation_attribute => {'insert' => 1, 'update' => 1, 'delete' => 0} },
                                        channel_id                      => $args->{channel_id}
                                });
                };
                if (my $err = $@){
                    die "Failed to transfer product navigation_attribute data for $args->{product_id} : $err\n";
                }
                        }
                        else {

                                transfer_product_data({
                                        dbh_ref             => $args->{transfer_dbh_ref},
                                        product_ids         => $args->{product_id},
                                        transfer_categories => 'list_attribute',
                                        attributes          => $attr_type->web_attribute,
                                        sql_action_ref      => { list_attribute => {'insert' => 1, 'update' => 1, 'delete' => 0} },
                                        channel_id                      => $args->{channel_id}
                                });
                        }

                }

                return  1;
        }


        sub remove_product_attribute {

                my( $self, $args ) = @_;

                if ( !defined( $args->{product_id} ) ) {
                        die "No product id defined\n";
                }

                if ( !defined( $args->{attribute_id} ) ) {
                        die "No attribute id defined\n";
                }

                if ( !defined( $args->{operator_id} ) ) {
                        die "No operator id defined\n";
                }

                if ( !defined( $args->{transfer_dbh_ref} ) ) {
                        die "No website db handles defined\n";
                }

                if ( !defined( $args->{channel_id} ) ) {
                        die "No channel id defined\n";
                }

                my $schema = $self->get_schema;

                # get db record for attribute and product
                my $cur_attr;

                my $rs = $schema->resultset('Product::AttributeValue')->search( { 'product_id' => $args->{product_id}, 'attribute_id' => $args->{attribute_id} } );

                while (my $attr = $rs->next) {
                        $cur_attr = $attr;
                }

                # set deleted if it exists
                if ( $cur_attr ) {

                        $cur_attr->sort_order( 0 );
                        $cur_attr->deleted( 1 );
                        $cur_attr->update;

                        # log change
                        $schema->resultset('Product::LogAttributeValue')->create( {
                'attribute_value_id'    => $cur_attr->id,
                'operator_id'                   => $args->{operator_id},
                'action'                                => 'Removed',
                        } );

                        # get attribute db record
                        my $attr                = $schema->resultset('Product::Attribute')->find( $args->{attribute_id}, { 'join' => 'type' } );
                        # get type record for attribute
                        my $attr_type   = $attr->type->web_attribute;

                        ## check if product is live for website updates
                        if ( product_present( $args->{transfer_dbh_ref}->{dbh_source}, { type => 'product_id', id => $args->{product_id}, environment => 'live', channel_id => $args->{channel_id} } ) ) {

                                # update website
                                if ( $attr_type eq 'NAV_LEVEL1' || $attr_type eq 'NAV_LEVEL2' ) {
                                        transfer_product_data({
                                                dbh_ref             => $args->{transfer_dbh_ref},
                                                product_ids         => $args->{product_id},
                                                transfer_categories => 'navigation_attribute',
                                                attributes          => $attr_type,
                                                sql_action_ref      => { navigation_attribute => {'insert' => 0, 'update' => 0, 'delete' => 1} },
                                                channel_id                      => $args->{channel_id}
                                        });

                                        transfer_product_data({
                                                dbh_ref             => $args->{transfer_dbh_ref},
                                                product_ids         => $args->{product_id},
                                                transfer_categories => 'navigation_attribute',
                                                attributes          => $attr_type,
                                                sql_action_ref      => { navigation_attribute => {'insert' => 1, 'update' => 0, 'delete' => 0} },
                                                channel_id                      => $args->{channel_id}
                                        });
                                }
                                else {
                                        transfer_product_data({
                                                dbh_ref             => $args->{transfer_dbh_ref},
                                                product_ids         => $args->{product_id},
                                                transfer_categories => 'list_attribute',
                                                attributes          => $attr_type,
                                                sql_action_ref      => { list_attribute => {'insert' => 0, 'update' => 0, 'delete' => 1} },
                                                channel_id                      => $args->{channel_id}
                                        });

                                        transfer_product_data({
                                                dbh_ref             => $args->{transfer_dbh_ref},
                                                product_ids         => $args->{product_id},
                                                transfer_categories => 'list_attribute',
                                                attributes          => $attr_type,
                                                sql_action_ref      => { list_attribute => {'insert' => 1, 'update' => 1, 'delete' => 0} },
                                                channel_id                      => $args->{channel_id}
                                        });
                                }

                        }

                }
                else {
                        return 0;
                }

                return 1;

        }


        sub set_synonyms {

                my( $self, $attribute_id, $synonyms, $transfer_dbh_ref ) = @_;

                my $schema = $self->get_schema;

                # get db record
                my $attr = $schema->resultset('Product::Attribute')->find( $attribute_id );

                if ( $attr ) {

                        $attr->synonyms( $synonyms );
                        $attr->update;

                        # update website
                        transfer_navigation_data({
                                dbh_ref             => $transfer_dbh_ref,
                                transfer_category   => 'navigation_category',
                                ids                 => $attribute_id,
                                sql_action_ref      => { navigation_category => {'update' => 1} },
                        });
                }

                return;

        }


        sub set_manual_sort {

                my( $self, $attribute_id, $manual_sort, $transfer_dbh_ref ) = @_;

                my $schema = $self->get_schema;

                # get db record
                my $attr = $schema->resultset('Product::Attribute')->find( $attribute_id );

                if ( $attr ) {

                        $attr->manual_sort( $manual_sort );
                        $attr->update;

                        # update website
                        transfer_navigation_data({
                                dbh_ref             => $transfer_dbh_ref,
                                transfer_category   => 'navigation_category',
                                ids                 => $attribute_id,
                                sql_action_ref      => { navigation_category => {'insert' => 1} },
                        });
                }

                return;

        }


        sub set_sort_order {

                my( $self, $attribute_id, $pid, $sort_order, $channel_id, $transfer_dbh_ref )   = @_;

                my $schema = $self->get_schema;

                # get attribute data
                my $attr = $schema->resultset('Product::Attribute')->find( $attribute_id );

                # get type record for attribute
                my $attr_type = $schema->resultset('Product::AttributeType')->find( $attr->attribute_type_id );

                # get db record for attribute value
                my $attr_val;

                my $rs = $schema->resultset('Product::AttributeValue')->search( { 'product_id' => $pid, 'attribute_id' => $attribute_id } );

                while (my $attr = $rs->next) {
                        $attr_val = $attr;
                }

                if ( $attr && $attr_val ) {

                        $attr_val->sort_order( $sort_order );
                        $attr_val->update;

                        ## check if product is live for website updates
                        if ( product_present( $transfer_dbh_ref->{dbh_source}, { type => 'product_id', id => $pid, environment => 'live', channel_id => $channel_id } ) ) {

                                # update website
                                if ($attr_type->navigational == 1) {

                                }
                                else {
                                        transfer_product_data({
                                                dbh_ref             => $transfer_dbh_ref,
                                                product_ids         => $pid,
                                                transfer_categories => 'list_attribute',
                                                attributes          => $attr_type->web_attribute,
                                                sql_action_ref      => { list_attribute => {'insert' => 0, 'delete' => 0, 'update' => 1} },
                                                channel_id                      => $channel_id
                                        });
                                }
                        }
                }

                return;

        }
}


1;

__END__

=pod

=head1 NAME

XTracker::DB::Factory::ProductAttribute

=head1 DESCRIPTION

=head1 SYNOPSIS


=head1 AUTHOR

Ben Galbraith C<< <ben.galbraith@net-a-porter.com> >>

=cut
