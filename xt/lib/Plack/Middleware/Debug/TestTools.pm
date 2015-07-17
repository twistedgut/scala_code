package Plack::Middleware::Debug::TestTools;
use strict;
use warnings;
use parent qw(Plack::Middleware::Debug::Base);

use XTracker::Config::Local qw( app_root_dir config_var );

use Template;

sub run {
    my ($self, $env, $panel) = @_;

    my $content;
    Template->new(
        INCLUDE_PATH        => app_root_dir . 'root/base',
    )->process('testtools/home.tt', {}, \$content) || die Template->error();

    $panel->content($content);
    return;
}

1;