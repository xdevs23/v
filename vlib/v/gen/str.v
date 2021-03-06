// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module gen

fn (mut g Gen) write_str_fn_definitions() {
	// _STR function can't be defined in vlib
	g.writeln("
void _STR_PRINT_ARG(const char *fmt, char** refbufp, int *nbytes, int *memsize, int guess, ...) {
	va_list args;
	va_start(args, guess);
	for(;;) {
		if (guess < *memsize - *nbytes) {
			guess = vsnprintf(*refbufp + *nbytes, *memsize - *nbytes, fmt, args);
			if (guess < *memsize - *nbytes) { // result did fit into buffer
				*nbytes += guess;
				return;
			}
		}
		// increase buffer (somewhat exponentially)
		*memsize += (*memsize + *memsize) / 3 + guess;
		*refbufp = realloc(*refbufp, *memsize);
	}
}

string _STR(const char *fmt, int nfmts, ...) {
	va_list argptr;
	int memsize = 128;
	int nbytes = 0;
	char* buf = malloc(memsize);
	va_start(argptr, nfmts);
	for (int i=0; i<nfmts; i++) {
		int k = strlen(fmt);
		bool is_fspec = false;
		for (int j=0; j<k; j++) {
			if (fmt[j] == '%') {
				j++;
				if (fmt[j] != '%') {
					is_fspec = true;
					break;
				}
			}
		}
		if (is_fspec) {
			char f = fmt[k-1];
			char fup = f & 0xdf; // toupper
			bool l = fmt[k-2] == 'l';
			bool ll = l && fmt[k-3] == 'l';
			if (f == 'u' || fup == 'X' || f == 'o' || f == 'd' || f == 'c') { // int...
				if (ll) _STR_PRINT_ARG(fmt, &buf, &nbytes, &memsize, k+16, va_arg(argptr, long long));
				else if (l) _STR_PRINT_ARG(fmt, &buf, &nbytes, &memsize, k+10, va_arg(argptr, long));
				else _STR_PRINT_ARG(fmt, &buf, &nbytes, &memsize, k+8, va_arg(argptr, int));
			} else if (fup >= 'E' && fup <= 'G') { // floating point
				_STR_PRINT_ARG(fmt, &buf, &nbytes, &memsize, k+10, va_arg(argptr, double));
			} else if (f == 's') { // v string
				string s = va_arg(argptr, string);
				if (fmt[k-4] == '*') { // %*.*s
					int fwidth = va_arg(argptr, int);
					if (fwidth < 0)
						fwidth -= (s.len - utf8_str_len(s));
					else
						fwidth += (s.len - utf8_str_len(s));
					_STR_PRINT_ARG(fmt, &buf, &nbytes, &memsize, k+fwidth-4, fwidth, s.len, s.str);
				} else { // %.*s
					_STR_PRINT_ARG(fmt, &buf, &nbytes, &memsize, k+s.len-4, s.len, s.str);
				}
			} else {
				//v_panic(tos3('Invaid format specifier'));
			}
		} else {
			if (k)
				_STR_PRINT_ARG(fmt, &buf, &nbytes, &memsize, k);
		}
		fmt += k+1;
	}
	va_end(argptr);
	buf[nbytes] = 0;
	buf = realloc(buf, nbytes+1);
#ifdef DEBUG_ALLOC
	//puts('_STR:');
	puts(buf);
#endif
	return tos2(buf);
}

string _STR_TMP(const char *fmt, ...) {
	va_list argptr;
	va_start(argptr, fmt);
	//size_t len = vsnprintf(0, 0, fmt, argptr) + 1;
	va_end(argptr);
	va_start(argptr, fmt);
	vsprintf((char *)g_str_buf, fmt, argptr);
	va_end(argptr);
#ifdef DEBUG_ALLOC
	//puts('_STR_TMP:');
	//puts(g_str_buf);
#endif
	return tos2(g_str_buf);
} // endof _STR_TMP

")
}
