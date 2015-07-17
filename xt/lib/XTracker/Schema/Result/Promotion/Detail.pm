use utf8;
package XTracker::Schema::Result::Promotion::Detail;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.detail");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.detail_id_seq",
  },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "last_modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "last_modified_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "visible_id",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "internal_title",
  { data_type => "varchar", is_nullable => 0, size => 60 },
  "start_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "end_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "target_city_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "enabled",
  { data_type => "boolean", is_nullable => 1 },
  "discount_type",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "discount_percentage",
  { data_type => "integer", is_nullable => 1 },
  "discount_pounds",
  { data_type => "integer", is_nullable => 1 },
  "discount_euros",
  { data_type => "integer", is_nullable => 1 },
  "discount_dollars",
  { data_type => "integer", is_nullable => 1 },
  "coupon_prefix",
  { data_type => "varchar", is_nullable => 1, size => 8 },
  "coupon_target_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "coupon_restriction_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "coupon_generation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "price_group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "basket_trigger_pounds",
  { data_type => "integer", is_nullable => 1 },
  "basket_trigger_euros",
  { data_type => "integer", is_nullable => 1 },
  "basket_trigger_dollars",
  { data_type => "integer", is_nullable => 1 },
  "title",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "subtitle",
  { data_type => "varchar", is_nullable => 1, size => 75 },
  "status_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "been_exported",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "exported_to_lyris",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "restrict_by_weeks",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "restrict_x_weeks",
  { data_type => "integer", default_value => 6, is_nullable => 0 },
  "coupon_custom_limit",
  { data_type => "integer", is_nullable => 1 },
  "event_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "publish_method_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "publish_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "announce_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "close_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "publish_to_announce_visibility",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "announce_to_start_visibility",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "start_to_end_visibility",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "end_to_close_visibility",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "target_value",
  { data_type => "integer", is_nullable => 1 },
  "target_currency",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "product_page_visible",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
  "end_price_drop_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "dont_miss_out",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "sponsor_id",
  { data_type => "integer", is_nullable => 1 },
  "is_classic",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("idx_promotion_detail_visible_id", ["visible_id"]);
__PACKAGE__->add_unique_constraint("idx_promotion_title", ["internal_title"]);
__PACKAGE__->belongs_to(
  "announce_to_start_visibility_obj",
  "XTracker::Schema::Result::Promotion::ProductVisibility",
  { id => "announce_to_start_visibility" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "coupon_generation",
  "XTracker::Schema::Result::Promotion::CouponGeneration",
  { id => "coupon_generation_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "coupon_restriction",
  "XTracker::Schema::Result::Promotion::CouponRestriction",
  { id => "coupon_restriction_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "coupon_target",
  "XTracker::Schema::Result::Promotion::CouponTarget",
  { id => "coupon_target_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "coupons",
  "XTracker::Schema::Result::Promotion::Coupon",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "created_by",
  "XTracker::Schema::Result::Public::Operator",
  { id => "created_by" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "detail_customergroup_joins",
  "XTracker::Schema::Result::Promotion::DetailCustomerGroupJoinListType",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_customergroups",
  "XTracker::Schema::Result::Promotion::DetailCustomerGroup",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_customers",
  "XTracker::Schema::Result::Promotion::DetailCustomer",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_designers",
  "XTracker::Schema::Result::Promotion::DetailDesigners",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_product",
  "XTracker::Schema::Result::Promotion::DetailProduct",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_products",
  "XTracker::Schema::Result::Promotion::DetailProducts",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_producttypes",
  "XTracker::Schema::Result::Promotion::DetailProductTypes",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_seasons",
  "XTracker::Schema::Result::Promotion::DetailSeasons",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_shippingoptions",
  "XTracker::Schema::Result::Promotion::DetailShippingOptions",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_websites",
  "XTracker::Schema::Result::Promotion::DetailWebsites",
  { "foreign.event_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "end_to_close_visibility_obj",
  "XTracker::Schema::Result::Promotion::ProductVisibility",
  { id => "end_to_close_visibility" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "event_type",
  "XTracker::Schema::Result::Promotion::Type",
  { id => "event_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "last_modified_by",
  "XTracker::Schema::Result::Public::Operator",
  { id => "last_modified_by" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "price_group",
  "XTracker::Schema::Result::Promotion::PriceGroup",
  { id => "price_group_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "publish_method",
  "XTracker::Schema::Result::Promotion::PublishMethod",
  { id => "publish_method_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "publish_to_announce_visibility_obj",
  "XTracker::Schema::Result::Promotion::ProductVisibility",
  { id => "publish_to_announce_visibility" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "start_to_end_visibility_obj",
  "XTracker::Schema::Result::Promotion::ProductVisibility",
  { id => "start_to_end_visibility" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Promotion::Status",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "target_city",
  "XTracker::Schema::Result::Promotion::TargetCity",
  { id => "target_city_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "target_currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "target_currency" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+I0a4QH8DGmBTZux7OIVNA

__PACKAGE__->add_unique_constraint(
    unique_title => [ qw/internal_title/ ],
);

__PACKAGE__->many_to_many(
    seasons => 'detail_seasons' => 'season'
);
__PACKAGE__->many_to_many(
    designers => 'detail_designers' => 'designer'
);
__PACKAGE__->many_to_many(
    producttypes => 'detail_producttypes' => 'producttype'
);
__PACKAGE__->many_to_many(
    products => 'detail_products' => 'product'
);
__PACKAGE__->many_to_many(
    customergroups => 'detail_customergroups' => 'customergroup'
);
__PACKAGE__->many_to_many(
    websites => 'detail_websites' => 'website'
);
__PACKAGE__->many_to_many(
    shipping_options => 'detail_shippingoptions' => 'shipping_option'
);


use Data::Dump qw(pp);
use Data::Dumper;
use DateTime;
use DateTime::Format::Pg;
use List::Compare;

use XT::Domain::Messages;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(
    :event_type
    :promotion_coupon_target
    :promotion_customergrouptype
    :promotion_jointype
    :promotion_price_group
    :promotion_status
    :promotion_coupon_generation
);
use XTracker::Database qw ( :common ); # primarily for PWD db connection
use XTracker::EmailFunctions qw( send_email );
use XTracker::Error qw( xt_warn xt_info );
use XTracker::SchemaHelper qw(:records);
use XTracker::Logfile qw(xt_logger);
use XTracker::Promotion::Coupon;
use Try::Tiny;

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw<feedback_message>);


#
## Custom Record-Level Methods
#

sub can_export {
    my $record = shift;

    # XXX this will probably change
    # if we're "Exported" don't allow the tinkers to export us again
    # (we want people to Disable first, hopefully triggering an email alert)
    # .. NO
    # if we've got something queued ... NO
    if (
        ($record->status_id == $PROMOTION_STATUS__EXPORTED_TO_PWS)
        ||
        ($record->status_id == $PROMOTION_STATUS__EXPORTING_TO_PWS)
        ||
        ($record->status_id == $PROMOTION_STATUS__JOB_QUEUED)
    ) {
        return 0;
    }

    # if we require customer groups, and they've not yet been frozen ...
    # then .. NO
    if (
        $record->requires_customer_freeze
    ) {
        #xt_logger->debug($record->title . q{: has c-groups selected, groups not frozen});
        return 0;
    }

    # if we don't require any coupons .. OK
    if (
        (not $record->is_generic_coupon)
            and
        (not $record->is_specific_coupon)
    ) {
        #xt_logger->debug($record->title . q{: no coupons required});
        return 1;
    }

    # if we're GENERIC, have a coupon and haven't been disabled
    # we can export .. OK
    if (
        $record->is_generic_coupon
            and
        $record->has_coupon_codes
            and
        ($record->status_id != $PROMOTION_STATUS__DISABLED)
    ) {
        #xt_logger->debug($result->title . q{: generic, and generated});
        return 1;
    }

    # if we're SPECIFIC, have coupons, don't need any lyris interaction
    # and haven't been disabled .. OK
    if (
        $record->is_specific_coupon
            and
        $record->has_coupon_codes
            and
        (not $record->requires_emails)
            and
        ($record->status_id != $PROMOTION_STATUS__DISABLED)
    ) {
        #xt_logger->debug($result->title . q{: specific, generated, no lyris});
        return 1;
    }

    # if we're specific, have coupons, need lyris interaction, have exported
    # to Lyris AND haven't been disabled .. OK
    if (
        $record->is_specific_coupon
            and
        $record->has_coupon_codes
            and
        $record->requires_emails
            and
        $record->exported_to_lyris
            and
        ($record->status_id != $PROMOTION_STATUS__DISABLED)
    ) {
        #xt_logger->debug($result->title . q{: specific, generated, lyris, data sent});
        return 1;
    }

    # default to "No! You May Not!"
    #xt_logger->debug($result->title . q{: No, you may not!});
    return 0;
}

# FIXME - refactor customergroup_included_id_list and customergroup_excluded_id_list
#   into two smaller functions that call a master one that takes the listtype.name
#   as a parameter

sub applicable_customer_list {
    my $record      = shift;
    my $website_id  = shift;
    my ($included_rs, $excluded_rs);
    my (@customer_is_id_included, @customer_is_id_excluded);
    my ($lc, @customers);

    # get the included custards
    $included_rs = $record->included_customers($website_id);
    while (my $record = $included_rs->next) {
        push @customer_is_id_included, $record->customer_id();
    }

    # get the excluded custards
    $excluded_rs = $record->excluded_customers($website_id);
    while (my $record = $excluded_rs->next) {
        push @customer_is_id_excluded, $record->customer_id();
    }

    # subtract the excluded from the included
    $lc = List::Compare->new( {
        lists    => [\@customer_is_id_included, \@customer_is_id_excluded],
        accelerated => 1,
        unsorted => 1,
    } );
    @customers = $lc->get_unique;

    # voila!
    return \@customers;
}

# work out the PIDs based on information supplied in the "products tab"
sub applicable_product_list {
    my($record) = @_;
    my ($expected_restrictions);
    my $schema = $record->result_source()->schema();
    my @pids = $record->detail_products->get_column('product_id')->all;

    # product_types
    my @prodtypes = $record->detail_producttypes
        ->get_column('producttype_id')->all;
    # seasons
    my @seasons = $record->detail_seasons
        ->get_column('season_id')->all;
    # designers
    my @designers = $record->detail_designers
        ->get_column('designer_id')->all;

    # are we expecting to have a season/designer/type/pid restriction?
    $expected_restrictions =
          scalar @pids
        + scalar @prodtypes
        + scalar @seasons
        + scalar @designers
    ;

    # no products ... no restrictions ... no joins
    # ... no age restriction
    if (
         0 ==
             $expected_restrictions
           + $record->restrict_by_weeks
    ) {
        # no restrictions (by product) were requested
        return [];
    }

    my @channel_ids = $record->detail_websites->get_column('website_id')->all;

    if (scalar @channel_ids == 0) {
        die "No channel. No go!";
    }

    # get the products we've limited to (season/designer/type/pid)
    my $products = $schema->resultset('Public::Product')
        ->get_promotion_products(
            \@channel_ids,
            \@seasons,
            \@designers,
            \@prodtypes,
            \@pids
        );

    # do we need to apply the "X-week rule"?
    if ($record->restrict_by_weeks) {
        xt_logger->info(
              q{Restricting to products that are }
            . $record->restrict_x_weeks
            . q{ week(s) old}
        );

        # if the age is the only restriction, we won't have any products yet
        if (not $expected_restrictions) {
            $products = $schema->resultset('Public::Product')->search();
        }

        # the "interval" for the WHERE clause
        my $interval =
              q{interval '}
            . ($record->restrict_x_weeks || 6) # in case some bugger slips in a zero
            . q{ weeks'}
        ;
        # search our products
        my $channel_ids = join(',',@channel_ids);
        $products = $products->search_related(
            q{product_channel},
            { },
            {
                where   => \"channel_id IN ($channel_ids) AND AGE(product_channel.upload_date) >= $interval",
            }
        );

        # if we expected restrictions, and we don't have any products in our
        # resultset ..
        if (0 == $products->count) {
            # disable the promotion, until investigations are complete
            $record->disable;
            # put something in the logs, in case people actually read it
            xt_logger->error(
                q{Promotion }
                . $record->visible_id
                . q{ has age product restrictions, but an empty resultset. Disabling.}
            );

            # XXX - I'm not sure if [] is an appropriate response
            # (it should be OK with the disabled promotion)
            return [];
        }
    }

    if (defined $products) {
        my @matched =  $products->get_column('me.id')->all;
        my $lc = List::Compare->new({ lists => [ \@pids, \@matched ] });
        my @pid_union = $lc->get_union;

        return \@pid_union;
    }

    return [];
}

sub customergroup_included_id_list {
    my $record = shift;
    my (@ids);

    my $customer_groups = $record->detail_customergroups
        ->search(
            {
                'listtype.name' => 'include'
            },
            {
                prefetch => qw( listtype ),
            }
        );

    while (my $customergroup = $customer_groups->next) {
        push @ids, $customergroup->customergroup_id();
    }

    return wantarray ? @ids : \@ids;
}

sub customergroup_excluded_id_list {
    my $record = shift;
    my (@ids);

    my $customer_groups = $record->detail_customergroups
        ->search(
            {
                'listtype.name' => 'exclude'
            },
            {
                prefetch => qw( listtype ),
            }
        );

    while (my $customergroup = $customer_groups->next) {
        push @ids, $customergroup->customergroup_id();
    }

    return wantarray ? @ids : \@ids;
}

sub customers_of_type {
    my $record      = shift;
    my $listtype    = shift;
    my $website_id  = shift;
    my $schema      = $record->result_source()->schema();

    my ($sub_rs, @group_ids, $rs, $where_clause, $groupjoin);

    # we need the get all records from promotion.customer_customergroup
    # for the current promotion, where the groups are in the include list

    # in psql we did the following .. the trick is to implement it nicely in
    # dbic:
    #   select * from promotion.customer_customergroup
    #   where customergroup_id in
    #   (select customergroup_id from promotion.detail_customergroup
    #   where event_id=1 and listtype_id=1);

    # do the sub-select, and get the IDs
    $sub_rs = $schema->resultset('Promotion::DetailCustomerGroup')
        ->search(
            {
                'event_id'   => $record->id,
                'listtype_id' => $listtype,
            },
        )
    ;
    while (my $rec = $sub_rs->next) { # FIXME with a get_column() call
        push @group_ids, $rec->customergroup_id();
    }

    # work out what the join type is
    $groupjoin = $record->group_join_type(
        $listtype
    );

    # OR join type
    if ($PROMOTION_DETAIL_CUSTOMERGROUP_JOIN__OR == $groupjoin->id) {
        # if we don't have any groups ..
        if (not @group_ids) {
            @group_ids = (-1); # yes, this is evil, but ...
        }
        # what we always want in the where clause
        $where_clause->{customergroup_id} = { 'IN', \@group_ids };
        # if $website_id is defined, restrict to those
        if (defined $website_id) {
            $where_clause->{website_id} = $website_id;
        }

        $rs = $schema->resultset('Promotion::CustomerCustomerGroup')
            ->search(
                $where_clause,
                {
                    # no extra magic
                }
            )
        ;
    }
    elsif ($PROMOTION_DETAIL_CUSTOMERGROUP_JOIN__AND == $groupjoin->id) {
        my (%customers_in_group, @intersection, @customers, @lists, $lcm);

        # for each group, get a list of customer IDs that match
        foreach my $group_id (@group_ids) {
            my $where_clause = {
                customergroup_id => $group_id,
            };

            # if $website_id is defined, restrict to those
            if (defined $website_id) {
                $where_clause->{website_id} = $website_id;
            }

            # do the search
            $rs = $schema->resultset('Promotion::CustomerCustomerGroup')
                ->search(
                    $where_clause,
                    {
                        # no extra magic
                    }
                )
            ;
            # add to the list-of-lists
            push @lists, [ $rs->get_column('customer_id')->all ];
        } # foreach

        # if we have any lists .. get the intersection of them
        if (@lists) {
            if (@lists > 1) {
                # create a new List::Compare object
                $lcm = List::Compare->new(@lists);
                # get the intersection
                @intersection = $lcm->get_intersection;
            }
            else {
                # the one list is the intersection
                @intersection = @{ $lists[0] };
            }
        }

        # replace an empty intersection with data that won't do anything
        if (not @intersection) {
            @intersection = ( -1 );
        }

        # magick it all into a Promotion::CustomerCustomerGroup resultset
        $rs = $schema->resultset('Promotion::CustomerCustomerGroup')
            ->search(
                {
                    customer_id => { 'IN', \@intersection }
                },
                {
                    distinct    => 1,
                    columns     => [ qw/customer_id/ ],
                }
            )
        ;
    }
    else {
        die "unknown join type in customers_of_type()";
    }

    return $rs;
}

sub designer_id_list {
    my $record = shift;
    my (@ids, $website_rs);

    my $designers = $record->designers();
    while (my $designer = $designers->next) {
        push @ids, $designer->id();
    }

    return \@ids;
}

sub disable {
    my $record      = shift;
    my $pws_info    = $record->pws_info();
    my $schema      = $record->result_source()->schema();

    # loop through the remote websites
    foreach my $sitename (keys %{$pws_info}) {
        # get the remote schema
        my $pws_schema = $pws_info->{$sitename}{schema};
        eval {
            $schema->txn_do(
                sub {
                    # get the promotion on the PWS
                    my $pws_promo = $pws_schema->resultset('Detail')->find(
                        $record->id
                    );

                    # disable the promotion on the PWS
                    if (defined $pws_promo) {
                        $pws_promo->update(
                            { enabled => 0 }
                        );
                    }
                    else {
                        die qq{couldn't find promotion on PWS};
                    }
                } # sub
            ); # txn_do
        };
        if ($@) {
            #xt_warn($@);
            xt_logger->error($@);
            xt_info("$sitename: failed to disable promotion: $@");
        }
    } # foreach

    $record->update(
        {
            enabled => 0,
        }
    );

    return;
}

sub exclude_group_join {
    my $record      = shift;

    my $groupjoin = $record->group_join_type(
        $PROMOTION_CUSTOMERGROUP_LISTTYPE__EXCLUDE,
    );
    return $groupjoin;
}

sub excluded_customers {
    my $record      = shift;
    my $website_id  = shift;

    my $rs = $record->customers_of_type(
        $PROMOTION_CUSTOMERGROUP_LISTTYPE__EXCLUDE,
        $website_id
    );
    return $rs;
}

sub expects_product_restrictions {
    my($record) = @_;
    my ($expected_restrictions);
    my $schema = $record->result_source()->schema();
    my @pids = $record->detail_products->get_column('product_id')->all;

    # product_types
    my @prodtypes = $record->detail_producttypes
        ->get_column('producttype_id')->all;
    # seasons
    my @seasons = $record->detail_seasons
        ->get_column('season_id')->all;
    # designers
    my @designers = $record->detail_designers
        ->get_column('designer_id')->all;

    # are we expecting to have a season/designer/type/pid restriction?
    $expected_restrictions =
          scalar @pids
        + scalar @prodtypes
        + scalar @seasons
        + scalar @designers
    ;

    return $expected_restrictions;
}

sub export_coupons {
    my $record      = shift;
    my $pws_info    = $record->pws_info();
    my $schema      = $record->result_source()->schema();

    # copy over the coupons
    # if the promotion has ever been enabled DO NOT export the coupons
    # again; i.e. if enabled is undef
    if (not $record->been_exported) {
        # do the export in a transaction for each site
        foreach my $sitename (keys %{$pws_info}) {
            # get the remote schema
            my $pws_schema = $pws_info->{$sitename}{schema};
            eval {
                $schema->txn_do(
                    sub {
                        foreach my $coupon ($record->coupons) {
                            $pws_schema->resultset('Coupon')->create(
                                $coupon->data_as_hash,
                            );
                        }
                    } # sub
                ); # txn_do
            };
            if ($@) {
                xt_warn($@);
                die "$sitename: failed to export coupons: $@";
            }
        } # foreach

        $record->update(
            {
                been_exported => 1,
            }
        );
    }
    else {
        warn "coupons have already been exported";
    }

    return;
}

sub export_customers {
    my $record      = shift;
    my $pws_info    = $record->pws_info();
    my $schema      = $record->result_source()->schema();

    my ($frozen_rs, @frozen_customers);
    my ($rs, @local_cust_list, $pws_schema);

    # get the list of frozen customers
    $frozen_rs = $record->frozen_customers;

    # get a list of the IDs
    @frozen_customers = $frozen_rs->get_column('customer_id')->all;
    # make sure it's not empty
    if (not @frozen_customers) {
        # assume we'll never have a customer with a negative ID
        @frozen_customers = (-1);
    }

    # for each site attached to the promotion, get the relevant
    # customer/customer-group records, and export them to the website database
    foreach my $sitename (keys %{$pws_info}) {
        # get the remote schema
        my $pws_schema = $pws_info->{$sitename}{schema};

        # the list of matching customers from the customer_customergroup table
        $rs = $schema->resultset('Promotion::CustomerCustomerGroup')
            ->search(
                {
                    customer_id => { 'IN', \@frozen_customers },
                    website_id  => $pws_info->{$sitename}{id},
                },
                {
                    distinct    => 1,
                    columns     => [ qw/customer_id/ ],
                }
            )
        ;
        @local_cust_list = $rs->get_column('customer_id')->all();

        # do the export in a transaction for each site
        eval {
            $schema->txn_do(
                sub {
                    $pws_schema->resultset('DetailCustomer')->search(
                        {
                            event_id       => $record->id,
                        }
                    )
                    ->delete;

                    # if we're FRIENDS-AND_FAMILY we need to make sure we
                    # don't restrict to any customers
                    # we just completed phase 1 on the plan (make sure we nuke
                    # all restrictions in the PWS)
                    # phase 2 is ... don't export anything
                    if ($PROMOTION_COUPON_TARGET__FRIENDS_AND_FAMILY eq $record->coupon_target->id()) {
                        # do nothing!
                    }
                    else {
                        # get all customers that we'd like to link to a promotion
                        # *and* actually exist
                        my $custard_list = $pws_schema->resultset('Customer')->search(
                            {
                                id => { 'IN' => \@local_cust_list },
                            }
                        );
                        # get a list of the ids
                        my @known_customers = $custard_list->get_column('id')->all;

                        # now, with the right pws-db, insert each custard into the
                        # detail_customer join table
                        foreach my $cust_id (@known_customers) {
                            $pws_schema->resultset('DetailCustomer')->create(
                                {
                                    event_id       => $record->id,
                                    customer_id     => $cust_id,
                                }
                            );
                        } # foreach

                        # work out if there were any customers we didn't/couldn't
                        # insert
                        my $diff_count = @local_cust_list - @known_customers;
                        if ( $diff_count > 0) {
                            # XXX xt_info( qq{$sitename : $diff_count customers not found in database, and ignored} );
                        }

                        xt_logger->warn(
                            qq{$sitename : }
                            . scalar(@known_customers)
                            . q{ out of }
                            . scalar(@local_cust_list)
                            . qq{ customers exported to $sitename database}
                        );
                    } # if (friendsandfamily)
                } # sub
            ); # txn_do
        };
        if ($@) {
            xt_warn($@);
            die $sitename . ": Failed to update promotion-detail information";
        }

    }

    return;
}

sub export_customers_to_pws {
    my $record      = shift;
    my $pws_info    = shift;
    my $feedback_to = shift;
    my $xt_schema   = $record->result_source()->schema();

    # run through each applicable pws_schema
    foreach my $sitename (keys %{$pws_info}) {
        $record->_append_to_feedback(
            qq{<b><u>$sitename Customers</u></b>}
        );

        my $site_cust_list = $record->applicable_customer_list(
            $pws_info->{$sitename}{id}
        );

        # we don't have to do anything if there aren't any customers
        if (not scalar @{ $site_cust_list }) {
            # nothing to export
            $record->_append_to_feedback(
                q{Nothing to export}
            );
            next;
        }

        # grab the schema
        my $pws_schema = $pws_info->{$sitename}{schema};

        # do the export in a transaction for each site
        eval {
            $pws_schema->txn_do(
                sub {
                    # get hold of the remote record for the same promo
                    my $remote_detail = $pws_schema->resultset('Detail')->find(
                        $record->id
                    );

                    if (not defined $remote_detail) {
                        xt_warn(
                              q{couldn't find remote promotion "}
                            . $record->internal_title
                            . q{" (}
                            . $record->visible_id
                            . q{) for }
                            . $sitename
                            . q{ site in export_customers_to_pws()}
                        );
                        $record->_append_to_feedback(
                              q{<span style="color:red;">}
                            . q{Couldn't find remote promotion "}
                            . $record->internal_title
                            . q{" (}
                            . $record->visible_id
                            . q{) for }
                            . $sitename
                            . q{ site in export_customers_to_pws()}
                            . q{</span>}
                        );
                        return;
                    }

                    # if the remote promotion is already disabled, we don't want to re-enable
                    # it at the end of the update
                    my $remote_enabled = $remote_detail->enabled;

                    # While we're exporting the promotion product restrictions, we disable the
                    # promotion, to ensure that no-one sneaks through the tiny gap in time
                    # while there are NO RESTRICTIONS by product
                    xt_logger->debug('disabling remote promotion while there are no customer restrictions');
                    $remote_detail->update( { enabled => 0 });

                    # delete existing records
                    $pws_schema->resultset('DetailCustomer')->search(
                        {
                            event_id       => $record->id,
                        }
                    )
                    ->delete;

                    # get all customers that we'd like to link to a promotion
                    # *and* actually exist
                    my $custard_list = $pws_schema->resultset('Customer')->search(
                        {
                            id => { 'IN' => $site_cust_list },
                        }
                    );

                    # get a list of the ids
                    my @known_customers = $custard_list->get_column('id')->all;

                    # now, with the right pws-db, insert each custard into the
                    # detail_customer join tabl
                    my $count = 0;
                    foreach my $cust_id (@known_customers) {
                        my $result = $pws_schema->resultset('DetailCustomer')->create(
                            {
                                event_id       => $record->id,
                                customer_id     => $cust_id,
                            }
                        );
                        if (defined $result) {
                            $count++;
                            # if $count hits 1, we've just added our first product, and
                            # we're now restricted by (one or more) products
                            if (1 == $count) {
                                if (not $remote_enabled) {
                                    xt_logger->debug('promotion ' .  $record->visible_id . ' was disabled before the update - leaving disabled despite having custoner restrictions');
                                    $record->_append_to_feedback(
                                          'Promotion '
                                        . $record->visible_id
                                        . ' was disabled before the update'
                                        . ' - leaving disabled despite having customerrestrictions'
                                    );
                                }
                                else {
                                    xt_logger->debug('enabling remote promotion ' . $record->visible_id . ' - we have our first customer restriction');
                                    $record->_append_to_feedback(
                                        q{Enabling promotion on Website - we have at least one customer restriction}
                                    );
                                    $remote_detail->update( { enabled => 1 });
                                }
                            }
                        }
                    } # foreach

                    # if we don't have any custards in the pws-db; we need to
                    # shut down shop, kill the promo, set off all the fire
                    # extinguishers ....
                    my $customer_count =
                        $pws_schema->resultset('DetailCustomer')->count(
                            {
                                event_id       => $record->id,
                            }
                        );
                    # if we wanted to restrict by customer, but don't have any
                    # ...
                    if (
                        $record->detail_customergroups
                            and
                        not $customer_count
                    ) {
                        my ($message, $email_message);

                        # a message to output
                        $message =
                              $record->visible_id
                            . q{ exported ZERO customers to }
                            . $sitename
                            . q{; customer restrictions were requested. }
                            . q{Disabling the promotion on }
                            . $sitename
                        ;
                        # put something in the log file
                        xt_logger->error($message);
                        # add it to the email message
                        $record->_append_to_feedback(
                              q{<span style="color:red;">}
                            . $message
                            . q{</span>}
                        );

                        # disable on the PWS
                        my $remote_promo = $pws_schema->resultset('Detail')
                            ->find(
                                {
                                    id   => $record->id,
                                }
                            );
                        # disable it if we can find it, otherwise, more
                        # complaining
                        if (defined $remote_promo) {
                            $remote_promo->update(
                                { enabled => 0 }
                            );
                        }
                        else {
                            $message =
                                $record->visible_id
                                . q{ wasn't found in the }
                                . $sitename
                                . q{ database; we couldn't disable it}
                            ;
                            # put something in the log file
                            xt_logger->error($message);
                            # add it to the email message
                            $record->_append_to_feedback(
                                  q{<span style="color:red;">}
                                . $message
                                . q{</span>}
                            );
                        }
                    }

                    # report on the customer export
                    my ($report_msg, $report_subject);
                    # a helpful subject line
                    $report_subject =
                          $record->visible_id
                        . q{: Report: Customer Export to }
                        . $sitename
                    ;
                    # work out if there were any customers we didn't/couldn't
                    my $diff_count = @{$site_cust_list} - @known_customers;
                    if ( $diff_count > 0) {
                        $report_msg .= qq{<p>$diff_count customers were not found in the database, and ignored</p>};
                    }
                    # an overall summary
                    $report_msg .=
                          q{<p>}
                        . scalar(@known_customers)
                        . q{ out of }
                        . scalar(@{$site_cust_list})
                        . qq{ customers were exported to the $sitename database}
                        . q{</p>}
                    ;
                    $record->_append_to_feedback( $report_msg );
                } # sub
            ); # txn_do
        };
        if ($@) {
            xt_warn($@);
            die $sitename . ": Failed to update promotion-detail information";
        }
    }

    return;
}

sub export_promo_products_to_pws {
    my $record = shift;
    my $pids = shift;
    my $operator_id = shift;
    my $feedback_to = shift;
    my $info = {};  # hash to hold the number of rows inserted for websites
    my (
        $xt_schema,
        $pws_schema,
        $xt_detail,
        $pws_detail,
    );

    # FIXME: commented this out as this will always be called be a script
    if (not defined $operator_id) {
        die "operator_id not passed";
    }

    # get the XT schema, so we get stuff
    $xt_schema = $record->result_source()->schema();

    foreach my $website ($record->websites) {
        # get the PWS (intl) schema, so we can punt stuff into in
        $pws_schema->{$website->name} = get_database_handle(
            {
                name    => 'pws_schema_' . $website->name,
#                type    => 'transaction',
            }
        );
    }

    # let people know how much we're exporting
    xt_logger->info(
          q{Exporting }
        . scalar(@{$pids})
        . q{ PID(s) as product restrictions for promotion }
        . $record->visible_id
    );

    # do the export in a transaction for each site
    $xt_schema->txn_do(
        sub {
            # make the promotion enabled
            # *but only if enabled is undefined)
            if (not defined $record->enabled) {
                $record->update(
                    {
                        enabled             => 1,
                        status_id           => $PROMOTION_STATUS__EXPORTED,
                        last_modified_by    => $operator_id,
                    }
                );
            }

            my $xtset = $xt_schema->resultset('Promotion::DetailProduct')
                ->search({ event_id => $record->id })->delete;

            # push out to each applicable site
            foreach my $sitename (keys %{$pws_schema}) {
                $record->_append_to_feedback(
                    qq{<b><u>$sitename Products</u></b>}
                );
                $info->{$sitename} = _txn_export_promo_products_to_pws(
                    $record,
                    $xt_schema,
                    $pws_schema->{$sitename},
                    $pids
                );

                # if no products were exported, raise an alarm, disable the
                # promotion, panic, throw a chair through the window
                if (
                    $record->expects_product_restrictions
                        and
                    not $info->{$sitename}
                ) {
                    my ($message, $email_message);

                    # a message to output
                    $message =
                          $record->visible_id
                        . q{ exported ZERO products to }
                        . $sitename
                        . q{; product restrictions were requested. }
                        . q{Disabling the promotion on }
                        . $sitename
                    ;
                    # put something in the log file
                    xt_logger->error($message);
                    # add it to the email message
                    $record->_append_to_feedback(
                            q{<span style="color:red;">}
                        . $message
                        . q{</span>}
                    );

                    # disable on the PWS
                    my $remote_promo = $pws_schema->{$sitename}->resultset('Detail')
                        ->find(
                            {
                                id   => $record->id,
                            }
                        );
                    # disable it if we can find it, otherwise, more
                    # complaining
                    if (defined $remote_promo) {
                        $remote_promo->update(
                            { enabled => 0 }
                        );
                    }
                    else {
                        $message =
                              $record->visible_id
                            . q{ wasn't found in the }
                            . $sitename
                            . q{ database; we couldn't disable it}
                        ;
                        # put something in the log file
                        xt_logger->error($message);
                        # add it to the email message
                        $record->_append_to_feedback(
                              q{<span style="color:red;">}
                            . $message
                            . q{</span>}
                        );
                    }
                }

                # send a report on the product export
                if ($record->expects_product_restrictions) {
                    my ($report_msg, $report_subject);
                    # a helpful subject line
                    $report_subject =
                            $record->visible_id
                        . q{: Report: Product Export to }
                        . $sitename
                    ;
                    # an overall summary
                    my $pid_count = q{<span style="color:red;">UNKNOWN</span>}; # default to something
                    if (defined $pids and ref($pids)) {
                        $pid_count = scalar(@{$pids})
                    }
                    $report_msg .=
                            q{<p>}
                        . (defined $info->{$sitename} ? $info->{$sitename} : q{<span style="color:red;">UNKNOWN</span>})
                        . q{ out of }
                        . $pid_count
                        . qq{ product ids were exported to the $sitename database}
                        . q{</p>}
                    ;
                    $record->_append_to_feedback( $report_msg );
                }
            }
        }
    );

    return $info;
}

sub export_to_lyris {
    my $record      = shift;
    my $schema      = $record->result_source()->schema();
    my ($lyris_schema, $frozen_rs);

    # grab the schema connection to lyris
    $lyris_schema = get_database_handle(
        {
            name    => 'lyris_schema',
#            type    => 'transaction',
        }
    );

    # if there are any records for this promo in the lyris db ... DO NOT
    # EXPORT
    my $already_there_count = $lyris_schema->resultset('CustomerPromotion')->count(
        {
            promotion_number => $record->visible_id,
        }
    );
    if ($already_there_count > 0) {
        warn "attempt to re-export to Lyris for " . $record->visible_id;
        return;
    }

    # run through all of the frozen customers, and insert a Lyris entry for
    # each one (with the person's coupon code)
    $frozen_rs = $record->frozen_customers;

    # do everything inside a txn
    eval {
        $schema->txn_do(
            sub {
                while (my $detail_customer = $frozen_rs->next) {
                    #warn('Looking for: ' . $record->id . ' - ' . $detail_customer->customer_id);
                    # get the relevant coupon
                    my $coupon = $schema->resultset('Promotion::Coupon')->find(
                        {
                            event_id       => $record->id,
                            customer_id     => $detail_customer->customer_id,
                        },
                        {
                            key => 'customer_promotion',
                        }
                    );

                    if (not defined $coupon) {
                        warn('No coupon found for: ' . $record->id . ' - ' . $detail_customer->customer_id);
                        next;
                    }

                    # create a suitable record in Lyris
                    #warn($record->visible_id . ' - ' .  $detail_customer->customer_id . ' - ' .  $coupon->code);
                    $lyris_schema->resultset('CustomerPromotion')->create(
                        {
                            promotion_number    => $record->visible_id,
                            customer_id         => $detail_customer->customer_id,
                            coupon_code         => $coupon->code,
                        }
                    );
                }

                # flag the promotion as having been exported to lyris
                $record->update(
                    {
                        exported_to_lyris => 1,
                    }
                );
            } # sub
        ); # txn_do
    }; # eval
    if ($@) {
        xt_warn($@);
        die $record->visible_id . ": failed to export to lyris: $@";
    }

    return;
}

# this method will provide the evil magic to put (all) of the relevant data to
# the PWS promotion table(s)
sub export_to_pws {
    my $record      = shift;
    my $operator_id = shift;
    my $feedback_to = shift;
    my $pws_info    = $record->pws_info();
    my (
        $xt_schema,
        $xt_detail,
        $pws_detail,
    );

    if (not defined $operator_id) {
        die "operator_id not passed";
    }

    # get the XT schema, so we get stuff
    $xt_schema = $record->result_source()->schema();

    # do the export in a transaction for each site
    $xt_schema->txn_do(
        sub {
            # we need to store the promotion's enabled state because we're
            # going to alter it shortly, but we need the original status to work
            # out what to do with coupons
            my $initial_enabled_state = $record->enabled;

            # make the promotion enabled
            # *but only if enabled is undefined*
            if (not defined $record->enabled) {
                $record->update(
                    {
                        enabled             => 1,
                        last_modified_by    => $operator_id,
                    }
                );
            }

            # flag the promotion as "exported"
            $record->update(
                {
                    status_id           => $PROMOTION_STATUS__EXPORTED,
                    last_modified_by    => $operator_id,
                }
            );

            # push out to each applicable site
            foreach my $sitename (keys %{$pws_info}) {
                $record->_append_to_feedback(
                    qq{<b><u>$sitename Main Details</u></b>}
                );
                # export the detail
                _txn_export_to_pws(
                    $record,
                    $operator_id,
                    $xt_schema,
                    $pws_info->{$sitename}{schema},
                    $initial_enabled_state,
                );
            }

            # perform JT's product join magic
            $record->export_promo_products_to_pws(
                # pid-list
                $record->applicable_product_list(),
                # operator
                $operator_id,
                # who to send feedback to
                $feedback_to
            );

            # freeze the customers in the group(s) and export to detail_customer in
            # the PWS
            $record->export_customers_to_pws($pws_info, $feedback_to);
        }
    );

    if ($record->feedback_message) {
        # add a link to the XT promo page
        $record->_append_to_feedback(
            q{<b><u>Finally</u></b>}
        );
        $record->_append_to_feedback(
              q{View the promotion: }
            . $record->_promotion_link
        );

      # send the alert
    if($record->feedback_message =~ /(.*)already exists in target website database; not exporting(.*)/){
              $record->_send_alert(
              q{ ERROR - }
            . $record->visible_id
            . q{ Export Report : }
            . $record->internal_title,
            $record->feedback_message,
            $feedback_to
           );
        }
       else{
           $record->_send_alert(
              $record->visible_id
            . q{ Export Report : }
            . $record->internal_title,
            $record->feedback_message,
            $feedback_to
           );
        };
    }

    return;
}

sub freeze_customers_in_groups {
    my $record      = shift;
    my $feedback_to = shift;
    my $schema      = $record->result_source()->schema();

    # fetch _all_ applicable customers (for both sites)
    my $site_cust_list = $record->applicable_customer_list();

    # wrap our delete+inserts in a transaction
    eval {
        $schema->txn_do(
            sub {
                # delete all existing records (for the current promotion)
                $schema->resultset('Promotion::DetailCustomer')->search(
                    {
                        event_id => $record->id,
                    }
                )
                ->delete;

                # insert the ones in our list
                foreach my $cust_id (@{ $site_cust_list }) {
                    $schema->resultset('Promotion::DetailCustomer')->create(
                        {
                            event_id       => $record->id,
                            customer_id     => $cust_id,
                        }
                    );
                } # foreach
            }
        );
    };
    if ($@) {
        die $@;
    }

    # check to see how many frozen customers we have for the promotion, and
    # warn someone if we didn't have any qualifying victims
    # This should address the "Freeze->Freeze" confusion reported in XTR-879
    my $cust_count = $schema->resultset('Promotion::DetailCustomer')->count(
        {
            event_id       => $record->id,
        }
    );
    if (0 == $cust_count) {
        # build up a message to send to the person who kicked of the freeze,
        # so they know why they're seeing the Freeze Button again

        # put something in the logs
        xt_logger->info($record->visible_id . q{ Customer Freeze resulted in a ZERO sized set of results});

        # report on the customer export
        my ($report_msg, $report_subject);
        # a helpful subject line
        $report_subject =
                $record->visible_id
            . q{: Customer Group Freeze: No Customers}
        ;
        # an overall summary
        $report_msg .=
              q{<p>}
            . q{There are no customers that meet the customer group restrictions for the promotion. }
            . q{</p>}
            . q{<p>}
            . q{Please don't be surprised if you repeatedly see the "Freeze" button. This will continue until there is at least one customer to meet the restrictions. }
            . q{</p>}
        ;
        $record->_append_to_feedback( $report_msg );
    }
    else {
        # do we want to report on the number of customers we DID freeze?
    }

    if ($record->feedback_message) {
        # add a link to the XT promo page
        $record->_append_to_feedback(
            q{<b><u>Finally</u></b>}
        );
        $record->_append_to_feedback(
              q{View the promotion: }
            . $record->_promotion_link
        );

        # send the alert
        $record->_send_alert(
            $record->visible_id . q{ Export Report},
            $record->feedback_message,
            $feedback_to
        );
    }

    return;
}

sub frozen_customers {
    my $record  = shift;
    my $schema  = $record->result_source()->schema();

    # get the list of frozen customers
    my $frozen_rs = $schema->resultset('Promotion::DetailCustomer')->search(
        {
            event_id => $record->id,
        }
    );

    return $frozen_rs;
}

sub generate_coupons {
    my $record      = shift;

    # if we have any coupons, don't do anything
    # we should only generate them ONCE!
    if ($record->has_coupon_codes) {
        warn $record->visible_id . qq{ already has generated coupons\n};
        return;
    }

    # generate specific coupons
    if ($record->is_specific_coupon) {
        # get a list of the frozen custards for the promotion
        $record->generate_specific_coupons;
    }
    elsif ($record->is_generic_coupon) {
        warn "generic\n";
    }
    else {
        die q{It's not generic. It's not specific. What the *beep* is it?};
    }


    return;
}

sub generate_specific_coupons {
    my $record      = shift;
    my $schema      = $record->result_source()->schema();
    my ($cust_rs, $coupon, $suffix_list, $fixed_coupon_data);

    # get a coupon (data) making object
    $coupon = XTracker::Promotion::Coupon->new(
        {
            prefix => $record->coupon_prefix(),
        }
    );

    # get the customers that have been frozen
    $cust_rs = $schema->resultset('Promotion::DetailCustomer')->search(
        {
            event_id       => $record->id,
        }
    );

    # generate suffixes for them
    $suffix_list = $coupon->generate_suffix_list(
        $cust_rs->count
    );

    # coupon data that doesn't change
    $fixed_coupon_data = {
        prefix              => $coupon->get_prefix,

        event_id           => $record->id(),
        restrict_by_email   => 1,   # this might get changed if we're creating
                                    # Friends&Family coupons; safer to default
                                    # to a restriction
        valid               => 1,
    };

    # if we're Friends and Family, we don't want to
    if ($PROMOTION_COUPON_TARGET__FRIENDS_AND_FAMILY eq $record->coupon_target->id()) {
        $fixed_coupon_data->{restrict_by_email} = 0;
    }

    # any coupon restrictions?
    if (defined $record->coupon_restriction) {
        $fixed_coupon_data->{usage_limit}   = $record->coupon_restriction->usage_limit();
        $fixed_coupon_data->{usage_type_id} = $record->coupon_restriction->group_id();

        # if there's a custom usage limit, nuke the menu value
        if ($record->has_custom_coupon_limit) {
            $fixed_coupon_data->{usage_limit} = $record->coupon_custom_limit;
            xt_logger->info(
                  q{(specific) using custom usage limit: }
                . $fixed_coupon_data->{usage_limit}
            ) if (1);
        }
    }

    # wrap our inserts in a transaction
    # TODO - deal with friends-and-family
    eval {
        $schema->txn_do(
            sub {
                while (my $cust = $cust_rs->next) {
                    $schema->resultset('Promotion::Coupon')->create(
                        {
                            # fixed data
                            %{ $fixed_coupon_data },
                            # customer specific
                            customer_id     => $cust->customer_id,
                            suffix          => pop(@{$suffix_list}),
                        }
                    );
                }
            }
        );
    };
    if ($@) {
        die $@;
    }

    return;
}

sub generic_coupon {
    my $record = shift;

    if (not $record->is_generic_coupon) {
        return;
    }

    if (not defined $record->coupons) {
        return;
    }

    my $first = $record->coupons_rs->first;
    return $first;
}

sub group_join_type {
    my $record      = shift;
    my $listtype    = shift;
    my $schema      = $record->result_source()->schema();
    my ($groupjoin);

    $groupjoin = $schema->resultset('Promotion::DetailCustomerGroupJoinListType')
        ->find(
            {
                event_id                   => $record->id,
                customergroup_listtype_id   => $listtype,
            }
        );

    my $rv = undef;
    # if we don't have a jointype, default to AND
    if (not defined $groupjoin) {
        #warn "defaulting to AND in group_join_type()";
    $rv = $schema->resultset('Promotion::DetailCustomerGroupJoin')->search({type=>'AND'})->first;
    return $rv;
    }

    eval {
    $rv = $groupjoin->detail_customergroup_join;
    };
    if (my $e = $@) {
    # join unknown
    return;
    }

    return $rv;
}

sub has_coupon_codes {
    my $record = shift;

    # done this way as this seems to prevent TT issues
    if (defined $record->coupons and $record->coupons->count) {
        return 1;
    }

    return 0;
}

sub has_custom_coupon_limit {
    my $record = shift;

    # we might want sonstants for this, but we added them by hand, not relying
    # on the auto-increment ...
    if (
        not (25 == $record->coupon_restriction_id)
            and
        not (26 == $record->coupon_restriction_id)
    ) {
        # it's not one of the "custom amount" meu items
        return 0;
    }

    # yep, it's one of the custom ones ...
    return 1;
}

sub include_group_join {
    my $record      = shift;

    my $groupjoin = $record->group_join_type(
        $PROMOTION_CUSTOMERGROUP_LISTTYPE__INCLUDE,
    );
    return $groupjoin;
}

sub included_customers {
    my $record      = shift;
    my $website_id  = shift;

    my $rs = $record->customers_of_type(
        $PROMOTION_CUSTOMERGROUP_LISTTYPE__INCLUDE,
        $website_id
    );
    return $rs;
}

sub is_active {
    my $record = shift;
    my ($now, $start_date, $end_date, $cmp);

    $now = DateTime->now();
    $start_date = $record->start_date;
    $end_date = $record->end_date;

    # a promotion is active if:
    #  1. start date is in the past, and we have no end date
    #  2. start date is in the past, and end date is in the future

    # we can abort right away if the start time is in the future
    eval {
        $cmp = DateTime->compare( $start_date, $now );
    };
    if ($@) {
        xt_logger->fatal($@);
        return 0;
    }
    if ($cmp == 1) { # $a > $b
        # start date is in the future
        return 0;
    }


    # ** Start Time Is In The Past

    # if we don't have an end date, ttarget_cityhen it's active
    # (started, never finishes)
    if (not defined $end_date) {
        return 1;
    }


    # ** Promotion has an end date

    # if the end date is in the future, we're (still) active
    eval {
        $cmp = DateTime->compare( $end_date, $now );
    };
    if ($@) {
        xt_logger->fatal($@);
        return 0;
    }
    if ($cmp == 1) { # $a > $b
        # end date is in the future - still active
        return 1;
    }

    # default conclusion ... fail
    return 0;
}

sub is_generic_coupon {
    my $record = shift;

    # what makes a generic coupon?
    # 1. there's a coupon prefix; detail.coupon_prefix
    # 2. the coupon target is generic; detail.coupon_target_id =>
    #    (promotion.coupon_target.description) -> 'Generic')
    if (defined $record->coupon_prefix
            and
        $PROMOTION_COUPON_TARGET__GENERIC eq $record->coupon_target->id()
    ) {
        # we have a prefix and we are Generic
        return 1;
    }

    # default to "nope, not generic"
    return 0;
}

sub is_specific_coupon {
    my $record = shift;

    # what makes a specific coupon?
    # 1. there's a coupon prefix; detail.coupon_prefix
    # 2. the coupon target is specific; detail.coupon_target_id =>
    #    (promotion.coupon_target.description) -> 'Customer Specific')
    if (defined $record->coupon_prefix
            and
        (
            $PROMOTION_COUPON_TARGET__CUSTOMER_SPECIFIC eq $record->coupon_target->id()
                or
            $PROMOTION_COUPON_TARGET__FRIENDS_AND_FAMILY eq $record->coupon_target->id()
        )
    ) {
        # we have a prefix and we are Generic
        return 1;
    }

    # default to "nope, not specific"
    return 0;
}

# DCS-848
sub is_outnet_event {
    my $record = shift;

    # ... if it's not classic ... it's "event" [Outnet]
    return 1
        if (not $record->is_classic);

    # it's not an outnet event
    return 0;
}

sub producttype_id_list {
    my $record = shift;
    my (@ids, $website_rs);

    my $producttypes = $record->producttypes();
    while (my $producttype = $producttypes->next) {
        push @ids, $producttype->id();
    }

    return \@ids;
}

sub promotion_product_pid_list {
    my $record = shift;
    my (@ids);

    my $pids = $record->products();
    while (my $pid = $pids->next) {
        push @ids, $pid->id();
    }
    return \@ids;
}

sub pws_info {
    my $record      = shift;

    # a scalar to be used as ahashref of schema connections
    my $pws_info;

    # foreach website the promotion is attached to ...
    foreach my $website ($record->websites) {
        # get the PWS (intl) schema, so we can punt stuff into in
        $pws_info->{$website->name}{schema} = get_database_handle(
            {
                name    => 'pws_schema_' . $website->name,
#                type    => 'transaction',
            }
        );
        # store the website id
        # (primarily used when exporting custards)
        $pws_info->{$website->name}{id} = $website->id;
    }

    return $pws_info;
}

sub requires_customer_freeze {
    my $record = shift;

    return (
        ($record->detail_customergroups->count > 0)
            and
        (not $record->detail_customers->count)
    );
}

sub requires_emails {
    my $record = shift;

    return ($record->coupon_generation_id == $PROMOTION_COUPON_GENERATION__COUPON_AND_SEND);
}

sub season_id_list {
    my $record = shift;
    my (@ids, $website_rs);

    my $seasons = $record->seasons();
    while (my $season = $seasons->next) {
        push @ids, $season->id();
    }

    return \@ids;
}

sub shipping_id_list {
    my $record = shift;
    my (@ids, $website_rs);

    my $shipping_options = $record->shipping_options();
    while (my $shipping_option = $shipping_options->next) {
        push @ids, $shipping_option->id();
    }

    return \@ids;
}

sub status_coupons_generated {
    my $record = shift;

    return ($record->status_id == $PROMOTION_STATUS__GENERATED_COUPONS);
}

sub status_coupons_generating {
    my $record = shift;

    return ($record->status_id == $PROMOTION_STATUS__GENERATING_COUPONS);
}

sub status_customer_list_frozen {
    my $record = shift;

    return ($record->status_id == $PROMOTION_STATUS__GENERATED_CUSTOMER_LISTS);
}

sub status_disabled {
    my $record = shift;

    return ($record->status_id == $PROMOTION_STATUS__DISABLED);
}

sub status_exported {
    my $record = shift;

    return (
        ($record->status_id == $PROMOTION_STATUS__EXPORTED)
        ||
        ($record->status_id == $PROMOTION_STATUS__EXPORTED_TO_PWS)
    );
}

sub status_exported_to_lyris {
    my $record = shift;

    return ($record->status_id == $PROMOTION_STATUS__EXPORTED_TO_LYRIS);
}

sub status_exporting_to_lyris {
    my $record = shift;

    return ($record->status_id == $PROMOTION_STATUS__EXPORTING_TO_LYRIS);
}

sub status_exporting_anything {
    my $record = shift;

    return (
        ($record->status_id == $PROMOTION_STATUS__EXPORTING_TO_PWS)
        ||
        ($record->status_id == $PROMOTION_STATUS__EXPORTING_TO_LYRIS)
        ||
        ($record->status_id == $PROMOTION_STATUS__EXPORTING_CUSTOMERS)
        ||
        ($record->status_id == $PROMOTION_STATUS__EXPORTING_COUPONS)
        ||
        ($record->status_id == $PROMOTION_STATUS__EXPORTING_PRODUCTS)
    );
}

sub status_exporting_to_pws {
    my $record = shift;

    return ($record->status_id == $PROMOTION_STATUS__EXPORTING_TO_PWS);
}

sub status_in_progress {
    my $record = shift;

    return ($record->status_id == $PROMOTION_STATUS__IN_PROGRESS);
}

sub status_job_failed {
    my $record = shift;

    return ($record->status_id == $PROMOTION_STATUS__JOB_FAILED);
}

sub status_job_queued {
    my $record = shift;

    return ($record->status_id == $PROMOTION_STATUS__JOB_QUEUED);
}

sub website_id_list {
    my $record = shift;
    my (@ids, $website_rs);

    my $sites = $record->websites();
    while (my $site = $sites->next) {
        push @ids, $site->id();
    }

    return \@ids;
}

#
# PRIVATE METHODS
#

sub _send_alert {
    my ($record, $subject, $message, $feedback_to) = @_;
    my $xt_schema   = $record->result_source()->schema();

    # send an email to the xtracker team
    send_email(
        config_var('Email', 'xtracker_email'),      # from
        config_var('Email', 'xtracker_email'),      # reply-to
        config_var('Email', 'promotion_alert'),     # to
        $subject,                                   # subject
           q{<html><head></head><body>}             # message; yes it's horrible
         . $message
         . q{</body></html>},
        q{html}                                     # be HTML
    );

    # send an internal alert/message
    if (defined $feedback_to) {
        # grab the domain
        my $messages = XT::Domain::Messages->new({ schema => $xt_schema });
        # default the message to whoever we're sending to
        my $message_data = $feedback_to;
        # add the subject and message
        $message_data->{subject}    = $subject;
        $message_data->{message}    = $message;
        # send the message
        $messages->send_message( $message_data );
    }
    else {
        xt_logger->info("no feedback_to specified; no internal message will be sent");
    }
}

sub _append_to_feedback {
    my $record    = shift;
    my $to_append = shift;

    return
        if not defined $to_append;

    if (not defined $record->feedback_message) {
        $record->feedback_message( qq{<p>$to_append</p>} );
    }
    else {
        $record->feedback_message(
              $record->feedback_message
            . qq{<p>$to_append</p>}
        )
    }
    return;
}

sub _promotion_url {
    my $record = shift;
    my $host = config_var('URL', 'url');
    # e.g. http://localhost:8000/NAPEvents/Manage/Edit?id=49
    return
          q{http://}
        . $host
        . q{/NAPEvents/Manage/Edit?id=}
        . $record->id
    ;
}

sub _promotion_link {
    my $record = shift;
    # e.g. <a href="http://localhost:8000/NAPEvents/Manage/Edit?id=49" class="showicon">...</a>
    return
          q{<a href="}
        . $record->_promotion_url
        . q{" class="showicon">}
        . $record->visible_id
        . q{</a>}
    ;
}

# the sub called in the txn_do for export_to_pws()
sub _txn_export_to_pws {
    my ($record, $operator_id, $xt_schema, $pws_schema, $initial_enabled_state) = @_;

    # make sure that convert_tz() support data exists
    #  "The MySQL installation procedure creates the time zone tables in the
    #   mysql database, but does not load them. You must do so manually using
    #   the following instructions"
    # [http://dev.mysql.com/doc/refman/5.0/en/time-zone-support.html]
    #
    # Fix: http://dev.mysql.com/doc/refman/5.0/en/mysql-upgrade.html
    #
    # convert_tz() returns NULL if the timezone data is missing
    CONVERT_TZ_CHECK: {
        # TODO - find a better way to do this
        my $row;
        eval {
            my $dbh = $pws_schema->storage()->dbh();
            my $qry = q{select convert_tz('2009-05-05T01:00:00','UTC','Europe/London') as the_result};
            my $sth = $dbh->prepare($qry);
            $sth->execute;
            $row = $sth->fetchrow_hashref;
        };
        if (my $e = $@) {
            die "CONVERT_TZ() check failed: $@\n";
        }
        elsif (not defined $row->{the_result}) {
            $record->_append_to_feedback(
                  q{<span style="color:red;">}
                . qq{CONVERT_TZ() is returning NULL for }
                . $record->visible_id
                . qq{<br />You may need a tech-type to run the following:<br/>}
                . q{  mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p mysql<br/>}
                . qq{[source: http://dev.mysql.com/doc/refman/5.1/en/time-zone-support.html]}
                . q{</span>}
            );
            $record->_append_to_feedback(
                  q{<span style="color:red;">}
                . q{This prevents us sending "SET time_zone = ?" to MySQL, }
                . q{which means we can't reliably send timestamps to it. }
                . q{<strong>ABORTING EXPORT OF THIS RECORD</strong>. }
                . q{</span>}
            );
            return;
        }
    }

    # try to make timestamps mysql-proof
    # make everything (the same time zone)
    $pws_schema->storage->dbh->do(
        q{SET time_zone = ?},
        undef,
        $record->target_city->timezone,
    );
    foreach my $field (qw/start_date end_date publish_date announce_date close_date end_price_drop_date/) {
        #next; # XXX
        if (defined(my $dt = $record->$field)) {
            $record->$field->set_time_zone( $record->target_city->timezone );
        }
    }

    # DCS-836 - populate publish_date and friends (outnet only)
    if ( $record->is_outnet_event() ) {
        # make sure we've got a publish_date
        if (not defined $record->publish_date) {
            $record->update(
                { publish_date =>
                    $record->start_date
                        ->clone
                        ->subtract( minutes => 10 )
                }
            );
        };
        # make sure we have an announce date
        if (not defined $record->announce_date) {
            $record->update(
                { announce_date =>
                    $record->start_date
                        ->clone
                        ->subtract( minutes => 5 )
                }
            );
        };

        # make sure we have a close date
        if (not defined $record->close_date) {
            $record->update(
                { close_date =>
                    $record->end_date
                        ->clone
                        ->add( minutes => 5 )
                }
            );
        };

        # more DCS-836 (later comment)
        # if we're %-age or free-ship make sure we correctly set
        # product_page_visible and price_group_id
        # [CCW] BUT ONLY FOR EVENTS (outnet)
        #
        # New information 2009-08-25
        # freeship --> ALL
        # discount% --> MARKDOWN
        if ( 'free_shipping' eq $record->discount_type) {
            $record->update(
                {
                    # we don't want these to appear on the event page
                    product_page_visible    => 0,
                    # although everything on Outnet is strictly speaking a
                    # markdown, E.Ors said that he doesn't have/use that
                    # attribute when finding matching products.
                    price_group_id          => $PROMOTION_PRICE_GROUP__ALL_FULL_PRICE__AMP__MARKDOWN,
                }
            );
        }
        elsif ( 'percentage_discount' eq $record->discount_type) {
            $record->update(
                {
                    # we don't want these to appear on the event page
                    product_page_visible    => 0,
                    # although everything on Outnet is strictly speaking a
                    # markdown, E.Ors said that he doesn't have/use that
                    # attribute when finding matching products.
                    price_group_id          => $PROMOTION_PRICE_GROUP__MARKDOWN,
                }
            );
        }
    }

    # copy over the key data (detail)
    my $detail_data = $record->data_as_hash;

    # if the promotion has already been exported, we want to preserve their
    # "enabled" state
    if (defined $detail_data->{id}) {
        #xt_logger->debug('we think we have a remote promotion #' .  $detail_data->{id});
        my $remote_detail = $pws_schema->resultset('Detail')->find(
            $detail_data->{id},
            { key => 'primary' }
        );

        # use the remote value of "enabled" if we found a record
        if (defined $remote_detail) {
            #xt_logger->debug('using remote value of <enabled>: ' .  $remote_detail->enabled);
            $detail_data->{enabled} = $remote_detail->enabled;
        }
        else {
            xt_logger->debug('no remote record found');
        }
    }


    # push into the mysql database
    $pws_schema->resultset('Detail')->update_or_create(
        $detail_data,
        { key => 'primary' }
    );

    # copy over the coupons
    # if the promotion has ever been enabled DO NOT export the coupons
    # again; i.e. if enabled is undef
    if (not $record->been_exported) {
        my $total_coupons = $record->coupons->count;
        my $exported_coupons = 0;
        my $skipped_coupons = 0;

        foreach my $coupon ($record->coupons) {
            # does the coupon already exist in the PWS database?
            my $count = $pws_schema->resultset('Coupon')->count({
                id  => $coupon->id,
            });

            # no coupon? OK to copy over to PWS
            if (not $count) {
                $pws_schema->resultset('Coupon')->create(
                    $coupon->data_as_hash,
                );
                $exported_coupons++;
            }

            # if we have a count ... we're out of sync
            else {
                $record->_append_to_feedback(
                    q{<span style="color:red;">}
                    . 'Coupon #'
                    . $coupon->id
                    . ' ['
                    . $coupon->code
                    . '] already exists in target website database; not exporting - this might not apply promotions you expect it to.'
                );
                $skipped_coupons++;
            }
        }

        # give feedback about the number of coupons exported
        if($skipped_coupons == 0){
         $record->_append_to_feedback(
              'Coupons: '
            . $exported_coupons
            . ' out of '
            . $total_coupons
            . ' exported. Skipped: '
            . $skipped_coupons
        );
        }
        else{
         $record->_append_to_feedback(
            q{<span style="color:red;">}
            . 'Coupons: '
            . $exported_coupons
            . ' out of '
            . $total_coupons
            . ' exported. Skipped: '
            . $skipped_coupons
         );
        }
    }

    # copy over the joins for shipping restrictions
    foreach my $detail_shippingoption ($record->detail_shippingoptions) {
        $pws_schema->resultset('DetailShippingOptions')->update_or_create(
            $detail_shippingoption->data_as_hash,
            {
                key => 'join_data',
            }
        );
    }

    # some feedback
    $record->_append_to_feedback(
        q{Promotion record exported to the website.}
    );

    return;
}

# the sub called in the txn_do for export_promo_to_pws()
sub _txn_export_promo_products_to_pws {
    my ($record, $xt_schema, $pws_schema, $pids) = @_;

    # copy over the key data (detail)
    my $detail_data = $record->data_as_hash;

    # we need to do some date magic

    # get hold of the remote record for the same promo
    my $remote_detail = $pws_schema->resultset('Detail')->find(
        $record->id
    );

    # only situation which is a uh oh.. when there is no existing promotion
    # detail record on the website
    if (not defined $remote_detail) {
        return;
    }

    # if the remote promotion is already disabled, we don't want to re-enable
    # it at the end of the update
    my $remote_enabled = $remote_detail->enabled;

    # While we're exporting the promotion product restrictions, we disable the
    # promotion, to ensure that no-one sneaks through the tiny gap in time
    # while there are NO RESTRICTIONS by product
    # *** but only if we expect product restrictions
    if ($record->expects_product_restrictions) {
        xt_logger->debug('disabling remote promotion ' . $record->visible_id . ' while there are no product restrictions');
        $remote_detail->update( { enabled => 0 });
    }

    # remove the old records to do a refresh for this promo - decided to
    # do this as a simplier approach than trying to sync it
    my $detail_products = $pws_schema->resultset('DetailProduct')->search(
        event_id => $record->id,
    );

    if (defined $detail_products) {
        $detail_products->delete;
    }

    my $loop_times = 5;
#    my $error_pids = [@$pids[0 .. 3000]];
#    Uncomment below for full script

    my $error_pids = $pids;

    my $count = 0;
    while($loop_times > 0 && scalar @{$error_pids} != 0) {
        ($error_pids,$count) = _export_pids_to_pws($record, $xt_schema, $pws_schema,$error_pids,$remote_enabled, $remote_detail, $count);
        $loop_times = $loop_times - 1;
    }

    # logging and emailing any pids that weren't uploaded
    if (defined $error_pids and 'ARRAY' eq ref($error_pids) and @$error_pids) {
        xt_logger->debug(
                q{Products #}
            . join(",", @$error_pids)
            . q{ were not uploaded to live site }
        );
        $record->_append_to_feedback(
                q{<span style="color:red;">}
            . q{Products #}
            . join(",",@$error_pids)
            . q{ were not uploaded to live site}
            . q{</span>}
        );
    }
    return $count;
}


# the sub called in the txn_do for export_promo_to_pws()
sub _export_pids_to_pws {
    ## no critic(ProhibitDeepNests)
    my ($record, $xt_schema, $pws_schema, $pids, $remote_enabled, $remote_detail,$count) = @_;

    my $error_pids = [];

    # loop through the incoming list of PIDs
    foreach my $pid (@{$pids}) {
        my $xt = undef;
        my $xtset = $xt_schema->resultset('Promotion::DetailProduct')->search({
            event_id   => $record->id,
            product_id  => $pid,
        });

        if ($xtset->count == 0) {
            $xt = $xt_schema->resultset('Promotion::DetailProduct')->create({
                event_id   => $record->id,
                product_id  => $pid,
            });
        } else {
            $xt = $xtset->next;
        }


        if (ref($xt) eq 'XTracker::Schema::Result::Promotion::DetailProduct') {
            # make sure the product exists remotely
            my $pws_count;my $err;
            try {
                $pws_count = $pws_schema->resultset('SearchableProduct')->count(
                    { id => $pid }
                );
                $err = 0;
            }
            catch {
                $err = 1;
                push @$error_pids, $pid;
            };
            next if $err;

            # if the product exists remotely, we can add it to the promotion
            if ($pws_count) {
                my $rs;
                try {
                    $rs = $pws_schema->resultset('DetailProduct')->create({
                        event_id   => $record->id,
                        product_id  => $pid,
                    });
                }
                catch
                {
                    push @$error_pids, $pid;
                };
                if (ref($rs) eq 'PWS::Schema::DetailProduct') {
                    $count++;
                    # if $count hits 1, we've just added our first product, and
                    # we're now restricted by (one or more) products
                    if (1 == $count and $record->expects_product_restrictions) {
                        if (not $remote_enabled) {
                            xt_logger->debug('promotion ' . $record->visible_id . ' was disabled before the update - leaving disabled despite having product restrictions');
                            $record->_append_to_feedback(
                                  'Promotion '
                                . $record->visible_id
                                . ' was disabled on the website before the update '
                                . '- leaving disabled despite having product restrictions'
                            );
                        }
                        else {
                            xt_logger->debug('enabling remote promotion ' . $record->visible_id . ' - we have our first product restriction');
                            $record->_append_to_feedback(
                                q{Enabling promotion on Website - we have at least one product restriction}
                            );
                            $remote_detail->update( { enabled => 1 });
                        }
                    }
                }
            }
#            # if it doesn't exist, we _should_ report back to the user
#            # TODO fix up messaging and feedback to the user
            else {
                xt_logger->debug(
                      q{Product #}
                    . $pid
                    . q{ does not exist in the remote database; currently exporting }
                    . $record->visible_id
                );
                $record->_append_to_feedback(
                      q{<span style="color:red;">}
                    . q{Product #}
                    . $pid
                    . q{ does not exist in the website database}
                    . q{</span>}
                );
            }
        }
    }
    return ($error_pids, $count);

}

1;
