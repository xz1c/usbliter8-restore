import XCTest
@testable import Usb8RestoreSwift

final class Usbliter8BootOutputTests: XCTestCase {
    func testPipeErrorRequestsRepwn() {
        let output = """
        Traceback (most recent call last):
          File "usbliter8ctl", line 41, in download
        usb.core.USBError: [Errno 32] Pipe error
        """

        XCTAssertTrue(Usbliter8BootOutput.needsRepwn(output))
    }

    func testLibusbPipeErrorRequestsRepwn() {
        XCTAssertTrue(Usbliter8BootOutput.needsRepwn("USBError: LIBUSB_ERROR_PIPE"))
    }

    func testNativeUSBFailureRequestsRepwn() {
        XCTAssertTrue(Usbliter8BootOutput.needsRepwn("USBError: DFU_DNLOAD failed at 0x4000: 0xe000404f"))
    }

    func testUnrelatedFailureDoesNotRequestRepwn() {
        XCTAssertFalse(Usbliter8BootOutput.needsRepwn("RuntimeError: no device?"))
    }

    func testNeedsRepwnMarksSendEraseStep() {
        let error = RestoreError.needsRepwn(step: .sendErase, message: "usb.core.USBError: [Errno 32] Pipe error")

        XCTAssertEqual(error.failedStep, .sendErase)
        XCTAssertEqual(error.errorDescription, "Please re-pwn")
    }
}
