use v6;
use Test;
use File::Find;

subtest 'recursive' => {
	my $res = find(:dir<t/dir1>, :name<file.bar>);
	is $res.elems, 2, 'name with a string - recursive by default';
	}

subtest 'max-depth-zero' => {
	my @res = find(:dir<t/dir1>, :name<file.bar>, :max-depth(0) );
	is @res.elems, 1, 'name with a string - max-depth = 0';
	}

subtest 'not-recursive' => {
	my @res = find(:dir<t/dir1>, :name<file.bar>, recursive => False);
	@res.join("\n").put;
	is @res.elems, 1, 'name with a string';
	}

done-testing();
