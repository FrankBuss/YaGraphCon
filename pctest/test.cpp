#include <windows.h>
#include <stdio.h>
#include "serial.h"

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 240
#define SCREEN_SIZE (SCREEN_WIDTH * SCREEN_HEIGHT)

int screenAddress = 0;
int fontAddress = screenAddress + SCREEN_SIZE;

#define RESET_COMMAND 0
#define SET_FRAMEBUFFER_START 1
#define SET_FRAMEBUFFER_PITCH 2
#define SET_DESTINATION_START 3
#define SET_DESTINATION_PITCH 4
#define SET_SOURCE_START 5
#define SET_SOURCE_PITCH 6
#define SET_COLOR 7
#define SET_PIXEL 8
#define MOVE_TO 9
#define LINE_TO 10
#define FILL_RECT 11
#define BLIT_SIZE 12
#define BLIT 13
#define BLIT_TRANSPARENT 14
#define WRITE_FRAMEBUFFER 15

int font[] =
{
	0x00000180, 0x018003c0, 0x03c003c0, 0x06e004e0, 0x0c700870, 0x08701ff8, 0x1038301c, 0x201c701e,
	0x00007fc0, 0x38703838, 0x38183838, 0x38703fc0, 0x38703838, 0x381c381c, 0x381c3838, 0x38707fc0,
	0x000007e4, 0x1f3c3c0c, 0x38047800, 0x70007000, 0x70007000, 0x70007000, 0x3804380c, 0x1c3807e0,
	0x00007fc0, 0x38f03838, 0x3838381c, 0x381c381c, 0x381c381c, 0x381c381c, 0x38383838, 0x38f07fc0,
	0x00007ffc, 0x380c3804, 0x38003800, 0x38203860, 0x3fe03860, 0x38203800, 0x38003804, 0x380c7ffc,
	0x00007ffc, 0x380c3804, 0x38003800, 0x38203860, 0x3fe03860, 0x38203800, 0x38003800, 0x38007c00,
	0x000007e4, 0x1f3c3c0c, 0x38047800, 0x70007000, 0x7000703e, 0x701c701c, 0x381c381c, 0x1c3807e0,
	0x00007c3e, 0x381c381c, 0x381c381c, 0x381c381c, 0x3ffc381c, 0x381c381c, 0x381c381c, 0x381c7c3e,
	0x000007c0, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x038007c0,
	0x0000003e, 0x001c001c, 0x001c001c, 0x001c001c, 0x001c001c, 0x181c3c1c, 0x3c381838, 0x0c7003c0,
	0x00007c38, 0x38303860, 0x38c03980, 0x3b003e00, 0x3f003f80, 0x3bc039e0, 0x38f03878, 0x383c7c1e,
	0x00007c00, 0x38003800, 0x38003800, 0x38003800, 0x38003800, 0x38003800, 0x3804380c, 0x381c7ffc,
	0x0000781e, 0x381c3c3c, 0x3c3c3c3c, 0x3e7c2e5c, 0x2e5c2fdc, 0x279c279c, 0x279c231c, 0x231c733e,
	0x0000600e, 0x30043804, 0x3c043e04, 0x2f042784, 0x23c421e4, 0x20f4207c, 0x203c201c, 0x200c7004,
	0x000007e0, 0x1c38381c, 0x381c781e, 0x700e700e, 0x700e700e, 0x700e781e, 0x381c381c, 0x1c3807e0,
	0x00007fc0, 0x38f03838, 0x381c381c, 0x381c3838, 0x38f03fc0, 0x38003800, 0x38003800, 0x38007c00,
	0x000007e0, 0x1c38381c, 0x381c781e, 0x700e700e, 0x700e700e, 0x73ee78fe, 0x387c383c, 0x1c3e07ef,
	0x00007fc0, 0x38f03838, 0x381c381c, 0x381c3838, 0x38f03fc0, 0x39e038f0, 0x3878383c, 0x381e7c0f,
	0x00000fc8, 0x38786018, 0x60087000, 0x7c003f80, 0x0fe003f8, 0x007c001c, 0x400c600c, 0x78384fe0,
	0x00007ffc, 0x638c4384, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x038007c0,
	0x00007c0e, 0x38043804, 0x38043804, 0x38043804, 0x38043804, 0x38043804, 0x1c0c1c08, 0x0f3803e0,
	0x0000780e, 0x3804380c, 0x1c081c18, 0x0e100e10, 0x0e300720, 0x076003c0, 0x03c003c0, 0x01800180,
	0x0000fbe7, 0x71c271c2, 0x38e638e4, 0x39e439e4, 0x1d7c1d78, 0x1f781e78, 0x0e380e30, 0x0c300c30,
	0x0000fc1e, 0x780c3c18, 0x1e300e60, 0x0fc00780, 0x038003c0, 0x07e00ce0, 0x18f03078, 0x603cf07e,
	0x0000780c, 0x38081c18, 0x1e300e20, 0x076007c0, 0x03800380, 0x03800380, 0x03800380, 0x038007c0,
	0x00007ffc, 0x60384078, 0x00f000e0, 0x01e003c0, 0x03800780, 0x0f000e00, 0x1e003c04, 0x380c7ffc,
	0x000003c0, 0x0e701c38, 0x1c383c3c, 0x381c381c, 0x381c381c, 0x381c3c3c, 0x1c381c38, 0x0e7003c0,
	0x00000380, 0x0f800380, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x03800380, 0x03800fe0,
	0x000003c0, 0x0c701838, 0x3c3c3c1c, 0x181c0038, 0x007800f0, 0x01e003c0, 0x07800f04, 0x1e0c3ffc,
	0x00003ffc, 0x30382070, 0x00e001c0, 0x03f00078, 0x0038003c, 0x181c3c1c, 0x3c3c1838, 0x0c7003c0,
	0x00000e00, 0x0e000e00, 0x0e000e00, 0x1c001c70, 0x1c703870, 0x38703ffc, 0x00700070, 0x007001fc,
	0x00003ffc, 0x380c3804, 0x38003800, 0x3fc00070, 0x0038003c, 0x181c3c1c, 0x3c3c1838, 0x0c7003c0,
	0x000003f0, 0x0f001c00, 0x1c003800, 0x3fc03c70, 0x38383838, 0x381c381c, 0x1c381c38, 0x0e7003c0,
	0x00003ffc, 0x301c2038, 0x007000f0, 0x00e001e0, 0x01c001c0, 0x03c00380, 0x03800380, 0x03800380,
	0x000007e0, 0x1c38381c, 0x380c3c0c, 0x1e180fb0, 0x07e00df0, 0x1878303c, 0x301c381c, 0x1c7807e0,
	0x000003c0, 0x0e701c38, 0x1c38381c, 0x381c1c1c, 0x1c1c0e3c, 0x03fc001c, 0x00380038, 0x00f00fc0,
	0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000800, 0x1c000800,
	0x000003c0, 0x0e701818, 0x33ac2664, 0x6c264c02, 0x4c024c02, 0x6c262664, 0x33cc1818, 0x0e7003c0,
	0x00000780, 0x06c00c40, 0x0c400c80, 0x07000e00, 0x1e1c3718, 0x731073a0, 0x71c039e4, 0x1f380000,
};

volatile int acknowledge = 0;

// RS232 functions

void onCOMChar(ui8 data)
{
	acknowledge = 1;
}

void waitForOk()
{
	if (acknowledge) return;
	Sleep(1);
	if (!acknowledge) printf("acknowledge timeout\n");
}


// SPI transfer

void spiSelect(int enabled)
{
	if (enabled) {
		writeCOMChar(0);
	} else {
		writeCOMChar(1);
	}
}

void spiClock(int enabled)
{
	if (enabled) {
		writeCOMChar(2);
	} else {
		writeCOMChar(3);
	}
}

void spiData(int enabled)
{
	if (enabled) {
		writeCOMChar(4);
	} else {
		writeCOMChar(5);
	}
}

void spiTransfer(int data, int length)
{
	for (int i = length-1; i >= 0; i--) {
		spiClock(0);
		spiData((data >> i) & 1);
		spiClock(1);
	}
}

void oneArgumentCommand(int command, int arg, int length)
{
	spiSelect(0);
	spiTransfer(command, 8);
	spiTransfer(arg, length);
	spiSelect(1);
}

void twoArgumentsCommand(int command, int arg1, int arg2)
{
	acknowledge = 0;
	spiSelect(0);
	spiTransfer(command, 8);
	spiTransfer(arg1, 16);
	spiTransfer(arg2, 16);
	spiSelect(1);
	waitForOk();
}

void fourArgumentsCommand(int command, int arg1, int arg2, int arg3, int arg4)
{
	acknowledge = 0;
	spiSelect(0);
	spiTransfer(command, 8);
	spiTransfer(arg1, 16);
	spiTransfer(arg2, 16);
	spiTransfer(arg3, 16);
	spiTransfer(arg4, 16);
	spiSelect(1);
	waitForOk();
}



// graphics commands

void reset()
{
	acknowledge = 0;
	spiSelect(0);
	spiTransfer(RESET_COMMAND, 8);
	spiSelect(1);
	waitForOk();
}

void setFramebufferStart(int address)
{
	oneArgumentCommand(SET_FRAMEBUFFER_START, address, 24);
}

void setFramebufferPitch(int offset)
{
	oneArgumentCommand(SET_FRAMEBUFFER_PITCH, offset, 16);
}

void setDestinationStart(int address)
{
	oneArgumentCommand(SET_DESTINATION_START, address, 24);
}

void setDestinationPitch(int offset)
{
	oneArgumentCommand(SET_DESTINATION_PITCH, offset, 16);
}

void setSourceStart(int address)
{
	oneArgumentCommand(SET_SOURCE_START, address, 24);
}

void setSourcePitch(int offset)
{
	oneArgumentCommand(SET_SOURCE_PITCH, offset, 16);
}

void setColor(int color)
{
	oneArgumentCommand(SET_COLOR, color, 1);
}

void setPixel(int x, int y)
{
	twoArgumentsCommand(SET_PIXEL, x, y);
}

void moveTo(int x, int y)
{
	twoArgumentsCommand(MOVE_TO, x, y);
}

void lineTo(int x, int y)
{
	twoArgumentsCommand(LINE_TO, x, y);
}

void fillRect(int x, int y, int width, int height)
{
	fourArgumentsCommand(FILL_RECT, x, y, width, height);
}

void blitSize(int width, int height)
{
	twoArgumentsCommand(BLIT_SIZE, width, height);
}

void blit(int srcX, int srcY, int dstX, int dstY)
{
	fourArgumentsCommand(BLIT, srcX, srcY, dstX, dstY);
}

void blitTransparent(int srcX, int srcY, int dstX, int dstY)
{
	fourArgumentsCommand(BLIT_TRANSPARENT, srcX, srcY, dstX, dstY);
}

void writeFramebuffer(int address, int size, int* data)
{
	spiSelect(0);
	spiTransfer(WRITE_FRAMEBUFFER, 8);
	spiTransfer(address, 24);
	spiTransfer(32 * size, 24);
	for (int i = 0; i < size; i++) {
		spiTransfer(data[i], 32);
		printf("%i\n", i);
	}
	spiSelect(1);
}


// higher level functions

void drawChar(int x, int y, int c)
{
	int srcX = 0;
	int srcY = 16*c;
	int dstX = x;
	int dstY = y;
	blit(srcX, srcY, dstX, dstY);
}

void drawText(int x, int y, char* text)
{
	setSourceStart(fontAddress);
	setSourcePitch(16);
	setDestinationStart(screenAddress);
	blitSize(16, 16);
	while (*text) {
		char c = *text;
		if (c != 32) drawChar(x, y, c - 'a');
		x += 16;
		text++;
	}
}

void init(int port)
{
	openCOMPort(port);
	reset();
	setFramebufferPitch(SCREEN_WIDTH);
	setDestinationPitch(SCREEN_WIDTH);
	setSourcePitch(SCREEN_WIDTH);
}

int main(int argc, char** argv)
{
	if (argc != 2) {
		printf("usage: %s com-port\n", argv[0]);
		return 1;
	}
	
	// initialize hardware
	init(atoi(argv[1]));

	// clear background
	setColor(0);
	fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

	// set pixels in corners
	setColor(1);
	setPixel(0, 0);
	setPixel(SCREEN_WIDTH - 1, 0);
	setPixel(SCREEN_WIDTH - 1, SCREEN_HEIGHT - 1);
	setPixel(0, SCREEN_HEIGHT - 1);

	// draw frame
	moveTo(2, 0);
	lineTo(SCREEN_WIDTH - 3, 0);
	moveTo(SCREEN_WIDTH - 1, 2);
	lineTo(SCREEN_WIDTH - 1, SCREEN_HEIGHT - 3);
	moveTo(SCREEN_WIDTH - 3, SCREEN_HEIGHT - 1);
	lineTo(2, SCREEN_HEIGHT - 1);
	moveTo(0, SCREEN_HEIGHT - 3);
	lineTo(0, 2);

	// draw some lines
	int width = 20;
	int steps = 10;
	int x0 = 10;
	int y0 = 20;
	for (int i = 0; i < steps; i++) {
		moveTo(x0 + i * width, y0);
		lineTo(x0 + steps * width, y0 + i * width);
		lineTo(x0 + steps * width - i * width, y0 + steps * width);
		lineTo(x0, y0 + steps * width - i * width);
		lineTo(x0 + i * width, y0);
	}

	// upload font
	writeFramebuffer(fontAddress, sizeof(font) / sizeof(int), font);

	// text test
	drawText(27, 110, "hello world");

	// blit test
	drawText(27, 2, "opaque blit");
	setSourcePitch(SCREEN_WIDTH);
	setSourceStart(0);
	blitSize(176, 16);
	blit(27, 2, 27, 52);

	// transaprent blit test
	setColor(0);  // transparent background color
	drawText(27, 222, "transparent");
	setSourcePitch(SCREEN_WIDTH);
	setSourceStart(0);
	blitSize(176, 16);
	blitTransparent(27, 222, 27, 172);

	// draw some rectangles
	drawText(240, 180, "fill");
	drawText(240, 196, "rect");
	setColor(1);
	fillRect(270, 30, 40, 120);
	fillRect(230, 70, 70, 20);
	fillRect(250, 120, 30, 50);
}
