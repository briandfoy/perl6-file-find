use v6;
need X::FileFind::Stop;

unit module File::Find:auth<BDFOY>:ver<0.1.1>;

subset IntInf where Int:D | Inf;

my sub create-file-checker ( %opts --> Junction ) {
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

my sub create-add-to-queue (
	@queue, # container, so already rw
	:$exclude where { $^a ~~ any( Any, Bool, IO ) } = False,
	Bool:D :$breadth-first   = True,
	Bool:D :$stop-on-error   = False,
	Bool:D :$follow-symlinks = False,
	Junction :$prune-element,
	--> Code
	) {
	# some things won't make it into the queue. they might
	# have already been found but they won't be processed
	# further
	my @skip-tests = -> $elem, Int $depth { $elem.IO !~~ :d };
	@skip-tests.push( -> $elem, Int $depth { $elem.IO ~~ :l } ) unless $follow-symlinks;
	@skip-tests.push( -> $elem, Int $depth { $prune-element.( $elem, $depth ) } ) if $prune-element;
	my Junction $skip-this-element = any( @skip-tests );

	my $add-to-queue = sub ($elem, Int $depth --> Bool) {
		state $method = $breadth-first ?? 'append' !! 'unshift';

		return False if $skip-this-element.( $elem, $depth ).so;

		try {
			CATCH {
				when $stop-on-error == True { $_.throw  }
				default { warn "Caught {$_.^name} for $elem" }
				}
			@queue."$method"(
				slip dir($elem).grep( * !~~ $exclude ).map: { $( $_, $depth ) }
				);
			return True;
			}
		}
	}

my sub create-prune-tests (
	IntInf:D  :$max-depth    = Inf,
	IntInf:D  :$max-items    = Inf,
	:$prune   where { $^a ~~ any( Any, Code ) },
	--> Junction
	) {
	# stack a bunch of code bits that determine if we descend into
	# the next element. If any of these return True then that element
	# will be skipped.
	my @prune-tests;
	@prune-tests.unshift( -> $elem, $depth { $depth > $max-depth } )
		 if $max-depth ~~ Int;
	@prune-tests.unshift( -> $elem, $depth { $prune.( $elem, $depth ) } )
		 if $prune;
	@prune-tests.unshift( -> $a, $b { False } )
		unless @prune-tests.elems > 0; # default test (always false, so no skipping)
	my $prune-element = any( @prune-tests );
	}

sub find (
	:$dir = $*CWD,
	:$name,
	:$type    where { $^a ~~ Any or $^a eq any( <dir file symlink> ) },
	:$code    where { $^a ~~ any( Any, Code ) },
	:$prune   where { $^a ~~ any( Any, Code ) },
	:$exclude where { $^a ~~ any( Any, Bool, IO ) } = False,
	:$channel where { $^a ~~ Any or $^a.^can( 'send' ).[0].arity == 2 }, # this can be more flexible
	IntInf:D  :$max-depth is copy = Inf,
	IntInf:D  :$max-items    = Inf,
	Bool:D :$breadth-first   = True,
	Bool:D :$recursive       = True,
	Bool:D :$stop-on-error   = False,
	Bool:D :$follow-symlinks = False
	--> Seq:D
	) is export {
	my $taken = 0;
	my $depth = 0;
	my @queue;


	$max-depth = 0 unless $recursive;

	my Junction $prune-element := create-prune-tests(
		:max-depth( $max-depth ),
		:$max-items,
		:$prune,
		);

	my Code $add-to-queue := create-add-to-queue(
		@queue,
		:$breadth-first,
		:$stop-on-error,
		:$exclude,
		:$prune-element,
		);

	my Junction $file-checker := create-file-checker( {
		:$name,
		:$type,
		:$code
		} );

	# prime the queue with the first directory
	$add-to-queue.( $dir, $depth );

	gather loop {
		state $taken = 0;
		last unless @queue.elems;
		my ( $file, $depth ) = |( @queue.shift );

		try {
			CATCH {
				when X::FileFind::Stop      { last }
				when $stop-on-error == True { last }
				default                     { True }
				}
			if $file ~~ $file-checker {
				$taken++;
				take $file;
				$channel.send( $file ) if $channel;
				};
			}

		last if $taken >= $max-items;
		# all the decisions are in this code. It might not be added.
		$add-to-queue.( $file, $depth + 1 );
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

=head2 (Callable --> Bool) code

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

=head2 (Callable --> Bool) prune

Use C<prune> when you don't want to descend into a directory. It still
finds the directory but doesn't go deeper along that path.

This code is called for each encountered file. When the code returns
True, no more files under that path are added to the queue. The code
takes two positional arguments: the filename and the current depth:

	-> $filename, $depth { ... }

Prune directories by their names. These still find these directories
but they don't go past them:

	my @prune-dirs = <.git .precomp>;
	find(
		prune => -> $filename, $d {
			$filename.IO.basename eq any( @prune-dirs )
			},
		);

Here's how I find all my git repos. Prune all the F<.git> dirs but look
for that name. It's finds the F<.git> but the prune prevents further processing:

	my @prune-dirs = <.git>;
	my @git-paths = find(
		dir  => '/Users/brian/Dev',
		name => '.git',
		prune => -> $filename, $d {
			$filename.IO.basename eq any( @prune-dirs )
			},
		);

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
