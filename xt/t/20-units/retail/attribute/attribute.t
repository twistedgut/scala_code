#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;
use Test::XTracker::Data;
use Test::MockObject;

use Test::XT::BlankDB;

# evil globals
our ($schema);
our (%columns);
our ($channel_id);

BEGIN {
 %columns = (
     attrib_types => [ qw( id name web_attribute navigational ) ],
     get_attribs => [ qw( id name attribute_type_id deleted synonyms manual_sort page_id channel_id type ) ],
     get_attribute => [ qw( id name attribute_type_id deleted synonyms manual_sort page_id type ) ],
 );

 plan tests => 69;

 use_ok('XTracker::Database',':common');
 use_ok('XTracker::Schema');
 use_ok('XTracker::Handler');
 use_ok('XTracker::Constants',qw( :application ) );
 use_ok('XTracker::DB::Factory::ProductAttribute');
}

# get a schema to query
$schema = Test::XTracker::Data->get_schema;
isa_ok($schema, 'XTracker::Schema',"Schema Created");

# set sales channel to be NET-A-PORTER
$channel_id = $schema->resultset('Public::Channel')->search(
    {
        'business.config_section' => 'NAP'
    },
    {
        join => [ 'business' ]
    }
)->first->id;
cmp_ok($channel_id,">",0,"Found Sales Channel");

my $attrtype_rs = $schema->resultset('Product::AttributeType');
isa_ok($attrtype_rs, 'DBIx::Class::ResultSet',"Attribute Type Result Set");

my $attr_rs = $schema->resultset('Product::Attribute');
isa_ok($attr_rs, 'DBIx::Class::ResultSet',"Attribute Result Set");

my $attrval_rs = $schema->resultset('Product::AttributeValue');
isa_ok($attrval_rs, 'DBIx::Class::ResultSet',"Attribute Value Result Set");

my $factory =  XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });
isa_ok($factory,'XTracker::DB::Factory::ProductAttribute',"Attribute Factory Set");


#--------------- Run TESTS ---------------

_test_passive_factory_not_blankdb_dependant(1);
_test_passive_factory_blankdb_dependant(! Test::XT::BlankDB::check_blank_db($schema));
_test_create_attrib(1);
_test_create_nav_level_3(1);

_check_stuff_out(0);

#--------------- END TESTS ---------------

#----------------------- Test Functions -----------------------

### test reading basic attribute data
sub _test_passive_factory_not_blankdb_dependant {

  SKIP: {
        skip '_test_passive_factory_not_blankdb_dependant',5 if (!shift);

        my $attr_types = $factory->get_attribute_types( { 'navigational' => 0 } );
        isa_ok($attr_types,'DBIx::Class::ResultSet',"Attribute Type List");
        my $count = $attr_types->count;
        cmp_ok($count,">",1,"Attribute Type List Count");
        my $rec = $attr_types->first;
        isa_ok($rec,'XTracker::Schema::Result::Product::AttributeType',"Attribute Type Record");
        my @columns = $rec->result_source->columns;
        is_deeply(\@columns,$columns{attrib_types},"Attribute Type Columns");
        while ( $rec = $attr_types->next() ) {
            if ( $rec->web_attribute eq "CUSTOM_LIST" ) {
                last;
            }
        }

        my $attribs = $factory->get_attributes({ attribute_type_id => $rec->id, deleted => 0, channel_id => $channel_id });
        isa_ok($attribs,'DBIx::Class::ResultSet',"Attributes List");
    }
    ;
}
sub _test_passive_factory_blankdb_dependant {

  SKIP: {
        skip '_test_passive_factory_blankdb_dependant',6 if (!shift);

        my $attr_types = $factory->get_attribute_types( { 'navigational' => 0 } );
        my $rec = $attr_types->first;

        my $attribs = $factory->get_attributes({ attribute_type_id => $rec->id, deleted => 0, channel_id => $channel_id });
        isa_ok($attribs,'DBIx::Class::ResultSet',"Attributes List");
        my $count = $attribs->count;
        cmp_ok($count,">",1,"Attribute List Count");
        $rec = $attribs->first;
        isa_ok($rec,'XTracker::Schema::Result::Product::Attribute',"Attribute Record");
        foreach my $col ( @{ $columns{get_attribs} } ) {
            $rec->get_column($col);
        }
        pass("Get Attributes Columns");

        my $attrib = $factory->get_attribute({ attribute_name => $rec->name, channel_id => $rec->channel_id, attribute_type => $rec->get_column('type') });
        isa_ok($attrib,'XTracker::Schema::Result::Product::Attribute',"Get Specific Attribute");
        foreach my $col ( @{ $columns{get_attribute} } ) {
            $attrib->get_column($col);
        }
        pass("Get Attribute Columns");
    }
    ;
}

### test creating retail attributes
sub _test_create_attrib {

  SKIP: {
        skip '_test_create_attrib',21 if (!shift);

        my $cl_atype_1;
        my $cl_atype_2;
        my $wn_atype;
        my $rec;

        my $attr_types = $factory->get_attribute_types( { 'navigational' => 0 } );
        isa_ok($attr_types,'DBIx::Class::ResultSet',"Attribute Type List");
        while ( $rec = $attr_types->next() ) {
            if ( $rec->web_attribute eq "CUSTOM_LIST" ) {
                $cl_atype_2 = $rec if ( !defined $cl_atype_2 && defined $cl_atype_1 );
                $cl_atype_1 = $rec if ( !defined $cl_atype_1 );
            }
            if ( $rec->web_attribute eq "WHATS_NEW" ) {
                $wn_atype = $rec if ( !defined $wn_atype );
            }
        }
        my @columns = $cl_atype_1->result_source->columns;
        is_deeply(\@columns,$columns{attrib_types},"Custom List 1 Type Columns");
        @columns = $cl_atype_2->result_source->columns;
        is_deeply(\@columns,$columns{attrib_types},"Custom List 2 Type Columns");
        @columns = $wn_atype->result_source->columns;
        is_deeply(\@columns,$columns{attrib_types},"Whats New List Type Columns");

        my $test_attr_name = 'Test Attrib ' . $$;
        my $test_name = $test_attr_name;
        $test_name =~ s/ /_/g;

        my $new_attr_id_1 = 0;
        my $new_attr_id_2 = 0;
        my $new_attr_id_3 = 0;
        my $dupe_attr_id = 0;

        my $max_attr_id = $attr_rs->get_column('id')->max || 0; # hack for the blank db

        # create new attribs all with the same name
        $schema->txn_do( sub {

                             # create a new attribute
                             eval{ $new_attr_id_1 = $factory->create_attribute( $test_attr_name, $cl_atype_1->id, $channel_id, undef ); };
                             $new_attr_id_1 = $attr_rs->get_column('id')->max;
                             cmp_ok($new_attr_id_1,'>',$max_attr_id,'Created New Attribute 1');
                             $max_attr_id = $new_attr_id_1;

                             # check name has been created properly and spaces replaced with underscores
                             $rec = $attr_rs->find($new_attr_id_1);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','New Attribute Record Found');
                             is($rec->name,$test_name,'Attribute Created & Name Parsed Correctly');

                             # create the same attribute again, no increase in max id should occur
                             eval{ $dupe_attr_id = $factory->create_attribute( $test_attr_name, $cl_atype_1->id, $channel_id, undef ); };
                             $dupe_attr_id = $attr_rs->get_column('id')->max;
                             cmp_ok($dupe_attr_id ,'==',$new_attr_id_1,'Created Dupe Attribute with Same Type & Web Attribute');

                             # create a second new attribute with the same Attr Type but with a different Web Attribute, Max Id should not increase
                             eval{ $new_attr_id_2 = $factory->create_attribute( $test_attr_name, $cl_atype_2->id, $channel_id, undef ); };
                             like($@,qr/already Exists in/,"Got 'Attribute Already Exists' Message");
                             $new_attr_id_2 = $attr_rs->get_column('id')->max;
                             cmp_ok($new_attr_id_2,'==',$new_attr_id_1,"Didn't Create New Attribute 2 with Different Type but Same Web Attribute");

                             # create a third new attribute with different Attr Type & Web Attribute, Max Id should increase
                             eval{ $new_attr_id_3 = $factory->create_attribute( $test_attr_name, $wn_atype->id, $channel_id, undef ); };
                             $new_attr_id_3 = $attr_rs->get_column('id')->max;
                             cmp_ok($new_attr_id_3,'>',$max_attr_id,'Created New Attribute 3 with Different Type & Web Attribute');
                             $max_attr_id = $new_attr_id_3;

                             # delete the 1st new attribute, del flag should be set to 1
                             eval{ $factory->delete_attribute( $new_attr_id_1, $channel_id, undef, $APPLICATION_OPERATOR_ID ); };
                             $rec = $attr_rs->find($new_attr_id_1);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','Del Attribute 1 Record Found');
                             cmp_ok($rec->deleted,'==',1,'Attribute Record 1 Deleted');

                             # resurect the 1st new attribute, max id should not increase, search for first id & del flag should be set to zero
                             eval{ $dupe_attr_id = $factory->create_attribute( $test_attr_name, $cl_atype_1->id, $channel_id, undef ); };
                             $dupe_attr_id = $attr_rs->get_column('id')->max;
                             cmp_ok($dupe_attr_id ,'==',$new_attr_id_3,'Max Id Still the Same as New Attrib 3');
                             $rec = $attr_rs->find($new_attr_id_1);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','Duplicate Attribute Record Found');
                             cmp_ok($rec->deleted,'==',0,'Attribute Record 1 Un-Deleted');

                             # delete the 1st attribute again
                             eval{ $factory->delete_attribute( $new_attr_id_1, $channel_id, undef, $APPLICATION_OPERATOR_ID ); };
                             $rec = $attr_rs->find($new_attr_id_1);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','Del Duplicate Attribute Record Found');
                             cmp_ok($rec->deleted,'==',1,'Duplicate Attribute Record Deleted');

                             # now attribute 1 is deleted attribute 2 can be created
                             # create a second new attribute with the same Attr Type but with a different Web Attribute, Max Id should increase
                             eval{ $new_attr_id_2 = $factory->create_attribute( $test_attr_name, $cl_atype_2->id, $channel_id, undef ); };
                             $new_attr_id_2 = $attr_rs->get_column('id')->max;
                             cmp_ok($new_attr_id_2,'>',$max_attr_id,'Created New Attribute 2 with Different Type but Same Web Attribute');
                             $max_attr_id = $new_attr_id_2;

                             # delete the 2nd new attribute created
                             eval{ $factory->delete_attribute( $new_attr_id_2, $channel_id, undef, $APPLICATION_OPERATOR_ID ); };
                             $rec = $attr_rs->find($new_attr_id_2);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','Del Attribute 2 Record Found');
                             cmp_ok($rec->deleted,'==',1,'Attribute Record 2 Deleted');

                             # delete the 3rd new attribute created
                             eval{ $factory->delete_attribute( $new_attr_id_3, $channel_id, undef, $APPLICATION_OPERATOR_ID ); };
                             $rec = $attr_rs->find($new_attr_id_3);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','Del Attribute 3 Record Found');
                             cmp_ok($rec->deleted,'==',1,'Attribute Record 3 Deleted');

                             $schema->txn_rollback;
                         } );
    }
    ;

}

### test Sub-Types and Hierarchies
sub _test_create_nav_level_3 {

  SKIP: {
        skip '_test_create_nav_level_3',22 if (!shift);

        my $nl3_subtype;
        my $nl3_hierarchy;
        my $rec;

        my $attr_types = $factory->get_attribute_types();
        isa_ok($attr_types,'DBIx::Class::ResultSet',"Attribute Type List");
        while ( $rec = $attr_types->next() ) {
            if ( $rec->web_attribute eq "NAV_LEVEL3" && $rec->navigational ) {
                $nl3_subtype= $rec;
            }
            if ( $rec->web_attribute eq "NAV_LEVEL3" && !$rec->navigational ) {
                $nl3_hierarchy= $rec;
            }
        }
        my @columns = $nl3_subtype->result_source->columns;
        is_deeply(\@columns,$columns{attrib_types},"Sub-Type Columns");
        @columns = $nl3_hierarchy->result_source->columns;
        is_deeply(\@columns,$columns{attrib_types},"Hierarchy Columns");

        # set-up a test name and also a underscore version to test it has been created properly
        my $test_attr_name = 'Test Nav Level 3 ' . $$;
        my $test_name = $test_attr_name;
        $test_name =~ s/ /_/g;

        my $dupe_attr_id = 0;
        my $new_nl3_cat_id = 0;
        my $new_nl3_hir_id  = 0;
        my $max_attr_id = $attr_rs->get_column('id')->max || 0;

        ### First Create New Sub-Type then Hierarchy with the same name
        $schema->txn_do( sub {

                             # create a new sub-type, max id should have increased
                             eval{ $factory->create_attribute( $test_attr_name, $nl3_subtype->id, $channel_id, undef ); };
                             $new_nl3_cat_id= $attr_rs->get_column('id')->max;
                             cmp_ok($new_nl3_cat_id,'>',$max_attr_id,'Pass 1 Created New Sub-Type Attribute');
                             $max_attr_id = $new_nl3_cat_id;

                             # check name has been created properly and spaces replaced with underscores
                             $rec = $attr_rs->find($new_nl3_cat_id);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','New Attribute Record Found');
                             is($rec->name,$test_name,'Sub-Type Created & Name Parsed Correctly');

                             # create a new hierarchy with same name as above sub-type, should be created and max id have increased
                             eval{ $factory->create_attribute( $test_attr_name, $nl3_hierarchy->id, $channel_id, undef ); };
                             $new_nl3_hir_id= $attr_rs->get_column('id')->max;
                             cmp_ok($new_nl3_hir_id,'>',$max_attr_id,'Pass 1 Created New Hierarchy Attribute');
                             $max_attr_id    = $new_nl3_hir_id;

                             # delete the Sub-Type attribute created
                             eval{ $factory->delete_attribute( $new_nl3_cat_id, $channel_id, undef, $APPLICATION_OPERATOR_ID ); };
                             $rec = $attr_rs->find($new_nl3_cat_id);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','Pass 1 Del Sub-Type Attribute Record Found');
                             cmp_ok($rec->deleted,'==',1,'Pass 1 Sub-Type Attribute Record Deleted');

                             # create a new hierarchy with same name as above sub-type, should re-use the existing hirarchy
                             # and max id should not increase
                             eval{ $factory->create_attribute( $test_attr_name, $nl3_hierarchy->id, $channel_id, undef ); };
                             $new_nl3_hir_id= $attr_rs->get_column('id')->max;
                             cmp_ok($new_nl3_hir_id,'==',$max_attr_id,'Pass 1 Re-used Hierarchy Attribute (2)');

                             # delete the Hierarchy attribute created
                             eval{ $factory->delete_attribute( $new_nl3_hir_id, $channel_id, undef, $APPLICATION_OPERATOR_ID ); };
                             $rec = $attr_rs->find($new_nl3_hir_id);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','Pass 1 Del Hierarchy Attribute Record Found');
                             cmp_ok($rec->deleted,'==',1,'Pass 1 Hierarchy Attribute Record Deleted');

                             $schema->txn_rollback;
                         } );

        ### Second Create New Hierarchy then Sub-Type with the same name
        $schema->txn_do( sub {

                             $max_attr_id = $attr_rs->get_column('id')->max || 0;
                             # create a new hierarchy, max id should have increased
                             eval{ $factory->create_attribute( $test_attr_name, $nl3_hierarchy->id, $channel_id, undef ); };
                             $new_nl3_hir_id= $attr_rs->get_column('id')->max;
                             cmp_ok($new_nl3_hir_id,'>',$max_attr_id,'Pass 2 Created New Hierarchy Attribute');
                             $max_attr_id = $new_nl3_hir_id;

                             # create a new sub-type with same name as above hierarchy, should be created and max id increased
                             eval{ $factory->create_attribute( $test_attr_name, $nl3_subtype->id, $channel_id, undef ); };
                             $new_nl3_cat_id= $attr_rs->get_column('id')->max;
                             cmp_ok($new_nl3_cat_id,'>',$max_attr_id,'Pass 2 Created New Sub-Type Attribute');
                             $max_attr_id    = $new_nl3_cat_id;

                             # delete the Hierarchy attribute created
                             eval{ $factory->delete_attribute( $new_nl3_hir_id, $channel_id, undef, $APPLICATION_OPERATOR_ID ); };
                             $rec = $attr_rs->find($new_nl3_hir_id);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','Pass 2 Del Hierarchy Attribute Record Found');
                             cmp_ok($rec->deleted,'==',1,'Pass 2 Hierarchy Attribute Record Deleted');

                             # create a new sub-type with same name as above hierarchy, should reuse the existing and max id should have increased
                             eval{ $factory->create_attribute( $test_attr_name, $nl3_subtype->id, $channel_id, undef ); };
                             $new_nl3_cat_id= $attr_rs->get_column('id')->max;
                             cmp_ok($new_nl3_cat_id,'==',$max_attr_id,'Pass 2 Re-used Sub-Type Attribute (2)');

                             # delete the Sub-Type attribute created
                             eval{ $factory->delete_attribute( $new_nl3_cat_id, $channel_id, undef, $APPLICATION_OPERATOR_ID ); };
                             $rec = $attr_rs->find($new_nl3_cat_id);
                             isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','Pass 2 Del Sub-Type Attribute Record Found');
                             cmp_ok($rec->deleted,'==',1,'Pass 2 Sub-Type Attribute Record Deleted');

                             $schema->txn_rollback;
                         } );
    }
    ;
}

### used to check stuff works
sub _check_stuff_out {

  SKIP: {
        skip '_check_stuff_out',5 if (!shift);

        my $type_grp= $schema->resultset('Product::AttributeType')->find(13);
        isa_ok($type_grp,'XTracker::Schema::Result::Product::AttributeType','Got Attribute Type');
        my $chk_rs  = $schema->resultset('Product::Attribute')->search( {
            'UPPER(me.name)' => uc('Cocktail_Cool'),
            'me.channel_id' => 1,
            'me.deleted' => 0,
            'me.attribute_type_id' => { '!=' => 13 },
            'type.web_attribute' => $type_grp->web_attribute
        },
                                                                        {
                                                                            'join' => [ qw( type ) ],
                                                                            '+select' => [ 'type.name' ],
                                                                            '+as' => [ 'attribute_type_name' ]
                                                                        } );
        isa_ok($chk_rs,'DBIx::Class::ResultSet','Got Check Attribute List by Group');
        my $chk_rec = $chk_rs->first();
        isa_ok($chk_rec,'XTracker::Schema::Result::Product::Attribute','Got Check Attribute List by Group Record');
        $chk_rec->get_column('attribute_type_name');

        my $rs = $schema->resultset('Product::Attribute')->search( {
            'UPPER(name)'       => uc('Ankle_Boots'),
            'attribute_type_id' => 13,
            'channel_id'        => 1
        } );
        isa_ok($rs,'DBIx::Class::ResultSet','Got Search List by Attribute Type');
        my $rec = $rs->next();
        isa_ok($rec,'XTracker::Schema::Result::Product::Attribute','Got Search List by Attribute Type Record');
    }
    ;
}
