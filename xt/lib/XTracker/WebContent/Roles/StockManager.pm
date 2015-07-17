package XTracker::WebContent::Roles::StockManager;

use Moose::Role;

requires 'stock_update';

=head1 NAME

XTracker::WebContent::Roles::StockManager

=head1 DESCRIPTION

Role providing base interface for web stock update managers

=head1 SEE ALSO

L<XTracker::WebContent::StockManagment>
L<XTracker::WebContent::Roles::ContentManagment>

=head1 AUTHORS

Andrew Solomon <andrew.solomon@net-a-porter.com>,
Pete Smith <pete.smith@net-a-porter.com>,
Adam Taylor <adam.taylor@net-a-porter.com>,

=cut

1;
