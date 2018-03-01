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

{
my $res = find(:dir<t/dir1>);
my @test = $res.map({ .Str }).sort;
equals @test, <t/dir1/another_dir t/dir1/another_dir/empty_file t/dir1/another_dir/file.bar t/dir1/file.bar t/dir1/file.foo t/dir1/foodir t/dir1/foodir/not_a_dir>, 'just a dir';
}



{ # names ------------------------------------------------------------
my $res = find(:dir<t/dir1>, :name(/foo/));
my @test = $res.map({ .Str }).sort;
equals @test, <t/dir1/file.foo t/dir1/foodir t/dir1/foodir/not_a_dir>, 'name with regex';
}

{
my $res = find(:dir<t/dir1>, :name<notexisting>);
is $res.elems, 0, 'no results';
}

# ====================================================================
{ # types (dir) ------------------------------------------------------
my $res = find(:dir<t/dir1>, :type<dir>);
my @test = $res.map({ .Str }).sort;
equals @test, <t/dir1/another_dir t/dir1/foodir>, 'types: dir';
}

{ # types (dir) with name --------------------------------------------
my $res = find(:dir<t/dir1>, :type<dir>, :name(/foo/));
my @test = $res.map({ .Str }).sort;
equals @test, <t/dir1/foodir>, 'types: dir, combined with name';
}

{ # types (file) -----------------------------------------------------
my $res = find(:dir<t/dir1>, :type<file>, :name(/foo/));
my @test = $res.map({ .Str }).sort;
equals @test, <t/dir1/file.foo t/dir1/foodir/not_a_dir>,
	'types: file, combined with name';
}

{ #exclude -----------------------------------------------------------
my $res = find(:dir<t/dir1>, :type<file>,
            :exclude('t/dir1/another_dir'.IO));
my @test = $res.map({ .Str }).sort;
equals @test, <t/dir1/file.bar t/dir1/file.foo t/dir1/foodir/not_a_dir>, 'exclude works';
}

done-testing();
