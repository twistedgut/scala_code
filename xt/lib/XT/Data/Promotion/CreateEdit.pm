package XT::Data::Promotion::CreateEdit;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use XTracker::Logfile qw(xt_logger);
use Data::Dump qw(pp);

use Class::Std;

{
    my %start_date_of               :ATTR( get => 'start_date',             set => 'start_date'                 );
    my %end_date_of                 :ATTR( get => 'end_date',               set => 'end_date'                   );
    my %internal_title_of           :ATTR( get => 'internal_title',         set => 'internal_title'             );
    my %target_city_id_of           :ATTR( get => 'target_city_id',         set => 'target_city_id'             );
    my %discount_percentage_of      :ATTR( get => 'discount_percentage',    set => 'discount_percentage'        );
    my %discount_pounds_of          :ATTR( get => 'discount_pounds',        set => 'discount_pounds'            );
    my %discount_euros_of           :ATTR( get => 'discount_euros',         set => 'discount_euros'             );
    my %discount_dollars_of         :ATTR( get => 'discount_dollars',       set => 'discount_dollars'           );
    my %coupon_target_id_of         :ATTR( get => 'coupon_target_id',       set => 'coupon_target_id'           );
    my %coupon_prefix_of            :ATTR( get => 'coupon_prefix',                                              );
    my %coupon_suffix_of            :ATTR( get => 'coupon_suffix',          set => 'coupon_suffix'              );
    my %coupon_restriction_id_of    :ATTR( get => 'coupon_restriction_id',  set => 'coupon_restriction_id'      );
    my %coupon_generation_id_of     :ATTR( get => 'coupon_generation_id',   set => 'coupon_generation_id'       );
    my %price_group_id_of           :ATTR( get => 'price_group_id',         set => 'price_group_id'             );
    my %basket_trigger_pounds_of    :ATTR( get => 'basket_trigger_pounds',  set => 'basket_trigger_pounds'      );
    my %basket_trigger_euros_of     :ATTR( get => 'basket_trigger_euros',   set => 'basket_trigger_euros'       );
    my %basket_trigger_dollars_of   :ATTR( get => 'basket_trigger_dollars', set => 'basket_trigger_dollars'     );
    my %discount_type_of            :ATTR( get => 'discount_type',          set => 'discount_type'              );
    my %applicability_website_of    :ATTR( get => 'applicability_website',  set => 'applicability_website'      );
    my %shipping_restriction_of     :ATTR( get => 'shipping_restriction',   set => 'shipping_restriction'       );
    my %title_of                    :ATTR( get => 'title',                  set => 'title'                      );
    my %subtitle_of                 :ATTR( get => 'subtitle',               set => 'subtitle'                   );
    my %creator_of                  :ATTR( get => 'creator',                set => 'creator'                    );
    my %last_modified_of            :ATTR( get => 'last_modified',                                              );
    my %last_modifier_of            :ATTR( get => 'last_modifier',          set => 'last_modifier'              );
    my %individual_pids_of          :ATTR( get => 'individual_pids',                                            );
    my %customer_group_include_of   :ATTR( get => 'customer_group_include', set => 'customer_group_include'     );
    my %customer_group_exclude_of   :ATTR( get => 'customer_group_exclude', set => 'customer_group_exclude'     );
    my %include_join_type_of        :ATTR( get => 'include_join_type',      set => 'include_join_type'          );
    my %exclude_join_type_of        :ATTR( get => 'exclude_join_type',      set => 'exclude_join_type'          );
    my %status_id_of                :ATTR( get => 'status_id',              set => 'status_id'                  );
    my %restrict_by_weeks_of        :ATTR( get => 'restrict_by_weeks',      set => 'restrict_by_weeks'          );
    my %restrict_x_weeks_of         :ATTR( get => 'restrict_x_weeks',       set => 'restrict_x_weeks'           );
    my %coupon_custom_limit_of      :ATTR( get => 'coupon_custom_limit',    set => 'coupon_custom_limit'        );
    my %event_type_id_of            :ATTR( get => 'event_type_id',          set => 'event_type_id'              );
    my %product_page_visible_of     :ATTR( get => 'product_page_visible',   set => 'product_page_visible'       );
    my %is_classic_of               :ATTR( get => 'is_classic',             set => 'is_classic'                 );

    sub START {
        my($self) = @_;
    }

    sub set_coupon_prefix {
        my($self, $value) = @_;

        # default value
        $coupon_prefix_of{ident $self} = undef;

        # overwrite with the passed in value (if any)
        if (defined $value) {
            $coupon_prefix_of{ident $self} = $value;
        }
    }

    sub set_individual_pids {
        my ($self, $value) = @_;
        # default value
        $individual_pids_of{ident $self} = undef;

        # overwrite with the passed in value (if any), split at commas
        if (defined $value) {
            my @items = split(m{,\s*}, $value);
            $individual_pids_of{ident $self} = \@items;
        }
    }

}

1;
