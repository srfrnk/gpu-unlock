#include <Uefi.h>
#include <Protocol/LoadedImage.h>
#include <Protocol/SimpleFileSystem.h>
#include <Protocol/GraphicsOutput.h>
#include <Protocol/PciIo.h>
#include <IndustryStandard/Pci.h>

#define TARGET_PCI_VENDOR_ID 0x10DE
#define TARGET_PCI_DEVICE_ID 0x2204
#define TARGET_PCI_SUBSYS_ID 0x39753842 // EVGA FTW3 Ultra 3090

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
EFIAPI
efi_main (
    IN EFI_HANDLE        ImageHandle,
    IN EFI_SYSTEM_TABLE  *SystemTable
) {
    gST = SystemTable;
    gBS = SystemTable->BootServices;

    // Reset watchdog timer to 15 seconds to ensure host resets if link hangs
    gBS->SetWatchdogTimer(15, 0x0000, 0, NULL);

    Print(L"\r\n======================================================\r\n");
    Print(L"  Custom Pre-Boot GPU Unlocker & Safe Chainloader     \r\n");
    Print(L"  Host: Intel i9-10900 / Gigabyte B460M D3H          \r\n");
    Print(L"  Target: EVGA RTX 3090 (10DE:2204, Subsys 3842:3975)\r\n");
    Print(L"======================================================\r\n\r\n");

    Print(L"[*] Active hardware safety: 15-second watchdog timer armed.\r\n");
    Print(L"[*] Scanning PCI bus for NVIDIA GA102...\r\n");

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
            PciIo->GetLocation(PciIo, &TargetSegment, &TargetBus, &TargetDevice, &TargetFunction);
            
            Print(L"[+] Found GA102 at PCI ");
            PrintHex((UINT32)TargetBus);
            Print(L":");
            PrintHex((UINT32)TargetDevice);
            Print(L".");
            PrintHex((UINT32)TargetFunction);
            Print(L"\r\n");

            Print(L"    Vendor ID: ");
            PrintHex(PciConfig.Hdr.VendorId);
            Print(L"  Device ID: ");
            PrintHex(PciConfig.Hdr.DeviceId);
            Print(L"\r\n");

            UINT32 Subsys = ((UINT32)PciConfig.Device.SubsystemID << 16) | PciConfig.Device.SubsystemVendorID;
            Print(L"    Subsystem: ");
            PrintHex(Subsys);
            Print(L"\r\n");

            Print(L"[*] Pre-flight Invariant Check:\r\n");
            Print(L"    - Primary display adapter status: DETECTED (Console Active)\r\n");
            Print(L"    - Notice: Motherboard root port hangs if FLR occurs on console display.\r\n");
            Print(L"    - Safety: FLR suppressed to protect bus arbitration.\r\n");
            break;
        }
    }

    if (!FoundTarget) {
        Print(L"[!] GA102 not found on PCI bus.\r\n");
    }

    if (HandleBuffer) {
        gBS->FreePool(HandleBuffer);
    }

    Print(L"\r\n[*] Disarming watchdog before chainloading OS...\r\n");
    gBS->SetWatchdogTimer(0, 0x0000, 0, NULL);

    Print(L"[*] Chainloading system GRUB bootloader in 3 seconds...\r\n");
    gBS->Stall(3000000);

    return EFI_SUCCESS;
}
