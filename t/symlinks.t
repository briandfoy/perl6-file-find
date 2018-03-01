use v6;
use Test;
use File::Find;

sub equals(\a, \b, $name) {
	unless a.elems == b.elems {
		diag "Expected {b.elems} elements but got {a.elems}";
		flunk( $name );
		return False;
		}
	ok ([&&] a >>~~<< b.map(*.IO)), $name
	}

if $*DISTRO.is-win { pass }
else {
	subtest 'follow-symlinks-True' => {
		my $res = find( :dir<t/dir2>, follow-symlinks => True );
		my @test = $res.map({ .Str }).sort;
		equals @test, <t/dir2/file.foo t/dir2/symdir t/dir2/symdir/empty_file t/dir2/symdir/file.bar>, 'follow-symlinks is True';
		}

	subtest 'follow-symlinks-False' => {
		my $res = find( :dir<t/dir2>, follow-symlinks => False );
		my @test = $res.map({ .Str }).sort;
		equals @test, <t/dir2/file.foo t/dir2/symdir>, 'follow-symlinks is False';
		}
	}

done-testing();
