#ifndef __SERIALPORT_H__
#define __SERIALPORT_H__

typedef unsigned char ui8;
typedef unsigned short ui16;
typedef unsigned int ui32;

// open a COM port with 115,200 baud, no flow control and 8N1
// port: 1-255
void openCOMPort(int port);

// callback for every received char
void onCOMChar(ui8 data);

// write a char to the COM port
void writeCOMChar(ui8 data);

#endif __SERIALPORT_H__
