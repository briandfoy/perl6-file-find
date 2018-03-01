#!/Users/brian/bin/perl6s/perl6-latest

use lib </Users/brian/Dev/perl6-modules/perl6-file-find/lib>;
use File::Find:auth<BDFOY>:ver<0.1.1>;

my $channel = Channel.new;
$channel.Supply.tap: -> $file { put "Channel got $file" };

my @prune-dirs = <.precomp ~~Others .git>;
find(
	dir  => '/Users/brian/Documents/Dev',
	name => '.git',
	prune => -> $filename, $d {
		$filename.IO.basename eq any( @prune-dirs )
		},
	channel => $channel,
	);
