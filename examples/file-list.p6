#!/Applications/Rakudo/bin/perl6


sub MAIN ( Str $dir = '/etc' ) {
	use File::Find;
	for find( dir => $dir, :stop-on-error ) -> $file {
		put $file ~ ( $file.d ?? '@' !! '' )
		}
	}
