use ExtUtils::MakeMaker;
use File::ShareDir::Install;

install_share 'tt';

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
        'Digest::SHA'                    => 0,
        'File::Copy'                     => 0,
        'File::Spec::Functions'          => 0,
        'File::Temp'                     => 0,
        'Getopt::Long'                   => 0,
        'JSON'                           => 0,
        'Moose'                          => 0,
        'Pod::Usage'                     => 0,
        'Template'                       => 0,
        'Cache::Memcached::libmemcached' => 0,
    },
    EXE_FILES => ['bin/fok.pl']
);

package MY;
use File::ShareDir::Install qw(postamble);
