use utf8;
package XTracker::Schema::Result::Public::MarketingPromotion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.marketing_promotion");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "marketing_promotion_id_seq",
  },
  "title",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "start_date",
  { data_type => "timestamp with time zone", is_nullable => 0 },
  "end_date",
  { data_type => "timestamp with time zone", is_nullable => 0 },
  "enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "is_sent_once",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "message",
  { data_type => "text", is_nullable => 0 },
  "created_date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "promotion_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_marketing_promotion__countries",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionCountry",
  { "foreign.marketing_promotion_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__customer_categories",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionCustomerCategory",
  { "foreign.marketing_promotion_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__customer_segments",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionCustomerSegment",
  { "foreign.marketing_promotion_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__designers",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionDesigner",
  { "foreign.marketing_promotion_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__gender_proxies",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionGenderProxy",
  { "foreign.marketing_promotion_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__languages",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionLanguage",
  { "foreign.marketing_promotion_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__product_types",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionProductType",
  { "foreign.marketing_promotion_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_orders__marketing_promotions",
  "XTracker::Schema::Result::Public::LinkOrdersMarketingPromotion",
  { "foreign.marketing_promotion_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "marketing_promotion_logs",
  "XTracker::Schema::Result::Public::MarketingPromotionLog",
  { "foreign.marketing_promotion_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "promotion_type",
  "XTracker::Schema::Result::Public::PromotionType",
  { id => "promotion_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PXdp35/qwsUucKx54U0DJQ


use XTracker::Logfile           qw( xt_logger );

use Carp;


=head2 has_designers_assigned

    $boolean = $self->has_designers_assigned;

Returns TRUE or FALSE based on whether any Designers are actually assigned to the Promotion.

=cut

sub has_designers_assigned {
    my $self    = shift;
    return (
            $self->link_marketing_promotion__designers->count()
            ? 1
            : 0
        );
}

=head2 can_designers_be_applied_to_order

    $boolean    = $self->can_designers_be_applied_to_order;

Returns TRUE or FALSE as to whether a Promotion can be applied to an Order based on
the Designers linked to the Promotion.

=cut

sub can_designers_be_applied_to_order {
    my ( $self, $order )    = @_;

    # get all Non-Cancelled Shipment Items
    my @items   = $order->get_standard_class_shipment
                            ->shipment_items
                                ->not_cancelled
                                ->not_cancel_pending
                                    ->all;

    # get all Designers for the Products
    my @designer_ids = ();
    foreach my $item (@items){
        if( defined $item->variant ){
            push @designer_ids, $item->variant->product->designer_id;
        }
    }

    my $designer_count  = $self->link_marketing_promotion__designers
                                    ->get_included_designers
                                        ->search( { id => { 'IN' => \@designer_ids } } )
                                            ->count;

    # any Designers match then return TRUE
    return ( $designer_count ? 1 : 0 );
}

=head2 has_customer_segment_assigned

    $boolean = $self->has_customer_segment_assigned;

Return TRUE or FALSE based on whether any Active Customer Segments are assigned to the Promotion

=cut

sub has_customer_segment_assigned {
    my $self = shift;

    my $count = $self->link_marketing_promotion__customer_segments
                      ->get_active_segments
                       ->count();

    return ( $count ? 1 : 0 );

}

=head2 can_customer_segment_be_applied_to_order

    $boolean    = $self->can_customer_segment_be_applied_to_order;

Returns TRUE or FALSE as to whether a Promotion can be applied to an Order based on
customer_id  belonging to any Active  Customer Segments linked to Promotion.

=cut

sub can_customer_segment_be_applied_to_order {
    my ($self, $order ) = @_;

    my $order_customer_id = $order->customer_id;
    my $segment_rs = $self->link_marketing_promotion__customer_segments
          ->get_active_segments;

   my $count =  $segment_rs->search_related_rs('link_marketing_customer_segment__customers',{
            customer_id => $order_customer_id,
        })->count();


    $count > 0 ? return 1 : return 0;

}

=head2 has_countries_assigned

    $boolean = $self->has_countries_assigned;

Returns TRUE or FALSE based on whether any Countries are actually assigned to the Promotion.

=cut

sub has_countries_assigned {
    my $self    = shift;
    return $self->_has_option_assigned('countries');
}

=head2 can_countries_be_applied_to_order

    $boolean    = $self->can_countries_be_applied_to_order;

Returns TRUE or FALSE as to whether a Promotion can be applied to an Order based on
the Countries linked to the Promotion.

=cut

sub can_countries_be_applied_to_order {
    my ( $self, $order )    = @_;

    my $country_rec = $order->get_standard_class_shipment
                                ->shipment_address
                                    ->country_ignore_case;
    return 0        if ( !$country_rec );

    my $count   = $self->link_marketing_promotion__countries
                        ->get_included_countries
                            ->search( { id => $country_rec->id } )
                                ->count;

    return ( $count ? 1 : 0 );
}

=head2 has_languages_assigned

    $boolean = $self->has_languages_assigned;

Returns TRUE or FALSE based on whether any Languages are actually assigned to the Promotion.

=cut

sub has_languages_assigned {
    my $self    = shift;
    return $self->_has_option_assigned('languages');
}

=head2 can_languages_be_applied_to_order

    $boolean    = $self->can_languages_be_applied_to_order;

Returns TRUE or FALSE as to whether a Promotion can be applied to an Order based on
the Languages linked to the Promotion.

=cut

sub can_languages_be_applied_to_order {
    my ( $self, $order )    = @_;

    my $lang_preference = $order->customer->get_language_preference;
    return 0            if ( !$lang_preference );

    my $count   = $self->link_marketing_promotion__languages
                        ->get_included_languages
                            ->search( { id => $lang_preference->{language}->id } )
                                ->count;

    return ( $count ? 1 : 0 );
}

=head2 has_product_types_assigned

    $boolean = $self->has_product_types_assigned;

Returns TRUE or FALSE based on whether any Product Types are actually assigned to the Promotion.

=cut

sub has_product_types_assigned {
    my $self    = shift;
    return $self->_has_option_assigned('product_types');
}

=head2 can_product_types_be_applied_to_order

    $boolean    = $self->can_product_types_be_applied_to_order;

Returns TRUE or FALSE as to whether a Promotion can be applied to an Order based on
the Product Types linked to the Promotion.

=cut

sub can_product_types_be_applied_to_order {
    my ( $self, $order )    = @_;

    # get all Non-Cancelled Shipment Items
    my @items   = $order->get_standard_class_shipment
                            ->shipment_items
                                ->not_cancelled
                                ->not_cancel_pending
                                    ->all;

    # get all Product Types for the Products
    my @product_type_ids = ();
    foreach my $item (@items){
        if( defined $item->variant ){
            push @product_type_ids, $item->variant->product->product_type_id;
        }
    }

    my $count   = $self->link_marketing_promotion__product_types
                        ->get_included_product_types
                            ->search( { id => { 'IN' => \@product_type_ids } } )
                                ->count;

    return ( $count ? 1 : 0 );
}

=head2 has_gender_titles_assigned

    $boolean = $self->has_gender_titles_assigned;

Returns TRUE or FALSE based on whether any Titles used to determin a Customer's Gender
are actually assigned to the Promotion.

=cut

sub has_gender_titles_assigned {
    my $self    = shift;
    return $self->_has_option_assigned('gender_proxies');
}

=head2 can_gender_titles_be_applied_to_order

    $boolean    = $self->can_gender_titles_be_applied_to_order;

Returns TRUE or FALSE as to whether a Promotion can be applied to an Order based on
the Gender Titles linked to the Promotion.

=cut

sub can_gender_titles_be_applied_to_order {
    my ( $self, $order )    = @_;

    my $schema      = $self->result_source->schema;

    # if the Shipping Address has a Title then
    # use it, else check the Customer Record
    my $cust_title  = $order->get_standard_class_shipment->shipment_address->title;
    $cust_title     = $order->customer->title   if ( !defined $cust_title || $cust_title eq '' );

    # get the Record that matches the Customer's Title
    my $title_rec   = $schema->resultset('Public::MarketingGenderProxy')->search( {
        title => { ILIKE => ( $cust_title // '' ) },
    } )->first;
    # if NO record has been found then no point in continuing
    return 0        if ( !$title_rec );

    my $count   = $self->link_marketing_promotion__gender_proxies
                        ->get_included_titles
                            ->search( { id => $title_rec->id } )
                                ->count;

    return ( $count ? 1 : 0 );
}

=head2 has_customer_categories_assigned

    $boolean = $self->has_customer_categories_assigned;

Returns TRUE or FALSE based on whether any Categories are actually assigned to the Promotion.

=cut

sub has_customer_categories_assigned {
    my $self    = shift;
    return $self->_has_option_assigned('customer_categories');
}

=head2 can_customer_categories_be_applied_to_order

    $boolean    = $self->can_customer_categories_be_applied_to_order;

Returns TRUE or FALSE as to whether a Promotion can be applied to an Order based on
the Categories linked to the Promotion.

=cut

sub can_customer_categories_be_applied_to_order {
    my ( $self, $order )    = @_;

    my $cust_category_id = $order->customer->category_id;
    return 0            if ( !$cust_category_id );

    my $count = $self->link_marketing_promotion__customer_categories
                        ->get_included_customer_categories
                            ->search( { id => $cust_category_id } )
                                ->count;

    return ( $count ? 1 : 0 );
}

=head2 is_weighted

    my $marketing_promotion = $schema->resultset('Public::MarketingPromotion')->find( $id );
    my $boolean = $marketing_promotion->is_weighted;

=cut

sub is_weighted {
    my $self = shift;

    # A Marketing Promotion is weighted only if it's associated with a Promotion Type,
    # un-weighted Marketing Promotions do not have this link.
    return defined $self->promotion_type_id
        ? 1
        : 0;

}

=head2 assign_designers

    $self->assign_designers( [ $designer_id, $designer_id, ... ] );

=cut

sub assign_designers {
    my ( $self, $ids )  = @_;

    return $self->_assign_option_to_promotion(
        'link_marketing_promotion__designers',
        'designer_id',
        $ids
    );
}

=head2 reassign_designers

    $self->reassign_designers( [ $designer_id, $designer_id, ... ] );

This will Re-Assign Designers to the Promotion which means it will first
Remove currently assigned Designers and then Assign those passed in. To
completely Remove ALL Designers from the Promotion then don't pass in an
Array Ref. of Ids.

=cut

sub reassign_designers {
    my ( $self, $ids )  = @_;

    xt_logger->debug("Re-Assigning Designers");

    $self->link_marketing_promotion__designers->delete;
    return $self->assign_designers( $ids );
}

=head2 assign_customer_segments

    $self->assign_customer_segments( [ $segment_id, $segment_id, ... ] );

=cut

sub assign_customer_segments {
    my ( $self, $ids )  = @_;

    return $self->_assign_option_to_promotion(
        'link_marketing_promotion__customer_segments',
        'customer_segment_id',
        $ids
    );
}

=head2 reassign_customer_segments

    $self->reassign_customer_segments( [ $segment_id, $segment_id, ... ] );

This will Re-Assign Customer Segments to the Promotion which means it will first
Remove currently assigned Customer Segments and then Assign those passed in. To
completely Remove ALL Customer Segments from the Promotion then don't pass in an
Array Ref. of Ids.

=cut

sub reassign_customer_segments {
    my ( $self, $ids )  = @_;

    xt_logger->debug("Re-Assigning Customer Segments");

    $self->link_marketing_promotion__customer_segments->delete;
    return $self->assign_customer_segments( $ids );
}

=head2 assign_countries

    $self->assign_countries( [ $country_id, $country_id, ... ] );

=cut

sub assign_countries {
    my ( $self, $ids )  = @_;

    return $self->_assign_option_to_promotion(
        'link_marketing_promotion__countries',
        'country_id',
        $ids
    );
}

=head2 reassign_countries

    $self->reassign_countries( [ $country_id, $country_id, ... ] );

This will Re-Assign Countries to the Promotion which means it will first
Remove currently assigned Countries and then Assign those passed in. To
completely Remove ALL Countries from the Promotion then don't pass in an
Array Ref. of Ids.

=cut

sub reassign_countries {
    my ( $self, $ids )  = @_;

    xt_logger->debug("Re-Assigning Countries");

    $self->link_marketing_promotion__countries->delete;
    return $self->assign_countries( $ids );
}


=head2 assign_languages

    $self->assign_languages( [ $language_id, $language_id, ... ] );

=cut

sub assign_languages {
    my ( $self, $ids )  = @_;

    return $self->_assign_option_to_promotion(
        'link_marketing_promotion__languages',
        'language_id',
        $ids
    );
}

=head2 reassign_languages

    $self->reassign_languages( [ $language_id, $language_id, ... ] );

This will Re-Assign Languages to the Promotion which means it will first
Remove currently assigned Languages and then Assign those passed in. To
completely Remove ALL Languages from the Promotion then don't pass in an
Array Ref. of Ids.

=cut

sub reassign_languages {
    my ( $self, $ids )  = @_;

    xt_logger->debug("Re-Assigning Languages");

    $self->link_marketing_promotion__languages->delete;
    return $self->assign_languages( $ids );
}

=head2 assign_product_types

    $self->assign_product_types( [ $product_type_id, $product_type_id, ... ] );

=cut

sub assign_product_types {
    my ( $self, $ids )  = @_;

    return $self->_assign_option_to_promotion(
        'link_marketing_promotion__product_types',
        'product_type_id',
        $ids
    );
}

=head2 reassign_product_types

    $self->reassign_product_types( [ $product_type_id, $product_type_id, ... ] );

This will Re-Assign Product Types to the Promotion which means it will first
Remove currently assigned Product Types and then Assign those passed in. To
completely Remove ALL Product Types from the Promotion then don't pass in an
Array Ref. of Ids.

=cut

sub reassign_product_types {
    my ( $self, $ids )  = @_;

    xt_logger->debug("Re-Assigning Product Types");

    $self->link_marketing_promotion__product_types->delete;
    return $self->assign_product_types( $ids );
}

=head2 assign_gender_titles

    $self->assign_gender_titles( [ $gender_title_id, $gender_title_id, ... ] );

=cut

sub assign_gender_titles {
    my ( $self, $ids )  = @_;

    return $self->_assign_option_to_promotion(
        'link_marketing_promotion__gender_proxies',
        'gender_proxy_id',
        $ids
    );
}

=head2 reassign_gender_titles

    $self->reassign_gender_titles( [ $gender_title_id, $gender_title_id, ... ] );

This will Re-Assign Titles to the Promotion which means it will first
Remove currently assigned Titles and then Assign those passed in. To
completely Remove ALL Titles from the Promotion then don't pass in an
Array Ref. of Ids.

=cut

sub reassign_gender_titles {
    my ( $self, $ids )  = @_;

    xt_logger->debug("Re-Assigning Gender Titles");

    $self->link_marketing_promotion__gender_proxies->delete;
    return $self->assign_gender_titles( $ids );
}

=head2 assign_customer_categories

    $self->assign_customer_categories( [ $customer_category_id, $customer_category_id, ... ] );

=cut

sub assign_customer_categories {
    my ( $self, $ids )  = @_;

    return $self->_assign_option_to_promotion(
        'link_marketing_promotion__customer_categories',
        'customer_category_id',
        $ids
    );
}

=head2 reassign_customer_categories

    $self->reassign_customer_categories( [ $customer_category_id, $customer_category_id, ... ] );

This will Re-Assign Customer Categories to the Promotion which means it
will first Remove currently assigned Categories and then Assign those
passed in. To completely Remove ALL Categories from the Promotion then
don't pass in an Array Ref. of Ids.

=cut

sub reassign_customer_categories {
    my ( $self, $ids )  = @_;

    xt_logger->debug("Re-Assigning Customer Categories");

    $self->link_marketing_promotion__customer_categories->delete;
    return $self->assign_customer_categories( $ids );
}


# helper function to add a list of Option Ids such
# as Countries, Languages etc to the Promotion
sub _assign_option_to_promotion {
    my ( $self, $relationship, $id_field_name, $ids )   = @_;

    my $logger  = xt_logger;
    $logger->debug( "Assigning '${relationship}' to Promotion" );

    return      if ( !$ids );

    if ( ref( $ids ) && ref( $ids ) ne 'ARRAY' ) {
        croak "Ids passed NOT in an ARRAY Ref to '" . __PACKAGE__ . "->_assign_option_to_promotion'";
    }

    $ids = [ $ids ]     if ( ref( $ids ) ne 'ARRAY' );

    $logger->debug( "Number of '${relationship}' to Add: '" . @{ $ids } . "'" );

    foreach my $id ( @{ $ids } ) {
        $logger->debug( "Adding: ${id_field_name}: ${id} to Promotion Id: " . $self->id );
        $self->create_related( $relationship, { $id_field_name => $id } );
    }

    return;
}

sub _has_option_assigned {
    my ( $self, $relationship ) = @_;
    $relationship   = "link_marketing_promotion__${relationship}";
    return ( $self->$relationship->count() ? 1 : 0 );
}

1;
