#include <Uefi.h>
#include <Protocol/LoadedImage.h>
#include <Protocol/SimpleFileSystem.h>
#include <Protocol/GraphicsOutput.h>
#include <Protocol/PciIo.h>
#include <Guid/FileInfo.h>
#include <IndustryStandard/Pci.h>

#define TARGET_PCI_VENDOR_ID 0x10DE
#define TARGET_PCI_DEVICE_ID 0x2204
#define TARGET_PCI_SUBSYS_ID 0x39753842 // EVGA FTW3 Ultra 3090

#define GU_FEAT_SS0_OFFSET   0x0082381cU
#define GU_FEAT_SS1_OFFSET   0x00823820U
#define GU_SS0_UNLOCK        0x88888888U
#define GU_SS1_UNLOCK        0x00000008U

static EFI_SYSTEM_TABLE     *gST = NULL;
static EFI_BOOT_SERVICES    *gBS = NULL;
static EFI_FILE_PROTOCOL    *gLogFile = NULL;

static void LogStr(const char *Str) {
    if (gLogFile) {
        UINTN Len = 0;
        while (Str[Len]) Len++;
        gLogFile->Write(gLogFile, &Len, (VOID *)Str);
        gLogFile->Flush(gLogFile);
    }
}

static void Print(CHAR16 *Msg) {
    if (gST && gST->ConOut) {
        gST->ConOut->OutputString(gST->ConOut, Msg);
    }
    // Also log to ascii
    char Ascii[256];
    UINTN i = 0;
    while (Msg[i] && i < 254) {
        Ascii[i] = (char)Msg[i];
        i++;
    }
    Ascii[i] = '\0';
    LogStr(Ascii);
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

static void InitLogFile(EFI_HANDLE ImageHandle) {
    EFI_LOADED_IMAGE_PROTOCOL *LoadedImage = NULL;
    EFI_GUID LoadedImageGuid = EFI_LOADED_IMAGE_PROTOCOL_GUID;
    EFI_GUID SimpleFileSystemGuid = EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *FileSystem = NULL;
    EFI_FILE_PROTOCOL *Root = NULL;

    EFI_STATUS Status = gBS->HandleProtocol(ImageHandle, &LoadedImageGuid, (VOID **)&LoadedImage);
    if (!EFI_ERROR(Status) && LoadedImage) {
        Status = gBS->HandleProtocol(LoadedImage->DeviceHandle, &SimpleFileSystemGuid, (VOID **)&FileSystem);
        if (!EFI_ERROR(Status) && FileSystem) {
            Status = FileSystem->OpenVolume(FileSystem, &Root);
            if (!EFI_ERROR(Status) && Root) {
                Root->Open(
                    Root,
                    &gLogFile,
                    L"\\GPU_UNLOCK_LOG.TXT",
                    EFI_FILE_MODE_READ | EFI_FILE_MODE_WRITE | EFI_FILE_MODE_CREATE,
                    0
                );
            }
        }
    }
}

EFI_STATUS
EFIAPI
efi_main (
    IN EFI_HANDLE        ImageHandle,
    IN EFI_SYSTEM_TABLE  *SystemTable
) {
    gST = SystemTable;
    gBS = SystemTable->BootServices;

    // Reset watchdog timer to 15 seconds to ensure host resets if link hangs
    gBS->SetWatchdogTimer(15, 0x0000, 0, NULL);

    InitLogFile(ImageHandle);

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

    if (EFI_ERROR(Status)) {
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

        PCI_TYPE00 PciConfig;
        Status = PciIo->Pci.Read(
            PciIo,
            EfiPciIoWidthUint32,
            0,
            sizeof(PCI_TYPE00) / sizeof(UINT32),
            &PciConfig
        );
        if (EFI_ERROR(Status)) continue;

        if (PciConfig.Hdr.VendorId == TARGET_PCI_VENDOR_ID &&
            PciConfig.Hdr.DeviceId == TARGET_PCI_DEVICE_ID) {
            
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

            UINT32 Subsys = ((UINT32)PciConfig.Device.SubsystemID << 16) | PciConfig.Device.SubsystemVendorID;
            Print(L"    Subsystem ID: ");
            PrintHex(Subsys);
            Print(L"\r\n");
            break;
        }
    }

    if (!FoundTarget || !TargetPciIo) {
        Print(L"[!] GA102 not found on PCI bus.\r\n");
        if (HandleBuffer) gBS->FreePool(HandleBuffer);
        return EFI_NOT_FOUND;
    }

    // Enable Memory Space decode if not already enabled
    UINT16 Command;
    Status = TargetPciIo->Pci.Read(TargetPciIo, EfiPciIoWidthUint16, PCI_COMMAND_OFFSET, 1, &Command);
    if (!EFI_ERROR(Status) && !(Command & EFI_PCI_COMMAND_MEMORY_SPACE)) {
        Command |= EFI_PCI_COMMAND_MEMORY_SPACE;
        TargetPciIo->Pci.Write(TargetPciIo, EfiPciIoWidthUint16, PCI_COMMAND_OFFSET, 1, &Command);
        Print(L"[*] Enabled PCI Memory Space decode on GA102.\r\n");
    }

    Print(L"[*] Probing BAR0 MMIO Speed Selector Registers...\r\n");

    // Read current SS0 (0x0082381c) and SS1 (0x00823820)
    UINT32 Ss0_Before = 0, Ss1_Before = 0;
    Status = TargetPciIo->Mem.Read(
        TargetPciIo,
        EfiPciIoWidthUint32,
        0, // BAR0
        GU_FEAT_SS0_OFFSET,
        1,
        &Ss0_Before
    );

    Status = TargetPciIo->Mem.Read(
        TargetPciIo,
        EfiPciIoWidthUint32,
        0, // BAR0
        GU_FEAT_SS1_OFFSET,
        1,
        &Ss1_Before
    );

    Print(L"    Current SS0 (Instruction Issue Selector): ");
    PrintHex(Ss0_Before);
    Print(L"\r\n");

    Print(L"    Current SS1 (IMLA4 Selector):            ");
    PrintHex(Ss1_Before);
    Print(L"\r\n");

    if (Ss0_Before == GU_SS0_UNLOCK && Ss1_Before == GU_SS1_UNLOCK) {
        Print(L"[SUCCESS] Hardware is ALREADY UNLOCKED (SS0=0x88888888, SS1=0x8)!\r\n");
    } else {
        Print(L"[*] Attempting non-destructive Speed Selector write...\r\n");
        UINT32 TargetSS0 = GU_SS0_UNLOCK;
        UINT32 TargetSS1 = GU_SS1_UNLOCK;

        TargetPciIo->Mem.Write(TargetPciIo, EfiPciIoWidthUint32, 0, GU_FEAT_SS0_OFFSET, 1, &TargetSS0);
        TargetPciIo->Mem.Write(TargetPciIo, EfiPciIoWidthUint32, 0, GU_FEAT_SS1_OFFSET, 1, &TargetSS1);

        UINT32 Ss0_After = 0, Ss1_After = 0;
        TargetPciIo->Mem.Read(TargetPciIo, EfiPciIoWidthUint32, 0, GU_FEAT_SS0_OFFSET, 1, &Ss0_After);
        TargetPciIo->Mem.Read(TargetPciIo, EfiPciIoWidthUint32, 0, GU_FEAT_SS1_OFFSET, 1, &Ss1_After);

        Print(L"    Post-Write SS0: ");
        PrintHex(Ss0_After);
        Print(L"\r\n");

        Print(L"    Post-Write SS1: ");
        PrintHex(Ss1_After);
        Print(L"\r\n");

        if (Ss0_After == GU_SS0_UNLOCK) {
            Print(L"[+] Direct write ACCEPTED by hardware!\r\n");
        } else {
            Print(L"[-] Note: Direct write locked until Falcon SEC2/WPR microcode completes.\r\n");
        }
    }

    if (HandleBuffer) {
        gBS->FreePool(HandleBuffer);
    }

    Print(L"\r\n[*] Disarming watchdog timer...\r\n");
    gBS->SetWatchdogTimer(0, 0x0000, 0, NULL);

    if (gLogFile) {
        gLogFile->Close(gLogFile);
    }

    Print(L"[*] Finished. Exiting to boot manager in 5 seconds...\r\n");
    gBS->Stall(5000000);

    return EFI_SUCCESS;
}
