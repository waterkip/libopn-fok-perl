use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'OPN::Fok::RSS',
    VERSION_FROM  => 'lib/OPN/Fok/RSS.pm',
    AUTHOR        => 'Wesley Schwengle (wesley@schwengle.net)',
    ABSTRACT      => 'Fok RSS feed',
    TEST_REQUIRES => {
        'Test::CheckManifest' => 0,
        'Test::Compile'       => 0,
        'Test::Exception'     => 0,
        'Test::More'          => 0,
        'Test::Pod'           => 0,
        'Test::Pod::Coverage' => 0,
    },
    PREREQ_PM => {
        'Moose'             => 0,
        'HTML::Entities'    => 0,
        'HTML::TreeBuilder' => 0,
        'HTTP::Cookies'     => 0,
        'HTTP::Date'        => 0,
        'HTTP::Request'     => 0,
        'HTTP::Response'    => 0,
        'LWP::UserAgent'    => 0,
    },
);

