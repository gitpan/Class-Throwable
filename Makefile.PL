use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Class::Throwable',
    VERSION_FROM => 'lib/Class/Throwable.pm', 
    PREREQ_PM    => {
        'Test::More' => 0.47,
        'Scalar::Util' => 1.10
    }
);
