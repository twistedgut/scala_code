use utf8;
package XTracker::Schema::Result::Operator::StickyPage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("operator.sticky_page");
__PACKAGE__->add_columns(
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "signature",
  { data_type => "text", is_nullable => 0 },
  "html",
  { data_type => "text", is_nullable => 1 },
  "sticky_class",
  { data_type => "text", is_nullable => 0 },
  "sticky_id",
  { data_type => "integer", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "sticky_url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("operator_id");
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Lg581GRoDVKpqu2v0FBzhA

use Moose;

use Digest::MD5 'md5_hex';
use XTracker::DBEncode  qw( encode_it );

{
    # Inflate to correct subclass based on sticky_class column
    around inflate_result => sub {
        my ($orig, $class, $source, $cols, $prefetch) = @_;

        # Work out which (subclass) to bless it into.
        my $sticky_class = $cols->{sticky_class};
        if ($class eq __PACKAGE__) {
            # ensure we have a sticky class...
            confess "sticky_page.sticky_class not set!" unless $sticky_class;

            # work out result class name
            #   XTracker::Schema::Result::Operator::StickyPage
            # ->XTracker::Schema::Result::Some::Sticky::Class
            $class =~ s/^(.*::Result::).*$/$1$sticky_class/;
            __PACKAGE__->ensure_class_loaded($class);
        }

        # This calls into DBIC and does the bless into the (new) $class
        return $class->$orig($source, $cols, $prefetch);
    };

    # Fill in sticky_class automatically upon creation
    around new => sub {
        my ($orig, $class, $args) = @_;

        if (!defined $args->{sticky_class}) {
            (my $sticky_class = $class) =~ s/^.*::Result:://;
            $args->{sticky_class} = $sticky_class;
        }

        return $class->$orig($args);
    };
}

=item is_valid

Returns a boolean indicating whether or not this sticky page is still valid,
i.e. whether the signature object has changed since the signature was recorded.

=cut

sub is_valid {
    my ( $self ) = @_;

    # check existing signature against newly calculated signature
    my $current_sig = $self->signature;

    return ($current_sig && $current_sig eq $self->_calculate_new_signature);
}

sub _calculate_new_signature {
    my ( $self ) = @_;

    if (my $signature_object = $self->signature_object) {
        if ( $signature_object->can('state_signature') ) {
            return md5_hex( encode_it($signature_object->state_signature) );
        } else {
            confess "Signature object $signature_object does not support state signature";
        }
    }

    return '';
}

=item description

Returns a human-readable description of the sticky page.

=cut

sub description {
    my ($self) = @_;
    confess 'StickyPage subclass must override description';
}

=item is_valid_exit_url

Returns a boolean indicating whether or not the supplied exit URL is a valid
exit URL for this sticky page, i.e. whether or not the exit should be allowed
and the sticky page object therefore be deleted.

=cut

sub is_valid_exit_url {
    my ( $self, $url, $param_of ) = @_;
    confess 'StickyPage subclass must override is_valid_exit_url';
}

=item signature_class

Returns the name of the DBIC class from which to generate the signature.

=cut

sub signature_object_class {
    confess 'StickyPage subclass must override signature_object_class';
}

=item signature_object

Returns the object from which to generate the signature.

=cut

sub signature_object {
    my $self = shift;

    my $obj_class = $self->signature_object_class;
    my $obj_id = $self->sticky_id;

    return $self->result_source->schema->resultset($obj_class)->find($obj_id);
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
