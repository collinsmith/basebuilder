#if defined _bb_colorchat_included
	#endinput
#endif
#define _bb_colorchat_included

#include "include/colorchat.inc"

stock bb_printColor(id, szMsg[], any:...) {
	static buffer[192];
	switch (numargs()) {
		case 2: client_print_color(id, DontChange, "^1[^3BB^1] %s", szMsg);
		default: {
			vformat(buffer, 191, szMsg, 3);
			client_print_color(id, DontChange, "^1[^3BB^1] %s", buffer);
		}
	}
}