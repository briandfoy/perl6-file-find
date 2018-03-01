use v6;

use X::FileFind::Stop;

unit module File::Find:auth<BDFOY>:ver<0.1.1>;

subset IntInf where Int:D | Inf;

sub make-checker ( %opts --> Junction ) {
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

	@tests.unshift: do given %opts<code> {
		when !.defined { Empty }
		default        { %opts<code> }
		}

	all( @tests );
	}

my sub create-add-targets (
	:$exclude where { $^a ~~ any( Any, Bool, IO ) } = False,
	Bool:D :$breadth-first = True,
	Bool:D :$stop-on-error = False,
	) {
	my $add-targets = -> $elem, $depth {
		state $method = $breadth-first ?? 'append' !! 'unshift';

		try {
			CATCH {
				when $stop-on-error == True { $_.throw  }
				default { warn "Caught {$_.^name}" }
				}
			@targets."$method"(
				slip dir($elem).grep( * !~~ $exclude ).map: { $( $_, $depth ) }
				);
			}
		}
	}

sub find (
	:$dir = $*CWD,
	:$name,
	:$type    where { $^a ~~ Any or $^a eq any( <dir file symlink> ) },
	:$code    where { $^a ~~ any( Any, Code ) },
	:$prune   where { $^a ~~ any( Any, Code ) },
	:$exclude where { $^a ~~ any( Any, Bool, IO ) } = False,
	IntInf:D  :$max-depth    = Inf,
	IntInf:D  :$max-items    = Inf,
	Bool:D :$breadth-first   = True,
	Bool:D :$recursive       = True,
	Bool:D :$stop-on-error   = False,
	Bool:D :$follow-symlinks = False
	--> Seq:D
	) is export {
	my $taken = 0;
	my $depth = 0.Num;
	my @targets;

	# add-targets takes care of exclusions and depths
	# recursion is simply a max depth that's non-zero
	# I can't make $max-depth rw (why not?).
	my $max-depth-rw = $recursive ?? $max-depth !! 0;

	my $add-targets = create-add-targets( {
		:$breadth-first,
		:$stop-on-error,
		:$exclude,
		} );

	my $junction := make-checker( { :$name, :$type, :$code } );

	# stack a bunch of code bits that determine if we descend into
	# the next element. If any of these return True then that element
	# will be skipped.
	my @skip-tests;
	@skip-tests.unshift( -> $elem, $depth { $depth > $max-depth-rw } )
		 if $max-depth ~~ Int;
	@skip-tests.unshift( -> $elem, $depth { $prune.( $elem, $depth ) } )
		 if $prune;
	@skip-tests.unshift( -> $a, $b { False } )
		unless @skip-tests.elems > 0; # default test (always false, so no skipping)
	my $skip-element = any( @skip-tests );

	@targets = $add-targets.( $dir, $depth );


	gather while $taken < $max-items && @targets {
		my $dyad = @targets.shift;

		try {
			CATCH {
				when X::FileFind::Stop      { last }
				when $stop-on-error == True { last }
				default                     { True }
				}
			if $dyad.[0] ~~ $junction { $taken++; take $dyad.[0] };
			}


		if $skip-element.( $elem, $depth ).so;

		unless !$follow-symlinks and $dyad.[0] ~~ :l {
			$add-targets.( $dyad.[0], $dyad.[1] + 1 ) if $dyad.[0] ~~ :d;
			}
		}
	}

=begin pod

=head1 NAME

File::Find - Get a list of files in a directory tree

=head1 SYNOPSIS

	use File::Find;

	my @list := find( dir => 'foo' );  # Lazy because of binding
	say @list[0..3];

	my $list = find( dir => 'foo' );   # Lazy because scalar
	say $list[0..3];

	my @list = find( dir => 'foo' );   # Eager
	say @list[0..3];

=head1 DESCRIPTION

C<File::Find::find()> searches a directory tree for files that matches various
conditions that you choose. A file must match every condition that you
specify.

When you assign to a positional you get an eager list; otherwise you
get a lazy list.

=head2 (Str|IO::Path) dir

Return files whose basename smart matches against this value.

Default: $*CWD (the current working directory)

=head2 (Str|Regex) name

Return files whose basename smart matches against this value.

Default: Any

=head2 (Str) type

Only return entries of the named file type. The available types are
C<file>, C<dir> or C<symlink>.

Default: Empty

=head2 (Callable) code

Return files that make the code evaluate to C<True>. The code have
zero or one parameters. With one parameter the argument is the IO
object that represents the file.

If the code fails with C<X::FileFind::Stop>, C<find> stops processing
and will not return any more files.

=head2 (Str|Bool|IO) exclude

Exclude is meant to be used for skipping certain big and uninteresting
directories, like '.git'. Neither them nor any of their contents will be
returned, saving a significant amount of time.

The value of C<exclude> will be smartmatched against each IO object
found by File::Find. It's recommended that it's passed as an IO object
(or a Junction of those) so we avoid silly things like slashes
vs backslashes on different platforms.

=head2 (Num) max-depth

Descend only this deep.

Default: Inf

=head2 (Bool) breadth-first

Process new directories last. Files are treated as a FIFO. When C<False>
the search is depth first (LIFO).

Default: True

=head2 (Bool) recursive

(Deprecated) This sets the C<max-depth> to zero if C<False>.

Default: True

=head2 (Bool) stop-on-error

If there's an error reading a directory, stop immediately.

Default: False

=head2 (Bool) follow-symlinks

Follow symlinks.

Beware! This might put you in a part of the filesystem above where you
started.

Default: False

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>.

I originally forked this module from U<https://github.com/tadzik/File-Find>
but then I changed almost everything.

=head1 SOURCE

The repository for this source is in GitHub at
L<https://github.com/briandfoy/perl6-file-find>

=head1 COPYRIGHT

Copyright © 2018, brian d foy C<< <bdfoy@cpan.org> >>

=head1 LICENSE

This module is available under the Artistic 2 License. A copy of
this license should have come with this distribution in the LICENSE
file.

=end pod
