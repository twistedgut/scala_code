use utf8;
package XTracker::Schema::Result::Public::SubRegion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.sub_region");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sub_region_id_seq",
  },
  "region_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "sub_region",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "countries",
  "XTracker::Schema::Result::Public::Country",
  { "foreign.sub_region_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "region",
  "XTracker::Schema::Result::Public::Region",
  { id => "region_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "return_sub_region_refund_charges",
  "XTracker::Schema::Result::Public::ReturnSubRegionRefundCharge",
  { "foreign.sub_region_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ky8ZWgz/potAsvv08cjCbg


# You can replace this text with custom code or comments, and it will be preserved on regeneration

use Carp;


=head2 can_refund_for_return

    $boolean    = $country->can_refund_for_return( $REFUND_CHARGE_TYPE__??? .. n );

You can pass in one or more Refund Charge Types (such as '_TAX' & '_DUTY') and this method will only return TRUE
if ALL of the types are TRUE. It will check the 'can_refund_for_return' flag on the 'return_sub_region_refund_charge'
table to see if it is TRUE or FALSE.

=cut

sub can_refund_for_return {
    my ($self, @types) = @_; # Refund Charge Types passed in to Check
                             # for, ALL must be TRUE

    if ( !@types ) {
        croak "No Refund Charge Types passed to 'sub_region->can_refund_for_return'";
    }

    my $retval  = 1;

    foreach my $type ( @types ) {
        # there should only be one record per type per sub-region
        my $rec = $self->return_sub_region_refund_charges
                            ->search( { refund_charge_type_id => $type } )->first;
        if ( defined $rec ) {
            $retval = $retval & $rec->can_refund_for_return;        # bitwise AND means only TRUE if ALL TRUE
        }
        else {
            $retval = 0;
        }
    }

    return $retval;
}

=head2 no_charge_for_exchange

    $boolean    = $country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__??? .. n );

You can pass in one or more Refund Charge Types (such as '_TAX' & '_DUTY') and this method will only return TRUE
if ALL of the types are TRUE. It will check the 'no_charge_for_exchange' flag on the 'return_sub_region_refund_charge'
table to see if it is TRUE or FALSE.

=cut

sub no_charge_for_exchange {
    my ($self, @types) = @_; # Refund Charge Types passed in to Check
                             # for, ALL must be TRUE

    if ( !@types ) {
        croak "No Refund Charge Types passed to 'sub_region->no_charge_for_exchange'";
    }

    my $retval  = 1;

    foreach my $type ( @types ) {
        # there should only be one record per type per sub-region
        my $rec = $self->return_sub_region_refund_charges
                            ->search( { refund_charge_type_id => $type } )->first;
        if ( defined $rec ) {
            $retval = $retval & $rec->no_charge_for_exchange;        # bitwise AND means only TRUE if ALL TRUE
        }
        else {
            $retval = 0;
        }
    }

    return $retval;
}

1;
