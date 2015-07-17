package Test::XTracker::Data::Packaging;
use NAP::policy "tt", 'class';
use Test::XTracker::Data;

=head1 NAME

Test::XTracker::Data::Packaging - Packaging test helper methods

=head1 METHODS

=head2 grab_packaging_attribute

  $pa = Test::XTracker::Data::Packaging->grab_packaging_attribute();

Returns a L<XTracker::Schema::Result::Public::PackagingAttribute> object.
Optionally accepts the following arguments:

  $pa = Test::XTracker::Data::Packaging->grab_packaging_attribute({
        name => 'foo',
        channel_id => 1,
        description => 'bar',
        packaging_type_id => $packaging_type->id,
  });

=cut

sub grab_packaging_attribute {
    my ( $class, $args ) = @_;

    my $schema = Test::XTracker::Data->get_schema();

    my $default_channel_id = Test::XTracker::Data->get_local_channel_or_nap('nap')->id;

    $schema->resultset('Public::PackagingAttribute')->find_or_create({
        name => $args->{name} // 'packaging',
        public_name => $args->{public_name} // 'public packaging',
        channel_id => $args->{channel_id} // $default_channel_id,
        title => $args->{title} // 'NAP Packaging',
        public_title => $args->{public_title} // 'Public NAP Packaging',
        description => $args->{description} // 'lovely packaging',
        packaging_type_id => $class->grab_packaging_type->id,
    });
}

=head2 grab_packaging_type

  $pt = Test::XTracker::Data::Packaging->grab_packaging_type();

Returns a L<XTracker::Schema::Result::Public::PackagingType> object.

=cut

sub grab_packaging_type {
    my ( $class ) = @_;

    my $schema = Test::XTracker::Data->get_schema();

    return $schema->resultset('Public::PackagingType')->search(
        {}, { order_by => { -desc => 'id' } }
    )->slice(0,0)->single;
}

=head1 SEE ALSO

L<Test::XTracker::Data>

=cut
