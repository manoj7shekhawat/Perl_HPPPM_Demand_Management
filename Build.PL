#!/usr/bin/perl -w

use strict;
use Module::Build;

my $build = Module::Build->new
    (
        module_name          => 'HPPPM::Demand::Management',
        license              => 'perl',
	config_requires => {
	    'Module::Build'             => '0.38',
	},    
	requires => {
	    'perl'                      => '5.8.9',
	    'Moose'                     => '2.0403',
	    'Error::TryCatch'           => '0.07',
	    'Config::Simple'            => '4.58',
	    'Log::Log4perl'             => '1.36',
	    'LWP::UserAgent'            => '2.036',
            'namespace::autoclean'      => '0.13',
            'LWP::Protocol::https'      => '6.02',
	    'HTTP::Request::Common'     => '1.28',
	    'Template'                  => '2.24',
	    'Test::Simple'              => '0.78',
	    'Test::More'                => '0.78',
            'FieldParser'               => '0.01',
	    'HPPPM::ErrorHandler'       => '0.01',
            'HPPPM::Demand::Management' => '0.01',
	},
    );

$build->create_build_script;

