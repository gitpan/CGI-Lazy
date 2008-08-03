# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl CGI-Lazy.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 10;
BEGIN { 
	use_ok('HTML::Template');
    	use_ok('HTML::Template', 2.9);
	use_ok('JSON',	2.11);
	use_ok('DBI', 1.60);
	use_ok('JavaScript::Minifier', 1.05);
	use_ok('Tie::IxHash', 1.21);
	use_ok('Digest::MD5', 2.36);
	use_ok('Time::HiRes');
	use_ok('CGI::Lazy');
};

#########################
ok(baseConfig(), 'basic configuration- no db');

#-----------------------------------------------------------------------------
sub baseConfig {
	my $q = CGI::Lazy->new({
				tmplDir 	=> "/templates",
				jsDir		=>  "/js",
				plugins 	=> {
					ajax	=>  1,
				},
			}) or die;
}

