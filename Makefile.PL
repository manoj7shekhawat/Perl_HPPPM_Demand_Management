use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'HPPPM::Demand::Management',
    AUTHOR              => q{Varun Juyal <vj2288@att.com>},
    VERSION_FROM        => 'lib/HPPPM/Demand/Management.pm',
    ABSTRACT_FROM       => 'lib/HPPPM/Demand/Management.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Moose'                     => '2.0403',
        'Error::TryCatch'           => '0.07',
        'Config::Simple'            => '4.58',
        'Log::Log4perl'             => '1.36',
        'LWP::UserAgent'            => '2.036',
        'HTTP::Request::Common'     => '1.28',
        'namespace::autoclean'      => '0.13',
        'LWP::Protocol::https'      => '6.02',
        'Template'                  => '2.24',
        'Test::Simple'              => '0.78',
        'Test::More'                => '0.78',
        'FieldParser'               => '0.01',
        'HPPPM::ErrorHandler'       => '0.01',
        'HPPPM::Demand::Management' => '0.01',
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'HPPPM-Demand-Management-*' },
);
