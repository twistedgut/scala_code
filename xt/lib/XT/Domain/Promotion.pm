package XT::Domain::Promotion;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base qw/ XT::Domain /;
use Carp;
use Data::Dump qw(pp);
use Time::HiRes qw/ gettimeofday /;

use XTracker::Logfile qw(xt_logger);
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw( :promotion_status :event_type
    :event_product_visibility );

use Class::Std;
{

    sub events_summary {
        my($self,$conditions) = @_;
        my $schema = $self->get_schema;

        $conditions->{is_classic} = 0;

        return $schema->resultset('Promotion::Detail')->promotion_list()
            ->search( $conditions );
    }

    sub promotion_summary {
        my($self,$conditions) = @_;
        my $schema = $self->get_schema;

        #$conditions->{is_classic} = 1;

        return $schema->resultset('Promotion::Detail')->promotion_list()
            ->search( $conditions );
    }


    # XXX not sure why we have promotion_retrieve() and retrieve_promotion()
    sub promotion_retrieve {
        my($self, $id, $opt) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::Detail')->retrieve_promotion( $id );
    }

    sub retrieve_promotion {
        my($self, $id) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::Detail')
            ->retrieve_promotion( $id );
    }

    sub retrieve_event {
        my($self, $id, $opt) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::Detail')
            ->retrieve_event( $id );
    }

    sub promotion_coupon_targets {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset(
            'Promotion::CouponTarget')->coupontarget_list();
    }

    sub promotion_coupon_restriction {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::CouponRestriction')
            ->couponrestriction_list();
    }

    sub promotion_coupon_restriction_group {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::CouponRestrictionGroup')
            ->couponrestrictiongroup_list();
    }

    sub promotion_coupon_generation {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::CouponGeneration')
            ->action_list();
    }

    sub promotion_price_group {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::PriceGroup')->pricegroup_list();
    }

    sub promotion_target_city {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::TargetCity')->targetcity_list();
    }

    sub promotion_website {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::Website')->site_list();
    }

    sub event_website {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::Website')->event_site_list();
    }

    sub promotion_shippingoption {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::ShippingOption')->shippingoption_list();
    }

    sub customer_group_list {
        my($self, $id) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::CustomerGroup')
            ->customer_group_list()
    }

    sub customer_group_join_list {
        my($self, $id) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Promotion::DetailCustomerGroupJoin')
            ->customer_group_join_list()
    }

    sub _get_matched_pids {
        my($self,$rec) = @_;
        my $schema = $self->get_schema;
        my @pids = $rec->detail_products->get_column('product_id')->all;

        return $rec->applicable_product_list;
    }

    sub _push_to_pws {
        my($self,$rec,$pids,$upload, $oid) = @_;
        my $rv = {};

        return $rv if (not defined $upload);

        $rv = $rec->export_promo_products_to_pws($pids, $oid);

        return $rv
    }

    sub export_promo_products_to_pws {
        my($self,$output,$upload,$timing,$oid) = @_;
        my $schema = $self->get_schema;

        if (not defined $oid) {
            $oid = $APPLICATION_OPERATOR_ID;
        }

        my $process_start_time = gettimeofday;
        print "\n" if (defined $output); # for tidiness of displaying

        my $promos = $schema->resultset('Promotion::Detail')
            ->pws_get_export_promos;

        die "No suitable promotions"
            if (not defined $promos or $promos->count == 0);

        my @msgs = ();
        while (my $rec = $promos->next) {
            my $start_time = gettimeofday;
            print " > ". $rec->id .":". $rec->internal_title if (defined $output);

            # retrieve matched pids
            my $pids = $self->_get_matched_pids( $rec );
            #join @pids, get_promo_products( $rec->id );

            print "  ". scalar @{$pids} if (defined $output);

            # upload if necessary
            my $status = $self->_push_to_pws( $rec, $pids, $upload, $oid );

            if (defined $status and ref($status) eq 'HASH') {
                print " ( " if (defined $output);
                foreach my $key (keys %{$status}) {
                    if (defined $status->{$key}) {
                        print "$key => $status->{$key} " if (defined $output);
                    } else {
                        push @msgs, "WARNING: $key cannot find detail record - "
                            ."products mapping not uploaded";
                    }
                }
                print ")" if (defined $output);
            }

            print "\n" if (defined $output);
            foreach my $mesg (@msgs) {
                print "   $mesg\n" if (defined $output);
            }

            if (defined $timing) {
                print "    promo: ". (gettimeofday - $start_time) ."s\n"
                    if (defined $timing and defined $output);
            }
        }

        print "\n" if (defined $output);
        print "    process: ". (gettimeofday - $process_start_time) ."s\n"
                    if (defined $timing and defined $output);
    }
}

sub update_detail {
    my($self,$attrs) = @_;
    my $schema = $self->get_schema;

    # FIXME: check $results
    # create the summary details
    my $detail = $schema->resultset('Promotion::Detail')->update_or_create(
        {
            # after Outnet launch we default to classic promotion (PROMOTION
            # && 0), but allow other types to be set if required (e.g.
            # /OutnetEvents)
            event_type_id                   => ($attrs->get_event_type_id||$EVENT_TYPE__PROMOTION),
            product_page_visible            => ($attrs->get_product_page_visible||0),
            # anything we create this route is "classic"
            is_classic                      => $attrs->get_is_classic,
            # these are NOT NULL on the PWS database, so let's put something
            # there
            publish_to_announce_visibility  => $EVENT_PRODUCT_VISIBILITY__VISIBLE,
            announce_to_start_visibility    => $EVENT_PRODUCT_VISIBILITY__VISIBLE,
            start_to_end_visibility         => $EVENT_PRODUCT_VISIBILITY__VISIBLE,
            end_to_close_visibility         => $EVENT_PRODUCT_VISIBILITY__VISIBLE,

            created_by                      => $attrs->get_creator,
            last_modified_by                => $attrs->get_last_modifier,

            internal_title                  => $attrs->get_internal_title,
            start_date                      => $attrs->get_start_date,
            target_city_id                  => $attrs->get_target_city_id,
            end_date                        => $attrs->get_end_date,

            title                           => $attrs->get_title,
            subtitle                        => $attrs->get_subtitle,

            discount_percentage             => $attrs->get_discount_percentage,
            discount_pounds                 => $attrs->get_discount_pounds,
            discount_euros                  => $attrs->get_discount_euros,
            discount_dollars                => $attrs->get_discount_dollars,
            coupon_prefix                   => $attrs->get_coupon_prefix,
            coupon_target_id                => $attrs->get_coupon_target_id,
            coupon_restriction_id           => $attrs->get_coupon_restriction_id,
            coupon_generation_id            => $attrs->get_coupon_generation_id,
            price_group_id                  => $attrs->get_price_group_id,
            basket_trigger_pounds           => $attrs->get_basket_trigger_pounds,
            basket_trigger_euros            => $attrs->get_basket_trigger_euros,
            basket_trigger_dollars          => $attrs->get_basket_trigger_dollars,
            discount_type                      => $attrs->get_discount_type,

            restrict_by_weeks               => ($attrs->get_restrict_by_weeks||0),
            restrict_x_weeks                => ($attrs->get_restrict_x_weeks||0),

            coupon_custom_limit             => $attrs->get_coupon_custom_limit,
        },
        { key => 'unique_title' }
    );

    # make sure we fetch the FULL db-record when we use it
    $detail->discard_changes;

    # if our status is "UNKNOWN" progress it to "IN_PROGRESS"
    if ($PROMOTION_STATUS__UNKNOWN == $detail->status_id) {
        $detail->update(
            {
                status_id => $PROMOTION_STATUS__IN_PROGRESS,
            }
        );
    }

    return $detail;
}

sub update_detail_status {
    my ($self, $event_id, $status_id) = @_;
    my $schema = $self->get_schema;

    $schema->resultset('Promotion::Detail')->find($event_id)
    ->update(
        {
            status_id => $status_id,
        }
    );

    return;
}

sub disable {
    my ($self, $event_id) = @_;
    my $schema = $self->get_schema;

    eval {
        # export to the relevant website(s)
        $schema->resultset('Promotion::Detail')->find($event_id)
            ->disable();

        # set the status
        $self->update_detail_status(
            $event_id,
            $PROMOTION_STATUS__DISABLED
        );
    };
    if ($@) {
        xt_logger->error($@);
        # this line caused:
        #      Can't locate class method "xt_warn" via package
        #      "XT::Domain::Promotion" at
        #      lib/XT/Domain/Promotion.pm line 348

        #xt_warn($@);
    }

    return;
}

sub freeze_customers_in_groups {
    my ($self, $event_id, $feedback_to) = @_;
    my $schema = $self->get_schema;

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__GENERATING_CUSTOMER_LISTS
    );

    # start the freeze
    $schema->resultset('Promotion::Detail')->find($event_id)
        ->freeze_customers_in_groups(
            $feedback_to,
        )
    ;

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__GENERATED_CUSTOMER_LISTS
    );

    return;
}

sub generate_coupons {
    my ($self, $event_id) = @_;
    my $schema = $self->get_schema;

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__GENERATING_COUPONS
    );

    # kick off coupon generation
    # start the freeze
    $schema->resultset('Promotion::Detail')->find($event_id)
        ->generate_coupons();

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__GENERATED_COUPONS
    );

    return;
}

sub export_coupons {
    my ($self, $event_id) = @_;
    my $schema = $self->get_schema;

    warn "TODO: export_coupons()";

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__EXPORTING_COUPONS
    );

    # export to the relevant website(s)
    $schema->resultset('Promotion::Detail')->find($event_id)
        ->export_coupons();

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__EXPORTED_COUPONS
    );

    return;
}

sub export_customers {
    my ($self, $event_id) = @_;
    my $schema = $self->get_schema;

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__EXPORTING_CUSTOMERS
    );

    # export to the relevant website(s)
    $schema->resultset('Promotion::Detail')->find($event_id)
        ->export_customers();

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__EXPORTED_CUSTOMERS
    );

    return;
}

sub export_to_lyris {
    my ($self, $event_id) = @_;
    my $schema = $self->get_schema;

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__EXPORTING_TO_LYRIS
    );

    # export to the relevant website(s)
    $schema->resultset('Promotion::Detail')->find($event_id)
        ->export_to_lyris();

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__EXPORTED_TO_LYRIS
    );

    return;
}

sub export_to_pws {
    my ($self, $event_id, $feedback_to) = @_;

    my $schema = $self->get_schema;

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__EXPORTING_TO_PWS
    );

    # export to the relevant website(s)
    $schema->resultset('Promotion::Detail')->find($event_id)
        ->export_to_pws(
            $APPLICATION_OPERATOR_ID,
            $feedback_to
        )
    ;

    # set the status
    $self->update_detail_status(
        $event_id,
        $PROMOTION_STATUS__EXPORTED_TO_PWS
    );

    return;
}

sub update_detail_shippingoptions {
    my ($self, $event_id, $data) = @_;
    my ($site_id_list, $shippingoptions);
    my $schema = $self->get_schema;

    # remove all the existing detail_websites for the current detail
    $schema->resultset('Promotion::DetailShippingOptions')->search(
        {
            event_id => $event_id,
        }
    )
    ->delete;

    $shippingoptions = $data->get_shipping_restriction;

    # if we don't have any "applicability_website" items, then the list was
    # cleared, or never populated - nothing to do
    if (not defined $shippingoptions) {
        return;
    }

    # if we've got a list, just use it, otherwise "promote" a scalar to a list
    # elelent
    if ('ARRAY' eq ref($shippingoptions)) {
        # it's already an array-ref
        $site_id_list = $shippingoptions;
    }
    else {
        # promote to array-ref
        $site_id_list = [ $shippingoptions ];
    }

    # add all selected websites to detail_websites for the
    # current detail
    foreach my $site_id (@{$site_id_list}) {
        $schema->resultset('Promotion::DetailShippingOptions')->create(
            {
                event_id           => $event_id,
                shippingoption_id   => $site_id,
            }
        );
    }

    return;
}

sub update_detail_websites {
    # FIXME: shouldnt be playing with handlers isntance at this level
    my ($self, $event_id, $data) = @_;
    my ($site_id_list);
    my $schema = $self->get_schema;

    # remove all the existing detail_websites for the current detail
    $schema->resultset('Promotion::DetailWebsites')->search({
        event_id => $event_id,
    })->delete;


    # if we don't have any "applicability_website" items, then the list was
    # cleared, or never populated - nothing to do
    if (not defined $data->get_applicability_website) {
        return;
    }

    my $applicability_website = $data->get_applicability_website;

    # if we've got a list, just use it, otherwise "promote" a scalar to a list
    # elelent
    if ('ARRAY' eq ref($applicability_website)) {
        # it's already an array-ref
        $site_id_list = $applicability_website;
    }
    else {
        # promote to array-ref
        $site_id_list = [ $applicability_website ];
    }

    # add all selected websites to detail_websites for the
    # current detail
    foreach my $site_id (@{$site_id_list}) {
        $schema->resultset('Promotion::DetailWebsites')->create(
            {
                event_id   => $event_id,
                website_id  => $site_id,
            }
        );
    }

    return;
}

sub DEPRECATED_update_summary {
    my($self,$event_id,$attrs) = @_;
    my $schema = $self->get_schema;

    my $promotion = $schema->resultset('Promotion::Detail')
        ->update_or_create(
        {
            internal_title           => $attrs->get_internal_title,
            start_date      => $attrs->get_start_date,
            target_city_id  => $attrs->get_target_city_id,
            #event_id       => $event_id,
            end_date        => $attrs->get_end_date,
        },
        {
            key => 'unique_internal_title',
        }
    );

    return $promotion;
}

# this gets called in a txn_do elsewhere
# call it outside one at your own [data's] risk
sub update_summary_seasons {
    my ($self,$results, $promo_id) = @_;
    my ($season_id_list);
    my $schema = $self->get_schema;

    # remove all the existing detail_websites for the current detail
    $schema->resultset('Promotion::DetailSeasons')->search(
        {
            event_id => $promo_id,
        }
    )
    ->delete;

    # if we don't have any "applicability_website" items, then the list was
    # cleared, or never populated - nothing to do
    if (not defined $results->valid('season_checkboxes')) {
        return;
    }
    # if we've got a list, just use it, otherwise "promote" a scalar to a list
    # elelent
    if ('ARRAY' eq ref($results->valid('season_checkupdate_summary_productsboxes'))) {
        # it's already an array-ref
        $season_id_list = $results->valid('season_checkboxes');
    }
    else {
        # promote to array-ref
        $season_id_list = [ $results->valid('season_checkboxes') ];
    }

    # add all selected websites to summary_seasons for the
    # current detail
    foreach my $season_id (@{$season_id_list}) {
        $schema->resultset('Promotion::DetailSeasons')->create(
            {
                event_id   => $promo_id,
                season_id   => $season_id,
            }
        );
    }

    return;
}

# this gets called in a txn_do elsewhere
# call it outside one at your own [data's] risk
sub update_summary_designers {
    my ($self, $results, $promo_id) = @_;
    my ($designer_id_list);
    my $schema = $self->get_schema;

    # remove all the existing detail_websites for the current detail
    $schema->resultset('Promotion::DetailDesigners')->search(
        {
            event_id => $promo_id,
        }
    )
    ->delete;

    # if we don't have any "applicability_website" items, then the list was
    # cleared, or never populated - nothing to do
    if (not defined $results->valid('designer_checkboxes')) {
        return;
    }
    # if we've got a list, just use it, otherwise "promote" a scalar to a list
    # elelent
    if ('ARRAY' eq ref($results->valid('designer_checkboxes'))) {
        # it's already an array-ref
        $designer_id_list = $results->valid('designer_checkboxes');
    }
    else {
        # promote to array-ref
        $designer_id_list = [ $results->valid('designer_checkboxes') ];
    }

    # add all selected websites to summary_designers for the
    # current detail
    foreach my $designer_id (@{$designer_id_list}) {
        $schema->resultset('Promotion::DetailDesigners')->create(
            {
                event_id  => $promo_id,
                designer_id => $designer_id,
            }
        );
    }

    return;
}

# this gets called in a txn_do elsewhere
# call it outside one at your own [data's] risk
sub update_summary_producttypes {
    my ($self, $results, $promo_id) = @_;
    my ($producttype_id_list);
    my $schema = $self->get_schema;

    # remove all the existing detail_websites for the current detail
    $schema->resultset('Promotion::DetailProductTypes')->search(
        {
            event_id => $promo_id,
        }
    )
    ->delete;

    # if we don't have any "applicability_website" items, then the list was
    # cleared, or never populated - nothing to do
    if (not defined $results->valid('producttype_checkboxes')) {
        return;
    }
    # if we've got a list, just use it, otherwise "promote" a scalar to a list
    # elelent
    if ('ARRAY' eq ref($results->valid('producttype_checkboxes'))) {
        # it's already an array-ref
        $producttype_id_list = $results->valid('producttype_checkboxes');
    }
    else {
        # promote to array-ref
        $producttype_id_list = [ $results->valid('producttype_checkboxes') ];
    }

    # add all selected websites to summary_designers for the
    # current detail
    foreach my $producttype_id (@{$producttype_id_list}) {
        $schema->resultset('Promotion::DetailProductTypes')->create(
            {
                event_id      => $promo_id,
                producttype_id  => $producttype_id,
            }
        );
    }

    return;
}

# this gets called in a txn_do elsewhere
# call it outside one at your own [data's] risk
sub update_summary_products {
    my ($self, $results, $promo_id) = @_;
    my ($pid_list, @pids);
    my $schema = $self->get_schema;

    # remove all the existing detail_websites for the current detail
    $schema->resultset('Promotion::DetailProducts')->search(
        {
            event_id => $promo_id,
        }
    )
    ->delete;

    # if we don't have any "applicability_website" items, then the list was
    # cleared, or never populated - nothing to do
    if (not defined $results->valid('product_pid_list')) {
        return;
    }

    @pids = split(m{,\s*}, $results->valid('product_pid_list'));

    # add all selected websites to summary_designers for the
    # current detail
    foreach my $pid (@pids) {
        $schema->resultset('Promotion::DetailProducts')->create(
            {
                event_id       => $promo_id,
                product_id      => $pid,
            }
        );
    }

    return;
}

sub update_customer_groups {
    my ($self, $results, $promo_id) = @_;
    my ($group_list);
    my $schema = $self->get_schema;


    # the sub should already be called in a txn_do() but it doesn't hurt to be
    # careful and cautious
    $schema->txn_do(
        sub {
            # remove all the existing detail_customergroup entries
            $schema->resultset('Promotion::DetailCustomerGroup')->search(
                {
                    event_id => $promo_id,
                }
            )
            ->delete;

            # add the items in each list
            foreach my $list_type (qw[include exclude]) {
                ## add all the items in the current list
                $group_list = $results->valid("group_${list_type}_checkboxes");

                # if the group list isn't defined, don't try to add anything
                next
                    if (not defined $group_list);

                # if we've need to otherwise "promote" a scalar to a list element
                if ('ARRAY' ne ref($group_list)) {
                    # promote to array-ref
                    $group_list = [ $group_list ];
                }

                if (defined $group_list) {
                    foreach my $group_id (@{$group_list}) {
                        $schema->resultset('Promotion::DetailCustomerGroup')->create(
                            {
                                event_id           => $promo_id,
                                customergroup_id    => $group_id,

                                # perldoc DBIx::Class::ResultSet
                                # "Example of creating a new row and also creating a row
                                # in a related belongs_to"resultset."
                                listtype => {
                                    name => $list_type,
                                },
                            }
                        );
                    } # foreach
                } # if
            } # foreach

            # store the customer_group_joins
            $self->update_customer_group_joins($results, $promo_id);
        } # sub
    );

    return;
}

sub create_generic_coupon {
    my ($self, $promo_id, $data) = @_;
    my ($schema, $record, $coupon_rs, $coupon, $new_coupon_data);

    $schema = $self->get_schema;
    $record = $schema->resultset('Promotion::Detail')->find($promo_id);

    # the data we'll always set
    $new_coupon_data = {
        prefix              => $data->get_coupon_prefix,
        suffix              => $data->get_coupon_suffix,
        code                => ($data->get_coupon_prefix .  $data->get_coupon_suffix),

        event_id           => $record->id(),
        valid               => 1,
    };

    # any coupon restrictions?
    if (defined $record->coupon_restriction) {
        $new_coupon_data->{usage_limit}   = $record->coupon_restriction->usage_limit();
        $new_coupon_data->{usage_type_id} = $record->coupon_restriction->group_id();

        # if there's a custom usage limit, nuke the menu value
        if ($record->has_custom_coupon_limit) {
            $new_coupon_data->{usage_limit} = $record->coupon_custom_limit;
            xt_logger->info(
                  q{(generic) using custom usage limit: }
                . $new_coupon_data->{usage_limit}
            ) if (1);
        }
    }


    # search for an existing coupon
    # (tried to use update_or_create() but I couldn't get it to play nice, so
    # opted for the manual implementation of the same idea - CCW)
    $coupon_rs = $schema->resultset('Promotion::Coupon')->search(
        {
            event_id   => $record->id(),
        },
    );
    if ($coupon_rs->count > 0) {
        # make sure we don't have too many coupons
        if ($coupon_rs->count > 1) {
            die "Too many coupons for a GENERIC COUPON promotion";
        }
        # fetch the first (and only) coupon
        $coupon = $coupon_rs->first;
    }

    # UPDATE OR CREATE the coupon
    if (defined $coupon) {
        # update the existing coupon
        $coupon->update(
            $new_coupon_data,
        );
    }
    else {
        # create the new coupon
        $schema->resultset('Promotion::Coupon')->create(
            $new_coupon_data,
        );
    }

    return;
}

# we'd expect this to be called from update_customer_groups() [above]
# but I'm sure someone will call it from somewhere random
sub update_customer_group_joins {
    my ($self, $results, $promo_id) = @_;
    my ($join_id);
    my $schema = $self->get_schema;

    # the sub should already be called in a txn_do() but it doesn't hurt to be
    # careful and cautious
    $schema->txn_do(
        sub {
            # remove all the existing join entries
            $schema->resultset('Promotion::DetailCustomerGroupJoinListType')->search(
                {
                    event_id => $promo_id,
                }
            )
            ->delete;

            # for each list type we need to store the promo/listtype/join
            # record
            foreach my $list_type (qw[include exclude]) {
                $join_id = $results->valid("${list_type}_join_type");

                # if we don't have a join .. default to AND
                if (not defined $join_id) {
                    $join_id =
                        $schema->resultset('Promotion::DetailCustomerGroupJoin')
                            ->search(
                                {
                                    'type' => 'AND',
                                }
                            )
                            ->first
                                ->id;
                }

                # store the relevant information
                $schema->resultset('Promotion::DetailCustomerGroupJoinListType')->create(
                    {
                        event_id                       => $promo_id,
                        detail_customergroup_join_id    => $join_id,

                        # perldoc DBIx::Class::ResultSet
                        # "Example of creating a new row and also creating a row
                        # in a related belongs_to"resultset."
                        listtype => {
                            name => $list_type,
                        },
                    }
                );
            } # foreach
        } # sub
    );

    return;
}

sub _tx_add_customer_to_promotion {
    my ( $self, $customer_id, $customer_group_id, $website_id, $operator_id ) = @_;

    my $schema = $self->get_schema;

    # Check if customer group exists
    my $group = $schema->resultset('Promotion::CustomerGroup')
        ->find( $customer_group_id );

    # No matching groups
    if ( not $group ) {
        croak("There was an error adding customer $customer_id: customer
            group $customer_group_id does not exist");
    }

    my $customer = $schema->resultset('Promotion::CustomerCustomerGroup')
        ->create(
            {
                customer_id         => $customer_id,
                customergroup_id    => $group->id,
                website_id          => $website_id,
                created_by          => $operator_id,
                modified_by         => $operator_id,
            }
        )
    ;

    return $customer;
}

# Gets the customer using the customer ID and the customer group ID
sub get_customer_by_cid_cgid {
    my ( $self, $customer_id, $customer_group_id ) = @_;

    my $ccg_rs = $self->get_schema->resultset('Promotion::CustomerCustomerGroup');

    my $customer_rs = $ccg_rs->get_by_customer_and_group(
        $customer_id,
        $customer_group_id,
    );

    return $customer_rs;
}

sub get_customer_by_join_data {
    my ( $self, $customer_id, $customer_group_id, $website_id ) = @_;

    my $ccg_rs = $self->get_schema->resultset('Promotion::CustomerCustomerGroup');

    my $ccg = $ccg_rs->get_by_join_data(
        $customer_id,
        $customer_group_id,
        $website_id,
    );

    return $ccg;
}

sub get_group_promotions {
    my ( $self, $customer_group_id ) = @_;

    my $cg_rs = $self->get_schema->resultset('Promotion::CustomerGroup');

    return $cg_rs->find( $customer_group_id )->get_promotions;
}

1;

__END__

=pod

=head1 NAME

XT::Domain::Promotion;

=head1 AUTHOR

Chisel Wright

Jason Tang

=cut

