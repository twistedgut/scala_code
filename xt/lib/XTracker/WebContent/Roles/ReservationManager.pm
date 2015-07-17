package XTracker::WebContent::Roles::ReservationManager;

use Moose::Role;

requires 'reservation_upload';
requires 'reservation_cancel';
requires 'reservation_update_expiry';

=head1 NAME

XTracker::WebContent::Roles::ReservationManager

=head1 DESCRIPTION

Role providing base interface for reservation update manages

=head1 SEE ALSO

L<XTracker::WebContent::StockManagment>
L<XTracker::WebContent::Roles::ContentManagment>

=head1 AUTHORS

Adam Taylor <adam.taylor@net-a-porter.com>

=cut

1;
