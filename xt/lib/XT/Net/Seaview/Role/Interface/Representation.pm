package XT::Net::Seaview::Role::Interface::Representation;

use NAP::policy "tt", 'role';

=head1 NAME

XT::Net::Seaview::Role::Representation

=head1 DESCRIPTION

XT/Seaview resource representation interface

=head1 REQUIRED METHODS

=head2 identity

Resource identity

=cut

requires '_build_identity';

=head2 media_type

The representations media type

=cut

requires 'media_type';

=head2 to_rep

Create a representation

=cut

requires 'to_rep';
