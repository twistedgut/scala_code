package NAP::Carrier;
use Moose;

=head1 NAME

NAP::Carrier - generalised API for Carrier interaction

=head2 SYNOPSIS

  # new carrier object
  # - by shipment
  my $carrier = NAP::Carrier->new({dbh => $dbh, shipment_id => $shipment_id});
  # - or by manifest
  my $carrier = NAP::Carrier->new({dbh => $dbh, manifest_id => $manifest_id});

  # address validation for order importing
  my $carrier = NAP::Carrier->new({dbh => $dbh, shipment_id => $shipment_id});
  if (not defined $carrier) {
      $carrier->set_address_validator('DHL');
  }
  $carrier->validate_address;


=head1 METHODS

=over 4

=item new

Create a new C<NAP::Carrier> object. Requires I<one> of C<shipment> or
C<manifest> as well as a I<dbh>.

  # new carrier object - by shipment
  my $carrier = NAP::Carrier->new(
   {
    dbh => $dbh,
    shipment_id => $shipment_id
   }
  );

  # new carrier object - by manifest
  my $carrier = NAP::Carrier->new(
   {
    dbh => $dbh,
    manifest_id => $manifest_id
   }
  );

=item get_quality_rating_threshold

=item name

=item classification

=item quality_rating

=item set_address_validator

=item validate_address

=item manifest

=item deduce_autoable

=item is_autoable

=back

=head1 METHODS FOR THE FUTURE

Not immediately needed, but might be helpful

=over 4

=item carrier_label_format

=back

=cut

with 'XTracker::Role::WithSchema';

use Carp qw<carp>;
use XTracker::Constants::FromDB qw( :shipment_type );

use Module::Pluggable
    search_path     => ['NAP::Carrier'],
    sub_name        => 'carriers',
    require         => 1,
;

has carrier => (
    is          => 'rw',
    reader      => 'carrier',
    writer      => 'set_carrier',
);

has carrier_name => (
    is          => 'rw',
    reader      => 'name',
    writer      => 'set_name',
);

has carrier_classification => (
    is          => 'rw',
    reader      => 'classification',
    writer      => 'set_classification',
);

has shipment_id => (
    is          => 'ro',
    isa         => 'Int',
    init_arg    => 'shipment_id',
);

has manifest_id => (
    is          => 'ro',
    isa         => 'Int',
    init_arg    => 'manifest_id',
);

has operator_id => (
    is          => 'ro',
    isa         => 'Int',
    init_arg    => 'operator_id',
    required    => 1,
);

has _manifest => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Manifest',
    init_arg    => undef, # stop it being set by evil users
    writer      => '_set_manifest', # from Moose::Manual::Attributes
    reader      => 'manifest',
);

has _shipment => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Shipment',
    init_arg    => undef, # stop it being set by evil users
    writer      => '_set_shipment', # from Moose::Manual::Attributes
    reader      => 'shipment',
);

has _operator => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Operator',
    builder     => '_build_operator',
    lazy        => 1,
    init_arg    => undef,
    writer      => '_set_operator',
    reader      => 'get_operator',
);

has _address_validator => (
    is          => 'rw',
    isa         => 'Str',
    builder     => '_build_address_validator',
    lazy        => 1,
    reader      => 'address_validator',
    writer      => 'set_address_validator',
);

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

sub BUILDARGS {
    my $class = shift;
    my $argref = $_[0];

    # we need EITHER shipment_id XOR manifest_id
    my $count = 0;
    $count += defined($argref->{shipment_id}) || 0;
    $count += defined($argref->{manifest_id}) || 0;
    if ($count != 1) {
        die 'must specify exactly ONE of shipment_id or manifest_id'
    }

    return $class->SUPER::BUILDARGS(@_);
}

# set the operator
sub _build_operator {
    my $self    = shift;

    my $operator;

    eval {
        $operator   = $self->schema->resultset('Public::Operator')->find(
            $self->operator_id
        );
    };

    if (defined $operator) {
        $self->_set_operator($operator);
        return $self->get_operator;
    }

    # we didn't match anything - oopsie
    carp "no available operator for operator_id=" . $self->operator_id;
    return;
}

sub _build_address_validator {
    my $self = shift;
    $self->set_address_validator(
        $self->name
    );
}

sub BUILD {
    my $self = shift;

    # get the name of the class
    my $class = ref($self);

    # only do the "evil voodoo" for NAP::Carrier, not the subclasses
    if (__PACKAGE__ eq $class) {
        # derive the carrier (name) from the shipment/manifest
        my $subclass = $self->_derive_carrier_class;
        my $carrier_class = "${class}::${subclass}";

        # make sure we re-bless to something we know we have as a carrier
        my @instantiated = grep { m[\A${carrier_class}\z] } $class->carriers;
        if(@instantiated < 1) {
            die qq{can't instantiate $carrier_class module};
        }
        elsif(@instantiated > 1) {
            die qq{more than one module found matching $carrier_class};
        }

        # rebless ourself?
        my $new_oject = bless $self, $carrier_class;
        # call out BUILD method, to tie up loose ends
        return $new_oject->BUILD(@_);
    }
}

sub _derive_carrier_class {
    my $self = shift;

    if (defined $self->shipment_id) {
        $self->_derive_carrier_class_from_shipment;
    }
    elsif (defined $self->manifest_id) {
        $self->_derive_carrier_class_from_manifest;
    }
    else {
        # BUILDARGS validation shouldn't let us get here
        die "there's no way for me to deduce the carrier";
    }
    return $self->name;
}

sub _derive_carrier_class_from_manifest {
    my $self = shift;
    my $manifest;

    eval {
        $manifest = $self->schema->resultset('Public::Manifest')->find(
            $self->manifest_id
        );
    };

    if (defined $manifest) {
        $self->_set_manifest($manifest);
        $self->_split_carrier_name($manifest->carrier->name);
        return $self->name;
    }

    # we didn't match anything - oopsie
    carp "no available manifest for manifest_id=" . $self->manifest_id;
    return;
}

sub _derive_carrier_class_from_shipment {
    my $self = shift;
    my $shipment;

    eval {
        $shipment = $self->schema->resultset('Public::Shipment')->find(
            $self->shipment_id
        );
    };

    if (defined $shipment) {
        $self->_set_shipment($shipment);
        $self->_split_carrier_name($shipment->carrier->name);
        return $self->name;
    }

    # we didn't match anything - oopsie
    carp "no available shipment for shipment_id=" . $self->shipment_id;
    return;
}

sub _split_carrier_name {
    my $self = shift;
    my $name = shift;

    # store the full carrier name
    $self->set_carrier($name);

    if ( defined $self->shipment && $self->shipment->shipment_type_id == $SHIPMENT_TYPE__PREMIER ) {
        # name and classification get set to Premier
        $self->set_name('Premier');
        $self->set_classification('Premier');
        return;
    }

    # if we have UPS or DHL in the name, strip anything from the first
    # whitespace onwards, the last portion will be used to set the
    # classification
    if (
        my ($n,$c) = ($name =~ m{
            (DHL|UPS)
            \s+
            (.+)
        }xms)
    ) {
        $self->set_name($n);
        $self->set_classification($c);
    }
    else {
        # name and classification default to being the same
        $self->set_name($name);
        $self->set_classification($name);
    }

    return;
}


# the following methods should be implemented by the kiddie modules

sub deduce_autoable
    { carp "Abstract method 'deduce_autoable' not implemented for " . ref $_[0]; }
sub is_autoable
    { carp "Abstract method 'is_autoable' not implemented for " . ref $_[0]; }
sub quality_rating
    { carp "Abstract method 'quality_rating' not implemented for " . ref $_[0]; }
sub validate_address
    { carp "Abstract method 'validate_address' not implemented for " . ref $_[0]; }


=head2 is_virtual_shipment

Returns true if the shipment is virtual only - ie there is no physical
shipment.

=cut

sub is_virtual_shipment {
    my $self = shift;

    return 1 if $self->shipment->is_virtual_voucher_only;
    return 0;
}

1;
__END__

=pod

=head1 SYNOPSIS

  use NAP::Carrier;

  my $carrier = NAP::Carrier->build($argref);

  if ($carrier->is_autoable) {
  }
  else {
  }

=head1 XTracker::Database::Shipment

  sub is_autoable {
    my $dbh = shift
    my $sid = shift;
    my $carrier = NAP::Carrier->build($argref)(
     {
      dbh => $dbh,
      shipment_id => $shipment_id,
     }
    );
    return $carrier->is_autoable;
  }

=cut
