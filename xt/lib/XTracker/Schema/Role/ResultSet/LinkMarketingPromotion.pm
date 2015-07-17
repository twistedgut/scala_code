package XTracker::Schema::Role::ResultSet::LinkMarketingPromotion;

use NAP::policy;

use MooseX::Role::Parameterized;

=head1 NAME

XTracker::Schema::Role::ResultSet::LinkMarketingPromotion

=head1 DESCRIPTION

Parameterised Role that Creates two methods:

    order_by_*
    get_included_*

Required parameter I<included_and_order_by> is a hash of keys that
have the 'name' & the 'plural' of the look-up option that has a
link table linked to the 'marketing_promotion' table:

    with 'XTracker::Schema::Role::ResultSet::LinkMarketingPromotion' => {
        included_and_order_by => {
            name        => 'country',
            plural      => 'countries',
            # these can be optional if the 'name' will work for both
            join_name         => 'country_list',     # defaults to whatever 'name' is if absent
            description_field => 'country_name',     # defaults to whatever 'name' is if absent
        }
    };

This would generate two methods:
    order_by_country
    get_included_countries

'name' will be assumed to be the look-up table being linked to and also the
name of the field that contains the description of the option, but these can
be overridden using the 'join_name' & 'description_field' keys respectively.

=head2 order_by_*

    $result_set = $rs->order_by_country;

Will return a result set Ordered Alphabetically by the look-up description field,
in the above example it would be sorted by the 'country_name' field on the
'country_list' table.

=head2 get_included_*

    $result_set = $rs->get_included_countries;

Will return a result set (that will be ordered by the 'order_by_*' method) where the
look-up options linked to the Promotion have their 'include' flag set to TRUE. In the
above example it would return a list of Countries that have been linked to the Promotion
via the 'link_marketing_promotion__country' table.

=cut

parameter included_and_order_by => (
    isa      => 'HashRef',
    required => 1,
);

role {
    my $p = shift;

    my $param = $p->included_and_order_by;

    my $name              = $param->{name};
    my $plural            = $param->{plural};
    my $join_name         = $param->{join_name} // $name;
    my $description_field = $param->{description_field} // $name;

    my $order_by_method_name = "order_by_${name}";

    # create the 'order_by_' method
    method $order_by_method_name => sub {
        my $rs = shift;

        return $rs->search( {},
            {
                join     => $join_name,
                order_by => "${join_name}.${description_field}",
            }
        );
    };

    # create the 'get_included_' method
    method "get_included_${plural}" => sub {
        my $rs = shift;

        return $rs->$order_by_method_name->search(
            {
                'me.include' => 1,
            }
        )->search_related( $join_name,
            {},
            {
                # this provides an 'include' flag that easily
                # identifies that the Options ARE Included
                '+select' => \'1',
                '+as'     => 'include',
            }
        );
    };
};

1;
