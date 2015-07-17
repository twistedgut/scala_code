package Test::XTracker::LoadTestConfig;
use strict;
use warnings;

=head1 NAME

Test::XTracker::LoadTestConfig

=head1 DESCRIPTION

Initialize L<Test::XTracker::Config> appropriately

=head1 SYNOPSIS

 use Test::XTracker::LoadTestConfig;

=head1 WHY

XTracker's configuration loading process is long and distinguished, and enough
of a pain in the ass to require its own loading module when used in tests.

In order to successfully load the Test config, it requires an environment var
to be set (C<XT_CONFIG_LOCAL_SUFFIX>, and to be C<import()>'d with the root
directory we're running from.

While L<Test::XTracker::Data> will do this, it turns out that a great way to
make tests fast is to skip out the loading of L<XTracker::Schema>, which also
means avoiding L<Test::XTracker::Data>.

This module does the necessary setup to get L<Test::XTracker::Config> loaded,
doesn't overwrite previous loadings, and doesn't do anything that will cause
L<XTracker::Schema> to be loaded. If you need to use L<XTracker::Config> to
look up values, load this first to hide the complexity of loading
L<Test::XTracker::Config> first.

=cut

BEGIN {
    unless ( $INC{'Test/XTracker/Config.pm'} ) {
        $ENV{XT_CONFIG_LOCAL_SUFFIX} ||= 'test_intl';
        require Test::XTracker::Config;
        Test::XTracker::Config->import($ENV{XTDC_BASE_DIR});
   }
}

1;
