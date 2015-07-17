use utf8;
package XTracker::Schema::Result::Public::Business;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.business");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "business_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "config_section",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "url",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "show_sale_products",
  { data_type => "boolean", is_nullable => 0 },
  "email_signoff",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "email_valediction",
  { data_type => "char", is_nullable => 1, size => 50 },
  "fulfilment_only",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "client_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("business_name_key", ["name"]);
__PACKAGE__->has_many(
  "channels",
  "XTracker::Schema::Result::Public::Channel",
  { "foreign.business_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "client",
  "XTracker::Schema::Result::Public::Client",
  { id => "client_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "third_party_skus",
  "XTracker::Schema::Result::Public::ThirdPartySku",
  { "foreign.business_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gQwcJyNY9sv66dAMzLD7OA

use XTracker::SchemaHelper qw(:records);
use XTracker::Constants::FromDB     qw( :business );
use XTracker::Config::Local qw/config_var/;


=head2 short_name( )

Returns a short version of the channel name.

=cut


# FIXME: should probably rename config_section to short_name and make it unique
sub short_name {
    my($self) = @_;
    return $self->config_section;
}

=head2 branded_date

    $string = branded_date( $DateTime_Object );

Given a DateTime object this returns the Date in a string consistent with the Net-A-Porter Company wide branding (across all DC's),
which is:
    NaP & The Outnet:
        'Month Day, Year' I.E. 'September 5, 2012'

    MrP & Jimmy Choo:
        'Dayth Month Year' I.E. '5th September 2012'

=cut

sub branded_date {
    my ( $self, $date ) = @_;

    return ''       if ( !$date || ref( $date ) ne 'DateTime' );

    # default format of 'September 5, 2012' which is used for NaP & The Outnet
    my $format_str  = 'MMMM d, y';

    if ( $self->id == $BUSINESS__MRP || $self->id == $BUSINESS__JC ) {
        # format for MrP & Jimmy Choo
        my $suffix  = $self->_dotm_suffix( $date->day );
        $format_str = "d'$suffix' MMMM y";
    }

    return $date->format_cldr( $format_str );
}

# helper method to give the correct suffix to the day of the month
sub _dotm_suffix {
    my ( $self, $day ) = @_;

    my $suffix  = 'th';     # default
    my %suffixes= (
            1   => 'st',
            2   => 'nd',
            3   => 'rd',
            21  => 'st',
            22  => 'nd',
            23  => 'rd',
            31  => 'st',
        );

    return (
            exists( $suffixes{ $day } )
            ? $suffixes{ $day }
            : $suffix
       );
}

=head2 branded_salutation

Given a hash containing first_name, last_name and title fields, return
the salutation in a string consistent with the Net-A-Porter
company-wide branding for this business, which is:

    NAP & Outnet (and, I guess, Jimmy Choo):

        first_name

    Mr P:

        title last_name

      or, if either of title or last_name is not available:

        first_name last_name

Note that this doesn't return the 'Dear ' part of the salutation, just
what comes after it.  Because, I don't know, localization.

=cut

sub branded_salutation {
    my ( $self, $arghash ) = @_;

    # presumes first_name is always available
    return $arghash->{first_name} unless $self->id == $BUSINESS__MRP;

    return $arghash->{title}.' '.$arghash->{last_name}
      if   $arghash->{title}  && $arghash->{last_name};

    # use join to avoid silliness when only one of first_ and last_name is defined
    return join(' ',$arghash->{first_name},$arghash->{last_name});
}

=head2 is_nap

Returns true if the business is Net-A-Porter.

=cut
sub is_nap { shift->id == $BUSINESS__NAP; }

=head2 does_refund_shipping

Returns true if this business refunds the original cost of shipping for returns

=cut
sub does_refund_shipping {
    my ($self) = @_;
    my $sec = $self->config_section();
    return config_var( "Returns_$sec", 'refund_shipping');
}

1;
