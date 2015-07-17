use utf8;
package XTracker::Schema::Result::Public::MarketingGenderProxy;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.marketing_gender_proxy");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "marketing_gender_proxy_id_seq",
  },
  "title",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("marketing_gender_proxy_title_key", ["title"]);
__PACKAGE__->has_many(
  "link_marketing_promotion__gender_proxies",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionGenderProxy",
  { "foreign.gender_proxy_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:K0kSF0MovaNYs80Ivc/AVA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
