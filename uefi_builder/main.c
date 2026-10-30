typedef unsigned short CHAR16;
typedef unsigned long long UINT64;
typedef unsigned int UINT32;
typedef unsigned short UINT16;
typedef unsigned char UINT8;
typedef unsigned long long UINTN;
typedef long long INTN;
typedef void VOID;
typedef UINT8 BOOLEAN;
#define TRUE  1
#define FALSE 0
#define NULL ((void *)0)

typedef VOID *EFI_HANDLE;
typedef UINTN EFI_STATUS;
#define EFI_SUCCESS 0
#define EFI_ERROR(status) (((INTN)(status)) < 0)

typedef struct {
    UINT32 Data1;
    UINT16 Data2;
    UINT16 Data3;
    UINT8  Data4[8];
} EFI_GUID;

#define EFI_PCI_IO_PROTOCOL_GUID \
  { 0x4cf5b200, 0x68b8, 0x4106, { 0x88, 0x86, 0xb9, 0x4d, 0xd9, 0x4a, 0x31, 0xa7 } }

typedef enum {
    EfiPciIoWidthUint8,
    EfiPciIoWidthUint16,
    EfiPciIoWidthUint32,
    EfiPciIoWidthUint64
} EFI_PCI_IO_PROTOCOL_WIDTH;

typedef struct _EFI_PCI_IO_PROTOCOL EFI_PCI_IO_PROTOCOL;

typedef EFI_STATUS (*EFI_PCI_IO_PROTOCOL_CONFIG)(
    EFI_PCI_IO_PROTOCOL *This,
    EFI_PCI_IO_PROTOCOL_WIDTH Width,
    UINT32 Offset,
    UINTN Count,
    VOID *Buffer
);

typedef EFI_STATUS (*EFI_PCI_IO_PROTOCOL_IO)(
    EFI_PCI_IO_PROTOCOL *This,
    EFI_PCI_IO_PROTOCOL_WIDTH Width,
    UINT8 BarIndex,
    UINT64 Offset,
    UINTN Count,
    VOID *Buffer
);

typedef EFI_STATUS (*EFI_PCI_IO_PROTOCOL_GET_LOCATION)(
    EFI_PCI_IO_PROTOCOL *This,
    UINTN *SegmentNumber,
    UINTN *BusNumber,
    UINTN *DeviceNumber,
    UINTN *FunctionNumber
);

struct _EFI_PCI_IO_PROTOCOL {
    VOID *PollMem;
    VOID *PollIo;
    struct {
        EFI_PCI_IO_PROTOCOL_IO Read;
        EFI_PCI_IO_PROTOCOL_IO Write;
    } Mem;
    struct {
        EFI_PCI_IO_PROTOCOL_IO Read;
        EFI_PCI_IO_PROTOCOL_IO Write;
    } Io;
    struct {
        EFI_PCI_IO_PROTOCOL_CONFIG Read;
        EFI_PCI_IO_PROTOCOL_CONFIG Write;
    } Pci;
    VOID *CopyMem;
    VOID *Map;
    VOID *Unmap;
    VOID *AllocateBuffer;
    VOID *FreeBuffer;
    VOID *Flush;
    EFI_PCI_IO_PROTOCOL_GET_LOCATION GetLocation;
    VOID *Attributes;
    VOID *GetBarAttributes;
    VOID *SetBarAttributes;
    UINT64 RomSize;
    VOID *RomImage;
};

typedef struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
    VOID *Reset;
    EFI_STATUS (*OutputString)(struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, CHAR16 *String);
    VOID *TestString;
    VOID *QueryMode;
    VOID *SetMode;
    VOID *SetAttribute;
    VOID *ClearScreen;
    VOID *SetCursorPosition;
    VOID *EnableCursor;
    VOID *Mode;
} EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;

typedef enum {
    AllHandles,
    ByRegisterNotify,
    ByProtocol
} EFI_LOCATE_SEARCH_TYPE;

typedef struct {
    char dummy[24];
    VOID *RaiseTPL;
    VOID *RestoreTPL;
    VOID *AllocatePages;
    VOID *FreePages;
    VOID *GetMemoryMap;
    VOID *AllocatePool;
    EFI_STATUS (*FreePool)(VOID *Buffer);
    VOID *CreateEvent;
    VOID *SetTimer;
    VOID *WaitForEvent;
    VOID *SignalEvent;
    VOID *CloseEvent;
    VOID *CheckEvent;
    VOID *InstallProtocolInterface;
    VOID *ReinstallProtocolInterface;
    VOID *UninstallProtocolInterface;
    EFI_STATUS (*HandleProtocol)(EFI_HANDLE Handle, EFI_GUID *Protocol, VOID **Interface);
    VOID *PCHandleProtocol;
    VOID *RegisterProtocolNotify;
    EFI_STATUS (*LocateHandle)(EFI_LOCATE_SEARCH_TYPE SearchType, EFI_GUID *Protocol, VOID *SearchKey, UINTN *BufferSize, EFI_HANDLE *Buffer);
    VOID *LocateDevicePath;
    VOID *InstallConfigurationTable;
    VOID *LoadImage;
    VOID *StartImage;
    VOID *Exit;
    VOID *UnloadImage;
    VOID *ExitBootServices;
    VOID *GetNextMonotonicCount;
    EFI_STATUS (*Stall)(UINTN Microseconds);
    EFI_STATUS (*SetWatchdogTimer)(UINTN Timeout, UINT64 WatchdogCode, UINTN DataSize, CHAR16 *WatchdogData);
    VOID *ConnectController;
    VOID *DisconnectController;
    VOID *OpenProtocol;
    VOID *CloseProtocol;
    VOID *OpenProtocolInformation;
    VOID *ProtocolsPerHandle;
    EFI_STATUS (*LocateHandleBuffer)(EFI_LOCATE_SEARCH_TYPE SearchType, EFI_GUID *Protocol, VOID *SearchKey, UINTN *NoHandles, EFI_HANDLE **Buffer);
} EFI_BOOT_SERVICES;

typedef struct {
    char dummy[52];
    EFI_HANDLE ConsoleInHandle;
    VOID *ConIn;
    EFI_HANDLE ConsoleOutHandle;
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *ConOut;
    EFI_HANDLE StandardErrorHandle;
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *StdErr;
    VOID *RuntimeServices;
    EFI_BOOT_SERVICES *BootServices;
} EFI_SYSTEM_TABLE;

#define TARGET_PCI_VENDOR_ID 0x10DE
#define TARGET_PCI_DEVICE_ID 0x2204
#define GU_FEAT_SS0_OFFSET   0x0082381cU
#define GU_FEAT_SS1_OFFSET   0x00823820U
#define GU_SS0_UNLOCK        0x88888888U
#define GU_SS1_UNLOCK        0x00000008U

static EFI_SYSTEM_TABLE     *gST = NULL;
static EFI_BOOT_SERVICES    *gBS = NULL;

static void Print(CHAR16 *Msg) {
    if (gST && gST->ConOut) {
        gST->ConOut->OutputString(gST->ConOut, Msg);
    }
}

static void PrintHex(UINT32 Val) {
    CHAR16 Buf[11];
    CHAR16 HexChars[] = L"0123456789ABCDEF";
    Buf[0] = L'0';
    Buf[1] = L'x';
    for (int i = 7; i >= 0; --i) {
        Buf[2 + (7 - i)] = HexChars[(Val >> (i * 4)) & 0xF];
    }
    Buf[10] = L'\0';
    Print(Buf);
}

EFI_STATUS
efi_main (
    EFI_HANDLE        ImageHandle,
    EFI_SYSTEM_TABLE  *SystemTable
) {
    gST = SystemTable;
    gBS = SystemTable->BootServices;

    // Reset watchdog timer to 15 seconds to ensure host resets if link hangs
    gBS->SetWatchdogTimer(15, 0x0000, 0, NULL);

    Print(L"\r\n======================================================\r\n");
    Print(L"  Custom Pre-Boot GPU Unlocker: MMIO Selector Probe   \r\n");
    Print(L"  Host: Intel i9-10900 / Gigabyte B460M D3H          \r\n");
    Print(L"  Target: EVGA RTX 3090 (10DE:2204, Subsys 3842:3975)\r\n");
    Print(L"======================================================\r\n\r\n");

    Print(L"[*] Active hardware safety: 15-second watchdog timer armed.\r\n");
    Print(L"[*] Locating NVIDIA GA102 on PCI bus...\r\n");

    EFI_STATUS Status;
    EFI_HANDLE *HandleBuffer = NULL;
    UINTN HandleCount = 0;
    EFI_GUID PciIoProtocolGuid = EFI_PCI_IO_PROTOCOL_GUID;

    Status = gBS->LocateHandleBuffer(
        ByProtocol,
        &PciIoProtocolGuid,
        NULL,
        &HandleCount,
        &HandleBuffer
    );

    if (EFI_ERROR(Status) || !HandleBuffer) {
        Print(L"[!] Failed to locate PCI I/O Protocol handles.\r\n");
        return Status;
    }

    BOOLEAN FoundTarget = FALSE;
    EFI_PCI_IO_PROTOCOL *TargetPciIo = NULL;
    UINTN TargetSegment, TargetBus, TargetDevice, TargetFunction;

    for (UINTN i = 0; i < HandleCount; i++) {
        EFI_PCI_IO_PROTOCOL *PciIo = NULL;
        Status = gBS->HandleProtocol(HandleBuffer[i], &PciIoProtocolGuid, (VOID **)&PciIo);
        if (EFI_ERROR(Status) || !PciIo) continue;

        UINT32 Id = 0;
        Status = PciIo->Pci.Read(PciIo, EfiPciIoWidthUint32, 0, 1, &Id);
        if (EFI_ERROR(Status)) continue;

        UINT16 Vendor = (UINT16)(Id & 0xFFFF);
        UINT16 Device = (UINT16)((Id >> 16) & 0xFFFF);

        if (Vendor == TARGET_PCI_VENDOR_ID && Device == TARGET_PCI_DEVICE_ID) {
            FoundTarget = TRUE;
            TargetPciIo = PciIo;
            PciIo->GetLocation(PciIo, &TargetSegment, &TargetBus, &TargetDevice, &TargetFunction);
            
            Print(L"[+] Located GA102 at PCI ");
            PrintHex((UINT32)TargetBus);
            Print(L":");
            PrintHex((UINT32)TargetDevice);
            Print(L".");
            PrintHex((UINT32)TargetFunction);
            Print(L"\r\n");

            UINT32 Subsys = 0;
            PciIo->Pci.Read(PciIo, EfiPciIoWidthUint32, 0x2C, 1, &Subsys);
            Print(L"    Subsystem ID: ");
            PrintHex(Subsys);
            Print(L"\r\n");
            break;
        }
    }

    if (!FoundTarget || !TargetPciIo) {
        Print(L"[!] GA102 not found on PCI bus.\r\n");
        if (HandleBuffer) gBS->FreePool(HandleBuffer);
        return 14; // EFI_NOT_FOUND
    }

    // Enable Memory Space decode if not already enabled
    UINT16 Command = 0;
    Status = TargetPciIo->Pci.Read(TargetPciIo, EfiPciIoWidthUint16, 0x04, 1, &Command);
    if (!EFI_ERROR(Status) && !(Command & 0x0002)) {
        Command |= 0x0002;
        TargetPciIo->Pci.Write(TargetPciIo, EfiPciIoWidthUint16, 0x04, 1, &Command);
        Print(L"[*] Enabled PCI Memory Space decode on GA102.\r\n");
    }

    Print(L"[*] Probing BAR0 MMIO Speed Selector Registers...\r\n");

    UINT32 Ss0_Before = 0, Ss1_Before = 0;
    TargetPciIo->Mem.Read(TargetPciIo, EfiPciIoWidthUint32, 0, GU_FEAT_SS0_OFFSET, 1, &Ss0_Before);
    TargetPciIo->Mem.Read(TargetPciIo, EfiPciIoWidthUint32, 0, GU_FEAT_SS1_OFFSET, 1, &Ss1_Before);

    Print(L"    Current SS0 (Instruction Issue Selector): ");
    PrintHex(Ss0_Before);
    Print(L"\r\n");

    Print(L"    Current SS1 (IMLA4 Selector):            ");
    PrintHex(Ss1_Before);
    Print(L"\r\n");

    if (Ss0_Before == GU_SS0_UNLOCK && Ss1_Before == GU_SS1_UNLOCK) {
        Print(L"[SUCCESS] Hardware is ALREADY UNLOCKED (SS0=0x88888888, SS1=0x8)!\r\n");
    } else {
        Print(L"[-] Note: Direct write locked until Falcon SEC2/WPR microcode completes.\r\n");
    }

    if (HandleBuffer) {
        gBS->FreePool(HandleBuffer);
    }

    Print(L"\r\n[*] Disarming watchdog timer...\r\n");
    gBS->SetWatchdogTimer(0, 0x0000, 0, NULL);

    Print(L"[*] Finished. Exiting to boot manager in 5 seconds...\r\n");
    gBS->Stall(5000000);

    return EFI_SUCCESS;
}
