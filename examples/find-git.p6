#!/Users/brian/bin/perl6s/perl6-latest

use lib </Users/brian/Dev/perl6-modules/perl6-file-find/lib>;
use File::Find:auth<BDFOY>:ver<0.1.1>;

my @pairs;

my $date-channel = Channel.new;
$date-channel.Supply.tap: -> $pair {
	@pairs.push: $pair;
	};

my $channel = Channel.new;
$channel.Supply.tap: -> $file {
#	put "Channel got $file";
#	put "\tdir is {$file.IO.parent}";
	indir $file.IO.parent, {
		my $date = try run( 'git', <log -1 --format=%cI>, :out, :err ).out.get;
		if $date {
			my $dt = DateTime.new: $date;
			$date-channel.send: "$*CWD" => $dt;
			}
		else {
#			put "NO DATE!!!";
			}
		}
	};


my @prune-dirs = <.precomp ~~Others .git>;
find(
	dir  => '/Users/brian/Documents/Dev',
	name => '.git',
	prune => -> $filename, $d {
		$filename.IO.basename eq any( @prune-dirs )
		},
	channel => $channel,
	on-start  => -> { put "Starting at {now}" },
	on-finish => -> {
		$channel.close;
		$date-channel.close;
		put "Starting at {now}";
		put "There are {@pairs.elems} elems";
		@pairs.sort( *.value ).map( { "$_" } ).join( "\n" ).put;
		},
	);


$channel.close;
