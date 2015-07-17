package XTracker::DB::Factory::Designer;

use strict;
use warnings;
use Carp;
use Class::Std;
use Error;

use Data::Dump qw(pp);

use XTracker::Comms::DataTransfer   qw(:transfer);
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :web_content_field
                                        :web_content_type
                                        :web_content_template
                                        :page_instance_status
                                        :product_attribute_type
                                        :designer_attribute_type );

use XTracker::DB::Factory::CMS;
use XTracker::DB::Factory::ProductAttribute;

use XTracker::Logfile qw( xt_logger );

my $logger = xt_logger();

use base qw/ Helper::Class::Schema /;

{

    sub create_designer {
        my ($self, $params) = @_;
        my $schema = $self->get_schema;

        my $expected_keys = [qw(designer_id designer_name url_key supplier_code supplier_name)];
        foreach (@$expected_keys){
            die ("$_ not specified in create_designer_channel") unless defined $params->{$_};
        }

        # ensure nothing has this ID
        my $designer_rs = $schema->resultset('Public::Designer');
        my $designer = $designer_rs->find($params->{designer_id});

        my $fulcrum_designer_name =  $params->{designer_name};

        if ($designer) {
            if ($designer->designer eq $fulcrum_designer_name) {
                warn "designer ". $designer->designer .".(id=". $designer->id
                    .") already existed";

                return $designer->id;
            } else {
                die "designer ids are out of sync. id=" . $params->{designer_id} . " (fulcrum_name=" .
                    $fulcrum_designer_name . ", xt name=". $designer->designer. ")";
            }
        }

        # check for dupe on name.
        $designer = $designer_rs->search({ 'designer' => $fulcrum_designer_name})->first;

        if ($designer) {
            die "designer already exists with a different id. designer=". $designer->designer .
                "(fulcrum id=" . $params->{designer_id} . ", xt id=" . $designer->id . ")";
        }

        # create the designer
        $designer = $schema->resultset('Public::Designer')->create({
            'id'       => $params->{designer_id},
            'designer' => $fulcrum_designer_name,
            'url_key'  => $params->{url_key}
        });

        # create supplier and link to designer
        my $supplier_id  = $self->create_supplier( $params->{supplier_code}, $params->{supplier_name} );
        $self->link_designer_supplier( $designer->id, $supplier_id );

        return $designer->id;
    }

    sub create_supplier {
        my( $self, $code, $name ) = @_;
        my $schema = $self->get_schema;

        my $supplier = $schema->resultset('Public::Supplier')->create( { 'code' => $code, 'description' => $name } );
        return $supplier->id;
    }

    sub link_designer_supplier {
        my( $self, $designer_id, $supplier_id ) = @_;
        my $schema = $self->get_schema;

        $schema->resultset('Public::LegacyDesignerSupplier')->create( { 'designer_id' => $designer_id, 'supplier_id' => $supplier_id } );
    }


    sub create_designer_channel {
        my ( $self, $params ) = @_;
        my $schema  = $self->get_schema;

        my $expected_keys = [qw(designer_id
                                channel_id
                                create_page
                                designer_name
                                url_key
                                visibility_id
                                operator_id
                                transfer_dbh_ref
                                staging_transfer_dbh_ref)];
        foreach (@$expected_keys){
            die ("$_ not specified in create_designer_channel") unless defined $params->{$_};
        }


        my $page_id = $params->{create_page} ? $self->create_designer_cms($params) : undef;

        # create designer chanenl
        my $des_chann = $schema->resultset('Public::DesignerChannel')->create({
            designer_id         => $params->{designer_id},
            page_id             => $page_id,
            website_state_id    => $params->{visibility_id},
            description         => $params->{description},
            description_is_live => $params->{description} ? 1 : 0,
            channel_id          => $params->{channel_id},
        });

        # update website
        transfer_designer_data({
            dbh_ref             => $params->{transfer_dbh_ref},
            transfer_category   => 'designer',
            ids                 => $params->{designer_id},
            sql_action_ref      => {'insert' => 1},
            channel_id          => $params->{channel_id},
        });

        # update staging website
        if ( $params->{staging_transfer_dbh_ref} ) {
            transfer_designer_data({
                dbh_ref             => $params->{staging_transfer_dbh_ref},
                transfer_category   => 'designer',
                ids                 => $params->{designer_id},
                sql_action_ref      => {'insert' => 1},
                channel_id          => $params->{channel_id},
            });
        }

        # Put designer in navigation tree. for some reason...
        $self->create_designer_nav_tree($params);

        # finally, set designer categories
        $self->set_designer_categories($des_chann, $params) if defined $params->{categories};
    }


    sub create_designer_cms {
        my ( $self, $params ) = @_;
        my $schema  = $self->get_schema;

        my $expected_keys = [qw(channel_id
                                designer_name
                                url_key
                                operator_id
                                transfer_dbh_ref
                                staging_transfer_dbh_ref)];
        foreach (@$expected_keys){
            die ("$_ not specified in create_designer_cms") unless defined $params->{$_};
        }

        my $cms_factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

        # create designer cms page
        my $page_id = $cms_factory->create_page({
            name                        => 'Designer - '.$params->{designer_name},
            type                        => $WEB_CONTENT_TYPE__DESIGNER_FOCUS,
            template                    => $WEB_CONTENT_TEMPLATE__STANDARD_DESIGNER_LANDING_PAGE,
            page_key                    => $params->{url_key},
            transfer_dbh_ref            => $params->{transfer_dbh_ref},
            staging_transfer_dbh_ref    => $params->{staging_transfer_dbh_ref},
            channel_id                  => $params->{channel_id},
        });

        # create page instance
        my $instance_id = $cms_factory->create_instance({
            page_id                     => $page_id,
            name                        => 'Version 1',
            operator_id                 => $params->{operator_id},
            transfer_dbh_ref            => $params->{transfer_dbh_ref},
            staging_transfer_dbh_ref    => $params->{staging_transfer_dbh_ref},
        });

        # define and create instance content blocks
        my @required_content = (
            $WEB_CONTENT_FIELD__TITLE,
            $WEB_CONTENT_FIELD__DESIGNER_DESCRIPTION,
            $WEB_CONTENT_FIELD__MAIN_AREA_IMAGE,
            $WEB_CONTENT_FIELD__LEFT_NAV_LINK_1_TEXT,
            $WEB_CONTENT_FIELD__LEFT_NAV_LINK_1_URL,
            $WEB_CONTENT_FIELD__LEFT_NAV_LINK_2_TEXT,
            $WEB_CONTENT_FIELD__LEFT_NAV_LINK_2_URL,
            $WEB_CONTENT_FIELD__LEFT_NAV_LINK_3_TEXT,
            $WEB_CONTENT_FIELD__LEFT_NAV_LINK_3_URL,
            $WEB_CONTENT_FIELD__LINK_1_TEXT,
            $WEB_CONTENT_FIELD__LINK_1_URL,
            $WEB_CONTENT_FIELD__LINK_2_TEXT,
            $WEB_CONTENT_FIELD__LINK_2_URL,
            $WEB_CONTENT_FIELD__LINK_3_TEXT,
            $WEB_CONTENT_FIELD__LINK_3_URL,
            $WEB_CONTENT_FIELD__LINK_4_TEXT,
            $WEB_CONTENT_FIELD__LINK_4_URL,
            $WEB_CONTENT_FIELD__LINK_5_TEXT,
            $WEB_CONTENT_FIELD__LINK_5_URL,
            $WEB_CONTENT_FIELD__PROMO_BLOCK,
            $WEB_CONTENT_FIELD__DESIGNER_NAME_FONT_CLASS,
            $WEB_CONTENT_FIELD__PROMO_BLOCK_TWO,
            $WEB_CONTENT_FIELD__DESIGNER_RUNWAY_VIDEO,
            $WEB_CONTENT_FIELD__FP_ONE__DASH__PID,
            $WEB_CONTENT_FIELD__FP_ONE__DASH__IMAGE_TYPE,
            $WEB_CONTENT_FIELD__FP_TWO__DASH__PID,
            $WEB_CONTENT_FIELD__FP_TWO__DASH__IMAGE_TYPE,
            $WEB_CONTENT_FIELD__FP_THREE__DASH__PID,
            $WEB_CONTENT_FIELD__FP_THREE__DASH__IMAGE_TYPE
        );
        foreach my $field_id (@required_content) {
            $cms_factory->create_content({
                instance_id                 => $instance_id,
                field_id                    => $field_id,
                content                     => ($field_id == $WEB_CONTENT_FIELD__TITLE) ? $params->{designer_name} : '',
                transfer_dbh_ref            => $params->{transfer_dbh_ref},
                staging_transfer_dbh_ref    => $params->{staging_transfer_dbh_ref},
            });
        }
        # publish instance
        $cms_factory->set_instance_status({
            page_id                     => $page_id,
            instance_id                 => $instance_id,
            status_id                   => $WEB_CONTENT_INSTANCE_STATUS__PUBLISH,
            operator_id                 => $params->{operator_id},
            environment                 => 'live',
            transfer_dbh_ref            => $params->{transfer_dbh_ref},
            staging_transfer_dbh_ref    => $params->{staging_transfer_dbh_ref},
        });

        return $page_id;
    }


    sub create_designer_nav_tree {
        my ( $self, $params ) = @_;
        my $schema  = $self->get_schema;

        my $expected_keys = [qw(url_key
                                channel_id
                                create_page
                                operator_id
                                transfer_dbh_ref
                                staging_transfer_dbh_ref)];
        foreach (@$expected_keys){
            die ("$_ not specified in create_designer_channel") unless defined $params->{$_};
        }
        my $attr_factory    = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });
        my $nav_factory     = XTracker::DB::Factory::ProductNavigation->new({ schema => $schema });


        # create product attribute.
        my $attr_id         = $attr_factory->create_attribute( $params->{url_key},
                                                               $PRODUCT_ATTRIBUTE_TYPE__DESIGNER,
                                                               $params->{channel_id},
                                                               $params->{transfer_dbh_ref} );




        # get prod navigation object

        my $root_id = $self->_find_designer_root($params->{channel_id});
        # Should only be in nav tree if we've got a root designer cat for this channel
        # (currently should exist for NAP and MRP but not OUT)
        return unless $root_id;

        my $des_node_id = $nav_factory->create_node({
            attribute_id        => $attr_id,
            parent_id           => $root_id,
            transfer_dbh_ref    => $params->{transfer_dbh_ref},
            operator_id         => $params->{operator_id},
            channel_id          => $params->{channel_id},
        });

        # set parent id to id of created node for hairbrained website functionality
        $nav_factory->set_node_parent({
            node_id             => $des_node_id,
            parent_id           => $des_node_id,
            transfer_dbh_ref    => $params->{transfer_dbh_ref},
            operator_id         => $params->{operator_id},
        });

        # make it visible
        $nav_factory->set_node_visibility({
            node_id             => $des_node_id,
            transfer_dbh_ref    => $params->{transfer_dbh_ref},
            operator_id         => $params->{operator_id},
        });

        # now create Clothing, Bags, Shoes, Accessories in tree
        # TODO: Refactor out hard coded top level Classification strings
        foreach my $cat_name ( qw(Clothing Bags Shoes Accessories) ) {
            # get the attribute id
            my $attr = $attr_factory->get_attribute({
                attribute_name  => $cat_name,
                attribute_type  => 'Classification',
                channel_id      => $params->{channel_id},
            });

            # put it in the nav tree
            $nav_factory->create_node({
                attribute_id        => $attr->id,
                parent_id           => $des_node_id,
                transfer_dbh_ref    => $params->{transfer_dbh_ref},
                operator_id         => $params->{operator_id},
                channel_id          => $params->{channel_id},
            });
        }
    }

    sub set_designer_categories {
        my ( $self, $designer_channel, $params ) = @_;
        my $schema  = $self->get_schema;

        # first remove all categories from designer
        my $attr_values = $schema->resultset('Designer::AttributeValue')->search(
            { 'me.designer_id' => $designer_channel->designer_id,
              'me.deleted' => 0,
              'attribute.channel_id'  => $params->{channel_id},
            },
            { join => 'attribute' }
        );
        my @attr_val_ids;
        while (my $record = $attr_values->next) {
            $record->update({ deleted => 1 });
            push @attr_val_ids, $record->id;
        }

        # then add the new ones
        foreach my $category_name (@{$params->{categories}}){
            my $attr = $schema->resultset('Designer::Attribute')->search(
                { 'name'        => $category_name,
                  'channel_id'  => $params->{channel_id},
                })->first;
            die "Category $category_name not found on channel $params->{channel_id}" unless $attr;

            my $record = $schema->resultset('Designer::AttributeValue')->search({
                'designer_id'   => $designer_channel->designer_id,
                'attribute_id'  => $attr->id,
            })->first;

            if ($record){
                $record->update({ deleted => 0 });
            } else {
                $record = $schema->resultset('Designer::AttributeValue')->create({
                    'designer_id'   => $designer_channel->designer_id,
                    'attribute_id'  => $attr->id,
                });
            }
            push @attr_val_ids, $record->id;
        }

        # update the website for all attribuet_calues changed
        transfer_designer_data({
            dbh_ref             => $params->{transfer_dbh_ref},
            transfer_category   => 'designer_attribute_value',
            ids                 => \@attr_val_ids,
            sql_action_ref      => {'insert' => 1},
        }) if scalar @attr_val_ids;

    }



    sub update_designer {
        my( $self, $params) = @_;
        my $schema = $self->get_schema;

        die "No designer id supplied to update_designer" unless $params->{designer_id};
        my $designer = $schema->resultset('Public::Designer')->find($params->{designer_id});
        die "Designer id $params->{designer_id} not found" unless $designer;

        if ($params->{new_name} || $params->{url_key}){
            $designer->update({ designer => $params->{new_name},
                                url_key  => $params->{url_key}, });
        }

        # Update supplier
        my $supplier = $designer->suppliers->first;
        die("Could not find supplier for designer: " . $designer->designer) unless $supplier;
        $supplier->code($params->{supplier_code}) if $params->{supplier_code};
        $supplier->description($params->{supplier_name}) if $params->{supplier_name};
        $supplier->update() if $supplier->is_changed;
    }


    sub update_designer_channel {
        my ($self, $params) = @_;
        my $schema  = $self->get_schema;

        my $expected_keys = [qw(designer_id
                                channel_id
                                operator_id
                                transfer_dbh_ref
                                staging_transfer_dbh_ref)];
        foreach (@$expected_keys){
            die ("$_ not specified in update_designer_channel") unless defined $params->{$_};
        }

        my $des_channel = $schema->resultset('Public::DesignerChannel')->find({
            designer_id => $params->{designer_id},
            channel_id => $params->{channel_id},
        });
        die "Could not find designer record for id: ".$params->{designer_id} unless $des_channel;


        # will need to update CMS designer landing page if one exists
        if ($des_channel->page_id && $params->{designer_name_new}){
            $self->update_designer_cms({page_id => $des_channel->page_id, %$params});
        }

        # and the product attribute
        $self->update_designer_nav_tree($params) if $params->{url_key};


        # then update the designer_channel itself
        if (defined $params->{visibility_id} &&
                $des_channel->website_state_id != $params->{visibility_id}) {
            # update designer state
            $des_channel->website_state_id( $params->{visibility_id} );
        }

        if (defined $params->{description} &&
                ($des_channel->description or '') ne $params->{description} ) {
            # update designer description
            $des_channel->description( $params->{description} );
            $des_channel->description_is_live( $params->{description} ? 1 : 0 );
        }

        $des_channel->update;

        # update website
        transfer_designer_data({
            dbh_ref             => $params->{transfer_dbh_ref},
            transfer_category   => 'designer',
            ids                 => $params->{designer_id},
            channel_id          => $params->{channel_id},
        });

        # push to staging if needed
        if ( defined $params->{staging_transfer_dbh_ref} ) {
            transfer_designer_data({
                dbh_ref             => $params->{staging_transfer_dbh_ref},
                transfer_category   => 'designer',
                ids                 => $params->{designer_id},
                channel_id          => $params->{channel_id},
            });
        }

        # finally, set designer categories
        $self->set_designer_categories($des_channel, $params) if defined $params->{categories};
    }


    sub update_designer_cms {
        my ($self, $params) = @_;
        my $schema  = $self->get_schema;

        my $expected_keys = [qw(page_id
                                designer_name_new
                                designer_name_old
                                url_key
                                transfer_dbh_ref
                                staging_transfer_dbh_ref)];
        foreach (@$expected_keys){
            die ("$_ not specified in update_designer_cms") unless defined $params->{$_};
        }

        my $cms_factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

        # update the page name
        $cms_factory->update_page({
            page_id                     => $params->{page_id},
            name                        => 'Designer - '.$params->{designer_name_new},
            page_key                    => $params->{url_key},
            transfer_dbh_ref            => $params->{transfer_dbh_ref},
            staging_transfer_dbh_ref    => $params->{staging_transfer_dbh_ref},
        });

        # Update the 'title' type page contents
        my $contents = $schema->resultset('WebContent::Content')->search(
            { 'instance.page_id' => $params->{page_id},
              'me.field_id'      => $WEB_CONTENT_FIELD__TITLE
            },
            {join => 'instance'}
        );
        while (my $cont = $contents->next){
            # only update if content has not been changed since
            next unless ($cont->content eq $params->{designer_name_old});
            $cms_factory->set_content({
                content_id                  => $cont->id,
                content                     => $params->{designer_name_new},
                transfer_dbh_ref            => $params->{transfer_dbh_ref},
                staging_transfer_dbh_ref    => $params->{staging_transfer_dbh_ref},
            })
        }

    }

    sub update_designer_nav_tree {
        my ($self, $params) = @_;
        my $schema  = $self->get_schema;

        my $expected_keys = [qw(channel_id
                                url_key_old
                                url_key
                                transfer_dbh_ref)];
        foreach (@$expected_keys){
            die ("$_ not specified in update_designer_cms") unless defined $params->{$_};
        }

        return if ($params->{url_key_old} eq $params->{url_key});

        my $attr = $schema->resultset('Product::Attribute')->search(
            { name              => $params->{url_key_old},
              attribute_type_id => $PRODUCT_ATTRIBUTE_TYPE__DESIGNER,
              channel_id        => $params->{channel_id}
            }
        )->first;
        return unless $attr;

        # update attribute
        $attr->update({name => $params->{url_key}});
        # update websites
        transfer_navigation_data({
            dbh_ref             => $params->{transfer_dbh_ref},
            transfer_category   => 'navigation_category',
            ids                 => $attr->id,
            sql_action_ref      => { navigation_category => {'insert' => 0, 'update' => 1} },
        });

    }




    sub create_category {
        my ( $self, $params )   = @_;
        my $schema  = $self->get_schema;

        my $expected_keys = [qw(name
                                channel_id
                                operator_id
                                transfer_dbh_ref)];
        foreach (@$expected_keys){
            die ("$_ not specified in designer create_attribute") unless defined $params->{$_};
        }


        my $attribute = $schema->resultset('Designer::Attribute')->search( {
                            'UPPER(name)'       => uc($params->{name}),
                            'channel_id'        => $params->{channel_id},
                        })->first;


        if ( !$attribute ) {
            # create the attribute
            $attribute = $schema->resultset('Designer::Attribute')->create({
                'name'              => $params->{name},
                'attribute_type_id' => $DESIGNER_ATTRIBUTE_TYPE__BESPOKE_CATEGORY,
                'deleted'           => 0,
                'synonyms'          => '',
                'manual_sort'       => 0,
                'channel_id'        => $params->{channel_id},
            });
        }
        elsif ( $attribute->deleted ) {
            $attribute->update({deleted => 0});
        }

        # set designer list if necessary
        $self->set_category_designers($attribute, $params) if defined $params->{designers};

        return $attribute->id;
    }


    sub update_category {
        my ( $self, $params )   = @_;
        my $schema  = $self->get_schema;

        my $expected_keys = [qw(name
                                channel_id
                                operator_id
                                transfer_dbh_ref)];
        foreach (@$expected_keys){
            die ("$_ not specified in designer update_category") unless defined $params->{$_};
        }

        my $attr = $schema->resultset('Designer::Attribute')->search( {
                            'UPPER(name)'       => uc($params->{name}),
                            'channel_id'        => $params->{channel_id},
                        })->first;

        die "cannot find category named $params->{name} to update" unless $attr;

        # update the category name if necessary
        $attr = $self->update_category_name($attr, $params)
            if ( $params->{new_name} && uc($params->{new_name}) ne uc($params->{name}) );

        # set designer list if necessary
        $self->set_category_designers($attr, $params) if defined $params->{designers};
    }


    sub update_category_name {
        my ( $self, $attr, $params )   = @_;
        my $schema  = $self->get_schema;

        my $attr_newname = $schema->resultset('Designer::Attribute')->search( {
                            'UPPER(name)'       => uc($params->{new_name}),
                            'channel_id'        => $params->{channel_id},
                        })->first;

        my $cms_factory = XTracker::DB::Factory::CMS->new({ schema => $schema });


        if (!$attr_newname){
            # Update the current attribute
            $attr->update({ name => $params->{new_name} });
            # Refresh all of the designer attribute value details on the website
            my @attr_val_ids = map { $_->id }
                               $schema->resultset('Designer::AttributeValue')->search( { 'attribute_id' => $attr->id, 'deleted' => 0 } )->all;
            transfer_designer_data({
                dbh_ref             => $params->{transfer_dbh_ref},
                transfer_category   => 'designer_attribute_value',
                ids                 => \@attr_val_ids,
                sql_action_ref      => {'insert' => 1},
            }) if scalar @attr_val_ids;

        } else {
            # pain in the ass. Cannot update name of current attribute as it's already in use.
            # Why can't we just properly delete things rather than setting a flag! Hurumph

            # Should just be able to:
            # 1) make sure the newname one is not deleted
            $attr_newname->update({deleted => 0});

            # 2) add designers from old category to new
            my $attr_values = $schema->resultset('Designer::AttributeValue')->search( { 'attribute_id' => $attr->id, 'deleted' => 0 } );
            my @attr_val_ids;
            while (my $record = $attr_values->next) {
                my $new_record = $schema->resultset('Designer::AttributeValue')->search({
                    'designer_id'   => $record->designer_id,
                    'attribute_id'  => $attr_newname->id,
                })->first;

                if ($new_record){
                    $new_record->update({ deleted => 0 });
                } else {
                    $new_record = $schema->resultset('Designer::AttributeValue')->create({
                        'designer_id'   => $record->designer_id,
                        'attribute_id'  => $attr_newname->id,
                    });
                }
                push @attr_val_ids, $new_record->id;
            }

            transfer_designer_data({
                dbh_ref             => $params->{transfer_dbh_ref},
                transfer_category   => 'designer_attribute_value',
                ids                 => \@attr_val_ids,
                sql_action_ref      => {'insert' => 1},
            }) if scalar @attr_val_ids;

            # 3) make the current category deleted,
            $self->delete_category($params);

            # 4) return the now active attribute
            $attr = $attr_newname;
        }

        return $attr;
    }

    sub set_category_designers {
        my ( $self, $attr, $params ) = @_;
        my $schema  = $self->get_schema;

        # first remove all designers from category
        my $attr_values = $schema->resultset('Designer::AttributeValue')->search( { 'attribute_id' => $attr->id, 'deleted' => 0 } );
        my @attr_val_ids;
        while (my $record = $attr_values->next) {
            $record->update({ deleted => 1 });
            push @attr_val_ids, $record->id;
        }

        # then add the new ones
        foreach my $designer_name (@{$params->{designers}}){
            my $dc = $schema->resultset('Public::DesignerChannel')->search(
                { 'designer.designer' => $designer_name,
                  'channel_id'        => $params->{channel_id},
                },
                { join => 'designer'} )->first;
            die "Designer $designer_name not found on channel $params->{channel_id}" unless $dc;

            my $record = $schema->resultset('Designer::AttributeValue')->search({
                'designer_id'   => $dc->designer_id,
                'attribute_id'  => $attr->id,
            })->first;

            if ($record){
                $record->update({ deleted => 0 });
            } else {
                $record = $schema->resultset('Designer::AttributeValue')->create({
                    'designer_id'   => $dc->designer_id,
                    'attribute_id'  => $attr->id,
                });
            }
            push @attr_val_ids, $record->id;
        }

        # update the website for all attribuet_calues changed
        transfer_designer_data({
            dbh_ref             => $params->{transfer_dbh_ref},
            transfer_category   => 'designer_attribute_value',
            ids                 => \@attr_val_ids,
            sql_action_ref      => {'insert' => 1},
        }) if scalar @attr_val_ids;
    }


    sub delete_category {
        my( $self, $params ) = @_;
        my $schema  = $self->get_schema;

        my $expected_keys = [qw(name
                                channel_id
                                operator_id
                                transfer_dbh_ref)];
        foreach (@$expected_keys){
            die ("$_ not specified in designer delete_attribute") unless defined $params->{$_};
        }


        # get db record for attribute
        my $attribute = $schema->resultset('Designer::Attribute')->search( {
                            'UPPER(name)'       => uc($params->{name}),
                            'channel_id'        => $params->{channel_id},
                        })->first;
        return unless $attribute;


        # set deleted flag
        $attribute->update({ deleted => 1 });


        # get all attribute value records for this attribute that haven't already been deleted
        my $attr_values = $schema->resultset('Designer::AttributeValue')->search( { 'attribute_id' => $attribute->id, 'deleted' => 0 } );

        # loop through records and set deleted flag
        my @attr_val_ids;
        while (my $record = $attr_values->next) {
            $record->update({ deleted => 1 });
            push @attr_val_ids, $record->id;
        }

        if ( @attr_val_ids ) {
            # update website
            transfer_designer_data({
                dbh_ref             => $params->{transfer_dbh_ref},
                transfer_category   => 'designer_attribute_value',
                ids                 => \@attr_val_ids,
                sql_action_ref      => {'insert' => 1},
            });
        }
    }

    sub _find_designer_root {
        my( $self, $channel_id ) = @_;

        my $schema  = $self->get_schema;

        my $attr = $schema->resultset('Product::Attribute')->search({
            'name' => 'Designer',
            'attribute_type_id' => 0,
            'channel_id' => $channel_id,
        });
        if ($attr->first) {
            my $nav = $schema->resultset('Product::NavigationTree')->search({
                'attribute_id' => $attr->first->id,
            });
            if ($nav->first) {
                return $nav->first->id;
            }
        }
        return;
    }


}


1;

__END__

=pod

=head1 NAME

XTracker::DB::Factory::Designer

=head1 DESCRIPTION

=head1 SYNOPSIS


=head1 AUTHOR

Ben Galbraith C<< <ben.galbraith@net-a-porter.com> >>

=cut
