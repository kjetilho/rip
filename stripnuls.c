#include <stdio.h>
#include <math.h>

#define BYTES_PER_SECOND (2*2*44100)
static const int threshold = 1 * BYTES_PER_SECOND;

int
main (int argc, char **argv)
{
	int bytecount = 0;
	int removed = 0;
	int zeroes = 0;
	int c;

	while ((c = getchar ()) != EOF) {
		++bytecount;

		if (c == 0) {
			if (zeroes)
				++zeroes;
			else if (bytecount % 4)
				++zeroes;
		} else if (zeroes) {
			if (zeroes > threshold) {
				int newsize = (int)
					(sqrt (zeroes / BYTES_PER_SECOND)
					 * BYTES_PER_SECOND / 4)
					* 4;
				newsize += zeroes % 4;
				fprintf (stderr, "shrunk %d into %d\n",
					 zeroes, newsize);
				removed += zeroes - newsize;
				zeroes = newsize;
			}

			while (zeroes--)
				putchar (0);
		}
		if (! zeroes)
			putchar (c);
	}
}
