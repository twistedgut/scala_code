package Test::XT::PSGI;
use NAP::policy "tt", 'class';

use Plack::Util;

has app => (
    is          => 'ro',
    required    => 1,
    lazy        => 1,
    builder     => '_build_app',
);

sub _build_app {
    $ENV{PLACK_ENV} = 'test';
    Plack::Util::load_psgi(
        $ENV{XTDC_BASE_DIR}
        . q{/}
        . q{xt.psgi}
    );
}

no Moose;
