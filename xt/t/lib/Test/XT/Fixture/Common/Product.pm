package Test::XT::Fixture::Common::Product;
use NAP::policy "tt", "class";
with ( "Test::XT::Fixture::Role::WithProduct" );

=head1 NAME

Test::XT::Fixture::Common::Product - Common Product fixture setup

=head1 DESCRIPTION

Test fixture with a Product

=cut

# All the Product stuff is in the role, this class is just to be able
# to instantiate it

sub discard_changes { }

