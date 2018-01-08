use v6;

unit module File::Find:auth<BDFOY>:ver<0.1.1>;

subset IntInf where Int:D | Inf;
	my @tests = (True);


sub make-checker ( %opts --> Junction ) {
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

	@tests.unshift: do given %opts<code> {
		when !.defined { Empty }
		default        { %opts<code> }
		}

sub find (
	:$dir!,
	:$name,
	:$type    where { $^a ~~ Any or $^a eq any( <dir file symlink> ) },
	:$code    where { $^a ~~ any( Any, Code ) },
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

	# add-targets takes care exclusions and depths
	# recursion is simply a max depth of zero
	# I can't make $max-depth rw.
	my $max-depth-rw = $recursive ?? $max-depth !! 0;
	my $add-targets = -> $elem, $depth {
		state $method = $breadth-first ?? 'append' !! 'unshift';
		unless $depth > $max-depth-rw {
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

	my $junction := make-checker( { :$name, :$type, :$code } );

	@targets = $add-targets.( $dir, $depth );

	gather while $taken < $max-items && @targets {
		my $dyad = @targets.shift;

		try {
			CATCH {
				#when X::FileFind::Stop      { last }
				when $stop-on-error == True { last }
				default                     { True }
				}
			if $dyad.[0] ~~ $junction { $taken++; take $dyad.[0] };
			}

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

This module is available under the MIT License. A copy of
this license should have come with this distribution in the LICENSE
file.

=end pod
