implement Expand;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "arg.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;

Expand: module {
	init:	fn(nil: ref Draw->Context, args: list of string);
};

aflag := 0;
uflag := 0;
width := 8;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg := load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;

	arg->init(args);
	arg->setusage(arg->progname()+" [-t tabwidth] [-u [-a]]");
	while((c := arg->opt()) != 0)
		case c {
		'a' =>	aflag++;
		'u' =>	uflag++;
		't' =>	width = int arg->earg();
		* =>	arg->usage();
		}
	args = arg->argv();
	if(args != nil || aflag && !uflag)
		arg->usage();

	i := bufio->fopen(sys->fildes(0), bufio->OREAD);
	o := bufio->fopen(sys->fildes(1), bufio->OWRITE);
	if(i == nil || o == nil)
		fail(sprint("fopen: %r"));

	if(uflag)
		unexpand(i, o);
	else
		expand(i, o);
}

expand(i, o: ref Iobuf)
{
	n := 0;
	c: int;
	for(;;)
	case c = xgetb(i) {
	bufio->EOF =>
		xflush(o);
		return;
	'\t' =>
		do {
			xputb(o, ' ');
		} while(++n%width != 0);
	* =>
		n++;
		if(c == '\n')
			n = 0;
		xputb(o, c);
	}
}

unexpand(i, o: ref Iobuf)
{
	ws := 1;
	n := 0;
	c: int;
	for(;;)
	case c = xgetb(i) {
	bufio->EOF =>
		xflush(o);
		return;
	' ' =>
		n++;
		nc := xgetb(i);
		if(nc != ' ' || !ws && !aflag) {
			xputb(o, c);
			if(nc != bufio->EOF)
				i.ungetb();
			continue;
		}
		n++;
		x := 2;
		while(n%width != 0) {
			nc = xgetb(i);
			if(nc == bufio->EOF)
				break;
			if(nc != ' ') {
				i.ungetb();
				break;
			}
			n++;
			x++;
		}
		if(n%width == 0)
			xputb(o, '\t');
		else
			while(x--)
				xputb(o, ' ');
	'\n' =>
		n = 0;
		ws = 1;
		xputb(o, c);
	'\t' =>
		n += width-n%width;
		xputb(o, c);
	* =>
		n++;
		ws = 0;
		xputb(o, c);
	}
}

xgetb(b: ref Iobuf): int
{
	c := b.getb();
	if(c == bufio->ERROR)
		fail(sprint("read: %r"));
	return c;
}

xputb(b: ref Iobuf, c: int)
{
	if(b.putb(byte c) == bufio->ERROR)
		fail(sprint("write: %r"));
}

xflush(b: ref Iobuf)
{
	if(b.flush() == bufio->ERROR)
		fail(sprint("flush: %r"));
}

warn(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
}

fail(s: string)
{
	warn(s);
	raise "fail:"+s;
}
