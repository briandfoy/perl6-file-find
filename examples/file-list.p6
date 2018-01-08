#!/Applications/Rakudo/bin/perl6
use v6;
use File::Find;

sub MAIN ( Str $dir = '/etc'.IO ) {
	header "Show 7 files";
	for find( dir => $dir, max-items => 7 ) -> $file {
		put $file ~ ( $file.d ?? '@' !! '' )
		}

	header "Show files with 2 to 5 consecutive numbers";
	for find( dir => $dir, name => /\d ** 2..5 / ) -> $file {
		put $file ~ ( $file.d ?? '@' !! '' )
		}

	header "Show directories";
	for find( dir => $dir, type => 'dir' ) -> $file {
		put $file ~ ( $file.d ?? '@' !! '' )
		}

	header "Show files";
	for find( dir => $dir, type => 'file' ) -> $file {
		put $file ~ ( $file.d ?? '@' !! '' )
		}

	header "Show files depth first";
	for find( dir => $dir, breadth-first => False ) -> $file {
		put $file ~ ( $file.d ?? '@' !! '' )
		}

	header "Show files only 1 level";
	for find( dir => $dir, max-depth => 1 ) -> $file {
		put $file ~ ( $file.d ?? '@' !! '' )
		}

	header "Stop when a file ends in 'ir'";
	my $code = {
		fail X::FileFind::Stop.new( "$^a has 'ir'" ) if $^a ~~ /ir $/;
		True;
		}
	for find( dir => $dir, code => $code ) -> $file {
		put $file ~ ( $file.d ?? '@' !! '' )
		}
	}



sub header ( Str $message ) {
	put "\n", '=' x 50, "\n$message\n", '-' x 50;
	}
