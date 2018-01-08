use v6;

unit module File::Find:auth<BDFOY>:ver<0.1.1>;

sub make-checker ( %opts ) {
	my @tests = (True);

	@tests.unshift: do given %opts<name> {
		when !.defined { Empty }
		when Str       { -> $elem { $elem.basename eq %opts<name> } }
		when Regex     { %opts<name> }
		default        { Empty }
		}

	@tests.unshift: do given %opts<type> {
		when !.defined { Empty }
		when 'dir'     { :d }
		when 'file'    { :f }
		when 'symlink' { :l }
		default        { Empty }
		}

	all( @tests );
	}

sub find (
	:$dir!,
	:$name,
	:$type    where { $^a ~~ Any or $^a eq any( <dir file symlink> ) },
	:$code    where { $^a ~~ any( Any, Code ) },
	:$exclude where { $^a ~~ any( Any, Bool, IO ) } = False,
	Num:D :$max-depth        = Inf,
	Num:D :$max-items        = Inf,
	Bool:D :$breadth-first   = True,
	Bool:D :$depth-first     = False,
	Bool:D :$recursive       = True,
	Bool:D :$keep-going      = False,
	Bool:D :$follow-symlinks = False
	) is export {
	my $depth = 0.Num;
	my @targets;

	# add-targets takes care exclusions and depths
	# recursion is simply a max depth of zero
	# I can't make $max-depth rw.
	my $max-depth-rw = $recursive ?? $max-depth !! 0;
	my $add-targets = -> $elem, $depth {
		state $method = $breadth-first ?? 'append' !! 'unshift';

		unless $depth > $max-depth-rw {
			@targets."$method"(
				dir($elem).grep( * !~~ $exclude ).map: { $( $_, $depth ) }
				);
			}
		}

	my $junction := make-checker( { :$name, :$type, :$code } );

	@targets = $add-targets.( $dir, $depth );

	gather while @targets {
		my $dyad = @targets.shift;
		# exclude is special because it also stops traversing inside,
		# which checkrules does not
		next if $dyad.[0] ~~ $exclude;
		take $dyad.[0] if $dyad.[0] ~~ $junction;

		unless !$follow-symlinks and $dyad.[0].IO ~~ :l {
			if $dyad.[0].IO ~~ :d {
				$add-targets.( $dyad.[0], $dyad.[1] + 1 );
				CATCH { when X::IO::Dir {
					$_.throw unless $keep-going;
					next;
				}}
			}
		}
	}
}

=begin pod

=head1 NAME

File::Find - Get a lazy list of a directory tree

=head1 SYNOPSIS

	use File::Find;

	my @list := find(dir => 'foo');
	say @list[0..3];

	my $list = find(dir => 'foo');
	say $list[0..3];

=head1 DESCRIPTION

C<File::Find> allows you to get the contents of the given directory,
recursively, depth first. The only exported function, C<find()>,
generates a lazy list of files in given directory. Every element of
the list is an C<IO::Path> object, described below. C<find()> takes
one (or more) named arguments. The C<dir> argument is mandatory, and
sets the directory C<find()> will traverse. There are also few
optional arguments. If more than one is passed, all of them must match
for a file to be returned.

=head2 name

Specify a name of the file C<File::Find> is ought to look for. If you
pass a string here, C<find()> will return only the files with the given
name. When passing a regex, only the files with path matching the
pattern will be returned. Any other type of argument passed here will
just be smartmatched against the path (which is exactly what happens to
regexes passed, by the way).

=head2 type

Given a type, C<find()> will only return files being the given type.
The available types are C<file>, C<dir> or C<symlink>.

=head2 exclude

Exclude is meant to be used for skipping certain big and uninteresting
directories, like '.git'. Neither them nor any of their contents will be
returned, saving a significant amount of time.

The value of C<exclude> will be smartmatched against each IO object
found by File::Find. It's recommended that it's passed as an IO object
(or a Junction of those) so we avoid silly things like slashes
vs backslashes on different platforms.

=head2 keep-going

Parameter C<keep-going> tells C<find()> to not stop finding files
on errors such as 'Access is denied', but rather ignore the errors
and keep going.

=head2 follow-symlinks

Paramenter C<follow-symlinks> tells C<find()> whether or not it should
follow symlinks during recursive searches. This will still return
symlinks in its results if the type parameter allows.

=head1 Perl 5's File::Find

Please note, that this module is not trying to be the verbatim port of
Perl 5's File::Find module. Its interface is closer to Perl 5's
File::Find::Rule, and its features are planned to be similar one day.

=head1 CAVEATS

List assignment is eager in Perl 6, so if You assign C<find()> result
to an array, the elements will be copied and the laziness will be
spoiled. For a proper lazy list, use either binding (C<:=>) or assign
a result to a scalar value (see SYNOPSIS).

=end pod

# vim: ft=perl6
