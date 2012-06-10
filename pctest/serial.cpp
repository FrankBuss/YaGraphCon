#include <windows.h>
#include <stdio.h>

#include "serial.h"

HANDLE hComm;

static DWORD WINAPI commThread(LPVOID pParam) 
{
	char buf[256];
	while (true) {
		DWORD read;
		if (ReadFile(hComm, (void*) buf, 256, &read, NULL)) {
			for (DWORD i = 0; i < read; i++) onCOMChar(buf[i]);
		}
	}
	return 0;
}

void openCOMPort(int port)
{
	char portString[100];
	sprintf(portString, "\\\\.\\COM%i", port);
	hComm = CreateFile(portString, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, NULL, 0);
	if (hComm == INVALID_HANDLE_VALUE) {
		printf("port open error\n");
		exit(1);
	}
	COMMTIMEOUTS commTimeouts;
	commTimeouts.ReadIntervalTimeout = MAXDWORD;
	commTimeouts.ReadTotalTimeoutMultiplier = MAXDWORD ;
	commTimeouts.ReadTotalTimeoutConstant = 1;
	commTimeouts.WriteTotalTimeoutMultiplier = 1000;
	commTimeouts.WriteTotalTimeoutConstant = 1000;
	if (!SetCommTimeouts(hComm, &commTimeouts)) {						   
		printf("SetCommTimeouts error\n");
		exit(1);
	}
	DCB	dcb;
	if (!GetCommState(hComm, &dcb)) {
		printf("GetCommState error\n");
		exit(1);
	}
	if (!BuildCommDCB("baud=115200 parity=N data=8 stop=1", &dcb)) {
		printf("BuildCommDCB() error\n");
		exit(1);
	}
	dcb.BaudRate = CBR_115200;
	dcb.fBinary = TRUE;
	dcb.fParity = FALSE;
	dcb.fOutxCtsFlow = FALSE;
	dcb.fOutxDsrFlow = FALSE;
	dcb.fDtrControl = DTR_CONTROL_DISABLE;
	dcb.fDsrSensitivity = FALSE;
	dcb.fOutX = FALSE;
	dcb.fInX = FALSE;
	dcb.fErrorChar = FALSE;
	dcb.fNull = FALSE;
	dcb.fRtsControl = RTS_CONTROL_DISABLE;
	dcb.fAbortOnError = FALSE;
	dcb.ByteSize = 8;
	dcb.Parity = NOPARITY;
	dcb.StopBits = ONESTOPBIT;
	if (!SetCommState(hComm, &dcb)) {
		printf("SetCommState() error\n");
		exit(1);
	}
	PurgeComm(hComm, PURGE_RXCLEAR | PURGE_TXCLEAR | PURGE_RXABORT | PURGE_TXABORT);
	DWORD threadID;
	HANDLE thread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE) commThread, NULL, 0, &threadID);
	if (!thread) {
		printf("CreateThread() error\n");
		exit(1);
	}
}

void writeCOMChar(ui8 data) {
	unsigned char buf[1];
	buf[0] = data;
	DWORD bytesSent = 0;
	if (!WriteFile(hComm, buf, 1, &bytesSent, NULL)) {
		printf("WriteFile() error\n");
		exit(1);
	}
}
